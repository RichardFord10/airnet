import CSQLite
import Foundation

public struct StoredPost: Identifiable {
    public var id: String { envelope.id }
    public let envelope: Envelope
    public let queued: Bool
}

/// The database and outbox share one row, so a saved local post cannot lose its queued state.
public final class PostStore {
    private var db: OpaquePointer?
    private let lock = NSLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            if db != nil { sqlite3_close(db) }
            db = nil
            throw AirnetError.storage("Cannot open the database.")
        }
        do {
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=FULL")
            try execute("""
                CREATE TABLE IF NOT EXISTS posts (
                    id TEXT PRIMARY KEY, timestamp INTEGER NOT NULL,
                    envelope BLOB NOT NULL, queued INTEGER NOT NULL CHECK(queued IN (0,1))
                )
                """)
        } catch {
            sqlite3_close(db)
            db = nil
            throw error
        }
    }

    deinit { sqlite3_close(db) }

    private func failure() -> AirnetError {
        .storage(db.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed.")
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        return statement
    }

    public func save(_ envelope: Envelope, queued: Bool) throws {
        guard envelope.verify() else { throw AirnetError.invalidEnvelope }
        let bytes = try envelope.encoded()
        lock.lock(); defer { lock.unlock() }
        let statement = try prepare("INSERT OR IGNORE INTO posts (id,timestamp,envelope,queued) VALUES (?,?,?,?)")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, envelope.id, -1, transient)
        sqlite3_bind_int64(statement, 2, envelope.payload.timestamp)
        _ = bytes.withUnsafeBytes { sqlite3_bind_blob(statement, 3, $0.baseAddress, Int32(bytes.count), transient) }
        sqlite3_bind_int(statement, 4, queued ? 1 : 0)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    public func posts() throws -> [StoredPost] {
        lock.lock(); defer { lock.unlock() }
        let statement = try prepare("SELECT envelope,queued FROM posts ORDER BY timestamp DESC,id ASC")
        defer { sqlite3_finalize(statement) }
        var result: [StoredPost] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else { throw failure() }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
            result.append(StoredPost(envelope: try Envelope.decode(data), queued: sqlite3_column_int(statement, 1) == 1))
        }
        return result
    }

    public func markHandedOff(_ id: String) throws {
        lock.lock(); defer { lock.unlock() }
        let statement = try prepare("UPDATE posts SET queued=0 WHERE id=?")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, id, -1, transient)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }
}
