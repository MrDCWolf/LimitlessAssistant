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

        // Attempting a common OAuth2Swift initializer pattern
        let oauthSwiftInstance = OAuth2Swift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: authorizeUrl,
            accessTokenUrl: accessTokenUrl,
            responseType: "code" // responseType is often specified for OAuth2
        )
        self.oauthswift = oauthSwiftInstance

        // Use ASWebAuthenticationSession for macOS (preferred over SFSafariViewController for this platform)
        // This handler needs to be set up properly.
        // For now, we proceed, assuming a handler will be configured or the default behavior works.
        // oauthSwiftInstance.authorizeURLHandler = // ... appropriate handler ...

        // Start the authorization process
        let state = "STATE_G_" + UUID().uuidString // Generate a unique state for security
        
        // Corrected authorize call
        oauthSwiftInstance.authorize(
            withCallbackURL: redirectURI, // Can be String or URL
            scope: scope,
            state: state,
            // PKCE parameters can be added here if the provider requires them
            // codeChallenge: <challenge>,
            // codeChallengeMethod: "S256",
            // codeVerifier: <verifier>,
            completionHandler: { [weak self] (result: Result<OAuthSwift.TokenSuccess, OAuthSwiftError>) in // Explicitly type result
                guard let self = self else { return }
                DispatchQueue.main.async { // Correct async call
                    switch result {
                    case .success(let tokenSuccess):
                        print("Google Auth Success!")
                        let credential = tokenSuccess.credential
                        // Verify state parameter to prevent CSRF attacks
                        if let receivedState = tokenSuccess.parameters["state"] as? String, receivedState == state {
                            print("State verified.")
                            do {
                                try self.saveCredentials(credential: credential)
                                self.isAuthenticated = true
                            } catch {
                                print("Error saving Google credentials: \(error)")
                                self.isAuthenticated = false
                            }
                        } else {
                            print("Error: State parameter mismatch. Potential CSRF attack.")
                            self.isAuthenticated = false
                        }

                    case .failure(let error):
                        print("Error during Google OAuth: \(error.localizedDescription)")
                        self.isAuthenticated = false
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
        
        // Ensure clientID and clientSecret are available for token refresh
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            completion(.failure(.missingCredentials))
            return
        }

        // Attempting a common OAuth2Swift initializer pattern for refresh
        let oauthSwiftForRefresh = self.oauthswift as? OAuth2Swift ?? OAuth2Swift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: authorizeUrl, 
            accessTokenUrl: accessTokenUrl,
            responseType: "code"
        )
        self.oauthswift = oauthSwiftForRefresh // Ensure self.oauthswift is updated if it was nil

        oauthSwiftForRefresh.renewAccessToken(withRefreshToken: refreshToken) { [weak self] (result: Result<OAuthSwift.TokenSuccess, OAuthSwiftError>) in // Explicitly type result
            guard let self = self else { return }
            DispatchQueue.main.async { // Correct async call
                switch result {
                case .success(let tokenSuccess):
                    let credential = tokenSuccess.credential
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