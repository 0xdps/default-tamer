//
//  BrowserManagerTests.swift
//  DefaultTamerTests
//
//  Tests for BrowserManager — launch strategy resolution, profile ID parsing,
//  and browser availability checks.
//

import XCTest
@testable import DefaultTamer

@MainActor
final class BrowserManagerTests: XCTestCase {

    // MARK: - Launch Strategy Tests

    func testLaunchStrategy_Safari_IsWorkspace() {
        let browser = Browser(bundleId: BundleIdentifiers.safari, displayName: "Safari")
        if case .workspace = browser.launchStrategy {
            // expected
        } else {
            XCTFail("Safari should use .workspace strategy")
        }
    }

    func testLaunchStrategy_Arc_IsWorkspace() {
        let browser = Browser(bundleId: BundleIdentifiers.arc, displayName: "Arc")
        if case .workspace = browser.launchStrategy {
            // expected
        } else {
            XCTFail("Arc should use .workspace strategy")
        }
    }

    func testLaunchStrategy_Firefox_IsGecko() {
        let browser = Browser(bundleId: BundleIdentifiers.firefox, displayName: "Firefox")
        if case .gecko(let flag) = browser.launchStrategy {
            XCTAssertEqual(flag, "-private-window")
        } else {
            XCTFail("Firefox should use .gecko strategy")
        }
    }

    func testLaunchStrategy_Edge_IsChromium() {
        let browser = Browser(bundleId: BundleIdentifiers.edge, displayName: "Edge")
        if case .chromium(let flag) = browser.launchStrategy {
            XCTAssertEqual(flag, "-inprivate")
        } else {
            XCTFail("Edge should use .chromium strategy")
        }
    }

    func testLaunchStrategy_Chrome_IsChromiumWithIncognito() {
        let browser = Browser(bundleId: BundleIdentifiers.chrome, displayName: "Chrome")
        if case .chromium(let flag) = browser.launchStrategy {
            XCTAssertEqual(flag, "--incognito")
        } else {
            XCTFail("Chrome should use .chromium strategy with --incognito")
        }
    }

    func testLaunchStrategy_Brave_IsChromiumWithIncognito() {
        let browser = Browser(bundleId: BundleIdentifiers.brave, displayName: "Brave")
        if case .chromium(let flag) = browser.launchStrategy {
            XCTAssertEqual(flag, "--incognito")
        } else {
            XCTFail("Brave should use .chromium strategy with --incognito")
        }
    }

    func testLaunchStrategy_Opera_IsChromiumWithPrivate() {
        let browser = Browser(bundleId: BundleIdentifiers.opera, displayName: "Opera")
        if case .chromium(let flag) = browser.launchStrategy {
            XCTAssertEqual(flag, "--private")
        } else {
            XCTFail("Opera should use .chromium strategy with --private")
        }
    }

    func testLaunchStrategy_UnknownBrowser_DefaultsToChromiumIncognito() {
        let browser = Browser(bundleId: "com.example.unknownbrowser", displayName: "Unknown")
        if case .chromium(let flag) = browser.launchStrategy {
            XCTAssertEqual(flag, "--incognito")
        } else {
            XCTFail("Unknown browser should default to .chromium with --incognito")
        }
    }

    // MARK: - Profile Browser ID Tests

    func testProfileBrowserID_ContainsSeparator() {
        let browser = Browser(
            bundleId: BundleIdentifiers.chrome,
            displayName: "Chrome – Work",
            profileDirectory: "Profile 1"
        )
        XCTAssertTrue(browser.id.contains(Browser.profileSeparator))
        XCTAssertEqual(browser.baseBundleId, BundleIdentifiers.chrome)
        XCTAssertEqual(browser.profileDirectory, "Profile 1")
    }

    func testBaseBundleID_NoProfile_ReturnsSelf() {
        let browser = Browser(bundleId: BundleIdentifiers.safari, displayName: "Safari")
        XCTAssertEqual(browser.baseBundleId, BundleIdentifiers.safari)
        XCTAssertNil(browser.profileDirectory)
    }

    func testBaseBundleID_WithProfile_StripsSuffix() {
        let browser = Browser(
            bundleId: BundleIdentifiers.chrome,
            displayName: "Chrome – Work",
            profileDirectory: "Default"
        )
        XCTAssertEqual(browser.baseBundleId, BundleIdentifiers.chrome)
        XCTAssertNotEqual(browser.id, browser.baseBundleId)
    }

    // MARK: - Browser Equality Tests

    func testBrowserEquality_SameBundleIDAndProfile_AreEqual() {
        let a = Browser(bundleId: BundleIdentifiers.chrome, displayName: "Chrome", profileDirectory: "Default")
        let b = Browser(bundleId: BundleIdentifiers.chrome, displayName: "Chrome", profileDirectory: "Default")
        XCTAssertEqual(a, b)
    }

    func testBrowserEquality_DifferentProfiles_NotEqual() {
        let a = Browser(bundleId: BundleIdentifiers.chrome, displayName: "Chrome", profileDirectory: "Default")
        let b = Browser(bundleId: BundleIdentifiers.chrome, displayName: "Chrome", profileDirectory: "Profile 1")
        XCTAssertNotEqual(a, b)
    }

    func testBrowserEquality_DifferentBundleIDs_NotEqual() {
        let a = Browser(bundleId: BundleIdentifiers.chrome, displayName: "Chrome")
        let b = Browser(bundleId: BundleIdentifiers.firefox, displayName: "Firefox")
        XCTAssertNotEqual(a, b)
    }
}
