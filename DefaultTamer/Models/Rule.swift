//
//  Rule.swift
//  Default Tamer
//
//  Routing rule definitions
//

import Foundation
import SwiftUI

enum RuleType: String, Codable, CaseIterable {
    case sourceApp = "Source App"
    case domain = "Domain"
    case urlPattern = "URL Pattern"
    case shortcut = "Shortcut"

    /// SF Symbol name for this rule type — used in rule lists, detail views, and pickers.
    var symbolName: String {
        switch self {
        case .sourceApp:  return "macwindow"
        case .domain:     return "globe"
        case .urlPattern: return "link"
        case .shortcut:   return "keyboard"
        }
    }

    /// Accent color for this rule type — consistent across all views.
    var accentColor: Color {
        switch self {
        case .sourceApp:  return .orange
        case .domain:     return .blue
        case .urlPattern: return .purple
        case .shortcut:   return .teal
        }
    }
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

    // Shortcut fields
    var shortcutKeyCode: Int?      // NSEvent.keyCode
    var shortcutModifiers: Int?    // NSEvent.ModifierFlags.rawValue
    
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
        case .shortcut:
            let keys = ShortcutFormatter.format(keyCode: shortcutKeyCode, modifiers: shortcutModifiers)
            return "\(keys) → \(targetBrowser)"
        }
    }
    
    // Factory methods for common rules
    static func sourceAppRule(
        appName: String,
        targetBrowserId: String,
        fallbackBundleId: String
    ) -> Rule {
        var rule = Rule(type: .sourceApp, targetBrowserId: targetBrowserId)
        if let bundleId = AppResolver.resolveBundleId(forAppNamed: appName) {
            rule.sourceAppBundleId = bundleId
        } else {
            rule.sourceAppBundleId = fallbackBundleId
        }
        rule.sourceAppName = appName
        return rule
    }
    
    static func slackRule(targetBrowserId: String) -> Rule {
        return sourceAppRule(
            appName: "Slack",
            targetBrowserId: targetBrowserId,
            fallbackBundleId: BundleIdentifiers.slack
        )
    }
    
    static func cursorRule(targetBrowserId: String) -> Rule {
        return sourceAppRule(
            appName: "Cursor",
            targetBrowserId: targetBrowserId,
            fallbackBundleId: "com.todesktop.230313mzl4w4u92"
        )
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
