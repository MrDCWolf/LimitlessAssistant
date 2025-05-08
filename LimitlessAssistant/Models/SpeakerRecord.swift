import GRDB
import Foundation

struct SpeakerRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64? // Internal DB ID
    var limitlessSpeakerId: String // Unique ID from Limitless API for this speaker
    var name: String // Display name, might be user-editable or initially from API
    var isUserCreator: Bool // To identify if this speaker is the primary app user
    // Removed limitlessSpeakerNameRaw as limitlessSpeakerId serves as the stable API identifier

    static var databaseTableName = "speakers"
    
    enum Columns: String, ColumnExpression {
        case id, limitlessSpeakerId, name, isUserCreator
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Default initializer
    init(id: Int64? = nil, limitlessSpeakerId: String, name: String, isUserCreator: Bool) {
        self.id = id
        self.limitlessSpeakerId = limitlessSpeakerId
        self.name = name
        self.isUserCreator = isUserCreator
    }
} 