# airnet

airnet is an offline-first, radio-capable social network prototype.

the goal is to let phones and computers exchange signed social objects
(posts first, replies/votes later) without depending on the public internet.

## architecture

```text
browser / phone ui
        ↓
local airnet node
        ↓
sqlite + signed objects
        ↓
transport abstraction
   ├── loopback (dev)
   └── meshtastic / lora (later)
```

## current milestone

v0.1 runs completely locally:

- generate an ed25519 identity
- create signed posts
- verify signatures
- store objects in sqlite
- expose a small local http api
- render posts in a browser
- simulate radio delivery with a loopback transport

## setup

requires python 3.11+.

```bash
cd airnet
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
python -m airnet.app
```

open:

```text
http://127.0.0.1:8080
```

## run tests

```bash
pytest
```

## next hardware milestone

when the rf devices arrive:

```text
iphone
  ↓ bluetooth
lora node
  ↓ rf
lora node
  ↓ bluetooth
iphone
```

the first hardware transport target is meshtastic over usb/serial or bluetooth.

## design principles

- offline first
- local database first
- signed objects
- content-addressed ids
- eventual consistency
- transport-agnostic protocol
- no central server required
- tiny payloads suitable for low-bandwidth links

## hardware-free mesh simulator

The next milestone is now available: three independent identities and SQLite
stores, connected through an in-process A–B–C network. No internet connection
or RF devices are needed to run it after installing the dependencies.

```bash
source .venv/bin/activate
pip install -e ".[dev]"
python -m airnet.simulator
```

Open the three node feeds:

- node-a: http://127.0.0.1:8080
- node-b: http://127.0.0.1:8081
- node-c: http://127.0.0.1:8082

1. Post on node-a. It reaches node-c through node-b.
2. Uncheck the node-b ↔ node-c link in the simulator controls.
3. Post on node-c. It stays locally available while disconnected.
4. Reconnect the link. Missing posts synchronize within about five seconds
   for small demo feeds; the browser refreshes every 1.5 seconds.
5. Stop with Ctrl+C and restart. Posts and identities survive in `.airnet-sim/`.
   Link settings reset to A–B–C on each start.

Use `--base-port 8090` if 8080–8082 are occupied, or `--data-dir /tmp/airnet-demo`
for a separate set of node identities and databases. Stop the standalone app
before starting the simulator on its default ports.

The simulation models connectivity and multi-hop store-and-forward, with signed
object verification, duplicate suppression, and periodic HAVE/WANT reconciliation.
It uses complete messages in memory. It does **not** yet model airtime, random
packet loss, packet fragmentation, or actual radio limits. All three local HTTP
servers run in one process; they are not yet independent network peers.

## remaining roadmap

- Before hardware: packet framing and bounded reassembly, loss/latency simulation,
  retry/backoff and bandwidth budgets; replace full inventory scans for large feeds.
- Before hardware: replies and votes with validated parent references, identity
  backup/import, and feed pagination.
- With hardware: implement and verify a Meshtastic adapter, measure usable payload
  size and throughput, and exercise reconnects with two real devices.
- Phone milestone: build a phone-local database and UI plus Bluetooth transport.
  The current browser UI still requires a running Python node; it is not yet a
  standalone offline phone app.

Run the integration suite with `python -m pytest`. It covers multi-hop delivery,
partitions, live reconnection, restart recovery, cyclic links, malformed packets,
and the browser API.
