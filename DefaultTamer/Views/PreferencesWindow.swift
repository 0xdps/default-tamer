//
//  PreferencesWindow.swift
//  Default Tamer
//
//  Main preferences/settings window with tabs
//

import Sparkle
import SwiftUI

struct PreferencesWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var updateManager: UpdateManager
    @State private var selectedTab: PreferenceTab = .general
    @StateObject private var toastManager = ToastManager.shared

    private var windowTitle: String {
        switch selectedTab {
        case .general:
            return "Default Tamer / Settings"
        case .rules:
            return "Default Tamer / Rules"
        case .activity:
            return "Default Tamer / Activity"
        case .about:
            return "Default Tamer / About"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar area handled by .toolbar modifier

            Divider()

            // Main content
            Group {
                switch selectedTab {
                case .general:
                    GeneralTab()
                        .environmentObject(appState)
                case .rules:
                    RulesTab()
                        .environmentObject(appState)
                case .activity:
                    ActivityTab()
                        .environmentObject(appState)
                case .about:
                    AboutTab()
                        .environmentObject(appState)
                        .environmentObject(updateManager)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .navigationTitle(windowTitle)
        .toolbarColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { selectedTab = .general }) {
                    Label("General", systemImage: "gearshape")
                        .foregroundColor(selectedTab == .general ? .accentColor : .primary)
                }
                .keyboardShortcut("1", modifiers: .command)
                .help("General settings and preferences")

                Button(action: { selectedTab = .rules }) {
                    Label("Rules", systemImage: "arrow.triangle.branch")
                        .foregroundColor(selectedTab == .rules ? .accentColor : .primary)
                }
                .keyboardShortcut("2", modifiers: .command)
                .help("Manage routing rules")

                // Only show Activity tab when diagnostics is enabled
                if appState.settings.diagnosticsEnabled {
                    Button(action: { selectedTab = .activity }) {
                        Label("Activity", systemImage: "clock.arrow.circlepath")
                            .foregroundColor(selectedTab == .activity ? .accentColor : .primary)
                    }
                    .keyboardShortcut("3", modifiers: .command)
                    .help("View routing activity logs")
                }

                Button(action: { selectedTab = .about }) {
                    Label("About", systemImage: "info.circle")
                        .foregroundColor(selectedTab == .about ? .accentColor : .primary)
                }
                .keyboardShortcut("4", modifiers: .command)
                .help("About Default Tamer")
            }
        }
        .toastOverlay(manager: toastManager)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPreferencesTab"))) { notification in
            if let tab = notification.object as? PreferenceTab {
                selectedTab = tab
            } else if let tabIndex = notification.object as? Int,
                      let tab = PreferenceTab(rawValue: tabIndex)
            {
                // Legacy integer-based callers
                selectedTab = tab
            }
        }
        .onAppear {
            // Check for pending tab selection from menu bar
            if let pendingTab = appState.pendingTabSelection {
                selectedTab = pendingTab
                appState.pendingTabSelection = nil
            }
        }
        .onChange(of: appState.pendingTabSelection) { newValue in
            if let pendingTab = newValue {
                selectedTab = pendingTab
                appState.pendingTabSelection = nil
            }
        }
        .onChange(of: appState.settings.diagnosticsEnabled) { isEnabled in
            // If diagnostics is disabled while on Activity tab, switch to General
            if !isEnabled && selectedTab == .activity {
                selectedTab = .general
            }
        }
    }
}

enum PreferenceTab: Int {
    case general = 0
    case rules = 1
    case activity = 2
    case about = 3
}

// MARK: - General Tab

