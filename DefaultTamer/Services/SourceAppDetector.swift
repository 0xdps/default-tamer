//
//  SourceAppDetector.swift
//  Default Tamer
//
//  Multi-stage source application detection with confidence scoring
//

import Foundation
import AppKit

// MARK: - Detection Result

struct AppDetectionResult {
    let bundleId: String
    let appName: String?
    let confidence: Double
    let method: DetectionMethod
    
    enum DetectionMethod: String {
        case appleEvent = "Apple Event"
        case appleEventPID = "Apple Event (PID)"
        case activeApp = "Active Application"
        case menuBarOwner = "Menu Bar Owner"
        case recentSwitch = "Recent App Switch"
        case runningApps = "Running Applications"

        var confidence: Double {
            switch self {
            case .appleEvent: return 0.95
            case .appleEventPID: return 0.90
            case .activeApp: return 0.85
            case .menuBarOwner: return 0.75
            case .recentSwitch: return 0.65
            case .runningApps: return 0.50
            }
        }
    }
}

// MARK: - Source App Detector

class SourceAppDetector {
    
    // Singleton for tracking app switches
    static let shared = SourceAppDetector()
    
    // Recent app switches cache (last 10)
    private var recentAppSwitches: [(bundleId: String, timestamp: Date)] = []
    private let maxCacheSize = 10
    private let recentSwitchTimeWindow: TimeInterval = 2.0 // 2 seconds
    
    private init() {
        setupAppSwitchTracking()
    }
    
    // MARK: - Public API
    
    /// Attempts to detect the source application that initiated the URL open
    /// Returns bundle ID if detected, nil otherwise (legacy interface)
    static func detectSourceApp() -> String? {
        return shared.detectSourceAppWithConfidence()?.bundleId
    }
    
    /// Detects source app with confidence scoring from Apple Event
    /// Returns the best match based on multiple detection methods
    /// - Parameter event: Optional Apple Event descriptor for URL handling
    func detectSourceAppWithConfidence(from event: NSAppleEventDescriptor? = nil) -> AppDetectionResult? {
        // Method 0: Apple Event sender - Highest confidence (if available)
        // If we get a reliable Apple Event result (≥90%), use it immediately without
        // running the remaining (more expensive) detection heuristics.
        if let event = event, let result = detectFromAppleEvent(event) {
            if result.confidence >= 0.90 {
                debugLog("🔍 Detected source app (fast path): \(result.bundleId) via \(result.method.rawValue) (\(Int(result.confidence * 100))%)")
                return result
            }
        }

        var candidates: [AppDetectionResult] = []

        // Method 1: Active (frontmost) application - Most reliable
        if let result = detectActiveApp() {
            candidates.append(result)
        }

        // Method 2: Menu bar owner - Good fallback
        if let result = detectMenuBarOwner() {
            candidates.append(result)
        }

        // Method 3: Recent app switches - Useful for quick transitions
        if let result = detectFromRecentSwitches() {
            candidates.append(result)
        }

        // Method 4: Running applications scan - Last resort
        if let result = detectFromRunningApps() {
            candidates.append(result)
        }

        // Select best candidate by confidence
        let bestMatch = candidates.max(by: { $0.confidence < $1.confidence })

        // Log detection result
        if let match = bestMatch {
            debugLog("🔍 Detected source app: \(match.bundleId) (\(match.appName ?? "Unknown")) " +
                    "via \(match.method.rawValue) (confidence: \(Int(match.confidence * 100))%)")
        } else {
            debugLog("🔍 Could not detect source app")
        }

        return bestMatch
    }

    /// Legacy method for backwards compatibility
    func detectSourceAppWithConfidence() -> AppDetectionResult? {
        return detectSourceAppWithConfidence(from: nil)
    }
    
    // MARK: - Detection Methods

