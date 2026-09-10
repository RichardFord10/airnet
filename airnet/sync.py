from __future__ import annotations

import json
from .objects import verify_envelope

MAX_MESSAGE_BYTES = 8192


class SyncEngine:
    def __init__(self, database, transport):
        self.database = database
        self.transport = transport
        self.rejected = 0

    def _send(self, kind, value):
        self.transport.send(json.dumps({"kind": kind, "value": value}).encode("utf-8"))

    def publish(self, envelope: dict) -> None:
        if not verify_envelope(envelope):
            raise ValueError("invalid envelope")
        self.database.save(envelope)
        self._send("OBJECT", envelope)

    def announce(self):
        # One ID per message keeps inventories bounded for the prototype.
        for envelope in self.database.posts():
            self._send("HAVE", envelope["id"])

    def poll_once(self) -> bool:
        raw = self.transport.receive()
        if raw is None:
            return False
        try:
            if len(raw) > MAX_MESSAGE_BYTES:
                raise ValueError("message too large")
            message = json.loads(raw)
            kind, value = message["kind"], message["value"]
            if kind in ("HAVE", "WANT"):
                if not isinstance(value, str) or len(value) != 64:
                    raise ValueError("invalid object id")
                int(value, 16)
                envelope = self.database.get(value)
                if kind == "HAVE" and envelope is None:
                    self._send("WANT", value)
                elif kind == "WANT" and envelope is not None:
                    self._send("OBJECT", envelope)
            elif kind == "OBJECT":
                if not verify_envelope(value):
                    raise ValueError("invalid envelope")
                if self.database.get(value["id"]) is None:
                    self.database.save(value)
                    self._send("HAVE", value["id"])
            else:
                raise ValueError("unknown message kind")
        except (ValueError, TypeError, KeyError, UnicodeError, RecursionError):
            self.rejected += 1
        return True  # A packet was consumed, including malformed packets.
