import Foundation
import OAuthSwift

// MARK: - Error Handling
enum AuthServiceError: Error {
    case keychainError(OSStatus)
    case missingCredentials
    case authenticationFailed(Error)
    case missingToken
    case tokenSaveFailed(OSStatus)
    case tokenLoadFailed
    case tokenRefreshFailed(Error?)
}

// MARK: - GoogleAuthService

// Note: This is based on the conceptual example in TASKS.md.
// Further implementation will be needed for full functionality (e.g., token expiry check, refresh logic).
class GoogleAuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    private var oauthswift: OAuthSwift?
    private let keychainServicePrefix = "com.limitlessassistant.google" // Unique service identifier for Keychain

    // Keys for storing specific credentials in Keychain
    private enum KeychainAccount: String {
        case clientID = "clientID"
        case clientSecret = "clientSecret"
        case oauthToken = "oauthToken"
        case oauthRefreshToken = "oauthRefreshToken"
        case oauthTokenExpiry = "oauthTokenExpiry"
    }

    // --- OAuth Configuration ---
    // These should eventually be configurable or constants
    private var clientID: String {
        KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.clientID.rawValue)?.toString() ?? ""
    }
    private var clientSecret: String {
        KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.clientSecret.rawValue)?.toString() ?? ""
    }
    let authorizeUrl = "https://accounts.google.com/o/oauth2/auth"
    let accessTokenUrl = "https://oauth2.googleapis.com/token"
    let redirectURI = "limitlessassistant://oauth-callback/google" // Needs to match Info.plist URL Scheme
    let scope = "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks" // Calendar Read/Write, Tasks Read/Write
    let responseType = "code"

    // MARK: - Initialization
    init() {
        // Check for existing token on initialization
        // A more robust check would validate the token expiry date
        if let _ = loadAccessToken() {
            self.isAuthenticated = true
        }
    }

    // MARK: - Authentication Flow
    func authenticate() {
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            // TODO: Handle missing client ID/Secret (e.g., publish an error state)
            print("Error: Google Client ID or Client Secret not found in Keychain.")
            // Optionally publish an error state for the UI
            // self.authenticationError = .missingCredentials
            return
        }

        self.oauthswift = OAuthSwift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: authorizeUrl,
            accessTokenUrl: accessTokenUrl,
            responseType: responseType
        )

        // Use SFSafariViewController for the auth screen on macOS/iOS if possible
        // This requires assigning an appropriate handler. For macOS, ASWebAuthenticationSession is preferred.
        // We will set this up properly when integrating with the UI (SettingsView).
        #if os(iOS) || os(macOS)
        // Placeholder: Actual handler needs the presentation context (view controller/window)
        // oauthswift?.authorizeURLHandler = SafariURLHandler(viewController: /* Needs context */, oauthSwift: self.oauthswift!)
        #endif

        // Start the authorization process
        let state = "STATE_G_" + UUID().uuidString // Generate a unique state for security
        let _ = oauthswift?.authorize(
            withCallbackURL: URL(string: redirectURI)!,
            scope: scope,
            state: state,
            // Add PKCE parameters if required by Google in the future or for specific flows
            // codeChallenge: <challenge>,
            // codeChallengeMethod: "S256",
            // codeVerifier: <verifier>,
            completionHandler: { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let (credential, _, parameters)): // parameters might contain additional info
                        print("Google Auth Success!")
                        // Verify state parameter to prevent CSRF attacks
                        if let receivedState = parameters["state"] as? String, receivedState == state {
                            print("State verified.")
                            do {
                                try self.saveCredentials(credential: credential)
                                self.isAuthenticated = true
                                // TODO: Post notification or update state to indicate success
                            } catch {
                                print("Error saving Google credentials: \(error)")
                                self.isAuthenticated = false
                                // TODO: Handle error (e.g., publish error state)
                            }
                        } else {
                            print("Error: State parameter mismatch. Potential CSRF attack.")
                             self.isAuthenticated = false
                            // TODO: Handle error (e.g., publish error state)
                        }

                    case .failure(let error):
                        print("Error during Google OAuth: \(error.localizedDescription)")
                        self.isAuthenticated = false
                        // TODO: Handle error (e.g., publish error state)
                        // self.authenticationError = .authenticationFailed(error)
                    }
                }
            }
        )
    }

    // MARK: - Credential Management (Private Helpers)

    private func saveCredentials(credential: OAuthSwiftCredential) throws {
        // Save Access Token
        guard let tokenData = credential.oauthToken.toData() else {
            throw AuthServiceError.missingToken
        }
        var status = KeychainService.saveData(data: tokenData, service: keychainServicePrefix, account: KeychainAccount.oauthToken.rawValue)
        if status != errSecSuccess {
            throw AuthServiceError.tokenSaveFailed(status)
        }

        // Save Refresh Token (if available)
        if !credential.oauthRefreshToken.isEmpty,
           let refreshTokenData = credential.oauthRefreshToken.toData() {
            status = KeychainService.saveData(data: refreshTokenData, service: keychainServicePrefix, account: KeychainAccount.oauthRefreshToken.rawValue)
            if status != errSecSuccess {
                // Log error but don't necessarily fail the whole process if refresh token fails to save
                print("Warning: Failed to save Google refresh token. Status: \(status)")
            }
        }

        // Save Expiry Date (if available)
        if let expiryDate = credential.oauthTokenExpiresAt,
           let expiryData = try? JSONEncoder().encode(expiryDate) {
            status = KeychainService.saveData(data: expiryData, service: keychainServicePrefix, account: KeychainAccount.oauthTokenExpiry.rawValue)
            if status != errSecSuccess {
                print("Warning: Failed to save Google token expiry date. Status: \(status)")
            }
        }
    }

    func loadAccessToken() -> String? {
        return KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.oauthToken.rawValue)?.toString()
    }

    func loadRefreshToken() -> String? {
        return KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.oauthRefreshToken.rawValue)?.toString()
    }

    func loadTokenExpiryDate() -> Date? {
        guard let expiryData = KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.oauthTokenExpiry.rawValue) else {
            return nil
        }
        return try? JSONDecoder().decode(Date.self, from: expiryData)
    }

    // MARK: - Token Refresh (Conceptual)
    func refreshTokenIfNeeded(completion: @escaping (Result<Void, AuthServiceError>) -> Void) {
        guard let refreshToken = loadRefreshToken() else {
            completion(.failure(.missingToken))
            return
        }
        guard let currentOAuthSwift = self.oauthswift ?? OAuthSwift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: authorizeUrl,
            accessTokenUrl: accessTokenUrl,
            responseType: responseType
        ) else {
             completion(.failure(.missingCredentials))
            return
        }

        currentOAuthSwift.renewAccessToken(withRefreshToken: refreshToken) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let credential):
                    do {
                        try self.saveCredentials(credential: credential)
                        self.isAuthenticated = true // Ensure state reflects successful refresh
                        completion(.success(()))
                    } catch {
                        completion(.failure(error as? AuthServiceError ?? .tokenSaveFailed(errSecUnimplemented)))
                    }
                case .failure(let error):
                    print("Error refreshing Google token: \(error.localizedDescription)")
                    self.isAuthenticated = false // Mark as unauthenticated if refresh fails
                    completion(.failure(.tokenRefreshFailed(error)))
                }
            }
        }
    }

    // MARK: - Logout
    func logout() {
        let accountsToDelete: [KeychainAccount] = [.oauthToken, .oauthRefreshToken, .oauthTokenExpiry]
        for account in accountsToDelete {
            let status = KeychainService.deleteData(service: keychainServicePrefix, account: account.rawValue)
            if status != errSecSuccess && status != errSecItemNotFound {
                print("Warning: Failed to delete keychain item \(account.rawValue) for service \(keychainServicePrefix). Status: \(status)")
            }
        }
        self.oauthswift = nil // Clear the OAuthSwift instance
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
        // TODO: Add any additional cleanup (e.g., clearing cookies if using web views)
    }
} 