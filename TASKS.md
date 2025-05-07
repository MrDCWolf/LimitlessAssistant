# TASKS.md: Limitless Assistant - Phased Development Plan

This document outlines the phased development plan for the Limitless Assistant macOS application, based on PRD v1.0. Each phase details its goal, instructions for an AI Coder (e.g., Cursor), specific implementation ideas, testing requirements, and acceptance criteria.

---

## Phase 0: Project Setup & Core Application Structure

* **Goal:** Establish the foundational Xcode project, version control, dependency management, and a basic application shell with SwiftUI.
* **AI Coder Instructions (Cursor):**
    * Create a new macOS application project in Xcode using Swift and SwiftUI.
    * Initialize a Git repository and create an initial commit.
    * Set up Swift Package Manager (SPM) and add initial dependencies: `OAuthSwift`, `GRDB.swift`.
    * Create basic folder structures for Models, Views, ViewModels, Services, Utilities.
    * Implement a minimal SwiftUI App and WindowGroup structure.
* **Implementation Details:**
    * **Project Name:** `LimitlessAssistant`
    * **Organization Identifier:** (User to provide, e.g., `com.yourcompany`)
    * **SwiftUI App Structure:**
        ```swift
        // LimitlessAssistantApp.swift
        import SwiftUI

        @main
        struct LimitlessAssistantApp: App {
            var body: some Scene {
                WindowGroup {
                    ContentView() // Placeholder main view
                }
                // Add settings scene later if needed (macOS 13+)
                // Settings {
                //     SettingsView()
                // }
            }
        }

        // ContentView.swift (placeholder)
        struct ContentView: View {
            var body: some View {
                Text("Limitless Assistant - Coming Soon!")
                    .frame(minWidth: 400, minHeight: 300)
            }
        }
        ```
    * Add `OAuthSwift` and `GRDB.swift` to `Package.swift` or via Xcode's SPM interface.
* **Tests / Test Suites:**
    * N/A for this phase (focus is on setup). Basic launch test.
* **Acceptance Criteria:**
    * Xcode project compiles and runs, displaying the placeholder `ContentView`.
    * Git repository is initialized.
    * SPM dependencies (`OAuthSwift`, `GRDB.swift`) are added and resolve correctly.
    * Basic project folder structure is in place.

---

## Phase 1: Authentication & Secure Credential Storage

* **Goal:** Implement OAuth 2.0 authentication for Limitless API and Google (Calendar & Tasks APIs). Securely store and retrieve API tokens using the macOS Keychain.
* **AI Coder Instructions (Cursor):**
    * Create `AuthService` classes/structs for Limitless and Google.
    * Implement OAuth 2.0 flows using `OAuthSwift` for both services.
        * Handle callback URLs (e.g., custom URL schemes).
    * Create a `KeychainService` to securely store and retrieve OAuth tokens (access token, refresh token, expiry date) and user-provided API keys/client secrets.
    * Develop basic UI elements in a `SettingsView` to trigger authentication for Limitless and Google, and display connection status.
