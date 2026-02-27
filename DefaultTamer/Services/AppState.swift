//
//  AppState.swift
//  Default Tamer
//
//  Central app state management
//

import Foundation
import SwiftUI
import AppKit

@MainActor
class AppState: ObservableObject {
    // Managers
    let browserManager = BrowserManager()
    let diagnosticsManager = DiagnosticsManager()
    let persistence = PersistenceManager.shared
    let toastManager = ToastManager.shared
    
    // Thread-safe rules queue
    private let rulesQueue = DispatchQueue(label: "com.defaulttamer.rules", attributes: .concurrent)
    
    // Published state
    @Published var settings: Settings
    @Published private(set) var rules: [Rule]
    @Published var showFirstRun: Bool
    @Published var showRulesWindow = false
    @Published var showChooser = false
    @Published var chooserURL: URL?
    @Published var chooserSourceApp: String?
    @Published var pendingTabSelection: Int? = nil // For coordinating tab selection from menu bar
    
    init() {
        self.settings = persistence.loadSettings()
        self.rules = persistence.loadRules()
        self.showFirstRun = !persistence.hasCompletedFirstRun
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: Settings) {
        settings = newSettings
        persistence.saveSettings(settings)
    }
    
    func toggleEnabled() {
        settings.enabled.toggle()
        persistence.saveSettings(settings)
    }
    
    func setFallbackBrowser(_ browserId: String) {
        settings.fallbackBrowserId = browserId
        persistence.saveSettings(settings)
    }
    
    func toggleDiagnostics() {
        settings.diagnosticsEnabled.toggle()
        persistence.saveSettings(settings)
    }



    // MARK: - Reset

    func resetToDefaults() {
        persistence.resetToDefaults()
        settings = Settings.default
        rules = []
        showFirstRun = true
        toastManager.success("Reset to factory defaults")
    }

    // MARK: - Rules Management
    
    func addRule(_ rule: Rule) {
        rulesQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.rules.append(rule)
                self.persistence.saveRules(self.rules)
            }
        }
    }
    
    func updateRule(_ rule: Rule) {
        rulesQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if let index = self.rules.firstIndex(where: { $0.id == rule.id }) {
                    self.rules[index] = rule
                    self.persistence.saveRules(self.rules)
                }
            }
        }
    }
    
    func deleteRule(_ rule: Rule) {
        rulesQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.rules.removeAll(where: { $0.id == rule.id })
                self.persistence.saveRules(self.rules)
            }
        }
    }
    
    func toggleRule(_ rule: Rule) {
        rulesQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if let index = self.rules.firstIndex(where: { $0.id == rule.id }) {
                    self.rules[index].enabled.toggle()
                    self.persistence.saveRules(self.rules)
                }
            }
        }
    }
    
    func moveRule(from source: IndexSet, to destination: Int) {
        rulesQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.rules.move(fromOffsets: source, toOffset: destination)
                self.persistence.saveRules(self.rules)
            }
        }
    }
    
    func replaceRules(_ newRules: [Rule]) {
        rulesQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.rules = newRules
                self.persistence.saveRules(self.rules)
            }
        }
    }

    /// Refreshes bundle IDs for all app-based rules
    /// Useful when apps like Cursor update and change their bundle IDs
    /// Returns the number of rules that were updated
    @discardableResult
    func refreshAppBundleIds() -> Int {
        var updatedCount = 0

        for index in rules.indices {
            if rules[index].refreshBundleId() {
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            persistence.saveRules(rules)
            appLogger.info("🔄 Refreshed bundle IDs for \(updatedCount) rule(s)")
        }

        return updatedCount
    }

    // MARK: - URL Handling
    
    func handleURL(_ url: URL, sourceApp: String? = nil) {
        guard url.isHTTP else {
            appLogger.error("Non-HTTP URL received: \(url.absoluteString)")
            return
        }
        
        // Use provided source app or try to detect it
        let detectedSourceApp = sourceApp ?? SourceAppDetector.detectSourceApp()
        
        if let app = detectedSourceApp {
            appLogger.info("🔍 Using source app: \(app, privacy: .public)")
        } else {
            appLogger.info("🔍 No source app available")
        }
        
        // Get current modifier flags
        let modifierFlags = NSEvent.modifierFlags
        
        // Route the URL
        let action = Router.route(
            url: url,
            sourceApp: detectedSourceApp,
            settings: settings,
            rules: rules,
            modifierFlags: modifierFlags
        )
        
        // Execute action
        executeRouteAction(action, url: url, sourceApp: detectedSourceApp)
    }
    
    private func executeRouteAction(_ action: RouteAction, url: URL, sourceApp: String?) {
        let browserName: String

        switch action {
        case .openInBrowser(let bundleId, let matchedRule):
            let privateMode = matchedRule?.openInPrivateMode ?? false
            browserManager.openURLWithFallback(url, targetBrowserId: bundleId, fallbackBrowserId: settings.fallbackBrowserId, privateMode: privateMode)
            browserName = browserManager.availableBrowsers.first(where: { $0.id == bundleId })?.displayName ?? "Unknown"



            // Log if diagnostics enabled
            if settings.diagnosticsEnabled {
                diagnosticsManager.logRoute(
                    url: url,
                    sourceApp: sourceApp,
                    matchedRule: matchedRule,
                    targetBrowserId: bundleId,
                    targetBrowserName: browserName,
                    fallbackUsed: false
                )
            }

        case .showChooser(let url):
            chooserURL = url
            chooserSourceApp = sourceApp
            showChooser = true



        case .openInFallback:
            browserManager.openURL(url, inBrowser: settings.fallbackBrowserId)
            browserName = browserManager.availableBrowsers.first(where: { $0.id == settings.fallbackBrowserId })?.displayName ?? "Unknown"



            // Log if diagnostics enabled
            if settings.diagnosticsEnabled {
                diagnosticsManager.logRoute(
                    url: url,
                    sourceApp: sourceApp,
                    matchedRule: nil,
                    targetBrowserId: settings.fallbackBrowserId,
                    targetBrowserName: browserName,
                    fallbackUsed: true
                )
            }
        }
    }
    
    func openURLFromChooser(_ url: URL, browserId: String) {
        let sourceApp = chooserSourceApp
        let browserName = browserManager.availableBrowsers.first(where: { $0.id == browserId })?.displayName ?? "Unknown"

        browserManager.openURL(url, inBrowser: browserId)
        showChooser = false
        chooserURL = nil
        chooserSourceApp = nil



        // Log if diagnostics enabled
        if settings.diagnosticsEnabled {
            diagnosticsManager.logRoute(
                url: url,
                sourceApp: sourceApp,
                matchedRule: nil,
                targetBrowserId: browserId,
                targetBrowserName: browserName,
                fallbackUsed: false,
                isOverride: true
            )
        }
    }
    
    // MARK: - First Run
    
    func completeFirstRun() {
        showFirstRun = false
        persistence.hasCompletedFirstRun = true
    }
    
    // MARK: - Launch at Login
    
    func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.shared.toggle()
            settings.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
            persistence.saveSettings(settings)
        } catch {
            debugLog("❌ Failed to toggle launch at login: \(error)")
            ErrorNotifier.shared.notifyError(
                "Settings Error",
                message: "Failed to update launch at login setting."
            )
        }
    }
}
