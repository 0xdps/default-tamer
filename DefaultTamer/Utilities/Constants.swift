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
    static let umamiURL = "https://manage.anately.sh" 
    static let websiteID = "babc74c5-5c94-4f0b-9a47-6b0b0fa12384"
}

struct FeedbackConfig {
    static let submitURL = "https://api.inbounce.app/submit"
    #if DEBUG
    static let token = "e31470b50d73ca656538332fc32f500dd93d809f48423699bb8cc8adbe84d291"
    #else
    static let token = "2f70a7b331d693fc3b61ad69ca0dcd6b10a30483a7bfffa5b3753cea0eb511d8"
    #endif
}

struct ExternalLinks {
    static let github = "https://github.com/0xdps/default-tamer"
    static let issues = "https://github.com/0xdps/default-tamer/issues"
    static let buyMeACoffee = "https://buymeacoffee.com/0xdps"
    static let website = "https://www.defaulttamer.app"
    static let privacy = "https://www.defaulttamer.app/privacy"
    static let developerWebsite = "https://dps.codes"
    /// Promo config — polled once per day to check for active discount codes.
    /// Points to the local dev server in debug and the live site in production.
    #if DEBUG
    static let promoConfigURL = "http://localhost:4321/promo.json"
    #else
    static let promoConfigURL = "https://www.defaulttamer.app/promo.json"
    #endif
}

struct NubeAuthConstants {

    // -------------------------------------------------------------------------
    // Environment-specific values
    // Debug builds  → staging endpoints + localhost website
    // Release builds → production endpoints + live website
    // -------------------------------------------------------------------------

    #if DEBUG
    static let gatewayURL      = "https://api.staging.nubeauth.com"
    static let appId           = "APP0D4FPSe4Ev"
    static let powerPriceId    = "PRC0ADuG3k15Q"
    static let authCallbackURL = "http://localhost:4321/auth/callback"
    static let pricingURL      = "http://localhost:4321/pricing"
    #else
    static let gatewayURL      = "https://api.nubeauth.com"
    static let appId           = "APP0production"       // TODO: replace with production app ID
    static let powerPriceId    = "PRC0production"       // TODO: replace with production price ID
    static let authCallbackURL = "https://www.defaulttamer.app/auth/callback"
    static let pricingURL      = "https://www.defaulttamer.app/pricing"
    #endif

    // -------------------------------------------------------------------------
    // Derived URLs — shared across environments
    // -------------------------------------------------------------------------

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

    /// Promo code validation endpoint — call this before opening the browser to give
    /// the user immediate feedback if a code is invalid, exhausted, or expired.
    /// No auth required; pass X-Nube-User-Id if the user is already signed in.
    static var validatePromoURL: URL {
        URL(string: "\(gatewayURL)/v1/payment/validate-promo")!
    }

    /// OAuth + checkout URL — used when the user is NOT yet signed in.
    /// Authenticates via Google and triggers a payment checkout in one browser flow.
    /// Pass `promoCode` to pre-apply a validated discount coupon at the payment step.
    static func oauthUpgradeURL(returnTo: String, promoCode: String? = nil) -> URL {
        var components = URLComponents(string: "\(gatewayURL)/v1/auth/start")!
        var queryItems = [
            URLQueryItem(name: "provider",   value: "google"),
            URLQueryItem(name: "app_id",     value: appId),
            URLQueryItem(name: "audience",   value: "app"),
            URLQueryItem(name: "price_id",   value: powerPriceId),
            URLQueryItem(name: "return_to",  value: returnTo),
            URLQueryItem(name: "cancel_url", value: pricingURL),
        ]
        if let promoCode {
            queryItems.append(URLQueryItem(name: "promo_code", value: promoCode))
        }
        components.queryItems = queryItems
        return components.url!
    }

    /// License check endpoint
    static var licenseCheckURL: URL {
        URL(string: "\(gatewayURL)/v1/license/check")!
    }
}