    /// Detects source app from Apple Event descriptor (highest confidence)
    private func detectFromAppleEvent(_ event: NSAppleEventDescriptor) -> AppDetectionResult? {
        guard let senderDescriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)) else {
            return nil
        }

        // Method 1: Try to get bundle ID directly (95% confidence)
        if let bundleIdDesc = senderDescriptor.coerce(toDescriptorType: typeApplicationBundleID),
           let bundleId = bundleIdDesc.stringValue,
           bundleId != Bundle.main.bundleIdentifier {

            let appName = Self.getAppName(for: bundleId)
            return AppDetectionResult(
                bundleId: bundleId,
                appName: appName,
                confidence: AppDetectionResult.DetectionMethod.appleEvent.confidence,
                method: .appleEvent
            )
        }

        // Method 2: Try to get via PID (90% confidence)
        if let pidDesc = senderDescriptor.coerce(toDescriptorType: typeKernelProcessID) {
            let pidData = pidDesc.data
            let pid = pidData.withUnsafeBytes { $0.load(as: pid_t.self) }

            if let app = NSRunningApplication(processIdentifier: pid),
               let bundleId = app.bundleIdentifier,
               bundleId != Bundle.main.bundleIdentifier {

                return AppDetectionResult(
                    bundleId: bundleId,
                    appName: app.localizedName,
                    confidence: AppDetectionResult.DetectionMethod.appleEventPID.confidence,
                    method: .appleEventPID
                )
            }
        }

        return nil
    }

    private func detectActiveApp() -> AppDetectionResult? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            return nil
        }
        
        // Exclude DefaultTamer itself
        if bundleId == Bundle.main.bundleIdentifier {
            return nil
        }
        
        return AppDetectionResult(
            bundleId: bundleId,
            appName: frontmostApp.localizedName,
            confidence: AppDetectionResult.DetectionMethod.activeApp.confidence,
            method: .activeApp
        )
    }
    
    private func detectMenuBarOwner() -> AppDetectionResult? {
        // Find app that owns the menu bar (not necessarily frontmost)
        let runningApps = NSWorkspace.shared.runningApplications
        
        guard let menuBarOwner = runningApps.first(where: { $0.ownsMenuBar }),
              let bundleId = menuBarOwner.bundleIdentifier else {
            return nil
        }
        
        // Exclude DefaultTamer itself
        if bundleId == Bundle.main.bundleIdentifier {
            return nil
        }
        
        return AppDetectionResult(
            bundleId: bundleId,
            appName: menuBarOwner.localizedName,
            confidence: AppDetectionResult.DetectionMethod.menuBarOwner.confidence,
            method: .menuBarOwner
        )
    }
    
    private func detectFromRecentSwitches() -> AppDetectionResult? {
        // Check recent app switches within time window
        let now = Date()
        
        guard let recentSwitch = recentAppSwitches.first(where: {
            now.timeIntervalSince($0.timestamp) < recentSwitchTimeWindow
        }) else {
            return nil
        }
        
        // Get app name if possible
        let appName = Self.getAppName(for: recentSwitch.bundleId)
        
        return AppDetectionResult(
            bundleId: recentSwitch.bundleId,
            appName: appName,
            confidence: AppDetectionResult.DetectionMethod.recentSwitch.confidence,
            method: .recentSwitch
        )
    }
    
    private func detectFromRunningApps() -> AppDetectionResult? {
        // Scan running apps and pick most likely candidate
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { app in
                guard let bundleId = app.bundleIdentifier else { return false }
                // Exclude system apps and DefaultTamer
                return bundleId != Bundle.main.bundleIdentifier &&
                       !bundleId.hasPrefix("com.apple.") &&
                       app.activationPolicy == .regular
            }
        
        // Prefer active apps
        guard let candidateApp = runningApps.first(where: { $0.isActive }) ?? runningApps.first,
              let bundleId = candidateApp.bundleIdentifier else {
            return nil
        }
        
        return AppDetectionResult(
            bundleId: bundleId,
            appName: candidateApp.localizedName,
            confidence: AppDetectionResult.DetectionMethod.runningApps.confidence,
            method: .runningApps
        )
    }
    
    // MARK: - App Switch Tracking
    
    private func setupAppSwitchTracking() {
        // Track when apps become active
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier,
                  bundleId != Bundle.main.bundleIdentifier else {
                return
            }
            
            // Add to cache
            self.trackAppSwitch(bundleId: bundleId)
        }
    }
    
    private func trackAppSwitch(bundleId: String) {
        // Remove existing entry if present
        recentAppSwitches.removeAll { $0.bundleId == bundleId }
        
        // Add to front
        recentAppSwitches.insert((bundleId, Date()), at: 0)
        
        // Trim to max size
        if recentAppSwitches.count > maxCacheSize {
            recentAppSwitches = Array(recentAppSwitches.prefix(maxCacheSize))
        }
    }
    
    // MARK: - Static Helpers
    
    /// Known app bundle IDs for reference
    static let knownApps: [String: String] = [
        "com.tinyspeck.slackmacgap": "Slack",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "com.apple.mail": "Mail",
        "com.apple.iCal": "Calendar",
        "com.apple.Notes": "Notes",
        "com.hnc.Discord": "Discord",
        "com.microsoft.teams2": "Microsoft Teams",
        "com.linear": "Linear"
    ]
    
    /// Get display name for a bundle ID
    static func displayName(for bundleId: String) -> String {
        return knownApps[bundleId] ?? bundleId
    }
    
    /// Get the actual app name from bundle ID (queries system)
    static func getAppName(for bundleId: String) -> String? {
        // First check known apps
        if let knownName = knownApps[bundleId] {
            return knownName
        }
        
        // Try to get from NSWorkspace
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let appName = FileManager.default.displayName(atPath: appURL.path)
            // Remove .app extension if present
            if appName.hasSuffix(".app") {
                return String(appName.dropLast(4))
            }
            return appName
        }
        
        return nil
    }
}
