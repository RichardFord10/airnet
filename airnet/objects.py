from __future__ import annotations

import hashlib
import json
import time
from cryptography.exceptions import InvalidSignature

MAX_POST_LENGTH = 280
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
    if not isinstance(body, str) or not 1 <= len(body.strip()) <= MAX_POST_LENGTH:
        raise ValueError("body must contain 1–280 characters")
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
    try:
        if not isinstance(envelope, dict) or set(envelope) != {"id", "payload", "signature"}:
            return False
        payload = envelope["payload"]
        if not isinstance(payload, dict) or set(payload) != {"type", "author", "timestamp", "body"}:
            return False
        if payload["type"] != "post" or type(payload["timestamp"]) is not int or payload["timestamp"] < 0:
            return False
        body = payload["body"]
        if not isinstance(body, str) or not 1 <= len(body) <= MAX_POST_LENGTH or body != body.strip():
            return False
        author, signature = payload["author"], envelope["signature"]
        if not isinstance(author, str) or len(author) != 64 or not isinstance(signature, str) or len(signature) != 128:
            return False
        if envelope["id"] != object_id(payload):
            return False
        public_key = Ed25519PublicKey.from_public_bytes(bytes.fromhex(author))
        public_key.verify(bytes.fromhex(signature), canonical_bytes(payload))
        return True
    except (ValueError, TypeError, KeyError, InvalidSignature, UnicodeError):
        return False
