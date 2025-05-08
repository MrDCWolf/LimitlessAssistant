import GRDB
import Foundation

struct UserActionRepository {
    private var dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: - Create & Save Operations

    /// Creates a new user action record.
    /// Automatically sets the `actionTimestamp`.
    /// Returns the created record with its ID.
    func create(_ action: UserActionRecord) async throws -> UserActionRecord {
        return try await dbWriter.write { db -> UserActionRecord in
            var actionToInsert = action
            actionToInsert.actionTimestamp = Date()
            try actionToInsert.insert(db)
            return actionToInsert
        }
    }

    /// Saves a user action record (primarily for inserting, as updates are less common for this model).
    /// Ensures `actionTimestamp` is set if it's a new record.
    /// Returns the saved record.
    func save(_ action: UserActionRecord) async throws -> UserActionRecord {
        return try await dbWriter.write { db -> UserActionRecord in
            var actionToSave = action
            if actionToSave.id == nil { // If it's a new record being inserted
                actionToSave.actionTimestamp = Date()
            }
            try actionToSave.save(db)
            return actionToSave
        }
    }

    // MARK: - Read Operations

    /// Fetches a user action record by its ID.
    func fetchOne(id: Int64) async throws -> UserActionRecord? {
        try await dbWriter.read { db in
            try UserActionRecord.fetchOne(db, key: id)
        }
    }

    /// Fetches all user action records, ordered by action timestamp (most recent first).
    /// An optional limit can be provided.
    func fetchAll(limit: Int? = nil) async throws -> [UserActionRecord] {
        try await dbWriter.read { db in
            var request = UserActionRecord.order(UserActionRecord.Columns.actionTimestamp.desc)
            if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }

    /// Fetches all user action records for a specific LLM action suggestion ID, ordered by action timestamp (most recent first).
    /// An optional limit can be provided.
    func fetchAll(suggestionId: Int64, limit: Int? = nil) async throws -> [UserActionRecord] {
        try await dbWriter.read { db in
            var request = UserActionRecord
                .filter(UserActionRecord.Columns.suggestionId == suggestionId)
                .order(UserActionRecord.Columns.actionTimestamp.desc)
            if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }

    // MARK: - Delete Operations

    /// Deletes a user action record by its ID.
    @discardableResult
    func delete(id: Int64) async throws -> Bool {
        try await dbWriter.write { db in
            try UserActionRecord.deleteOne(db, key: id)
        }
    }
    
    /// Deletes all user action records for a specific LLM action suggestion ID.
    /// Returns the number of deleted records.
    @discardableResult
    func deleteAll(suggestionId: Int64) async throws -> Int {
        try await dbWriter.write { db in
            try UserActionRecord
                .filter(UserActionRecord.Columns.suggestionId == suggestionId)
                .deleteAll(db)
        }
    }

    /// Deletes all user action records from the database.
    /// Use with caution.
    func deleteAll() async throws {
        _ = try await dbWriter.write { db in
            try UserActionRecord.deleteAll(db)
        }
    }
} 