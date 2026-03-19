//
//  AnalyticsManager.swift
//  Default Tamer
//
//  Minimal, privacy-first telemetry for Umami
//

import Foundation
import AppKit

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private let umamiURL = AnalyticsConfig.umamiURL
    private let websiteID = AnalyticsConfig.websiteID
    
    private init() {}
    
    /// Sends an anonymous event to Umami if telemetry is enabled
    @MainActor
    func sendEvent(name: String, data: [String: Any]? = nil, completion: ((Bool) -> Void)? = nil) {
        // Prefer in-memory settings (fast path, avoids disk decode per event)
        let telemetryEnabled = (NSApp.delegate as? AppDelegate)?.appState.settings.telemetryEnabled
            ?? PersistenceManager.shared.loadSettings().telemetryEnabled
        
        guard telemetryEnabled == true else {
            let msg = "SKIP event '\(name)' — telemetryEnabled=\(String(describing: telemetryEnabled))"
            UnifiedLogger.debug("Analytics: \(msg)", category: .network)
            Self.writeDebugLog(msg)
            completion?(false)
            return
        }
        
        let installID = PersistenceManager.shared.installID
        
        var eventData = data ?? [:]
        eventData["install_id"] = installID
        
        let payload: [String: Any] = [
            "website": websiteID,
            "hostname": "defaulttamer.app",
            "url": "/app/\(name)",
            "language": Locale.current.identifier,
            "browser": "DefaultTamer",
            "title": name,
            "name": name,
            "data": eventData
        ]
        
        let body: [String: Any] = [
            "type": "event",
            "payload": payload
        ]
        
        guard let url = URL(string: "\(umamiURL)/api/send"),
              let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Required for Umami to accept the request correctly sometimes
        request.setValue("DefaultTamer/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                let msg = "FAIL event '\(name)' — \(error.localizedDescription)"
                UnifiedLogger.debug("Analytics: \(msg)", category: .network)
                Self.writeDebugLog(msg)
                completion?(false)
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let msg = "FAIL event '\(name)' — HTTP \(httpResponse.statusCode)"
                UnifiedLogger.debug("Analytics: \(msg)", category: .network)
                Self.writeDebugLog(msg)
                completion?(false)
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let msg = "OK event '\(name)' — HTTP \(statusCode)"
            UnifiedLogger.debug("Analytics: \(msg)", category: .network)
            Self.writeDebugLog(msg)
            completion?(true)
        }
        // Async fire-and-forget
        task.resume()
    }
    
    // MARK: - Helper for Buckets
    
    static func getBucket(for count: Int) -> String {
        switch count {
        case 0: return "0"
        case 1...3: return "1-3"
        case 4...10: return "4-10"
        case 11...50: return "11-50"
        default: return "50+"
        }
    }
    
    // MARK: - Debug File Log
    
    private static let debugLogURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DefaultTamer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("analytics_debug.log")
    }()
    
    static func writeDebugLog(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        
        do {
            if FileManager.default.fileExists(atPath: debugLogURL.path) {
                let handle = try FileHandle(forWritingTo: debugLogURL)
                handle.seekToEndOfFile()
                try handle.write(contentsOf: data)
                handle.closeFile()
            } else {
                try data.write(to: debugLogURL)
            }
        } catch {
            // File logging is best-effort; failures are non-critical
            debugLog("⚠️ Analytics debug log write failed: \(error.localizedDescription)")
        }
    }
}
