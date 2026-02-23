//
//  RouteLog.swift
//  Default Tamer
//
//  Activity log entry for route tracking
//

import Foundation

struct RouteLog: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let url: String              // Full URL
    let urlHost: String           // Domain for display
    let sourceApp: String?        // App that triggered the URL
    let matchedRuleId: UUID?      // Rule that matched (if any)
    let matchedRuleType: String?  // Type of rule: domain/prefix/contains/regex
    let targetBrowserId: String   // Browser that opened the URL
    let targetBrowserName: String // Browser display name (for display)
    let fallbackUsed: Bool        // True if fallback browser was used
    let success: Bool             // Whether the URL opened successfully
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        url: String,
        urlHost: String,
        sourceApp: String?,
        matchedRuleId: UUID?,
        matchedRuleType: String?,
        targetBrowserId: String,
        targetBrowserName: String,
        fallbackUsed: Bool,
        success: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.urlHost = urlHost
        self.sourceApp = sourceApp
        self.matchedRuleId = matchedRuleId
        self.matchedRuleType = matchedRuleType
        self.targetBrowserId = targetBrowserId
        self.targetBrowserName = targetBrowserName
        self.fallbackUsed = fallbackUsed
        self.success = success
    }
    
    func relativeTime() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}
