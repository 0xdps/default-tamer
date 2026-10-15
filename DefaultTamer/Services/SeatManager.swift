//
//  SeatManager.swift
//  Default Tamer
//
//  Manages device seat activation, heartbeats, and deactivation for the
//  Power plan licensing system.
//
//  Extracted from LicensingManager to separate seat lifecycle management
//  from subscription validation and promo handling.
//

import AppKit
import Foundation
import IOKit
import Security

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

/// Manages the device's seat in the user's Power plan.
///
/// Responsibilities:
/// - Activate this device against the server's seat pool
/// - Send periodic heartbeats to keep the seat alive
/// - Detect remote deactivations
/// - Deactivate on sign-out
///
/// This class is owned by `LicensingManager` and not used directly by the UI.
@MainActor
final class SeatManager: ObservableObject {

    @Published private(set) var activationState: ActivationState = .idle

    private let activationIdKey = "activationId"
    private let appTokenKey = "appToken"  // Shared with LicensingManager
    private var heartbeatTimer: Timer?

    /// Heartbeat interval — keeps the device's seat alive and detects remote
    /// deactivations. Twice a day is sufficient; the server reclaims seats via
    /// its own timeout if heartbeats stop.
    private let heartbeatInterval: TimeInterval = 43_200  // 12 hours

    // MARK: - Public API

    /// Whether this device has an activation ID stored locally.
    var hasStoredActivation: Bool {
        Keychain.load(key: activationIdKey) != nil
    }

    /// Clears the local activation ID (used on remote deactivation).
    func clearActivation() {
        Keychain.delete(key: activationIdKey)
    }

    /// Marks the server as unreachable (used when subscription check fails
    /// and we have no cached status).
    func markServerUnreachable() {
        activationState = .serverUnreachable
    }

    // MARK: - Device Status

    /// Checks whether this device is already registered via GET /api/seats/status.
    /// Returns true if registered (and saves the activationId), false otherwise.
    /// The web now registers devices during SSR, so this is the common fast path.
    func checkDeviceStatus(appToken: String) async -> Bool {
        let deviceId = PersistenceManager.shared.installID

        var request = URLRequest(url: SeatAPIConstants.statusURL(deviceId: deviceId))
        request.httpMethod = "GET"
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }

            struct StatusResponse: Decodable {
                let registered: Bool
                let activationId: String?
                let planSlug: String?
                let seatsUsed: Int
                let seatsTotal: Int
            }

            guard http.statusCode == 200 else { return false }
            let result = try JSONDecoder().decode(StatusResponse.self, from: data)

            guard result.registered, let activationId = result.activationId else {
                return false
            }

