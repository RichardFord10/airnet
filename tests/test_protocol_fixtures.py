import json
from pathlib import Path

from airnet.objects import canonical_bytes, verify_envelope


def test_shared_mobile_protocol_fixtures():
    fixtures = json.loads((Path(__file__).resolve().parents[1] / 'protocol/fixtures/posts-v1.json').read_text())
    for vector in fixtures['vectors']:
        assert verify_envelope(vector['envelope']), vector['name']
        assert canonical_bytes(vector['envelope']['payload']).hex() == vector['canonical_utf8_hex']
