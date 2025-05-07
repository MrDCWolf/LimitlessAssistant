import GRDB
import Foundation
import os.log

class UtteranceRepository {
    private let dbQueue: DatabaseQueue
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "UtteranceRepository")

    init(dbQueue: DatabaseQueue = DatabaseService.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Create / Update
    func save(_ utterance: inout UtteranceRecord) throws {
        let mutableUtterance = utterance
        try dbQueue.write {
            try mutableUtterance.save($0)
            UtteranceRepository.logger.debug("Saved utterance with ID: \(mutableUtterance.id ?? -1)")
        }
        utterance = mutableUtterance
    }
    
    func saveAll(_ utterances: inout [UtteranceRecord]) throws {
        let mutableUtterances = utterances
        try dbQueue.write { db in
            for i in 0..<mutableUtterances.count {
                try mutableUtterances[i].save(db)
            }
            UtteranceRepository.logger.debug("Saved \(mutableUtterances.count) utterances.")
        }
        utterances = mutableUtterances
    }

    // MARK: - Read
    func fetchAll(forConversationId conversationId: Int64) throws -> [UtteranceRecord] {
        try dbQueue.read {
            try UtteranceRecord
                .filter(UtteranceRecord.Columns.conversationId == conversationId)
                .order(UtteranceRecord.Columns.sequenceInConversation.asc)
                .fetchAll($0)
        }
    }
    
    func fetchById(_ id: Int64) throws -> UtteranceRecord? {
        try dbQueue.read {
            try UtteranceRecord.fetchOne($0, key: id)
        }
    }

    // MARK: - FTS5 Search
    /**
     Performs a full-text search on utterance content.
     - Parameter query: The search query string. Supports FTS5 query syntax.
     - Returns: An array of `UtteranceRecord` that match the query.
     - Throws: Database errors.
    */
    func search(query: String) throws -> [UtteranceRecord] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // The FTS5 query. We match against the fts5Utterances table.
        // We select the rowid from fts5Utterances which corresponds to the id in UtteranceRecord.
        let ftsQuery = """
            SELECT utterances.* 
            FROM utterances
            JOIN fts5Utterances ON fts5Utterances.rowid = utterances.id
            WHERE fts5Utterances MATCH ?
            ORDER BY rank -- Optional: Order by relevance
        """
        
        return try dbQueue.read {
            // Fetch UtteranceRecord directly using the FTS query
            try UtteranceRecord.fetchAll($0, sql: ftsQuery, arguments: [query])
        }
    }
    
    // Fetch utterances within a specific time range for a given conversation
    func fetchUtterances(forConversationId conversationId: Int64, from: Date, to: Date) throws -> [UtteranceRecord] {
        try dbQueue.read { db in
            try UtteranceRecord
                .filter(UtteranceRecord.Columns.conversationId == conversationId)
                .filter(UtteranceRecord.Columns.utteranceStartTime >= from)
                .filter(UtteranceRecord.Columns.utteranceStartTime <= to)
                .order(UtteranceRecord.Columns.utteranceStartTime.asc)
                .fetchAll(db)
        }
    }

    // MARK: - Delete
    func deleteById(_ id: Int64) throws -> Bool {
        try dbQueue.write {
            try UtteranceRecord.deleteOne($0, key: id)
        }
    }

    func deleteAll(forConversationId conversationId: Int64) throws {
        try dbQueue.write {
            _ = try UtteranceRecord.filter(UtteranceRecord.Columns.conversationId == conversationId).deleteAll($0)
        }
    }
    
    func deleteAll() throws {
        try dbQueue.write {
            _ = try UtteranceRecord.deleteAll($0)
        }
    }
} 