struct GeneralTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                Toggle("Start at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: { _ in appState.toggleLaunchAtLogin() }
                ))

                Toggle("Enable routing", isOn: Binding(
                    get: { appState.settings.enabled },
                    set: { _ in appState.toggleEnabled() }
                ))

                Toggle("Show menu bar icon", isOn: .constant(true))
                    .disabled(true)
                    .help("Menu bar icon provides quick access to settings and rules")
            } header: {
                Text("Startup")
                    .font(.headline)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fallback Browser")
                            .font(.subheadline)
                        Text("Browser to use when no rules match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { appState.settings.fallbackBrowserId },
                        set: { appState.setFallbackBrowser($0) }
                    )) {
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

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secondary Browser")
                            .font(.subheadline)
                        Text("Open ⌥ Option+click links directly in this browser instead of showing the chooser pop-up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { appState.settings.secondaryBrowserId ?? "" },
                        set: { appState.setSecondaryBrowser($0.isEmpty ? nil : $0) }
                    )) {
                        Text("Show Chooser Pop-up").tag("")
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
                }
            } header: {
                Text("Default Browser")
                    .font(.headline)
            }

            // Diagnostics and User Feedback

            Section {
                Toggle(isOn: Binding(
                    get: { appState.settings.telemetryEnabled == true },
                    set: { appState.setTelemetryEnabled($0) }
                )) {
                    Text("Share anonymous usage stats") + Text(" (recommended)").foregroundColor(.secondary)
                }

                TelemetryConsentDescription()

                Toggle(isOn: Binding(
                    get: { appState.settings.diagnosticsEnabled },
                    set: { _ in appState.toggleDiagnostics() }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activity Log")
                        Text("Record routing decisions. Adds an Activity tab to view recent routes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

            } header: {
                Text("Diagnostics")
                    .font(.headline)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset to Factory Defaults")
                            .font(.subheadline)
                        Text("Removes all rules, settings, and preferences. This cannot be undone.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(role: .destructive, action: { showResetConfirmation = true }) {
                        Text("Reset")
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("Danger Zone")
                    .font(.headline)
                    .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Reset to Factory Defaults?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                appState.resetToDefaults()
            }
        } message: {
            Text("This will delete all your rules, settings, and preferences. The app will return to its first-run state. This cannot be undone.")
        }
    }
}

// MARK: - Rules Tab

struct RulesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedRule: Rule?
    @State private var showAddRule = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false

    var body: some View {
        HStack(spacing: 0) {
            // Left side - rules list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Rules")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 8) {
                        Menu {
                            Button("Import Rules...") {
                                showImportSheet = true
                            }
                            Button("Export Rules...") {
                                showExportSheet = true
                            }
                            .disabled(appState.rules.isEmpty)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .help("Import/Export")

                        Button(action: { showAddRule = true }) {
                            Image(systemName: "plus")
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .help("Add Rule")

                        Button(action: deleteSelectedRule) {
                            Image(systemName: "minus")
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRule == nil)
                        .help("Delete Rule")
                    }
                }
                .padding()

                Divider()

                // Rules list
                if appState.rules.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No rules")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedRule) {
                        ForEach(appState.rules) { rule in
                            RuleSidebarRow(rule: rule)
                                .tag(rule)
                        }
                        .onMove { source, destination in
                            appState.moveRule(from: source, to: destination)
                        }
                    }
                }

                Divider()

                // Footer
                HStack {
                    Text("\(appState.rules.count) rule\(appState.rules.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .frame(width: 250)

            Divider()

            // Right side - rule details
            if let rule = selectedRule {
                RuleDetailView(rule: rule)
                    .environmentObject(appState)
            } else {
                EmptyRuleDetail()
            }
        }
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportRulesSheet(rules: appState.rules)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportRulesSheet(appState: appState)
        }
        .onAppear {
            if selectedRule == nil, let first = appState.rules.first {
                selectedRule = first
            }
        }
    }

    private func deleteSelectedRule() {
        guard let rule = selectedRule else { return }
        appState.deleteRule(rule)
        selectedRule = appState.rules.first
    }
}

// MARK: - Export Rules Sheet

struct ExportRulesSheet: View {
    let rules: [Rule]
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ExportFormat = .json
    @State private var isExporting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Export Rules")
                    .font(.title2)

                Text("\(rules.count) rule\(rules.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Format selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Format")
                    .font(.headline)

