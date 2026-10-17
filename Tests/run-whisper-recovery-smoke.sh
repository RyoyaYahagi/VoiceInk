#!/bin/bash
# Real local model test using synthetic Japanese speech; no API/network calls.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL="${1:-$HOME/Library/Application Support/com.prakashjoshipax.VoiceInk/WhisperModels/ggml-base.bin}"
FRAMEWORK="${WHISPER_FRAMEWORK_DIR:-$HOME/VoiceInk-Dependencies/whisper.cpp/build-apple/whisper.xcframework/macos-arm64_x86_64}"
TEMP="$(mktemp -d /tmp/voiceink-whisper-smoke.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
APP="$TEMP/WhisperSmoke.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/VoiceInk/Resources/models/ggml-silero-v5.1.2.bin" "$APP/Contents/Resources/"
say -v Kyoko -o "$TEMP/ja.wav" --file-format=WAVE --data-format=LEI16@16000 --channels=1 \
    'これは日本語の音声入力のテストです。明日の会議は午前十時に始まります。'
swiftc -parse-as-library -O -F "$FRAMEWORK" -framework whisper \
    -Xlinker -rpath -Xlinker "$FRAMEWORK" \
    "$ROOT/VoiceInk/Infrastructure/Providers/Transcription/Whisper/LibWhisper.swift" \
    "$ROOT/VoiceInk/Infrastructure/Providers/Transcription/Whisper/VADModelManager.swift" \
    "$ROOT/Tests/WhisperRecoverySmokeTests.swift" -o "$APP/Contents/MacOS/smoke"
"$APP/Contents/MacOS/smoke" "$MODEL" "$TEMP/ja.wav"
