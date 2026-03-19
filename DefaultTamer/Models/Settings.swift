//
//  Settings.swift
//  Default Tamer
//
//  App settings model
//

import Foundation
import AppKit

struct Settings: Codable {
    var enabled: Bool
    var fallbackBrowserId: String
    var chooserModifierKey: String // "option" by default
    var diagnosticsEnabled: Bool
    var launchAtLogin: Bool
    var telemetryEnabled: Bool? // nil = not asked, true = opt-in, false = opt-out
    var hasCreatedFirstRule: Bool
    
    init(
        enabled: Bool = true,
        fallbackBrowserId: String = BundleIdentifiers.safari,
        chooserModifierKey: String = "option",
        diagnosticsEnabled: Bool = false,
        launchAtLogin: Bool = false,
        telemetryEnabled: Bool? = nil,
        hasCreatedFirstRule: Bool = false
    ) {
        self.enabled = enabled
        self.fallbackBrowserId = fallbackBrowserId
        self.chooserModifierKey = chooserModifierKey
        self.diagnosticsEnabled = diagnosticsEnabled
        self.launchAtLogin = launchAtLogin
        self.telemetryEnabled = telemetryEnabled
        self.hasCreatedFirstRule = hasCreatedFirstRule
    }

    static let `default` = Settings()
}

// MARK: - Modifier Key Helpers

extension Settings {
    /// Maps the stored `chooserModifierKey` string to the corresponding
    /// `NSEvent.ModifierFlags` value used by the router.
    var chooserModifierFlags: NSEvent.ModifierFlags {
        switch chooserModifierKey.lowercased() {
        case "command":  return .command
        case "shift":    return .shift
        case "control":  return .control
        case "option":   return .option
        default:         return .option
        }
    }
}
