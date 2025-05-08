import Foundation

// Renamed from LimitlessAPIServiceType to LimitlessAPIServiceProtocol
protocol LimitlessAPIServiceProtocol {
    // Modified to be an async function
    func fetchLifelogs() async throws -> [APILifelogData]
}

class LimitlessAPIService: LimitlessAPIServiceProtocol { // Conforms to the renamed protocol
    private let authService: LimitlessAuthService
    private let baseURL = URL(string: "https://api.limitless.ai/v1")! // Update if needed

    init(authService: LimitlessAuthService = LimitlessAuthService()) {
        self.authService = authService
    }

    /// Fetches lifelogs from the Limitless API and decodes them into [APILifelogData].
    // Modified to be an async function
    func fetchLifelogs() async throws -> [APILifelogData] {
        guard let accessToken = authService.loadAccessToken() else {
            throw AuthServiceError.missingToken
        }
        let url = baseURL.appendingPathComponent("lifelogs")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Using modern async/await URLSession
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // TODO: Better error handling based on status code
            throw URLError(.badServerResponse) // Or a more specific error
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(LimitlessAPIResponse.self, from: data)
            return apiResponse.data.lifelogs
        } catch {
            // Log the decoding error for more insight
            print("JSON Decoding Error: \(error.localizedDescription)") 
            print("Failed to decode: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
            throw error
        }
    }
} 