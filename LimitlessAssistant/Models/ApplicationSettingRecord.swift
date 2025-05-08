import GRDB
import Foundation

struct ApplicationSettingRecord: Codable, FetchableRecord, PersistableRecord {
    var settingKey: Key // The unique key for the setting, using the enum
    var value: String    // The value of the setting
    var updatedAt: Date  // Timestamp of the last update

    static var databaseTableName = "applicationSettings"
    
    enum CodingKeys: String, CodingKey {
        case settingKey // This matches the property name
        case value
        case updatedAt
    }

    /// Enum for type-safe setting keys.
    enum Key: String, Codable, CaseIterable, DatabaseValueConvertible {
        case limitlessUserCreatorId = "limitlessUserCreatorId"
        case googleDefaultCalendarId = "googleDefaultCalendarId"
        case googleDefaultTasksListId = "googleDefaultTasksListId"
        case dataFetchScheduleMinutes = "dataFetchScheduleMinutes"
        case llmConfidenceThresholdHigh = "llmConfidenceThresholdHigh"
        case llmServicePreference = "llmServicePreference" // e.g., "openai", "gemini"
        case openAiApiKey = "openAiApiKey_in_keychain_placeholder"
        case geminiApiKey = "geminiApiKey_in_keychain_placeholder"
        // Add other specific keys as needed
        
        // DatabaseValueConvertible conformance
        var databaseValue: DatabaseValue {
            self.rawValue.databaseValue
        }
        
        static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Key? {
            guard let rawValue = String.fromDatabaseValue(dbValue) else {
                return nil
            }
            return Key(rawValue: rawValue)
        }
    }

    init(key: Key, value: String, updatedAt: Date = Date()) {
        self.settingKey = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

// GRDB TableRecord conformance is not strictly needed if Codable conformance is enough 
// and the primary key is correctly identified by GRDB (e.g. if it were 'id' or 'rowid').
// Since 'settingKey' is our PK and is a String (from Key.rawValue), GRDB should handle it.
// The custom strategies for column encoding/decoding are only needed if Key itself was directly stored 
// in a way GRDB doesn't natively understand, or if property names didn't match column names.
// Given Key.rawValue is a String, and ApplicationSettingRecord is Codable, this should be simpler.
// We just need to make sure GRDB uses `settingKey` as the PK.

// We can define the primary key using standard GRDB mechanisms if not inferable.
// In this case, `PersistableRecord` will use the `settingKey` column as PK because it is `TEXT PRIMARY KEY` in the schema. 