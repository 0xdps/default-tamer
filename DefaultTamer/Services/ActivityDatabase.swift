//
//  ActivityDatabase.swift
//  Default Tamer
//
//  SQLite-based storage for activity logs
//

import Foundation
import SQLite

@MainActor
class ActivityDatabase {
    static let shared = ActivityDatabase()
    
    private var db: Connection?
    private let routeLogs = Table("route_logs")
    private let metadata = Table("metadata")
    
    // Column definitions
    private let id = Expression<String>("id")
    private let timestamp = Expression<Date>("timestamp")
    private let url = Expression<String>("url")
    private let urlHost = Expression<String>("url_host")
    private let sourceApp = Expression<String?>("source_app")
    private let matchedRuleId = Expression<String?>("matched_rule_id")
    private let matchedRuleType = Expression<String?>("matched_rule_type")
    private let targetBrowserId = Expression<String>("target_browser_id")
    private let targetBrowserName = Expression<String>("target_browser_name")
    private let fallbackUsed = Expression<Bool>("fallback_used")
    private let success = Expression<Bool>("success")
    
    // Metadata columns
    private let key = Expression<String>("key")
    private let value = Expression<String>("value")
    
    private init() {
        setupDatabase()
        performAutomaticCleanup()
    }
    
    private func setupDatabase() {
        do {
            let path = getDatabasePath()
            db = try Connection(path)
            try createTables()
            try performMigrations()
        } catch {
            debugLog("❌ Failed to setup database: \(error)")
            ErrorNotifier.shared.notifyError(
                "Database Error",
                message: "Failed to initialize activity tracking. Recent routes may not be saved."
            )
        }
    }
    
    private func getDatabasePath() -> String {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls[0].appendingPathComponent("DefaultTamer", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        return appSupport.appendingPathComponent("activity.db").path
    }
    
    private func createTables() throws {
        // Create metadata table for versioning
        try db?.run(metadata.create(ifNotExists: true) { t in
            t.column(key, primaryKey: true)
            t.column(value)
        })
        
        // Create route logs table
        try db?.run(routeLogs.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(timestamp)
            t.column(url)
            t.column(urlHost)
            t.column(sourceApp)
            t.column(matchedRuleId)
            t.column(matchedRuleType)
            t.column(targetBrowserId)
            t.column(targetBrowserName)
            t.column(fallbackUsed)
            t.column(success)
        })
        
        // Create indexes for common queries
        try db?.run(routeLogs.createIndex(timestamp, ifNotExists: true))
        try db?.run(routeLogs.createIndex(urlHost, ifNotExists: true))
        try db?.run(routeLogs.createIndex(targetBrowserId, ifNotExists: true))
        
        // Set initial version if not exists
        let currentVersion = getDatabaseVersion()
        if currentVersion == 0 {
            try setDatabaseVersion(DatabaseConstants.currentVersion)
        }
    }
    
    // MARK: - Insert
    
    func logRoute(_ log: RouteLog) {
        do {
            try db?.run(routeLogs.insert(
                id <- log.id.uuidString,
                timestamp <- log.timestamp,
                url <- log.url,
                urlHost <- log.urlHost,
                sourceApp <- log.sourceApp,
                matchedRuleId <- log.matchedRuleId?.uuidString,
                matchedRuleType <- log.matchedRuleType,
                targetBrowserId <- log.targetBrowserId,
                targetBrowserName <- log.targetBrowserName,
                fallbackUsed <- log.fallbackUsed,
                success <- log.success
            ))
        } catch {
            debugLog("❌ Failed to log route: \(error)")
        }
    }
    
    // MARK: - Migration
    
    private func getDatabaseVersion() -> Int {
        do {
            let query = metadata.filter(key == "schema_version")
            if let row = try db?.pluck(query), let versionStr = try? row.get(value) {
                return Int(versionStr) ?? 0
            }
        } catch {
            debugLog("Failed to get database version: \(error)")
        }
        return 0
    }
    
    private func setDatabaseVersion(_ version: Int) throws {
        try db?.run(metadata.insert(or: .replace, key <- "schema_version", value <- String(version)))
    }
    
    private func performMigrations() throws {
        guard let db = db else { return }
        
        let currentVersion = getDatabaseVersion()
        let targetVersion = DatabaseConstants.currentVersion
        
        // No migration needed
        guard currentVersion < targetVersion else {
            return
        }
        
        debugLog("📦 Starting database migration from v\(currentVersion) to v\(targetVersion)")
        
        // Backup database before migration
        try backupDatabase()
        
        do {
            // Wrap all migrations in a single transaction
            // Automatically rolls back if any migration fails
            try db.transaction {
                var version = currentVersion
                
                // Migration 1→2
                if version < 2 {
                    try migrateToVersion2(db: db)
                    version = 2
                    debugLog("   ✅ Migrated to v2")
                }
                
                // Migration 2→3 (example for future use)
                // if version < 3 {
                //     try migrateToVersion3(db: db)
                //     version = 3
                //     debugLog("   ✅ Migrated to v3")
                // }
                
                // Update version only if all migrations succeed
                try setDatabaseVersion(targetVersion)
                debugLog("✅ Migration complete: v\(currentVersion) → v\(targetVersion)")
            }
        } catch {
            debugLog("❌ Migration failed: \(error)")
            debugLog("   Attempting to restore from backup...")
            
            // Restore from backup on failure
            do {
                try restoreDatabase()
                debugLog("   ✅ Database restored from backup")
            } catch {
                debugLog("   ❌ Backup restoration failed: \(error)")
            }
            
            // Re-throw original migration error
            throw error
        }
    }
    
