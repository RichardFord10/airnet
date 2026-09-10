#!/bin/bash
# No Xcode test runner needed. Dependencies: Apple Swift compiler/SDK and Python dev environment.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/airnet-core.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
swift_compiler="${AIRNET_SWIFTC:-$(xcrun --find swiftc)}"
sdk_path="${AIRNET_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
python_runner="${AIRNET_PYTHON:-$repo_dir/.venv/bin/python}"
common=(-sdk "$sdk_path" -module-cache-path "$check_dir/cache" -I mobile/AirnetCore/Sources/CSQLite)
"$swift_compiler" "${common[@]}" -emit-library -emit-module -module-name AirnetCore \
  mobile/AirnetCore/Sources/AirnetCore/*.swift \
  -o "$check_dir/libAirnetCore.dylib" -emit-module-path "$check_dir/AirnetCore.swiftmodule"
"$swift_compiler" "${common[@]}" -I "$check_dir" -L "$check_dir" -lAirnetCore \
  -Xlinker -rpath -Xlinker "$check_dir" scripts/verify_swift_core.swift -o "$check_dir/check"
"$check_dir/check" protocol/fixtures/posts-v1.json "$check_dir/swift-posts.json"
"$python_runner" - "$check_dir/swift-posts.json" <<'PY'
import json
import sys
from airnet.objects import verify_envelope
with open(sys.argv[1]) as source:
    posts = json.load(source)
assert len(posts) == 5
assert all(verify_envelope(post) for post in posts)
print('PASS: Python verifies all 5 Swift-signed post vectors')
PY
