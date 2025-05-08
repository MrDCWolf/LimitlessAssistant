import GRDB

struct UtteranceRepository {
    private var dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: - CRUD & Save Operations

    /// Creates a new utterance record in the database.
    /// Returns the created utterance record with its ID.
    func create(_ utterance: UtteranceRecord) async throws -> UtteranceRecord {
        return try await dbWriter.write { db -> UtteranceRecord in
            let utteranceToInsert = utterance
            try utteranceToInsert.insert(db)
            return utteranceToInsert
        }
    }
    
    /// Saves an utterance record (inserts or updates if ID exists).
    /// Returns the saved utterance record (which will have an ID).
    func save(_ utterance: UtteranceRecord) async throws -> UtteranceRecord {
        return try await dbWriter.write { db -> UtteranceRecord in
            let utteranceToSave = utterance
            try utteranceToSave.save(db)
            return utteranceToSave
        }
    }
    
    /// Saves multiple utterance records in a single transaction.
    /// This is more efficient than calling save for each utterance individually.
    /// Returns the array of saved utterances, now with their database IDs.
    func saveAll(_ utterances: [UtteranceRecord]) async throws -> [UtteranceRecord] {
        return try await dbWriter.write { db -> [UtteranceRecord] in
            let utterancesToSave = utterances
            var savedUtterances: [UtteranceRecord] = []
            savedUtterances.reserveCapacity(utterancesToSave.count)
            for i in 0..<utterancesToSave.count {
                try utterancesToSave[i].save(db)
                savedUtterances.append(utterancesToSave[i])
            }
            return savedUtterances
        }
    }

    /// Fetches an utterance record by its ID.
    func fetchOne(id: Int64) async throws -> UtteranceRecord? {
        try await dbWriter.read { db in
            try UtteranceRecord.fetchOne(db, key: id)
        }
    }

    /// Fetches all utterance records (potentially very large, use with caution).
    func fetchAll() async throws -> [UtteranceRecord] {
        try await dbWriter.read { db in
            try UtteranceRecord.fetchAll(db)
        }
    }
    
    /// Fetches all utterance records for a specific conversation ID, ordered by their start time.
    func fetchAll(conversationId: Int64) async throws -> [UtteranceRecord] {
        try await dbWriter.read { db in
            try UtteranceRecord
                .filter(UtteranceRecord.Columns.conversationId == conversationId)
                .order(UtteranceRecord.Columns.utteranceStartTime.asc)
                .fetchAll(db)
        }
    }

    /// Updates an existing utterance record.
    /// Note: `save(_:)` is generally preferred.
    func update(_ utterance: UtteranceRecord) async throws {
        try await dbWriter.write { db in
            try utterance.update(db)
        }
    }

    /// Deletes an utterance record by its ID.
    @discardableResult
    func delete(id: Int64) async throws -> Bool {
        try await dbWriter.write { db in
            try UtteranceRecord.deleteOne(db, key: id)
        }
    }

    // MARK: - Full-Text Search

    /// Performs a full-text search on the `textContent` of utterances.
    /// - Parameters:
    ///   - query: The search term or FTS5 query string.
    ///   - limit: The maximum number of results to return.
    /// - Returns: An array of matching `UtteranceRecord`s, ordered by relevance (rank).
    func search(query: String, limit: Int = 25) async throws -> [UtteranceRecord] {
        try await dbWriter.read { db in
            // Ensure the FTS5 table name matches the one in DatabaseService.swift migration (e.g., "utterance_fts5")
            // This SQL assumes UtteranceRecord.databaseTableName is "utterance"
            let sql = """
                SELECT u.* FROM \(UtteranceRecord.databaseTableName) u
                JOIN utterance_fts5 fts ON fts.rowid = u.id
                WHERE fts.textContent MATCH ?
                ORDER BY fts.rank DESC -- Higher rank is more relevant
                LIMIT ?
            """
            return try UtteranceRecord.fetchAll(db, sql: sql, arguments: [query, limit])
        }
    }
    
    // MARK: - Bulk Deletion

    /// Deletes all utterance records for a specific conversation ID.
    /// Returns the number of deleted records.
    @discardableResult
    func deleteAll(conversationId: Int64) async throws -> Int {
        try await dbWriter.write { db in
            try UtteranceRecord
                .filter(UtteranceRecord.Columns.conversationId == conversationId)
                .deleteAll(db)
        }
    }

    /// Deletes all utterance records from the database.
    /// Use with extreme caution.
    func deleteAll() async throws {
        _ = try await dbWriter.write { db in
            try UtteranceRecord.deleteAll(db)
        }
    }
} 