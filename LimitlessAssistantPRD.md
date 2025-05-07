# Product Requirements Document: Limitless Assistant (Version 1.0)

**1. Introduction & Vision**

Limitless Assistant is a macOS application designed to help users capture, understand, and act upon information from their daily audio transcripts. It intelligently identifies potential calendar events, tasks, and reminders from Limitless.ai transcript data, integrates seamlessly with Google services (Calendar & Tasks), and learns from user interactions to improve its suggestions over time. The goal is to provide a smart, intuitive, and efficient way for users to manage their commitments and to-dos that originate from spoken interactions, enhancing productivity and organization.

**2. Goals**

* **Automated Information Capture:** Automatically process Limitless transcripts to identify actionable items (events, tasks, reminders) specific to the user.
* **Intelligent Categorization:** Accurately categorize these items with a high degree of precision.
* **Seamless Google Integration:** Allow users to effortlessly add these items to their Google Calendar and Google Tasks with minimal friction.
* **User-Controlled Workflow:** Provide a clear, modern interface for reviewing, editing, accepting, or declining suggestions, especially for items where the system's confidence is lower.
* **Adaptive Learning:** Implement a feedback mechanism allowing the system to improve suggestion accuracy over time by learning from user choices.
* **Data Privacy & Security:** Ensure all user data, especially sensitive transcripts and API keys, is handled securely and stored locally using best practices for macOS.
* **Performance & Stability:** Deliver a responsive and reliable user experience, even with large volumes of transcript data.
* **Extensibility:** Build a robust and modular foundation that allows for future enhancements, such as support for additional LLMs, services, or advanced analytical features.

**3. Target Users**

* Individuals actively using Limitless.ai for lifelogging and capturing audio transcripts of their daily interactions.
* Users who rely heavily on Google Calendar and Google Tasks for personal and professional organization.
* Productivity-focused individuals seeking to streamline the conversion of spoken intentions into actionable digital items, reducing manual entry and cognitive load.
* Mac users who appreciate native, well-integrated desktop applications.

**4. Key Features & Functionality**

**4.1. Setup & Authentication**
    * **4.1.1. Limitless API Integration:**
        * Users must be able to securely input their Limitless API credentials (OAuth 2.0 based).
        * Credentials (access/refresh tokens) must be securely stored in the macOS Keychain.
        * The application must clearly display the connection status to the Limitless API.
        * Provide a mechanism to re-authenticate if tokens expire or are revoked.
    * **4.1.2. Google Account Integration:**
        * Users must be able to authenticate their Google Account using OAuth 2.0, granting necessary permissions for Google Calendar API (read/write) and Google Tasks API (read/write).
        * Credentials/tokens must be securely stored in the macOS Keychain.
        * Users must be able to select a default Google Calendar for new events (e.g., "Limitless Calendar Events").
        * Users must be able to select a default Google Tasks list for new tasks.
        * The application must clearly display the connection status to Google services.
        * Provide a mechanism to re-authenticate.
    * **4.1.3. User Identification:**
        * The application will need to reliably identify the primary user's `creatorId` from the Limitless API to filter relevant transcript portions. This should be confirmed or configured during the initial setup.

**4.2. Data Ingestion & Processing**
    * **4.2.1. Transcript Fetching:**
        * Periodically fetch new transcript data from the Limitless API.
        * Implement a user-configurable schedule for fetching (e.g., every 15 minutes, 30 minutes, 1 hour, or manual trigger).
        * Implement robust retry logic with exponential backoff (e.g., up to 1-minute intervals) for API calls to handle transient network issues or API rate limits gracefully.
    * **4.2.2. Local Transcript Storage (Revised for Logical Events):**
        * Store all fetched transcript data indefinitely (or per user configuration) in a local SQLite database.
        * The database schema should be optimized for querying and include `ConversationRecord`s (representing individual lifelogs), `UtteranceRecord`s (individual speech segments), and `SpeakerRecord`s.
        * `ConversationRecord`s will include a `logicalEventId` to group multiple lifelogs that form a single continuous event (e.g., a long meeting).
    * **4.2.3. LLM-Powered Item Identification & Extraction:**
        * Utilize a Large Language Model (LLM) to analyze new transcripts. Initial support for OpenAI (e.g., GPT-4o, GPT-4 Turbo) and Google Gemini models via their respective APIs.
        * **Contextual Analysis:** The LLM will be provided with context from the entire logical event (potentially spanning multiple `ConversationRecord`s linked by `logicalEventId`) for more accurate action item extraction.
        * **Prompt Engineering Strategy:**
            * Develop sophisticated prompts to accurately identify potential **Calendar Events**, **Tasks**, or **Reminders**.
            * Extract relevant details: title, date(s), time(s), duration, location, attendees, description.
            * **User Specificity Logic:** Critically determine if the identified item is for the current application user ("Me").
            * The LLM interaction should return the extracted item details, its categorized type, a **confidence score**, and the **triggering snippet**.
        * User-provided API keys for LLM services will be securely stored in the macOS Keychain.

