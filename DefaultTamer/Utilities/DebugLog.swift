//
//  DebugLog.swift
//  Default Tamer
//
//  Debug-only logging wrapper
//

import Foundation
import os.log

struct DebugLog {
    private static let logger = Logger(subsystem: "com.defaulttamer.app", category: "menu")
    
    static func menu(_ message: String) {
        #if DEBUG
        logger.info("\\(message, privacy: .public)")
        #endif
    }
}

// Keep old function for backward compatibility
#if DEBUG
func debugLog(_ message: String) {
    print(message)
}
#else
func debugLog(_ message: String) {}
#endif
