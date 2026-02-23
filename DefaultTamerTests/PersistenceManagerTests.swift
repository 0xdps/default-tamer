//
//  PersistenceManagerTests.swift
//  DefaultTamerTests
//
//  Tests for PersistenceManager
//

import XCTest
@testable import DefaultTamer

@MainActor
final class PersistenceManagerTests: XCTestCase {
    
    var persistence: PersistenceManager!
    let testSuiteName = "com.defaulttamer.tests"
    
    override func setUp() {
        super.setUp()
        
        // Use test user defaults
        let defaults = UserDefaults(suiteName: testSuiteName)!
        persistence = PersistenceManager(userDefaults: defaults)
        
        // Clear any existing data
        clearTestDefaults()
    }
    
    override func tearDown() {
        clearTestDefaults()
        persistence = nil
        super.tearDown()
    }
    
    private func clearTestDefaults() {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.removePersistentDomain(forName: testSuiteName)
    }
    
    // MARK: - Settings Tests
    
    func testSaveSettings_Success() throws {
        // Given: Settings object
        let settings = Settings(
            enabled: true,
            fallbackBrowserId: BundleIdentifiers.chrome,
            chooserModifierKey: "option",
            diagnosticsEnabled: true,
            launchAtLogin: false
        )
        
        // When: Saving settings
        try persistence.saveSettings(settings)
        
        // Then: Settings should be persisted
        let loaded = persistence.loadSettings()
        XCTAssertEqual(loaded.enabled, settings.enabled)
        XCTAssertEqual(loaded.fallbackBrowserId, settings.fallbackBrowserId)
        XCTAssertEqual(loaded.chooserModifierKey, settings.chooserModifierKey)
        XCTAssertEqual(loaded.diagnosticsEnabled, settings.diagnosticsEnabled)
        XCTAssertEqual(loaded.launchAtLogin, settings.launchAtLogin)
    }
    
    func testLoadSettings_NoData_ReturnsDefaults() {
        // Given: No saved settings
        
        // When: Loading settings
        let settings = persistence.loadSettings()
        
        // Then: Should return default values
        XCTAssertEqual(settings.enabled, true)
        XCTAssertEqual(settings.fallbackBrowserId, BundleIdentifiers.safari)
        XCTAssertEqual(settings.chooserModifierKey, "option")
        XCTAssertEqual(settings.diagnosticsEnabled, false)
        XCTAssertEqual(settings.launchAtLogin, false)
    }
    
    func testSaveSettings_Roundtrip() throws {
        // Given: Multiple setting changes
        var settings = Settings()
        
        // When: Saving multiple times
        try persistence.saveSettings(settings)
        
        settings.enabled = false
        try persistence.saveSettings(settings)
        
        settings.fallbackBrowserId = BundleIdentifiers.firefox
        try persistence.saveSettings(settings)
        
        // Then: Latest settings should be persisted
        let loaded = persistence.loadSettings()
        XCTAssertEqual(loaded.enabled, false)
        XCTAssertEqual(loaded.fallbackBrowserId, BundleIdentifiers.firefox)
    }
    
    // MARK: - Rules Tests
    
    func testSaveRules_EmptyArray() throws {
        // Given: Empty rules array
        let rules: [Rule] = []
        
        // When: Saving empty rules
        try persistence.saveRules(rules)
        
        // Then: Should persist empty array
        let loaded = persistence.loadRules()
        XCTAssertEqual(loaded.count, 0)
    }
    
