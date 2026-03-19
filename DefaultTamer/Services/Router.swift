//
//  Router.swift
//  Default Tamer
//
//  Pure routing decision engine
//

import Foundation
import AppKit

enum RouteAction {
    case openInBrowser(bundleId: String, matchedRule: Rule?)
    case showChooser(url: URL)
    case openInFallback
}

class Router {
    
    /// Compiled NSRegularExpression cache, keyed by pattern string.
    /// NSRegularExpression is thread-safe after compilation.
    private nonisolated(unsafe) static var regexCache: [String: NSRegularExpression] = [:]
    
    /// Returns a cached compiled regex, or compiles and caches on first access.
    private static func compiledRegex(for pattern: String) throws -> NSRegularExpression {
        if let cached = regexCache[pattern] {
            return cached
        }
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        regexCache[pattern] = regex
        return regex
    }
    
    /// Main routing decision function
    /// Returns the action to take for a given URL
    static func route(
        url: URL,
        sourceApp: String?,
        settings: Settings,
        rules: [Rule],
        modifierFlags: NSEvent.ModifierFlags?
    ) -> RouteAction {
        
        appLogger.info("🔀 Routing URL: \(url.absoluteString, privacy: .public)")
        appLogger.info("🔀 Source App: \(sourceApp ?? "nil", privacy: .public)")
        appLogger.info("🔀 Enabled Rules: \(rules.filter { $0.enabled }.count, privacy: .public)/\(rules.count, privacy: .public)")
        
        // Check if app is disabled
        guard settings.enabled else {
            appLogger.info("🔀 App disabled, using fallback")
            return .openInFallback
        }
        
        // Check for modifier key to show chooser
        if let flags = modifierFlags, flags.contains(settings.chooserModifierFlags) {
            appLogger.info("🔀 Modifier key held (\(settings.chooserModifierKey)), showing chooser")
            return .showChooser(url: url)
        }
        
        // Evaluate rules top-to-bottom, first match wins
        for (index, rule) in rules.enumerated() where rule.enabled {
            appLogger.info("🔀 Evaluating rule #\(index + 1, privacy: .public): \(rule.type.rawValue, privacy: .public)")
            if let action = evaluateRule(rule, url: url, sourceApp: sourceApp) {
                appLogger.info("🔀 ✅ Rule matched!")
                return action
            }
            appLogger.info("🔀 ❌ Rule didn't match")
        }
        
        // No rule matched, use fallback
        appLogger.info("🔀 No rules matched, using fallback")
        return .openInFallback
    }
    
    /// Evaluates a single rule against the URL and source app
    private static func evaluateRule(_ rule: Rule, url: URL, sourceApp: String?) -> RouteAction? {
        switch rule.type {
        case .sourceApp:
            return evaluateSourceAppRule(rule, sourceApp: sourceApp)
        case .domain:
            return evaluateDomainRule(rule, url: url)
        case .urlPattern:
            return evaluateURLPatternRule(rule, url: url)
        }
    }
    
    /// Evaluates source app rule
    private static func evaluateSourceAppRule(_ rule: Rule, sourceApp: String?) -> RouteAction? {
        guard let ruleAppBundleId = rule.sourceAppBundleId else {
            appLogger.info("   Source app rule: No bundle ID set")
            return nil
        }
        
        guard let sourceApp = sourceApp else {
            appLogger.info("   Source app rule: No source app for \(ruleAppBundleId)")
            return nil
        }
        
        appLogger.info("   Source app rule: source=\(sourceApp, privacy: .public), rule=\(ruleAppBundleId, privacy: .public)")
        
        if sourceApp == ruleAppBundleId {
            appLogger.info("   ✅ Source app rule MATCHED!")
            return .openInBrowser(bundleId: rule.targetBrowserId, matchedRule: rule)
        }
        
        return nil
    }
    
    /// Evaluates domain rule
    private static func evaluateDomainRule(_ rule: Rule, url: URL) -> RouteAction? {
        guard let host = url.host?.lowercased() else {
            appLogger.info("   Domain rule: URL has no host")
            return nil
        }
        
        guard let pattern = rule.domainPattern?.lowercased() else {
            appLogger.info("   Domain rule: No pattern set")
            return nil
        }
        
        guard let matchType = rule.domainMatchType else {
            appLogger.info("   Domain rule: No match type set")
            return nil
        }
        
        appLogger.info("   Domain rule: host=\(host, privacy: .public), pattern=\(pattern, privacy: .public), type=\(matchType.rawValue, privacy: .public)")
        
        let matches: Bool
        switch matchType {
        case .exact:
            // Normalize both by stripping 'www.' for cleaner UX
            // This way github.com matches both github.com and www.github.com
            let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            let normalizedPattern = pattern.hasPrefix("www.") ? String(pattern.dropFirst(4)) : pattern
            matches = normalizedHost == normalizedPattern
        case .suffix:
            // Pattern like ".atlassian.net" or "atlassian.net"
            let suffixPattern = pattern.hasPrefix(".") ? pattern : "." + pattern
            matches = host.hasSuffix(suffixPattern) || host == pattern
        case .contains:
            matches = host.contains(pattern)
        }
        
        appLogger.info("   Domain rule: matches=\(matches, privacy: .public)")
        
        if matches {
            return .openInBrowser(bundleId: rule.targetBrowserId, matchedRule: rule)
        }
        
        return nil
    }
    
    /// Evaluates URL pattern rule
    private static func evaluateURLPatternRule(_ rule: Rule, url: URL) -> RouteAction? {
        let urlString = url.absoluteString.lowercased()
        
        // Contains matching
        if let contains = rule.urlContains?.lowercased() {
            if urlString.contains(contains) {
                return .openInBrowser(bundleId: rule.targetBrowserId, matchedRule: rule)
            }
        }
        
        // Regex matching (optional)
        if let regexPattern = rule.urlRegex {
            do {
                let regex = try compiledRegex(for: regexPattern)
                let range = NSRange(urlString.startIndex..., in: urlString)
                if regex.firstMatch(in: urlString, options: [], range: range) != nil {
                    return .openInBrowser(bundleId: rule.targetBrowserId, matchedRule: rule)
                }
            } catch {
                debugLog("⚠️ Invalid regex pattern: \(regexPattern)")
            }
        }
        
        return nil
    }
}