* **Implementation Details:**
    * **Custom URL Scheme:** Define a unique URL scheme for the app (e.g., `limitlessassistant://oauth-callback`). Register this in `Info.plist`.
    * **KeychainService:**
        ```swift
        // KeychainService.swift
        import Foundation
        import Security

        struct KeychainService {
            // Generic function to save data
            static func saveData(data: Data, service: String, account: String) -> OSStatus {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecValueData as String: data
                ]
                SecItemDelete(query as CFDictionary) // Delete existing item first
                return SecItemAdd(query as CFDictionary, nil)
            }

            // Generic function to load data
            static func loadData(service: String, account: String) -> Data? {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecReturnData as String: kCFBooleanTrue!,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var dataTypeRef: AnyObject?
                let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
                if status == errSecSuccess {
                    return dataTypeRef as? Data
                }
                return nil
            }

            // Generic function to delete data
            static func deleteData(service: String, account: String) -> OSStatus {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account
                ]
                return SecItemDelete(query as CFDictionary)
            }
        }
        // Helper extension Data -> String
        extension Data { func toString() -> String? { return String(data: self, encoding: .utf8) } }
        ```
    * **AuthService (Example for one service):**
        ```swift
        // GoogleAuthService.swift (Conceptual)
        import OAuthSwift

        class GoogleAuthService: ObservableObject {
            @Published var isAuthenticated: Bool = false
            private var oauthswift: OAuthSwift?
            private let keychainServicePrefix = "com.limitlessassistant.google"

            private var clientID: String {
                KeychainService.loadData(service: keychainServicePrefix, account: "clientID")?.toString() ?? ""
            }
            private var clientSecret: String {
                 KeychainService.loadData(service: keychainServicePrefix, account: "clientSecret")?.toString() ?? ""
            }

            let redirectURI = "limitlessassistant://oauth-callback/google"
            let scope = "[https://www.googleapis.com/auth/calendar](https://www.googleapis.com/auth/calendar) [https://www.googleapis.com/auth/tasks](https://www.googleapis.com/auth/tasks)"

            init() {
                // Check if token exists in Keychain and is valid (e.g., check expiry)
                if let tokenData = KeychainService.loadData(service: keychainServicePrefix, account: "oauthToken"),
                   !tokenData.isEmpty {
                    // Further validation might be needed (e.g. check expiry date stored alongside token)
                    self.isAuthenticated = true 
                }
            }

            func authenticate() {
                guard !clientID.isEmpty, !clientSecret.isEmpty else {
                    // Notify user to set them in Settings
                    return
                }
                self.oauthswift = OAuthSwift(
                    consumerKey: clientID,
                    consumerSecret: clientSecret,
                    authorizeUrl: "[https://accounts.google.com/o/oauth2/auth](https://accounts.google.com/o/oauth2/auth)",
                    accessTokenUrl: "[https://oauth2.googleapis.com/token](https://oauth2.googleapis.com/token)",
                    responseType: "code"
                )

                oauthswift?.authorize(
                    withCallbackURL: URL(string: redirectURI)!,
                    scope: scope,
                    state: "STATE_G" 
                ) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let (credential, _, _)):
                            KeychainService.saveData(data: Data(credential.oauthToken.utf8), service: self.keychainServicePrefix, account: "oauthToken")
                            if !credential.oauthRefreshToken.isEmpty {
                                KeychainService.saveData(data: Data(credential.oauthRefreshToken.utf8), service: self.keychainServicePrefix, account: "oauthRefreshToken")
                            }
                            // Store credential.oauthTokenExpiresAt if needed for proactive refresh
                            self.isAuthenticated = true
                        case .failure(let error):
                            self.isAuthenticated = false
                        }
                    }
                }
            }
        }
        ```
    * **SettingsView (Basic):**
        ```swift
        // SettingsView.swift
        import SwiftUI

        struct SettingsView: View {
            @StateObject var googleAuthService = GoogleAuthService()
            // @StateObject var limitlessAuthService = LimitlessAuthService() // Implement similarly

            @State private var googleClientIDInput: String = ""
            @State private var googleClientSecretInput: String = ""

            var body: some View {
                Form {
                    Section("API Credentials (Stored in Keychain)") {
                        TextField("Google Client ID", text: $googleClientIDInput)
                        SecureField("Google Client Secret", text: $googleClientSecretInput)
                        Button("Save Google Credentials") {
                            KeychainService.saveData(data: Data(googleClientIDInput.utf8), service: "com.limitlessassistant.google", account: "clientID")
                            KeychainService.saveData(data: Data(googleClientSecretInput.utf8), service: "com.limitlessassistant.google", account: "clientSecret")
                        }
                    }
                    Section("Google Account") {
                        if googleAuthService.isAuthenticated {
                            Text("Connected to Google")
                        } else {
                            Button("Connect to Google") { googleAuthService.authenticate() }
                        }
                    }
                }
                .padding().frame(minWidth: 400, idealWidth: 500)
                .onAppear {
                    googleClientIDInput = KeychainService.loadData(service: "com.limitlessassistant.google", account: "clientID")?.toString() ?? ""
                    googleClientSecretInput = KeychainService.loadData(service: "com.limitlessassistant.google", account: "clientSecret")?.toString() ?? ""
                }
            }
        }
        ```
* **Tests / Test Suites:**
    * Mock `OAuthSwift` and `KeychainService`. Test token storage/retrieval. Test auth flow.
* **Acceptance Criteria:**
    * OAuth flow for Limitless/Google works. Tokens stored in Keychain. API keys/secrets stored. Auth status reflected.

---

## Phase 2: Local Database Setup (GRDB.swift) - Revised

