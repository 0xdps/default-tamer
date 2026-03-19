//
//  AppResolver.swift
//  Default Tamer
//
//  Dynamic bundle ID resolution for applications
//

import Foundation
import AppKit

class AppResolver {
    
    // Cache for resolved bundle IDs
    private static var bundleIdCache: [String: String] = [:]
    
    /// Finds the bundle ID for an application by name
    /// - Parameter appName: The display name of the application (e.g., "Cursor")
    /// - Returns: Bundle ID if found, nil otherwise
    static func findBundleId(forAppNamed appName: String) -> String? {
        // Check cache first
        if let cachedBundleId = bundleIdCache[appName] {
            return cachedBundleId
        }
        
        // Try common app locations
        if let bundleId = findBundleIdInCommonLocations(appName: appName) {
            bundleIdCache[appName] = bundleId
            return bundleId
        }
        
        // Fall back to Spotlight search
        if let bundleId = findBundleIdUsingSpotlight(appName: appName) {
            bundleIdCache[appName] = bundleId
            return bundleId
        }
        
        return nil
    }
    
    /// Finds bundle ID by checking common application directories
    private static func findBundleIdInCommonLocations(appName: String) -> String? {
        let searchPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            NSHomeDirectory() + "/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app"
        ]
        
        for path in searchPaths {
            if let bundleId = getBundleIdFromPath(path) {
                debugLog("📍 Found \(appName) at \(path): \(bundleId)")
                return bundleId
            }
        }
        
        return nil
    }
    
    /// Gets bundle ID from an application path
    private static func getBundleIdFromPath(_ path: String) -> String? {
        guard let bundle = Bundle(path: path),
              let bundleId = bundle.bundleIdentifier else {
            return nil
        }
        return bundleId
    }
    
    /// Finds bundle ID using Spotlight (NSMetadataQuery)
    /// - Note: This is a synchronous search with timeout. Must NOT be called on the main thread.
    private static func findBundleIdUsingSpotlight(appName: String) -> String? {
        // The Spotlight notification fires on the main queue; waiting on main → deadlock.
        guard !Thread.isMainThread else {
            debugLog("⚠️ Skipping Spotlight lookup for '\(appName)' — called on main thread")
            return nil
        }
        
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "kMDItemKind == 'Application' AND kMDItemFSName == %@",
            "\(appName).app"
        )
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        
        var result: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { _ in
            defer {
                query.stop()
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
            
            if let item = query.results.first as? NSMetadataItem,
               let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
               let bundleId = getBundleIdFromPath(path) {
                result = bundleId
                debugLog("🔍 Found \(appName) via Spotlight: \(bundleId)")
            }
            
            semaphore.signal()
        }
        
        query.start()
        
        // Wait max 2 seconds for Spotlight
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        return result
    }
    
    /// Updates the bundle ID for a known app if it has changed
    /// Useful for apps like Cursor that may update their bundle ID
    static func refreshBundleId(forAppNamed appName: String) -> String? {
        // Clear cache for this app
        bundleIdCache.removeValue(forKey: appName)
        
        // Re-resolve
        return findBundleId(forAppNamed: appName)
    }
    
    /// Clears the entire bundle ID cache
    /// Call this when user wants to refresh all app detections
    static func clearCache() {
        bundleIdCache.removeAll()
        debugLog("🗑️ App resolver cache cleared")
    }
    
    /// Known bundle IDs for common apps (fallback)
    /// These are checked first before dynamic resolution
    static let knownBundleIds: [String: String] = [
        "Cursor": "com.todesktop.230313mzl4w4u92",
        "Slack": "com.tinyspeck.slackmacgap",
        "Discord": "com.hnc.Discord",
        "Linear": "com.linear",
        "Teams": "com.microsoft.teams2"
    ]
    
    /// Get bundle ID with fallback to known IDs
    static func resolveBundleId(forAppNamed appName: String) -> String? {
        // Try known IDs first (fast path)
        if let knownBundleId = knownBundleIds[appName] {
            // Verify it still exists
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: knownBundleId) != nil {
                return knownBundleId
            }
            // Known ID doesn't work anymore, fall through to dynamic resolution
        }
        
        // Dynamic resolution
        return findBundleId(forAppNamed: appName)
    }
}
