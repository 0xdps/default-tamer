//
//  MenuHeaderView.swift
//  Default Tamer
//
//  Menu header with app info and toggle
//

import SwiftUI

struct MenuHeaderView: View {
    @EnvironmentObject var appState: AppState
    var isDefaultBrowser: Bool = true
    @State private var isToggleHovering = false
    @State private var isIconHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // App info row (always shown)
            HStack {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .grayscale(isDefaultBrowser ? 0.0 : 1.0)
                        .opacity(isDefaultBrowser ? 1.0 : 0.6)
                        .scaleEffect(isIconHovered ? 1.15 : 1.0)
                        .shadow(color: isIconHovered ? Color.accentColor.opacity(0.3) : Color.clear, radius: isIconHovered ? 8 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isIconHovered)
                        .onHover { hovering in
                            isIconHovered = hovering
                        }
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
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if isDefaultBrowser {
                // Normal state: routing toggle
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: appState.settings.enabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .frame(width: 16, alignment: .center)
                        .foregroundColor(appState.settings.enabled ? .green : .secondary)
                    Text(appState.settings.enabled ? "Routing Active" : "Routing Paused")
                        .font(.subheadline)
                    Spacer()
                    routingToggle
                }
                .frame(height: 32)
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .frame(width: UIConstants.menuBarPopoverWidth)
                .background(isToggleHovering ? Color.accentColor.opacity(0.15) : Color.clear)
                .onHover { hovering in
                    isToggleHovering = hovering
                }
            } else {
                // Warning state: not default browser
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text("Not set as default browser")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    Text("Rules won't work until Default Tamer is your default browser.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        _ = appState.browserManager.requestSetAsDefault()
                    }) {
                        Text("Set as Default Browser")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var statusText: String {
        let rulesCount = appState.rules.count
        if rulesCount == 0 {
            return "No rules configured"
        } else {
            return "\(rulesCount) rule\(rulesCount == 1 ? "" : "s")"
        }
    }

    private var routingToggle: some View {
        let isOn = appState.settings.enabled
        return Capsule()
            .fill(isOn ? Color.accentColor : Color.gray.opacity(0.3))
            .frame(width: 36, height: 20)
            .overlay(
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                    .frame(width: 16, height: 16)
                    .offset(x: isOn ? 8 : -8),
                alignment: .center
            )
            .animation(.easeInOut(duration: 0.15), value: isOn)
            .onTapGesture {
                appState.toggleEnabled()
            }
    }
}
