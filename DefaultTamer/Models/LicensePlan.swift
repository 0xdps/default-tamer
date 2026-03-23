//
//  LicensePlan.swift
//  Default Tamer
//
//  License plan model. The slug matches the NubeAuth plan slug ("free", "plus").
//  The display name shown to users is different — "plus" is presented as "Power".
//

import Foundation

/// Wire slug values that match plan.slug in NubeAuth.
/// Never show the raw slug to users — use `displayName` instead.
enum LicensePlan: String, Codable, Equatable {
    case free = "free"
    case plus = "plus"

    /// User-visible name. "plus" is branded as "Power" in the UI.
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Power"
        }
    }

    var isPaid: Bool { self == .plus }

    /// Initialise from an unknown slug string; returns .free for unrecognised values.
    /// Accepts "plus", "power", or any slug prefixed with "power" (e.g. "power-tq").
    init(slug: String?) {
        guard let slug else { self = .free; return }
        if slug == "plus" || slug.hasPrefix("power") {
            self = .plus
        } else {
            self = .free
        }
    }
}

/// Features that are gated behind the Power plan.
/// Values must match the feature slugs configured in NubeAuth plan settings.
enum LicenseFeature: String, Codable, CaseIterable {
    case privateBrowsing = "private_browsing"
    case chromeProfiles  = "chrome_profiles"
    case shortcutRules   = "shortcut_rules"
}

/// The validated license state returned by LicensingManager after a /check call.
struct LicenseStatus: Codable, Equatable {
    let licenseId: String
    let plan: LicensePlan
    let features: [String]
    let validUntil: Date?

    /// Whether a specific feature is enabled for this license.
    func has(_ feature: LicenseFeature) -> Bool {
        features.contains(feature.rawValue)
    }
}
