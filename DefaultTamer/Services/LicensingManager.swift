//
//  LicensingManager.swift
//  Default Tamer
//
//  Manages Power plan licensing via NubeAuth OAuth.
//
//  Flow:
//  1. User taps "Sign in with Google" → startOAuth() opens browser to NubeAuth
//  2. NubeAuth redirects to https://www.defaulttamer.app/auth/callback?code=...
//  3. Website bridge opens defaulttamer://auth?code=... deep link
//  4. AppDelegate calls handleOAuthCallback(_:) → exchangeCode() → POST /v1/auth/token
//  5. App stores the returned sessionToken and calls GET /v1/me/subscription
//  6. validateOnLaunch() re-checks the subscription on every app launch.
//

import AppKit
import Foundation
import Security

// MARK: - Keychain helper

private enum Keychain {
    private static let service = "app.defaulttamer.licensing"

    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Promo validation

struct PromoValidationResult {
    let valid: Bool
    let discountCents: Int?
    let adjustedTotal: Int?
    let reason: String?
    let promotionName: String?

    /// Human-readable error suitable for display in the UI.
    var errorMessage: String {
        guard !valid else { return "" }
        switch reason {
        case "code_not_found":                           return "Invalid promo code."
        case "promotion_inactive", "code_inactive":      return "This promo code is no longer active."
        case "promotion_not_started":                    return "This promo code isn't active yet."
        case "promotion_expired":                        return "This promo code has expired."
        case "code_exhausted",
             "promotion_max_redemptions_reached":        return "This promo code has reached its usage limit."
        case "plan_not_eligible":                        return "This promo code isn't valid for this plan."
        case "interval_not_eligible":                   return "This promo code isn't valid for this billing period."
        case "existing_customer":                       return "This promo code is for new customers only."
        case "already_redeemed":                        return "You've already used this promo code."
        default:                                         return "This promo code is not valid."
        }
    }
}

// MARK: - LicensingManager

/// The activation state of this device's seat in the user's plan.
enum ActivationState: Equatable {
    case idle
    case activating
    case activated(seatsUsed: Int, seatsTotal: Int)
    case overLimit(seatsUsed: Int, seatsTotal: Int)
    case deactivatedRemotely
    case error(String)
}

@MainActor
final class LicensingManager: ObservableObject {
    static let shared = LicensingManager()

    @Published private(set) var status: LicenseStatus?
    @Published private(set) var isValidating = false
    @Published private(set) var activationState: ActivationState = .idle

    private let sessionTokenKey  = "sessionToken"
    private let userIdKey        = "userId"
    private let activationIdKey  = "activationId"
    private var lastValidated: Date?

    private init() {}

    // MARK: - Public API

    /// Whether the user has an active Power plan license.
    var hasPowerPlan: Bool { status?.plan == .plus }

    /// Whether a specific feature is available under the current license.
    func isEnabled(_ feature: LicenseFeature) -> Bool {
        status?.has(feature) ?? false
    }

    /// Called at app startup. If a session token is stored, validates the subscription server-side.
    func validateOnLaunch() {
        guard let sessionToken = Keychain.load(key: sessionTokenKey) else { return }
        Task { await checkSubscription(sessionToken: sessionToken) }
    }

    /// Called when the app returns to the foreground.
    /// Throttled — skips the network call if a check ran within the last 5 minutes.
    func validateOnForeground() {
        if let last = lastValidated, Date().timeIntervalSince(last) < 300 { return }
        validateOnLaunch()
    }

    /// Opens the NubeAuth OAuth flow to activate an existing license (no payment).
    /// Use this when the user already has a Power plan and just needs to link it to this device.
    /// Opens in the user's configured fallback browser; falls back to the system default.
    func startOAuth(fallbackBrowserId: String? = nil) {
        open(NubeAuthConstants.oauthStartURL, in: fallbackBrowserId)
    }

