import SwiftUI

struct SettingsView: View {
    // Instantiate the auth services as StateObjects
    // They will manage their own state ('isAuthenticated')
    @StateObject var googleAuthService = GoogleAuthService()
    @StateObject var limitlessAuthService = LimitlessAuthService() // Add Limitless service
    // TODO: Add LLM service instance later

    // State variables to hold user input for credentials
    @State private var googleClientIDInput: String = ""
    @State private var googleClientSecretInput: String = ""
    @State private var limitlessClientIDInput: String = ""
    @State private var limitlessClientSecretInput: String = ""
    // TODO: Add state vars for LLM API keys

    // Service identifiers for Keychain access
    private let googleKeychainPrefix = "com.limitlessassistant.google"
    private let limitlessKeychainPrefix = "com.limitlessassistant.limitless"

    var body: some View {
        // Using Form for standard macOS settings layout
        Form {
            // MARK: - Google Credentials
            Section("Google API Credentials (Stored in Keychain)") {
                TextField("Google Client ID", text: $googleClientIDInput)
                    .textContentType(.username) // Hint for keychain autofill
                SecureField("Google Client Secret", text: $googleClientSecretInput)
                     .textContentType(.password) // Hint for keychain autofill
                Button("Save Google Credentials") {
                    saveGoogleCredentials()
                }
                .disabled(googleClientIDInput.isEmpty || googleClientSecretInput.isEmpty)
            }

            // MARK: - Google Account Connection
            Section("Google Account") {
                if googleAuthService.isAuthenticated {
                    HStack {
                        Text("Connected to Google")
                        Spacer()
                        Button("Disconnect", role: .destructive) {
                            googleAuthService.logout()
                        }
                    }
                } else {
                    Button("Connect to Google") {
                        googleAuthService.authenticate()
                    }
                    .disabled(googleClientIDInput.isEmpty || googleClientSecretInput.isEmpty)
                    // Disable connect button if credentials haven't been saved yet
                }
            }

            // MARK: - Limitless Credentials
            Section("Limitless API Credentials (Stored in Keychain)") {
                 TextField("Limitless Client ID", text: $limitlessClientIDInput)
                    .textContentType(.username)
                 SecureField("Limitless Client Secret", text: $limitlessClientSecretInput)
                    .textContentType(.password)
                 Button("Save Limitless Credentials") {
                    saveLimitlessCredentials()
                 }
                 .disabled(limitlessClientIDInput.isEmpty || limitlessClientSecretInput.isEmpty)
            }

            // MARK: - Limitless Account Connection
             Section("Limitless Account") {
                if limitlessAuthService.isAuthenticated {
                     HStack {
                        Text("Connected to Limitless")
                        Spacer()
                        Button("Disconnect", role: .destructive) {
                            limitlessAuthService.logout()
                        }
                    }
                } else {
                    Button("Connect to Limitless") {
                        limitlessAuthService.authenticate()
                    }
                    .disabled(limitlessClientIDInput.isEmpty || limitlessClientSecretInput.isEmpty)
                }
            }

            // TODO: Add sections for LLM API Keys (OpenAI, Gemini, etc.)
            // TODO: Add sections for selecting default Google Calendar/Task List
            // TODO: Add section for sync schedule configuration
        }
        .padding()
        .frame(minWidth: 450, idealWidth: 550) // Adjust frame as needed
        .onAppear {
            // Load existing credentials when the view appears
            loadCredentialsFromKeychain()
        }
    }

    // MARK: - Helper Functions
    private func saveGoogleCredentials() {
        guard let clientIDData = googleClientIDInput.toData(),
              let clientSecretData = googleClientSecretInput.toData() else {
            print("Error: Could not convert Google credentials to Data.")
            // TODO: Show user-facing error
            return
        }
        let idStatus = KeychainService.saveData(data: clientIDData, service: googleKeychainPrefix, account: "clientID")
        let secretStatus = KeychainService.saveData(data: clientSecretData, service: googleKeychainPrefix, account: "clientSecret")

        if idStatus != errSecSuccess || secretStatus != errSecSuccess {
            print("Error saving Google credentials to Keychain. Status codes: ID=\(idStatus), Secret=\(secretStatus)")
            // TODO: Show user-facing error
        } else {
            print("Google credentials saved successfully.")
            // Optionally provide user feedback (e.g., temporary confirmation message)
        }
    }

    private func saveLimitlessCredentials() {
         guard let clientIDData = limitlessClientIDInput.toData(),
              let clientSecretData = limitlessClientSecretInput.toData() else {
            print("Error: Could not convert Limitless credentials to Data.")
            return
        }
        let idStatus = KeychainService.saveData(data: clientIDData, service: limitlessKeychainPrefix, account: "clientID")
        let secretStatus = KeychainService.saveData(data: clientSecretData, service: limitlessKeychainPrefix, account: "clientSecret")

        if idStatus != errSecSuccess || secretStatus != errSecSuccess {
             print("Error saving Limitless credentials to Keychain. Status codes: ID=\(idStatus), Secret=\(secretStatus)")
        } else {
            print("Limitless credentials saved successfully.")
        }
    }

    private func loadCredentialsFromKeychain() {
        googleClientIDInput = KeychainService.loadData(service: googleKeychainPrefix, account: "clientID")?.toString() ?? ""
        // Note: SecureFields don't typically pre-fill for security, but we load to enable/disable buttons.
        // For actual display, you might just show placeholder text or asterisks.
        googleClientSecretInput = KeychainService.loadData(service: googleKeychainPrefix, account: "clientSecret")?.toString() ?? ""

        limitlessClientIDInput = KeychainService.loadData(service: limitlessKeychainPrefix, account: "clientID")?.toString() ?? ""
        limitlessClientSecretInput = KeychainService.loadData(service: limitlessKeychainPrefix, account: "clientSecret")?.toString() ?? ""

        // TODO: Load LLM keys
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
} 