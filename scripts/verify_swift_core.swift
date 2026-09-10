// Compiler-only integration check for hosts where Xcode/XCTest cannot launch.
import AirnetCore
import Foundation

func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw AirnetError.storage("CHECK FAILED: \(message)") }
}

let fixturesURL = URL(fileURLWithPath: CommandLine.arguments[1])
let root = try JSONSerialization.jsonObject(with: Data(contentsOf: fixturesURL)) as! [String: Any]
let identity = try Identity(rawRepresentation: Data(hex: root["private_key"] as! String)!)
let vectors = root["vectors"] as! [[String: Any]]
var swiftEnvelopes: [Envelope] = []
for vector in vectors {
    let envelope = try Envelope.decode(JSONSerialization.data(withJSONObject: vector["envelope"]!))
    try require(envelope.payload.canonicalBytes.hex == vector["canonical_utf8_hex"] as! String, "canonical bytes")
    let signed = try identity.createPost(envelope.payload.body, timestamp: envelope.payload.timestamp)
    try require(signed.id == envelope.id, "ID: \(vector["name"]!)")
    try require(signed.payload.canonicalBytes == envelope.payload.canonicalBytes, "payload: \(vector["name"]!)")
    try require(signed.verify(), "Swift signature verifies")
    swiftEnvelopes.append(signed)
}
try JSONEncoder().encode(swiftEnvelopes).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("PASS: \(vectors.count) Python/Swift canonical byte, ID, and signature vectors")

let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: dir) }
let url = dir.appendingPathComponent("posts.sqlite")
let post = try identity.createPost("saved offline")
do {
    let store = try PostStore(url: url)
    try store.save(post, queued: true)
    try store.save(post, queued: false)
}
let reopened = try PostStore(url: url)
let rows = try reopened.posts()
try require(rows.count == 1 && rows[0].envelope == post && rows[0].queued, "reopen and duplicate suppression")
print("PASS: SQLite reopen preserves post and pending-send state")

final class TestLink: ObjectTransport {
    var offline = true
    var messages: [Data] = []
    func send(_ message: Data) throws {
        if offline { throw AirnetError.storage("Test link offline") }
        messages.append(message)
    }
    func receive() throws -> Data? { messages.isEmpty ? nil : messages.removeFirst() }
}
let link = TestLink()
var failed = false
do { try ObjectTransfer.flushOutbox(reopened, through: link) } catch { failed = true }
try require(failed && reopened.posts()[0].queued, "failed send retains outbox")
link.offline = false
try ObjectTransfer.flushOutbox(reopened, through: link)
try require(!reopened.posts()[0].queued, "handoff updates outbox")
let peer = try PostStore(url: dir.appendingPathComponent("peer.sqlite"))
link.messages += link.messages
try require(ObjectTransfer.receiveOne(into: peer, from: link), "first receive")
try require(ObjectTransfer.receiveOne(into: peer, from: link), "duplicate receive")
try require(peer.posts().map(\.envelope) == [post], "peer deduplication")
print("PASS: failed send, retry, OBJECT transfer, and peer deduplication")

for body in ["", " \n", String(repeating: "📻", count: 281), String(repeating: "e\u{0301}", count: 141)] {
    var rejected = false
    do { _ = try identity.createPost(body) } catch { rejected = true }
    try require(rejected, "invalid body rejected")
}
var tampered = try JSONSerialization.jsonObject(with: post.encoded()) as! [String: Any]
var payload = tampered["payload"] as! [String: Any]
payload["body"] = "changed"
tampered["payload"] = payload
var rejected = false
do { _ = try Envelope.decode(JSONSerialization.data(withJSONObject: tampered)) } catch { rejected = true }
try require(rejected, "tampered signature rejected")
try require(identity.createPost("\u{001C}hello\u{0085}").payload.body == "hello", "Python whitespace")
print("PASS: input validation, tamper rejection, and Python whitespace compatibility")