    /// Validates a promo code against the NubeAuth billing API before opening any browser.
    /// Returns the result synchronously so the caller can show immediate feedback.
    /// Passes `X-Nube-User-Id` when the user is already signed in to enable
    /// `existing_customer` / `already_redeemed` server-side checks.
    func validatePromoCode(_ code: String) async -> PromoValidationResult {
        var request = URLRequest(url: NubeAuthConstants.validatePromoURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let userId = Keychain.load(key: userIdKey)
        if let userId {
            request.setValue(userId, forHTTPHeaderField: "X-Nube-User-Id")
        }

        let body: [String: String] = [
            "code":    code,
            "priceId": NubeAuthConstants.powerPriceId,
            "appId":   NubeAuthConstants.appId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("━━━ [PromoValidate] REQUEST ━━━")
        print("  URL:     \(NubeAuthConstants.validatePromoURL.absoluteString)")
        print("  code:    \(code)")
        print("  priceId: \(NubeAuthConstants.powerPriceId)")
        print("  appId:   \(NubeAuthConstants.appId)")
        print("  userId:  \(userId ?? "(none)")")
        appLogger.info("[PromoValidate] POST \(NubeAuthConstants.validatePromoURL.absoluteString, privacy: .public) code=\(code, privacy: .public) priceId=\(NubeAuthConstants.powerPriceId, privacy: .public) appId=\(NubeAuthConstants.appId, privacy: .public) userId=\(userId ?? "(none)", privacy: .public)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"

            print("━━━ [PromoValidate] RESPONSE ━━━")
            print("  HTTP:    \(statusCode)")
            print("  Body:    \(rawBody)")
            appLogger.info("[PromoValidate] HTTP \(statusCode) body=\(rawBody, privacy: .public)")

            struct Response: Decodable {
                let valid: Bool
                let discountCents: Int?
                let adjustedTotal: Int?
                let reason: String?
                struct Promotion: Decodable { let name: String? }
                let promotion: Promotion?
            }

            do {
                let result = try JSONDecoder().decode(Response.self, from: data)
                print("  Decoded: valid=\(result.valid) reason=\(result.reason ?? "nil") promotion=\(result.promotion?.name ?? "nil")")
                appLogger.info("[PromoValidate] decoded valid=\(result.valid) reason=\(result.reason ?? "nil", privacy: .public)")
                return PromoValidationResult(
                    valid: result.valid,
                    discountCents: result.discountCents,
                    adjustedTotal: result.adjustedTotal,
                    reason: result.reason,
                    promotionName: result.promotion?.name
                )
            } catch {
                print("  DECODE ERROR: \(error)")
                appLogger.error("[PromoValidate] decode error: \(error.localizedDescription, privacy: .public)")
                return PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: nil, promotionName: nil)
            }
        } catch {
            print("━━━ [PromoValidate] NETWORK ERROR ━━━")
            print("  \(error)")
            appLogger.error("[PromoValidate] network error: \(error.localizedDescription, privacy: .public)")
            return PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: nil, promotionName: nil)
        }
    }

    /// Initiates a Power plan purchase.
    ///
    /// If the user is already signed in, calls `POST /v1/payment/checkout` directly
    /// to skip re-authentication and opens the returned Stripe/Dodo checkout page.
    /// On success the payment provider redirects to the website callback page with
    /// `?upgraded=true`, which opens `defaulttamer://upgraded` and triggers a
    /// subscription re-check.
    ///
    /// If the user is NOT signed in, falls back to the combined OAuth + payment URL
    /// so they authenticate and pay in a single browser flow. Success returns a
    /// `defaulttamer://auth?code=…` deep-link handled by `handleOAuthCallback`.
    ///
    /// Pass `promoCode` after validating it with `validatePromoCode(_:)` to apply a
    /// discount. It is forwarded to the payment provider in both the direct-checkout
    /// and OAuth+checkout paths.
    @discardableResult
    func startUpgrade(priceId: String = NubeAuthConstants.powerPriceId, promoCode: String? = nil, fallbackBrowserId: String? = nil) async -> Bool {
        if let sessionToken = Keychain.load(key: sessionTokenKey) {
            if let checkoutURL = await createCheckoutSession(priceId: priceId, sessionToken: sessionToken, promoCode: promoCode) {
                open(checkoutURL, in: fallbackBrowserId)
                return true
            }
            appLogger.warning("Direct checkout failed; falling back to OAuth+payment URL")
        }

        open(NubeAuthConstants.oauthUpgradeURL(priceId: priceId, returnTo: NubeAuthConstants.authCallbackURL, promoCode: promoCode),
             in: fallbackBrowserId)
        return true
    }

    /// Called when the OS delivers `defaulttamer://upgraded` after a successful
    /// direct-checkout payment. Re-checks the subscription so the UI updates to Power.
    /// Retries up to 5 times to handle the async Stripe webhook processing delay.
    func handleUpgradeCallback() {
        guard let sessionToken = Keychain.load(key: sessionTokenKey) else {
            appLogger.warning("handleUpgradeCallback — no session token found, ignoring")
            return
        }
        Task { await checkSubscriptionWithRetry(sessionToken: sessionToken) }
    }


    // Open a URL in a specific browser, falling back to NSWorkspace if the browser can't be launched.
    private func open(_ url: URL, in browserId: String?) {
        if let browserId, !browserId.isEmpty,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserId) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Called by AppDelegate when the OS delivers a `defaulttamer://auth` deep-link.
    /// Reads the one-time exchange code, calls POST /v1/auth/token to get a session
    /// token, stores it in Keychain, then validates the subscription status.
    func handleOAuthCallback(_ url: URL) {
        guard url.scheme == "defaulttamer", url.host == "auth" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            appLogger.error("OAuth error from deep-link: \(error, privacy: .public)")
            return
        }

        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            appLogger.error("defaulttamer://auth — missing or empty code")
            return
        }

