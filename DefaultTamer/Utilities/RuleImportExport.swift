//
//  RuleImportExport.swift
//  Default Tamer
//
//  Import/Export functionality for routing rules
//

import Foundation
import UniformTypeIdentifiers

enum ExportFormat {
    case json
    case csv
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        }
    }
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        }
    }
}

enum ImportMode {
    case replace    // Replace all existing rules
    case append     // Add to existing rules
    case merge      // Merge, avoiding duplicates
    
    var displayName: String {
        switch self {
        case .replace: return "Replace All"
        case .append: return "Append"
        case .merge: return "Merge"
        }
    }
    
    var description: String {
        switch self {
        case .replace:
            return "Replace all existing rules with imported ones"
        case .append:
            return "Add imported rules to existing ones (may create duplicates)"
        case .merge:
            return "Add only new rules that don't already exist"
        }
    }
}

class RuleImportExport {
    
    // MARK: - Export
    
    /// Export rules to JSON format
    static func exportToJSON(_ rules: [Rule]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let exportData = RulesExport(
            version: 1,
            exportedAt: Date(),
            appVersion: AppVersion.current,
            rules: rules
        )
        
        return try encoder.encode(exportData)
    }
    
    /// Export rules to CSV format
    static func exportToCSV(_ rules: [Rule]) throws -> Data {
        var csv = "Type,Enabled,Pattern/Domain/Bundle ID,Target Browser,URL Contains,URL Regex\n"
        
        for rule in rules {
            let type = rule.type.rawValue
            let enabled = rule.enabled ? "Yes" : "No"
            
            let pattern: String
            switch rule.type {
            case .domain:
                let domainType = rule.domainMatchType?.rawValue ?? "Exact"
                pattern = "\(rule.domainPattern ?? "") (\(domainType))"
            case .urlPattern:
                pattern = rule.urlContains ?? rule.urlRegex ?? ""
            case .sourceApp:
                pattern = rule.sourceAppName ?? rule.sourceAppBundleId ?? ""
            }
            
            let targetBrowser = rule.targetBrowserId
            let urlContains = rule.urlContains ?? ""
            let urlRegex = rule.urlRegex ?? ""
            
            // Escape CSV fields that contain commas or quotes
            let escapedPattern = escapeCSVField(pattern)
            let escapedTargetBrowser = escapeCSVField(targetBrowser)
            let escapedUrlContains = escapeCSVField(urlContains)
            let escapedUrlRegex = escapeCSVField(urlRegex)
            
            csv += "\(type),\(enabled),\(escapedPattern),\(escapedTargetBrowser),\(escapedUrlContains),\(escapedUrlRegex)\n"
        }
        
        guard let data = csv.data(using: .utf8) else {
            throw AppError.persistence(reason: "Failed to encode CSV data")
        }
        
        return data
    }
    
    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    // MARK: - Import
    
    /// Import rules from JSON data
    static func importFromJSON(_ data: Data, mode: ImportMode, existingRules: [Rule]) throws -> [Rule] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportData: RulesExport
        do {
            exportData = try decoder.decode(RulesExport.self, from: data)
        } catch {
            // Try decoding as plain array of rules (for backward compatibility)
            let importedRules = try decoder.decode([Rule].self, from: data)
            return applyImportMode(importedRules, mode: mode, existingRules: existingRules)
        }
        
        // Validate version compatibility
        if exportData.version > 1 {
            throw AppError.invalidRule(reason: "Unsupported export format version \(exportData.version)")
        }
        
