//
//  LicensingManagerTests.swift
//  DefaultTamerTests
//
//  Tests for LicensingManager, LicensePlan, LicenseStatus, and PromoValidationResult.
//

import XCTest
@testable import DefaultTamer

// MARK: - LicensePlan Tests

final class LicensePlanTests: XCTestCase {

    func testInit_free_returnsFree() {
        XCTAssertEqual(LicensePlan(slug: "free"), .free)
    }

    func testInit_plus_returnsPlus() {
        XCTAssertEqual(LicensePlan(slug: "plus"), .plus)
    }

    func testInit_powerPrefix_returnsPlus() {
        XCTAssertEqual(LicensePlan(slug: "power-1"), .plus)
        XCTAssertEqual(LicensePlan(slug: "power-2"), .plus)
        XCTAssertEqual(LicensePlan(slug: "power-5"), .plus)
        XCTAssertEqual(LicensePlan(slug: "power-tq"), .plus)
    }

    func testInit_unknownSlug_returnsFree() {
        XCTAssertEqual(LicensePlan(slug: "enterprise"), .free)
        XCTAssertEqual(LicensePlan(slug: "premium"), .free)
    }

    func testInit_nil_returnsFree() {
        XCTAssertEqual(LicensePlan(slug: nil), .free)
    }

    func testDisplayName_free() {
        XCTAssertEqual(LicensePlan.free.displayName, "Free")
    }

    func testDisplayName_plus() {
        XCTAssertEqual(LicensePlan.plus.displayName, "Power")
    }

    func testIsPaid_free() {
        XCTAssertFalse(LicensePlan.free.isPaid)
    }

    func testIsPaid_plus() {
        XCTAssertTrue(LicensePlan.plus.isPaid)
    }
}

// MARK: - LicenseStatus Tests

final class LicenseStatusTests: XCTestCase {

    func testHas_featurePresent_returnsTrue() {
        let status = LicenseStatus(
            licenseId: "test-id",
            plan: .plus,
            features: ["private_browsing", "chrome_profiles"],
            validUntil: nil
        )
        XCTAssertTrue(status.has(.privateBrowsing))
        XCTAssertTrue(status.has(.chromeProfiles))
    }

    func testHas_featureMissing_returnsFalse() {
        let status = LicenseStatus(
            licenseId: "test-id",
            plan: .plus,
            features: ["private_browsing"],
            validUntil: nil
        )
        XCTAssertFalse(status.has(.chromeProfiles))
        XCTAssertFalse(status.has(.shortcutRules))
    }

    func testHas_emptyFeatures_returnsFalse() {
        let status = LicenseStatus(
            licenseId: "test-id",
            plan: .free,
            features: [],
            validUntil: nil
        )
        XCTAssertFalse(status.has(.privateBrowsing))
    }

    func testValidUntil_encodesAndDecodes() throws {
        let date = Date()
        let status = LicenseStatus(
            licenseId: "id",
            plan: .plus,
            features: ["private_browsing"],
            validUntil: date
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(LicenseStatus.self, from: data)
        // Date comparison with sub-second tolerance
        XCTAssertEqual(decoded.validUntil?.timeIntervalSince1970 ?? 0,
                       date.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testCodable_freePlan() throws {
        let status = LicenseStatus(
            licenseId: "",
            plan: .free,
            features: [],
            validUntil: nil
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(LicenseStatus.self, from: data)
        XCTAssertEqual(decoded.plan, .free)
        XCTAssertEqual(decoded.features, [])
        XCTAssertNil(decoded.validUntil)
    }
}

// MARK: - PromoValidationResult Tests

final class PromoValidationResultTests: XCTestCase {

    func testValid_hasEmptyErrorMessage() {
        let result = PromoValidationResult(valid: true, discountCents: 500, adjustedTotal: 499, reason: nil, promotionName: "Launch")
        XCTAssertTrue(result.errorMessage.isEmpty)
    }

    func testCodeNotFound_errorMessage() {
        let result = PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: "code_not_found", promotionName: nil)
        XCTAssertFalse(result.errorMessage.isEmpty)
        XCTAssertTrue(result.errorMessage.contains("Invalid"))
    }

    func testPromotionExpired_errorMessage() {
        let result = PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: "promotion_expired", promotionName: nil)
        XCTAssertTrue(result.errorMessage.contains("expired"))
    }

    func testExistingCustomer_errorMessage() {
        let result = PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: "existing_customer", promotionName: nil)
        XCTAssertTrue(result.errorMessage.contains("new customers"))
    }

    func testAlreadyRedeemed_errorMessage() {
        let result = PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: "already_redeemed", promotionName: nil)
        XCTAssertTrue(result.errorMessage.contains("already used"))
    }

