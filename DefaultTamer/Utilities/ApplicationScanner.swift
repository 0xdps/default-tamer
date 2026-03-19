//
//  ApplicationScanner.swift
//  Default Tamer
//
//  Utility to scan and list installed applications on macOS
//

import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id: String // Bundle ID
    let name: String
    let bundleId: String
    let path: String
    let icon: NSImage?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

class ApplicationScanner {
    static let shared = ApplicationScanner()
    
    private var cachedApps: [InstalledApp]?
    
    private init() {
        observeAppInstallations()
    }
    
    /// Watches for newly launched apps that aren't in the cache, which indicates a fresh install.
    /// macOS doesn't expose explicit install/uninstall notifications; using app-launch as a proxy.
    private func observeAppInstallations() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               let bundleId = app.bundleIdentifier,
               let cached = self.cachedApps,
               !cached.contains(where: { $0.bundleId == bundleId }) {
                self.cachedApps = nil
                debugLog("🗑️ Application scanner cache invalidated (new app launched: \(bundleId))")
            }
        }
    }
    
    /// Get all installed applications on the system
    func getInstalledApplications() -> [InstalledApp] {
        // Return cached results if available
        if let cached = cachedApps {
            return cached
        }
        
        var apps: [InstalledApp] = []
        
        // Standard application directories
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices/Applications",
            FileManager.default.homeDirectoryForCurrentUser.path + "/Applications"
        ]
        
        for searchPath in searchPaths {
            if let enumerator = FileManager.default.enumerator(atPath: searchPath) {
                for case let file as String in enumerator {
                    if file.hasSuffix(".app") {
                        let fullPath = "\(searchPath)/\(file)"
                        if let app = getAppInfo(atPath: fullPath) {
                            apps.append(app)
                        }
                        // Don't descend into .app bundles
                        enumerator.skipDescendants()
                    }
                }
            }
        }
        
        // Sort by name
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Remove duplicates (prefer /Applications over others)
        var uniqueApps: [String: InstalledApp] = [:]
        for app in apps {
            if let existing = uniqueApps[app.bundleId] {
                // Prefer apps in /Applications
                if app.path.hasPrefix("/Applications/") && !existing.path.hasPrefix("/Applications/") {
                    uniqueApps[app.bundleId] = app
                }
            } else {
                uniqueApps[app.bundleId] = app
            }
        }
        
        let result = Array(uniqueApps.values).sorted { 
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending 
        }
        
        // Cache the results
        cachedApps = result
        
        return result
    }
    
    /// Get application info from a .app bundle path
    private func getAppInfo(atPath path: String) -> InstalledApp? {
        guard let bundle = Bundle(path: path) else { return nil }
        
        // Get bundle ID
        guard let bundleId = bundle.bundleIdentifier else { return nil }
        
        // Get app name (prefer CFBundleDisplayName, fall back to CFBundleName)
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        
        // Get icon
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        return InstalledApp(
            id: bundleId,
            name: name,
            bundleId: bundleId,
            path: path,
            icon: icon
        )
    }
    
    /// Clear the cache (useful if apps are installed/removed)
    func clearCache() {
        cachedApps = nil
    }
}
