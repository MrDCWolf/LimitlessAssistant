import GRDB
import Foundation

struct ConversationRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var limitlessLogId: String // From Limitless lifelogs.id
    var title: String?
    var conversationStartTime: Date
    var conversationEndTime: Date?
    var creatorId: String // To identify the user's transcripts
    var fullMarkdownContent: String?
    var logicalEventId: String? // UUID String to group related lifelogs
    var processedStatusActions: Int // 0: pending, 1: processing, 2: processed, 3: error
    var createdAt: Date

    static var databaseTableName = "conversations"

    // Column names for easier querying (optional but good practice)
    enum Columns: String, ColumnExpression {
        case id, limitlessLogId, title, conversationStartTime, conversationEndTime, creatorId, fullMarkdownContent, logicalEventId, processedStatusActions, createdAt
    }

    // Let GRDB handle the auto-incremented ID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Default initializer
    init(id: Int64? = nil, limitlessLogId: String, title: String? = nil, conversationStartTime: Date, conversationEndTime: Date? = nil, creatorId: String, fullMarkdownContent: String? = nil, logicalEventId: String? = nil, processedStatusActions: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.limitlessLogId = limitlessLogId
        self.title = title
        self.conversationStartTime = conversationStartTime
        self.conversationEndTime = conversationEndTime
        self.creatorId = creatorId
        self.fullMarkdownContent = fullMarkdownContent
        self.logicalEventId = logicalEventId
        self.processedStatusActions = processedStatusActions
        self.createdAt = createdAt
    }
} 