                Picker("", selection: $selectedFormat) {
                    ForEach([ExportFormat.json, ExportFormat.csv], id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)

                Group {
                    if selectedFormat == .json {
                        Text("JSON format preserves all rule details and is recommended for backup and transfer between Default Tamer installations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("CSV format is compatible with spreadsheet applications but may lose some metadata.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 20)
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export...") {
                    exportRules()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 450, height: 320)
        .alert("Export Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func exportRules() {
        isExporting = true

        do {
            let data: Data
            switch selectedFormat {
            case .json:
                data = try RuleImportExport.exportToJSON(rules)
            case .csv:
                data = try RuleImportExport.exportToCSV(rules)
            }

            // Show save panel
            let panel = NSSavePanel()
            panel.allowedContentTypes = [selectedFormat.contentType]
            panel.nameFieldStringValue = "DefaultTamer-Rules.\(selectedFormat.fileExtension)"
            panel.message = "Choose where to save your rules"

            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        try data.write(to: url)
                        Task { @MainActor in
                            ToastManager.shared.success("Rules exported successfully")
                        }
                        dismiss()
                    } catch {
                        errorMessage = "Failed to save file: \(error.localizedDescription)"
                        showError = true
                    }
                }
                isExporting = false
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isExporting = false
        }
    }
}

// MARK: - Import Rules Sheet

struct ImportRulesSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedMode: ImportMode = .merge
    @State private var isImporting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Import Rules")
                    .font(.title2)

                if !appState.rules.isEmpty {
                    Text("\(appState.rules.count) existing rule\(appState.rules.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Import mode selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Import Mode")
                    .font(.headline)

                Picker("", selection: $selectedMode) {
                    ForEach([ImportMode.merge, ImportMode.append, ImportMode.replace], id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(selectedMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if selectedMode == .replace && !appState.rules.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This will delete all \(appState.rules.count) existing rules")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.leading, 20)
                }
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Choose File...") {
                    importRules()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isImporting)
            }
        }
        .padding()
        .frame(width: 450, height: 350)
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func importRules() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a rules file to import"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            isImporting = true

            do {
                let data = try Data(contentsOf: url)

                // Detect format by file extension
                let importedRules: [Rule]
                if url.pathExtension.lowercased() == "json" {
                    importedRules = try RuleImportExport.importFromJSON(
                        data,
                        mode: selectedMode,
                        existingRules: appState.rules
                    )
                } else {
                    importedRules = try RuleImportExport.importFromCSV(
                        data,
                        mode: selectedMode,
                        existingRules: appState.rules
                    )
                }

                // Apply imported rules
                appState.replaceRules(importedRules)

                let message: String
                switch selectedMode {
                case .replace:
                    message = "Replaced with \(importedRules.count) rules"
                case .append:
                    message = "Added \(importedRules.count - appState.rules.count) rules"
                case .merge:
                    let newCount = importedRules.count - appState.rules.count
                    message = "Merged \(newCount) new rules"
                }

                Task { @MainActor in
                    ToastManager.shared.success(message)
                }

                dismiss()
            } catch let error as AppError {
                errorMessage = error.errorDescription ?? error.localizedDescription
                showError = true
                Task { @MainActor in
                    ErrorHandler.shared.handle(error, context: "Import Rules", showToast: true)
                }
            } catch {
                errorMessage = "Failed to import rules: \(error.localizedDescription)"
                showError = true
            }

            isImporting = false
        }
    }
}

// MARK: - Activity Tab

struct ActivityTab: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        if !appState.settings.diagnosticsEnabled {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Activity Logging Disabled")
                    .font(.headline)

                Text("Enable diagnostics in the General tab to track URL routing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Toolbar
                ActivityToolbar(viewModel: viewModel)

                Divider()

                // Table
                if viewModel.logs.isEmpty {
                    EmptyActivityView()
                } else {
                    ActivityTableView(logs: viewModel.logs)
                }
            }
            .onAppear {
                viewModel.loadLogs()
            }
        }
    }
}

// MARK: - Activity Toolbar