        let isPaymentCallback = components?.queryItems?.contains(where: { $0.name == "upgraded" && $0.value == "true" }) ?? false
        Task { await exchangeCode(code, isPaymentCallback: isPaymentCallback) }
    }

    /// Signs out — deactivates this device's seat, removes stored credentials, clears license state.
    func signOut() {
        // Capture values before clearing keychain so the network request has what it needs.
        let capturedToken = Keychain.load(key: sessionTokenKey)
        let capturedDeviceId = PersistenceManager.shared.installID
        if let capturedToken {
            Task {
                var req = URLRequest(url: SeatAPIConstants.deactivateURL)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(capturedToken)", forHTTPHeaderField: "Authorization")
                req.timeoutInterval = 15
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["device_id": capturedDeviceId])
                try? await URLSession.shared.data(for: req)
            }
        }
        Keychain.delete(key: sessionTokenKey)
        Keychain.delete(key: userIdKey)
        Keychain.delete(key: activationIdKey)
        status = nil
        activationState = .idle
    }

    // MARK: - Private

    /// Calls `POST /v1/payment/checkout` with the stored session token to create a
    /// checkout session directly (no re-authentication needed).
    /// Returns the payment provider's redirect URL on success, or `nil` on failure.
    private func createCheckoutSession(priceId: String = NubeAuthConstants.powerPriceId, sessionToken: String, promoCode: String? = nil) async -> URL? {
        var request = URLRequest(url: NubeAuthConstants.billingCheckoutURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        var body: [String: String] = [
            "priceId":    priceId,
            "appId":      NubeAuthConstants.appId,
            "successUrl": NubeAuthConstants.upgradeSuccessURL,
            "cancelUrl":  NubeAuthConstants.pricingURL,
        ]
        if let promoCode {
            body["promoCode"] = promoCode
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }

            if http.statusCode == 401 {
                appLogger.info("Billing checkout — session expired, clearing token")
                Keychain.delete(key: sessionTokenKey)
                Keychain.delete(key: userIdKey)
                status = nil
                return nil
            }

            guard http.statusCode == 200 else {
                appLogger.error("Billing checkout HTTP \(http.statusCode, privacy: .public)")
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rawURL = json["checkoutUrl"] as? String,
               let url = URL(string: rawURL) {
                appLogger.info("✅ Checkout session created")
                return url
            }
            appLogger.error("Billing checkout — could not parse checkoutUrl from response")
            return nil
        } catch {
            appLogger.error("Billing checkout failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Polls /v1/me/subscription up to `maxAttempts` times with `delaySeconds` between
    /// retries. Used after payment callbacks to tolerate async Stripe webhook processing.
    private func checkSubscriptionWithRetry(sessionToken: String, maxAttempts: Int = 5, delaySeconds: UInt64 = 3) async {
        for attempt in 1...maxAttempts {
            await checkSubscription(sessionToken: sessionToken)
            if status?.plan.isPaid == true { return }
            if attempt < maxAttempts {
                appLogger.info("Subscription not active yet (attempt \(attempt)/\(maxAttempts)), retrying in \(delaySeconds)s…")
                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }
        appLogger.warning("Subscription still inactive after \(maxAttempts) attempts")
    }

    // MARK: - Seat device management

    /// Activates this device's seat via POST /api/seats/activate.
    private func activateDevice(sessionToken: String) async {
        let deviceId   = PersistenceManager.shared.installID
        let deviceName = Host.current().localizedName ?? "Mac"

        activationState = .activating

        var request = URLRequest(url: SeatAPIConstants.activateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: String] = ["device_id": deviceId, "device_name": deviceName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            struct ActivateResponse: Decodable {
                let activationId: String
                let seatsUsed: Int
                let seatsTotal: Int
            }
            struct LimitResponse: Decodable {
                let seatsUsed: Int
                let seatsTotal: Int
            }

            switch http.statusCode {
            case 200:
                let result = try JSONDecoder().decode(ActivateResponse.self, from: data)
                Keychain.save(key: activationIdKey, value: result.activationId)
                activationState = .activated(seatsUsed: result.seatsUsed, seatsTotal: result.seatsTotal)
                appLogger.info("✅ Device activated — \(result.seatsUsed)/\(result.seatsTotal) seats")
            case 403:
                if let limit = try? JSONDecoder().decode(LimitResponse.self, from: data) {
                    activationState = .overLimit(seatsUsed: limit.seatsUsed, seatsTotal: limit.seatsTotal)
                } else {
                    activationState = .overLimit(seatsUsed: 0, seatsTotal: 0)
                }
                appLogger.warning("Seat limit reached — cannot activate this device")
            default:
                activationState = .error("Activation failed (\(http.statusCode))")
                appLogger.error("Device activation HTTP \(http.statusCode, privacy: .public)")
            }
        } catch {
            activationState = .error(error.localizedDescription)
            appLogger.error("Device activation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Updates last_seen_at via POST /api/seats/heartbeat.
    /// Sets activationState to .deactivatedRemotely if the server returns 404.
    private func heartbeatDevice(sessionToken: String) async {
        let deviceId = PersistenceManager.shared.installID

        var request = URLRequest(url: SeatAPIConstants.heartbeatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: String] = ["device_id": deviceId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            struct HeartbeatResponse: Decodable {
                let active: Bool
                let seatsUsed: Int
                let seatsTotal: Int
            }

            switch http.statusCode {
            case 200:
                if let result = try? JSONDecoder().decode(HeartbeatResponse.self, from: data) {
                    if result.active {
                        activationState = .activated(seatsUsed: result.seatsUsed, seatsTotal: result.seatsTotal)
                    } else {
                        Keychain.delete(key: activationIdKey)
                        activationState = .deactivatedRemotely
                    }
                }
            case 404:
                Keychain.delete(key: activationIdKey)
                activationState = .deactivatedRemotely
                appLogger.info("Device deactivated remotely — seat released")
            default:
                // Non-fatal: leave existing state unchanged so app stays usable offline
                appLogger.error("Heartbeat HTTP \(http.statusCode, privacy: .public)")
            }
        } catch {
            // Non-fatal: keep existing activation state
            appLogger.error("Heartbeat failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Exchange the one-time code for a long-lived session token via POST /v1/auth/token.
    private func exchangeCode(_ code: String, isPaymentCallback: Bool = false) async {
        isValidating = true
        defer { isValidating = false }

        guard let url = URL(string: "\(NubeAuthConstants.gatewayURL)/v1/auth/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: String] = [
            "code":   code,
            "app_id": NubeAuthConstants.appId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                appLogger.error("Token exchange HTTP \(statusCode, privacy: .public)")
                return
            }

            struct TokenResponse: Decodable {
                let sessionToken: String
                let userId: String
                let appId: String
            }

            let result = try JSONDecoder().decode(TokenResponse.self, from: data)
            Keychain.save(key: sessionTokenKey, value: result.sessionToken)
            Keychain.save(key: userIdKey, value: result.userId)
            appLogger.info("✅ Token exchange OK — userId: \(result.userId, privacy: .public)")

            if isPaymentCallback {
                await checkSubscriptionWithRetry(sessionToken: result.sessionToken)
            } else {
                await checkSubscription(sessionToken: result.sessionToken)
            }
        } catch {
            appLogger.error("Token exchange failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetch /v1/me/subscription using the stored Bearer session token.
    private func checkSubscription(sessionToken: String) async {
        isValidating = true
        defer { isValidating = false }

        guard let url = URL(string: "\(NubeAuthConstants.gatewayURL)/v1/me/subscription") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 401 {
                appLogger.info("Session expired — clearing stored token")
                Keychain.delete(key: sessionTokenKey)
                Keychain.delete(key: userIdKey)
                status = nil
                return
            }

            struct SubscriptionResponse: Decodable {
                let hasActivePlan: Bool
                let planSlug: String?
                let status: String?
                let periodEnd: String?
            }

            let result = try JSONDecoder().decode(SubscriptionResponse.self, from: data)

            if result.hasActivePlan {
                let plan = LicensePlan(slug: result.planSlug)
                var validUntil: Date?
                if let iso = result.periodEnd {
                    let fmt = ISO8601DateFormatter()
                    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    validUntil = fmt.date(from: iso)
                }
                // All Power features are unlocked when the subscription is active.
                let allFeatures = LicenseFeature.allCases.map(\.rawValue)
                status = LicenseStatus(
                    licenseId: sessionToken,
                    plan: plan,
                    features: allFeatures,
                    validUntil: validUntil
                )
                appLogger.info("✅ Subscription active — plan: \(plan.displayName, privacy: .public)")

                // Activate or heartbeat this device's seat
                if Keychain.load(key: activationIdKey) != nil {
                    await heartbeatDevice(sessionToken: sessionToken)
                } else {
                    await activateDevice(sessionToken: sessionToken)
                }
            } else {
                status = LicenseStatus(licenseId: "", plan: .free, features: [], validUntil: nil)
                appLogger.info("Subscription inactive or free plan")
            }
            lastValidated = Date()
        } catch {
            appLogger.error("Subscription check failed: \(error.localizedDescription, privacy: .public)")
            // Non-fatal: leave existing status unchanged so the app stays usable offline
        }
    }
}
