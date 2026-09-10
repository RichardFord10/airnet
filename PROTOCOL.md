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

v0.1 does not implement routing or deduplication across radios yet.
those belong in the transport and sync layers.

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
