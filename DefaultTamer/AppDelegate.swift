//
//  AppDelegate.swift
//  Default Tamer
//
//  AppKit delegate for menu bar integration and URL handling
//

import Cocoa
import Combine
import SwiftUI
import Sparkle

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    let appState = AppState() // Single shared instance
    /// Holds Sparkle's controller for the app's lifetime.
    let updateManager = UpdateManager()
    var firstRunWindow: NSWindow?
    var preferencesWindow: NSWindow?
    var chooserWindow: NSWindow?
    private var chooserCancellable: AnyCancellable?
    private var firstRunCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock and hide default window
        NSApp.setActivationPolicy(.accessory)

        // Close any default windows created by WindowGroup
        NSApplication.shared.windows.forEach { $0.close() }

        // Create menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        // Build menu with SwiftUI views hosted in NSMenuItem.view
        menu = NSMenu()
        menu.delegate = self

        // Header item (app info + toggle or warning)
        let isDefault = appState.browserManager.isDefaultBrowser()
        let headerItem = NSMenuItem()
        headerItem.view = makeHostingView(
            MenuHeaderView(isDefaultBrowser: isDefault)
                .environmentObject(appState)
                .environmentObject(LicensingManager.shared),
            width: UIConstants.menuBarPopoverWidth, height: isDefault ? 90 : 150)
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // Preferences
        let prefsItem = NSMenuItem()
        prefsItem.view = makeHostingView(
            MenuItemView(icon: "gearshape", title: "Preferences", action: { [weak self] in
                self?.openPreferences()
            }), width: UIConstants.menuBarPopoverWidth, height: 32)
        menu.addItem(prefsItem)

        // Manage Rules
        let rulesItem = NSMenuItem()
        rulesItem.view = makeHostingView(
            MenuItemView(icon: "list.bullet", title: "Manage Rules", action: { [weak self] in
                self?.openRules()
            }), width: UIConstants.menuBarPopoverWidth, height: 32)
        menu.addItem(rulesItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem()
        quitItem.view = makeHostingView(
            MenuItemView(icon: "power", title: "Quit Default Tamer", isDestructive: true, action: { [weak self] in
                self?.quitApp()
            }), width: UIConstants.menuBarPopoverWidth, height: 32)
        menu.addItem(quitItem)

        // Let macOS handle show/hide natively — no manual popover management needed
        statusItem.menu = menu
        statusItem.isVisible = true

        // Register for URL events
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        // Observe chooser state to present/dismiss chooser window
        chooserCancellable = appState.$showChooser
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                guard let self = self else { return }
                if show, let url = self.appState.chooserURL {
                    self.showChooserWindow(for: url)
                } else {
                    self.chooserWindow?.close()
                    self.chooserWindow = nil
                }
            }

        // Refresh bundle IDs for app-based rules (handles app updates like Cursor/Slack)
        let updatedCount = appState.refreshAppBundleIds()
        if updatedCount > 0 {
            appLogger.info("✅ Updated \(updatedCount) rule(s) with new bundle IDs")
        }

        // Disable rules whose target browser is no longer installed
        let disabledCount = appState.validateBrowserTargets()
        if disabledCount > 0 {
            let noun = disabledCount == 1 ? "rule" : "rules"
            ToastManager.shared.warning("\(disabledCount) \(noun) disabled — target browser not installed", duration: 6.0)
        }

        // Show first run if needed
        if appState.showFirstRun {
            DispatchQueue.main.async {
                self.showFirstRunWindow()
            }
        } else {
            // Existing users get the Day 0 consent prompt
            checkAndPromptTelemetryConsent()
        }

        // Validate stored license in the background (refreshes plan status from server)
        LicensingManager.shared.validateOnLaunch()

        // Re-validate when the app returns to the foreground (throttled in LicensingManager)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                LicensingManager.shared.validateOnForeground()
            }
        }

        // Track app launch & updates (AppState handles debouncing internal to these calls)
        appState.trackAppUpdated()
        appState.trackAppLaunch()
    }

    // MARK: - Helpers

    /// Existing user Day 0 Consent
    private func checkAndPromptTelemetryConsent() {
        if appState.settings.telemetryEnabled == nil {
            let alert = NSAlert()
            alert.messageText = "Help improve DefaultTamer"
            alert.informativeText = """
            Share anonymous usage stats to help improve the app.
            
            We never collect:
            • URLs or links
            • Browsing history
            • Personal information
            
            You can change this anytime in Settings.
            """
            alert.addButton(withTitle: "Share anonymous stats")
            alert.addButton(withTitle: "No, thanks")
            alert.alertStyle = .informational

            // Privacy Policy link as accessory view
            if let privacyURL = URL(string: ExternalLinks.privacy) {
                let linkField = NSTextField(labelWithString: "")
                linkField.isSelectable = true
                linkField.allowsEditingTextAttributes = true
                let attrTitle = NSMutableAttributedString(string: "Privacy Policy →")
                let fullRange = NSRange(location: 0, length: attrTitle.length)
                attrTitle.addAttribute(.link, value: privacyURL, range: fullRange)
                attrTitle.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), range: fullRange)
                linkField.attributedStringValue = attrTitle
                linkField.sizeToFit()
                alert.accessoryView = linkField
            }

            // Visual tweak: Slightly reduce icon size (~15%)
            if let originalIcon = NSImage(named: NSImage.applicationIconName),
               let iconCopy = originalIcon.copy() as? NSImage {
                iconCopy.size = NSSize(width: 54, height: 54)
                alert.icon = iconCopy
            }
            
            // Bring app to front
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            
            // NSAlertFirstButtonReturn (1000) corresponds to "Share"
            if response == .alertFirstButtonReturn {
                appState.setTelemetryEnabled(true)
            } else {
                appState.setTelemetryEnabled(false)
            }
        }
    }

    /// Wraps a SwiftUI view in an NSHostingView sized for an NSMenuItem.
    private func makeHostingView<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSHostingView<V> {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        return hosting
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Check default browser status each time the menu opens
        let isDefault = appState.browserManager.isDefaultBrowser()
        let headerHeight: CGFloat = isDefault ? 90 : 150

        if let headerItem = menu.items.first {
            headerItem.view = makeHostingView(
                MenuHeaderView(isDefaultBrowser: isDefault)
                    .environmentObject(appState)
                    .environmentObject(LicensingManager.shared),
                width: UIConstants.menuBarPopoverWidth, height: headerHeight)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        DebugLog.menu("📂 menuDidClose")
    }

    // MARK: - Actions

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }

    @objc func openPreferences() {
        appState.pendingTabSelection = .general
        showPreferencesWindow()
    }

    @objc func openRules() {
        appState.pendingTabSelection = .rules
        showPreferencesWindow()
    }

    private func showPreferencesWindow() {
        if let existingWindow = preferencesWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let prefsView = PreferencesWindow()
            .environmentObject(appState)
            .environmentObject(updateManager)
            .environmentObject(LicensingManager.shared)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Default Tamer Preferences"
        window.contentView = NSHostingView(rootView: prefsView)
        window.delegate = self
        window.isReleasedWhenClosed = false

        preferencesWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - URL Handling

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            appLogger.error("Invalid URL received")
            return
        }

        let diagnosticsEnabled = appState.settings.diagnosticsEnabled

        if diagnosticsEnabled {
            appLogger.info("📥 Received URL: \(url.absoluteString, privacy: .public)")
        }

        // Route `defaulttamer://auth` deep-links to LicensingManager (sign-in / code exchange)
        if url.scheme == "defaulttamer", url.host == "auth" {
            LicensingManager.shared.handleOAuthCallback(url)
            return
        }

        // Route `defaulttamer://upgraded` deep-links — direct checkout payment confirmed
        if url.scheme == "defaulttamer", url.host == "upgraded" {
            LicensingManager.shared.handleUpgradeCallback()
            return
        }

        // Use enhanced SourceAppDetector with Apple Event support
        let detectionResult = SourceAppDetector.shared.detectSourceAppWithConfidence(from: event)
        let sourceAppBundleId = detectionResult?.bundleId

        if diagnosticsEnabled {
            if let result = detectionResult {
                appLogger.info("🔍 Source app: \(result.bundleId) (\(result.appName ?? "Unknown"))")
                appLogger.info("   Method: \(result.method.rawValue)")
                appLogger.info("   Confidence: \(Int(result.confidence * 100))%")
            } else {
                appLogger.info("🔍 Source app: unknown")
            }
        }

        Task { @MainActor in
            appState.handleURL(url, sourceApp: sourceAppBundleId)
        }
    }

    // MARK: - Windows

    func showFirstRunWindow() {
        let firstRunView = FirstRunView()
            .environmentObject(appState)
            .toastOverlay(manager: appState.toastManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to Default Tamer"
        window.contentView = NSHostingView(rootView: firstRunView)
        window.delegate = self
        window.isReleasedWhenClosed = false

        self.firstRunWindow = window

        // When the user completes first run, close the window and open preferences.
        // All AppKit lifecycle management stays in AppDelegate — never call close()
        // from inside a SwiftUI view action.
        firstRunCancellable = appState.$showFirstRun
            .dropFirst()
            .filter { !$0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.firstRunWindow?.close()
                self.firstRunCancellable = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.openPreferences()
                }
            }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Browser Chooser

    private func showChooserWindow(for url: URL) {
        if let existingWindow = chooserWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let chooserView = BrowserChooser(url: url)
            .environmentObject(appState)
            .toastOverlay(manager: appState.toastManager)
        let hostingView = NSHostingView(rootView: chooserView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let window = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()

        chooserWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        let window = notification.object as? NSWindow

        if window === firstRunWindow {
            firstRunWindow = nil
        } else if window === preferencesWindow {
            preferencesWindow = nil
        } else if window === chooserWindow {
            chooserWindow = nil
            appState.showChooser = false
            appState.chooserURL = nil
            appState.chooserSourceApp = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
