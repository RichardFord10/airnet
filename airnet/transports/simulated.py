"""In-process links: disconnected transmissions are lost, never secretly queued."""
from collections import deque
from .base import Transport


class SimulatedNetwork:
    def __init__(self):
        self.transports = {}
        self.links = set()
        self.delivered = 0

    def attach(self, name):
        transport = SimulatedTransport(self, name)
        self.transports[name] = transport
        return transport

    def set_link(self, a, b, enabled):
        if a == b or a not in self.transports or b not in self.transports:
            raise ValueError("unknown node or self link")
        link = tuple(sorted((a, b)))
        if enabled:
            self.links.add(link)
        else:
            self.links.discard(link)


class SimulatedTransport(Transport):
    def __init__(self, network, name):
        self.network = network
        self.name = name
        self.queue = deque()

    def send(self, data):
        for a, b in sorted(self.network.links):
            if self.name in (a, b):
                peer = b if self.name == a else a
                self.network.transports[peer].queue.append(data)
                self.network.delivered += 1

    def receive(self):
        return self.queue.popleft() if self.queue else None
