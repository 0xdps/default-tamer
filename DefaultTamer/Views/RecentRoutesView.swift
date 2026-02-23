//
//  RecentRoutesView.swift
//  Default Tamer
//
//  Diagnostics view for recent routes
//

import SwiftUI

struct RecentRoutesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Routes")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Clear") {
                    appState.diagnosticsManager.clearLogs()
                }
                .disabled(appState.diagnosticsManager.recentRoutes.isEmpty)
            }
            .padding()
            
            Divider()
            
            // Routes list
            if appState.diagnosticsManager.recentRoutes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No routes yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Routes will appear here when diagnostics is enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(appState.diagnosticsManager.recentRoutes) {
                    TableColumn("Time") { log in
                        Text(log.formattedTimestamp())
                            .font(.caption)
                    }
                    .width(min: 120, ideal: 140)
                    
                    TableColumn("URL") { log in
                        Text(log.urlHost)
                            .font(.caption)
                    }
                    
                    TableColumn("Source") { log in
                        if let sourceApp = log.sourceApp {
                            Text(SourceAppDetector.displayName(for: sourceApp))
                                .font(.caption)
                        } else {
                            Text("Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(min: UIConstants.tableColumnMinWidth, ideal: UIConstants.tableColumnIdealWidth)
                    
                    TableColumn("Rule") { log in
                        if log.matchedRuleType == "Override" {
                            Text("Override")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if let ruleType = log.matchedRuleType {
                            Text(ruleType)
                                .font(.caption)
                        } else if log.fallbackUsed {
                            Text("Fallback")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("—")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(min: UIConstants.tableColumnMinWidth, ideal: UIConstants.tableColumnIdealWidth)
                    
                    TableColumn("Browser") { log in
                        if let browser = appState.browserManager.getBrowser(byId: log.targetBrowserId) {
                            HStack(spacing: 4) {
                                if let icon = browser.getIcon() {
                                    Image(nsImage: icon)
                                        .renderingMode(.original)
                                        .resizable()
                                        .frame(width: 12, height: 12)
                                }
                                Text(browser.displayName)
                                    .font(.caption)
                            }
                        }
                    }
                    .width(min: UIConstants.tableColumnMinWidth, ideal: UIConstants.tableColumnIdealWidth)
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(appState.diagnosticsManager.recentRoutes.count) route\(appState.diagnosticsManager.recentRoutes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 700, height: 500)
    }
}

