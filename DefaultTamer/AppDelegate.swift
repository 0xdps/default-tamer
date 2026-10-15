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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register Apple Event handlers here — this is the earliest point where
        // NSAppleEventManager is ready, and it fires before any queued events
        // (including kAEOpenDocuments from Finder) are dispatched.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentsEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

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
        buildMenu()

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
        // Note: kAEOpenDocuments is registered in init() for earlier delivery.

        // Ensure Default Tamer is the LaunchServices handler for HTML documents
        // so Finder double-clicks route through kAEOpenDocuments to us.
        appState.browserManager.claimHTMLDocumentHandlerIfNeeded()

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

        // Check for active promo codes (throttled to once per 24 h)
        PromoManager.shared.checkIfNeeded()

        // Re-validate when the app returns to the foreground (throttled in LicensingManager)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                LicensingManager.shared.validateOnForeground()
                PromoManager.shared.checkIfNeeded()
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
            alert.messageText = "Help improve Default Tamer"
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

    /// Rebuilds the entire menu from scratch. Called at launch and each time the
    /// menu opens, so the "Upgrade to Power Plan" item reflects the live license state.
    private func buildMenu() {
        menu.removeAllItems()

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

        // Upgrade to Power Plan — only shown when the user doesn't have Power.
        if !LicensingManager.shared.hasPowerPlan {
            let upgradeItem = NSMenuItem()
            upgradeItem.view = makeHostingView(
                MenuItemView(icon: "bolt.fill", title: "Upgrade to Power Plan", action: { [weak self] in
                    self?.openUpgrade()
                }), width: UIConstants.menuBarPopoverWidth, height: 32)
            menu.addItem(upgradeItem)
        }

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem()
        quitItem.view = makeHostingView(
            MenuItemView(icon: "power", title: "Quit Default Tamer", isDestructive: true, action: { [weak self] in
                self?.quitApp()
            }), width: UIConstants.menuBarPopoverWidth, height: 32)
        menu.addItem(quitItem)
    }

    /// Wraps a SwiftUI view in an NSHostingView sized for an NSMenuItem.
    private func makeHostingView<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSHostingView<V> {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        return hosting
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Rebuild the menu so the upgrade item and header reflect the latest
        // license and default-browser state.
        buildMenu()
    }

    func menuDidClose(_ menu: NSMenu) {
        appLogger.debug("📂 menuDidClose")
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

    @objc func openUpgrade() {
        // Opens the Power plan purchase/activation page in the browser.
        // startUpgrade re-checks the subscription first; if the user already has
        // an active plan it activates silently without opening a browser.
        LicensingManager.shared.startUpgrade()
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

        // Switch to .regular so the app becomes the key application and can
        // receive keyboard events (e.g. in the shortcut recorder, text fields).
        // Restored to .accessory when the window closes.
        NSApp.setActivationPolicy(.regular)
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

        // Route `defaulttamer://activate?token=...&did=...` deep-links — issued by /upgrade
        if url.scheme == "defaulttamer", url.host == "activate" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let token     = components?.queryItems?.first(where: { $0.name == "token" })?.value ?? ""
            let isUpgraded = components?.queryItems?.contains(where: { $0.name == "upgraded" && $0.value == "true" }) ?? false
            let did        = components?.queryItems?.first(where: { $0.name == "did" })?.value
            if !token.isEmpty {
                LicensingManager.shared.handleActivation(token: token, isPaymentCallback: isUpgraded, confirmedDeviceId: did)
            }
            return
        }

        // Route `defaulttamer://upgraded` — legacy no-op (kept for compatibility)
        if url.scheme == "defaulttamer", url.host == "upgraded" {
            return
        }

        // Route `defaulttamer://promo?code=XXXX` — promo code delivered via deep link
        // (e.g. from a pricing page button or a notification tap).
        // Opens Preferences on the License tab with the code pre-filled and validated.
        if url.scheme == "defaulttamer", url.host == "promo" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
               !code.isEmpty {
                PromoManager.shared.applyFromDeepLink(code: code)
                appState.pendingTabSelection = .power
                showPreferencesWindow()
            }
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

        // Capture modifier flags immediately at Apple Event arrival time, before any
        // async dispatch, so the snapshot is correct for shortcut-rule matching.
        let capturedFlags = NSEvent.modifierFlags

        Task { @MainActor in
            appState.handleURL(url, sourceApp: sourceAppBundleId, modifierFlags: capturedFlags)
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        let browserOpenableURLs = urls.filter { $0.isBrowserOpenableFile }

        guard !browserOpenableURLs.isEmpty else {
            appLogger.error("No browser-openable files received from Finder")
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        for url in browserOpenableURLs {
            appLogger.info("📄 Received local file from Finder (openFiles): \(url.lastPathComponent, privacy: .public)")
            appState.handleURL(url, sourceApp: BundleIdentifiers.finder)
        }

        sender.reply(toOpenOrPrint: .success)
    }

    @objc func handleOpenDocumentsEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        appLogger.info("handleOpenDocuments: received kAEOpenDocuments event")

        guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else {
            appLogger.error("handleOpenDocuments: no direct object in Apple Event")
            return
        }

        appLogger.info("handleOpenDocuments: descriptor type=\(fileList.descriptorType, privacy: .public) items=\(fileList.numberOfItems, privacy: .public)")

        var urls: [URL] = []

        // Iterate list items, or treat the descriptor itself as a single item.
        // fileURLValue resolves typeAlias, typeBookmarkData, typeFSRef, and
        // typeFileURL descriptors uniformly — no need to branch on descriptorType.
        let count = fileList.numberOfItems
        if count > 0 {
            for i in 1...count {
                guard let item = fileList.atIndex(i) else { continue }
                if let fileURL = item.fileURLValue {
                    urls.append(fileURL)
                } else if let s = item.stringValue, !s.isEmpty {
                    // Fallback: coerce to URL if it looks like a path or file URL
                    if s.hasPrefix("/") {
                        urls.append(URL(fileURLWithPath: s))
                    } else if s.hasPrefix("file://"), let u = URL(string: s) {
                        urls.append(u)
                    }
                }
            }
        } else {
            if let fileURL = fileList.fileURLValue {
                urls.append(fileURL)
            } else if let s = fileList.stringValue, !s.isEmpty {
                if s.hasPrefix("/") {
                    urls.append(URL(fileURLWithPath: s))
                } else if s.hasPrefix("file://"), let u = URL(string: s) {
                    urls.append(u)
                }
            }
        }

        appLogger.info("handleOpenDocuments: resolved \(urls.count, privacy: .public) URL(s)")

        let browserOpenable = urls.filter { $0.isBrowserOpenableFile }
        guard !browserOpenable.isEmpty else {
            appLogger.error("handleOpenDocuments: no browser-openable files (resolved \(urls.count) total, paths: \(urls.map(\.lastPathComponent).joined(separator: ", "), privacy: .public))")
            return
        }

        for url in browserOpenable {
            appLogger.info("📄 Received local file from Finder: \(url.lastPathComponent, privacy: .public)")
            appState.handleURL(url, sourceApp: BundleIdentifiers.finder)
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
            NSApp.setActivationPolicy(.accessory)
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
