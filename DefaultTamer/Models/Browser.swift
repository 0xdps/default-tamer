//
//  Browser.swift
//  Default Tamer
//
//  Represents an installed browser application
//

import Foundation
import AppKit

struct Browser: Identifiable, Codable, Hashable {
    let id: String // Bundle identifier
    let displayName: String
    var isInstalled: Bool
    
    // Non-codable icon cache
    private var iconCache: NSImage?
    
    init(bundleId: String, displayName: String, isInstalled: Bool = true) {
        self.id = bundleId
        self.displayName = displayName
        self.isInstalled = isInstalled
        self.iconCache = nil
    }
    
    // MARK: - Icon Loading
    
    /// Get cached icon if available, otherwise returns nil
    func getCachedIcon() -> NSImage? {
        return iconCache
    }
    
    /// Synchronously load icon (use sparingly, prefer async loading)
    func getIcon() -> NSImage? {
        // Return cached if available
        if let cached = iconCache {
            return cached
        }
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            // Return default browser icon if app not found
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Browser")
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    /// Asynchronously load and cache icon
    @MainActor
    mutating func loadIcon() async -> NSImage? {
        // Return cached if available
        if let cached = iconCache {
            return cached
        }
        
        // Load icon on background thread
        let bundleId = self.id
        let icon = await Task.detached(priority: .utility) {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                // Return default browser icon if app not found
                return NSImage(systemSymbolName: "globe", accessibilityDescription: "Browser")
            }
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }.value
        
        // Cache the result
        iconCache = icon
        return icon
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, displayName, isInstalled
    }
}

