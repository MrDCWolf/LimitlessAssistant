import GRDB
import Foundation

struct ApplicationSettingRecord: Codable, FetchableRecord, PersistableRecord {
    var settingKey: String      // The unique key for the setting (e.g., "userCreatorId", "defaultCalendarId")
    var settingValue: String    // The value of the setting

    static var databaseTableName = "applicationSettings"

    init(settingKey: String, settingValue: String) {
        self.settingKey = settingKey
        self.settingValue = settingValue
    }
} 