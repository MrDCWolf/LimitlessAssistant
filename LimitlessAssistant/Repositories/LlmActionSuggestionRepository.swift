import GRDB
import Foundation
import os.log

class LlmActionSuggestionRepository {
    private let dbQueue: DatabaseQueue
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "LlmActionSuggestionRepository")

    init(dbQueue: DatabaseQueue = DatabaseService.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Create / Update
    func save(_ suggestion: inout LlmActionSuggestionRecord) throws {
        // Ensure updatedAt is set on save
        suggestion.updatedAt = Date()
        if suggestion.id == nil { // New record
            suggestion.createdAt = Date()
        }
        
        let mutableSuggestion = suggestion // Create a let constant since it's not mutated
        try dbQueue.write {
            try mutableSuggestion.save($0) // Save the constant
            LlmActionSuggestionRepository.logger.debug("Saved LLM action suggestion with ID: \(mutableSuggestion.id ?? -1)")
        }
        suggestion = mutableSuggestion // Assign back (still valid for inout)
    }

    // MARK: - Read
    func fetchAll() throws -> [LlmActionSuggestionRecord] {
        try dbQueue.read {
            try LlmActionSuggestionRecord.fetchAll($0)
        }
    }

    func fetchById(_ id: Int64) throws -> LlmActionSuggestionRecord? {
        try dbQueue.read {
            try LlmActionSuggestionRecord.fetchOne($0, key: id)
        }
    }
    
    func fetchByConversationId(_ conversationId: Int64) throws -> [LlmActionSuggestionRecord] {
        try dbQueue.read {
            try LlmActionSuggestionRecord
                .filter(LlmActionSuggestionRecord.Columns.conversationId == conversationId)
                .order(LlmActionSuggestionRecord.Columns.createdAt.desc)
                .fetchAll($0)
        }
    }
    
    func fetchByStatus(_ status: String, limit: Int = 100) throws -> [LlmActionSuggestionRecord] {
        try dbQueue.read {
            try LlmActionSuggestionRecord
                .filter(LlmActionSuggestionRecord.Columns.status == status)
                .order(LlmActionSuggestionRecord.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll($0)
        }
    }
    
    func fetchPendingReview(limit: Int = 50) throws -> [LlmActionSuggestionRecord] {
        try fetchByStatus("PENDING_REVIEW", limit: limit)
    }

    // MARK: - Delete
    func deleteById(_ id: Int64) throws -> Bool {
        try dbQueue.write {
            try LlmActionSuggestionRecord.deleteOne($0, key: id)
        }
    }

    func deleteAll() throws {
        try dbQueue.write {
            _ = try LlmActionSuggestionRecord.deleteAll($0)
        }
    }
} 