import GRDB
import Foundation

struct LlmActionSuggestionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var conversationId: Int64           // Link to the ConversationRecord this suggestion belongs to
    var triggeringUtteranceIdStart: Int64? // Optional: Link to the first utterance that triggered this
    var triggeringUtteranceIdEnd: Int64?   // Optional: Link to the last utterance in a triggering span
    var triggeringSnippetText: String?  // The actual text snippet from utterance(s) that triggered suggestion

    var llmName: String?                // Name of the LLM used (e.g., "GPT-4o", "Gemini-Pro")
    var llmPromptVersion: String?       // Version of the prompt used to generate this suggestion
    var llmRawResponse: String?         // Full raw response from LLM for debugging/auditing

    var suggestedItemType: String       // E.g., "EVENT", "TASK", "REMINDER"
    var extractedTitle: String?
    var extractedStartDate: Date?
    var extractedEndDate: Date?         // For events with duration
    var extractedLocation: String?
    var extractedDetails: String?       // Description or notes for the item
    var extractedAttendees: String?     // Comma-separated list or JSON string of attendees

    var confidenceScore: Double?        // LLM's confidence in this suggestion (0.0 to 1.0)
    var status: String                  // E.g., "PENDING_REVIEW", "ACCEPTED", "DECLINED", "AUTO_ADDED"
    var googleItemId: String?           // ID of the item created in Google Calendar/Tasks

    var createdAt: Date
    var updatedAt: Date

    static var databaseTableName = "llmActionSuggestions"

    enum Columns: String, ColumnExpression {
        case id, conversationId, triggeringUtteranceIdStart, triggeringUtteranceIdEnd, triggeringSnippetText
        case llmName, llmPromptVersion, llmRawResponse
        case suggestedItemType, extractedTitle, extractedStartDate, extractedEndDate, extractedLocation, extractedDetails, extractedAttendees
        case confidenceScore, status, googleItemId
        case createdAt, updatedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Default initializer
    init(id: Int64? = nil, conversationId: Int64, triggeringUtteranceIdStart: Int64? = nil, triggeringUtteranceIdEnd: Int64? = nil, triggeringSnippetText: String? = nil, llmName: String? = nil, llmPromptVersion: String? = nil, llmRawResponse: String? = nil, suggestedItemType: String, extractedTitle: String? = nil, extractedStartDate: Date? = nil, extractedEndDate: Date? = nil, extractedLocation: String? = nil, extractedDetails: String? = nil, extractedAttendees: String? = nil, confidenceScore: Double? = nil, status: String, googleItemId: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.conversationId = conversationId
        self.triggeringUtteranceIdStart = triggeringUtteranceIdStart
        self.triggeringUtteranceIdEnd = triggeringUtteranceIdEnd
        self.triggeringSnippetText = triggeringSnippetText
        self.llmName = llmName
        self.llmPromptVersion = llmPromptVersion
        self.llmRawResponse = llmRawResponse
        self.suggestedItemType = suggestedItemType
        self.extractedTitle = extractedTitle
        self.extractedStartDate = extractedStartDate
        self.extractedEndDate = extractedEndDate
        self.extractedLocation = extractedLocation
        self.extractedDetails = extractedDetails
        self.extractedAttendees = extractedAttendees
        self.confidenceScore = confidenceScore
        self.status = status
        self.googleItemId = googleItemId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 