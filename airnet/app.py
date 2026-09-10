from __future__ import annotations

from pathlib import Path
from threading import RLock
from flask import Flask, jsonify, request, send_from_directory

from .database import Database
from .identity import load_or_create_identity
from .objects import create_post
from .sync import SyncEngine
from .transports.loopback import LoopbackTransport

STATIC_DIR = Path(__file__).resolve().parent / "static"


def create_app(data_dir=Path("."), *, database=None, identity=None, sync=None, lock=None):
    app = Flask(__name__, static_folder=None)
    app.config["MAX_CONTENT_LENGTH"] = 8192
    data_dir = Path(data_dir)
    data_dir.mkdir(parents=True, exist_ok=True)
    db = database if database is not None else Database(data_dir / "airnet.db")
    identity = identity if identity is not None else load_or_create_identity(data_dir / "identity.json")
    sync = sync if sync is not None else SyncEngine(db, LoopbackTransport())
    lock = lock if lock is not None else RLock()
    app.extensions.update(airnet_db=db, airnet_sync=sync)

    @app.get("/")
    def index():
        return send_from_directory(STATIC_DIR, "index.html")

    @app.get("/<any(app.js,styles.css):filename>")
    def asset(filename):
        return send_from_directory(STATIC_DIR, filename)

    @app.get("/api/identity")
    def get_identity():
        return jsonify({"public_key": identity["public_key"]})

    @app.get("/api/posts")
    def get_posts():
        with lock:
            return jsonify(db.posts())

    @app.post("/api/posts")
    def make_post():
        data = request.get_json(silent=True)
        if not isinstance(data, dict):
            return jsonify(error="a JSON object is required"), 400
        try:
            envelope = create_post(data.get("body"), identity["public_key"], identity["private_key"])
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        with lock:
            sync.publish(envelope)
            # Drain the local loopback; simulated nodes are serviced by their scheduler.
            if isinstance(sync.transport, LoopbackTransport):
                while sync.poll_once():
                    pass
        return jsonify(envelope), 201

    return app


if __name__ == "__main__":
    create_app().run(host="127.0.0.1", port=8080)
