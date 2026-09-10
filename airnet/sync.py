from __future__ import annotations

import json
from .objects import verify_envelope


class SyncEngine:
    def __init__(self, database, transport):
        self.database = database
        self.transport = transport

    def publish(self, envelope: dict) -> None:
        if not verify_envelope(envelope):
            raise ValueError("invalid envelope")
        self.database.save(envelope)
        self.transport.send(json.dumps(envelope).encode("utf-8"))

    def poll_once(self) -> bool:
        raw = self.transport.receive()
        if raw is None:
            return False

        envelope = json.loads(raw.decode("utf-8"))
        if verify_envelope(envelope):
            self.database.save(envelope)
            return True

        return False