struct ActivityToolbar: View {
    @ObservedObject var viewModel: ActivityViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search URLs or domains...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.searchText) { _ in
                        viewModel.applyFilters()
                    }

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 300)

            Spacer()

            // Stats
            Text("\(viewModel.logs.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 20)

            // Time filter
            Picker("", selection: $viewModel.timeFilter) {
                Text("All Time").tag(ActivityViewModel.TimeFilter.all)
                Text("Today").tag(ActivityViewModel.TimeFilter.today)
                Text("Last 7 Days").tag(ActivityViewModel.TimeFilter.week)
                Text("Last 30 Days").tag(ActivityViewModel.TimeFilter.month)
            }
            .pickerStyle(.menu)
            .frame(width: 130)
            .onChange(of: viewModel.timeFilter) { _ in
                viewModel.applyFilters()
            }

            // Browser filter
            if !viewModel.availableBrowsers.isEmpty {
                Picker("", selection: $viewModel.browserFilter) {
                    Text("All Browsers").tag(nil as String?)
                    ForEach(viewModel.availableBrowsers, id: \.self) { browser in
                        Text(browser).tag(browser as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: viewModel.browserFilter) { _ in
                    viewModel.applyFilters()
                }
            }

            Divider()
                .frame(height: 20)

            // Actions
            Menu {
                Button("Refresh") {
                    viewModel.loadLogs()
                }

                Divider()

                Button("Clear Logs...") {
                    viewModel.showClearConfirmation = true
                }
                .disabled(viewModel.logs.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .alert("Clear Activity Logs?", isPresented: $viewModel.showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                viewModel.clearAllLogs()
            }
        } message: {
            Text("This will permanently delete all activity logs. This action cannot be undone.")
        }
    }
}

// MARK: - Activity Table View

struct ActivityTableView: View {
    let logs: [RouteLog]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("Time")
                        .frame(width: 120, alignment: .leading)
                        .font(.caption.bold())
                    Text("URL")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption.bold())
                    Text("Source")
                        .frame(width: 120, alignment: .leading)
                        .font(.caption.bold())
                    Text("Rule")
                        .frame(width: 110, alignment: .leading)
                        .font(.caption.bold())
                    Text("Browser")
                        .frame(width: 140, alignment: .leading)
                        .font(.caption.bold())
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Rows
                ForEach(logs) { log in
                    ActivityRowView(log: log)
                    Divider()
                }
            }
        }
    }
}

struct ActivityRowView: View {
    let log: RouteLog

