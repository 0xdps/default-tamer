//
//  PersistenceManager.swift
//  Default Tamer
//
//  UserDefaults-based storage with corruption recovery
//

import Foundation

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let defaults: UserDefaults
    private let schemaVersion = 1
    
    // Keys
    private let settingsKey = "defaultTamer.settings"
    private let rulesKey = "defaultTamer.rules"
    private let schemaVersionKey = "defaultTamer.schemaVersion"
    
    // Backup keys
    private let settingsBackupKey = "defaultTamer.settings.backup"
    private let rulesBackupKey = "defaultTamer.rules.backup"
    
    // File-based first-run sentinel (survives app updates, resets on full uninstall)
    private var setupCompleteURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("DefaultTamer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".setup_complete")
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        migrateIfNeeded()
    }
    
    private convenience init() {
        self.init(userDefaults: .standard)
    }
    
    // MARK: - Settings
    
    func saveSettings(_ settings: Settings) {
        // Backup current settings before overwriting
        if let currentData = defaults.data(forKey: settingsKey) {
            defaults.set(currentData, forKey: settingsBackupKey)
        }
        
        // Save new settings
        do {
            let encoded = try JSONEncoder().encode(settings)
            defaults.set(encoded, forKey: settingsKey)
            
            guard defaults.synchronize() else {
                throw AppError.persistence(reason: "Failed to synchronize UserDefaults")
            }
        } catch let error as AppError {
            Task { @MainActor in
                ErrorHandler.shared.handleCritical(error, context: "Save Settings")
            }
        } catch {
            let appError = AppError.persistence(reason: "Failed to encode settings: \(error.localizedDescription)")
            Task { @MainActor in
                ErrorHandler.shared.handleCritical(appError, context: "Save Settings")
            }
        }
    }
    
    func loadSettings() -> Settings {
        // Try to load current settings
        if let settings = loadSettingsFromKey(settingsKey) {
            return settings
        }
        
        // Current settings corrupt, try backup
        debugLog("⚠️ Settings corrupted, attempting recovery from backup...")
        if let settings = loadSettingsFromKey(settingsBackupKey) {
            debugLog("✅ Settings recovered from backup")
            // Restore backup to main key
            saveSettings(settings)
            
            let error = AppError.dataCorruption(dataType: "Settings", recovered: true)
            Task { @MainActor in
                ErrorHandler.shared.handle(error, context: "Load Settings", showToast: true)
            }
            return settings
        }
        
        // Both corrupt, use defaults
        debugLog("⚠️ Settings backup also corrupt, using defaults")
        let error = AppError.dataCorruption(dataType: "Settings", recovered: false)
        Task { @MainActor in
            ErrorHandler.shared.handleCritical(error, context: "Load Settings")
        }
        return Settings.default
    }
    
    private func loadSettingsFromKey(_ key: String) -> Settings? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            return settings
        } catch {
            debugLog("❌ Failed to decode settings from \(key): \(error)")
            return nil
        }
    }
    
    // MARK: - Rules
    
    func saveRules(_ rules: [Rule]) {
        // Backup current rules before overwriting
        if let currentData = defaults.data(forKey: rulesKey) {
            defaults.set(currentData, forKey: rulesBackupKey)
        }
        
        // Save new rules
        do {
            let encoded = try JSONEncoder().encode(rules)
            defaults.set(encoded, forKey: rulesKey)
            
            guard defaults.synchronize() else {
                throw AppError.persistence(reason: "Failed to synchronize UserDefaults")
            }
        } catch let error as AppError {
            Task { @MainActor in
                ErrorHandler.shared.handleCritical(error, context: "Save Rules")
            }
        } catch {
            let appError = AppError.persistence(reason: "Failed to encode rules: \(error.localizedDescription)")
            Task { @MainActor in
                ErrorHandler.shared.handleCritical(appError, context: "Save Rules")
            }
        }
    }
    
    func loadRules() -> [Rule] {
        // Try to load current rules
        if let rules = loadRulesFromKey(rulesKey) {
            return rules
        }
        
        // Current rules corrupt, try backup
        debugLog("⚠️ Rules corrupted, attempting recovery from backup...")
        if let rules = loadRulesFromKey(rulesBackupKey) {
            debugLog("✅ Rules recovered from backup")
            // Restore backup to main key
            saveRules(rules)
            
            let error = AppError.dataCorruption(dataType: "Routing Rules", recovered: true)
            Task { @MainActor in
                ErrorHandler.shared.handle(error, context: "Load Rules", showToast: true)
            }
            return rules
        }
        
        // Both corrupt, try partial recovery
        if let partialRules = attemptPartialRulesRecovery() {
            debugLog("✅ Partially recovered \(partialRules.count) rules")
            saveRules(partialRules)
            
            let error = AppError.dataCorruption(dataType: "Routing Rules", recovered: true)
            Task { @MainActor in
                ErrorHandler.shared.handle(error, context: "Partial Rules Recovery", showToast: true)
                ToastManager.shared.info("Recovered \(partialRules.count) rules from corrupted data")
            }
            return partialRules
        }
        
        // All recovery failed, start fresh
        debugLog("⚠️ Rules backup also corrupt, starting with empty rules")
        let error = AppError.dataCorruption(dataType: "Routing Rules", recovered: false)
        Task { @MainActor in
            ErrorHandler.shared.handleCritical(error, context: "Load Rules")
        }
        return []
    }
    
    private func loadRulesFromKey(_ key: String) -> [Rule]? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let rules = try JSONDecoder().decode([Rule].self, from: data)
            return rules
        } catch {
            debugLog("❌ Failed to decode rules from \(key): \(error)")
            return nil
        }
    }
    
    // MARK: - Partial Recovery
    
    private func attemptPartialRulesRecovery() -> [Rule]? {
        // Try to recover individual rules even if array is corrupt
        guard let data = defaults.data(forKey: rulesKey),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        var recoveredRules: [Rule] = []
        
        for (index, ruleDict) in jsonObject.enumerated() {
            do {
                let ruleData = try JSONSerialization.data(withJSONObject: ruleDict)
                let rule = try JSONDecoder().decode(Rule.self, from: ruleData)
                recoveredRules.append(rule)
            } catch {
                debugLog("   ⚠️ Skipping corrupt rule at index \(index)")
            }
        }
        
        return recoveredRules.isEmpty ? nil : recoveredRules
    }
    
    // MARK: - First Run
    
    var hasCompletedFirstRun: Bool {
        get {
            return FileManager.default.fileExists(atPath: setupCompleteURL.path)
        }
        set {
            if newValue {
                FileManager.default.createFile(atPath: setupCompleteURL.path, contents: nil)
            } else {
                try? FileManager.default.removeItem(at: setupCompleteURL)
            }
        }
    }
    
    // MARK: - Migration
    
    private func migrateIfNeeded() {
        let currentVersion = defaults.integer(forKey: schemaVersionKey)
        
        if currentVersion < schemaVersion {
            // Perform migrations here in future versions
            defaults.set(schemaVersion, forKey: schemaVersionKey)
        }
        
        // Migrate hasCompletedFirstRun from UserDefaults to file sentinel (one-time)
        let legacyKey = "defaultTamer.hasCompletedFirstRun"
        if defaults.bool(forKey: legacyKey) && !hasCompletedFirstRun {
            hasCompletedFirstRun = true
            defaults.removeObject(forKey: legacyKey)
        }
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        defaults.removeObject(forKey: settingsKey)
        defaults.removeObject(forKey: rulesKey)
        defaults.removeObject(forKey: settingsBackupKey)
        defaults.removeObject(forKey: rulesBackupKey)
        hasCompletedFirstRun = false
    }
}
