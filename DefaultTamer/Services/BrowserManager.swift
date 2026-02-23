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
    
    // Cache keys
    private static let cacheKey = "defaultTamer.cachedBrowsers"
    private static let cacheVersionKey = "defaultTamer.browserCacheVersion"
    private static let cacheTimestampKey = "defaultTamer.browserCacheTimestamp"
    private static let currentCacheVersion = 2
    private static let cacheExpirationInterval: TimeInterval = TimeConstants.browserCacheExpiration // 24 hours
    
    init() {
        loadCachedBrowsers()
    }
    
    /// Load browsers from cache or discover if cache is invalid
    private func loadCachedBrowsers() {
        let defaults = UserDefaults.standard
        
        // Check cache version
        let cachedVersion = defaults.integer(forKey: Self.cacheVersionKey)
        guard cachedVersion == Self.currentCacheVersion else {
            debugLog("🔄 Browser cache version mismatch, discovering...")
            discoverBrowsers()
            return
        }
        
        // Check cache expiration
        if let timestamp = defaults.object(forKey: Self.cacheTimestampKey) as? Date {
            let age = Date().timeIntervalSince(timestamp)
            if age > Self.cacheExpirationInterval {
                debugLog("🔄 Browser cache expired (age: \(Int(age/3600))h), discovering...")
                discoverBrowsers()
                return
            }
        } else {
            discoverBrowsers()
            return
        }
        
        // Load from cache
        if let data = defaults.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode([Browser].self, from: data),
           !cached.isEmpty {
            availableBrowsers = cached
            debugLog("✅ Loaded \(cached.count) browsers from cache")
            
            // Refresh in background (non-blocking)
            Task.detached(priority: .background) {
                await self.refreshBrowsersInBackground()
            }
        } else {
            debugLog("⚠️ Cache invalid, discovering...")
            discoverBrowsers()
        }
    }
    
    /// Background refresh of browser list (non-blocking)
    private func refreshBrowsersInBackground() async {
        debugLog("🔄 Background browser refresh started")
        
        // Discover browsers off main thread
        let newBrowsers = await performDiscovery()
        
        await MainActor.run {
            // Only update if there are changes
            if newBrowsers != availableBrowsers {
                debugLog("✅ Browser list updated (\(availableBrowsers.count) → \(newBrowsers.count))")
                availableBrowsers = newBrowsers
                saveBrowserCache()
            } else {
                debugLog("✅ Browser list unchanged")
            }
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
    
    /// Manual refresh (for user-initiated actions)
    func refreshBrowsers() {
        debugLog("🔄 Manual browser refresh")
        discoverBrowsers()
    }
    
    /// Discovers all apps that can handle HTTP/HTTPS URLs (using LaunchServices)
    func discoverBrowsers() {
        let discovered = performDiscoverySync()
        availableBrowsers = discovered
        saveBrowserCache()
    }
    
    /// Async wrapper for browser discovery
    private func performDiscovery() async -> [Browser] {
        return performDiscoverySync()
    }
    
    /// Core browser discovery logic (synchronous)
    private func performDiscoverySync() -> [Browser] {
        var discovered: [Browser] = []
        var seenBundleIds = Set<String>()
        var seenDisplayNames = Set<String>() // Track display names to avoid duplicates
        
        // Get current app's bundle ID to exclude it
        let currentBundleId = Bundle.main.bundleIdentifier
        
        // Apps to exclude from browser list (terminal emulators, browser managers, system utilities)
        let excludedBundleIds: Set<String> = [
            "com.googlecode.iterm2",           // iTerm2
            "com.apple.Terminal",               // Terminal
            "com.choosyosx.choosy",            // Choosy
            "com.choosyosx.choosy.3",          // Choosy 3
            "com.apple.Safari.WebApp",         // Safari Web Apps
            "com.apple.WebKit.WebContent",     // WebKit Helper
        ]
        
        // Query for all apps that handle http URL scheme
        if let httpURL = URL(string: "http://"),
           let httpHandlers = LSCopyApplicationURLsForURL(httpURL as CFURL, .all)?.takeRetainedValue() as? [URL] {
            
            for appURL in httpHandlers {
                if let bundle = Bundle(url: appURL),
                   let bundleId = bundle.bundleIdentifier,
                   !seenBundleIds.contains(bundleId),
                   bundleId != currentBundleId,
                   !excludedBundleIds.contains(bundleId),
                   isBrowserApp(bundleId: bundleId, appURL: appURL) {
                    
                    if let displayName = getDisplayName(for: bundleId) {
                        // Check for duplicate display names (e.g., multiple Atlas installations)
                        if !seenDisplayNames.contains(displayName) {
                            discovered.append(Browser(bundleId: bundleId, displayName: displayName, isInstalled: true))
                            seenBundleIds.insert(bundleId)
                            seenDisplayNames.insert(displayName)
                        }
                    }
                }
            }
        }
        
        // Query for https handlers as well
        if let httpsURL = URL(string: "https://"),
           let httpsHandlers = LSCopyApplicationURLsForURL(httpsURL as CFURL, .all)?.takeRetainedValue() as? [URL] {
            
            for appURL in httpsHandlers {
                if let bundle = Bundle(url: appURL),
                   let bundleId = bundle.bundleIdentifier,
                   !seenBundleIds.contains(bundleId),
                   bundleId != currentBundleId,
                   !excludedBundleIds.contains(bundleId),
                   isBrowserApp(bundleId: bundleId, appURL: appURL) {
                    
                    if let displayName = getDisplayName(for: bundleId) {
                        // Check for duplicate display names
                        if !seenDisplayNames.contains(displayName) {
                            discovered.append(Browser(bundleId: bundleId, displayName: displayName, isInstalled: true))
                            seenBundleIds.insert(bundleId)
                            seenDisplayNames.insert(displayName)
                        }
                    }
                }
            }
        }
        
        // Always ensure Safari is present as fallback
        if !seenBundleIds.contains(BundleIdentifiers.safari),
           let displayName = getDisplayName(for: BundleIdentifiers.safari) {
            discovered.append(Browser(bundleId: BundleIdentifiers.safari, displayName: displayName, isInstalled: true))
        }
        
        // Sort by display name for consistency
        return discovered.sorted { $0.displayName < $1.displayName }
    }
    
    /// Check if an app is likely a web browser (not a terminal, text editor, etc.)
    private func isBrowserApp(bundleId: String, appURL: URL) -> Bool {
        let lowercasedId = bundleId.lowercased()
        
        // Exclude terminal emulators and command line tools
        if lowercasedId.contains("terminal") || 
           lowercasedId.contains("iterm") ||
           lowercasedId.contains("console") {
            return false
        }
        
        // Exclude text editors that can handle URLs
        if lowercasedId.contains("textedit") ||
           lowercasedId.contains("sublimetext") ||
           lowercasedId.contains("vscode") ||
           lowercasedId.contains("xcode") {
            return false
        }
        
        // Exclude other browser managers
        if lowercasedId.contains("choosy") ||
           lowercasedId.contains("browserosaurus") ||
           lowercasedId.contains("finicky") {
            return false
        }
        
        // Include known web browsers and their variants
        let knownBrowsers = [
            "safari", "chrome", "firefox", "edge", "brave",
            "opera", "vivaldi", "arc", "orion", "webkit",
            "chromium", "browser", "navigator", "atlas",
            "mozilla", "nightly", "developer.edition"
        ]
        
        for browser in knownBrowsers {
            if lowercasedId.contains(browser) {
                return true
            }
        }
        
        // Check app category in Info.plist
        if let bundle = Bundle(url: appURL),
           let category = bundle.infoDictionary?["LSApplicationCategoryType"] as? String {
            // Accept apps in the "Web Browser" category
            if category == "public.app-category.web-browser" {
                return true
            }
        }
        
        // Conservative approach: if we're not sure, exclude it
        return false
    }
    
    /// Get the human-readable name for an app bundle ID
    private func getDisplayName(for bundleId: String) -> String? {
        // Try to get from bundle
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: appURL),
           let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? bundle.infoDictionary?["CFBundleName"] as? String {
            return displayName
        }
        
        // Fallback: try to get from app name
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return appURL.deletingPathExtension().lastPathComponent
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
