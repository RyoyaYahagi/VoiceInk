#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/voiceink-correction-diff.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -module-cache-path "$TEMP/module-cache" -parse-as-library \
    "$ROOT/VoiceInk/App/Configuration/AutoLearnSettings.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/Workflows/WordReplacementVariants.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnLocalReviewer.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnReviewEligibility.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnTypes.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/CorrectionDiffEngine.swift" \
    "$ROOT/Tests/AutoLearnCorrectionDiffTests.swift" -o "$TEMP/tests"
"$TEMP/tests"
