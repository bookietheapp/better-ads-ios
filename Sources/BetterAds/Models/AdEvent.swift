import Foundation

enum AdEventType: String, Codable, Sendable, Equatable {
    case impression
    case click
}

/// A single impression or click queued for `POST /api/v1/events`.
struct AdEvent: Sendable, Equatable {
    let eventId: UUID
    let type: AdEventType
    let campaignId: Int
    let occurredAt: Date
    let deviceId: String
    let sessionId: String
    let userId: String?
    let locale: String?
    let ctaValue: String?
    let sdkVersion: String

    private enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case type
        case campaignId = "campaign_id"
        case occurredAt = "occurred_at"
        case deviceId = "device_id"
        case sessionId = "session_id"
        case userId = "user_id"
        case locale
        case ctaValue = "cta_value"
        case sdkVersion = "sdk_version"
    }

    init(
        eventId: UUID = UUID(),
        type: AdEventType,
        campaignId: Int,
        occurredAt: Date = Date(),
        deviceId: String,
        sessionId: String,
        userId: String? = nil,
        locale: String? = nil,
        ctaValue: String? = nil,
        sdkVersion: String = BetterAdsSDK.version
    ) {
        self.eventId = eventId
        self.type = type
        self.campaignId = campaignId
        self.occurredAt = occurredAt
        self.deviceId = deviceId
        self.sessionId = sessionId
        self.userId = userId
        self.locale = locale
        self.ctaValue = ctaValue
        self.sdkVersion = sdkVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventIdString = try container.decode(String.self, forKey: .eventId)
        guard let parsedEventId = UUID(uuidString: eventIdString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .eventId,
                in: container,
                debugDescription: "Invalid UUID"
            )
        }
        eventId = parsedEventId
        type = try container.decode(AdEventType.self, forKey: .type)
        campaignId = try container.decode(Int.self, forKey: .campaignId)
        let occurredAtString = try container.decode(String.self, forKey: .occurredAt)
        guard let parsedDate = AdEventFormatters.iso8601.date(from: occurredAtString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .occurredAt,
                in: container,
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        occurredAt = parsedDate
        deviceId = try container.decode(String.self, forKey: .deviceId)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        locale = try container.decodeIfPresent(String.self, forKey: .locale)
        ctaValue = try container.decodeIfPresent(String.self, forKey: .ctaValue)
        sdkVersion = try container.decodeIfPresent(String.self, forKey: .sdkVersion) ?? BetterAdsSDK.version
    }
}

extension AdEvent: Decodable {}
extension AdEvent: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventId.uuidString.lowercased(), forKey: .eventId)
        try container.encode(type, forKey: .type)
        try container.encode(campaignId, forKey: .campaignId)
        try container.encode(
            AdEventFormatters.iso8601.string(from: occurredAt),
            forKey: .occurredAt
        )
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(locale, forKey: .locale)
        try container.encodeIfPresent(ctaValue, forKey: .ctaValue)
        try container.encodeIfPresent(sdkVersion, forKey: .sdkVersion)
    }
}

enum AdEventFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension AdModel {
    /// Parses Serve `campaignId` for analytics. Returns `nil` when not a positive integer.
    var campaignIdAsInt: Int? {
        guard let value = Int(campaignId.trimmingCharacters(in: .whitespacesAndNewlines)),
              value > 0
        else {
            return nil
        }
        return value
    }
}
