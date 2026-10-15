//
//  LicensingManager.swift
//  Default Tamer
//
//  Manages Power plan licensing.
//
//  All NubeAuth communication is proxied through the Default Tamer backend
//  (/api/auth, /api/subscription, /api/checkout, /api/promo) so the app
//  contains no NubeAuth URLs, app IDs, or price IDs.
//
//  Flow:
//  1. User taps "Get Power Plan" / "I already have Power" → opens /upgrade in browser
//  2. Website handles OAuth (Google) and issues a 1-year appToken JWT
//  3. Website fires defaulttamer://activate?token=<appToken>[&upgraded=true]
//  4. App stores appToken in Keychain, calls GET /api/subscription
//  5. If plan is active: calls POST /api/seats/activate with device metadata
//  6. validateOnLaunch() / validateOnForeground() re-checks silently
//

import AppKit
import Foundation
import Security

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
/// Defined in SeatManager.swift and re-exported here for backward compatibility.

@MainActor
final class LicensingManager: ObservableObject {
    static let shared = LicensingManager()

    @Published private(set) var status: LicenseStatus?
    @Published private(set) var isValidating = false

    /// Seat manager handles device activation, heartbeats, and deactivation.
    let seatManager = SeatManager()

    /// Convenience accessor — exposes seat activation state for UI bindings.
    var activationState: ActivationState { seatManager.activationState }

    private let appTokenKey       = "appToken"
    private let userIdKey         = "userId"
    private let cachedStatusKey   = "cachedLicenseStatus"
    private var lastValidated: Date?

    private let defaults = UserDefaults.standard

    /// Minimum interval between automatic subscription checks (foreground resume).
    /// The user opening the app or manually triggering a check bypasses this.
    private let foregroundCheckInterval: TimeInterval = 3600  // 1 hour

    private init() {
        restoreCachedStatus()
    }

    // MARK: - Offline / cached status

    /// Restores the last known license status from UserDefaults so the app
    /// doesn't immediately show "not signed in" when offline.
    private func restoreCachedStatus() {
        guard let data = defaults.data(forKey: cachedStatusKey),
              let cached = try? JSONDecoder().decode(LicenseStatus.self, from: data) else { return }
        status = cached
        appLogger.info("Restored cached license status: \(cached.plan.displayName, privacy: .public)")
    }

    /// Persists the current license status to UserDefaults for offline recovery.
    private func cacheStatus(_ newStatus: LicenseStatus?) {
        guard let newStatus else {
            defaults.removeObject(forKey: cachedStatusKey)
            return
        }
        if let data = try? JSONEncoder().encode(newStatus) {
            defaults.set(data, forKey: cachedStatusKey)
        }
    }

    // MARK: - Public API

    /// Clears all cached license state. Used by tests for isolation.
    /// Does NOT touch the Keychain (app token) — only the in-memory and
    /// UserDefaults-cached status.
    func clearCachedStateForTesting() {
        status = nil
        cacheStatus(nil)
        lastValidated = nil
    }

    /// Whether the user has an active Power plan license.
    var hasPowerPlan: Bool { status?.plan == .plus }

    /// Whether a specific feature is available under the current license.
    func isEnabled(_ feature: LicenseFeature) -> Bool {
        status?.has(feature) ?? false
    }

    /// Called at app startup. Validates the stored app token against the backend.
    /// Throttled to avoid re-checking if we recently validated (e.g. app was
    /// only backgrounded briefly). Use `validateNow()` to force a check.
    func validateOnLaunch() {
        guard let appToken = Keychain.load(key: appTokenKey) else { return }
        if let last = lastValidated, Date().timeIntervalSince(last) < foregroundCheckInterval {
            appLogger.debug("Skipping launch validation — last checked \(Int(Date().timeIntervalSince(last)))s ago")
            return
        }
        Task { await checkSubscription(appToken: appToken) }
    }