    func testUnknownReason_hasGenericMessage() {
        let result = PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: "some_random_reason", promotionName: nil)
        XCTAssertTrue(result.errorMessage.contains("not valid"))
    }

    func testNilReason_hasGenericMessage() {
        let result = PromoValidationResult(valid: false, discountCents: nil, adjustedTotal: nil, reason: nil, promotionName: nil)
        XCTAssertTrue(result.errorMessage.contains("not valid"))
    }
}

// MARK: - ActivationState Tests

final class ActivationStateTests: XCTestCase {

    func testIdle_equatable() {
        XCTAssertEqual(ActivationState.idle, ActivationState.idle)
        XCTAssertNotEqual(ActivationState.idle, ActivationState.activating)
    }

    func testActivatedWithSeatCounts_equatable() {
        let a = ActivationState.activated(seatsUsed: 1, seatsTotal: 3)
        let b = ActivationState.activated(seatsUsed: 1, seatsTotal: 3)
        let c = ActivationState.activated(seatsUsed: 2, seatsTotal: 3)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testOverLimit_equatable() {
        let a = ActivationState.overLimit(seatsUsed: 3, seatsTotal: 3)
        let b = ActivationState.overLimit(seatsUsed: 3, seatsTotal: 3)
        let c = ActivationState.overLimit(seatsUsed: 2, seatsTotal: 2)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testErrorWithMessage_equatable() {
        XCTAssertEqual(ActivationState.error("fail"), ActivationState.error("fail"))
        XCTAssertNotEqual(ActivationState.error("fail"), ActivationState.error("other"))
    }

    func testServerUnreachable_isDistinct() {
        XCTAssertEqual(ActivationState.serverUnreachable, ActivationState.serverUnreachable)
        XCTAssertNotEqual(ActivationState.serverUnreachable, ActivationState.idle)
        XCTAssertNotEqual(ActivationState.serverUnreachable, ActivationState.error("offline"))
    }

    func testDeactivatedRemotely_equatable() {
        XCTAssertEqual(ActivationState.deactivatedRemotely, ActivationState.deactivatedRemotely)
        XCTAssertNotEqual(ActivationState.deactivatedRemotely, ActivationState.idle)
    }
}

// MARK: - LicensingManager Tests

@MainActor
final class LicensingManagerTests: XCTestCase {

    var licensing: LicensingManager!

    override func setUp() {
        super.setUp()
        licensing = LicensingManager.shared
        // Clear cached state so tests start from a clean slate.
        // The shared singleton may have restored a cached license status
        // from UserDefaults (e.g. if the app was run previously).
        licensing.clearCachedStateForTesting()
    }

    // MARK: - Initial state

    func testInitialStatus_isNil() {
        XCTAssertNil(licensing.status)
    }

    func testInitialActivationState_isIdle() {
        XCTAssertEqual(licensing.activationState, .idle)
    }

    func testInitialIsValidating_isFalse() {
        XCTAssertFalse(licensing.isValidating)
    }

    func testHasPowerPlan_initial_returnsFalse() {
        XCTAssertFalse(licensing.hasPowerPlan)
    }

    // MARK: - Feature gating

    func testIsEnabled_nilStatus_returnsFalse() {
        XCTAssertFalse(licensing.isEnabled(.privateBrowsing))
        XCTAssertFalse(licensing.isEnabled(.chromeProfiles))
        XCTAssertFalse(licensing.isEnabled(.shortcutRules))
    }

    // MARK: - LicenseFeature allCases

    func testLicenseFeature_allCases_count() {
        // Currently 3 features: privateBrowsing, chromeProfiles, shortcutRules
        XCTAssertEqual(LicenseFeature.allCases.count, 3)
    }

    func testLicenseFeature_rawValues_matchExpected() {
        let rawValues = LicenseFeature.allCases.map(\.rawValue)
        XCTAssertTrue(rawValues.contains("private_browsing"))
        XCTAssertTrue(rawValues.contains("chrome_profiles"))
        XCTAssertTrue(rawValues.contains("shortcut_rules"))
    }
}
