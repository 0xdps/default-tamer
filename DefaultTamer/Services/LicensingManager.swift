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
import IOKit
import Security

// MARK: - Keychain helper

private enum Keychain {
    private static let service = "app.defaulttamer.licensing"

    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let search: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(search as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = search
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
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
    case serverUnreachable
    case error(String)
}

@MainActor
final class LicensingManager: ObservableObject {
    static let shared = LicensingManager()

    @Published private(set) var status: LicenseStatus?
    @Published private(set) var isValidating = false
    @Published private(set) var activationState: ActivationState = .idle

    private let appTokenKey       = "appToken"
    private let userIdKey         = "userId"
    private let activationIdKey   = "activationId"
    private let cachedStatusKey   = "cachedLicenseStatus"
    private var lastValidated: Date?
    private var heartbeatTimer: Timer?

    private let defaults = UserDefaults.standard

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

    /// Whether the user has an active Power plan license.
    var hasPowerPlan: Bool { status?.plan == .plus }

    /// Whether a specific feature is available under the current license.
    func isEnabled(_ feature: LicenseFeature) -> Bool {
        status?.has(feature) ?? false
    }

    /// Called at app startup. Validates the stored app token against the backend.
    func validateOnLaunch() {
        guard let appToken = Keychain.load(key: appTokenKey) else { return }
        Task { await checkSubscription(appToken: appToken) }
    }

    /// Called when the app returns to the foreground.
    /// Throttled — skips the network call if a check ran within the last 5 minutes.
    func validateOnForeground() {
        if let last = lastValidated, Date().timeIntervalSince(last) < 300 { return }
        validateOnLaunch()
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
        let capturedDeviceId = PersistenceManager.shared.installID
        Task {
            if let capturedToken {
                var req = URLRequest(url: SeatAPIConstants.deactivateURL)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(capturedToken)", forHTTPHeaderField: "Authorization")
                req.timeoutInterval = 8
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["device_id": capturedDeviceId])
                do {
                    let (_, response) = try await URLSession.shared.data(for: req)
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    appLogger.info("Sign-out deactivation HTTP \(statusCode, privacy: .public)")
                } catch {
                    appLogger.error("Sign-out deactivation failed (server will reclaim via heartbeat timeout): \(error.localizedDescription, privacy: .public)")
                }
            }
            // Clear local state after the deactivation attempt completes (or times out).
            Keychain.delete(key: appTokenKey)
            Keychain.delete(key: userIdKey)
            Keychain.delete(key: activationIdKey)
            status = nil
            cacheStatus(nil)
            activationState = .idle
        }
    }

    // MARK: - Private


    /// Reads the hardware model identifier from IOKit, e.g. "MacBookPro18,1".
    /// Returns nil if the value cannot be read (sandboxing or VM environments).
    private static func hardwareModelIdentifier() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        let cfKey = "model" as CFString
        guard let data = IORegistryEntryCreateCFProperty(service, cfKey, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data,
              let raw = String(data: data, encoding: .utf8) else { return nil }
        // Strip any trailing null byte that IOKit sometimes includes.
        return raw.trimmingCharacters(in: .controlCharacters.union(.init(charactersIn: "\0")))
    }

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

    // MARK: - Seat device management

