//
//  BrowserManager.swift
//  Default Tamer
//
//  Manages browser discovery and URL opening
//

import Foundation
import AppKit

// MARK: - Browser Errors

enum BrowserError: LocalizedError {
    case notInstalled(bundleId: String)
    case notAccessible(bundleId: String)
    case openFailed(bundleId: String, underlying: Error)
    case noFallbackAvailable
    
    var errorDescription: String? {
        switch self {
        case .notInstalled(let bundleId):
            return "Browser '\(bundleId)' is not installed"
        case .notAccessible(let bundleId):
            return "Browser '\(bundleId)' cannot be accessed"
        case .openFailed(let bundleId, let error):
            return "Failed to open URL with '\(bundleId)': \(error.localizedDescription)"
        case .noFallbackAvailable:
            return "No fallback browser available"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notInstalled:
            return "Please install the browser or update your routing rules to use an installed browser."
        case .notAccessible:
            return "Check that the browser is properly installed and has necessary permissions."
        case .openFailed:
            return "Try opening the URL manually or use a different browser."
        case .noFallbackAvailable:
            return "Please install Safari or Chrome to use as a fallback browser."
        }
    }
}

@MainActor
class BrowserManager: ObservableObject {
    @Published var availableBrowsers: [Browser] = []
    @Published private(set) var isRefreshingBrowsers = false
    /// True when a silent background refresh is running (no spinner shown to user).
    private var isSilentlyRefreshing = false
    
    // Cache keys
    private static let cacheKey = "defaultTamer.cachedBrowsers"
    private static let cacheVersionKey = "defaultTamer.browserCacheVersion"
    private static let cacheTimestampKey = "defaultTamer.browserCacheTimestamp"
    private static let currentCacheVersion = 3
    private static let cacheExpirationInterval: TimeInterval = TimeConstants.browserCacheExpiration // 24 hours
    
    init() {
        loadCachedBrowsers()
    }
    
    /// Load browsers from cache. Falls back to async background discovery if cache is invalid.
    private func loadCachedBrowsers() {
        let defaults = UserDefaults.standard
        
        // Check cache version
        let cachedVersion = defaults.integer(forKey: Self.cacheVersionKey)
        guard cachedVersion == Self.currentCacheVersion else {
            debugLog("🔄 Browser cache version mismatch, scheduling background discovery...")
            Task { await self.refreshBrowsersInBackground(showSpinner: true) }
            return
        }
        
        // Check cache expiration
        if let timestamp = defaults.object(forKey: Self.cacheTimestampKey) as? Date {
            let age = Date().timeIntervalSince(timestamp)
            if age > Self.cacheExpirationInterval {
                debugLog("🔄 Browser cache expired (age: \(Int(age/3600))h), scheduling background discovery...")
                Task { await self.refreshBrowsersInBackground(showSpinner: true) }
                return
            }
        } else {
            Task { await self.refreshBrowsersInBackground(showSpinner: true) }
            return
        }
        
        // Load from cache
        if let data = defaults.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode([Browser].self, from: data),
           !cached.isEmpty {
            availableBrowsers = cached
            debugLog("✅ Loaded \(cached.count) browsers from cache")
            // Silently refresh in background to pick up new installs — no spinner
            Task { await self.refreshBrowsersSilently() }
        } else {
            debugLog("⚠️ Cache invalid, scheduling background discovery...")
            // List is empty; show spinner so the UI doesn't look broken
            Task { await self.refreshBrowsersInBackground(showSpinner: true) }
        }
    }
    
    /// Silent background refresh — runs without setting isRefreshingBrowsers (no spinner).
    @MainActor
    private func refreshBrowsersSilently() async {
        guard !isSilentlyRefreshing && !isRefreshingBrowsers else { return }
        isSilentlyRefreshing = true
        defer { isSilentlyRefreshing = false }
        debugLog("🔄 Silent background browser refresh started")
        let newBrowsers = await performDiscovery()
        if newBrowsers != availableBrowsers {
            debugLog("✅ Browser list silently updated (\(availableBrowsers.count) → \(newBrowsers.count))")
            availableBrowsers = newBrowsers
            saveBrowserCache()
        }
    }

