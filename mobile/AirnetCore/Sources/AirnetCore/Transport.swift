import Foundation

/// Development transport boundary. Success means accepted by this transport, not delivered over RF.
/// A future radio sync engine must retain/reconcile inventory even after handoff.
public protocol ObjectTransport {
    func send(_ message: Data) throws
    func receive() throws -> Data?
}

public enum ObjectTransfer {
    public static func flushOutbox(_ store: PostStore, through transport: ObjectTransport) throws {
        for post in try store.posts() where post.queued {
            let envelope = try JSONSerialization.jsonObject(with: post.envelope.encoded())
            let message = try JSONSerialization.data(withJSONObject: ["kind": "OBJECT", "value": envelope])
            try transport.send(message)
            try store.markHandedOff(post.id)
        }
    }

    @discardableResult
    public static func receiveOne(into store: PostStore, from transport: ObjectTransport) throws -> Bool {
        guard let bytes = try transport.receive() else { return false }
        guard bytes.count <= 8192,
              let message = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              message["kind"] as? String == "OBJECT", let value = message["value"] else {
            throw AirnetError.invalidEnvelope
        }
        let envelope = try Envelope.decode(JSONSerialization.data(withJSONObject: value))
        try store.save(envelope, queued: false)
        return true
    }
}
