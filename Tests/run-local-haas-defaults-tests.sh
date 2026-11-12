#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/voiceink-haas-defaults.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -module-cache-path "$TEMP/module-cache" -parse-as-library \
    "$ROOT/VoiceInk/Features/ModelLibrary/Models/TranscriptionModel.swift" \
    "$ROOT/VoiceInk/App/Configuration/LocalHaasSettings.swift" \
    "$ROOT/VoiceInk/Infrastructure/Providers/Transcription/Cloud/OpenAICompatibleTranscriptionService.swift" \
    "$ROOT/Tests/LocalHaasDefaultsTests.swift" -o "$TEMP/tests"
if [[ "${1:-}" == "--live" ]]; then
    say -v Kyoko -o "$TEMP/ja.wav" --file-format=WAVE --data-format=LEI16@16000 --channels=1 \
        'これは日本語の音声入力のテストです。明日の会議は午前十時に始まります。'
    "$TEMP/tests" "$TEMP/ja.wav"
else
    "$TEMP/tests"
fi