    /// Background refresh of browser list (shows spinner).
    @MainActor
    private func refreshBrowsersInBackground(showSpinner: Bool = false) async {
        // If a silent refresh is running, cancel it conceptually — we'll do a full refresh now
        guard !isRefreshingBrowsers else { return }

        if showSpinner { isRefreshingBrowsers = true }
        defer { isRefreshingBrowsers = false }
        debugLog("🔄 Browser refresh started (spinner=\(showSpinner))")

        let newBrowsers = await performDiscovery()
        if newBrowsers != availableBrowsers {
            debugLog("✅ Browser list updated (\(availableBrowsers.count) → \(newBrowsers.count))")
            availableBrowsers = newBrowsers
            saveBrowserCache()
        } else {
            debugLog("✅ Browser list unchanged")
        }
    }
    
    /// Save browser list to cache
    private func saveBrowserCache() {
        let defaults = UserDefaults.standard
        
        if let data = try? JSONEncoder().encode(availableBrowsers) {
            defaults.set(data, forKey: Self.cacheKey)
            defaults.set(Self.currentCacheVersion, forKey: Self.cacheVersionKey)
            defaults.set(Date(), forKey: Self.cacheTimestampKey)
            debugLog("💾 Cached \(availableBrowsers.count) browsers")
        }
    }
    
    /// Manual refresh (user-initiated — always shows spinner).
    func refreshBrowsers() {
        debugLog("🔄 Manual browser refresh")
        Task {
            await refreshBrowsersInBackground(showSpinner: true)
        }
    }
    
    /// Discovers all apps that can handle HTTP/HTTPS URLs (using LaunchServices)
    func discoverBrowsers() {
        let discovered = Self.performDiscoverySync()
        availableBrowsers = discovered
        saveBrowserCache()
    }
    
