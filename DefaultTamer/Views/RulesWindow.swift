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
            if let rule = selectedRule {
                RuleDetailView(rule: rule)
                    .environmentObject(appState)
            } else {
                EmptyRuleDetail(onAddRule: { showAddRule = true })
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet()
                .environmentObject(appState)
                .environmentObject(LicensingManager.shared)
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
                VStack(spacing: 12) {
                    Text("No rules yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Add Rule") { showAddRule = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(typeColor.opacity(rule.enabled ? 0.15 : 0.07))
                    .frame(width: 30, height: 30)
                Image(systemName: typeIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(rule.enabled ? typeColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ruleName)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(rule.enabled ? .primary : .secondary)
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
            } else if let browser = appState.browserManager.getBrowser(byId: rule.targetBrowserId),
                      let icon = browser.getIcon() {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.vertical, 3)
    }

    private var typeIcon: String {
        switch rule.type {
        case .sourceApp:  return "app.badge"
        case .domain:     return "globe"
        case .urlPattern: return "link"
        case .shortcut:   return "keyboard"
        }
    }

    private var typeColor: Color {
        switch rule.type {
        case .sourceApp:  return .orange
        case .domain:     return .blue
        case .urlPattern: return .purple
        case .shortcut:   return .teal
        }
    }

    private var ruleName: String {
        switch rule.type {
        case .sourceApp:  return rule.sourceAppName ?? rule.sourceAppBundleId ?? "Source App"
        case .domain:     return rule.domainPattern ?? "Domain"
        case .urlPattern: return rule.urlContains ?? rule.urlRegex ?? "URL Pattern"
        case .shortcut:   return ShortcutFormatter.format(keyCode: rule.shortcutKeyCode, modifiers: rule.shortcutModifiers)
        }
    }
}

// Detail view for selected rule
struct RuleDetailView: View {
    let rule: Rule
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    private var currentRule: Rule? {
        appState.rules.first(where: { $0.id == rule.id })
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────────────
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(typeColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: typeIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(typeColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(ruleName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(rule.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { currentRule?.enabled ?? false },
                    set: { _ in appState.toggleRule(rule) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(currentRule?.enabled == true ? "Disable rule" : "Enable rule")
            }
            .padding(20)

            Divider()

            // ── Info cards ─────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 12) {
                    DetailCard(label: "Match Criteria", icon: "scope") {
                        matchCriteriaContent
                    }

                    if let browser = appState.browserManager.getBrowser(byId: rule.targetBrowserId) {
                        DetailCard(label: "Opens In", icon: "safari") {
                            HStack(spacing: 10) {
                                if let icon = browser.getIcon() {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(browser.displayName).font(.body)
                                    if rule.openInPrivateMode {
                                        Text("Private / incognito mode")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if !appState.browserManager.isBrowserAvailable(rule.targetBrowserId) {
                                    Label("Not installed", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // ── Action bar ─────────────────────────────────────────────
            HStack(spacing: 10) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .help("Delete rule")

                Spacer()

                Button("Duplicate") { duplicateRule() }
                    .buttonStyle(.bordered)

                Button("Edit Rule") { showEditSheet = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showEditSheet) {
            EditRuleSheet(rule: rule)
                .environmentObject(appState)
                .environmentObject(LicensingManager.shared)
        }
        .alert("Delete Rule?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { appState.deleteRule(rule) }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var matchCriteriaContent: some View {
        switch rule.type {
        case .sourceApp:
            HStack(spacing: 10) {
                Image(systemName: "app.badge").foregroundColor(.orange).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.sourceAppName ?? "Unknown App").font(.body)
                    if let bundleId = rule.sourceAppBundleId {
                        Text(bundleId).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        case .domain:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "globe").foregroundColor(.blue).frame(width: 20)
                    Text(rule.domainPattern ?? "")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                }
                if let matchType = rule.domainMatchType {
                    HStack {
                        Text("Match type").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(matchType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        case .urlPattern:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: rule.urlRegex != nil ? "chevron.left.forwardslash.chevron.right" : "link")
                        .foregroundColor(.purple).frame(width: 20)
                    Text(rule.urlRegex ?? rule.urlContains ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                }
                if rule.urlRegex != nil {
                    Text("Regular expression").font(.caption).foregroundColor(.secondary)
                }
            }
        case .shortcut:
            HStack(spacing: 10) {
                Image(systemName: "keyboard").foregroundColor(.teal).frame(width: 20)
                Text(ShortcutFormatter.format(keyCode: rule.shortcutKeyCode, modifiers: rule.shortcutModifiers))
                    .font(.system(.body, design: .monospaced))
                Spacer()
            }
        }
    }

    private var typeIcon: String {
        switch rule.type {
        case .sourceApp:  return "app.badge"
        case .domain:     return "globe"
        case .urlPattern: return "link"
        case .shortcut:   return "keyboard"
        }
    }

    private var typeColor: Color {
        switch rule.type {
        case .sourceApp:  return .orange
        case .domain:     return .blue
        case .urlPattern: return .purple
        case .shortcut:   return .teal
        }
    }

    private var ruleName: String {
        switch rule.type {
        case .sourceApp:  return rule.sourceAppName ?? rule.sourceAppBundleId ?? "Source App"
        case .domain:     return rule.domainPattern ?? "Domain Rule"
        case .urlPattern: return rule.urlContains ?? rule.urlRegex ?? "URL Pattern"
        case .shortcut:   return ShortcutFormatter.format(keyCode: rule.shortcutKeyCode, modifiers: rule.shortcutModifiers)
        }
    }

    private func duplicateRule() {
        var ruleToAdd = Rule(id: UUID(), type: rule.type, enabled: rule.enabled, targetBrowserId: rule.targetBrowserId)
        ruleToAdd.sourceAppBundleId  = rule.sourceAppBundleId
        ruleToAdd.sourceAppName      = rule.sourceAppName
        ruleToAdd.domainPattern      = rule.domainPattern
        ruleToAdd.domainMatchType    = rule.domainMatchType
        ruleToAdd.urlContains        = rule.urlContains
        ruleToAdd.urlRegex           = rule.urlRegex
        ruleToAdd.openInPrivateMode  = rule.openInPrivateMode
        ruleToAdd.shortcutKeyCode    = rule.shortcutKeyCode
        ruleToAdd.shortcutModifiers  = rule.shortcutModifiers
        appState.addRule(ruleToAdd)
    }
}

// Empty state for the detail panel
struct EmptyRuleDetail: View {
    var onAddRule: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No Rule Selected")
                .font(.headline)
            Text("Select a rule from the list, or add a new one to start routing links.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            if let onAddRule {
                Button("Add Rule") { onAddRule() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Card component used in RuleDetailView
struct DetailCard<Content: View>: View {
    let label: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
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
                .environmentObject(LicensingManager.shared)
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
        case .sourceApp:  return "app.badge"
        case .domain:     return "globe"
        case .urlPattern: return "link"
        case .shortcut:   return "keyboard"
        }
    }
}

