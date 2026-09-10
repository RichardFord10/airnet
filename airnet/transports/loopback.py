from __future__ import annotations

from queue import Queue
from .base import Transport


class LoopbackTransport(Transport):
    def __init__(self):
        self.queue: Queue[bytes] = Queue()

    def send(self, data: bytes) -> None:
        self.queue.put(data)

    def receive(self) -> bytes | None:
        if self.queue.empty():
            return None
        return self.queue.get_nowait()
