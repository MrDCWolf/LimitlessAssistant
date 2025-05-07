import GRDB
import Foundation

struct UtteranceRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var conversationId: Int64 // Foreign key to ConversationRecord
    var speakerId: Int64?      // Foreign key to SpeakerRecord (nullable if speaker unknown)
    var textContent: String    // The actual text of the utterance (will be FTS5 indexed)
    var utteranceStartTime: Date
    var utteranceEndTime: Date?
    var startOffsetMs: Int?    // Start offset within the original Limitless log (milliseconds)
    var endOffsetMs: Int?      // End offset within the original Limitless log (milliseconds)
    var sequenceInConversation: Int // Order of utterance in its conversation
    var contentType: String?   // E.g., "speech", "note"

    static var databaseTableName = "utterances"

    enum Columns: String, ColumnExpression {
        case id, conversationId, speakerId, textContent, utteranceStartTime, utteranceEndTime, startOffsetMs, endOffsetMs, sequenceInConversation, contentType
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Default initializer
    init(id: Int64? = nil, conversationId: Int64, speakerId: Int64? = nil, textContent: String, utteranceStartTime: Date, utteranceEndTime: Date? = nil, startOffsetMs: Int? = nil, endOffsetMs: Int? = nil, sequenceInConversation: Int, contentType: String? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.speakerId = speakerId
        self.textContent = textContent
        self.utteranceStartTime = utteranceStartTime
        self.utteranceEndTime = utteranceEndTime
        self.startOffsetMs = startOffsetMs
        self.endOffsetMs = endOffsetMs
        self.sequenceInConversation = sequenceInConversation
        self.contentType = contentType
    }
} 