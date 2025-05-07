import GRDB
import Foundation
import os.log

class UserActionRepository {
    private let dbQueue: DatabaseQueue
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "UserActionRepository")

    init(dbQueue: DatabaseQueue = DatabaseService.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Create
    func save(_ userAction: inout UserActionRecord) throws {
        let mutableUserAction = userAction
        try dbQueue.write {
            try mutableUserAction.save($0)
            UserActionRepository.logger.debug("Saved user action with ID: \(mutableUserAction.id ?? -1)")
        }
        userAction = mutableUserAction
    }

    // MARK: - Read
    func fetchAll() throws -> [UserActionRecord] {
        try dbQueue.read {
            try UserActionRecord.fetchAll($0)
        }
    }

    func fetchById(_ id: Int64) throws -> UserActionRecord? {
        try dbQueue.read {
            try UserActionRecord.fetchOne($0, key: id)
        }
    }
    
    func fetchBySuggestionId(_ suggestionId: Int64) throws -> [UserActionRecord] {
        try dbQueue.read {
            try UserActionRecord
                .filter(UserActionRecord.Columns.suggestionId == suggestionId)
                .order(UserActionRecord.Columns.actionTimestamp.desc)
                .fetchAll($0)
        }
    }

    // MARK: - Delete
    // Typically, user actions might not be deleted, but providing for completeness
    func deleteById(_ id: Int64) throws -> Bool {
        try dbQueue.write {
            try UserActionRecord.deleteOne($0, key: id)
        }
    }

    func deleteAll() throws {
        try dbQueue.write {
            _ = try UserActionRecord.deleteAll($0)
        }
    }
} 