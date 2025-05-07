import GRDB
import Foundation
import os.log

class ConversationRepository {
    private let dbQueue: DatabaseQueue
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "ConversationRepository")

    init(dbQueue: DatabaseQueue = DatabaseService.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Create
    func save(_ conversation: inout ConversationRecord) throws {
        let mutableConversation = conversation
        try dbQueue.write {
            try mutableConversation.save($0)
            ConversationRepository.logger.debug("Saved conversation with ID: \(mutableConversation.id ?? -1)")
        }
        conversation = mutableConversation
    }
    
    // MARK: - Read
    func fetchAll() throws -> [ConversationRecord] {
        try dbQueue.read {
            try ConversationRecord.fetchAll($0)
        }
    }

    func fetchById(_ id: Int64) throws -> ConversationRecord? {
        try dbQueue.read {
            try ConversationRecord.fetchOne($0, key: id)
        }
    }
    
    func fetchByLimitlessLogId(_ limitlessLogId: String) throws -> ConversationRecord? {
        try dbQueue.read {
            try ConversationRecord.filter(ConversationRecord.Columns.limitlessLogId == limitlessLogId).fetchOne($0)
        }
    }
    
    func fetchByLogicalEventId(_ logicalEventId: String) throws -> [ConversationRecord] {
        try dbQueue.read {
            try ConversationRecord.filter(ConversationRecord.Columns.logicalEventId == logicalEventId)
                .order(ConversationRecord.Columns.conversationStartTime.asc)
                .fetchAll($0)
        }
    }
    
    func fetchPendingProcessing(limit: Int = 10) throws -> [ConversationRecord] {
        try dbQueue.read {
            try ConversationRecord.filter(ConversationRecord.Columns.processedStatusActions == 0)
                .order(ConversationRecord.Columns.conversationStartTime.asc)
                .limit(limit)
                .fetchAll($0)
        }
    }

    /// Fetches conversations that are temporally adjacent to a given conversation ID, within a specified time window.
    /// - Parameters:
    ///   - conversationId: The ID of the reference conversation.
    ///   - windowMinutes: The time window in minutes to look before and after the reference conversation.
    /// - Returns: A tuple containing arrays of preceding and succeeding `ConversationRecord`s.
    func fetchAdjacentConversationRecords(forConversationId conversationId: Int64, windowMinutes: Int) throws -> (preceding: [ConversationRecord], succeeding: [ConversationRecord]) {
        guard let referenceConversation = try fetchById(conversationId) else {
            ConversationRepository.logger.warning("Reference conversation with ID \(conversationId) not found for fetching adjacent records.")
            return ([], [])
        }
        
        let windowInterval = TimeInterval(windowMinutes * 60)
        let startTime = referenceConversation.conversationStartTime
        let endTime = referenceConversation.conversationEndTime ?? startTime // Use start time if end time is nil

        let preceding = try dbQueue.read { db -> [ConversationRecord] in
            try ConversationRecord
                .filter(ConversationRecord.Columns.creatorId == referenceConversation.creatorId)
                .filter(ConversationRecord.Columns.id != referenceConversation.id)
                .filter(ConversationRecord.Columns.conversationEndTime >= startTime.addingTimeInterval(-windowInterval))
                .filter(ConversationRecord.Columns.conversationStartTime < startTime)
                .order(ConversationRecord.Columns.conversationStartTime.desc) // Closest first
                .fetchAll(db)
        }

        let succeeding = try dbQueue.read { db -> [ConversationRecord] in
            try ConversationRecord
                .filter(ConversationRecord.Columns.creatorId == referenceConversation.creatorId)
                .filter(ConversationRecord.Columns.id != referenceConversation.id)
                .filter(ConversationRecord.Columns.conversationStartTime <= endTime.addingTimeInterval(windowInterval))
                .filter(ConversationRecord.Columns.conversationStartTime > endTime)
                .order(ConversationRecord.Columns.conversationStartTime.asc) // Closest first
                .fetchAll(db)
        }
        
        return (preceding.reversed(), succeeding) // Reverse preceding to maintain chronological order if combined
    }

    // MARK: - Update
    // `save` method handles updates if the record already has an ID.

    // MARK: - Delete
    func deleteById(_ id: Int64) throws -> Bool {
        try dbQueue.write {
            try ConversationRecord.deleteOne($0, key: id)
        }
    }

    func deleteAll() throws {
        try dbQueue.write {
            _ = try ConversationRecord.deleteAll($0)
        }
    }
} 