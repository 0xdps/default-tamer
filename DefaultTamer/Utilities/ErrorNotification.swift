//
//  ErrorNotification.swift
//  Default Tamer
//
//  User-facing error notifications
//

import SwiftUI
import UserNotifications

@MainActor
class ErrorNotifier {
    static let shared = ErrorNotifier()
    
    private var hasRequestedPermission = false
    
    private init() {}
    
    /// Requests notification permission lazily — only when the first error
    /// actually needs to be shown, not at singleton initialization time.
    private func ensurePermissionRequested() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, error in
            if let error = error {
                debugLog("Failed to request notification permissions: \(error)")
            }
        }
    }
    
    func notifyError(_ title: String, message: String) {
        ensurePermissionRequested()
        #if DEBUG
        // In debug, also print
        debugLog("ERROR: \(title) - \(message)")
        #endif
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("Failed to send notification: \(error)")
            }
        }
    }
    
    func notifyWarning(_ title: String, message: String) {
        ensurePermissionRequested()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
