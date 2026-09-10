import json

from airnet.simulator import Simulator
from airnet.objects import create_post


def publish(sim, name, body):
    _, identity, sync = sim.nodes[name]
    envelope = create_post(body, identity["public_key"], identity["private_key"])
    sync.publish(envelope)
    return envelope


def advance(sim, ticks=6):
    for _ in range(ticks):
        sim.tick()


def test_multi_hop_partition_reconnect_and_restart(tmp_path):
    sim = Simulator(tmp_path)
    first = publish(sim, "node-a", "hello across two hops")
    advance(sim)
    assert all(db.posts() == [first] for db, _, _ in sim.nodes.values())
    sim.network.set_link("node-b", "node-c", False)
    second = publish(sim, "node-c", "saved while isolated")
    advance(sim)
    assert sim.nodes["node-a"][0].get(second["id"]) is None
    identities = [identity for _, identity, _ in sim.nodes.values()]
    sim.close()
    sim = Simulator(tmp_path)  # Queues vanish, databases and identities survive.
    try:
        assert identities == [identity for _, identity, _ in sim.nodes.values()]
        advance(sim)
        assert all(len(db.posts()) == 2 for db, _, _ in sim.nodes.values())
        assert all(db.get(second["id"]) == second for db, _, _ in sim.nodes.values())
    finally:
        sim.close()


def test_live_reconnect_and_cycles_deduplicate(tmp_path):
    sim = Simulator(tmp_path)
    try:
        sim.network.set_link("node-b", "node-c", False)
        post = publish(sim, "node-a", "partition")
        advance(sim)
        assert sim.nodes["node-c"][0].posts() == []
        sim.network.set_link("node-b", "node-c", True)
        sim.network.set_link("node-a", "node-c", True)
        advance(sim, 12)
        assert all(db.posts() == [post] for db, _, _ in sim.nodes.values())
        assert all(not transport.queue for transport in sim.network.transports.values())
    finally:
        sim.close()


def test_bad_packets_do_not_block_valid_delivery(tmp_path):
    sim = Simulator(tmp_path)
    try:
        queue = sim.network.transports["node-b"].queue
        for packet in (b'no json', b'\xff', b'[]', b'{}', b'x' * 8193,
                       json.dumps({"kind": "OBJECT", "value": {"payload": {}}}).encode()):
            queue.append(packet)
        post = publish(sim, "node-a", "valid after garbage")
        advance(sim)
        assert sim.nodes["node-b"][2].rejected == 6
        assert sim.nodes["node-c"][0].get(post["id"]) == post
    finally:
        sim.close()


def test_browser_api_and_link_controls(tmp_path):
    sim = Simulator(tmp_path)
    try:
        a = sim.app("node-a").test_client()
        c = sim.app("node-c").test_client()
        assert b'type="module"' in a.get('/').data
        assert a.get('/app.js').status_code == 200
        assert a.get('/styles.css').status_code == 200
        for data in (None, [], {}, {"body": 123}, {"body": " "}, {"body": "x" * 281}):
            assert a.post('/api/posts', json=data).status_code == 400
        assert a.post('/api/network/links', json={"a": "node-b", "b": "node-c", "enabled": False}).status_code == 200
        response = a.post('/api/posts', json={"body": "hello browser"})
        assert response.status_code == 201
        advance(sim)
        assert c.get('/api/posts').json == []
        assert a.post('/api/network/links', json={"a": "node-b", "b": "node-c", "enabled": True}).status_code == 200
        advance(sim)
        assert c.get('/api/posts').json == [response.json]
        assert 'private_key' not in a.get('/api/identity').json
        assert a.post('/api/network/links', json={"enabled": "false"}).status_code == 400
    finally:
        sim.close()
