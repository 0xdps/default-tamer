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
    }
}
