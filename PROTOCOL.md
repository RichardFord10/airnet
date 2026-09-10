# airnet protocol draft v0.1

## object model

airnet objects are canonical json documents.

a post contains:

```json
{
  "type": "post",
  "author": "<hex ed25519 public key>",
  "timestamp": 0,
  "body": "hello airnet"
}
```

the canonical payload is serialized using sorted json keys and compact separators.

the object id is:

```text
sha256(canonical_payload)
```

the signature is:

```text
ed25519_sign(private_key, canonical_payload)
```

an envelope transmitted between nodes contains:

```json
{
  "id": "<sha256>",
  "payload": { "...": "..." },
  "signature": "<hex signature>"
}
```

## synchronization

initial synchronization vocabulary:

```text
HAVE <object_id>
WANT <object_id>
OBJECT <json-envelope>
```

The local simulator exchanges UTF-8 JSON messages:

```json
{"kind":"HAVE","value":"<object_id>"}
{"kind":"WANT","value":"<object_id>"}
{"kind":"OBJECT","value":{"id":"<sha256>","payload":{},"signature":"<hex>"}}
```

HAVE advertises one stored ID. A node broadcasts WANT if it lacks that ID;
any neighbor holding the object can answer with OBJECT. Nodes verify the entire
post before saving it and advertise newly received objects to their neighbors.
Existing IDs are not saved or advertised again on receipt. Periodic inventories
(every five simulator ticks) recover dropped transmissions and disconnected peers.
The transport broadcasts only to currently connected neighbors. This supports
multi-hop synchronization without persistent routes or a central object store.
The prior raw-envelope wire format is replaced by these typed messages.

Post bodies must contain 1–280 characters after trimming. Only the exact post
schema above is accepted; timestamps are nonnegative integer Unix seconds.
The canonical serializer uses UTF-8 with `ensure_ascii=False`. Incoming sync
messages larger than 8192 bytes are rejected. These limits are prototype limits,
not a claim that a JSON envelope fits a radio packet.

This is a small-network correctness prototype: periodic full inventory scans and
broadcast responses are not bandwidth-efficient. RF framing, fragmentation,
reassembly, backoff and airtime budgets remain to be implemented. Posts with the
same author, body and timestamp have the same ID and collapse into one object.

## transport contract

a transport only needs to:

```python
send(data: bytes)
receive() -> bytes | None
```

this allows the social/object layer to remain independent from:

- loopback
- tcp simulation
- lora
- meshtastic
- wifi mesh
- hf gateways
- satellite gateways
