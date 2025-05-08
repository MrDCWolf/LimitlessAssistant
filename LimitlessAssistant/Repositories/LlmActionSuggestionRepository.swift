import GRDB
import Foundation

struct LlmActionSuggestionRepository {
    private var dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: - CRUD & Save Operations

    /// Creates a new LLM action suggestion record.
    /// Automatically sets `createdAt` and `updatedAt` timestamps.
    func create(_ suggestion: LlmActionSuggestionRecord) async throws -> LlmActionSuggestionRecord {
        return try await dbWriter.write { db -> LlmActionSuggestionRecord in
            var suggestionToInsert = suggestion
            let now = Date()
            suggestionToInsert.createdAt = now
            suggestionToInsert.updatedAt = now
            try suggestionToInsert.insert(db)
            return suggestionToInsert
        }
    }

    /// Saves an LLM action suggestion record (inserts or updates).
    /// Updates `updatedAt` timestamp on save. If it's a new record (id is nil), `createdAt` is also set.
    /// Returns the saved record, which will have its ID and timestamps populated.
    func save(_ suggestion: LlmActionSuggestionRecord) async throws -> LlmActionSuggestionRecord {
        return try await dbWriter.write { db -> LlmActionSuggestionRecord in
            var suggestionToSave = suggestion
            let now = Date()
            suggestionToSave.updatedAt = now
            if suggestionToSave.id == nil {
                suggestionToSave.createdAt = now
            }
            try suggestionToSave.save(db)
            return suggestionToSave
        }
    }

    /// Fetches an LLM action suggestion record by its ID.
    func fetchOne(id: Int64) async throws -> LlmActionSuggestionRecord? {
        try await dbWriter.read { db in
            try LlmActionSuggestionRecord.fetchOne(db, key: id)
        }
    }

    /// Fetches all LLM action suggestion records, ordered by creation date (newest first).
    /// An optional limit can be provided.
    func fetchAll(limit: Int? = nil) async throws -> [LlmActionSuggestionRecord] {
        try await dbWriter.read { db in
            var request = LlmActionSuggestionRecord.order(LlmActionSuggestionRecord.Columns.createdAt.desc)
            if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }

    /// Fetches all LLM action suggestion records for a specific conversation ID, ordered by creation date (newest first).
    /// An optional limit can be provided.
    func fetchAll(conversationId: Int64, limit: Int? = nil) async throws -> [LlmActionSuggestionRecord] {
        try await dbWriter.read { db in
            var request = LlmActionSuggestionRecord
                .filter(LlmActionSuggestionRecord.Columns.conversationId == conversationId)
                .order(LlmActionSuggestionRecord.Columns.createdAt.desc)
            if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }

    /// Fetches all LLM action suggestion records with a specific status, ordered by creation date (newest first).
    /// An optional limit can be provided.
    func fetchAll(status: String, limit: Int? = nil) async throws -> [LlmActionSuggestionRecord] {
        try await dbWriter.read { db in
            var request = LlmActionSuggestionRecord
                .filter(LlmActionSuggestionRecord.Columns.status == status)
                .order(LlmActionSuggestionRecord.Columns.createdAt.desc)
            if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }
    
    /// Fetches LLM action suggestions for a specific conversation ID and status, ordered by creation date (newest first).
    /// An optional limit can be provided.
    func fetchAll(conversationId: Int64, status: String, limit: Int? = nil) async throws -> [LlmActionSuggestionRecord] {
        try await dbWriter.read { db in
            var request = LlmActionSuggestionRecord
                .filter(LlmActionSuggestionRecord.Columns.conversationId == conversationId)
                .filter(LlmActionSuggestionRecord.Columns.status == status)
                .order(LlmActionSuggestionRecord.Columns.createdAt.desc)
             if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }

    /// Updates an existing LLM action suggestion record. Also updates the `updatedAt` timestamp.
    /// Prefer `save(_:)` for a more general upsert behavior.
    func update(_ suggestion: LlmActionSuggestionRecord) async throws {
        return try await dbWriter.write { db in
            var mutableSuggestion = suggestion
            mutableSuggestion.updatedAt = Date()
            try mutableSuggestion.update(db)
        }
    }

    /// Deletes an LLM action suggestion record by its ID.
    @discardableResult
    func delete(id: Int64) async throws -> Bool {
        try await dbWriter.write { db in
            try LlmActionSuggestionRecord.deleteOne(db, key: id)
        }
    }
    
    // MARK: - Bulk Deletion

    /// Deletes all LLM action suggestion records for a specific conversation ID.
    /// Returns the number of deleted records.
    @discardableResult
    func deleteAll(conversationId: Int64) async throws -> Int {
        try await dbWriter.write { db in
            try LlmActionSuggestionRecord
                .filter(LlmActionSuggestionRecord.Columns.conversationId == conversationId)
                .deleteAll(db)
        }
    }

    /// Deletes all LLM action suggestion records from the database.
    /// Use with caution.
    func deleteAll() async throws {
        _ = try await dbWriter.write { db in
            try LlmActionSuggestionRecord.deleteAll(db)
        }
    }
} 