    /// Async wrapper for browser discovery — caps at 5s so isRefreshingBrowsers
    /// can never get permanently stuck if LSCopyApplicationURLsForURL hangs.
    private func performDiscovery() async -> [Browser] {
        let discoveryTask = Task.detached(priority: .userInitiated) {
            Self.performDiscoverySync()
        }
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(5))
            discoveryTask.cancel()
        }
        let result = await discoveryTask.value
        timeoutTask.cancel()
        return result
    }
    
    /// Core browser discovery logic (synchronous).
    ///
    /// Strategy: trust LaunchServices for discovery, then apply two filters:
    ///
    ///  1. **Standard install location** — the app's parent directory must be one of
    ///     the known macOS app directories. This eliminates: nested helper bundles
    ///     (e.g. ChatGPT Atlas's internal helper), Xcode DerivedData builds, apps in
    ///     ~/.cache/puppeteer, DMG-mounted apps on /Volumes, etc.
    ///
    ///  2. **Known non-browser exclusion list** — a small hard-coded set of apps that
    ///     genuinely install in /Applications but register for http without being
    ///     browsers (iTerm2, browser-picker tools).
    private nonisolated static func performDiscoverySync() -> [Browser] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Only apps whose .app bundle sits directly inside one of these directories.
        // This is the primary noise filter — kills helpers, dev builds, DMG mounts, etc.
        let allowedParents: Set<String> = [
            "/Applications",
            "/System/Applications",
            "/System/Volumes/Preboot/Cryptexes/App/System/Applications",
            homeDir + "/Applications",
        ]

        // Known apps that install in /Applications and register for http/https but
        // are not web browsers. Keep this list minimal.
        let nonBrowserBundleIds: Set<String> = [
            "com.googlecode.iterm2",            // iTerm2 — opens http links in terminal
            "com.apple.Safari.WebApp",          // Safari web-app wrapper
            "com.apple.WebKit.WebContent",      // WebKit renderer helper
            "com.choosyosx.choosy",             // Choosy — browser picker
            "com.choosyosx.choosy.3",
            "com.sindresorhus.Browserosaurus",  // Browserosaurus — browser picker
            "net.kassett.Finicky",              // Finicky — browser picker
        ]

        let currentBundleId = Bundle.main.bundleIdentifier
        var discovered: [Browser] = []
        var seenBundleIds = Set<String>()

        guard let httpURL = URL(string: "http://"),
              let handlers = LSCopyApplicationURLsForURL(httpURL as CFURL, .all)?
                .takeRetainedValue() as? [URL] else {
            if let safariURL = safariAppURL() {
                return [Browser(bundleId: BundleIdentifiers.safari,
                                displayName: displayNameFromURL(safariURL),
                                isInstalled: true)]
            }
            return []
        }

        for appURL in handlers {
            // Filter 1: must be in a standard installation directory
            let parentPath = appURL.deletingLastPathComponent().path
            guard allowedParents.contains(parentPath) else { continue }

            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier,
                  !seenBundleIds.contains(bundleId),
                  bundleId != currentBundleId else { continue }

            // Filter 2: known non-browser apps
            guard !nonBrowserBundleIds.contains(bundleId) else { continue }

            let displayName = displayNameFromURL(appURL)
            discovered.append(Browser(bundleId: bundleId, displayName: displayName, isInstalled: true))
            seenBundleIds.insert(bundleId)
        }

        // Safari's real path is in the system cryptex — always ensure it's present.
        if !seenBundleIds.contains(BundleIdentifiers.safari),
           let safariURL = safariAppURL() {
            discovered.append(Browser(bundleId: BundleIdentifiers.safari,
                                      displayName: displayNameFromURL(safariURL),
                                      isInstalled: true))
        }

        return discovered.sorted { $0.displayName < $1.displayName }
    }

    /// Finds Safari.app without NSWorkspace (safe to call off main actor).
    /// Safari lives in the system cryptex on modern macOS, not /Applications.
    private nonisolated static func safariAppURL() -> URL? {
        let paths = [
            "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
            "/System/Applications/Safari.app",
            "/Applications/Safari.app",
        ]
        return paths.map { URL(fileURLWithPath: $0) }.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }
    
    /// Reads the human-readable display name directly from a bundle URL.
    /// Safe to call from any thread — does not use NSWorkspace.
    private nonisolated static func displayNameFromURL(_ url: URL) -> String {
        if let bundle = Bundle(url: url) {
            if let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String, !name.isEmpty { return name }
            if let name = bundle.infoDictionary?["CFBundleName"] as? String, !name.isEmpty { return name }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    /// Get the human-readable name for an app bundle ID (main-actor safe only).
    /// Use `displayNameFromURL` instead when calling from background threads.
    @MainActor
    static func getDisplayName(for bundleId: String) -> String? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return displayNameFromURL(appURL)
        }
        return nil
    }
    
    /// Opens a URL in a specific browser by bundle ID
    /// Returns true if successful, false otherwise
    @discardableResult
    func openURL(_ url: URL, inBrowser bundleId: String, privateMode: Bool = false) -> Bool {
        do {
            if privateMode {
                try safeOpenURLInPrivateMode(url, inBrowser: bundleId)
            } else {
                try safeOpenURL(url, inBrowser: bundleId)
            }
            return true
        } catch {
            debugLog("⚠️ \(error.localizedDescription)")
            ErrorNotifier.shared.notifyWarning(
                "Browser Error",
                message: error.localizedDescription
            )
            return false
        }
    }
    
    /// Safe URL opening with proper error handling
    /// Throws BrowserError if operation fails
    private func safeOpenURL(_ url: URL, inBrowser bundleId: String) throws {
        // Defensive check: Verify browser is installed
        guard let appURL = safeURLForApplication(withBundleIdentifier: bundleId) else {
            throw BrowserError.notInstalled(bundleId: bundleId)
        }
        
        // Defensive check: Verify URL is accessible
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw BrowserError.notAccessible(bundleId: bundleId)
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        // Defensive check: Use completion handler to catch async errors
        var openError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
            openError = error
            semaphore.signal()
        }
        
        // Wait for open operation (with timeout)
        _ = semaphore.wait(timeout: .now() + 5.0)
        
        if let error = openError {
            throw BrowserError.openFailed(bundleId: bundleId, underlying: error)
        }
        
        debugLog("✅ Opened \(url.absoluteString) in \(bundleId)")
    }

    /// Opens URL in private/incognito mode for supported browsers
    /// Throws BrowserError if operation fails
    private func safeOpenURLInPrivateMode(_ url: URL, inBrowser bundleId: String) throws {
        // Defensive check: Verify browser is installed
        guard let appURL = safeURLForApplication(withBundleIdentifier: bundleId) else {
            throw BrowserError.notInstalled(bundleId: bundleId)
        }

        // Get private mode arguments for this browser
        let privateArgs = getPrivateModeArguments(for: bundleId)

        if privateArgs.isEmpty {
            // Browser doesn't support command-line private mode
            // Fall back to normal opening
            debugLog("⚠️ Private mode not supported for \(bundleId), opening normally")
            try safeOpenURL(url, inBrowser: bundleId)
            return
        }

        // Build command to open browser with private mode flags
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appURL.path] + privateArgs + [url.absoluteString]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                debugLog("✅ Opened \(url.absoluteString) in \(bundleId) (private mode)")
            } else {
                throw BrowserError.openFailed(bundleId: bundleId, underlying: NSError(domain: "ProcessError", code: Int(process.terminationStatus)))
            }
        } catch {
            throw BrowserError.openFailed(bundleId: bundleId, underlying: error)
        }
    }

    /// Returns command-line arguments for opening browser in private mode
    private func getPrivateModeArguments(for bundleId: String) -> [String] {
        switch bundleId {
        case BundleIdentifiers.chrome:
            return ["--args", "--incognito"]
        case BundleIdentifiers.firefox:
            return ["--args", "-private-window"]
        case BundleIdentifiers.edge:
            return ["--args", "-inprivate"]
        case BundleIdentifiers.brave:
            return ["--args", "--incognito"]
        case BundleIdentifiers.opera:
            return ["--args", "--private"]
        case BundleIdentifiers.vivaldi:
            return ["--args", "--incognito"]
        case BundleIdentifiers.safari:
            // Safari requires AppleScript for private mode, not supported via command-line
            return []
        case BundleIdentifiers.arc:
            // Arc doesn't have command-line private mode support
            return []
        default:
            // Unknown browser - try generic Chromium incognito flag
            return ["--args", "--incognito"]
        }
    }

    /// Safe wrapper for getting application URL by bundle ID
    /// Returns nil if app is not found or not accessible
    private func safeURLForApplication(withBundleIdentifier bundleId: String) -> URL? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        
        // Verify the app actually exists at this location
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            debugLog("⚠️ App URL exists but file doesn't: \(appURL.path)")
            return nil
        }
        
        return appURL
    }
    
    /// Checks if a browser is installed and accessible
    func isBrowserAvailable(_ bundleId: String) -> Bool {
        return safeURLForApplication(withBundleIdentifier: bundleId) != nil
    }
    
    /// Opens URL with silent fallback if target browser is missing
    func openURLWithFallback(_ url: URL, targetBrowserId: String, fallbackBrowserId: String, privateMode: Bool = false) {
        // Try target browser first
        if openURL(url, inBrowser: targetBrowserId, privateMode: privateMode) {
            return
        }

        // Target browser failed — track the failure
        Task { @MainActor in
            AnalyticsManager.shared.sendEvent(name: "routing_failed", data: ["reason": "browser_unavailable"])
        }

        // Notify user of fallback
        let browserName = getBrowser(byId: targetBrowserId)?.displayName ?? "target browser"
        Task { @MainActor in
            ToastManager.shared.warning(
                "\(browserName) unavailable, using fallback browser",
                duration: 3.0
            )
        }

        // Use fallback (note: private mode may not work in fallback)
        if openURL(url, inBrowser: fallbackBrowserId, privateMode: privateMode) {
            return
        }
        
        // Last resort: Safari
        if fallbackBrowserId != BundleIdentifiers.safari {
            Task { @MainActor in
                AnalyticsManager.shared.sendEvent(name: "routing_failed", data: ["reason": "no_fallback"])
                ToastManager.shared.error(
                    "Fallback browser unavailable, using Safari",
                    duration: 3.5
                )
            }
            _ = openURL(url, inBrowser: BundleIdentifiers.safari)
        }
    }
    
    /// Get browser by bundle ID
    func getBrowser(byId bundleId: String) -> Browser? {
        return availableBrowsers.first(where: { $0.id == bundleId })
    }
    
    // MARK: - Default Browser Management
    
    /// Check if DefaultTamer is currently set as the default browser for HTTP/HTTPS
    func isDefaultBrowser() -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else { return false }
        
        // Check http handler
        if let httpHandler = LSCopyDefaultHandlerForURLScheme("http" as CFString)?.takeRetainedValue() as String? {
            if httpHandler == bundleId {
                return true
            }
        }
        
        // Check https handler
        if let httpsHandler = LSCopyDefaultHandlerForURLScheme("https" as CFString)?.takeRetainedValue() as String? {
            if httpsHandler == bundleId {
                return true
            }
        }
        
        return false
    }
    
    /// Request to set DefaultTamer as the default browser for HTTP/HTTPS
    func requestSetAsDefault() -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else { return false }
        
        // Set as default for http
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleId as CFString)
        
        // Set as default for https
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleId as CFString)
        
        debugLog("✅ Set DefaultTamer as default browser for http/https")
        return true
    }
}