**4.3. User Interface & Interaction (SwiftUI)**
    * **4.3.1. Main Dashboard/Review View:**
        * A clean, modern, and intuitive interface built with SwiftUI.
        * Display a primary list of "Pending Review" items: suggestions from the LLM that fall below a high-confidence threshold.
        * Each item shows key details, confidence score, and the triggering snippet.
        * **Contextual Display:** Allow users to easily view the broader context of a suggestion, loading utterances from the entire logical event (spanning multiple lifelogs if necessary).
        * **Actions per item:** Edit, Accept, Decline.
    * **4.3.2. Automatic Processing & Notifications:**
        * Items identified with very high confidence can be configured to be automatically added to Google services.
        * Global setting to disable automatic additions.
        * macOS notifications for automatically added items.
    * **4.3.3. Status Indicators & Manual Sync:**
        * Clear visual indication of sync status and last sync time.
        * "Sync Now" button.
    * **4.3.4. Processed Items History (Optional V1, Desirable V1.1):**
        * Log of all processed items.
    * **4.3.5. Settings View:**
        * Manage API keys (Limitless, Google, LLM).
        * Manage Google Account connection.
        * Select default Google Calendar and Task list.
        * Configure data fetching schedule and confidence thresholds.
        * Notification preferences.
    * **4.3.6. Advanced Search View (New for V1, from TASKS.md Phase 13):**
        * Allow users to perform keyword searches across all stored utterances using SQLite FTS5.
        * Display search results with speaker, timestamp, and the matching utterance.
        * Allow users to view the full context of a search result, loading the entire logical event (potentially spanning multiple lifelogs).

**4.4. Learning Mechanism**
    * **4.4.1. Feedback Data Collection:**
        * Systematically store user actions (accept, decline, edits, reasons for decline) in the local database, linked to the specific suggestion.
    * **4.4.2. Simple Feedback Loop (Initial Implementation for V1.0):**
        * Collected feedback will be used for future manual refinement of LLM prompts or processing rules.
    * **4.4.3. Future Enhancement: Automated Learning (Post-V1.0):**
        * Pave the way for more advanced adaptive learning.

**4.5. Local Database (SQLite via GRDB.swift - Revised Schema)**
    * **4.5.1. Purpose:** Store conversations, utterances, speakers, LLM suggestions, user feedback, and settings.
    * **4.5.2. Key Tables:**
        * `ConversationRecord`: Represents individual lifelogs, includes `limitlessLogId`, `title`, timestamps, `fullMarkdownContent`, and a `logicalEventId` to group related lifelogs.
        * `SpeakerRecord`: Stores speaker information (name, `isUserCreator`).
        * `UtteranceRecord`: Stores individual speech segments with text (`FTS5` enabled), speaker link, timestamps, and link to `ConversationRecord`.
        * `LlmActionSuggestionRecord`: Stores LLM-identified actions, linked to `ConversationRecord` and potentially specific utterances. Includes extracted details, confidence, status, and `googleItemId`.
        * `UserActionRecord`: Logs user feedback on suggestions.
        * `ApplicationSettingRecord`: Stores application settings.
    * **4.5.3. Database Location & Management:**
        * User's Application Support directory. Schema creation and migrations handled by the app.

**5. Technical Stack & Libraries**

* **Operating System:** macOS (latest official version and one version prior).
* **Development Environment:** Xcode (latest stable version).
* **Primary Language:** Swift (latest stable version).
* **User Interface Framework:** SwiftUI.
* **Networking & Concurrency:** `URLSession`, Swift Concurrency (`async/await`).
* **Authentication (OAuth 2.0):** `OAuthSwift`.
* **Secure Credential Storage:** Native `Security` framework (Keychain Services).
* **Database Management:** SQLite with `GRDB.swift`.
* **JSON Parsing:** Swift `Codable`.
* **LLM API Clients:** Direct API calls or official SDKs (e.g., `google-generative-ai-swift`).
* **Background Task Scheduling & Timers:** `Timer` initially.
* **Logging Framework:** `OSLog`.
* **Source Code Management:** Git, GitHub.
* **Dependency Management:** Swift Package Manager (SPM).

**6. Performance & Stability Considerations**

* **Efficient API Usage:** Respect rate limits, use conditional requests if possible.
* **Responsive UI:** All long-running tasks on background threads. Lazy loading for lists.
* **Memory Management:** Efficient data handling and querying.
* **Robust Error Handling:** Comprehensive error handling with user-friendly messages.
* **Database Optimization:** Efficient schema, indexing, FTS5 for search.
* **Stability & Crash Prevention:** Thorough testing, defensive programming.
* **Application Startup Time:** Optimize for quick launch.

**7. Non-Functional Requirements**

* **Usability:** Intuitive, easy to learn, efficient.
* **Security:** Paramount. Keychain for secrets, local storage for transcripts.
* **Reliability:** Consistent and predictable operation.
* **Maintainability:** Well-structured, commented code.
* **Accessibility (A11y):** Adhere to macOS accessibility guidelines.

**8. Future Considerations (Post V1.0)**

* Support for additional LLMs (including local models).
* Expanded service integrations (other calendars, task managers, note apps).
* Advanced transcript analytics (summaries, topics, sentiment).
* More sophisticated learning mechanisms.
* Natural language querying of stored transcripts.
* Customizable workflows/rules.

**9. Open Questions & Design Decisions for Development Phase**

* Final iteration of LLM prompt structures for optimal extraction across (potentially multiple) linked lifelogs.
* Optimal strategy for determining the boundaries of a "logical event" when linking `ConversationRecord`s (time threshold, topic analysis in future).
* Specific UI/UX for presenting context that spans multiple lifelogs.
* Detailed design of the "learning mechanism" beyond simple feedback storage.
* Strategy for handling API version changes.
* Database schema migrations strategy.
