import Foundation

// Represents the top-level structure of the Limitless API response
struct LimitlessAPIResponse: Codable {
    let data: LimitlessData
    // let meta: LimitlessMeta? // Uncomment if needed
}

struct LimitlessData: Codable {
    let lifelogs: [APILifelogData]
}

struct APILifelogData: Codable {
    let id: String
    let title: String?
    let markdown: String?
    let startTime: String
    let endTime: String?
    let creatorId: String?
    let contents: [APIContentData]
}

struct APIContentData: Codable {
    let type: String
    let content: String?
    let text: String?
    let speakerName: String?
    let startTime: String?
    let endTime: String?
    let startOffsetMs: Int?
    let endOffsetMs: Int?

    var primaryText: String? {
        return text ?? content
    }
}

// Optional: Metadata structs if needed
// struct LimitlessMeta: Codable { ... }
// struct LifelogMeta: Codable { ... }

// --- Helper for Date Parsing ---
extension ISO8601DateFormatter {
    static let limitlessFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let limitlessFormatterNoFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from limitlessString: String?) -> Date? {
        guard let dateString = limitlessString else { return nil }
        return limitlessFormatter.date(from: dateString) ?? limitlessFormatterNoFractions.date(from: dateString)
    }
} 