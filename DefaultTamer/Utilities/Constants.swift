//
//  Constants.swift
//  Default Tamer
//
//  Application-wide constants
//

import Foundation

struct AppVersion {
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}

struct BundleIdentifiers {
    // Browsers
    static let safari = "com.apple.Safari"
    static let chrome = "com.google.Chrome"
    static let firefox = "org.mozilla.firefox"
    static let edge = "com.microsoft.edgemac"
    static let brave = "com.brave.Browser"
    static let arc = "company.thebrowser.Browser"
    static let opera = "com.operasoftware.Opera"
    static let vivaldi = "com.vivaldi.Vivaldi"
    
    // System
    static let finder = "com.apple.finder"
    
    // Common source apps
    static let slack = "com.tinyspeck.slackmacgap"
    static let teams = "com.microsoft.teams2"
    static let vscode = "com.microsoft.VSCode"
    static let vscodeInsiders = "com.microsoft.VSCodeInsiders"
}

struct DatabaseConstants {
    static let currentVersion = 2 // v1→v2 migration adds duration column
    static let maxLogsRetentionDays = 90 // Keep logs for 90 days
    static let cleanupBatchSize = 100 // Delete in batches for performance
    static let defaultFetchLimit = 1000 // Default limit for fetching logs
}

struct UIConstants {
    // Window dimensions
    static let menuBarPopoverWidth: CGFloat = 280
    static let rulesWindowWidth: CGFloat = 600
    static let rulesWindowHeight: CGFloat = 500
    static let addRuleSheetCompactWidth: CGFloat = 500
    static let addRuleSheetCompactHeight: CGFloat = 420
    static let addRuleSheetExpandedHeight: CGFloat = 500
    
    // Icon sizes
    static let browserIconSize: CGFloat = 24
    static let smallIconSize: CGFloat = 16
    static let largeIconSize: CGFloat = 32
    
    // Toast
    static let toastMinWidth: CGFloat = 300
    static let toastMaxWidth: CGFloat = 500
    
    // Table columns
    static let tableColumnMinWidth: CGFloat = 80
    static let tableColumnIdealWidth: CGFloat = 100
}

struct DataConstants {
    // In-memory limits
    static let maxRecentRoutes = 50 // Max recent routes kept in memory
    static let maxCachedBrowsers = 20 // Max browsers to cache
    
    // Confidence thresholds
    static let minimumDetectionConfidence = 0.50 // 50% minimum for source app detection
}

struct TimeConstants {
    // Cache durations
    static let browserCacheExpiration: TimeInterval = 86400 // 24 hours
    static let updateCheckMinimumInterval: TimeInterval = 3600 // 1 hour
    
    // Cleanup intervals
    static let logCleanupInterval: TimeInterval = 3600 // 1 hour
    static let maxLogAge: TimeInterval = 86400 // 24 hours for in-memory logs
    
    // Timeouts
    static let networkTimeout: TimeInterval = 30 // Network request timeout
    static let browserOpenTimeout: TimeInterval = 5 // Timeout for opening browser
}

struct NetworkConstants {
    // Retry
    static let maxRetryAttempts = 3
    static let retryDelay: TimeInterval = 1.0
    
    // Rate limiting
    static let maxRequestsPerMinute = 10
}

struct AnalyticsConfig {
    static let umamiURL: String = Bundle.main.infoDictionary?["DTAnalyticsURL"] as? String ?? "https://analytics.0xlabs.space"
    static let websiteID: String = Bundle.main.infoDictionary?["DTAnalyticsWebsiteID"] as? String ?? "babc74c5-5c94-4f0b-9a47-6b0b0fa12384"
}

struct FeedbackConfig {
    static var submitURL: String { "\(SeatAPIConstants.baseURL)/api/feedback" }
}

// MARK: - Seat-based device management

struct SeatAPIConstants {
    static let baseURL: String = Bundle.main.infoDictionary?["DTBaseURL"] as? String ?? "https://www.defaulttamer.app"

    // MARK: Subscription & payment
    static var subscriptionURL:   URL { URL(string: "\(baseURL)/api/subscription")! }
    static var promoValidateURL:  URL { URL(string: "\(baseURL)/api/promo/validate")! }
    /// Opens the /upgrade funnel page, which handles auth + seat-tier selection + checkout.
    /// Passes the install UUID as `did` so the web can include it in the activation deep link.
    static func upgradeURL(promoCode: String? = nil) -> URL {
        var items: [URLQueryItem] = []
        if let p = promoCode { items.append(URLQueryItem(name: "promo", value: p)) }
        items.append(URLQueryItem(name: "did", value: PersistenceManager.shared.installID))
        var components = URLComponents(string: "\(baseURL)/upgrade")!
        components.queryItems = items
        return components.url!
    }
    /// Opens /upgrade?restore=true — sign in to activate an existing Power plan.
    /// Also passes the install UUID so the deep link can echo it back.
    static var restoreURL: URL {
        var components = URLComponents(string: "\(baseURL)/upgrade")!
        components.queryItems = [
            URLQueryItem(name: "restore", value: "true"),
            URLQueryItem(name: "did",     value: PersistenceManager.shared.installID),
        ]
        return components.url!
    }

    // MARK: Seat management
    static var accountURL:    URL { URL(string: "\(baseURL)/account")! }
    static var activateURL:   URL { URL(string: "\(baseURL)/api/seats/activate")! }
    static var heartbeatURL:  URL { URL(string: "\(baseURL)/api/seats/heartbeat")! }
    static var deactivateURL: URL { URL(string: "\(baseURL)/api/seats/deactivate")! }
}

struct ExternalLinks {
    static let github = "https://github.com/0xdps/default-tamer"
    static let issues = "https://github.com/0xdps/default-tamer/issues"
    static let buyMeACoffee = "https://buymeacoffee.com/0xdps"
    static var website: String { SeatAPIConstants.baseURL }
    static var privacy: String { "\(SeatAPIConstants.baseURL)/privacy" }
    static let developerWebsite = "https://dps.codes"
    /// Promo config — polled once per day to check for active discount codes.
    static let promoConfigURL: String = Bundle.main.infoDictionary?["DTPromoURL"] as? String ?? "https://www.defaulttamer.app/promo.json"
}


