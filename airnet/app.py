from __future__ import annotations

from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory

from .database import Database
from .identity import load_or_create_identity
from .objects import create_post
from .sync import SyncEngine
from .transports.loopback import LoopbackTransport

BASE_DIR = Path(__file__).resolve().parent.parent
STATIC_DIR = BASE_DIR / "static"

app = Flask(__name__)
db = Database()
identity = load_or_create_identity()
transport = LoopbackTransport()
sync = SyncEngine(db, transport)


@app.get("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")


@app.get("/app.js")
def app_js():
    return send_from_directory(STATIC_DIR, "app.js")


@app.get("/styles.css")
def styles_css():
    return send_from_directory(STATIC_DIR, "styles.css")


@app.get("/api/identity")
def get_identity():
    return jsonify({"public_key": identity["public_key"]})


@app.get("/api/posts")
def get_posts():
    return jsonify(db.posts())


@app.post("/api/posts")
def make_post():
    body = (request.json or {}).get("body", "").strip()
    if not body:
        return jsonify({"error": "body is required"}), 400

    envelope = create_post(
        body=body,
        public_key_hex=identity["public_key"],
        private_key_hex=identity["private_key"],
    )

    sync.publish(envelope)
    return jsonify(envelope), 201


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080, debug=True)