* **Goal:** Define SQLite schema for conversations (potentially spanning multiple lifelogs), utterances, speakers, LLM suggestions, user actions, and settings. Implement setup and repositories.
* **AI Coder Instructions (Cursor):**
    * Create GRDB-compatible Swift structures: `ConversationRecord`, `SpeakerRecord`, `UtteranceRecord`, `LlmActionSuggestionRecord`, `UserActionRecord`, `ApplicationSettingRecord`.
    * `ConversationRecord` to include `logicalEventId` (nullable TEXT or UUID string) to group related lifelogs.
    * `DatabaseService` to manage `DatabaseQueue`, schema migrations (including FTS5 for utterances).
    * Define v1 migration. Create repositories.
* **Implementation Details:**
    * **Database Path:** `~/Library/Application Support/LimitlessAssistant/database.sqlite`
    * **GRDB Record Structs:**
        ```swift
        // ConversationRecord.swift
        import GRDB
        struct ConversationRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
            var id: Int64?
            var limitlessLogId: String // From Limitless lifelogs.id
            var title: String?
            var conversationStartTime: Date
            var conversationEndTime: Date?
            var creatorId: String
            var fullMarkdownContent: String?
            var logicalEventId: String? // UUID String to group related lifelogs
            var processedStatusActions: Int // 0: pending, 1: processing, 2: processed, 3: error
            var createdAt: Date
            static var databaseTableName = "conversations"
            mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
        }

        // SpeakerRecord.swift - (as before)
        import GRDB
        struct SpeakerRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
            var id: Int64?
            var name: String 
            var limitlessSpeakerNameRaw: String?
            var isUserCreator: Bool
            static var databaseTableName = "speakers"
            mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
        }

        // UtteranceRecord.swift - (as before)
        import GRDB
        struct UtteranceRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
            var id: Int64?
            var conversationId: Int64
            var speakerId: Int64?
            var textContent: String
            var utteranceStartTime: Date
            var utteranceEndTime: Date?
            var startOffsetMs: Int?
            var endOffsetMs: Int?
            var sequenceInConversation: Int
            var contentType: String?
            static var databaseTableName = "utterances"
            mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
            enum Columns: String, ColumnExpression {
                case id, conversationId, speakerId, textContent, utteranceStartTime, utteranceEndTime, startOffsetMs, endOffsetMs, sequenceInConversation, contentType
            }
        }

        // LlmActionSuggestionRecord.swift - (as before)
        import GRDB
        struct LlmActionSuggestionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
            var id: Int64?; var conversationId: Int64; var triggeringUtteranceIdStart: Int64?; var triggeringUtteranceIdEnd: Int64?; var triggeringSnippetText: String?; var llmName: String?; var llmPromptVersion: String?; var llmRawResponse: String?; var suggestedItemType: String; var extractedTitle: String?; var extractedStartDate: Date?; var extractedEndDate: Date?; var extractedLocation: String?; var extractedDetails: String?; var extractedAttendees: String?; var confidenceScore: Double?; var status: String; var googleItemId: String?; var createdAt: Date; var updatedAt: Date
            static var databaseTableName = "llmActionSuggestions"
            mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
        }

        // UserActionRecord.swift - (as before)
        import GRDB
        struct UserActionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
            var id: Int64?; var suggestionId: Int64; var actionType: String; var correctedItemType: String?; var correctedTitle: String?; var declineReason: String?; var actionTimestamp: Date
            static var databaseTableName = "userActions"
            mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
        }

        // ApplicationSettingRecord.swift - (as before)
        import GRDB
        struct ApplicationSettingRecord: Codable, FetchableRecord, PersistableRecord {
            var settingKey: String; var settingValue: String
            static var databaseTableName = "applicationSettings"; static let databasePrimaryKey = ["settingKey"]
        }
        ```
    * **DatabaseService:**
        ```swift
        // DatabaseService.swift
        import GRDB
        import Foundation

        class DatabaseService { // (Setup as before)
            static let shared = DatabaseService()
            var dbQueue: DatabaseQueue!
            private init() { /* ... create dbQueue ... */ 
                 do {
                    let fileManager = FileManager.default
                    let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let dbDirectoryURL = appSupportURL.appendingPathComponent("LimitlessAssistant")
                    try fileManager.createDirectory(at: dbDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                    let dbURL = dbDirectoryURL.appendingPathComponent("database.sqlite")
                    dbQueue = try DatabaseQueue(path: dbURL.path)
                    try setupDatabaseSchema(dbQueue)
                } catch {
                    fatalError("Failed to initialize database: \(error)")
                }
            }

            private func setupDatabaseSchema(_ dbQueue: DatabaseQueue) throws {
                var migrator = DatabaseMigrator()
                migrator.registerMigration("v1") { db in
                    try db.create(table: ConversationRecord.databaseTableName) { t in
                        t.autoIncrementedPrimaryKey("id")
                        t.column("limitlessLogId", .text).notNull().unique()
                        t.column("title", .text)
                        t.column("conversationStartTime", .datetime).notNull()
                        t.column("conversationEndTime", .datetime)
                        t.column("creatorId", .text).notNull()
                        t.column("fullMarkdownContent", .text)
                        t.column("logicalEventId", .text).indexed() // New field
                        t.column("processedStatusActions", .integer).notNull().defaults(to: 0)
                        t.column("createdAt", .datetime).notNull()
                    }
                    // Speakers, Utterances (with FTS5), LlmActionSuggestions, UserActions, ApplicationSettings tables (as before)
                    try db.create(table: SpeakerRecord.databaseTableName) { /* ... */ }
                    try db.create(virtualTable: "fts5Utterances", using: FTS5()) { /* ... */ }
                    try db.create(table: UtteranceRecord.databaseTableName) { /* ... */ }
                    try db.create(table: LlmActionSuggestionRecord.databaseTableName) { /* ... */ }
                    try db.create(table: UserActionRecord.databaseTableName) { /* ... */ }
                    try db.create(table: ApplicationSettingRecord.databaseTableName) { /* ... */ }
                }
                try migrator.migrate(dbQueue)
            }
        }
        ```
    * **Repositories:** Implement standard repositories. `ConversationRepository` will need methods to fetch by `logicalEventId` and to find adjacent conversations by time.
