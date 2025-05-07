import GRDB
import Foundation
import os.log

class SpeakerRepository {
    private let dbQueue: DatabaseQueue
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "SpeakerRepository")

    init(dbQueue: DatabaseQueue = DatabaseService.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Create / Update
    func save(_ speaker: inout SpeakerRecord) throws {
        let mutableSpeaker = speaker // Create a let constant since it's not mutated
        try dbQueue.write {
            try mutableSpeaker.save($0) // Save the constant
            SpeakerRepository.logger.debug("Saved speaker with ID: \(mutableSpeaker.id ?? -1)")
        }
        speaker = mutableSpeaker // Assign back (still valid for inout)
    }
    
    // Check if a speaker with a raw name already exists
    func findByRawName(_ rawName: String) throws -> SpeakerRecord? {
        try dbQueue.read {
            try SpeakerRecord.filter(SpeakerRecord.Columns.limitlessSpeakerNameRaw == rawName).fetchOne($0)
        }
    }

    // MARK: - Read
    func fetchAll() throws -> [SpeakerRecord] {
        try dbQueue.read {
            try SpeakerRecord.fetchAll($0)
        }
    }

    func fetchById(_ id: Int64) throws -> SpeakerRecord? {
        try dbQueue.read {
            try SpeakerRecord.fetchOne($0, key: id)
        }
    }
    
    func fetchUserCreatorSpeaker() throws -> SpeakerRecord? {
        try dbQueue.read {
            try SpeakerRecord.filter(SpeakerRecord.Columns.isUserCreator == true).fetchOne($0)
        }
    }

    // MARK: - Delete
    func deleteById(_ id: Int64) throws -> Bool {
        try dbQueue.write {
            try SpeakerRecord.deleteOne($0, key: id)
        }
    }

    func deleteAll() throws {
        try dbQueue.write {
            _ = try SpeakerRecord.deleteAll($0)
        }
    }
} 