    /// Called when the app returns to the foreground.
    /// Throttled — skips the network call if a check ran within the last hour.
    func validateOnForeground() {
        guard let appToken = Keychain.load(key: appTokenKey) else { return }
        if let last = lastValidated, Date().timeIntervalSince(last) < foregroundCheckInterval { return }
        Task { await checkSubscription(appToken: appToken) }
    }

    /// Forces an immediate subscription check, bypassing all throttling.
    /// Use this for user-initiated actions (e.g. tapping "Check status" in the UI).
    func validateNow() {
        guard let appToken = Keychain.load(key: appTokenKey) else { return }
        Task { await checkSubscription(appToken: appToken) }
    }

    /// Validates a promo code via the backend before opening any browser.
    /// Returns the result so the caller can show immediate feedback.
    func validatePromoCode(_ code: String) async -> PromoValidationResult {
        var request = URLRequest(url: SeatAPIConstants.promoValidateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let appToken = Keychain.load(key: appTokenKey) {
            request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": code])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLogger.info("[PromoValidate] HTTP \(statusCode, privacy: .public)")

            struct Response: Decodable {
                let valid: Bool
                let discountCents: Int?
                let adjustedTotal: Int?
                let reason: String?
                struct Promotion: Decodable { let name: String? }
                let promotion: Promotion?
            }

            let result = try JSONDecoder().decode(Response.self, from: data)
            return PromoValidationResult(
                valid: result.valid,
                discountCents: result.discountCents,
                adjustedTotal: result.adjustedTotal,
                reason: result.reason,
                promotionName: result.promotion?.name
            )
        } catch {
            appLogger.error("[PromoValidate] failed: \(error.localizedDescription, privacy: .public)")
            return PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: nil, promotionName: nil)
        }
    }

    /// Handles the activation deep link from the website.
    ///
    /// Stores the app JWT in Keychain, then validates the subscription. When
    /// `isPaymentCallback` is true, uses a retry loop to tolerate Stripe webhook
    /// processing delays (up to 5 attempts with 3-second delays).
    ///
    /// The optional `confirmedDeviceId` is the install UUID echoed back by the
    /// web page; if present and mismatched, we log a warning but proceed anyway
    /// using our own `PersistenceManager.installID` for the actual API call.
    func handleActivation(token: String, isPaymentCallback: Bool, confirmedDeviceId: String? = nil) {
        Keychain.save(key: appTokenKey, value: token)
        if let did = confirmedDeviceId, !did.isEmpty, did != PersistenceManager.shared.installID {
            appLogger.warning("⚠️ activate deep link did=\(did, privacy: .public) does not match local installID — ignoring mismatch")
        }
        Task {
            if isPaymentCallback {
                await checkSubscriptionWithRetry(appToken: token)
            } else {
                await checkSubscription(appToken: token)
            }
        }
    }

    /// Opens `/upgrade` in a browser so the user can sign in and activate an existing Power plan.
    /// Same pre-check as `startUpgrade`: if a stored token already has an active plan, skip browser.
    func startActivation(fallbackBrowserId: String? = nil) {
        guard let appToken = Keychain.load(key: appTokenKey) else {
            open(SeatAPIConstants.restoreURL, in: fallbackBrowserId)
            return
        }
        Task {
            await checkSubscription(appToken: appToken)
            guard status?.plan.isPaid != true else { return }
            open(SeatAPIConstants.restoreURL, in: fallbackBrowserId)
        }
    }

