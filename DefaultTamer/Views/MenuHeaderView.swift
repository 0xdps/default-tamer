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

    var body: some View {
        VStack(spacing: 12) {
            // App info row (always shown)
            HStack {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .grayscale(isDefaultBrowser ? 0.0 : 1.0)
                        .opacity(isDefaultBrowser ? 1.0 : 0.6)
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

            if isDefaultBrowser {
                // Normal state: routing toggle
                HStack {
                    Image(systemName: appState.settings.enabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(appState.settings.enabled ? .green : .secondary)
                    Text(appState.settings.enabled ? "Routing Active" : "Routing Paused")
                        .font(.subheadline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.settings.enabled },
                        set: { _ in appState.toggleEnabled() }
                    ))
                    .labelsHidden()
                    .toggleStyle(ActiveSwitchStyle())
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
            }
        }
        .padding()
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

// MARK: - Custom toggle that always renders with accent color
// The native .switch style uses AppKit's NSSwitch which renders grey
// inside NSMenu (non-key window). This custom style draws directly
// in SwiftUI so it always shows the correct color.

private struct ActiveSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        Capsule()
            .fill(isOn ? Color.accentColor : Color.gray.opacity(0.3))
            .frame(width: 46, height: 26)
            .overlay(
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                    .frame(width: 22, height: 22)
                    .offset(x: isOn ? 10 : -10),
                alignment: .center
            )
            .animation(.easeInOut(duration: 0.15), value: isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
    }
}