    /// Activates this device's seat via POST /api/seats/activate.
    /// Retries up to 3 times on transient network failures.
    private func activateDevice(appToken: String) async {
        activationState = .activating

        for attempt in 1...3 {
            let success = await tryActivateDevice(appToken: appToken)
            if success { return }
            if attempt < 3 {
                appLogger.info("Device activation attempt \(attempt)/3 failed, retrying…")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        appLogger.error("Device activation failed after 3 attempts")
    }

    /// Single attempt at device activation. Returns true on success.
    private func tryActivateDevice(appToken: String) async -> Bool {
        let deviceId   = PersistenceManager.shared.installID
        let deviceName = Host.current().localizedName ?? "Mac"

        var request = URLRequest(url: SeatAPIConstants.activateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        var body: [String: String] = [
            "device_id":   deviceId,
            "device_name": deviceName,
            "app_version": AppVersion.current,
        ]
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        body["macos_version"] = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        if let modelId = Self.hardwareModelIdentifier() {
            body["model_identifier"] = modelId
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }

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
                startHeartbeatTimer()
                return true
            case 403:
                if let limit = try? JSONDecoder().decode(LimitResponse.self, from: data) {
                    activationState = .overLimit(seatsUsed: limit.seatsUsed, seatsTotal: limit.seatsTotal)
                } else {
                    activationState = .overLimit(seatsUsed: 0, seatsTotal: 0)
                }
                appLogger.warning("Seat limit reached — cannot activate this device")
                return true  // Non-retryable: server definitively rejected
            case 409:
                // Conflict: this device may already be activated. Do a heartbeat to sync.
                appLogger.info("Device activation returned 409 — running heartbeat to sync state")
                await heartbeatDevice(appToken: appToken)
                return true  // heartbeatDevice sets activationState; don't retry
            case 503:
                appLogger.warning("Device activation HTTP 503 (transient) — will retry")
                return false // Retryable
            default:
                activationState = .error("Activation failed (\(http.statusCode))")
                appLogger.error("Device activation HTTP \(http.statusCode, privacy: .public)")
                return true  // Non-retryable: unexpected status code
            }
        } catch {
            let nsError = error as NSError
            let isTransient = nsError.domain == NSURLErrorDomain &&
                (nsError.code == NSURLErrorTimedOut ||
                 nsError.code == NSURLErrorCannotConnectToHost ||
                 nsError.code == NSURLErrorNetworkConnectionLost ||
                 nsError.code == NSURLErrorNotConnectedToInternet ||
                 nsError.code == NSURLErrorDNSLookupFailed)
            if isTransient {
                appLogger.warning("Device activation transient error: \(error.localizedDescription, privacy: .public)")
                return false // Retryable
            }
            activationState = .error(error.localizedDescription)
            appLogger.error("Device activation failed: \(error.localizedDescription, privacy: .public)")
            return true  // Non-retryable
        }
    }

    // MARK: - Periodic heartbeat

    /// Starts a timer that sends a heartbeat every 8 hours to keep the
    /// device's seat active on the server and detect remote deactivations.
    func startHeartbeatTimer() {
        stopHeartbeatTimer()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 28_800, repeats: true) { [weak self] _ in
            guard let self, let appToken = Keychain.load(key: self.appTokenKey) else { return }
            Task { @MainActor in
                await self.heartbeatDevice(appToken: appToken)
            }
        }
        // Allow the timer to fire while UI interactions are happening.
        heartbeatTimer?.tolerance = 900
        RunLoop.main.add(heartbeatTimer!, forMode: .common)
        appLogger.info("Heartbeat timer started (every 8h)")
    }

    /// Stops the periodic heartbeat timer.
    func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        appLogger.info("Heartbeat timer stopped")
    }

    /// Updates last_seen_at via POST /api/seats/heartbeat.
    /// Sets activationState to .deactivatedRemotely if the server returns 404.
    private func heartbeatDevice(appToken: String) async {
        let deviceId = PersistenceManager.shared.installID

        var request = URLRequest(url: SeatAPIConstants.heartbeatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        // Send metadata on every heartbeat so the server always has the latest values
        // (covers OS upgrades, app updates, etc. without requiring a full re-activation).
        var body: [String: String] = [
            "device_id":   deviceId,
            "app_version": AppVersion.current,
        ]
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        body["macos_version"] = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        if let modelId = Self.hardwareModelIdentifier() {
            body["model_identifier"] = modelId
        }
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

                if Keychain.load(key: activationIdKey) != nil {
                    startHeartbeatTimer()
                    await heartbeatDevice(appToken: appToken)
                } else {
                    await activateDevice(appToken: appToken)
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
                activationState = .serverUnreachable
            }
        }
    }
}
