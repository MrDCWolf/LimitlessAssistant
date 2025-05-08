import Foundation
import OSLog
import GRDB // Ensure GRDB is imported if DatabaseService.shared.dbQueue is used directly

// MARK: - SyncController

/// Orchestrates fetching lifelogs from the Limitless API, processing, and storing them in the database with logical event linking.
final class SyncController: ObservableObject {
    // MARK: - Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LimitlessAssistant", category: "SyncController")
    private let apiService: LimitlessAPIServiceProtocol
    private let conversationRepo: ConversationRepository
    private let speakerRepo: SpeakerRepository
    private let utteranceRepo: UtteranceRepository
    private let logicalEventGapThreshold: TimeInterval = 5 * 60 // 5 minutes
    
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastSyncError: Error?
    
    // MARK: - Init
    init(
        apiService: LimitlessAPIServiceProtocol = LimitlessAPIService(),
        // Pass the dbQueue to the repositories
        dbWriter: any DatabaseWriter = DatabaseService.shared.dbQueue! // Added type annotation and force unwrap assuming dbQueue is always initialized
    ) {
        self.apiService = apiService
        self.conversationRepo = ConversationRepository(dbWriter: dbWriter)
        self.speakerRepo = SpeakerRepository(dbWriter: dbWriter)
        self.utteranceRepo = UtteranceRepository(dbWriter: dbWriter)
    }
    
