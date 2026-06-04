//
//  URLHelpersTests.swift
//  DefaultTamerTests
//
//  Tests for URL helper classification.
//

import XCTest
@testable import DefaultTamer

final class URLHelpersTests: XCTestCase {

    func testHTTPURLsAreHTTP() {
        XCTAssertTrue(URL(string: "http://example.com")!.isHTTP)
        XCTAssertTrue(URL(string: "https://example.com")!.isHTTP)
    }

    func testFileURLIsNotHTTP() {
        let url = URL(fileURLWithPath: "/Users/test/Desktop/index.html")
        XCTAssertFalse(url.isHTTP)
    }

    func testHTMLFileURLsAreBrowserOpenable() {
        let extensions = ["html", "htm", "shtml", "xhtml", "shtm", "xhtm"]
        for ext in extensions {
            let url = URL(fileURLWithPath: "/Users/test/Desktop/index.\(ext)")
            XCTAssertTrue(url.isBrowserOpenableFile, "Expected .\(ext) to be browser-openable")
        }
    }

    func testHTMLFileURLCheckIsCaseInsensitive() {
        let url = URL(fileURLWithPath: "/Users/test/Desktop/INDEX.HTML")
        XCTAssertTrue(url.isBrowserOpenableFile)
    }

    func testNonHTMLFileURLsAreNotBrowserOpenable() {
        let url = URL(fileURLWithPath: "/Users/test/Desktop/notes.txt")
        XCTAssertFalse(url.isBrowserOpenableFile)
    }

    func testRemoteHTMLURLIsNotFileOpenable() {
        let url = URL(string: "https://example.com/index.html")!
        XCTAssertFalse(url.isBrowserOpenableFile)
    }
}