* **Tests / Test Suites:**
    * Unit tests for repositories. Test schema migration. Test FTS5.
* **Acceptance Criteria:**
    * Database created with revised schema including `logicalEventId`. Tables created. CRUD ops work. FTS5 search functional.

---

## Phase 3: Limitless API Integration & Data Ingestion (Revised for new DB Structure & Logical Events)

* **Goal:** Fetch Limitless data, parse it, and store in the revised DB, identifying and linking continuous logical events (e.g., meetings split across multiple lifelogs).
* **AI Coder Instructions (Cursor):**
    * Update `LimitlessAPIService` for granular JSON.
    * In `SyncController`'s processing logic:
        * For each `lifelog`: Create/update `ConversationRecord`.
        * **Logical Event Linking:** After saving a `ConversationRecord`, check its `conversationStartTime` against the `conversationEndTime` of the previously processed `ConversationRecord` (for the same `creatorId`, ordered by time). If within a small threshold (e.g., 1-5 minutes), assign the same `logicalEventId` (generate a new UUID if the previous had none, otherwise reuse). Store this `logicalEventId` in both records.
        * Process `lifelog.contents` into `SpeakerRecord`s and `UtteranceRecord`s as before.
    * Update repositories.
* **Implementation Details:**
    * **LimitlessAPIService `APILifelogData`:** (As before)
    * **SyncController `processAndStoreLifelogs` (Revised Logic for Logical Events):**
        ```swift
        // Inside SyncController
        private var lastProcessedConversationEndTime: Date? = nil // Track for logical event linking
        private var currentLogicalEventId: String? = nil
        private let logicalEventGapThreshold: TimeInterval = 5 * 60 // 5 minutes

        private func processAndStoreLifelogs(_ apiLifelogs: [LimitlessAPIService.APILifelogData]) {
            // Sort apiLifelogs by startTime to ensure correct processing order for logical events
            let sortedApiLifelogs = apiLifelogs.sorted { $0.startTime < $1.startTime }

            let isoDateFormatter = ISO8601DateFormatter(); isoDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let conversationRepo = ConversationRepository(); let speakerRepo = SpeakerRepository(); let utteranceRepo = UtteranceRepository()

            for apiLifelog in sortedApiLifelogs {
                guard let convStartTime = isoDateFormatter.date(from: apiLifelog.startTime) else { continue }
                let convEndTime = apiLifelog.endTime != nil ? isoDateFormatter.date(from: apiLifelog.endTime!) : nil
                let appUserCreatorId = SettingsManager.shared.userCreatorId ?? "default_user"

                // Logical Event ID determination
                if let lastEndTime = lastProcessedConversationEndTime,
                   convStartTime.timeIntervalSince(lastEndTime) <= logicalEventGapThreshold {
                    // Part of the current logical event
                    if currentLogicalEventId == nil { currentLogicalEventId = UUID().uuidString }
                } else {
                    // New logical event
                    currentLogicalEventId = UUID().uuidString
                }
                
                var conversation = ConversationRecord(
                    limitlessLogId: apiLifelog.id, title: apiLifelog.title,
                    conversationStartTime: convStartTime, conversationEndTime: convEndTime,
                    creatorId: appUserCreatorId, fullMarkdownContent: apiLifelog.markdown,
                    logicalEventId: currentLogicalEventId, // Assign determined logicalEventId
                    processedStatusActions: 0, createdAt: Date()
                )
                do {
                    // Save or update conversation (handle existing by limitlessLogId)
                    // ... (save/update conversation, get conversation.id) ...
                    // Process utterances and speakers (as before)
                } catch { /* ... */ }
                lastProcessedConversationEndTime = convEndTime ?? convStartTime // Update for next iteration
            }
        }
        ```
