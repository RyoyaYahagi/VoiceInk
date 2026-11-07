#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/voiceink-web-focus.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -module-cache-path "$TEMP/module-cache" -parse-as-library \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnWebFocusResolver.swift" \
    "$ROOT/Tests/AutoLearnWebFocusTests.swift" -o "$TEMP/tests"
"$TEMP/tests"
