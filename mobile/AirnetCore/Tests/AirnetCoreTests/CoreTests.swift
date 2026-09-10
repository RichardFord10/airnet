import XCTest
@testable import AirnetCore

final class CoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    private func fixtures() throws -> [String: Any] {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        let bytes = try Data(contentsOf: root.appendingPathComponent("protocol/fixtures/posts-v1.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }

    func testPythonSignaturesCanonicalBytesAndSwiftSigningMatch() throws {
        let fixture = try fixtures()
        let identity = try Identity(rawRepresentation: XCTUnwrap(Data(hex: fixture["private_key"] as! String)))
        for vector in fixture["vectors"] as! [[String: Any]] {
            let bytes = try JSONSerialization.data(withJSONObject: vector["envelope"]!)
            let envelope = try Envelope.decode(bytes)
            XCTAssertTrue(envelope.verify(), vector["name"] as! String)
            XCTAssertEqual(envelope.payload.canonicalBytes.hex, vector["canonical_utf8_hex"] as? String)
            let signed = try identity.createPost(envelope.payload.body, timestamp: envelope.payload.timestamp)
            XCTAssertEqual(signed.id, envelope.id)
            XCTAssertEqual(signed.payload.canonicalBytes, envelope.payload.canonicalBytes)
            XCTAssertTrue(signed.verify()) // CryptoKit uses randomized, valid Ed25519 signatures.
        }
    }

    func testUnicodeLimitsAndPythonWhitespace() throws {
        let identity = Identity()
        XCTAssertNoThrow(try identity.createPost(String(repeating: "📻", count: 280)))
        XCTAssertThrowsError(try identity.createPost(String(repeating: "📻", count: 281)))
        XCTAssertThrowsError(try identity.createPost(String(repeating: "e\u{0301}", count: 141)))
        XCTAssertEqual(try identity.createPost("\u{001C}hello\u{0085}").payload.body, "hello")
        XCTAssertThrowsError(try identity.createPost(" \n\t"))
    }

    func testRejectTamperingMalformedSchemaAndBooleanTimestamp() throws {
        let post = try Identity().createPost("hello", timestamp: 123)
        let root = try JSONSerialization.jsonObject(with: post.encoded()) as! [String: Any]
        for field in ["body", "author", "timestamp"] {
            var changed = root
            var payload = changed["payload"] as! [String: Any]
            payload[field] = field == "timestamp" ? true : "tampered"
            changed["payload"] = payload
            XCTAssertThrowsError(try Envelope.decode(JSONSerialization.data(withJSONObject: changed)))
        }
        var extra = root; extra["unexpected"] = true
        XCTAssertThrowsError(try Envelope.decode(JSONSerialization.data(withJSONObject: extra)))
        XCTAssertThrowsError(try Envelope.decode(Data("[]".utf8)))
        XCTAssertThrowsError(try Envelope.decode(Data(repeating: 0, count: 8193)))
    }

    func testDatabaseReopenPreservesPostAndOutbox() throws {
        let url = try temporaryDirectory().appendingPathComponent("posts.sqlite")
        let post = try Identity().createPost("saved with airplane mode on")
        do {
            let store = try PostStore(url: url)
            try store.save(post, queued: true)
            try store.save(post, queued: false) // Receiving our own post must not clear the outbox.
        }
        let reopened = try PostStore(url: url)
        let rows = try reopened.posts()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.envelope, post)
        XCTAssertEqual(rows.first?.queued, true)
    }

    func testFailedSendKeepsOutboxThenSimulatedTransferDeduplicates() throws {
        let dir = try temporaryDirectory()
        let a = try PostStore(url: dir.appendingPathComponent("a.sqlite"))
        let b = try PostStore(url: dir.appendingPathComponent("b.sqlite"))
        let post = try Identity().createPost("hello simulated phone")
        try a.save(post, queued: true)
        let transport = TestTransport()
        transport.disconnected = true
        XCTAssertThrowsError(try ObjectTransfer.flushOutbox(a, through: transport))
        XCTAssertTrue(try XCTUnwrap(a.posts().first).queued)
        transport.disconnected = false
        try ObjectTransfer.flushOutbox(a, through: transport)
        XCTAssertFalse(try XCTUnwrap(a.posts().first).queued)
        transport.messages.append(contentsOf: transport.messages)
        XCTAssertTrue(try ObjectTransfer.receiveOne(into: b, from: transport))
        XCTAssertTrue(try ObjectTransfer.receiveOne(into: b, from: transport))
        XCTAssertFalse(try ObjectTransfer.receiveOne(into: b, from: transport))
        XCTAssertEqual(try b.posts().map(\.envelope), [post])
    }
}

private final class TestTransport: ObjectTransport {
    var messages: [Data] = []
    var disconnected = false
    func send(_ message: Data) throws {
        if disconnected { throw AirnetError.storage("Test link disconnected") }
        messages.append(message)
    }
    func receive() throws -> Data? { messages.isEmpty ? nil : messages.removeFirst() }
}
