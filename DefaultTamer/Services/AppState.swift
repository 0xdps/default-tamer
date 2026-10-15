//
//  AppState.swift
//  Default Tamer
//
//  Central app state management
//

import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
class AppState: ObservableObject {
    // Managers
    let browserManager = BrowserManager()
    let diagnosticsManager = DiagnosticsManager()
    let persistence = PersistenceManager.shared
    let toastManager = ToastManager.shared

    // Published state
    @Published var settings: Settings
    @Published private(set) var rules: [Rule]
    @Published var showFirstRun: Bool
    @Published var showRulesWindow = false
    @Published var showChooser = false
    @Published var chooserURL: URL?
    @Published var chooserSourceApp: String?
    @Published var pendingTabSelection: PreferenceTab? = nil // For coordinating tab selection from menu bar

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.settings = persistence.loadSettings()
        self.rules = persistence.loadRules()
        self.showFirstRun = !persistence.hasCompletedFirstRun
        _ = persistence.installID // Eagerly guarantee UUID is generated locally

        // Forward child ObservableObject changes into AppState so that any view
        // observing appState re-renders when browserManager or diagnosticsManager
        // publish changes (e.g. availableBrowsers, isRefreshingBrowsers).
        browserManager.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        diagnosticsManager.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
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
        // Purge all tracked data when the user disables activity logging.
        // Data should not silently persist in a state the user can't see or clear.
        if !settings.diagnosticsEnabled {
            diagnosticsManager.clearLogs()
            ActivityDatabase.shared.deleteAllLogs()
        }
    }

    // MARK: - Telemetry
    
    func setTelemetryEnabled(_ enabled: Bool) {
        let wasNil = settings.telemetryEnabled == nil
        settings.telemetryEnabled = enabled
        persistence.saveSettings(settings)
        
        // If enabling for the first time, fire launch event
        if wasNil && enabled {
            trackAppLaunch(force: true)
        }
    }
    
    func trackAppLaunch(force: Bool = false) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let shouldFire: Bool
        if force {
            shouldFire = true
        } else if let lastLaunch = persistence.lastLaunchDate {
            shouldFire = calendar.startOfDay(for: lastLaunch) < today
        } else {
            shouldFire = true
        }
        
        if shouldFire {
            let bucket = AnalyticsManager.getBucket(for: rules.count)
            let isDefault = browserManager.isDefaultBrowser()
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            
            AnalyticsManager.shared.sendEvent(name: "app_launch", data: [
                "version": version,
                "os": osVersion,
                "rule_count_bucket": bucket,
                "is_default": isDefault
            ])
            persistence.lastLaunchDate = Date()
        }
    }
    
    func trackAppUpdated() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        guard let lastVersion = persistence.lastKnownVersion else {
            persistence.lastKnownVersion = currentVersion
            return
        }
        
        if currentVersion != lastVersion {
            // Only fire if telemetry is enabled and they were already on >= 0.0.7
            if settings.telemetryEnabled == true {
                AnalyticsManager.shared.sendEvent(name: "app_updated", data: [
                    "from_version": lastVersion,
                    "to_version": currentVersion
                ])
            }
            persistence.lastKnownVersion = currentVersion
        }
    }
    
    func trackRuleCreated(type: String = "unknown") {
        AnalyticsManager.shared.sendEvent(name: "rule_created", data: ["type": type])
        
        if !settings.hasCreatedFirstRule {
            AnalyticsManager.shared.sendEvent(name: "first_rule_created") { [weak self] success in
                if success {
                    Task { @MainActor in
                        self?.settings.hasCreatedFirstRule = true
                        self?.persistence.saveSettings(self?.settings ?? Settings())
                    }
                }
            }
        }
    }
    
    func trackRuleDeleted(type: String = "unknown") {
        AnalyticsManager.shared.sendEvent(name: "rule_deleted", data: ["type": type])
    }
    
    func trackLinkRouted(method: String) {
        AnalyticsManager.shared.sendEvent(name: "link_routed", data: ["method": method])
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
        rules.append(rule)
        persistence.saveRules(rules)
        trackRuleCreated(type: rule.type.rawValue)
    }

    func updateRule(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            persistence.saveRules(rules)
        }
    }

    func deleteRule(_ rule: Rule) {
        rules.removeAll(where: { $0.id == rule.id })
        persistence.saveRules(rules)
        trackRuleDeleted(type: rule.type.rawValue)
    }

    func toggleRule(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].enabled.toggle()
            persistence.saveRules(rules)
        }
    }

    func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        persistence.saveRules(rules)
    }

    func replaceRules(_ newRules: [Rule]) {
        rules = newRules
        persistence.saveRules(rules)
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

    /// Checks every enabled rule's target browser against the installed browsers list.
    /// Disables any rule whose target browser is no longer installed.
    /// Returns the number of rules that were disabled.
    @discardableResult
    func validateBrowserTargets() -> Int {
        var disabledCount = 0

        for index in rules.indices {
            guard rules[index].enabled else { continue }
            let browserId = rules[index].targetBrowserId
            if !browserManager.isBrowserAvailable(browserId) {
                rules[index].enabled = false
                disabledCount += 1
                appLogger.warning("⚠️ Disabled rule — target browser '\(browserId)' not found")
            }
        }

        if disabledCount > 0 {
            persistence.saveRules(rules)
        }

        return disabledCount
    }

    // MARK: - URL Handling
    
    func handleURL(_ url: URL, sourceApp: String? = nil, modifierFlags: NSEvent.ModifierFlags? = nil) {
        if url.isBrowserOpenableFile {
            appLogger.info("Local browser-openable file received, using fallback: \(url.lastPathComponent, privacy: .public)")
            executeRouteAction(.openInFallback, url: url, sourceApp: sourceApp)
            return
        }

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
        
        // Use the caller-supplied snapshot (captured at Apple Event arrival time) so we
        // always see the modifier keys that were held at the moment the link was clicked,
        // even if processing is slightly delayed by async dispatch.
        let currentFlags = modifierFlags ?? NSEvent.modifierFlags

        // Strip shortcut rules when the feature isn't licensed so they can never
        // fire at the routing layer, regardless of UI state.
        let effectiveRules = LicensingManager.shared.isEnabled(.shortcutRules)
            ? rules
            : rules.filter { $0.type != .shortcut }

        // Route the URL
        let action = Router.route(
            url: url,
            sourceApp: detectedSourceApp,
            settings: settings,
            rules: effectiveRules,
            modifierFlags: currentFlags
        )
        
        // Execute action
        executeRouteAction(action, url: url, sourceApp: detectedSourceApp)
    }
    
    private func executeRouteAction(_ action: RouteAction, url: URL, sourceApp: String?) {
        let browserName: String

        switch action {
        case .openInBrowser(let bundleId, let matchedRule):
            let privateMode = matchedRule?.openInPrivateMode ?? false

            if matchedRule?.type == .shortcut {
                // Modifier keys are still physically held at this point (they triggered the
                // shortcut match). Wait for actual key release before opening the browser —
                // a fixed delay is not reliable if the user holds the keys longer.
                let rawMods = matchedRule?.shortcutModifiers ?? 0
                let triggerFlags = NSEvent.ModifierFlags(rawValue: UInt(rawMods))
                    .intersection([.command, .option, .shift, .control])
                let fallbackId = settings.fallbackBrowserId
                waitForShortcutRelease(shortcutMods: triggerFlags) { [weak self] in
                    self?.browserManager.openURLWithFallback(url, targetBrowserId: bundleId, fallbackBrowserId: fallbackId, privateMode: privateMode)
                }
            } else {
                browserManager.openURLWithFallback(url, targetBrowserId: bundleId, fallbackBrowserId: settings.fallbackBrowserId, privateMode: privateMode)
            }
            browserName = browserManager.availableBrowsers.first(where: { $0.id == bundleId })?.displayName ?? "Unknown"

            trackLinkRouted(method: "rule")

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

            AnalyticsManager.shared.sendEvent(name: "chooser_shown")

        case .openInFallback:
            browserManager.openURL(url, inBrowser: settings.fallbackBrowserId)
            browserName = browserManager.availableBrowsers.first(where: { $0.id == settings.fallbackBrowserId })?.displayName ?? "Unknown"

            trackLinkRouted(method: "fallback")

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

    /// Calls `action` as soon as the shortcut’s trigger modifier keys are released.
    /// Uses a global NSEvent monitor so it works while Default Tamer is a background app.
    /// Falls back after 2 seconds in case the key-up event is missed.
    private func waitForShortcutRelease(shortcutMods: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        let relevant: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        let current = NSEvent.modifierFlags.intersection(relevant)

        // Keys are already released — dispatch on next runloop to keep call-stack clean.
        if !current.isSuperset(of: shortcutMods) {
            DispatchQueue.main.async { action() }
            return
        }

        var monitor: Any?
        var fired = false

        let fire = {
            guard !fired else { return }
            fired = true
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            DispatchQueue.main.async { action() }
        }

        // Guarantee: fire no later than 2 seconds from now.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { fire() }

        // Listen for actual modifier key release.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            let held = event.modifierFlags.intersection(relevant)
            if !held.isSuperset(of: shortcutMods) {
                fire()
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

        trackLinkRouted(method: "chooser")

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
