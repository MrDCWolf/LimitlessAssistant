import GRDB

struct SpeakerRepository {
    private var dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: - CRUD Operations

    /// Creates a new speaker record in the database or updates if it already exists based on `limitlessSpeakerId`.
    /// This is an "upsert" operation. The `speakerName` and `isUserCreator` fields will be updated if an existing record is found.
    func createOrUpdate(_ speaker: SpeakerRecord) async throws -> SpeakerRecord {
        return try await dbWriter.write { db -> SpeakerRecord in
            var speakerToUpsert = speaker
            if let existingSpeaker = try SpeakerRecord
                .filter(SpeakerRecord.Columns.limitlessSpeakerId == speakerToUpsert.limitlessSpeakerId)
                .fetchOne(db) {
                speakerToUpsert.id = existingSpeaker.id // Ensure we have the ID for update
                try speakerToUpsert.update(db)
            } else {
                try speakerToUpsert.insert(db)
            }
            return speakerToUpsert // Return the (potentially updated with ID) speaker
        }
    }
    
    /// Saves a speaker record (inserts or updates).
    /// GRDB's `save()` method handles this by checking for an ID.
    /// Returns the saved speaker record (which will have an ID).
    func save(_ speaker: SpeakerRecord) async throws -> SpeakerRecord {
        return try await dbWriter.write { db -> SpeakerRecord in
            var speakerToSave = speaker
            try speakerToSave.save(db) // save will insert if id is nil, otherwise update
            return speakerToSave
        }
    }

    /// Fetches a speaker record by its internal database ID.
    func fetchOne(id: Int64) async throws -> SpeakerRecord? {
        try await dbWriter.read { db in
            try SpeakerRecord.fetchOne(db, key: id)
        }
    }

    /// Fetches a speaker record by its `limitlessSpeakerId`.
    func fetchOne(limitlessSpeakerId: String) async throws -> SpeakerRecord? {
        try await dbWriter.read { db in
            try SpeakerRecord.filter(SpeakerRecord.Columns.limitlessSpeakerId == limitlessSpeakerId).fetchOne(db)
        }
    }

    /// Fetches all speaker records.
    func fetchAll() async throws -> [SpeakerRecord] {
        try await dbWriter.read { db in
            try SpeakerRecord.fetchAll(db)
        }
    }

    /// Updates an existing speaker record.
    /// Note: `save(_:)` or `createOrUpdate(_:)` are generally preferred.
    func update(_ speaker: SpeakerRecord) async throws {
        try await dbWriter.write { db in
            try speaker.update(db)
        }
    }

    /// Deletes a speaker record by its ID.
    /// Be cautious with deletions if speakers are referenced by utterances.
    /// The foreign key constraint on UtteranceRecord (ON DELETE RESTRICT) will prevent deletion if referenced.
    @discardableResult
    func delete(id: Int64) async throws -> Bool {
        try await dbWriter.write { db in
            try SpeakerRecord.deleteOne(db, key: id)
        }
    }
    
    /// Fetches the speaker record identified as the user creator.
    func fetchUserCreatorSpeaker() async throws -> SpeakerRecord? {
        try await dbWriter.read { db in
            try SpeakerRecord.filter(SpeakerRecord.Columns.isUserCreator == true).fetchOne(db)
        }
    }

    /// Deletes all speaker records from the database.
    /// Use with extreme caution due to foreign key constraints.
    func deleteAll() async throws {
        _ = try await dbWriter.write { db in
            // This will fail if any speakers are referenced by utterances due to ON DELETE RESTRICT.
            // You might need to delete utterances first or change the foreign key behavior if mass deletion is required.
            try SpeakerRecord.deleteAll(db)
        }
    }
} 