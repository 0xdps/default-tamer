//
//  Settings.swift
//  Default Tamer
//
//  App settings model
//

import Foundation

struct Settings: Codable {
    var enabled: Bool
    var fallbackBrowserId: String
    var chooserModifierKey: String // "option" by default
    var diagnosticsEnabled: Bool
    var launchAtLogin: Bool
    init(
        enabled: Bool = true,
        fallbackBrowserId: String = BundleIdentifiers.safari,
        chooserModifierKey: String = "option",
        diagnosticsEnabled: Bool = false,
        launchAtLogin: Bool = false
    ) {
        self.enabled = enabled
        self.fallbackBrowserId = fallbackBrowserId
        self.chooserModifierKey = chooserModifierKey
        self.diagnosticsEnabled = diagnosticsEnabled
        self.launchAtLogin = launchAtLogin
    }

    static let `default` = Settings()
}
