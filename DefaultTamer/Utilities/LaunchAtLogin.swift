//
//  LaunchAtLogin.swift
//  Default Tamer
//
//  SMAppService wrapper for launch at login
//

import Foundation
import ServiceManagement

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private init() {}
    
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback for older macOS versions
            return false
        }
    }
    
    func enable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
        } else {
            throw LaunchAtLoginError.unsupportedOS
        }
    }
    
    func disable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
        } else {
            throw LaunchAtLoginError.unsupportedOS
        }
    }
    
    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}

enum LaunchAtLoginError: Error {
    case unsupportedOS
    case registrationFailed
}
