#!/bin/bash
# Offline tests against production storage/recovery code. Fakes replace cloud/model calls.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/voiceink-reliability.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -parse-as-library -O \
    "$ROOT/VoiceInk/Features/Recording/Workflows/TranscriptionReliability.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/Workflows/DictionaryArchive.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/Workflows/DictionaryBackupArchiveWriter.swift" \
    "$ROOT/Tests/ReliabilityStorageTests.swift" -o "$TEMP/storage-tests"
"$TEMP/storage-tests"
swiftc -parse-as-library -O \
    "$ROOT/VoiceInk/Features/Recording/Workflows/TranscriptionServiceRegistry.swift" \
    "$ROOT/Tests/RecordingRecoveryTests.swift" -o "$TEMP/recovery-tests"
"$TEMP/recovery-tests"
