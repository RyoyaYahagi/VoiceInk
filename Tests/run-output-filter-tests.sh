#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/voiceink-output-filter.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -module-cache-path "$TEMP/module-cache" -parse-as-library \
    "$ROOT/VoiceInk/Features/Recording/Processing/TranscriptionOutputFilter.swift" \
    "$ROOT/Tests/TranscriptionOutputFilterTests.swift" -o "$TEMP/tests"
"$TEMP/tests"
