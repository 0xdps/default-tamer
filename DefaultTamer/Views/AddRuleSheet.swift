//
//  AddRuleSheet.swift
//  Default Tamer
//
//  Add/edit rule flow
//

import SwiftUI

struct AddRuleSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var ruleType: RuleType = .domain
    @State private var targetBrowserId: String = ""
    
    // Source app fields
    @State private var sourceAppBundleId: String = ""
    @State private var sourceAppName: String = ""
    @State private var selectedApp: InstalledApp?
    @State private var showAppPicker = false
    @State private var installedApps: [InstalledApp] = []
    @State private var appSearchText: String = ""
    
    // Domain fields
    @State private var domainPattern: String = ""
    @State private var domainMatchType: DomainMatchType = .exact
    
    // URL pattern fields
    @State private var urlContains: String = ""
    @State private var urlRegex: String = ""
    @State private var useRegex: Bool = false
    @State private var regexError: String?
    @State private var testURL: String = ""
    @State private var testResult: Bool? = nil

    // Privacy mode
    @State private var openInPrivateMode: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Rule")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section("Rule Type") {
                    Picker("Type", selection: $ruleType) {
                        ForEach(RuleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Match Criteria") {
                    switch ruleType {
                    case .sourceApp:
                        VStack(alignment: .leading, spacing: 12) {
                            if let app = selectedApp {
                                // Show selected app
                                HStack(spacing: 12) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: UIConstants.largeIconSize, height: UIConstants.largeIconSize)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Text(app.bundleId)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Change") {
                                        showAppPicker = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 4)
                            } else {
                                // Show select button
                                Button(action: {
                                    showAppPicker = true
                                }) {
                                    Label("Select Application", systemImage: "plus.app")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                        
                    case .domain:
                        TextField("Domain (e.g., github.com)", text: $domainPattern)
                        Picker("Match Type", selection: $domainMatchType) {
                            ForEach([DomainMatchType.exact, .suffix, .contains], id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        
                    case .urlPattern:
                        Toggle("Use Regular Expression", isOn: $useRegex)
                            .help("Advanced: Match URLs using regex patterns")

                        if useRegex {
                            TextField("Regular Expression", text: $urlRegex)
                                .help("e.g., ^https://github\\.com/[^/]+/[^/]+/pull")
                                .onChange(of: urlRegex) { _ in
                                    validateRegex(urlRegex)
                                    testResult = nil // Clear test result when pattern changes
                                }

                            if let error = regexError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Regex testing UI
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Pattern")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    TextField("Enter URL to test", text: $testURL)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: testURL) { _ in
                                            testResult = nil // Clear result when URL changes
                                        }

                                    Button("Test") {
                                        testAddRuleRegexPattern()
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(urlRegex.isEmpty || regexError != nil || testURL.isEmpty)
                                }

                                if let result = testResult {
                                    HStack(spacing: 6) {
                                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(result ? .green : .orange)
                                        Text(result ? "Pattern matches" : "Pattern does not match")
                                            .font(.caption)
                                            .foregroundColor(result ? .green : .orange)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            TextField("URL contains (e.g., /docs/)", text: $urlContains)
                        }
                    }
                }
                
                Section("Target Browser") {
                    HStack {
                        Picker("Browser", selection: $targetBrowserId) {
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

                    Toggle("Open in private/incognito mode", isOn: $openInPrivateMode)
                        .help("Opens URLs in private/incognito window (not all browsers supported)")
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                // Validation feedback
                if !isValid {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Add Rule") {
                    addRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: UIConstants.addRuleSheetCompactWidth, height: UIConstants.addRuleSheetCompactHeight)
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(
                apps: installedApps,
                selectedApp: $selectedApp,
                searchText: $appSearchText
            )
        }
        .onAppear {
            // Set default target browser
            if let firstBrowser = appState.browserManager.availableBrowsers.first {
                targetBrowserId = firstBrowser.id
            }
            
            // Load installed apps in background
            DispatchQueue.global(qos: .userInitiated).async {
                let apps = ApplicationScanner.shared.getInstalledApplications()
                DispatchQueue.main.async {
                    installedApps = apps
                }
            }
        }
    }
    
    private var isValid: Bool {
        // Must have target browser
        guard !targetBrowserId.isEmpty else { return false }
        
        switch ruleType {
        case .sourceApp:
            return selectedApp != nil
        case .domain:
            return !domainPattern.isEmpty
        case .urlPattern:
            if useRegex {
                return !urlRegex.isEmpty && regexError == nil
            } else {
                return !urlContains.isEmpty
            }
        }
    }
    
    private func validateRegex(_ pattern: String) {
        guard !pattern.isEmpty else {
            regexError = nil
            return
        }

        regexError = RegexValidator.validate(pattern)
    }

    private func testAddRuleRegexPattern() {
        guard !urlRegex.isEmpty, !testURL.isEmpty, regexError == nil else {
            testResult = nil
            return
        }

        testResult = RegexValidator.test(urlRegex, against: testURL)
    }

    private func addRule() {
        var rule = Rule(type: ruleType, targetBrowserId: targetBrowserId, openInPrivateMode: openInPrivateMode)
        
        switch ruleType {
        case .sourceApp:
            if let app = selectedApp {
                rule.sourceAppBundleId = app.bundleId
                rule.sourceAppName = app.name
            }
            
        case .domain:
            rule.domainPattern = domainPattern
            rule.domainMatchType = domainMatchType
            
        case .urlPattern:
            if useRegex {
                rule.urlRegex = urlRegex
            } else {
                rule.urlContains = urlContains
            }
        }
        
        appState.addRule(rule)
        dismiss()
    }
    
    private var validationMessage: String {
        if targetBrowserId.isEmpty {
            return "Select a browser"
        }
        
        switch ruleType {
        case .sourceApp:
            return selectedApp == nil ? "Select an app" : ""
        case .domain:
            return domainPattern.isEmpty ? "Enter a domain" : ""
        case .urlPattern:
            if useRegex {
                if urlRegex.isEmpty {
                    return "Enter regex pattern"
                } else if regexError != nil {
                    return "Invalid regex"
                }
            } else if urlContains.isEmpty {
                return "Enter URL pattern"
            }
            return ""
        }
    }
}

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    let apps: [InstalledApp]
    @Binding var selectedApp: InstalledApp?
    @Binding var searchText: String
    @Environment(\.dismiss) var dismiss
    
    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Application")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Apps list
            if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Loading applications..." : "No applications found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppPickerRow(app: app) {
                                selectedApp = app
                                dismiss()
                            }
                            if app.id != filteredApps.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: UIConstants.addRuleSheetCompactWidth, height: UIConstants.addRuleSheetExpandedHeight)
    }
}

// MARK: - App Picker Row

struct AppPickerRow: View {
    let app: InstalledApp
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIConstants.largeIconSize, height: UIConstants.largeIconSize)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(app.bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Edit Rule Sheet

struct EditRuleSheet: View {
    let rule: Rule
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var ruleType: RuleType
    @State private var targetBrowserId: String
    
    // Source app fields
    @State private var sourceAppBundleId: String
    @State private var sourceAppName: String
    @State private var selectedApp: InstalledApp?
    @State private var showAppPicker = false
    @State private var installedApps: [InstalledApp] = []
    @State private var appSearchText: String = ""
    
    // Domain fields
    @State private var domainPattern: String
    @State private var domainMatchType: DomainMatchType
    
    // URL pattern fields
    @State private var urlContains: String
    @State private var useRegex: Bool = false
    @State private var urlRegex: String = ""
    @State private var regexError: String? = nil
    @State private var testURL: String = ""
    @State private var testResult: Bool? = nil

    // Privacy mode
    @State private var openInPrivateMode: Bool

    init(rule: Rule) {
        self.rule = rule

        // Initialize all state from the rule
        _ruleType = State(initialValue: rule.type)
        _targetBrowserId = State(initialValue: rule.targetBrowserId)

        // Source app
        _sourceAppBundleId = State(initialValue: rule.sourceAppBundleId ?? "")
        _sourceAppName = State(initialValue: rule.sourceAppName ?? "")

        // Domain
        _domainPattern = State(initialValue: rule.domainPattern ?? "")
        _domainMatchType = State(initialValue: rule.domainMatchType ?? .exact)

        // URL pattern
        _urlContains = State(initialValue: rule.urlContains ?? "")
        _urlRegex = State(initialValue: rule.urlRegex ?? "")
        _useRegex = State(initialValue: (rule.urlRegex != nil && !rule.urlRegex!.isEmpty))

        // Privacy mode
        _openInPrivateMode = State(initialValue: rule.openInPrivateMode)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Rule")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section("Rule Type") {
                    Picker("Type", selection: $ruleType) {
                        ForEach(RuleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Match Criteria") {
                    switch ruleType {
                    case .sourceApp:
                        VStack(alignment: .leading, spacing: 12) {
                            if let app = selectedApp {
                                // Show selected app
                                HStack(spacing: 12) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: UIConstants.largeIconSize, height: UIConstants.largeIconSize)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Text(app.bundleId)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Change") {
                                        showAppPicker = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 4)
                            } else {
                                // Show select button
                                Button(action: {
                                    showAppPicker = true
                                }) {
                                    Label("Select Application", systemImage: "plus.app")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                        
                    case .domain:
                        TextField("Domain (e.g., github.com)", text: $domainPattern)
                        Picker("Match Type", selection: $domainMatchType) {
                            ForEach([DomainMatchType.exact, .suffix, .contains], id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        
                    case .urlPattern:
                        Toggle("Use Regular Expression", isOn: $useRegex)
                            .help("Advanced: Match URLs using regex patterns")
                        
                        if useRegex {
                            TextField("Regular Expression", text: $urlRegex)
                                .help("e.g., ^https://github\\.com/[^/]+/[^/]+/pull")
                                .onChange(of: urlRegex) { _ in
                                    validateRegex()
                                    testResult = nil // Clear test result when pattern changes
                                }

                            if let error = regexError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Regex testing UI
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Pattern")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    TextField("Enter URL to test", text: $testURL)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: testURL) { _ in
                                            testResult = nil // Clear result when URL changes
                                        }

                                    Button("Test") {
                                        testRegexPattern()
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(urlRegex.isEmpty || regexError != nil || testURL.isEmpty)
                                }

                                if let result = testResult {
                                    HStack(spacing: 6) {
                                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(result ? .green : .orange)
                                        Text(result ? "Pattern matches" : "Pattern does not match")
                                            .font(.caption)
                                            .foregroundColor(result ? .green : .orange)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            TextField("URL contains (e.g., /docs/)", text: $urlContains)
                        }
                    }
                }
                
                Section("Target Browser") {
                    HStack {
                        Picker("Browser", selection: $targetBrowserId) {
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

                    Toggle("Open in private/incognito mode", isOn: $openInPrivateMode)
                        .help("Opens URLs in private/incognito window (not all browsers supported)")
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                // Validation feedback
                if !isValid {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Save Changes") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: UIConstants.addRuleSheetCompactWidth, height: UIConstants.addRuleSheetCompactHeight)
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(
                apps: installedApps,
                selectedApp: $selectedApp,
                searchText: $appSearchText
            )
        }
        .onAppear {
            // Load installed apps in background
            DispatchQueue.global(qos: .userInitiated).async {
                let apps = ApplicationScanner.shared.getInstalledApplications()
                DispatchQueue.main.async {
                    installedApps = apps
                    
                    // Pre-select the app if editing a sourceApp rule
                    if ruleType == .sourceApp, let bundleId = rule.sourceAppBundleId {
                        selectedApp = apps.first(where: { $0.bundleId == bundleId })
                    }
                }
            }
        }
    }
    
    private var isValid: Bool {
        // Must have target browser
        guard !targetBrowserId.isEmpty else { return false }
        
        switch ruleType {
        case .sourceApp:
            return selectedApp != nil
        case .domain:
            return !domainPattern.isEmpty
        case .urlPattern:
            if useRegex {
                return !urlRegex.isEmpty && regexError == nil
            } else {
                return !urlContains.isEmpty
            }
        }
    }
    
    private func validateRegex() {
        guard !urlRegex.isEmpty else {
            regexError = nil
            return
        }

        regexError = RegexValidator.validate(urlRegex)
    }

    private func testRegexPattern() {
        guard !urlRegex.isEmpty, !testURL.isEmpty, regexError == nil else {
            testResult = nil
            return
        }

        testResult = RegexValidator.test(urlRegex, against: testURL)
    }

    private var validationMessage: String {
        if targetBrowserId.isEmpty {
            return "Select a browser"
        }
        
        switch ruleType {
        case .sourceApp:
            return selectedApp == nil ? "Select an app" : ""
        case .domain:
            return domainPattern.isEmpty ? "Enter a domain" : ""
        case .urlPattern:
            if useRegex {
                if urlRegex.isEmpty {
                    return "Enter regex pattern"
                } else if regexError != nil {
                    return "Invalid regex"
                } else {
                    return ""
                }
            } else {
                return urlContains.isEmpty ? "Enter URL pattern" : ""
            }
        }
    }
    
    private func saveChanges() {
        var updatedRule = rule
        updatedRule.type = ruleType
        updatedRule.targetBrowserId = targetBrowserId
        updatedRule.openInPrivateMode = openInPrivateMode

        // Clear all match criteria first
        updatedRule.sourceAppBundleId = nil
        updatedRule.sourceAppName = nil
        updatedRule.domainPattern = nil
        updatedRule.domainMatchType = nil
        updatedRule.urlContains = nil
        updatedRule.urlRegex = nil
        
        // Set the appropriate fields based on rule type
        switch ruleType {
        case .sourceApp:
            if let app = selectedApp {
                updatedRule.sourceAppBundleId = app.bundleId
                updatedRule.sourceAppName = app.name
            }
            
        case .domain:
            updatedRule.domainPattern = domainPattern
            updatedRule.domainMatchType = domainMatchType
            
        case .urlPattern:
            if useRegex {
                updatedRule.urlRegex = urlRegex
            } else {
                updatedRule.urlContains = urlContains
            }
        }
        
        appState.updateRule(updatedRule)
        dismiss()
    }
}
