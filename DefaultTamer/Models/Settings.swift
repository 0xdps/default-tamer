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
    var showRoutingFeedback: Bool // Show toast notifications for routing decisions

    init(
        enabled: Bool = true,
        fallbackBrowserId: String = BundleIdentifiers.safari,
        chooserModifierKey: String = "option",
        diagnosticsEnabled: Bool = false,
        launchAtLogin: Bool = false,
        showRoutingFeedback: Bool = true
    ) {
        self.enabled = enabled
        self.fallbackBrowserId = fallbackBrowserId
        self.chooserModifierKey = chooserModifierKey
        self.diagnosticsEnabled = diagnosticsEnabled
        self.launchAtLogin = launchAtLogin
        self.showRoutingFeedback = showRoutingFeedback
    }

    static let `default` = Settings()
}