    func testSaveRules_SingleRule() throws {
        // Given: Single rule
        var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule.domainPattern = "github.com"
        rule.domainMatchType = .exact
        let rules = [rule]
        
        // When: Saving rules
        try persistence.saveRules(rules)
        
        // Then: Rule should be persisted
        let loaded = persistence.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].type, .domain)
        XCTAssertEqual(loaded[0].targetBrowserId, BundleIdentifiers.chrome)
        XCTAssertEqual(loaded[0].domainPattern, "github.com")
        XCTAssertEqual(loaded[0].domainMatchType, .exact)
    }
    
    func testSaveRules_MultipleRules() throws {
        // Given: Multiple rules
        var rule1 = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule1.domainPattern = "github.com"
        rule1.domainMatchType = .exact
        
        var rule2 = Rule(type: .sourceApp, targetBrowserId: BundleIdentifiers.firefox)
        rule2.sourceAppBundleId = BundleIdentifiers.slack
        
        var rule3 = Rule(type: .urlPattern, targetBrowserId: BundleIdentifiers.brave)
        rule3.urlContains = "/docs/"
        
        let rules = [rule1, rule2, rule3]
        
        // When: Saving rules
        try persistence.saveRules(rules)
        
        // Then: All rules should be persisted in order
        let loaded = persistence.loadRules()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].type, .domain)
        XCTAssertEqual(loaded[1].type, .sourceApp)
        XCTAssertEqual(loaded[2].type, .urlPattern)
    }
    
    func testSaveRules_PreservesOrder() throws {
        // Given: Rules in specific order
        let rules = (0..<10).map { i in
            var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.safari)
            rule.domainPattern = "example\(i).com"
            rule.domainMatchType = .exact
            return rule
        }
        
        // When: Saving rules
        try persistence.saveRules(rules)
        
        // Then: Order should be preserved
        let loaded = persistence.loadRules()
        XCTAssertEqual(loaded.count, 10)
        for (index, rule) in loaded.enumerated() {
            XCTAssertEqual(rule.domainPattern, "example\(index).com")
        }
    }
    
    func testSaveRules_OverwritesPrevious() throws {
        // Given: Initial rules
        var rule1 = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule1.domainPattern = "github.com"
        rule1.domainMatchType = .exact
        try persistence.saveRules([rule1])
        
        // When: Saving different rules
        var rule2 = Rule(type: .domain, targetBrowserId: BundleIdentifiers.firefox)
        rule2.domainPattern = "google.com"
        rule2.domainMatchType = .exact
        try persistence.saveRules([rule2])
        
        // Then: Should only have new rules
        let loaded = persistence.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].domainPattern, "google.com")
    }
    
    func testLoadRules_NoData_ReturnsEmpty() {
        // Given: No saved rules
        
        // When: Loading rules
        let rules = persistence.loadRules()
        
        // Then: Should return empty array
        XCTAssertEqual(rules.count, 0)
    }
    
    func testSaveRules_ComplexRule() throws {
        // Given: Rule with all optional fields
        var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule.domainPattern = "github.com"
        rule.domainMatchType = .exact
        rule.enabled = false
        rule.sourceAppName = "Test App"
        
        // When: Saving complex rule
        try persistence.saveRules([rule])
        
        // Then: All fields should be persisted
        let loaded = persistence.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].enabled, false)
        XCTAssertEqual(loaded[0].sourceAppName, "Test App")
    }
    
    // MARK: - First Run Tests
    
    func testFirstRun_Initial_ReturnsFalse() {
        // Given: Fresh install
        
        // When: Checking first run
        let hasCompleted = persistence.hasCompletedFirstRun
        
        // Then: Should be false
        XCTAssertFalse(hasCompleted)
    }
    
    func testFirstRun_AfterSet_ReturnsTrue() {
        // Given: First run completed
        persistence.hasCompletedFirstRun = true
        
        // When: Checking first run
        let hasCompleted = persistence.hasCompletedFirstRun
        
        // Then: Should be true
        XCTAssertTrue(hasCompleted)
    }
    
    func testFirstRun_Persists() {
        // Given: First run completed
        persistence.hasCompletedFirstRun = true
        
        // When: Creating new persistence manager
        let newPersistence = PersistenceManager(
            userDefaults: UserDefaults(suiteName: testSuiteName)!
        )
        
        // Then: Value should persist
        XCTAssertTrue(newPersistence.hasCompletedFirstRun)
    }
    
    // MARK: - Data Corruption Tests
    
    func testLoadSettings_CorruptData_ReturnsDefaults() {
        // Given: Corrupt settings data
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.set("corrupt data", forKey: "settings")
        
        // When: Loading settings
        let settings = persistence.loadSettings()
        
        // Then: Should return defaults (not crash)
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings.enabled, true)
    }
    
    func testLoadRules_CorruptData_ReturnsEmpty() {
        // Given: Corrupt rules data
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.set("corrupt data", forKey: "rules")
        
        // When: Loading rules
        let rules = persistence.loadRules()
        
        // Then: Should return empty array (not crash)
        XCTAssertNotNil(rules)
        XCTAssertEqual(rules.count, 0)
    }
}