    // MARK: - Public Sync API
    @MainActor
    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        logger.info("Starting lifelog sync...")
        do {
            let lifelogs = try await apiService.fetchLifelogs()
            logger.info("Fetched \(lifelogs.count) lifelogs from API.")
            try await processAndStoreLifelogs(lifelogs)
            lastSyncDate = Date()
            logger.info("Sync completed successfully.")
        } catch {
            lastSyncError = error
            logger.error("Sync failed: \(error.localizedDescription)")
        }
        isSyncing = false
    }
    
    // MARK: - Core Processing Logic
    /// Processes and stores lifelogs, handling logical event linking.
    private func processAndStoreLifelogs(_ apiLifelogs: [APILifelogData]) async throws {
        let sortedLifelogs = apiLifelogs.sorted { ($0.startTime) < ($1.startTime) }
        var lastEndTime: Date? = nil
        var currentLogicalEventId: String? = nil
        let userCreatorId = await loadUserCreatorId() // Assuming this remains a simple string ID for now
        
        for lifelog in sortedLifelogs {
            guard let convStartTime = ISO8601DateFormatter.date(from: lifelog.startTime) else {
                logger.warning("Skipping lifelog with invalid startTime: \(lifelog.id)")
                continue
            }
            let convEndTime = ISO8601DateFormatter.date(from: lifelog.endTime)
            
            if let last = lastEndTime, convStartTime.timeIntervalSince(last) <= logicalEventGapThreshold {
                if currentLogicalEventId == nil { currentLogicalEventId = UUID().uuidString }
            } else {
                currentLogicalEventId = UUID().uuidString
            }
            
            var conversationRecord: ConversationRecord
            if var existingConv = try await conversationRepo.fetchByLimitlessLogId(lifelog.id) {
                existingConv.title = lifelog.title
                existingConv.conversationStartTime = convStartTime
                existingConv.conversationEndTime = convEndTime
                existingConv.creatorId = userCreatorId // Ensure creatorId is correct
                existingConv.fullMarkdownContent = lifelog.markdown
                existingConv.logicalEventId = currentLogicalEventId
                // existingConv.processedStatusActions remains unchanged unless specifically updated
                // existingConv.createdAt remains unchanged
                try await conversationRepo.update(existingConv) // update doesn't return, modifies in place
                conversationRecord = existingConv
            } else {
                let newConversation = ConversationRecord(
                    limitlessLogId: lifelog.id,
                    title: lifelog.title,
                    conversationStartTime: convStartTime,
                    conversationEndTime: convEndTime,
                    creatorId: userCreatorId,
                    fullMarkdownContent: lifelog.markdown,
                    logicalEventId: currentLogicalEventId,
                    processedStatusActions: 0, // Use 0 for pending
                    createdAt: Date()
                )
                conversationRecord = try await conversationRepo.create(newConversation)
            }
            
            guard let convId = conversationRecord.id else {
                logger.error("Failed to get conversation ID after save/create for limitlessLogId: \(lifelog.id)")
                continue
            }
            
            try await processSpeakersAndUtterances(for: lifelog, conversationId: convId)
            lastEndTime = convEndTime ?? convStartTime
        }
    }
    
    /// Processes speakers and utterances for a lifelog and stores them in the DB.
    private func processSpeakersAndUtterances(for lifelog: APILifelogData, conversationId: Int64) async throws {
        var speakerNameToId: [String: Int64] = [:]
        
        for content in lifelog.contents {
            guard let rawSpeakerName = content.speakerName, !rawSpeakerName.isEmpty else { continue }
            if speakerNameToId[rawSpeakerName] != nil { continue } // Already processed this speaker name in this lifelog

            // Assuming rawSpeakerName from API can be used as limitlessSpeakerId for upserting
            // And isUserCreator needs to be determined, defaulting to false for non-primary user for now.
            let speakerToUpsert = SpeakerRecord(limitlessSpeakerId: rawSpeakerName, name: rawSpeakerName, isUserCreator: false) 
            let savedSpeaker = try await speakerRepo.createOrUpdate(speakerToUpsert)
            
            if let speakerId = savedSpeaker.id {
                speakerNameToId[rawSpeakerName] = speakerId
            } else {
                logger.warning("Failed to get ID for speaker: \(rawSpeakerName)")
            }
        }
        
        var utterancesToSave: [UtteranceRecord] = []
        var sequence = 0
        for content in lifelog.contents {
            guard let text = content.primaryText, !text.isEmpty else { continue }
            
            let speakerId = content.speakerName.flatMap { speakerNameToId[$0] }
            let utteranceStart = ISO8601DateFormatter.date(from: content.startTime) ?? Date() // Fallback to now if parse fails
            let utteranceEnd = ISO8601DateFormatter.date(from: content.endTime)
            
            let utterance = UtteranceRecord(
                conversationId: conversationId,
                speakerId: speakerId,
                textContent: text,
                utteranceStartTime: utteranceStart,
                utteranceEndTime: utteranceEnd,
                startOffsetMs: content.startOffsetMs,
                endOffsetMs: content.endOffsetMs,
                sequenceInConversation: sequence,
                contentType: content.type
            )
            utterancesToSave.append(utterance)
            sequence += 1
        }
        
        if !utterancesToSave.isEmpty {
            _ = try await utteranceRepo.saveAll(utterancesToSave) // saveAll returns the saved records, assign if needed later
        }
    }
    
    // MARK: - Helper: Load User Creator ID
    private func loadUserCreatorId() async -> String {
        // TODO: Fetch this from ApplicationSettingRepository or a dedicated UserProfileService
        // For now, placeholder or retrieve from LimitlessAuthService if it stores it persistently after first fetch.
        if let id = LimitlessAuthService().loadUserCreatorIdFromKeychain() { // Assuming method name change for clarity
             logger.info("Loaded user creator ID from keychain: \(id)")
            return id
        }
        logger.warning("User creatorId not found in keychain. Using default 'unknown_user'. Configure in settings.")
        return "unknown_user" // Fallback
    }
}

// Extension for LimitlessAuthService to provide the creator ID (placeholder)
// This should ideally be part of LimitlessAuthService.swift
// And the ID should be fetched once and stored, perhaps in ApplicationSettings or KeychainService directly by AuthService.
fileprivate extension LimitlessAuthService {
    func loadUserCreatorIdFromKeychain() -> String? {
        // Placeholder: Actual implementation would fetch from KeychainService
        // where it was stored after initial Limitless API authentication/user info fetch.
        // For example:
        // return KeychainService.loadData(service: "com.limitlessassistant.limitless", account: "userCreatorId")?.toString()
        return nil // Simulate not found for now, prompting fallback in SyncController
    }
} 