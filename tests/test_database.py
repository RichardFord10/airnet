from airnet.database import Database
from airnet.identity import create_identity
from airnet.objects import create_post


def test_post_round_trip(tmp_path):
    identity = create_identity(tmp_path / "identity.json")
    db = Database(tmp_path / "airnet.db")

    envelope = create_post(
        "hello database",
        identity["public_key"],
        identity["private_key"],
    )

    db.save(envelope)
    posts = db.posts()

    assert len(posts) == 1
    assert posts[0]["payload"]["body"] == "hello database"
