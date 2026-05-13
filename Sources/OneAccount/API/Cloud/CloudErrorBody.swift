import Foundation

public struct CloudErrorBody: Codable, Sendable, Equatable {
    public let code: Int?
    public let description: String?
    public let key: String?
    public let message: String?
    public let values: OtpErrorValue?

    enum CodingKeys: String, CodingKey {
        case code
        case description
        case key
        case message
        case values
    }

    public init(
        code: Int? = nil,
        description: String? = nil,
        key: String? = nil,
        message: String? = nil,
        values: OtpErrorValue? = nil
    ) {
        self.code = code
        self.description = description
        self.key = key
        self.message = message
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.values = try container.decodeIfPresent(OtpErrorValue.self, forKey: .values)
        if let intCode = try? container.decodeIfPresent(Int.self, forKey: .code) {
            self.code = intCode
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .code), let v = Int(str) {
            self.code = v
        } else {
            self.code = nil
        }
    }
}
