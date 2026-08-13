//
//  DebugLog.swift
//
//  Logging wrapper that routes through the unified logging system (os.Logger)
//  in both debug and release builds.
//
//  In release, messages are captured by the OS but not printed to stdout.
//  They can be viewed in Console.app under subsystem "com.defaulttamer.app".
//  This makes it possible to diagnose user issues from sysdiagnose logs
//  without shipping a debug build.
//

import Foundation
import os.log

/// General-purpose logger for debug/diagnostic messages.
/// Uses the "debug" category so it's easy to filter in Console.app.
private let debugLogger = Logger(subsystem: "com.defaulttamer.app", category: "debug")

/// Logs a debug-level message through the unified logging system.
/// Visible in Console.app (subsystem: com.defaulttamer.app) in all builds.
func debugLog(_ message: String) {
    debugLogger.debug("\(message, privacy: .public)")
}
