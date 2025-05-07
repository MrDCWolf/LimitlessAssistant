import GRDB
import Foundation

struct UserActionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var suggestionId: Int64          // Foreign key to LlmActionSuggestionRecord
    var actionType: String           // E.g., "ACCEPTED", "DECLINED", "EDITED_ACCEPTED"
    var correctedItemType: String?   // If user changed the item type
    var correctedTitle: String?      // If user changed the title
    // Add other corrected fields as needed (e.g., correctedDate, correctedDetails)
    var declineReason: String?       // If user declined, optionally why
    var actionTimestamp: Date

    static var databaseTableName = "userActions"
    
    enum Columns: String, ColumnExpression {
        case id, suggestionId, actionType, correctedItemType, correctedTitle, declineReason, actionTimestamp
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Default initializer
    init(id: Int64? = nil, suggestionId: Int64, actionType: String, correctedItemType: String? = nil, correctedTitle: String? = nil, declineReason: String? = nil, actionTimestamp: Date = Date()) {
        self.id = id
        self.suggestionId = suggestionId
        self.actionType = actionType
        self.correctedItemType = correctedItemType
        self.correctedTitle = correctedTitle
        self.declineReason = declineReason
        self.actionTimestamp = actionTimestamp
    }
} 