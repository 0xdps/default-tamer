//
//  URLSanitizerTests.swift
//  DefaultTamerTests
//
//  Tests for URL sanitization
//

import XCTest
@testable import DefaultTamer

final class URLSanitizerTests: XCTestCase {
    
    // MARK: - Basic Sanitization Tests
    
    func testSanitizeCleanURL() {
        // Given: URL without sensitive parameters
        let url = URL(string: "https://github.com/user/repo")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: URL should remain unchanged
        XCTAssertEqual(sanitized, "https://github.com/user/repo")
    }
    
    func testSanitizeAPIKey() {
        // Given: URL with API key
        let url = URL(string: "https://api.example.com/data?api_key=secret123&other=value")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: API key should be removed, other param kept
        XCTAssertTrue(sanitized.contains("other=value"))
        XCTAssertFalse(sanitized.contains("api_key"))
        XCTAssertFalse(sanitized.contains("secret123"))
    }
    
    func testSanitizeToken() {
        // Given: URL with access token
        let url = URL(string: "https://api.example.com/user?access_token=xyz789")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Token should be removed
        XCTAssertFalse(sanitized.contains("access_token"))
        XCTAssertFalse(sanitized.contains("xyz789"))
    }
    
    func testSanitizeMultipleSensitiveParams() {
        // Given: URL with multiple sensitive parameters
        let url = URL(string: "https://api.example.com/data?api_key=key123&token=tok456&session=sess789&safe=value")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: All sensitive params removed, safe param kept
        XCTAssertTrue(sanitized.contains("safe=value"))
        XCTAssertFalse(sanitized.contains("api_key"))
        XCTAssertFalse(sanitized.contains("token"))
        XCTAssertFalse(sanitized.contains("session"))
    }
    
    func testSanitizePassword() {
        // Given: URL with password parameter
        let url = URL(string: "https://example.com/login?username=user&password=secret")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Password should be removed, username can stay
        XCTAssertFalse(sanitized.contains("password"))
        XCTAssertFalse(sanitized.contains("secret"))
    }
    
    func testSanitizeOAuthCode() {
        // Given: URL with OAuth authorization code
        let url = URL(string: "https://app.example.com/callback?code=abc123xyz&state=random")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Code should be removed
        XCTAssertFalse(sanitized.contains("code="))
        XCTAssertFalse(sanitized.contains("abc123xyz"))
    }
    
    func testSanitizeJWT() {
        // Given: URL with JWT token
        let url = URL(string: "https://api.example.com/resource?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: JWT should be removed
        XCTAssertFalse(sanitized.contains("jwt"))
        XCTAssertFalse(sanitized.contains("eyJ"))
    }
    
    // MARK: - Path-Based Sanitization Tests
    
    func testSanitizeSensitivePath() {
        // Given: URL with sensitive path
        let url = URL(string: "https://api.example.com/oauth/token?grant_type=code")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Should only return scheme + host for sensitive paths
        XCTAssertEqual(sanitized, "https://api.example.com")
    }
    
    func testSanitizeAuthEndpoint() {
        // Given: URL to authentication endpoint
        let url = URL(string: "https://example.com/auth/token/refresh?token=abc123")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Should only return scheme + host
        XCTAssertEqual(sanitized, "https://example.com")
    }
    
    func testSanitizeLoginPage() {
        // Given: URL to login page with credentials
        let url = URL(string: "https://example.com/login?username=user&password=pass")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Should only return scheme + host
        XCTAssertEqual(sanitized, "https://example.com")
    }
    
    // MARK: - Fragment Removal Tests
    
    func testRemoveFragment() {
        // Given: URL with fragment (hash)
        let url = URL(string: "https://example.com/page?param=value#access_token=secret")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Fragment should be removed
        XCTAssertFalse(sanitized.contains("#"))
        XCTAssertFalse(sanitized.contains("access_token=secret"))
    }
    
    // MARK: - Detection Tests
    
    func testContainsSensitiveDataTrue() {
        // Given: URL with sensitive data
        let url = URL(string: "https://api.example.com/data?api_key=secret")!
        
        // When: Checking for sensitive data
        let hasSensitive = URLSanitizer.containsSensitiveData(url)
        
        // Then: Should detect sensitive data
        XCTAssertTrue(hasSensitive)
    }
    
    func testContainsSensitiveDataFalse() {
        // Given: Clean URL
        let url = URL(string: "https://github.com/user/repo?page=2")!
        
        // When: Checking for sensitive data
        let hasSensitive = URLSanitizer.containsSensitiveData(url)
        
        // Then: Should not detect sensitive data
        XCTAssertFalse(hasSensitive)
    }
    
    func testContainsSensitiveDataInPath() {
        // Given: URL with sensitive path
        let url = URL(string: "https://api.example.com/oauth/authorize")!
        
        // When: Checking for sensitive data
        let hasSensitive = URLSanitizer.containsSensitiveData(url)
        
        // Then: Should detect sensitive path
        XCTAssertTrue(hasSensitive)
    }
    
    // MARK: - Real-World Examples
    
    func testGitHubAPIWithToken() {
        // Given: GitHub API URL with token
        let url = URL(string: "https://api.github.com/user/repos?access_token=ghp_abc123xyz")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Token should be removed
        XCTAssertFalse(sanitized.contains("access_token"))
        XCTAssertFalse(sanitized.contains("ghp_"))
    }
    
    func testAWSSignedURL() {
        // Given: AWS signed URL
        let url = URL(string: "https://s3.amazonaws.com/bucket/file?X-Amz-Signature=abc&signature=xyz")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Signature should be removed
        XCTAssertFalse(sanitized.contains("signature"))
        XCTAssertFalse(sanitized.contains("Signature"))
    }
    
    func testStripeAPIKey() {
        // Given: Stripe API call with key
        let url = URL(string: "https://api.stripe.com/v1/charges?key=sk_live_abc123")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Key should be removed
        XCTAssertFalse(sanitized.contains("key="))
        XCTAssertFalse(sanitized.contains("sk_live"))
    }
    
    func testGoogleMapsWithAPIKey() {
        // Given: Google Maps URL with API key
        let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=NYC&key=AIza123")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: API key removed, address kept
        XCTAssertTrue(sanitized.contains("address=NYC"))
        XCTAssertFalse(sanitized.contains("key="))
        XCTAssertFalse(sanitized.contains("AIza"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyQueryString() {
        // Given: URL with empty query
        let url = URL(string: "https://example.com/?")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Should handle gracefully
        XCTAssertNotNil(sanitized)
    }
    
    func testAllParametersRemoved() {
        // Given: URL where all params are sensitive
        let url = URL(string: "https://api.example.com/data?token=abc&api_key=xyz")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Query string should be completely removed
        XCTAssertFalse(sanitized.contains("?"))
        XCTAssertEqual(sanitized, "https://api.example.com/data")
    }
    
    func testCaseInsensitive() {
        // Given: URL with mixed case sensitive params
        let url = URL(string: "https://api.example.com/data?API_KEY=secret&Token=abc")!
        
        // When: Sanitizing
        let sanitized = URLSanitizer.sanitize(url)
        
        // Then: Should remove regardless of case
        XCTAssertFalse(sanitized.contains("API_KEY"))
        XCTAssertFalse(sanitized.contains("Token"))
    }
}
