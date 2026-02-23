//
//  Rule.swift
//  Default Tamer
//
//  Routing rule definitions
//

import Foundation

enum RuleType: String, Codable, CaseIterable {
    case sourceApp = "Source App"
    case domain = "Domain"
    case urlPattern = "URL Pattern"
}

enum DomainMatchType: String, Codable {
    case exact = "Exact"
    case suffix = "Suffix"
    case contains = "Contains"
}

struct Rule: Identifiable, Codable, Hashable {
    let id: UUID
    var type: RuleType
    var enabled: Bool
    var targetBrowserId: String
    var openInPrivateMode: Bool

    // Match criteria (only one set will be used based on type)
    var sourceAppBundleId: String?
    var sourceAppName: String?

    var domainPattern: String?
    var domainMatchType: DomainMatchType?

    var urlContains: String?
    var urlRegex: String?
    
    init(
        id: UUID = UUID(),
        type: RuleType,
        enabled: Bool = true,
        targetBrowserId: String,
        openInPrivateMode: Bool = false
    ) {
        self.id = id
        self.type = type
        self.enabled = enabled
        self.targetBrowserId = targetBrowserId
        self.openInPrivateMode = openInPrivateMode
    }
    
    // Helper to get a human-readable description
    func description(browsers: [Browser]) -> String {
        let targetBrowser = browsers.first(where: { $0.id == targetBrowserId })?.displayName ?? "Unknown"
        
        switch type {
        case .sourceApp:
            let appName = sourceAppName ?? sourceAppBundleId ?? "Unknown"
            return "From \(appName) → \(targetBrowser)"
        case .domain:
            let pattern = domainPattern ?? ""
            let matchType = domainMatchType?.rawValue ?? "Exact"
            return "Domain \(pattern) (\(matchType)) → \(targetBrowser)"
        case .urlPattern:
            let pattern = urlContains ?? urlRegex ?? ""
            return "URL contains '\(pattern)' → \(targetBrowser)"
        }
    }
    
    // Factory methods for common rules
    static func slackToChrome() -> Rule {
        var rule = Rule(type: .sourceApp, targetBrowserId: "com.google.Chrome")

        // Use dynamic resolution for Slack (bundle ID may change)
        if let bundleId = AppResolver.resolveBundleId(forAppNamed: "Slack") {
            rule.sourceAppBundleId = bundleId
            rule.sourceAppName = "Slack"
        } else {
            // Fallback to known bundle ID
            rule.sourceAppBundleId = "com.tinyspeck.slackmacgap"
            rule.sourceAppName = "Slack"
        }

        return rule
    }
    
    static func cursorToChrome() -> Rule {
        var rule = Rule(type: .sourceApp, targetBrowserId: "com.google.Chrome")
        
        // Use dynamic resolution for Cursor (bundle ID may change)
        if let bundleId = AppResolver.resolveBundleId(forAppNamed: "Cursor") {
            rule.sourceAppBundleId = bundleId
            rule.sourceAppName = "Cursor"
        } else {
            // Fallback to known bundle ID
            rule.sourceAppBundleId = "com.todesktop.230313mzl4w4u92"
            rule.sourceAppName = "Cursor"
        }
        
        return rule
    }
    
    /// Updates bundle IDs for app-based rules with dynamic resolution
    /// Returns true if bundle ID was updated
    mutating func refreshBundleId() -> Bool {
        guard type == .sourceApp,
              let appName = sourceAppName else {
            return false
        }
        
        // Try to find updated bundle ID
        if let newBundleId = AppResolver.refreshBundleId(forAppNamed: appName) {
            if newBundleId != sourceAppBundleId {
                sourceAppBundleId = newBundleId
                return true
            }
        }
        
        return false
    }
}
