from __future__ import annotations

import json
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

DEFAULT_IDENTITY_PATH = Path("identity.json")


def create_identity(path: Path = DEFAULT_IDENTITY_PATH) -> dict[str, str]:
    private_key = Ed25519PrivateKey.generate()
    public_key = private_key.public_key()

    private_raw = private_key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption(),
    )

    public_raw = public_key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )

    data = {
        "private_key": private_raw.hex(),
        "public_key": public_raw.hex(),
    }

    path.write_text(json.dumps(data, indent=2))
    return data


def load_or_create_identity(path: Path = DEFAULT_IDENTITY_PATH) -> dict[str, str]:
    if path.exists():
        return json.loads(path.read_text())
    return create_identity(path)
