//
//  UnifiedLogger.swift
//  Default Tamer
//
//  Unified logging system with severity levels and categories
//

import Foundation
import OSLog

/// Centralized logging system for the app
enum UnifiedLogger {
    
    // MARK: - Log Levels
    
    enum Level {
        case debug
        case info
        case warning
        case error
        case critical
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - Log Categories
    
    enum Category: String {
        case general = "General"
        case routing = "Routing"
        case browser = "Browser"
        case persistence = "Persistence"
        case database = "Database"
        case security = "Security"
        case network = "Network"
        case ui = "UI"
        case performance = "Performance"
        
        var subsystem: String {
            "com.defaulttamer.app"
        }
        
        var logger: Logger {
            Logger(subsystem: subsystem, category: rawValue)
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message
    static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Log an informational message
    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Log a critical error message
    static func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Internal Implementation
    
    private static func log(
        _ message: String,
        level: Level,
        category: Category,
        file: String,
        function: String,
        line: Int
    ) {
        let logger = category.logger
        let fileName = (file as NSString).lastPathComponent
        
        // Format message with context
        let formattedMessage = "[\(category.rawValue)] \(message)"
        
        #if DEBUG
        // In debug, also print to console with rich formatting
        let debugMessage = "\(level.emoji) [\(category.rawValue)] \(message) (\(fileName):\(line))"
        print(debugMessage)
        #endif
        
        // Always log to OSLog for Console.app and Instruments
        logger.log(level: level.osLogType, "\(formattedMessage, privacy: .public)")
    }
}

// MARK: - Convenience Extensions

extension UnifiedLogger {
    /// Log routing decisions
    static func route(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .routing, file: file, function: function, line: line)
    }
    
    /// Log browser operations
    static func browser(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .browser, file: file, function: function, line: line)
    }
    
    /// Log persistence operations
    static func persistence(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .persistence, file: file, function: function, line: line)
    }
    
    /// Log database operations
    static func database(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .database, file: file, function: function, line: line)
    }
    
    /// Log performance metrics
    static func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: .performance, file: file, function: function, line: line)
    }
}
