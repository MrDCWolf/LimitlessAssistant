import GRDB
import Foundation

struct ConversationRepository {
    private var dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: - CRUD Operations

    /// Creates a new conversation record in the database.
    func create(_ conversation: ConversationRecord) async throws -> ConversationRecord {
        return try await dbWriter.write { db -> ConversationRecord in
            let conversationToInsert = conversation
            try conversationToInsert.insert(db)
            return conversationToInsert
        }
    }

    /// Fetches a conversation record by its ID.
    func fetchOne(id: Int64) async throws -> ConversationRecord? {
        try await dbWriter.read { db in
            try ConversationRecord.fetchOne(db, key: id)
        }
    }

    /// Fetches all conversation records.
    func fetchAll() async throws -> [ConversationRecord] {
        try await dbWriter.read { db in
            try ConversationRecord.fetchAll(db)
        }
    }
    
    /// Fetches all conversation records matching a specific logicalEventId, ordered by start time.
    func fetchAll(logicalEventId: String) async throws -> [ConversationRecord] {
        try await dbWriter.read { db in
            try ConversationRecord
                .filter(ConversationRecord.Columns.logicalEventId == logicalEventId)
                .order(ConversationRecord.Columns.conversationStartTime.asc)
                .fetchAll(db)
        }
    }

    /// Updates an existing conversation record.
    func update(_ conversation: ConversationRecord) async throws {
        try await dbWriter.write { db in
            try conversation.update(db)
        }
    }

    /// Deletes a conversation record by its ID.
    @discardableResult
    func delete(id: Int64) async throws -> Bool {
        try await dbWriter.write { db in
            try ConversationRecord.deleteOne(db, key: id)
        }
    }

    // MARK: - Other Specific Queries
    
    /// Fetches a conversation by its `limitlessLogId`.
    func fetchByLimitlessLogId(_ limitlessLogId: String) async throws -> ConversationRecord? {
        try await dbWriter.read { db in
            try ConversationRecord.filter(ConversationRecord.Columns.limitlessLogId == limitlessLogId).fetchOne(db)
        }
    }

    /// Fetches all conversation records that are pending LLM action processing.
    /// Sorted by conversation start time, oldest first.
    func fetchPendingProcessing(limit: Int = 10) async throws -> [ConversationRecord] {
        try await dbWriter.read { db in
            try ConversationRecord
                .filter(ConversationRecord.Columns.processedStatusActions == 0) // 0 means pending
                .order(ConversationRecord.Columns.conversationStartTime.asc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    /// Fetches conversations that are temporally adjacent to a given conversation ID, 
    /// within a specified time window, and by the same creator.
    /// - Parameters:
    ///   - conversationId: The ID of the reference conversation.
    ///   - windowMinutes: The time window in minutes to look before the start and after the end of the reference conversation.
    /// - Returns: A tuple containing arrays of preceding and succeeding `ConversationRecord`s, chronologically ordered.
    func fetchAdjacentConversationRecords(forConversationId conversationId: Int64, windowMinutes: Int) async throws -> (preceding: [ConversationRecord], succeeding: [ConversationRecord]) {
        guard let referenceConversation = try await fetchOne(id: conversationId) else {
            // Consider logging this or throwing a specific error if a reference conversation is critical
            return ([], [])
        }

        let calendar = Foundation.Calendar.current
        let windowInterval: TimeInterval = TimeInterval(windowMinutes * 60)

        let referenceStartTime = referenceConversation.conversationStartTime
        let referenceEndTime = referenceConversation.conversationEndTime ?? referenceStartTime

        let precedingCutoff = calendar.date(byAdding: .second, value: -Int(windowInterval), to: referenceStartTime)!
        let succeedingCutoff = calendar.date(byAdding: .second, value: Int(windowInterval), to: referenceEndTime)!
        
        let creatorId = referenceConversation.creatorId // Assuming creatorId is non-optional and relevant for filtering

        let preceding = try await dbWriter.read { db -> [ConversationRecord] in
            try ConversationRecord
                .filter(ConversationRecord.Columns.creatorId == creatorId)
                .filter(ConversationRecord.Columns.conversationStartTime >= precedingCutoff && ConversationRecord.Columns.conversationStartTime < referenceStartTime)
                .order(ConversationRecord.Columns.conversationStartTime.asc)
                .fetchAll(db)
        }

        let succeeding = try await dbWriter.read { db -> [ConversationRecord] in
            try ConversationRecord
                .filter(ConversationRecord.Columns.creatorId == creatorId)
                .filter(ConversationRecord.Columns.conversationStartTime > referenceEndTime && ConversationRecord.Columns.conversationStartTime <= succeedingCutoff)
                .order(ConversationRecord.Columns.conversationStartTime.asc)
                .fetchAll(db)
        }

        return (preceding, succeeding)
    }

    /// Deletes all conversation records from the database.
    /// Use with caution.
    func deleteAll() async throws {
        _ = try await dbWriter.write { db in
            try ConversationRecord.deleteAll(db)
        }
    }
} 