"""Run three persistent local nodes on a controllable A—B—C mesh."""
from __future__ import annotations

import argparse
from pathlib import Path
from threading import Event, RLock, Thread
from flask import jsonify, request
from werkzeug.serving import make_server

from .app import create_app
from .database import Database
from .identity import load_or_create_identity
from .sync import SyncEngine
from .transports.simulated import SimulatedNetwork


class Simulator:
    names = ("node-a", "node-b", "node-c")

    def __init__(self, data_dir):
        self.lock = RLock()
        self.network = SimulatedNetwork()
        self.nodes = {}
        for name in self.names:
            path = Path(data_dir) / name
            path.mkdir(parents=True, exist_ok=True)
            db = Database(path / "airnet.db")
            identity = load_or_create_identity(path / "identity.json")
            sync = SyncEngine(db, self.network.attach(name))
            self.nodes[name] = (db, identity, sync)
        self.network.set_link("node-a", "node-b", True)
        self.network.set_link("node-b", "node-c", True)
        self.ticks = 0

    def tick(self):
        with self.lock:
            if self.ticks % 5 == 0:
                for _, _, sync in self.nodes.values():
                    sync.announce()
            # Bounded work per tick prevents a busy node monopolizing the scheduler.
            for _ in range(100):
                consumed = [sync.poll_once() for _, _, sync in self.nodes.values()]
                if not any(consumed):
                    break
            self.ticks += 1

    def state(self):
        with self.lock:
            return {
                "nodes": [{"name": name, "posts": len(db.posts()), "rejected": sync.rejected}
                          for name, (db, _, sync) in self.nodes.items()],
                "links": [{"a": a, "b": b, "enabled": (a, b) in self.network.links}
                          for a, b in (("node-a", "node-b"), ("node-b", "node-c"), ("node-a", "node-c"))],
                "delivered": self.network.delivered,
                "ticks": self.ticks,
            }

    def app(self, name, base_port=8080):
        db, identity, sync = self.nodes[name]
        app = create_app(database=db, identity=identity, sync=sync, lock=self.lock)

        @app.get("/api/network")
        def network_state():
            state = self.state()
            state.update(current=name, base_port=base_port)
            return jsonify(state)

        @app.post("/api/network/links")
        def update_link():
            data = request.get_json(silent=True)
            if not isinstance(data, dict) or type(data.get("enabled")) is not bool:
                return jsonify(error="enabled must be a boolean"), 400
            try:
                with self.lock:
                    self.network.set_link(data.get("a"), data.get("b"), data["enabled"])
            except (ValueError, TypeError):
                return jsonify(error="choose two different known nodes"), 400
            return jsonify(self.state())

        return app

    def close(self):
        for db, _, _ in self.nodes.values():
            db.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=Path(".airnet-sim"))
    parser.add_argument("--base-port", type=int, default=8080)
    args = parser.parse_args()
    if not 1 <= args.base_port <= 65533:
        parser.error("base port must be between 1 and 65533")
    sim = Simulator(args.data_dir)
    stop = Event()
    servers, threads = [], []
    try:
        for offset, name in enumerate(sim.names):
            port = args.base_port + offset
            server = make_server("127.0.0.1", port, sim.app(name, args.base_port), threaded=True)
            servers.append(server)
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            threads.append(thread)
            print(f"{name}: http://127.0.0.1:{port}", flush=True)
        print("Mesh: node-a — node-b — node-c. Ctrl+C to stop; posts and identities persist.", flush=True)
        while not stop.wait(1):
            sim.tick()
    except KeyboardInterrupt:
        pass
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        for thread in threads:
            thread.join()
        sim.close()


if __name__ == "__main__":
    main()
