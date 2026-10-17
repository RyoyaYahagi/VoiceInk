#!/bin/bash
# Offline integration tests with synthetic speech; no API keys/network required.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRAMEWORK="${WHISPER_FRAMEWORK_DIR:-$HOME/VoiceInk-Dependencies/whisper.cpp/build-apple/whisper.xcframework/macos-arm64_x86_64}"
TEMP="$(mktemp -d /tmp/voiceink-speech-gate.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
APP="$TEMP/VoiceInkGateTests.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/VoiceInk/Resources/models/ggml-silero-v5.1.2.bin" "$APP/Contents/Resources/"
say -o "$TEMP/speech.wav" --file-format=WAVE --data-format=LEI16@16000 --channels=1 \
    'This is a short speech detection test. Please preserve the beginning and ending of these words.'
swiftc -parse-as-library -O -F "$FRAMEWORK" -framework whisper \
    -Xlinker -rpath -Xlinker "$FRAMEWORK" \
    "$ROOT/VoiceInk/Features/Recording/Streaming/RecordingSpeechGate.swift" \
    "$ROOT/Tests/RecordingSpeechGateTests.swift" \
    -o "$APP/Contents/MacOS/gate-tests"
"$APP/Contents/MacOS/gate-tests" "$TEMP/speech.wav"