* **Tests / Test Suites:**
    * Test parsing. Test creation of all records. Test logical event linking logic with various time gaps.
* **Acceptance Criteria:**
    * Data parsed into granular structure. `logicalEventId` correctly assigned to group continuous lifelogs.

---

## Phase 4: Core LLM Integration (OpenAI/Gemini)

* **Goal:** Integrate with LLM service to send transcript text and receive responses. Securely manage LLM API keys.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---

## Phase 5: Item Identification & Extraction Logic (Revised for Logical Event Context)

* **Goal:** Refine LLM prompts. Parse responses. Link suggestions to conversations/utterances. Provide LLM with broader context from linked logical events.
* **AI Coder Instructions (Cursor):**
    * Refine prompts. Ensure `LLMActionAnalysisResponse` is suitable.
    * `ActionItemProcessingService`:
        * Iterate pending `ConversationRecord`s.
        * **Context Construction:** For a `ConversationRecord`, use its `logicalEventId` to fetch all related `ConversationRecord`s from `ConversationRepository`. Concatenate utterances from this entire logical event (ordered chronologically) to form `contextText` for the LLM. If no `logicalEventId`, use a time-window based approach to fetch adjacent conversations.
        * Send `contextText` to `LLMService`. Parse response. Create `LlmActionSuggestionRecord`s, linking to the primary `ConversationRecord` and specific utterances.
* **Implementation Details:**
    * **ActionItemProcessingService `constructContext` (Revised):**
        ```swift
        // Inside ActionItemProcessingService
        private func constructContext(for conversation: ConversationRecord) throws -> String {
            var conversationsToInclude: [ConversationRecord] = [conversation]
            let conversationRepo = ConversationRepository()

            if let logicalId = conversation.logicalEventId {
                let relatedConversations = try conversationRepo.fetchByLogicalEventId(logicalId)
                // Ensure 'conversation' is in relatedConversations, then sort and merge
                // This might fetch the same conversation again, handle deduplication or structure fetching.
                // For simplicity, assume fetchByLogicalEventId returns all including the current one, sorted.
                conversationsToInclude = relatedConversations.sorted { $0.conversationStartTime < $1.conversationStartTime }
            } else {
                // Fallback: Fetch temporally adjacent conversations (e.g., +/- 15 mins)
                let (preceding, succeeding) = try conversationRepo.fetchAdjacentConversationRecords(forConversationId: conversation.id!, windowMinutes: 15)
                conversationsToInclude = preceding.sorted { $0.conversationStartTime < $1.conversationStartTime } +
                                         [conversation] +
                                         succeeding.sorted { $0.conversationStartTime < $1.conversationStartTime }
            }
            
            var context = ""
            for conv in conversationsToInclude {
                let utterances = try utteranceRepository.fetchAll(forConversationId: conv.id!)
                for utterance in utterances {
                    let speakerName = (try? SpeakerRepository().fetchById(utterance.speakerId ?? -1)?.name) ?? "Unknown"
                    context += "\(speakerName): \(utterance.textContent)\n"
                }
                context += "---\n" // Separator between lifelogs if desired for LLM
            }
            return context
        }
        ```
* **Tests / Test Suites:** Test LLM response parsing. Test extraction accuracy with multi-lifelog contexts.
* **Acceptance Criteria:** LLM identifies actions using broader context from linked/adjacent lifelogs. Suggestions stored correctly.

---

## Phase 6: Basic UI - Settings & Status Display