    /// Opens `/upgrade` in a browser to purchase or activate a Power plan.
    /// Performs a subscription pre-check first: if a stored token already has an active plan,
    /// `checkSubscription` will call `activateDevice` and update the UI without opening a browser.
    func startUpgrade(promoCode: String? = nil, fallbackBrowserId: String? = nil) {
        guard let appToken = Keychain.load(key: appTokenKey) else {
            // No stored session — open browser to sign in and purchase.
            open(SeatAPIConstants.upgradeURL(promoCode: promoCode), in: fallbackBrowserId)
            return
        }
        // User has a stored session. Re-check subscription first — covers the case
        // where they just paid in the browser and the app hasn't polled yet,
        // or where they already own the plan on another Mac and have seats available.
        // checkSubscription calls activateDevice automatically when the plan is active,
        // so if it succeeds the UI updates without ever opening a browser.
        Task {
            await checkSubscription(appToken: appToken)
            guard status?.plan.isPaid != true else { return }
            // Still no active plan — open the upgrade/purchase page.
            open(SeatAPIConstants.upgradeURL(promoCode: promoCode), in: fallbackBrowserId)
        }
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

    /// Signs out — deactivates this device's seat on the server, then removes
    /// stored credentials and clears license state. The deactivation call is
    /// awaited before local state is cleared so the server seat is released
    /// first. If the network call fails, we still clear locally — the seat
    /// will be reclaimed by the heartbeat timeout on the server side.
    func signOut() {
        let capturedToken = Keychain.load(key: appTokenKey)
        Task {
            if let capturedToken {
                await seatManager.deactivate(appToken: capturedToken)
            }
            // Clear local state after the deactivation attempt completes (or times out).
            Keychain.delete(key: appTokenKey)
            Keychain.delete(key: userIdKey)
            status = nil
            cacheStatus(nil)
        }
    }

    // MARK: - Private

    /// Checks the subscription status with retries. Used after payment callbacks
    /// to tolerate async Stripe webhook processing delays.
    private func checkSubscriptionWithRetry(appToken: String, maxAttempts: Int = 5, delaySeconds: UInt64 = 3) async {
        for attempt in 1...maxAttempts {
            await checkSubscription(appToken: appToken)
            if status?.plan.isPaid == true { return }
            if attempt < maxAttempts {
                appLogger.info("Subscription not active yet (attempt \(attempt)/\(maxAttempts)), retrying in \(delaySeconds)s…")
                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }
        appLogger.warning("Subscription still inactive after \(maxAttempts) attempts")
    }

    /// Fetches subscription status from GET /api/subscription.
    private func checkSubscription(appToken: String) async {
        isValidating = true
        defer { isValidating = false }

        var request = URLRequest(url: SeatAPIConstants.subscriptionURL)
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 401 {
                appLogger.info("Session expired — clearing stored token")
                Keychain.delete(key: appTokenKey)
                Keychain.delete(key: userIdKey)
                status = nil
                cacheStatus(nil)
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
                let allFeatures = LicenseFeature.allCases.map(\.rawValue)
                let newStatus = LicenseStatus(
                    licenseId: appToken,
                    plan: plan,
                    features: allFeatures,
                    validUntil: validUntil
                )
                status = newStatus
                cacheStatus(newStatus)
                appLogger.info("✅ Subscription active — plan: \(plan.displayName, privacy: .public)")

                if seatManager.hasStoredActivation {
                    seatManager.startHeartbeatTimer()
                    await seatManager.heartbeatDevice(appToken: appToken)
                } else {
                    // Web registers the device during SSR. Check status first;
                    // only fall back to a full activate if the web registration
                    // didn't happen (e.g. older web version or direct app flow).
                    let alreadyRegistered = await seatManager.checkDeviceStatus(appToken: appToken)
                    if !alreadyRegistered {
                        await seatManager.activateDevice(appToken: appToken)
                    }
                }
            } else {
                let freeStatus = LicenseStatus(licenseId: "", plan: .free, features: [], validUntil: nil)
                status = freeStatus
                cacheStatus(freeStatus)
                appLogger.info("Subscription inactive or free plan")
            }
            lastValidated = Date()
        } catch {
            appLogger.error("Subscription check failed: \(error.localizedDescription, privacy: .public)")
            // If we have no status at all (never validated), mark server as unreachable
            // so the UI can show a meaningful message instead of flashing "not signed in".
            if status == nil {
                seatManager.markServerUnreachable()
            }
        }
    }
}
