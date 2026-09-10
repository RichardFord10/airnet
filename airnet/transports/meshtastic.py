from __future__ import annotations

from .base import Transport


class MeshtasticTransport(Transport):
    """
    placeholder for the first RF transport.

    expected direction:
      airnet bytes
        -> compact framing/chunking
        -> meshtastic python api
        -> lora radio

    install later:
        pip install meshtastic
    """

    def __init__(self, *args, **kwargs):
        raise NotImplementedError(
            "meshtastic transport will be enabled once RF hardware is available"
        )

    def send(self, data: bytes) -> None:
        raise NotImplementedError

    def receive(self) -> bytes | None:
        raise NotImplementedError
