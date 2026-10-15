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
    private let customSetupCompleteURL: URL?

    // Keys
    private let settingsKey = "defaultTamer.settings"
    private let rulesKey = "defaultTamer.rules"
    private let schemaVersionKey = "defaultTamer.schemaVersion"

    private let settingsBackupKey = "defaultTamer.settings.backup"
    private let rulesBackupKey = "defaultTamer.rules.backup"
    private let installIdKey = "defaultTamer.install_id"
    private let lastVersionKey = "defaultTamer.lastVersion"
    private let lastLaunchDateKey = "defaultTamer.lastLaunchDate"

    // File-based first-run sentinel (survives app updates, resets on full uninstall)
    private var setupCompleteURL: URL {
        if let custom = customSetupCompleteURL { return custom }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("DefaultTamer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".setup_complete")
    }

    init(userDefaults: UserDefaults = .standard, setupCompleteURL: URL? = nil) {
        self.defaults = userDefaults
        self.customSetupCompleteURL = setupCompleteURL
        migrateIfNeeded()
        // Migrate rules from UserDefaults to SQLite if needed
        Task { @MainActor in
            RuleStore.shared.migrateFromUserDefaultsIfNeeded(userDefaults: userDefaults, rulesKey: "defaultTamer.rules")
        }
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
        // No data written yet — first run or clean install, silently use defaults
        guard defaults.data(forKey: settingsKey) != nil || defaults.data(forKey: settingsBackupKey) != nil else {
            return Settings.default
        }

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
        // Save to SQLite (primary storage for large rule sets)
        Task { @MainActor in
            RuleStore.shared.saveAllRules(rules)
        }

        // Also keep UserDefaults as a backup and for test isolation
        if let currentData = defaults.data(forKey: rulesKey) {
            defaults.set(currentData, forKey: rulesBackupKey)
        }

        do {
            let encoded = try JSONEncoder().encode(rules)
            defaults.set(encoded, forKey: rulesKey)
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
        // Try UserDefaults first (preserves test isolation with custom UserDefaults)
        guard defaults.data(forKey: rulesKey) != nil || defaults.data(forKey: rulesBackupKey) != nil else {
            // No UserDefaults data — try SQLite (post-migration storage)
            let sqliteRules = MainActor.assumeIsolated { RuleStore.shared.loadAllRules() }
            return sqliteRules
        }

        // Try to load current rules from UserDefaults
        if let rules = loadRulesFromKey(rulesKey) {
            // Migrate to SQLite for future loads
            Task { @MainActor in
                RuleStore.shared.saveAllRules(rules)
            }
            return rules
        }

        // Current rules corrupt, try backup
        debugLog("⚠️ Rules corrupted, attempting recovery from backup...")
        if let rules = loadRulesFromKey(rulesBackupKey) {
            debugLog("✅ Rules recovered from backup")
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
    
    // MARK: - Telemetry & Install Info
    
    var installID: String {
        if let existing = defaults.string(forKey: installIdKey) {
            return existing
        }
        let newID = UUID().uuidString
        defaults.set(newID, forKey: installIdKey)
        return newID
    }
    
    var lastKnownVersion: String? {
        get { defaults.string(forKey: lastVersionKey) }
        set { defaults.set(newValue, forKey: lastVersionKey) }
    }
    
    var lastLaunchDate: Date? {
        get { defaults.object(forKey: lastLaunchDateKey) as? Date }
        set { defaults.set(newValue, forKey: lastLaunchDateKey) }
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
