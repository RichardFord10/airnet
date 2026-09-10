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
pip install -e .
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
