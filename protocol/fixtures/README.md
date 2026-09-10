# Cross-platform protocol fixtures

`posts-v1.json` contains a deliberately public Ed25519 test key and signed post
vectors. Never use this key for a real identity. These fixtures are the shared
compatibility contract for Python, Swift, and a future Android implementation.

For each vector, an implementation must:

1. Serialize the payload to bytes exactly matching `canonical_utf8_hex`.
2. Hash those bytes to obtain the envelope ID.
3. Verify the signature using the payload's author key.
4. Sign the same payload with the test key and verify the new signature in the
   other implementation. Signature bytes need not match: CryptoKit deliberately
   randomizes Ed25519 signing. The canonical payload bytes and object IDs must match.
   See [Apple’s signing documentation](https://developer.apple.com/documentation/cryptokit/curve25519/signing/privatekey/signature(for:)).

The vectors exercise UTF-8, combining marks, emoji, control-character escaping,
slashes, Unicode line separators, and a 280-code-point body. Whitespace trimming
matches Python `str.strip`; the length limit counts Unicode code points, not UTF-16
units or grapheme clusters. No Unicode normalization is applied.
