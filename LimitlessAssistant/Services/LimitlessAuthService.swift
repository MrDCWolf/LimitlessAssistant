import Foundation
import OAuthSwift

// Reusing AuthServiceError from GoogleAuthService for now.
// Consider defining specific errors if needed later.

// MARK: - LimitlessAuthService

// Note: This service handles authentication with the Limitless API.
// Placeholder URLs and scopes are used; these need to be confirmed with Limitless API documentation.
class LimitlessAuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    private var oauthswift: OAuthSwift?
    private let keychainServicePrefix = "com.limitlessassistant.limitless" // Unique service identifier

    // Keys for storing specific credentials in Keychain
    private enum KeychainAccount: String {
        case clientID = "clientID"
        case clientSecret = "clientSecret"
        case oauthToken = "oauthToken"
        case oauthRefreshToken = "oauthRefreshToken"
        case oauthTokenExpiry = "oauthTokenExpiry"
        // Limitless might also need userCreatorId stored securely
        case userCreatorId = "userCreatorId"
    }

    // --- OAuth Configuration (PLACEHOLDERS - Update with actual Limitless API details) ---
    private var clientID: String {
        KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.clientID.rawValue)?.toString() ?? ""
    }
    private var clientSecret: String {
        KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.clientSecret.rawValue)?.toString() ?? ""
    }
    // TODO: Replace with actual Limitless API endpoints
    let authorizeUrl = "https://api.limitless.ai/oauth/authorize" // Placeholder
    let accessTokenUrl = "https://api.limitless.ai/oauth/token"    // Placeholder
    let redirectURI = "limitlessassistant://oauth-callback/limitless" // Needs to match Info.plist
    // TODO: Confirm required Limitless API scope(s)
    let scope = "read_transcripts manage_actions" // Placeholder scope
    let responseType = "code" // Assuming standard OAuth 2.0 code flow

    // MARK: - Initialization
    init() {
        // Check for existing token on initialization
        if let _ = loadAccessToken() {
            self.isAuthenticated = true
            // TODO: Load userCreatorId if authenticated?
        }
    }

    // MARK: - Authentication Flow
    func authenticate() {
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            print("Error: Limitless Client ID or Client Secret not found in Keychain.")
            // TODO: Publish error state
            return
        }

        // Use OAuth2Swift for OAuth2 flows
        let oauthSwiftInstance = OAuth2Swift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: authorizeUrl,
            accessTokenUrl: accessTokenUrl,
            responseType: "code"
        )
        self.oauthswift = oauthSwiftInstance

        // Start the authorization process
        let state = "STATE_L_" + UUID().uuidString
        oauthSwiftInstance.authorize(
            withCallbackURL: redirectURI,
            scope: scope,
            state: state,
            completionHandler: { [weak self] (result: Result<OAuthSwift.TokenSuccess, OAuthSwiftError>) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let tokenSuccess):
                        let credential = tokenSuccess.credential
                        if let receivedState = tokenSuccess.parameters["state"] as? String, receivedState == state {
                            do {
                                try self.saveCredentials(credential: credential)
                                self.isAuthenticated = true
                            } catch {
                                self.isAuthenticated = false
                            }
                        } else {
                            self.isAuthenticated = false
                        }
                    case .failure(_):
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

        // Save Refresh Token
        if !credential.oauthRefreshToken.isEmpty,
           let refreshTokenData = credential.oauthRefreshToken.toData() {
            status = KeychainService.saveData(data: refreshTokenData, service: keychainServicePrefix, account: KeychainAccount.oauthRefreshToken.rawValue)
            if status != errSecSuccess {
                 print("Warning: Failed to save Limitless refresh token. Status: \(status)")
            }
        }

        // Save Expiry Date
        if let expiryDate = credential.oauthTokenExpiresAt,
           let expiryData = try? JSONEncoder().encode(expiryDate) {
            status = KeychainService.saveData(data: expiryData, service: keychainServicePrefix, account: KeychainAccount.oauthTokenExpiry.rawValue)
             if status != errSecSuccess {
                print("Warning: Failed to save Limitless token expiry date. Status: \(status)")
            }
        }
        // TODO: Logic to store userCreatorId if received during auth or fetched separately
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

    // MARK: - Token Refresh (Conceptual - Needs Limitless API details)
    func refreshTokenIfNeeded(completion: @escaping (Result<Void, AuthServiceError>) -> Void) {
         guard let refreshToken = loadRefreshToken() else {
            completion(.failure(.missingToken))
            return
        }
       let oauthSwiftForRefresh = (self.oauthswift as? OAuth2Swift) ?? OAuth2Swift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: authorizeUrl,
            accessTokenUrl: accessTokenUrl,
            responseType: "code"
        )
        self.oauthswift = oauthSwiftForRefresh

        // Use the correct refresh URL if different from accessTokenUrl
        oauthSwiftForRefresh.renewAccessToken(withRefreshToken: refreshToken) { [weak self] (result: Result<OAuthSwift.TokenSuccess, OAuthSwiftError>) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let tokenSuccess):
                    let credential = tokenSuccess.credential
                    do {
                        try self.saveCredentials(credential: credential)
                         self.isAuthenticated = true
                        completion(.success(()))
                    } catch {
                        completion(.failure(error as? AuthServiceError ?? .tokenSaveFailed(errSecUnimplemented)))
                    }
                case .failure(let error):
                    print("Error refreshing Limitless token: \(error.localizedDescription)")
                    self.isAuthenticated = false
                    completion(.failure(.tokenRefreshFailed(error)))
                }
            }
        }
    }

    // MARK: - Logout
    func logout() {
        let accountsToDelete: [KeychainAccount] = [.oauthToken, .oauthRefreshToken, .oauthTokenExpiry, .clientID, .clientSecret, .userCreatorId] // Also clear client creds if needed
        for account in accountsToDelete {
             let status = KeychainService.deleteData(service: keychainServicePrefix, account: account.rawValue)
            if status != errSecSuccess && status != errSecItemNotFound {
                print("Warning: Failed to delete keychain item \(account.rawValue) for service \(keychainServicePrefix). Status: \(status)")
            }
        }
        self.oauthswift = nil
         DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }

    // MARK: - User Creator ID (Conceptual)
    func saveUserCreatorId(_ id: String) -> Bool {
        guard let data = id.toData() else { return false }
        let status = KeychainService.saveData(data: data, service: keychainServicePrefix, account: KeychainAccount.userCreatorId.rawValue)
        return status == errSecSuccess
    }

    func loadUserCreatorId() -> String? {
        return KeychainService.loadData(service: keychainServicePrefix, account: KeychainAccount.userCreatorId.rawValue)?.toString()
    }
} 