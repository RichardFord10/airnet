import CoreFoundation
import CryptoKit
import Foundation

public enum AirnetError: LocalizedError {
    case invalidPost, invalidEnvelope, storage(String), keychain(Int32)
    public var errorDescription: String? {
        switch self {
        case .invalidPost: return "Write a post containing 1–280 Unicode code points."
        case .invalidEnvelope: return "This post has an invalid format or signature."
        case .storage(let message): return "Local storage: \(message)"
        case .keychain(let status): return "Cannot access your identity (Keychain \(status)). Unlock your device and try again."
        }
    }
}

extension Data {
    public var hex: String { map { String(format: "%02x", $0) }.joined() }
    public init?(hex: String) {
        guard hex.utf8.count % 2 == 0, hex.utf8.allSatisfy({
            (48...57).contains($0) || (97...102).contains($0) || (65...70).contains($0)
        }) else { return nil }
        var result = Data()
        let bytes = Array(hex.utf8)
        for i in stride(from: 0, to: bytes.count, by: 2) {
            guard let byte = UInt8(String(bytes: bytes[i...i+1], encoding: .utf8)!, radix: 16) else { return nil }
            result.append(byte)
        }
        self = result
    }
}

public enum PostText {
    // Python str.strip uses these Unicode whitespace code points, including U+001C–001F.
    private static let whitespace = CharacterSet(charactersIn:
        "\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{001C}\u{001D}\u{001E}\u{001F} " +
        "\u{0085}\u{00A0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}" +
        "\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}")
    public static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: whitespace) }
    public static func count(_ value: String) -> Int { value.unicodeScalars.count }
}

public struct PostPayload: Codable, Equatable {
    public let type: String
    public let author: String
    public let timestamp: Int64
    public let body: String

    // Explicit escaping matches Python's canonical JSON, independent of JSONEncoder defaults.
    private static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 34: result += "\\\""
            case 92: result += "\\\\"
            case 8: result += "\\b"
            case 9: result += "\\t"
            case 10: result += "\\n"
            case 12: result += "\\f"
            case 13: result += "\\r"
            case 0..<32: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    public var canonicalBytes: Data {
        Data("{\"author\":\(Self.quoted(author)),\"body\":\(Self.quoted(body)),\"timestamp\":\(timestamp),\"type\":\(Self.quoted(type))}".utf8)
    }
}

public struct Envelope: Codable, Equatable, Identifiable {
    public let id: String
    public let payload: PostPayload
    public let signature: String

    public func verify() -> Bool {
        guard payload.type == "post", payload.timestamp >= 0,
              (1...280).contains(PostText.count(payload.body)),
              payload.body == PostText.trimmed(payload.body),
              payload.author.utf8.count == 64, signature.utf8.count == 128,
              let author = Data(hex: payload.author), let signature = Data(hex: signature),
              id == Data(SHA256.hash(data: payload.canonicalBytes)).hex,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: author) else { return false }
        return key.isValidSignature(signature, for: payload.canonicalBytes)
    }

    public static func decode(_ data: Data) throws -> Envelope {
        guard data.count <= 8192,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == ["id", "payload", "signature"],
              let payload = root["payload"] as? [String: Any],
              Set(payload.keys) == ["type", "author", "timestamp", "body"],
              let time = payload["timestamp"] as? NSNumber,
              CFGetTypeID(time) != CFBooleanGetTypeID(),
              !["f", "d"].contains(String(cString: time.objCType)) else { throw AirnetError.invalidEnvelope }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.verify() else { throw AirnetError.invalidEnvelope }
        return envelope
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }
}

public struct Identity {
    private let key: Curve25519.Signing.PrivateKey
    public init() { key = Curve25519.Signing.PrivateKey() }
    public init(rawRepresentation: Data) throws { key = try Curve25519.Signing.PrivateKey(rawRepresentation: rawRepresentation) }
    public var rawRepresentation: Data { key.rawRepresentation }
    public var publicKey: String { key.publicKey.rawRepresentation.hex }

    public func createPost(_ text: String, timestamp: Int64 = Int64(Date().timeIntervalSince1970)) throws -> Envelope {
        let body = PostText.trimmed(text)
        guard (1...280).contains(PostText.count(body)), timestamp >= 0 else { throw AirnetError.invalidPost }
        let payload = PostPayload(type: "post", author: publicKey, timestamp: timestamp, body: body)
        return Envelope(id: Data(SHA256.hash(data: payload.canonicalBytes)).hex, payload: payload,
                        signature: try key.signature(for: payload.canonicalBytes).hex)
    }
}
