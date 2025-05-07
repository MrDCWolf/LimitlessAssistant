import GRDB
import Foundation

struct SpeakerRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var limitlessSpeakerNameRaw: String? // Optional: original name from Limitless if we normalize it
    var isUserCreator: Bool // To identify if this speaker is the primary app user

    static var databaseTableName = "speakers"
    
    enum Columns: String, ColumnExpression {
        case id, name, limitlessSpeakerNameRaw, isUserCreator
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Default initializer
    init(id: Int64? = nil, name: String, limitlessSpeakerNameRaw: String? = nil, isUserCreator: Bool) {
        self.id = id
        self.name = name
        self.limitlessSpeakerNameRaw = limitlessSpeakerNameRaw
        self.isUserCreator = isUserCreator
    }
} 