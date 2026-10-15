//
//  PromoManager.swift
//  Default Tamer
//
//  Polls /promo.json once per day, fires a local notification when a new promo
//  is found, and publishes the active code so LicensingView can auto-fill it.
//
//  JSON shape (DefaultTamerWeb/public/promo.json):
//  [
//    { "active": true, "code": "LAUNCH50", "label": "50% off Power plan",
//      "discountPercent": 50, "expiresAt": "2026-04-30T23:59:59Z" },
//    { "active": true, "code": "WELCOME20", "label": "20% off",
//      "discountPercent": 20, "expiresAt": null }
//  ]
//  The app picks the live entry with the highest discountPercent.
//

import Foundation
import UserNotifications
import AppKit

// MARK: - Model

struct PromoConfig: Decodable {
    let active: Bool
    let code: String?
    let label: String?
    /// Integer percentage discount, e.g. 50 for 50% off. Used to pick the best
    /// promo when multiple are active simultaneously. nil treated as 0.
    let discountPercent: Int?
    let expiresAt: String?       // ISO-8601 or null

    var expiryDate: Date? {
        guard let iso = expiresAt else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: iso) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: iso)
    }

    /// True when active and not yet expired.
    var isLive: Bool {
        guard active, let code, !code.isEmpty else { return false }
        if let expiry = expiryDate { return Date() < expiry }
        return true
    }
}

// MARK: - Manager

@MainActor
final class PromoManager: ObservableObject {
    static let shared = PromoManager()

    /// The currently live promo, or nil when no promo is active.
    @Published private(set) var activePromo: PromoConfig?

    // UserDefaults keys
    private let lastCheckedKey  = "promoLastChecked"
    private let lastSeenCodeKey = "promoLastSeenCode"

    private let checkInterval: TimeInterval = 86_400  // 24 hours

    private init() {}

    // MARK: - Public API

    /// Call on app launch and foreground resume (throttled internally to once per 24 h).
    func checkIfNeeded() {
        let last = UserDefaults.standard.double(forKey: lastCheckedKey)
        let elapsed = Date().timeIntervalSince1970 - last
        guard elapsed >= checkInterval else { return }
        Task { await fetchPromo() }
    }

    /// Force an immediate fetch — used after the user taps a `defaulttamer://promo` deep link.
    func checkNow() {
        Task { await fetchPromo() }
    }

    /// Apply a promo code arriving via deep link (`defaulttamer://promo?code=LAUNCH50`).
    /// Publishes the promo immediately so LicensingView can auto-fill the field,
    /// then schedules a background validation poll so the label/expiry stay up-to-date.
    func applyFromDeepLink(code: String) {
        // Publish a minimal config immediately so the UI fills the field right away.
        activePromo = PromoConfig(active: true, code: code, label: nil, discountPercent: nil, expiresAt: nil)
        // Fetch the canonical promo.json in the background to enrich label/expiry/discountPercent.
        Task { await fetchPromo() }
    }

    // MARK: - Private

    private func fetchPromo() async {
        guard let url = URL(string: ExternalLinks.promoConfigURL) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let configs = try JSONDecoder().decode([PromoConfig].self, from: data)

            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckedKey)

            // Pick the live promo with the highest discount percentage.
            let best = configs
                .filter { $0.isLive }
                .max(by: { ($0.discountPercent ?? 0) < ($1.discountPercent ?? 0) })

            if let best {
                activePromo = best
                maybeNotify(best)
            } else {
                activePromo = nil
            }
        } catch {
            appLogger.error("PromoManager: fetch failed — \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fires a local notification only when the code is one the user hasn't seen before.
    private func maybeNotify(_ config: PromoConfig) {
        guard let code = config.code else { return }
        let lastSeen = UserDefaults.standard.string(forKey: lastSeenCodeKey)
        guard lastSeen != code else { return }

        UserDefaults.standard.set(code, forKey: lastSeenCodeKey)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            self.scheduleNotification(config)
        }
    }

    private func scheduleNotification(_ config: PromoConfig) {
        let content = UNMutableNotificationContent()
        content.title = "Limited-time offer on Default Tamer"

        if let label = config.label, !label.isEmpty {
            content.body = "\(label) — use code \(config.code ?? ""). Open the app to apply it."
        } else {
            content.body = "Use promo code \(config.code ?? "") for a discount. Open the app to apply it."
        }

        if let expiry = config.expiryDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            content.subtitle = "Expires \(fmt.string(from: expiry))"
        }

        content.sound = .default
        // Deep-link back into the app on notification tap
        content.userInfo = ["url": "defaulttamer://promo?code=\(config.code ?? "")"]

        let request = UNNotificationRequest(
            identifier: "promo-\(config.code ?? "active")",
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                appLogger.error("PromoManager: notification scheduling failed — \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