        return applyImportMode(exportData.rules, mode: mode, existingRules: existingRules)
    }
    
    /// Import rules from CSV data
    static func importFromCSV(_ data: Data, mode: ImportMode, existingRules: [Rule]) throws -> [Rule] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw AppError.persistence(reason: "Failed to decode CSV data")
        }
        
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw AppError.invalidRule(reason: "CSV file is empty or invalid")
        }
        
        var importedRules: [Rule] = []
        
        // Skip header line
        for (index, line) in lines.enumerated() where index > 0 {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            
            guard let rule = parseCSVLine(trimmed, lineNumber: index + 1) else {
                debugLog("⚠️ Skipping invalid CSV line \(index + 1)")
                continue
            }
            
            importedRules.append(rule)
        }
        
        if importedRules.isEmpty {
            throw AppError.invalidRule(reason: "No valid rules found in CSV file")
        }
        
        return applyImportMode(importedRules, mode: mode, existingRules: existingRules)
    }
    
    private static func parseCSVLine(_ line: String, lineNumber: Int) -> Rule? {
        let fields = parseCSVFields(line)
        
        guard fields.count >= 4 else {
            return nil
        }
        
        let typeStr = fields[0]
        let enabledStr = fields[1]
        let pattern = fields[2]
        let targetBrowser = fields[3]
        let urlContains = fields.count > 4 ? fields[4] : nil
        let urlRegex = fields.count > 5 ? fields[5] : nil
        
        guard let ruleType = RuleType(rawValue: typeStr) else {
            return nil
        }
        
        var rule = Rule(type: ruleType, targetBrowserId: targetBrowser)
        rule.enabled = enabledStr.lowercased() == "yes"
        
        switch ruleType {
        case .domain:
            // Extract domain and match type from pattern
            if let rangeStart = pattern.range(of: " ("),
               let rangeEnd = pattern.range(of: ")", options: .backwards) {
                let domain = String(pattern[..<rangeStart.lowerBound])
                let matchTypeStr = String(pattern[rangeStart.upperBound..<rangeEnd.lowerBound])
                rule.domainPattern = domain
                rule.domainMatchType = DomainMatchType(rawValue: matchTypeStr) ?? .exact
            } else {
                rule.domainPattern = pattern
                rule.domainMatchType = .exact
            }
        case .urlPattern:
            if let urlContains = urlContains, !urlContains.isEmpty {
                rule.urlContains = urlContains
            }
            if let urlRegex = urlRegex, !urlRegex.isEmpty {
                rule.urlRegex = urlRegex
            }
        case .sourceApp:
            // Try to parse as bundle ID or app name
            if pattern.contains(".") {
                rule.sourceAppBundleId = pattern
            } else {
                rule.sourceAppName = pattern
            }
        }
        
        return rule
    }
    
    private static func parseCSVFields(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                // Check for escaped quote
                let nextIndex = line.index(after: i)
                if insideQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                    currentField.append("\"")
                    i = nextIndex
                } else {
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
            
            i = line.index(after: i)
        }
        
        fields.append(currentField)
        return fields
    }
    
    private static func applyImportMode(_ importedRules: [Rule], mode: ImportMode, existingRules: [Rule]) -> [Rule] {
        switch mode {
        case .replace:
            return importedRules
            
        case .append:
            return existingRules + importedRules
            
        case .merge:
            var merged = existingRules
            for importedRule in importedRules {
                // Check if rule already exists (based on type and pattern)
                let isDuplicate = existingRules.contains { existing in
                    guard existing.type == importedRule.type else { return false }
                    guard existing.targetBrowserId == importedRule.targetBrowserId else { return false }
                    
                    switch importedRule.type {
                    case .domain:
                        return existing.domainPattern == importedRule.domainPattern
                    case .urlPattern:
                        return existing.urlContains == importedRule.urlContains &&
                               existing.urlRegex == importedRule.urlRegex
                    case .sourceApp:
                        return existing.sourceAppBundleId == importedRule.sourceAppBundleId
                    }
                }
                
                if !isDuplicate {
                    merged.append(importedRule)
                }
            }
            return merged
        }
    }
}

// MARK: - Export Data Structure

struct RulesExport: Codable {
    let version: Int
    let exportedAt: Date
    let appVersion: String
    let rules: [Rule]
}