* **Goal:** Develop `SettingsView` for API keys, Google defaults, sync schedule. Display statuses.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before, ensure `SettingsManager` is robust)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---

## Phase 7: UI - "Pending Review" & Item Management (Revised for Logical Event Context Display)

* **Goal:** UI for reviewing `LlmActionSuggestionRecord`s. Allow edit, accept, decline. Display context from the full logical event.
* **AI Coder Instructions (Cursor):**
    * `PendingReviewView` fetches pending `LlmActionSuggestionRecord`s.
    * Display suggestions.
    * **Context Display:** When user requests more context for a suggestion:
        * Fetch the parent `ConversationRecord`.
        * Use its `logicalEventId` (or temporal proximity) to fetch all related `ConversationRecord`s.
        * Present the `fullMarkdownContent` or concatenated utterances from this entire logical event, highlighting the `triggeringSnippetText` or related utterances.
    * Implement Edit, Accept, Decline actions.
* **Implementation Details:**
    * **PendingReviewViewModel:** Add method to load full logical event context.
        ```swift
        // Inside PendingReviewViewModel
        // @Published var fullEventContext: String?
        // func loadFullContext(for suggestion: LlmActionSuggestionRecord) {
        //    let convRepo = ConversationRepository()
        //    let uttRepo = UtteranceRepository()
        //    // Fetch parent conversation, then related conversations by logicalEventId or time
        //    // Concatenate their fullMarkdownContent or utterances
        //    // self.fullEventContext = ...
        // }
        ```
    * **SuggestionRow/DetailView:** Add button to trigger `loadFullContext` and display it (e.g., in a sheet or separate view).
* **Tests / Test Suites:** UI tests for displaying suggestions, full logical event context, and actions.
* **Acceptance Criteria:** Pending suggestions displayed. Users can view full context spanning multiple lifelogs if applicable. Actions work.

---

## Phase 8: Google Calendar & Tasks API Integration (No fundamental change due to logical events, uses `LlmActionSuggestionRecord`)

* **Goal:** Create Google Calendar events/Tasks from accepted `LlmActionSuggestionRecord`s. Fetch user's calendars/task lists.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before - `createEvent/createTask` methods take `LlmActionSuggestionRecord`)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---

## Phase 9: Automatic Processing & Notifications (No fundamental change due to logical events)

* **Goal:** Auto-process high-confidence `LlmActionSuggestionRecord`s. Provide notifications.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before - `ActionItemProcessingService` uses `ExtractedActionItem` which comes from context potentially spanning logical events)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---

## Phase 10: Learning Mechanism - Feedback Collection (No change)

* **Goal:** Store user feedback.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---

## Phase 11: Refinements, Error Handling, Logging (No fundamental change)

* **Goal:** Comprehensive error handling, structured logging, UI/UX refinement.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---

## Phase 12: Testing, Performance Optimization & Polish (No fundamental change)

* **Goal:** Thorough testing, performance optimization, overall polish.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---

## Phase 13: Advanced Search UI & Logic (Revised for Logical Event Context Display)

* **Goal:** UI for FTS5 search on utterances. Display results with context from the full logical event.
* **AI Coder Instructions (Cursor):**
    * `SearchView` and `SearchViewModel` as before.
    * Search `UtteranceRepository`.
    * **Context Display:** When user selects a search result (an `UtteranceRecord`):
        * Fetch its parent `ConversationRecord`.
        * Use `logicalEventId` (or temporal proximity) to fetch all related `ConversationRecord`s.
        * Display the `fullMarkdownContent` or concatenated utterances from this entire logical event, highlighting the matching search term or utterance.
* **Implementation Details:**
    * **SearchViewModel:** Add method to load and display full logical event context for a selected search result.
    * **SearchView:** When an utterance is selected from search results, trigger the loading and presentation of its full logical event context.
* **Tests / Test Suites:** Test search. Test display of full logical event context for search results.
* **Acceptance Criteria:** Search works. Results displayed with speaker/time. Users can access full logical event context for search results.

---

## Phase 14: Documentation & Packaging (was Phase 13)

* **Goal:** User documentation, app assets, package for distribution.
* **AI Coder Instructions (Cursor):** (As before)
* **Implementation Details:** (As before)
* **Tests / Test Suites:** (As before)
* **Acceptance Criteria:** (As before)

---
This phased plan provides a structured approach to building the Limitless Assistant. Each phase builds upon the previous, allowing for iterative development and testing.


