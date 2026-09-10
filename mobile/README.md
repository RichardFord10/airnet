# Mobile apps

Keep the first iOS app in this repository. Android can be added at
`mobile/android/` when development starts. Each native app owns its UI, database,
secure key storage, and OS integrations. They share the protocol specification and
language-neutral test vectors, not a dependency on the Python server or Swift UI.

```text
mobile/
  AirnetCore/              Swift package: signatures, SQLite, Keychain, transport boundary
  ios/Airnet.xcodeproj     Native iPhone/iPad app
  ios/Airnet/              SwiftUI feed, composer, identity screen
protocol/fixtures/         Public test vectors for Python, Swift, and future Kotlin
```

## Run on iPhone or simulator

Requires Xcode with the iOS SDK; the app targets iOS 17 or later. No third-party
Swift packages, backend, RF hardware, or internet connection are needed at runtime.

1. Open `mobile/ios/Airnet.xcodeproj` in Xcode.
2. Select the **Airnet** scheme and an iPhone simulator, then Run.
3. For a physical phone, select your development team under **Signing & Capabilities**
   and use a unique bundle identifier if required. Select your connected iPhone and Run.

The project deliberately does not contain a personal development team or signing
credentials. Xcode resolves `../AirnetCore` as a local package.

## Offline acceptance check

1. Launch the app once; it creates an Ed25519 identity in Keychain.
2. Turn Wi-Fi and cellular off on the phone.
3. Create a post. Confirm it appears as **Saved · waiting to share**.
4. Force-close the app and reopen it.
5. Confirm the same post, pending count, and public key are still present.
6. Try emoji, multiline posts, and a post over the 280-code-point limit.

Do not erase the app to simulate a restart: uninstalling can remove its database.
The signing key uses `WhenUnlockedThisDeviceOnly`; it is not synced to iCloud
Keychain or migrated to another phone. Backup/import is still a future milestone.
Keychain failures never silently generate a replacement identity.

## Tests

From the repository root, on a healthy Xcode installation:

```bash
swift test --package-path mobile/AirnetCore
python -m pytest
xcodebuild -project mobile/ios/Airnet.xcodeproj -scheme Airnet \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Swift tests compare exact canonical UTF-8 bytes and SHA-256 IDs and verify Ed25519
signatures against Python-generated fixtures. CryptoKit randomizes signatures, so
compatibility requires successful verification rather than equal signature bytes. They also cover SQLite reopening, duplicate
suppression, outbox retention after a failed send, and a simulated OBJECT transfer.
The fixture private key is intentionally public test data, never a user identity.

## Scope of this first app

Implemented: native offline UI, local signing and verification, device Keychain
identity, SQLite posts and durable outbox. The app does not connect to Python.

The core transport boundary can send/receive the protocol's OBJECT messages and
is exercised with a fake transport in tests. It is not wired to an active transport
in the UI. A transport accepting a message is not proof of peer or radio delivery.
Full HAVE/WANT reconciliation, a development bridge to the Python mesh, BLE,
packet fragmentation, and real-radio validation remain ahead. Posts stay queued
in this version. The feed currently loads all posts; pagination remains ahead.

For Android, implement the same canonical bytes and run the same fixtures in
Kotlin before adding synchronization. Swift counts Unicode scalars rather than
user-perceived characters to match Python's existing code-point limit. Neither
implementation normalizes Unicode text. Identical author/body/timestamp triples
are intentionally the same content-addressed post.

### Compiler-only integration check

`scripts/check_mobile_core.sh` compiles and runs a small integration check without
XCTest, then verifies Swift-generated signatures in Python. From the root:

```bash
bash scripts/check_mobile_core.sh
```

It defaults to the compiler/SDK selected by `xcrun` and `.venv/bin/python`.
`AIRNET_SWIFTC`, `AIRNET_SDK`, and `AIRNET_PYTHON` can select explicit installed tools.
For this development Mac's currently mismatched Xcode installation, the working
compiler-only command is:

```bash
AIRNET_SWIFTC=/Library/Developer/CommandLineTools/usr/bin/swiftc \
AIRNET_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
bash scripts/check_mobile_core.sh
```

This check does not exercise the device Keychain, SwiftUI runtime, or iOS lifecycle.
The host's Xcode launcher/XCTest runtime currently fail with a missing
`_XPCTypeBool` symbol in CoreDevice/Mercury; a compatible Xcode/macOS installation
is required to complete the simulator/device acceptance check. The core and app
sources have passed direct compiler checks against the installed iOS Simulator SDK.
