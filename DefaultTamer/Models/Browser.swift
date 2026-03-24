//
//  Browser.swift
//  Default Tamer
//
//  Represents an installed browser application
//

import Foundation
import AppKit

// MARK: - Launch Strategy

/// Describes how a browser should be launched to open a URL.
/// All browser-family-specific logic is captured here — adding a new browser
/// only requires assigning it a strategy, not adding new open paths.
enum LaunchStrategy {
    /// Platform-native only (Safari, Arc).
    /// Uses NSWorkspace.open([url]). No useful CLI flags available.
    case workspace

    /// Chromium-family (Chrome, Edge, Brave, Opera, Vivaldi, and unknown forks).
    /// Launched via: `open -na <App> --args [--profile-directory=X] [privateFlag] <url>`
    case chromium(privateFlag: String)

    /// Gecko-family (Firefox, LibreWolf, Waterfox).
    /// Invokes the binary directly: `<binary> [privateFlag] <url>`
    case gecko(privateFlag: String)
}

// MARK: - Browser Model

struct Browser: Identifiable, Codable, Hashable {
    let id: String // Bundle identifier, or "bundleId::profileDir" for profile browsers
    let displayName: String
    var isInstalled: Bool
    var profileDirectory: String? // Non-nil for profile-based browsers (e.g. Chrome profiles)

    /// Separator used between bundle ID and profile directory in profile browser IDs.
    static let profileSeparator = "::"

    /// The base bundle identifier, stripping any profile suffix.
    var baseBundleId: String {
        id.components(separatedBy: Self.profileSeparator).first ?? id
    }

    // Non-codable icon cache
    private var iconCache: NSImage?

    init(bundleId: String, displayName: String, isInstalled: Bool = true, profileDirectory: String? = nil) {
        if let dir = profileDirectory {
            self.id = "\(bundleId)\(Self.profileSeparator)\(dir)"
        } else {
            self.id = bundleId
        }
        self.displayName = displayName
        self.isInstalled = isInstalled
        self.profileDirectory = profileDirectory
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
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: baseBundleId) else {
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
        let bundleId = self.baseBundleId
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
        case id, displayName, isInstalled, profileDirectory
    }

    // MARK: - Launch Strategy

    /// The launch strategy for this browser, derived from its base bundle ID.
    /// Governs how URLs (and private-mode URLs) are opened — no switch needed at call sites.
    var launchStrategy: LaunchStrategy {
        switch baseBundleId {
        case BundleIdentifiers.safari, BundleIdentifiers.arc:
            return .workspace
        case BundleIdentifiers.firefox:
            return .gecko(privateFlag: "-private-window")
        case BundleIdentifiers.edge:
            return .chromium(privateFlag: "-inprivate")
        case BundleIdentifiers.opera:
            return .chromium(privateFlag: "--private")
        default:
            // Chrome, Brave, Vivaldi, and all unknown Chromium forks
            return .chromium(privateFlag: "--incognito")
        }
    }
}