    // MARK: - Migration Steps
    
    private func migrateToVersion2(db: Connection) throws {
        // Example migration - add duration column
        // try db.run("ALTER TABLE route_logs ADD COLUMN duration INTEGER DEFAULT 0")
        
        // For now, this is a placeholder for future v2 migration
        // The database is already at v1, so this would only run for users on old schema
    }
    
    // MARK: - Backup & Restore
    
    private func backupDatabase() throws {
        let dbPath = getDatabasePath()
        let backupPath = getBackupPath()
        
        // Remove old backup if exists
        try? FileManager.default.removeItem(atPath: backupPath)
        
        // Copy database to backup location
        try FileManager.default.copyItem(atPath: dbPath, toPath: backupPath)
        debugLog("   💾 Database backed up: \(backupPath)")
    }
    
    private func restoreDatabase() throws {
        let dbPath = getDatabasePath()
        let backupPath = getBackupPath()
        
        // Close current connection
        db = nil
        
        // Remove current (corrupted) database
        try FileManager.default.removeItem(atPath: dbPath)
        
        // Restore from backup
        try FileManager.default.copyItem(atPath: backupPath, toPath: dbPath)
        
        // Reconnect to restored database
        db = try Connection(dbPath)
        
        debugLog("   ✅ Database restored from backup")
    }
    
    private func getBackupPath() -> String {
        let dbDir = URL(fileURLWithPath: getDatabasePath()).deletingLastPathComponent()
        return dbDir.appendingPathComponent("activity.db.backup").path
    }
    
    // MARK: - Automatic Cleanup
    
    private func performAutomaticCleanup() {
        // Run cleanup in background to avoid blocking startup
        Task.detached(priority: .background) {
            await self.deleteOldLogs(olderThan: DatabaseConstants.maxLogsRetentionDays)
            #if DEBUG
            let count = await self.getLogCount()
            debugLog("📊 Database cleanup complete. \(count) logs retained.")
            #endif
        }
    }
    
    // MARK: - Query
    
    func fetchRecentLogs(limit: Int = 100) -> [RouteLog] {
        var logs: [RouteLog] = []
        
        do {
            let query = routeLogs
                .order(timestamp.desc)
                .limit(limit)
            
            guard let db = db else { return logs }
            for row in try db.prepare(query) {
                if let log = parseRow(row) {
                    logs.append(log)
                }
            }
        } catch {
            debugLog("❌ Failed to fetch logs: \(error)")
        }
        
        return logs
    }
    
    func fetchLogs(
        fromDate: Date? = nil,
        toDate: Date? = nil,
        host: String? = nil,
        browserId: String? = nil,
        sourceApp: String? = nil,
        limit: Int = 1000
    ) -> [RouteLog] {
        var logs: [RouteLog] = []
        
        do {
            var query = routeLogs.order(timestamp.desc).limit(limit)
            
            // Apply filters
            if let fromDate = fromDate {
                query = query.filter(timestamp >= fromDate)
            }
            if let toDate = toDate {
                query = query.filter(timestamp <= toDate)
            }
            if let host = host {
                query = query.filter(urlHost == host)
            }
            if let browserId = browserId {
                query = query.filter(targetBrowserId == browserId)
            }
            if let sourceApp = sourceApp {
                query = query.filter(self.sourceApp == sourceApp)
            }
            
            guard let db = db else { return logs }
            for row in try db.prepare(query) {
                if let log = parseRow(row) {
                    logs.append(log)
                }
            }
        } catch {
            debugLog("❌ Failed to fetch filtered logs: \(error)")
        }
        
        return logs
    }
    
    func getLogCount() -> Int {
        do {
            return try db?.scalar(routeLogs.count) ?? 0
        } catch {
            debugLog("❌ Failed to get log count: \(error)")
            return 0
        }
    }
    
    // MARK: - Delete
    
    func deleteOldLogs(olderThan days: Int) {
        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            try db?.run(routeLogs.filter(timestamp < cutoffDate).delete())
        } catch {
            debugLog("❌ Failed to delete old logs: \(error)")
        }
    }
    
    func deleteAllLogs() {
        do {
            try db?.run(routeLogs.delete())
        } catch {
            debugLog("❌ Failed to delete all logs: \(error)")
        }
    }
    
    // MARK: - Helper
    
    private func parseRow(_ row: Row) -> RouteLog? {
        guard let id = UUID(uuidString: row[self.id]) else { return nil }
        
        return RouteLog(
            id: id,
            timestamp: row[timestamp],
            url: row[url],
            urlHost: row[urlHost],
            sourceApp: row[sourceApp],
            matchedRuleId: row[matchedRuleId].flatMap { UUID(uuidString: $0) },
            matchedRuleType: row[matchedRuleType],
            targetBrowserId: row[targetBrowserId],
            targetBrowserName: row[targetBrowserName],
            fallbackUsed: row[fallbackUsed],
            success: row[success]
        )
    }
}
