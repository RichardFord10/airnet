from __future__ import annotations

import json
import sqlite3
from pathlib import Path

DEFAULT_DB_PATH = Path("airnet.db")


class Database:
    def __init__(self, path: Path = DEFAULT_DB_PATH):
        self.conn = sqlite3.connect(path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS objects (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                author TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                payload TEXT NOT NULL,
                signature TEXT NOT NULL
            )
        """)
        self.conn.commit()

    def save(self, envelope: dict) -> None:
        payload = envelope["payload"]
        self.conn.execute(
            """
            INSERT OR IGNORE INTO objects
            (id, type, author, timestamp, payload, signature)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                envelope["id"],
                payload["type"],
                payload["author"],
                payload["timestamp"],
                json.dumps(payload),
                envelope["signature"],
            ),
        )
        self.conn.commit()

    def posts(self) -> list[dict]:
        rows = self.conn.execute(
            """
            SELECT id, payload, signature
            FROM objects
            WHERE type = 'post'
            ORDER BY timestamp DESC
            """
        ).fetchall()

        return [
            {
                "id": row["id"],
                "payload": json.loads(row["payload"]),
                "signature": row["signature"],
            }
            for row in rows
        ]
