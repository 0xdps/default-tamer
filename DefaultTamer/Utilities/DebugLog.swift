//
//  DebugLog.swift
//  Default Tamer
//
//  Debug-only logging wrapper
//

import Foundation

#if DEBUG
func debugLog(_ message: String) {
    print(message)
}
#else
func debugLog(_ message: String) {}
#endif
