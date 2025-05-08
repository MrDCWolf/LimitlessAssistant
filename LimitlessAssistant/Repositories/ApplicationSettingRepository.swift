import GRDB
import Foundation

struct ApplicationSettingRepository {
    private var dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: - Save & Fetch Operations

    /// Saves an application setting (inserts or updates if the key already exists).
    /// The `updatedAt` timestamp is automatically managed.
    /// Returns the saved setting record.
    func saveSetting(_ setting: ApplicationSettingRecord) async throws -> ApplicationSettingRecord {
        return try await dbWriter.write { db -> ApplicationSettingRecord in
            var settingToPersist = setting
            settingToPersist.updatedAt = Date()
            try settingToPersist.save(db)
            return settingToPersist
        }
    }

    /// Convenience function to save or update a setting by its key and a new string value.
    /// Returns the saved setting record.
    @discardableResult
    func saveSetting(key: ApplicationSettingRecord.Key, value: String) async throws -> ApplicationSettingRecord {
        let setting = ApplicationSettingRecord(key: key, value: value, updatedAt: Date())
        return try await saveSetting(setting)
    }

    /// Fetches an application setting record by its key.
    func fetchSetting(forKey key: ApplicationSettingRecord.Key) async throws -> ApplicationSettingRecord? {
        try await dbWriter.read { db in
            try ApplicationSettingRecord.fetchOne(db, key: key.rawValue)
        }
    }
    
    /// Fetches the string value of an application setting by its key.
    /// Returns nil if the setting is not found.
    func fetchStringValue(forKey key: ApplicationSettingRecord.Key) async throws -> String? {
        let setting = try await fetchSetting(forKey: key)
        return setting?.value
    }

    /// Fetches all application settings, ordered by key.
    func fetchAllSettings() async throws -> [ApplicationSettingRecord] {
        try await dbWriter.read { db in
            try ApplicationSettingRecord.order(Column(ApplicationSettingRecord.CodingKeys.settingKey.rawValue).asc).fetchAll(db)
        }
    }

    // MARK: - Delete Operations

    /// Deletes an application setting by its key.
    @discardableResult
    func deleteSetting(forKey key: ApplicationSettingRecord.Key) async throws -> Bool {
        try await dbWriter.write { db in
            try ApplicationSettingRecord.deleteOne(db, key: key.rawValue)
        }
    }

    /// Deletes all application settings from the database.
    /// Use with caution.
    func deleteAllSettings() async throws {
        _ = try await dbWriter.write { db in
            try ApplicationSettingRecord.deleteAll(db)
        }
    }
} 