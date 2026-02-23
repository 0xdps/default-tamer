//
//  RouterTests.swift
//  DefaultTamerTests
//
//  Tests for the Router service
//

import XCTest
@testable import DefaultTamer

@MainActor
final class RouterTests: XCTestCase {
    
    var settings: Settings!
    var rules: [Rule]!
    
    override func setUp() {
        super.setUp()
        
        // Default test settings
        settings = Settings(
            enabled: true,
            fallbackBrowserId: BundleIdentifiers.safari,
            chooserModifierKey: "option",
            diagnosticsEnabled: false,
            launchAtLogin: false
        )
        
        // Default empty rules
        rules = []
    }
    
    override func tearDown() {
        settings = nil
        rules = nil
        super.tearDown()
    }
    
    // MARK: - Basic Routing Tests
    
    func testRouteWithNoRules_UsesFallback() {
        // Given: No rules and a URL
        let url = URL(string: "https://github.com")!
        
        // When: Routing without any rules
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should use fallback browser
        if case .openInFallback = action {
            // Success
        } else {
            XCTFail("Expected openInFallback, got \(action)")
        }
    }
    
    func testRouteWithOptionKey_ShowsChooser() {
        // Given: Option key is pressed
        let url = URL(string: "https://github.com")!
        let modifierFlags: NSEvent.ModifierFlags = [.option]
        
        // When: Routing with option key
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: modifierFlags
        )
        
