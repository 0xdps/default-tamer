//
//  MenuBarPopover.swift
//  Default Tamer
//
//  Main menu bar popover UI - simplified launcher
//

import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var appState: AppState
    var onDismiss: (() -> Void)?
    var onPreferences: (() -> Void)?
    var onRules: (() -> Void)?
    var onQuit: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with app info
            VStack(spacing: 12) {
                HStack {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "link.circle.fill")
                            .font(.title)
                            .foregroundColor(.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Tamer")
                            .font(.headline)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                // Status toggle
                Toggle(isOn: Binding(
                    get: { appState.settings.enabled },
                    set: { _ in appState.toggleEnabled() }
                )) {
                    HStack {
                        Image(systemName: appState.settings.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(appState.settings.enabled ? .green : .secondary)
                        Text(appState.settings.enabled ? "Routing Active" : "Routing Paused")
                            .font(.subheadline)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding()

            Divider()

            // Action buttons
            VStack(spacing: 0) {
                MenuButton(icon: "gearshape", title: "Preferences", action: {
                    onDismiss?()
                    onPreferences?()
                })

                Divider()

                MenuButton(icon: "list.bullet", title: "Manage Rules", action: {
                    onDismiss?()
                    onRules?()
                })

                Divider()

                MenuButton(icon: "power", title: "Quit Default Tamer", isDestructive: true, action: {
                    onQuit?()
                })
            }
            .padding(.vertical, 0)
        }
        .frame(width: UIConstants.menuBarPopoverWidth)
    }
    
    private var statusText: String {
        let rulesCount = appState.rules.count
        if rulesCount == 0 {
            return "No rules configured"
        } else {
            return "\(rulesCount) rule\(rulesCount == 1 ? "" : "s")"
        }
    }
}

// MARK: - Menu Button Component

struct MenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 16, alignment: .center)
                    .foregroundColor(isDestructive ? .red : .primary)
                Text(title)
                    .foregroundColor(isDestructive ? .red : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

