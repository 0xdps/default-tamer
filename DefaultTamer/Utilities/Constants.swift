//
//  Constants.swift
//  Default Tamer
//
//  Application-wide constants
//

import Foundation

struct AppVersion {
    /// Get current app version from Info.plist
    /// This is automatically updated from VERSION.txt during release builds
    static var current: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0"
    }
    
    /// Get build number from Info.plist
    /// This is also updated from VERSION.txt during release builds
    static var build: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "1"
    }
    
    /// Full version string (e.g., "1.0.1")
    static var full: String {
        return current
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
    static let addRuleSheetCompactHeight: CGFloat = 400
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
    static let umamiURL = "https://manage.anately.sh" 
    static let websiteID = "babc74c5-5c94-4f0b-9a47-6b0b0fa12384"
}

struct ExternalLinks {
    static let github = "https://github.com/0xdps/default-tamer"
    static let issues = "https://github.com/0xdps/default-tamer/issues"
    static let buyMeACoffee = "https://buymeacoffee.com/0xdps"
    static let website = "https://www.defaulttamer.app"
    static let privacy = "https://www.defaulttamer.app/privacy"
    static let developerWebsite = "https://dps.codes"
}

struct NubeAuthConstants {
    /// NubeAuth Gateway base URL (staging and production share the same path structure)
    static let gatewayURL = "https://api.staging.proofa.dev"
    /// NubeAuth app public_id registered for Default Tamer
    static let appId = "APP0D4FPSe4Ev"
    /// NubeAuth Power price public_id — encodes the plan, billing interval, provider and currency.
    static let powerPriceId = "PRC0paZVrwadG"
    /// Website bridge page — receives the exchange code from NubeAuth and opens the deep-link
    static let authCallbackURL = "http://localhost:4321/auth/callback"
    /// Pricing page — used as checkout cancel URL
    static let pricingURL = "http://localhost:4321/pricing"

    /// OAuth start URL — activates an existing license (no payment step).
    /// Used when the user already has a Power license and just needs to link it to this device.
    static var oauthStartURL: URL {
        var components = URLComponents(string: "\(gatewayURL)/v1/auth/start")!
        components.queryItems = [
            URLQueryItem(name: "provider",  value: "google"),
            URLQueryItem(name: "app_id",    value: appId),
            URLQueryItem(name: "audience",  value: "app"),
            URLQueryItem(name: "return_to", value: authCallbackURL),
        ]
        return components.url!
    }

    /// Direct billing checkout endpoint — the app calls this with Bearer auth to skip
    /// re-authentication when the user is already signed in.
    static var billingCheckoutURL: URL {
        URL(string: "\(gatewayURL)/v1/payment/checkout")!
    }
    /// Success URL for direct (already-signed-in) checkout.
    /// The callback page detects `?upgraded=true` (no code), shows a success state,
    /// then opens `defaulttamer://upgraded` so the app re-checks the subscription.
    static var upgradeSuccessURL: String { authCallbackURL + "?upgraded=true" }

    /// OAuth + checkout URL — used when the user is NOT yet signed in.
    /// Authenticates via Google and triggers a payment checkout in one browser flow.
    /// The gateway embeds `price_id` in its OAuth state, calls Core billing S2S after
    /// login, then redirects to the payment provider. On success the provider returns
    /// to `returnTo?code=…` — same as plain sign-in — so `handleOAuthCallback` activates
    /// the subscription automatically.
    static func oauthUpgradeURL(returnTo: String) -> URL {
        var components = URLComponents(string: "\(gatewayURL)/v1/auth/start")!
        components.queryItems = [
            URLQueryItem(name: "provider",   value: "google"),
            URLQueryItem(name: "app_id",     value: appId),
            URLQueryItem(name: "audience",   value: "app"),
            URLQueryItem(name: "price_id",   value: powerPriceId),
            URLQueryItem(name: "return_to",  value: returnTo),
            URLQueryItem(name: "cancel_url", value: pricingURL),
        ]
        return components.url!
    }

    /// License check endpoint
    static var licenseCheckURL: URL {
        URL(string: "\(gatewayURL)/v1/license/check")!
    }
}
