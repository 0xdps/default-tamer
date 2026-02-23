//
//  ErrorHandler.swift
//  Default Tamer
//
//  Centralized error handling and logging
//

import Foundation
import OSLog

@MainActor
class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    /// Handle an error with optional context
    func handle(_ error: Error, context: String = "", showToast: Bool = false) {
        let appError = error as? AppError
        let severity = appError?.severity ?? .high
        
        // Log the error
        logError(error, context: context, severity: severity)
        
        // Show user notification if requested
        if showToast {
            showToastForError(appError ?? error, context: context)
        }
        
        // Show system notification for critical errors
        if severity == .critical {
            showSystemNotification(for: appError ?? error)
        }
    }
    
    /// Handle a critical error (logs + notifies user + records in database)
    func handleCritical(_ error: Error, context: String = "") {
        let appError = error as? AppError
        
        // Log the error
        logError(error, context: context, severity: .critical)
        
        // Record in diagnostic database if available
        recordInDatabase(error, context: context)
        
        // Always notify user for critical errors
        showSystemNotification(for: appError ?? error)
    }
    
    /// Convenience method for handling AppError
    func handle(_ appError: AppError, context: String = "", showToast: Bool = true) {
        handle(appError as Error, context: context, showToast: showToast)
    }
    
    // MARK: - Private Methods
    
    private func logError(_ error: Error, context: String, severity: AppError.Severity) {
        let prefix = severityPrefix(severity)
        let contextStr = context.isEmpty ? "" : " [\(context)]"
        
        #if DEBUG
        print("\(prefix)\(contextStr) \(error.localizedDescription)")
        if let appError = error as? AppError, let suggestion = appError.recoverySuggestion {
            print("  ↳ \(suggestion)")
        }
        #endif
        
        // Log to unified logging system
        switch severity {
        case .critical:
            appLogger.fault("\(contextStr, privacy: .public) \(error.localizedDescription, privacy: .public)")
        case .high:
            appLogger.error("\(contextStr, privacy: .public) \(error.localizedDescription, privacy: .public)")
        case .medium:
            appLogger.warning("\(contextStr, privacy: .public) \(error.localizedDescription, privacy: .public)")
        case .low:
            appLogger.info("\(contextStr, privacy: .public) \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func severityPrefix(_ severity: AppError.Severity) -> String {
        switch severity {
        case .critical:
            return "💥"
        case .high:
            return "❌"
        case .medium:
            return "⚠️"
        case .low:
            return "ℹ️"
        }
    }
    
    private func showToastForError(_ error: Error, context: String) {
        let appError = error as? AppError
        let severity = appError?.severity ?? .high
        
        let message: String
        if let appError = appError {
            message = appError.errorDescription ?? error.localizedDescription
        } else {
            message = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        }
        
        switch severity {
        case .critical:
            ToastManager.shared.error(message, duration: 5.0)
        case .high:
            ToastManager.shared.error(message, duration: 4.0)
        case .medium:
            ToastManager.shared.warning(message, duration: 3.0)
        case .low:
            ToastManager.shared.info(message, duration: 2.5)
        }
    }
    
    private func showSystemNotification(for error: Error) {
        let appError = error as? AppError
        let title: String
        let message: String
        
        if let appError = appError {
            title = "Error"
            message = appError.errorDescription ?? error.localizedDescription
            
            if let suggestion = appError.recoverySuggestion {
                ErrorNotifier.shared.notifyError(title, message: "\(message)\n\n\(suggestion)")
            } else {
                ErrorNotifier.shared.notifyError(title, message: message)
            }
        } else {
            ErrorNotifier.shared.notifyError("Error", message: error.localizedDescription)
        }
    }
    
    private func recordInDatabase(_ error: Error, context: String) {
        // Only record if diagnostics is enabled
        // ActivityDatabase will handle this
        Task {
            // Future: Add error logging to database
            // ActivityDatabase.shared.logError(error: error, context: context)
        }
    }
}

// MARK: - Convenience Extensions

extension Error {
    /// Convert any error to AppError if possible, otherwise wrap it
    func asAppError(fallback: String = "An error occurred") -> AppError {
        if let appError = self as? AppError {
            return appError
        }
        return .databaseError(reason: fallback, underlying: self)
    }
}
