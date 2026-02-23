//
//  URLSanitizer.swift
//  Default Tamer
//
//  URL sanitization to prevent storing sensitive information
//

import Foundation

/// Utility to sanitize URLs before storing them in logs or database
enum URLSanitizer {
    
    // MARK: - Sensitive Parameter Patterns
    
    /// Common parameter names that may contain sensitive data
    private static let sensitiveParameters: Set<String> = [
        // API Keys
        "apikey", "api_key", "api-key", "key",
        
        // Authentication Tokens
        "token", "access_token", "auth_token", "bearer", "jwt",
        "id_token", "refresh_token", "oauth_token",
        
        // Session/User IDs
        "session", "sessionid", "session_id", "sid", "ssid",
        "userid", "user_id", "uid",
        
        // Secrets & Passwords
        "secret", "client_secret", "api_secret", "password",
        "pwd", "pass", "passwd",
        
        // Authentication Codes
        "code", "auth_code", "authorization_code", "verify",
        "verification", "otp", "2fa",
        
        // Cloud Provider Specific
        "signature", "x-api-key", "x-amz-security-token",
        "credentials", "auth",
        
        // Generic Sensitive
        "private", "securetoken", "accesskey"
    ]
    
    /// Patterns in the path that indicate sensitive endpoints
    private static let sensitivePaths: [String] = [
        "/api/key",
        "/auth/token",
        "/oauth",
        "/login",
        "/signin",
        "/authenticate"
    ]
    
    // MARK: - Sanitization
    
    /// Sanitize a URL by removing sensitive query parameters
    /// - Parameter url: The URL to sanitize
    /// - Returns: Sanitized URL string safe for logging/storage
    static func sanitize(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            // If we can't parse, return host only as fallback
            return url.host ?? url.absoluteString
        }
        
        // Check if path contains sensitive keywords
        let hasSensitivePath = sensitivePaths.contains { pattern in
            components.path.lowercased().contains(pattern)
        }
        
        // If URL contains sensitive path patterns, only return scheme + host
        if hasSensitivePath {
            var sanitizedComponents = URLComponents()
            sanitizedComponents.scheme = components.scheme
            sanitizedComponents.host = components.host
            sanitizedComponents.port = components.port
            return sanitizedComponents.url?.absoluteString ?? url.host ?? "[sanitized]"
        }
        
        // Sanitize query parameters
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            let sanitizedItems = queryItems.compactMap { item -> URLQueryItem? in
                let lowercasedName = item.name.lowercased()
                
                // Remove parameter if it matches sensitive patterns
                if sensitiveParameters.contains(lowercasedName) {
                    return nil
                }
                
                // Check if parameter name contains sensitive keywords
                for sensitive in sensitiveParameters {
                    if lowercasedName.contains(sensitive) {
                        return nil
                    }
                }
                
                return item
            }
            
            // Only keep query items if some remained after sanitization
            if sanitizedItems.isEmpty {
                components.queryItems = nil
            } else {
                components.queryItems = sanitizedItems
            }
        }
        
        // Remove fragment (hash) as it may contain sensitive data
        components.fragment = nil
        
        return components.url?.absoluteString ?? url.host ?? "[sanitized]"
    }
    
    /// Sanitize a URL string
    /// - Parameter urlString: The URL string to sanitize
    /// - Returns: Sanitized URL string
    static func sanitize(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return urlString
        }
        return sanitize(url)
    }
    
    /// Check if a URL contains potentially sensitive information
    /// - Parameter url: The URL to check
    /// - Returns: True if the URL appears to contain sensitive data
    static func containsSensitiveData(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }
        
        // Check path
        let hasSensitivePath = sensitivePaths.contains { pattern in
            components.path.lowercased().contains(pattern)
        }
        
        if hasSensitivePath {
            return true
        }
        
        // Check query parameters
        if let queryItems = components.queryItems {
            for item in queryItems {
                let lowercasedName = item.name.lowercased()
                
                if sensitiveParameters.contains(lowercasedName) {
                    return true
                }
                
                for sensitive in sensitiveParameters {
                    if lowercasedName.contains(sensitive) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
}
