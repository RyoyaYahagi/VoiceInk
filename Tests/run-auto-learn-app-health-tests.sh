#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/voiceink-app-health.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -module-cache-path "$TEMP/module-cache" -parse-as-library \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnAppHealth.swift" \
    "$ROOT/Tests/AutoLearnAppHealthTests.swift" -o "$TEMP/tests"
"$TEMP/tests"
