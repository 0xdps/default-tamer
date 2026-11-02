//
//  DefaultTamerApp.swift
//  Default Tamer
//
//  Main app entry point
//

import SwiftUI

@main
struct DefaultTamerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var appState: AppState {
        appDelegate.appState
    }
    
    var body: some Scene {
        // Menu bar app - windows managed by AppDelegate
        // Using Settings scene to avoid automatic window creation
        SwiftUI.Settings {
            EmptyView()
        }
        .commands {
            // App Menu additions (Check for Updates below About)
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
            }

            // View Menu (Tabs navigation inside the single system View menu)
            CommandGroup(before: .toolbar) {
                Button("General Settings") {
                    appDelegate.openPreferences()
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Rules") {
                    appDelegate.openRules()
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Activity") {
                    appDelegate.openActivity()
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("About") {
                    appDelegate.openAbout()
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Power Plan") {
                    appDelegate.openUpgrade()
                }
                .keyboardShortcut("5", modifiers: .command)

                Divider()
            }

            // Help Menu
            CommandGroup(replacing: .help) {
                Button("Default Tamer Help") {
                    appDelegate.openHelp()
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Default Tamer Website") {
                    appDelegate.openWebsite()
                }

                Button("Report an Issue…") {
                    appDelegate.openReportIssue()
                }
            }
        }
    }
}
