//
//  BrowserIconView.swift
//  Default Tamer
//
//  Async browser icon loading view with placeholder
//

import SwiftUI
import AppKit

/// A view that asynchronously loads and displays a browser icon
struct BrowserIconView: View {
    let browser: Browser
    let size: CGFloat
    
    @State private var icon: NSImage?
    @State private var isLoading = true
    
    init(browser: Browser, size: CGFloat = UIConstants.browserIconSize) {
        self.browser = browser
        self.size = size
    }
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else if isLoading {
                // Placeholder while loading
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: size, height: size)
            } else {
                // Fallback icon if loading failed
                Image(systemName: "globe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadIcon()
        }
    }
    
    private func loadIcon() async {
        // Check if browser has a cached icon first
        if let cached = browser.getCachedIcon() {
            icon = cached
            isLoading = false
            return
        }
        
        // Load icon asynchronously
        let bundleId = browser.id
        let loadedIcon = await Task.detached(priority: .utility) { () -> NSImage? in
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                return nil
            }
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }.value
        
        icon = loadedIcon
        isLoading = false
    }
}

// MARK: - Convenience Initializers

extension BrowserIconView {
    /// Create icon view for display in lists (24pt)
    static func standard(browser: Browser) -> BrowserIconView {
        BrowserIconView(browser: browser, size: UIConstants.browserIconSize)
    }
    
    /// Create small icon view for compact UI (16pt)
    static func small(browser: Browser) -> BrowserIconView {
        BrowserIconView(browser: browser, size: UIConstants.smallIconSize)
    }
    
    /// Create large icon view for preferences or detailed views (32pt)
    static func large(browser: Browser) -> BrowserIconView {
        BrowserIconView(browser: browser, size: UIConstants.largeIconSize)
    }
}

// MARK: - Preview

#if DEBUG
struct BrowserIconView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            BrowserIconView.small(browser: Browser(
                bundleId: BundleIdentifiers.safari,
                displayName: "Safari"
            ))
            
            BrowserIconView.standard(browser: Browser(
                bundleId: BundleIdentifiers.chrome,
                displayName: "Chrome"
            ))
            
            BrowserIconView.large(browser: Browser(
                bundleId: BundleIdentifiers.firefox,
                displayName: "Firefox"
            ))
        }
        .padding()
    }
}
#endif
