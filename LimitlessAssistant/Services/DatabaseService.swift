import GRDB
import Foundation
import os.log

class DatabaseService {
    static let shared = DatabaseService()
    var dbQueue: DatabaseQueue!

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "DatabaseService")

    private init() {
        do {
            let fileManager = FileManager.default
            // Get the Application Support directory URL
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
            // Create our app-specific subdirectory if it doesn't exist
            let dbDirectoryURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "LimitlessAssistant", isDirectory: true)
            try fileManager.createDirectory(at: dbDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            
            // Define the database file path
            let dbURL = dbDirectoryURL.appendingPathComponent("database.sqlite")
            DatabaseService.logger.info("Database path: \(dbURL.path)")

            // Connect to the database
            dbQueue = try DatabaseQueue(path: dbURL.path)
            
            // Setup the database schema (migrations)
            try setupDatabaseSchema(dbQueue)
            DatabaseService.logger.info("Database schema setup and migrations completed successfully.")
            
        } catch {
            DatabaseService.logger.fault("Failed to initialize or migrate database: \(error.localizedDescription, privacy: .public)")
            // Depending on the app's needs, you might want to propagate this error
            // or handle it in a way that allows the app to run in a degraded state.
            fatalError("Failed to initialize database: \(error)") // Or a more graceful fallback
        }
    }

    private func setupDatabaseSchema(_ db: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up development by erasing the database on every launch if needed.
        // migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            DatabaseService.logger.info("Running migration v1...")
            // MARK: - ConversationRecord Table
            try db.create(table: ConversationRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(ConversationRecord.Columns.id.rawValue)
                t.column(ConversationRecord.Columns.limitlessLogId.rawValue, .text).notNull().unique()
                t.column(ConversationRecord.Columns.title.rawValue, .text)
                t.column(ConversationRecord.Columns.conversationStartTime.rawValue, .datetime).notNull()
                t.column(ConversationRecord.Columns.conversationEndTime.rawValue, .datetime)
                t.column(ConversationRecord.Columns.creatorId.rawValue, .text).notNull()
                t.column(ConversationRecord.Columns.fullMarkdownContent.rawValue, .text)
                t.column(ConversationRecord.Columns.logicalEventId.rawValue, .text).indexed()
                t.column(ConversationRecord.Columns.processedStatusActions.rawValue, .integer).notNull().defaults(to: 0)
                t.column(ConversationRecord.Columns.createdAt.rawValue, .datetime).notNull()
            }
            DatabaseService.logger.debug("Created table '\(ConversationRecord.databaseTableName, privacy: .public)'")

            // MARK: - SpeakerRecord Table
            try db.create(table: SpeakerRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(SpeakerRecord.Columns.id.rawValue)
                t.column(SpeakerRecord.Columns.name.rawValue, .text).notNull()
                t.column(SpeakerRecord.Columns.limitlessSpeakerNameRaw.rawValue, .text)
                t.column(SpeakerRecord.Columns.isUserCreator.rawValue, .boolean).notNull()
            }
            DatabaseService.logger.debug("Created table '\(SpeakerRecord.databaseTableName, privacy: .public)'")

            // MARK: - UtteranceRecord Table
            try db.create(table: UtteranceRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(UtteranceRecord.Columns.id.rawValue)
                t.column(UtteranceRecord.Columns.conversationId.rawValue, .integer).notNull().indexed()
                    .references(ConversationRecord.databaseTableName, onDelete: .cascade) // Foreign key
                t.column(UtteranceRecord.Columns.speakerId.rawValue, .integer).indexed()
                    .references(SpeakerRecord.databaseTableName, onDelete: .setNull) // Foreign key (optional speaker)
                t.column(UtteranceRecord.Columns.textContent.rawValue, .text).notNull()
                t.column(UtteranceRecord.Columns.utteranceStartTime.rawValue, .datetime).notNull()
                t.column(UtteranceRecord.Columns.utteranceEndTime.rawValue, .datetime)
                t.column(UtteranceRecord.Columns.startOffsetMs.rawValue, .integer)
                t.column(UtteranceRecord.Columns.endOffsetMs.rawValue, .integer)
                t.column(UtteranceRecord.Columns.sequenceInConversation.rawValue, .integer).notNull()
                t.column(UtteranceRecord.Columns.contentType.rawValue, .text)
            }
            DatabaseService.logger.debug("Created table '\(UtteranceRecord.databaseTableName, privacy: .public)'")

            // MARK: - FTS5 Virtual Table for Utterances
            // Create an FTS5 virtual table for full-text search on utterances
            try db.create(virtualTable: "fts5Utterances", using: FTS5()) { t in
                // Add columns from UtteranceRecord that you want to be searchable or available in search results
                // It's common to just index the textContent and store the rowID of the original table
                t.synchronize(withTable: UtteranceRecord.databaseTableName) // Keeps FTS table in sync
                t.column(UtteranceRecord.Columns.textContent.rawValue)
                // You might add other columns if you want them returned directly by FTS queries without a join,
                // but typically you join back to the main table using rowid.
            }
            DatabaseService.logger.debug("Created virtual FTS5 table 'fts5Utterances' for '\(UtteranceRecord.databaseTableName, privacy: .public)'")
            
            // MARK: - LlmActionSuggestionRecord Table
            try db.create(table: LlmActionSuggestionRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(LlmActionSuggestionRecord.Columns.id.rawValue)
                t.column(LlmActionSuggestionRecord.Columns.conversationId.rawValue, .integer).notNull().indexed()
                    .references(ConversationRecord.databaseTableName, onDelete: .cascade)
                t.column(LlmActionSuggestionRecord.Columns.triggeringUtteranceIdStart.rawValue, .integer)
                    .references(UtteranceRecord.databaseTableName, onDelete: .setNull)
                t.column(LlmActionSuggestionRecord.Columns.triggeringUtteranceIdEnd.rawValue, .integer)
                    .references(UtteranceRecord.databaseTableName, onDelete: .setNull)
                t.column(LlmActionSuggestionRecord.Columns.triggeringSnippetText.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.llmName.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.llmPromptVersion.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.llmRawResponse.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.suggestedItemType.rawValue, .text).notNull()
                t.column(LlmActionSuggestionRecord.Columns.extractedTitle.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.extractedStartDate.rawValue, .datetime)
                t.column(LlmActionSuggestionRecord.Columns.extractedEndDate.rawValue, .datetime)
                t.column(LlmActionSuggestionRecord.Columns.extractedLocation.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.extractedDetails.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.extractedAttendees.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.confidenceScore.rawValue, .double)
                t.column(LlmActionSuggestionRecord.Columns.status.rawValue, .text).notNull()
                t.column(LlmActionSuggestionRecord.Columns.googleItemId.rawValue, .text)
                t.column(LlmActionSuggestionRecord.Columns.createdAt.rawValue, .datetime).notNull()
                t.column(LlmActionSuggestionRecord.Columns.updatedAt.rawValue, .datetime).notNull()
            }
            DatabaseService.logger.debug("Created table '\(LlmActionSuggestionRecord.databaseTableName, privacy: .public)'")

            // MARK: - UserActionRecord Table
            try db.create(table: UserActionRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(UserActionRecord.Columns.id.rawValue)
                t.column(UserActionRecord.Columns.suggestionId.rawValue, .integer).notNull().indexed()
                    .references(LlmActionSuggestionRecord.databaseTableName, onDelete: .cascade)
                t.column(UserActionRecord.Columns.actionType.rawValue, .text).notNull()
                t.column(UserActionRecord.Columns.correctedItemType.rawValue, .text)
                t.column(UserActionRecord.Columns.correctedTitle.rawValue, .text)
                t.column(UserActionRecord.Columns.declineReason.rawValue, .text)
                t.column(UserActionRecord.Columns.actionTimestamp.rawValue, .datetime).notNull()
            }
            DatabaseService.logger.debug("Created table '\(UserActionRecord.databaseTableName, privacy: .public)'")

            // MARK: - ApplicationSettingRecord Table
            try db.create(table: ApplicationSettingRecord.databaseTableName) { t in
                // Assuming settingKey is the primary key and is unique text
                t.column("settingKey", .text).primaryKey(onConflict: .replace) // Using the raw string from model as it's the PK
                t.column("settingValue", .text).notNull()
            }
            DatabaseService.logger.debug("Created table '\(ApplicationSettingRecord.databaseTableName, privacy: .public)'")
            DatabaseService.logger.info("Migration v1 completed.")
        }
        
        // Add more migrations here if needed in the future
        // migrator.registerMigration("v2") { db in ... }

        try migrator.migrate(db)
    }
} 