//
//  RuleStore.swift
//  Default Tamer
//
//  SQLite-backed storage for routing rules.
//
//  Replaces the UserDefaults-based rules storage with a per-rule database
//  that supports incremental updates, partial corruption recovery, and
//  scales better for users with many rules.
//
//  Migration from UserDefaults is automatic: on first load, if the database
//  is empty but UserDefaults contains rules, they are imported.
//

import Foundation
import SQLite

@MainActor
class RuleStore {
    static let shared = RuleStore()

    private var db: Connection?
    private let rules = Table("rules")

    // Column definitions
    private let id = Expression<String>("id")
    private let data = Expression<Blob>("data")  // JSON-encoded Rule
    private let orderIndex = Expression<Int>("order_index")
    private let enabled = Expression<Bool>("enabled")
    private let type = Expression<String>("type")

    private init() {
        setupDatabase()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            let path = getDatabasePath()
            db = try Connection(path)
            try createTables()
        } catch {
            debugLog("❌ Failed to setup rules database: \(error)")
            ErrorNotifier.shared.notifyError(
                "Database Error",
                message: "Failed to initialize rules storage. Rules may not be saved."
            )
        }
    }

    private func getDatabasePath() -> String {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls[0].appendingPathComponent("DefaultTamer", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("rules.db").path
    }

    private func createTables() throws {
        try db?.run(rules.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(data)
            t.column(orderIndex)
            t.column(enabled)
            t.column(type)
        })
        try db?.run(rules.createIndex(orderIndex, ifNotExists: true))
    }

    // MARK: - CRUD

    func loadAllRules() -> [Rule] {
        guard let db = db else { return [] }

        do {
            let query = rules.order(orderIndex.asc)
            var result: [Rule] = []
            for row in try db.prepare(query) {
                let blob = try row.get(data)
                let jsonData = Data(blob.bytes)
                if let rule = try? JSONDecoder().decode(Rule.self, from: jsonData) {
                    result.append(rule)
                }
            }
            return result
        } catch {
            debugLog("❌ Failed to load rules from database: \(error)")
            return []
        }
    }

    func saveAllRules(_ ruleList: [Rule]) {
        guard let db = db else { return }

        do {
            try db.transaction {
                // Clear existing rules
                try db.run(rules.delete())

                // Insert all rules with order index
                for (index, rule) in ruleList.enumerated() {
                    let encoded = try JSONEncoder().encode(rule)
                    try db.run(rules.insert(
                        id <- rule.id.uuidString,
                        data <- Blob(bytes: [UInt8](encoded)),
                        orderIndex <- index,
                        enabled <- rule.enabled,
                        type <- rule.type.rawValue
                    ))
                }
            }
        } catch {
            debugLog("❌ Failed to save rules to database: \(error)")
            Task { @MainActor in
                ErrorHandler.shared.handleCritical(
                    AppError.databaseError(reason: "Failed to save rules", underlying: error),
                    context: "RuleStore.saveAllRules"
                )
            }
        }
    }

    // MARK: - Testing

    /// Clears all rules from the database. Used by tests for isolation.
    func clearAllRules() {
        guard let db = db else { return }
        do {
            try db.run(rules.delete())
        } catch {
            debugLog("❌ Failed to clear rules: \(error)")
        }
    }

    // MARK: - Migration

    /// Migrates rules from UserDefaults to SQLite if needed.
    /// Called once on app launch. If the database already has rules, this is a no-op.
    func migrateFromUserDefaultsIfNeeded(userDefaults: UserDefaults, rulesKey: String) {
        guard let db = db else { return }

        // Check if database already has rules
        let count = (try? db.scalar(rules.count)) ?? 0
        guard count == 0 else { return }

        // Check if UserDefaults has rules to migrate
        guard let data = userDefaults.data(forKey: rulesKey) else { return }

        do {
            let oldRules = try JSONDecoder().decode([Rule].self, from: data)
            if !oldRules.isEmpty {
                debugLog("📦 Migrating \(oldRules.count) rules from UserDefaults to SQLite")
                saveAllRules(oldRules)
                // Keep the UserDefaults data as a backup but don't delete it
                // (in case the migration needs to be reversed)
                debugLog("✅ Migration complete — \(oldRules.count) rules moved to SQLite")
            }
        } catch {
            debugLog("⚠️ Failed to migrate rules from UserDefaults: \(error)")
        }
    }
}