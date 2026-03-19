//
//  FirstRunView.swift
//  Default Tamer
//
//  First-run experience
//

import SwiftUI
import AppKit

struct FirstRunView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSystemSettingsInstructions = false
    @State private var setDefaultInProgress = false
    @State private var setDefaultFailed = false
    @State private var setDefaultSuccess = false
    @State private var checkingDefaultStatus = false
    @State private var selectedFallbackBrowser: String = ""
    @State private var telemetryEnabled: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon and title - more compact
            VStack(spacing: 4) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                
                Text("Welcome to Default Tamer")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Route your links to the right browser, every time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Setup steps
            Form {
                // Step 1: Set as default
                Section {
                    HStack {
                        if setDefaultSuccess {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        Text("Set as Default Browser")
                            .font(.headline)
                        
                        if setDefaultSuccess {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(setDefaultSuccess ? "✅ DefaultTamer is now your default browser" : "Open System Settings and set Default Tamer as your default web browser")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !setDefaultSuccess {
                        Button(setDefaultInProgress ? "Waiting for confirmation..." : "Set as Default Browser") {
                            setDefaultInProgress = true
                            setDefaultFailed = false
                            checkingDefaultStatus = false
                            
                            // First check if we're already default
                            if appState.browserManager.isDefaultBrowser() {
                                setDefaultInProgress = false
                                setDefaultSuccess = true
                                return
                            }
                            
                            // Request to set as default (shows system dialog)
                            _ = appState.browserManager.requestSetAsDefault()
                            
                            // Start monitoring for the user's choice
                            startMonitoringDefaultBrowserStatus()
                        }
                        .buttonStyle(.bordered)
                        .disabled(setDefaultInProgress)
                    }
                }
                .alert("Failed to Set Default", isPresented: $setDefaultFailed) {
                    Button("Try Again") {
                        setDefaultFailed = false
                    }
                    Button("Open Settings", action: openSystemSettings)
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("DefaultTamer was not set as the default browser. You may have cancelled the system dialog or selected a different browser. Would you like to try again or manually set it in System Settings?")
                }
                
                // Step 2: Choose fallback
                Section {
                    HStack {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Choose Fallback Browser")
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("Select which browser to use when no rules match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("", selection: $selectedFallbackBrowser) {
                            ForEach(appState.browserManager.availableBrowsers) { browser in
                                Label {
                                    Text(browser.displayName)
                                } icon: {
                                    if let icon = browser.getIcon() {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    }
                                }
                                .tag(browser.id)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()

                        Button(action: {
                            appState.browserManager.refreshBrowsers()
                        }) {
                            if appState.browserManager.isRefreshingBrowsers {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(appState.browserManager.isRefreshingBrowsers)
                        .help("Refresh browser list")
                    }
                }
                
                // Step 3: Privacy
                Section {
                    HStack {
                        Image(systemName: "hand.raised.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Privacy")
                            .font(.headline)
                    }
                    
                    Toggle(isOn: $telemetryEnabled) {
                        Text("Share anonymous usage stats") + Text(" (recommended)").foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    
                    TelemetryConsentDescription()
                }
                
            }
            .formStyle(.grouped)
            
            // Done button
            Button("Get Started") {
                appState.setTelemetryEnabled(telemetryEnabled)
                appState.setFallbackBrowser(selectedFallbackBrowser)
                appState.completeFirstRun()
                // AppDelegate observes showFirstRun → false via Combine and handles
                // closing this window + opening preferences. No AppKit calls here.
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(width: 480, height: 520)
        .onAppear {
            // Initialize with current fallback browser or first available
            if appState.settings.fallbackBrowserId.isEmpty {
                selectedFallbackBrowser = appState.browserManager.availableBrowsers.first?.id ?? ""
            } else {
                selectedFallbackBrowser = appState.settings.fallbackBrowserId
            }
            // Pre-populate telemetry toggle from existing setting (default false)
            telemetryEnabled = appState.settings.telemetryEnabled ?? false
        }
    }
    
    private func startMonitoringDefaultBrowserStatus() {
        checkingDefaultStatus = true
        var attempts = 0
        let maxAttempts = 60 // Check for up to 60 seconds (60 attempts * 1 second)
        
        // Check periodically if DefaultTamer is now the default browser
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            attempts += 1
            
            // Check if we're now the default browser
            Task { @MainActor in
                if appState.browserManager.isDefaultBrowser() {
                    timer.invalidate()
                    setDefaultInProgress = false
                    setDefaultSuccess = true
                    checkingDefaultStatus = false
                    return
                }
                
                // If we've checked too many times, assume the user cancelled or chose another browser
                if attempts >= maxAttempts {
                    timer.invalidate()
                    setDefaultInProgress = false
                    setDefaultFailed = true
                    checkingDefaultStatus = false
                }
            }
        }
    }
    
    private func openSystemSettings() {
        // Try multiple approaches to open the correct settings pane
        
        // Approach 1: Open Desktop & Dock settings (macOS 13+)
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.preference.dock")!, // Desktop & Dock
            URL(string: "x-apple.systempreferences:com.apple.preference.general")! // Fallback to General
        ]
        
        for url in urls {
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