        // Then: Should show chooser
        if case .showChooser(let chooserURL) = action {
            XCTAssertEqual(chooserURL, url)
        } else {
            XCTFail("Expected showChooser, got \(action)")
        }
    }
    
    func testRouteWhenDisabled_UsesFallback() {
        // Given: App is disabled
        settings.enabled = false
        let url = URL(string: "https://github.com")!
        
        // When: Routing while disabled
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should use fallback
        if case .openInFallback = action {
            // Success
        } else {
            XCTFail("Expected openInFallback when disabled")
        }
    }
    
    // MARK: - Domain Rule Tests
    
    func testDomainRule_ExactMatch() {
        // Given: An exact domain match rule
        var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule.domainPattern = "github.com"
        rule.domainMatchType = .exact
        rules = [rule]
        
        let url = URL(string: "https://github.com/user/repo")!
        
        // When: Routing URL with matching domain
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should route to target browser
        if case .openInBrowser(let browserId, let matchedRule) = action {
            XCTAssertEqual(browserId, BundleIdentifiers.chrome)
            XCTAssertEqual(matchedRule?.id, rule.id)
        } else {
            XCTFail("Expected openInBrowser")
        }
    }
    
    func testDomainRule_SuffixMatch() {
        // Given: A suffix domain match rule
        var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.firefox)
        rule.domainPattern = "github.com"
        rule.domainMatchType = .suffix
        rules = [rule]
        
        let url = URL(string: "https://api.github.com/repos")!
        
        // When: Routing URL with suffix match
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should route to target browser
        if case .openInBrowser(let browserId, _) = action {
            XCTAssertEqual(browserId, BundleIdentifiers.firefox)
        } else {
            XCTFail("Expected openInBrowser")
        }
    }
    
    func testDomainRule_ContainsMatch() {
        // Given: A contains domain match rule
        var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.brave)
        rule.domainPattern = "example"
        rule.domainMatchType = .contains
        rules = [rule]
        
        let url = URL(string: "https://test.example.com")!
        
        // When: Routing URL with contains match
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should route to target browser
        if case .openInBrowser(let browserId, _) = action {
            XCTAssertEqual(browserId, BundleIdentifiers.brave)
        } else {
            XCTFail("Expected openInBrowser")
        }
    }
    
    func testDomainRule_NoMatch_UsesFallback() {
        // Given: A domain rule that doesn't match
        var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule.domainPattern = "github.com"
        rule.domainMatchType = .exact
        rules = [rule]
        
        let url = URL(string: "https://google.com")!
        
        // When: Routing URL with non-matching domain
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should use fallback
        if case .openInFallback = action {
            // Success
        } else {
            XCTFail("Expected openInFallback")
        }
    }
    
    // MARK: - URL Pattern Tests
    
    func testURLPattern_ContainsMatch() {
        // Given: A URL contains rule
        var rule = Rule(type: .urlPattern, targetBrowserId: BundleIdentifiers.edge)
        rule.urlContains = "/docs/"
        rules = [rule]
        
        let url = URL(string: "https://example.com/docs/guide")!
        
        // When: Routing URL containing pattern
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should route to target browser
        if case .openInBrowser(let browserId, _) = action {
            XCTAssertEqual(browserId, BundleIdentifiers.edge)
        } else {
            XCTFail("Expected openInBrowser")
        }
    }
    
    func testURLPattern_RegexMatch() {
        // Given: A URL regex rule
        var rule = Rule(type: .urlPattern, targetBrowserId: BundleIdentifiers.arc)
        rule.urlRegex = "^https://github\\.com/[^/]+/[^/]+/pull/\\d+$"
        rules = [rule]
        
        let url = URL(string: "https://github.com/user/repo/pull/123")!
        
        // When: Routing URL matching regex
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should route to target browser
        if case .openInBrowser(let browserId, _) = action {
            XCTAssertEqual(browserId, BundleIdentifiers.arc)
        } else {
            XCTFail("Expected openInBrowser")
        }
    }
    
    func testURLPattern_RegexNoMatch() {
        // Given: A URL regex rule
        var rule = Rule(type: .urlPattern, targetBrowserId: BundleIdentifiers.arc)
        rule.urlRegex = "^https://github\\.com/[^/]+/[^/]+/pull/\\d+$"
        rules = [rule]
        
        let url = URL(string: "https://github.com/user/repo/issues/123")!
        
        // When: Routing URL not matching regex
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should use fallback
        if case .openInFallback = action {
            // Success
        } else {
            XCTFail("Expected openInFallback")
        }
    }
    
    // MARK: - Source App Tests
    
    func testSourceAppRule_Match() {
        // Given: A source app rule
        var rule = Rule(type: .sourceApp, targetBrowserId: BundleIdentifiers.chrome)
        rule.sourceAppBundleId = BundleIdentifiers.slack
        rules = [rule]
        
        let url = URL(string: "https://example.com")!
        
        // When: Routing from matching source app
        let action = Router.route(
            url: url,
            sourceApp: BundleIdentifiers.slack,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should route to target browser
        if case .openInBrowser(let browserId, _) = action {
            XCTAssertEqual(browserId, BundleIdentifiers.chrome)
        } else {
            XCTFail("Expected openInBrowser")
        }
    }
    
    func testSourceAppRule_NoMatch() {
        // Given: A source app rule
        var rule = Rule(type: .sourceApp, targetBrowserId: BundleIdentifiers.chrome)
        rule.sourceAppBundleId = BundleIdentifiers.slack
        rules = [rule]
        
        let url = URL(string: "https://example.com")!
        
        // When: Routing from different source app
        let action = Router.route(
            url: url,
            sourceApp: BundleIdentifiers.vscode,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should use fallback
        if case .openInFallback = action {
            // Success
        } else {
            XCTFail("Expected openInFallback")
        }
    }
    
    // MARK: - Rule Priority Tests
    
    func testRulePriority_FirstMatchWins() {
        // Given: Multiple rules with same domain
        var rule1 = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule1.domainPattern = "github.com"
        rule1.domainMatchType = .exact
        
        var rule2 = Rule(type: .domain, targetBrowserId: BundleIdentifiers.firefox)
        rule2.domainPattern = "github.com"
        rule2.domainMatchType = .exact
        
        rules = [rule1, rule2]
        
        let url = URL(string: "https://github.com")!
        
        // When: Routing with multiple matching rules
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should use first matching rule
        if case .openInBrowser(let browserId, let matchedRule) = action {
            XCTAssertEqual(browserId, BundleIdentifiers.chrome)
            XCTAssertEqual(matchedRule?.id, rule1.id)
        } else {
            XCTFail("Expected openInBrowser with first rule")
        }
    }
    
    func testDisabledRule_Skipped() {
        // Given: A disabled rule
        var rule = Rule(type: .domain, targetBrowserId: BundleIdentifiers.chrome)
        rule.domainPattern = "github.com"
        rule.domainMatchType = .exact
        rule.enabled = false
        rules = [rule]
        
        let url = URL(string: "https://github.com")!
        
        // When: Routing with disabled rule
        let action = Router.route(
            url: url,
            sourceApp: nil,
            settings: settings,
            rules: rules,
            modifierFlags: []
        )
        
        // Then: Should use fallback (skip disabled rule)
        if case .openInFallback = action {
            // Success
        } else {
            XCTFail("Expected openInFallback (disabled rule should be skipped)")
        }
    }
}
