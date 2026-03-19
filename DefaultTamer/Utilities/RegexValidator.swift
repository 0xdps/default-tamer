//
//  RegexValidator.swift
//  Default Tamer
//
//  Validates regex patterns to prevent crashes and ReDoS attacks
//

import Foundation

enum RegexValidationError: Error, LocalizedError {
    case emptyPattern
    case invalidSyntax(String)
    case dangerousPattern(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyPattern:
            return "Regex pattern cannot be empty"
        case .invalidSyntax(let message):
            return "Invalid regex syntax: \(message)"
        case .dangerousPattern(let reason):
            return "Potentially dangerous pattern: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyPattern:
            return "Enter a valid regex pattern"
        case .invalidSyntax:
            return "Check your regex syntax and try again"
        case .dangerousPattern:
            return "Avoid nested quantifiers or alternations that could cause performance issues"
        }
    }
}

class RegexValidator {
    
    /// Validates a regex pattern for safety and correctness
    /// - Parameter pattern: The regex pattern to validate
    /// - Returns: Error message if invalid, nil if valid
    static func validate(_ pattern: String) -> String? {
        // Check for empty pattern
        guard !pattern.isEmpty else {
            return nil // Empty is valid (no error)
        }
        
        // Try to compile the pattern
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            return "Invalid regex syntax: \(error.localizedDescription)"
        }
        
        // Check for ReDoS (Regular Expression Denial of Service) patterns
        if let error = checkForDangerousPatterns(pattern) {
            return error
        }
        
        return nil // Valid pattern
    }
    
    /// Checks for potentially dangerous regex patterns that could cause ReDoS
    /// - Returns: Error message if dangerous, nil if safe
    private static func checkForDangerousPatterns(_ pattern: String) -> String? {
        // Common ReDoS patterns
        let dangerousPatterns: [(String, String)] = [
            // Nested quantifiers on a group - (a+)+, (a*)*
            // Only flag when the outer quantifier follows a group that itself has a quantifier.
            ("\\([^)]*[+*][^)]*\\)[+*]", "Nested quantifiers can cause exponential backtracking"),
            
            // Multiple consecutive quantifiers - a** (always a syntax error)
            ("[+*]{2,}", "Multiple consecutive quantifiers are invalid"),
            
            // Unbounded repetition with backreference
            ("\\([^)]+\\)[+*]\\1", "Backreference with unbounded repetition"),
        ]
        
        for (dangerousPattern, reason) in dangerousPatterns {
            if let regex = try? NSRegularExpression(pattern: dangerousPattern, options: []),
               regex.firstMatch(in: pattern, range: NSRange(pattern.startIndex..., in: pattern)) != nil {
                return "Potentially dangerous pattern: \(reason)"
            }
        }
        
        // Check for excessive nesting depth (independent of alternation)
        let nestedGroupDepth = countNestedGroups(pattern)
        if nestedGroupDepth > 5 {
            return "Too many nested groups (max 5)"
        }
        
        return nil // Pattern is safe
    }
    
    /// Counts the maximum nesting depth of groups in a regex pattern
    private static func countNestedGroups(_ pattern: String) -> Int {
        var maxDepth = 0
        var currentDepth = 0
        var escaped = false
        
        for char in pattern {
            if escaped {
                escaped = false
                continue
            }
            
            if char == "\\" {
                escaped = true
                continue
            }
            
            if char == "(" {
                currentDepth += 1
                maxDepth = max(maxDepth, currentDepth)
            } else if char == ")" {
                currentDepth = max(0, currentDepth - 1)
            }
        }
        
        return maxDepth
    }
    
    /// Tests a regex pattern against a sample string to ensure it works
    /// - Parameters:
    ///   - pattern: The regex pattern
    ///   - testString: A sample string to test against
    /// - Returns: true if the pattern matches, false otherwise
    static func test(_ pattern: String, against testString: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        
        let range = NSRange(testString.startIndex..., in: testString)
        return regex.firstMatch(in: testString, range: range) != nil
    }
}
