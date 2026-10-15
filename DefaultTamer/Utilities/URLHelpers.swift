//
//  URLHelpers.swift
//  Default Tamer
//
//  URL parsing and normalization utilities
//

import Foundation

extension URL {
    private static let browserOpenableFileExtensions: Set<String> = [
        "html", "htm", "shtml", "xhtml", "shtm", "xhtm"
    ]

    /// Normalized host (lowercase, www. prefix handling)
    var normalizedHost: String? {
        guard let host = self.host?.lowercased() else {
            return nil
        }
        
        // Optionally strip www. prefix for matching
        // For now, keep it as-is to allow exact matching
        return host
    }
    
    /// Validates if URL is http or https
    var isHTTP: Bool {
        return scheme == "http" || scheme == "https"
    }

    /// True for local document types that Default Tamer registers to receive from Finder
    /// and should hand straight to the fallback browser.
    var isBrowserOpenableFile: Bool {
        guard isFileURL else { return false }
        let ext = pathExtension.lowercased()
        return Self.browserOpenableFileExtensions.contains(ext)
    }
}

extension String {
    /// Validates if string is a valid URL
    var isValidURL: Bool {
        return URL(string: self) != nil
    }
}
