from __future__ import annotations

import hashlib
import json
import time
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)


def canonical_bytes(payload: dict) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def object_id(payload: dict) -> str:
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def create_post(body: str, public_key_hex: str, private_key_hex: str) -> dict:
    payload = {
        "type": "post",
        "author": public_key_hex,
        "timestamp": int(time.time()),
        "body": body.strip(),
    }

    raw = canonical_bytes(payload)
    private_key = Ed25519PrivateKey.from_private_bytes(bytes.fromhex(private_key_hex))
    signature = private_key.sign(raw).hex()

    return {
        "id": object_id(payload),
        "payload": payload,
        "signature": signature,
    }


def verify_envelope(envelope: dict) -> bool:
    payload = envelope["payload"]

    if envelope["id"] != object_id(payload):
        return False

    public_key = Ed25519PublicKey.from_public_bytes(
        bytes.fromhex(payload["author"])
    )

    try:
        public_key.verify(
            bytes.fromhex(envelope["signature"]),
            canonical_bytes(payload),
        )
        return True
    except Exception:
        return False
