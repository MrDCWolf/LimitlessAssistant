import GRDB
import Foundation
import os.log

class ApplicationSettingRepository {
    private let dbQueue: DatabaseQueue
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "ApplicationSettingRepository")

    init(dbQueue: DatabaseQueue = DatabaseService.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Create / Update
    // Uses settingKey as primary key with .replace conflict policy defined in the model
    func saveSetting(key: String, value: String) throws {
        let setting = ApplicationSettingRecord(settingKey: key, settingValue: value)
        try dbQueue.write {
            try setting.save($0) // save() will use INSERT OR REPLACE due to PK definition
            ApplicationSettingRepository.logger.debug("Saved application setting with key: \(key, privacy: .public)")
        }
    }

    // MARK: - Read
    func fetchSetting(forKey key: String) throws -> ApplicationSettingRecord? {
        try dbQueue.read {
            // Use the custom fetcher defined in the model for string primary keys
            try ApplicationSettingRecord.fetchOne($0, key: ["settingKey": key])
        }
    }
    
    func fetchSettingValue(forKey key: String) throws -> String? {
        try fetchSetting(forKey: key)?.settingValue
    }

    func fetchAllSettings() throws -> [ApplicationSettingRecord] {
        try dbQueue.read {
            try ApplicationSettingRecord.fetchAll($0)
        }
    }

    // MARK: - Delete
    func deleteSetting(forKey key: String) throws -> Bool {
        try dbQueue.write {
            try ApplicationSettingRecord.deleteOne($0, key: ["settingKey": key])
        }
    }

    func deleteAllSettings() throws {
        try dbQueue.write {
            _ = try ApplicationSettingRecord.deleteAll($0)
        }
    }
} 