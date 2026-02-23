//
//  BrowserChooser.swift
//  Default Tamer
//
//  Modifier key chooser UI — compact icon grid with hover labels
//

import SwiftUI

struct BrowserChooser: View {
    let url: URL
    @EnvironmentObject var appState: AppState

    @State private var selectedIndex = 0
    @State private var hoveredIndex: Int? = nil
    @State private var keyMonitor: Any?

    var browsers: [Browser] {
        appState.browserManager.availableBrowsers
    }

    /// The label to show — hovered name takes priority, else selected name
    private var activeName: String {
        let idx = hoveredIndex ?? selectedIndex
        guard idx >= 0 && idx < browsers.count else { return "" }
        return browsers[idx].displayName
    }

    /// Pick column count based on number of browsers
    private var columnCount: Int {
        let count = browsers.count
        if count <= 1 { return 1 }
        if count <= 2 { return 2 }
        if count <= 3 { return 3 }
        if count == 4 { return 2 }
        if count <= 6 { return 3 }
        if count <= 8 { return 4 }
        return 4
    }

    // Layout constants
    private let cellSize: CGFloat = 60
    private let cellSpacing: CGFloat = 12
    private let gridPadding: CGFloat = 24

    /// Total popup width derived from column count
    private var popupWidth: CGFloat {
        let cols = CGFloat(columnCount)
        return (cols * cellSize) + ((cols - 1) * cellSpacing) + (gridPadding * 2)
    }

    /// Rows of browser indices
    private var rows: [[Int]] {
        let indices = Array(0..<browsers.count)
        return stride(from: 0, to: indices.count, by: columnCount).map {
            Array(indices[$0..<min($0 + columnCount, indices.count)])
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header — app icon + domain
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Open in...")
                        .font(.system(size: 13, weight: .semibold))
                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.horizontal, gridPadding)
            .padding(.top, 14)

            // Browser icon grid — manual rows
            VStack(spacing: cellSpacing) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(row, id: \.self) { index in
                            BrowserIconItem(
                                browser: browsers[index],
                                isSelected: index == selectedIndex,
                                isHovered: index == hoveredIndex,
                                shortcut: index < 9 ? index + 1 : nil,
                                action: { selectBrowser(browsers[index]) }
                            )
                            .onHover { over in
                                hoveredIndex = over ? index : nil
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, gridPadding)
            .padding(.vertical, 4)

            // Active browser name label
            Text(activeName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .frame(height: 16)
                .animation(.easeInOut(duration: 0.12), value: activeName)

            // Hint
            Text("↑↓ ←→  or  1–\(min(browsers.count, 9))  ·  Enter to open  ·  Esc to cancel")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 12)
        }
        .frame(width: popupWidth)
        .fixedSize(horizontal: true, vertical: true)
        .background(
            ZStack {
                VisualEffectBlur()
                Color(nsColor: .windowBackgroundColor).opacity(0.82)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.55), radius: 30, y: 10)
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { removeKeyboardMonitor() }
    }

    // MARK: - Keyboard

    private func setupKeyboardMonitor() {
        let colCount = columnCount
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 126: // Up
                let newIdx = selectedIndex - colCount
                if newIdx >= 0 { selectedIndex = newIdx }
                return nil
            case 125: // Down
                let newIdx = selectedIndex + colCount
                if newIdx < browsers.count { selectedIndex = newIdx }
                return nil
            case 123: // Left
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 124: // Right
                if selectedIndex < browsers.count - 1 { selectedIndex += 1 }
                return nil
            case 36: // Enter/Return
                if selectedIndex >= 0 && selectedIndex < browsers.count {
                    selectBrowser(browsers[selectedIndex])
                }
                return nil
            case 53: // Escape
                closeChooser()
                return nil
            default:
                // Number keys 1-9
                if let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1 && num <= min(browsers.count, 9) {
                    selectBrowser(browsers[num - 1])
                    return nil
                }
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func selectBrowser(_ browser: Browser) {
        appState.openURLFromChooser(url, browserId: browser.id)
        closeChooser()
    }

    private func closeChooser() {
        appState.showChooser = false
        appState.chooserURL = nil
        appState.chooserSourceApp = nil
    }
}

// MARK: - Single Browser Icon

struct BrowserIconItem: View {
    let browser: Browser
    let isSelected: Bool
    let isHovered: Bool
    let shortcut: Int?
    let action: () -> Void

    private let iconSize: CGFloat = 40

    var body: some View {
        Button(action: action) {
            ZStack {
                // Selection / hover ring
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) :
                          isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )

                VStack(spacing: 4) {
                    if let icon = browser.getIcon() {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 28))
                            .frame(width: iconSize, height: iconSize)
                    }
                }
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(browser.displayName)
    }
}

// MARK: - Vibrancy background

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Key-accepting borderless panel

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