    var body: some View {
        HStack(spacing: 0) {
            // Time
            VStack(alignment: .leading, spacing: 2) {
                Text(log.relativeTime())
                    .font(.caption)
                Text(log.formattedTimestamp())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, alignment: .leading)

            // URL
            VStack(alignment: .leading, spacing: 2) {
                Text(log.urlHost)
                    .font(.system(.caption, design: .monospaced))
                Text(log.url)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Source
            VStack(alignment: .leading, spacing: 2) {
                if let sourceApp = log.sourceApp {
                    // Try to get app name, fallback to bundle ID
                    let appName = SourceAppDetector.getAppName(for: sourceApp) ?? sourceApp

                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.primary)

                    Text(sourceApp)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)

            // Rule
            Group {
                if log.fallbackUsed {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                        Text("Fallback")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                } else if log.matchedRuleType == "Override" {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption)
                        Text("Override")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                } else if let ruleType = log.matchedRuleType {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text(ruleType.capitalized)
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .frame(width: 110, alignment: .leading)

            // Browser
            Text(log.targetBrowserName)
                .font(.caption)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Empty Activity State

struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Activity Yet")
                .font(.title2)

            Text("Activity logs will appear here when URLs are routed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Activity View Model

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var logs: [RouteLog] = []
    @Published var allLogs: [RouteLog] = []
    @Published var searchText = ""
    @Published var timeFilter: TimeFilter = .all
    @Published var browserFilter: String?
    @Published var showClearConfirmation = false
    @Published var availableBrowsers: [String] = []

    enum TimeFilter {
        case all, today, week, month

        var startDate: Date? {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .all:
                return nil
            case .today:
                return calendar.startOfDay(for: now)
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .day, value: -30, to: now)
            }
        }
    }

    func loadLogs() {
        allLogs = ActivityDatabase.shared.fetchRecentLogs(limit: DatabaseConstants.defaultFetchLimit)

        // Extract unique browsers for filter
        let uniqueBrowsers = Set(allLogs.map { $0.targetBrowserName })
        availableBrowsers = Array(uniqueBrowsers).sorted()

        applyFilters()
    }

    func applyFilters() {
        var filtered = allLogs

        // Time filter
        if let startDate = timeFilter.startDate {
            filtered = filtered.filter { $0.timestamp >= startDate }
        }

        // Browser filter
        if let browser = browserFilter {
            filtered = filtered.filter { $0.targetBrowserName == browser }
        }

        // Search filter
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            filtered = filtered.filter { log in
                log.url.lowercased().contains(search) ||
                    log.urlHost.lowercased().contains(search)
            }
        }

        logs = filtered
    }

    func clearAllLogs() {
        ActivityDatabase.shared.deleteAllLogs()
        loadLogs()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var updateManager: UpdateManager
    @StateObject private var checkForUpdatesViewModel = CheckForUpdatesViewModel()
    @State private var isIconHovered = false

    var body: some View {
        VStack(spacing: 20) {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .scaleEffect(isIconHovered ? 1.1 : 1.0)
                    .shadow(color: isIconHovered ? Color.accentColor.opacity(0.3) : Color.clear, radius: isIconHovered ? 20 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isIconHovered)
                    .onHover { hovering in
                        isIconHovered = hovering
                    }
            }

            VStack(spacing: 8) {
                Text("Default Tamer")
                    .font(.title)
                    .fontWeight(.bold)

                // Version with Check for Updates button inline
                HStack(spacing: 12) {
                    Text("Version \(AppVersion.current)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: {
                        updateManager.checkForUpdates(forced: true)
                    }) {
                        if updateManager.isChecking {
                            ProgressView()
                                .scaleEffect(0.7, anchor: .center)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
                    .help("Check for updates")
                }
            }

            Text("Route your links to the right browser, every time")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("Made by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Link("0xdps", destination: URL(string: ExternalLinks.developerWebsite)!)
                    .font(.caption)
                Text("·")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Link("defaulttamer.app", destination: URL(string: ExternalLinks.website)!)
                    .font(.caption)
            }

            Spacer()

            // Centered links
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Spacer()

                    Link(destination: URL(string: ExternalLinks.github)!) {
                        Label("View on GitHub", systemImage: "link")
                    }

                    Divider()
                        .frame(height: 20)

                    Link(destination: URL(string: ExternalLinks.issues)!) {
                        Label("Report an Issue", systemImage: "exclamationmark.bubble")
                    }

                    Divider()
                        .frame(height: 20)

                    Link(destination: URL(string: ExternalLinks.buyMeACoffee)!) {
                        Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                    }
                    .foregroundColor(.orange)

                    Divider()
                        .frame(height: 20)

                    Link(destination: URL(string: ExternalLinks.privacy)!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Spacer()
                }

                Text("© 2026 Default Tamer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkForUpdatesViewModel.updater = updateManager.updater
        }
    }
}

// MARK: - Shared Telemetry Consent Description

/// Reusable description block shown wherever the telemetry toggle appears.
struct TelemetryConsentDescription: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Default Tamer is a free, solo, open source project. Anonymous stats are the main signal we have for what to fix or improve next.")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Helps us:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("• Know which rule types people use most")
                Text("• Spot if routing failures are increasing")
                Text("• Prioritise fixes across macOS versions")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text("We never collect URLs, browsing history, or personal data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Link("Privacy Policy →", destination: URL(string: ExternalLinks.privacy)!)
                .font(.caption)
                .padding(.top, 2)
        }
    }
}
