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
