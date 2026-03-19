//
//  RulesWindow.swift
//  Default Tamer
//
//  Rules management window content
//

import SwiftUI

// New window content - no dismiss, designed for standalone window
struct RulesWindowContent: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddRule = false
    @State private var selectedRule: Rule?
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - rules list
            RulesSidebar(selectedRule: $selectedRule, showAddRule: $showAddRule)
                .environmentObject(appState)
        } detail: {
            // Detail pane - selected rule details
            if let rule = selectedRule {
                RuleDetailView(rule: rule)
                    .environmentObject(appState)
            } else {
                EmptyRuleDetail()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet()
                .environmentObject(appState)
        }
        .onAppear {
            // Select first rule if available
            if selectedRule == nil, let first = appState.rules.first {
                selectedRule = first
            }
        }
    }
}

// Sidebar with rules list
struct RulesSidebar: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedRule: Rule?
    @Binding var showAddRule: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with add/remove buttons
            HStack {
                Text("Rules")
                    .font(.headline)
                Spacer()
                Button(action: { showAddRule = true }) {
                    Image(systemName: "plus")
                }
                .help("Add Rule")
                Button(action: deleteSelectedRule) {
                    Image(systemName: "minus")
                }
                .disabled(selectedRule == nil)
                .help("Delete Rule")
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
        .frame(minWidth: 180)
    }
    
    private func deleteSelectedRule() {
        guard let rule = selectedRule else { return }
        appState.deleteRule(rule)
        selectedRule = appState.rules.first
    }
}

// Compact row for sidebar
struct RuleSidebarRow: View {
    let rule: Rule
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(rule.enabled ? .green : .secondary)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ruleName)
                    .font(.body)
                    .lineLimit(1)
                Text(rule.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !appState.browserManager.isBrowserAvailable(rule.targetBrowserId) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .help("Target browser is not installed. This rule is inactive.")
            }
        }
        .padding(.vertical, 2)
    }
    
    private var ruleName: String {
        // Generate a short name for the rule
        switch rule.type {
        case .sourceApp:
            return rule.sourceAppName ?? rule.sourceAppBundleId ?? "Source App"
        case .domain:
            return rule.domainPattern ?? "Domain"
        case .urlPattern:
            return rule.urlContains ?? "URL Pattern"
        }
    }
}

// Detail view for selected rule
struct RuleDetailView: View {
    let rule: Rule
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    
    // Computed property to get the current state of the rule
    private var currentRule: Rule? {
        appState.rules.first(where: { $0.id == rule.id })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Rule Type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rule Type")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(rule.type.rawValue)
                        .font(.body)
                }
                
                Divider()
                
                // Match Criteria
                VStack(alignment: .leading, spacing: 8) {
                    Text("Match Criteria")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    switch rule.type {
                    case .sourceApp:
                        if let appName = rule.sourceAppName {
                            HStack {
                                Text("App Name:")
                                    .foregroundColor(.secondary)
                                Text(appName)
                            }
                        }
                        if let bundleId = rule.sourceAppBundleId {
                            HStack {
                                Text("Bundle ID:")
                                    .foregroundColor(.secondary)
                                Text(bundleId)
                                    .font(.caption)
                            }
                        }
                        
                    case .domain:
                        if let pattern = rule.domainPattern {
                            HStack {
                                Text("Domain:")
                                    .foregroundColor(.secondary)
                                Text(pattern)
                            }
                        }
                        if let matchType = rule.domainMatchType {
                            HStack {
                                Text("Match Type:")
                                    .foregroundColor(.secondary)
                                Text(matchType.rawValue)
                            }
                        }
                        
                    case .urlPattern:
                        if let contains = rule.urlContains {
                            HStack {
                                Text("URL Contains:")
                                    .foregroundColor(.secondary)
                                Text(contains)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Target Browser
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Browser")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let browser = appState.browserManager.getBrowser(byId: rule.targetBrowserId) {
                        HStack {
                            if let icon = browser.getIcon() {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Text(browser.displayName)
                        }
                    }
                }
                
                Divider()
                
                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Toggle("Enabled", isOn: Binding(
                        get: { currentRule?.enabled ?? false },
                        set: { _ in appState.toggleRule(rule) }
                    ))
                    .toggleStyle(.switch)
                }
                
                Divider()
                
                // Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("Edit") {
                            showEditSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Duplicate") {
                            duplicateRule()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Delete Rule", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showEditSheet) {
            EditRuleSheet(rule: rule)
                .environmentObject(appState)
        }
        .alert("Delete Rule?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                appState.deleteRule(rule)
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func duplicateRule() {
        // Create a new rule with a new ID but same properties
        let newRule = Rule(
            id: UUID(),
            type: rule.type,
            enabled: rule.enabled,
            targetBrowserId: rule.targetBrowserId
        )
        // Copy the match criteria based on type
        var ruleToAdd = newRule
        ruleToAdd.sourceAppBundleId = rule.sourceAppBundleId
        ruleToAdd.sourceAppName = rule.sourceAppName
        ruleToAdd.domainPattern = rule.domainPattern
        ruleToAdd.domainMatchType = rule.domainMatchType
        ruleToAdd.urlContains = rule.urlContains
        ruleToAdd.urlRegex = rule.urlRegex
        
        appState.addRule(ruleToAdd)
    }
}

// Empty state for detail view
struct EmptyRuleDetail: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Rule Selected")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Select a rule from the sidebar to view details")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Legacy sheet-based view (keep for now if needed)
struct RulesWindow: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddRule = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Routing Rules")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showAddRule = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Rules list
            if appState.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No rules yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add a rule to start routing links")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.rules) { rule in
                        RuleRow(rule: rule)
                            .environmentObject(appState)
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
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: UIConstants.rulesWindowWidth, height: UIConstants.rulesWindowHeight)
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet()
                .environmentObject(appState)
        }
    }
}

struct RuleRow: View {
    let rule: Rule
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Enabled toggle
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in appState.toggleRule(rule) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            
            // Rule icon
            Image(systemName: ruleIcon)
                .foregroundColor(rule.enabled ? .accentColor : .secondary)
                .frame(width: 20)
            
            // Rule description
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.description(browsers: appState.browserManager.availableBrowsers))
                    .font(.body)
                    .foregroundColor(rule.enabled ? .primary : .secondary)
                
                Text(rule.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Target browser icon
            if let browser = appState.browserManager.getBrowser(byId: rule.targetBrowserId),
               let icon = browser.getIcon() {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: UIConstants.browserIconSize, height: UIConstants.browserIconSize)
            }
            
            // Delete button
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Delete rule")
        }
        .padding(.vertical, 4)
        .alert("Delete Rule?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                appState.deleteRule(rule)
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private var ruleIcon: String {
        switch rule.type {
        case .sourceApp:
            return "app.badge"
        case .domain:
            return "globe"
        case .urlPattern:
            return "link"
        }
    }
}

