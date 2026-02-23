//
//  AppError.swift
//  Default Tamer
//
//  Unified error types for the application
//

import Foundation

enum AppError: LocalizedError {
    case persistence(reason: String)
    case invalidRule(reason: String)
    case invalidRegex(pattern: String, error: String)
    case browserUnavailable(browserId: String, browserName: String?)
    case browserOperationFailed(operation: String, browserId: String, underlying: Error)
    case databaseError(reason: String, underlying: Error?)
    case databaseMigrationFailed(version: Int, error: Error)
    case networkError(reason: String, underlying: Error?)
    case updateCheckFailed(reason: String)
    case bundleIdResolutionFailed(appName: String)
    case dataCorruption(dataType: String, recovered: Bool)
    
    var errorDescription: String? {
        switch self {
        case .persistence(let reason):
            return "Failed to save settings: \(reason)"
        case .invalidRule(let reason):
            return "Invalid rule: \(reason)"
        case .invalidRegex(let pattern, let error):
            return "Invalid regular expression '\(pattern)': \(error)"
        case .browserUnavailable(let browserId, let browserName):
            let name = browserName ?? browserId
            return "Browser '\(name)' is not available"
        case .browserOperationFailed(let operation, let browserId, let underlying):
            return "Failed to \(operation) with browser '\(browserId)': \(underlying.localizedDescription)"
        case .databaseError(let reason, _):
            return "Database error: \(reason)"
        case .databaseMigrationFailed(let version, let error):
            return "Failed to migrate database to version \(version): \(error.localizedDescription)"
        case .networkError(let reason, _):
            return "Network error: \(reason)"
        case .updateCheckFailed(let reason):
            return "Update check failed: \(reason)"
        case .bundleIdResolutionFailed(let appName):
            return "Could not find bundle ID for app '\(appName)'"
        case .dataCorruption(let dataType, let recovered):
            if recovered {
                return "Data corruption detected in \(dataType), successfully recovered from backup"
            } else {
                return "Data corruption detected in \(dataType), unable to recover"
            }
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .persistence:
            return "Your settings changes may not be saved. Try restarting the app or checking available disk space."
        case .invalidRule:
            return "Please check your rule configuration and ensure all fields are valid."
        case .invalidRegex:
            return "Check your regular expression syntax. Avoid nested quantifiers and excessive grouping."
        case .browserUnavailable:
            return "Install the browser or select a different one in your routing rules."
        case .browserOperationFailed:
            return "Try opening the URL manually in your preferred browser, or restart the app."
        case .databaseError:
            return "Try restarting the app. If the problem persists, you may need to reset the activity database."
        case .databaseMigrationFailed:
            return "The app will restore from a backup. Your recent activity logs may be lost."
        case .networkError:
            return "Check your internet connection and try again."
        case .updateCheckFailed:
            return "Check your internet connection. You can manually check for updates at https://github.com/0xdps/default-tamer/releases"
        case .bundleIdResolutionFailed:
            return "Ensure the application is installed in /Applications or ~/Applications."
        case .dataCorruption(_, let recovered):
            if recovered {
                return "Your data has been restored from the most recent backup."
            } else {
                return "The app will use default settings. You may need to reconfigure your preferences."
            }
        }
    }
    
    var severity: Severity {
        switch self {
        case .persistence, .databaseError, .databaseMigrationFailed, .dataCorruption(_, false):
            return .critical
        case .browserUnavailable, .browserOperationFailed, .bundleIdResolutionFailed:
            return .high
        case .invalidRule, .invalidRegex, .networkError, .updateCheckFailed:
            return .medium
        case .dataCorruption(_, true):
            return .low
        }
    }
    
    enum Severity {
        case critical  // Data loss, app unusable
        case high      // Core functionality broken
        case medium    // Degraded functionality
        case low       // Minor inconvenience
        
        var icon: String {
            switch self {
            case .critical:
                return "xmark.octagon.fill"
            case .high:
                return "exclamationmark.triangle.fill"
            case .medium:
                return "exclamationmark.circle.fill"
            case .low:
                return "info.circle.fill"
            }
        }
    }
}
