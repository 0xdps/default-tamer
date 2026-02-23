//
//  DiagnosticsManager.swift
//  Default Tamer
//
//  Recent routes tracking for diagnostics
//

import Foundation

@MainActor
class DiagnosticsManager: ObservableObject {
    @Published var recentRoutes: [RouteLog] = []
    
    private let maxRoutes = DataConstants.maxRecentRoutes
    private let maxAge: TimeInterval = TimeConstants.maxLogAge // 24 hours
    private var cleanupTimer: Timer?
    
    init() {
        startCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Cleanup
    
    private func startCleanupTimer() {
        // Run cleanup every hour
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: TimeConstants.logCleanupInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.pruneOldLogs()
            }
        }
    }
    
    private func pruneOldLogs() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        let before = recentRoutes.count
        recentRoutes.removeAll { $0.timestamp < cutoff }
        let after = recentRoutes.count
        
        if before != after {
            UnifiedLogger.debug("Pruned \(before - after) old logs from memory", category: .performance)
        }
    }
    
    /// Logs a route event
    func logRoute(
        url: URL,
        sourceApp: String?,
        matchedRule: Rule?,
        targetBrowserId: String,
        targetBrowserName: String,
        fallbackUsed: Bool,
        isOverride: Bool = false
    ) {
        // Sanitize URL to remove sensitive parameters before storing
        let sanitizedURL = URLSanitizer.sanitize(url)
        let hasSensitiveData = URLSanitizer.containsSensitiveData(url)
        
        // Log warning if sensitive data detected
        if hasSensitiveData {
            UnifiedLogger.warning("URL contained sensitive parameters - sanitized before storage", category: .security)
        }
        
        let ruleType: String? = isOverride ? "Override" : matchedRule?.type.rawValue
        
        let log = RouteLog(
            url: sanitizedURL,
            urlHost: url.host ?? url.absoluteString,
            sourceApp: sourceApp,
            matchedRuleId: matchedRule?.id,
            matchedRuleType: ruleType,
            targetBrowserId: targetBrowserId,
            targetBrowserName: targetBrowserName,
            fallbackUsed: fallbackUsed,
            success: true
        )
        
        recentRoutes.insert(log, at: 0)
        
        // Keep only the most recent routes in memory
        if recentRoutes.count > maxRoutes {
            recentRoutes.removeLast()
        }
        
        // Also save to database
        ActivityDatabase.shared.logRoute(log)
    }
    
    /// Clears all route logs
    func clearLogs() {
        recentRoutes.removeAll()
    }
}
