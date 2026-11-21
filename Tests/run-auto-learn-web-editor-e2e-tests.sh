#!/bin/bash
# Runs Auto Learn against real WKWebView editors (the engine Muse uses).
# Needs Accessibility permission for the terminal; briefly shows a test window.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/voiceink-web-editor-e2e.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -module-cache-path "$TEMP/module-cache" -parse-as-library \
    "$ROOT/VoiceInk/Infrastructure/SystemIntegration/Accessibility/AccessibilityFocusReader.swift" \
    "$ROOT/VoiceInk/Infrastructure/SystemIntegration/Accessibility/AccessibilityTextReader.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnWebFocusResolver.swift" \
    "$ROOT/VoiceInk/App/Configuration/AutoLearnSettings.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/Workflows/WordReplacementVariants.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnLocalReviewer.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnReviewEligibility.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnTypes.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/AutoLearnAXRuntime.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/FinalSnapshotDiffEngine.swift" \
    "$ROOT/VoiceInk/Features/Dictionary/AutoLearn/CorrectionDiffEngine.swift" \
    "$ROOT/Tests/AutoLearnWebEditorE2ETests.swift" -o "$TEMP/tests"
"$TEMP/tests"
