//
//  SourceAppDetectorTests.swift
//  DefaultTamerTests
//
//  Tests for SourceAppDetector — confidence scoring, detection method
//  ordering, and app switch tracking.
//

import XCTest
import AppKit
@testable import DefaultTamer

@MainActor
final class SourceAppDetectorTests: XCTestCase {

    // MARK: - Detection Method Confidence Tests

    func testConfidence_AppleEvent_Highest() {
        let confidence = AppDetectionResult.DetectionMethod.appleEvent.confidence
        XCTAssertEqual(confidence, 0.95)
    }

    func testConfidence_AppleEventPID_SecondHighest() {
        let confidence = AppDetectionResult.DetectionMethod.appleEventPID.confidence
        XCTAssertEqual(confidence, 0.90)
    }

    func testConfidence_ActiveApp() {
        let confidence = AppDetectionResult.DetectionMethod.activeApp.confidence
        XCTAssertEqual(confidence, 0.85)
    }

    func testConfidence_MenuBarOwner() {
        let confidence = AppDetectionResult.DetectionMethod.menuBarOwner.confidence
        XCTAssertEqual(confidence, 0.75)
    }

    func testConfidence_RecentSwitch() {
        let confidence = AppDetectionResult.DetectionMethod.recentSwitch.confidence
        XCTAssertEqual(confidence, 0.65)
    }

    func testConfidence_RunningApps_Lowest() {
        let confidence = AppDetectionResult.DetectionMethod.runningApps.confidence
        XCTAssertEqual(confidence, 0.50)
    }

    func testConfidence_Ordering_IsMonotonicallyDecreasing() {
        let methods: [AppDetectionResult.DetectionMethod] = [
            .appleEvent, .appleEventPID, .activeApp, .menuBarOwner, .recentSwitch, .runningApps
        ]
        for i in 0..<(methods.count - 1) {
            XCTAssertGreaterThan(
                methods[i].confidence,
                methods[i + 1].confidence,
                "\(methods[i]) should have higher confidence than \(methods[i + 1])"
            )
        }
    }

    // MARK: - Detection Result Tests

    func testDetectionResult_StoresAllFields() {
        let result = AppDetectionResult(
            bundleId: "com.example.app",
            appName: "Example",
            confidence: 0.90,
            method: .appleEventPID
        )
        XCTAssertEqual(result.bundleId, "com.example.app")
        XCTAssertEqual(result.appName, "Example")
        XCTAssertEqual(result.confidence, 0.90)
        XCTAssertEqual(result.method, .appleEventPID)
    }

    func testDetectionResult_NilAppName() {
        let result = AppDetectionResult(
            bundleId: "com.example.app",
            appName: nil,
            confidence: 0.50,
            method: .runningApps
        )
        XCTAssertNil(result.appName)
    }

    // MARK: - Known Apps Tests

    func testKnownApps_ContainsSlack() {
        XCTAssertNotNil(SourceAppDetector.knownApps["com.tinyspeck.slackmacgap"])
        XCTAssertEqual(SourceAppDetector.knownApps["com.tinyspeck.slackmacgap"], "Slack")
    }

    func testKnownApps_ContainsCursor() {
        XCTAssertNotNil(SourceAppDetector.knownApps["com.todesktop.230313mzl4w4u92"])
        XCTAssertEqual(SourceAppDetector.knownApps["com.todesktop.230313mzl4w4u92"], "Cursor")
    }

    func testDisplayName_ForKnownApp_ReturnsName() {
        XCTAssertEqual(SourceAppDetector.displayName(for: "com.tinyspeck.slackmacgap"), "Slack")
    }

    func testDisplayName_ForUnknownApp_ReturnsBundleId() {
        let unknownBundleId = "com.example.nonexistent"
        XCTAssertEqual(SourceAppDetector.displayName(for: unknownBundleId), unknownBundleId)
    }

    // MARK: - Detection Without Apple Event

    func testDetectSourceAppWithConfidence_NoEvent_ReturnsNilOrResult() {
        // Without an Apple Event and with DefaultTamer as the only running app,
        // detection may return nil or a low-confidence result.
        // We just verify it doesn't crash.
        let result = SourceAppDetector.shared.detectSourceAppWithConfidence(from: nil)
        if let result = result {
            XCTAssertFalse(result.bundleId.isEmpty)
            XCTAssertGreaterThan(result.confidence, 0)
        }
    }

    func testDetectSourceApp_LegacyAPI_ReturnsStringOrNil() {
        // The legacy API should return a String? (bundle ID) or nil
        let result = SourceAppDetector.detectSourceApp()
        if let result = result {
            XCTAssertFalse(result.isEmpty)
        }
    }
}