            Keychain.save(key: activationIdKey, value: activationId)
            activationState = .activated(seatsUsed: result.seatsUsed, seatsTotal: result.seatsTotal)
            appLogger.info("✅ Device already registered — \(result.seatsUsed)/\(result.seatsTotal) seats")
            startHeartbeatTimer()
            return true
        } catch {
            appLogger.warning("Device status check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Activation

    /// Activates this device's seat via POST /api/seats/activate.
    /// Retries up to 3 times on transient network failures.
    func activateDevice(appToken: String) async {
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

    /// Single attempt at device activation. Returns true on success (or non-retryable failure).
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

    // MARK: - Periodic Heartbeat

    /// Starts a timer that sends a heartbeat every 12 hours to keep the
    /// device's seat active on the server and detect remote deactivations.
    func startHeartbeatTimer() {
        stopHeartbeatTimer()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self, let appToken = Keychain.load(key: self.appTokenKey) else { return }
            Task { @MainActor in
                await self.heartbeatDevice(appToken: appToken)
            }
        }
        // Allow the timer to fire while UI interactions are happening.
        heartbeatTimer?.tolerance = 1800
        RunLoop.main.add(heartbeatTimer!, forMode: .common)
        appLogger.info("Heartbeat timer started (every \(Int(self.heartbeatInterval / 3600))h)")
    }

    /// Stops the periodic heartbeat timer.
    func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        appLogger.info("Heartbeat timer stopped")
    }

    /// Updates last_seen_at via POST /api/seats/heartbeat.
    /// Sets activationState to .deactivatedRemotely if the server returns 404.
    /// Retries transient failures with exponential backoff (up to 3 attempts).
    func heartbeatDevice(appToken: String) async {
        let deviceId = PersistenceManager.shared.installID

        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        var body: [String: String] = [
            "device_id":   deviceId,
            "app_version": AppVersion.current,
        ]
        body["macos_version"] = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        if let modelId = Self.hardwareModelIdentifier() {
            body["model_identifier"] = modelId
        }
        let bodyData = try? JSONSerialization.data(withJSONObject: body)

        struct HeartbeatResponse: Decodable {
            let active: Bool
            let seatsUsed: Int
            let seatsTotal: Int
        }

        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            var request = URLRequest(url: SeatAPIConstants.heartbeatURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 30
            request.httpBody = bodyData

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { return }

                switch http.statusCode {
                case 200:
                    if let result = try? JSONDecoder().decode(HeartbeatResponse.self, from: data) {
                        if result.active {
                            activationState = .activated(seatsUsed: result.seatsUsed, seatsTotal: result.seatsTotal)
                        } else {
                            clearActivation()
                            activationState = .deactivatedRemotely
                        }
                    }
                    return  // Success — no retry needed
                case 404:
                    clearActivation()
                    activationState = .deactivatedRemotely
                    appLogger.info("Device deactivated remotely — seat released")
                    return  // Definitive — no retry
                case 503:
                    appLogger.warning("Heartbeat HTTP 503 (transient) — attempt \(attempt)/\(maxAttempts)")
                    if attempt < maxAttempts {
                        let delay = UInt64(pow(2.0, Double(attempt - 1))) * 5 // 5s, 10s, 20s
                        try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                        continue
                    }
                default:
                    // Non-fatal: leave existing state unchanged so app stays usable offline
                    appLogger.error("Heartbeat HTTP \(http.statusCode, privacy: .public)")
                    return  // Non-retryable
                }
            } catch {
                let nsError = error as NSError
                let isTransient = nsError.domain == NSURLErrorDomain &&
                    (nsError.code == NSURLErrorTimedOut ||
                     nsError.code == NSURLErrorCannotConnectToHost ||
                     nsError.code == NSURLErrorNetworkConnectionLost ||
                     nsError.code == NSURLErrorNotConnectedToInternet ||
                     nsError.code == NSURLErrorDNSLookupFailed)
                if isTransient && attempt < maxAttempts {
                    let delay = UInt64(pow(2.0, Double(attempt - 1))) * 5 // 5s, 10s, 20s
                    appLogger.warning("Heartbeat transient error (attempt \(attempt)/\(maxAttempts)), retrying in \(delay)s: \(error.localizedDescription, privacy: .public)")
                    try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                    continue
                }
                // Non-fatal: keep existing activation state
                appLogger.error("Heartbeat failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        appLogger.error("Heartbeat failed after \(maxAttempts) attempts")
    }

    // MARK: - Deactivation

    /// Deactivates this device's seat on the server.
    /// Called during sign-out — the server seat is released first, then local state is cleared.
    /// If the network call fails, local state is still cleared; the server will
    /// reclaim the seat via heartbeat timeout.
    func deactivate(appToken: String) async {
        let deviceId = PersistenceManager.shared.installID
        var req = URLRequest(url: SeatAPIConstants.deactivateURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["device_id": deviceId])
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLogger.info("Sign-out deactivation HTTP \(statusCode, privacy: .public)")
        } catch {
            appLogger.error("Sign-out deactivation failed (server will reclaim via heartbeat timeout): \(error.localizedDescription, privacy: .public)")
        }
        clearActivation()
        activationState = .idle
        stopHeartbeatTimer()
    }

    // MARK: - Hardware Info

    /// Reads the hardware model identifier from IOKit, e.g. "MacBookPro18,1".
    /// Returns nil if the value cannot be read (sandboxing or VM environments).
    nonisolated static func hardwareModelIdentifier() -> String? {
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
}
