from airnet.identity import create_identity
from airnet.objects import create_post, verify_envelope


def test_signed_post_verifies(tmp_path):
    identity = create_identity(tmp_path / "identity.json")

    envelope = create_post(
        "hello airnet",
        identity["public_key"],
        identity["private_key"],
    )

    assert verify_envelope(envelope)


def test_modified_post_fails_verification(tmp_path):
    identity = create_identity(tmp_path / "identity.json")

    envelope = create_post(
        "hello airnet",
        identity["public_key"],
        identity["private_key"],
    )

    envelope["payload"]["body"] = "tampered"

    assert not verify_envelope(envelope)


def test_malformed_envelopes_are_rejected():
    for envelope in (None, [], {}, {"payload": {}}, {"id": "x", "payload": [], "signature": "x"}):
        assert not verify_envelope(envelope)


def test_invalid_author_is_rejected(tmp_path):
    from airnet.objects import object_id
    identity = create_identity(tmp_path / "identity.json")
    envelope = create_post("hello", identity["public_key"], identity["private_key"])
    envelope["payload"]["author"] = "z" * 64
    envelope["id"] = object_id(envelope["payload"])
    assert not verify_envelope(envelope)
