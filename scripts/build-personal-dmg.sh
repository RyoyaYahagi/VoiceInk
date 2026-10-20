#!/usr/bin/env bash
set -euo pipefail

# Builds a Developer ID-signed, notarized DMG for personal distribution.
# Requires a "Developer ID Application" certificate and an App Store Connect
# API key for notarytool. Nothing is uploaded anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEAM_ID="${VOICEINK_TEAM_ID:-2L6CD9CNHL}"
IDENTITY="${VOICEINK_DEVELOPER_IDENTITY:-Developer ID Application}"
NOTARY_KEY="${VOICEINK_NOTARY_KEY:-$HOME/.appstoreconnect/private_keys/AuthKey_LLRH4T7R7B.p8}"
NOTARY_KEY_ID="${VOICEINK_NOTARY_KEY_ID:-LLRH4T7R7B}"
NOTARY_ISSUER="${VOICEINK_NOTARY_ISSUER:-c6745991-34e1-4ed6-b003-9f975ae1fdac}"
OUTPUT_DIR="${VOICEINK_DMG_OUTPUT:-$HOME/Downloads/VoiceInk-dmg}"
SKIP_NOTARIZATION=0

usage() {
    cat <<'USAGE'
Usage: scripts/build-personal-dmg.sh [options]

Builds, signs with Developer ID, packages, and notarizes a DMG for personal use.

Options:
  --skip-notarization   Sign and package only (no Apple submission).
  --output <dir>        Output directory (default ~/Downloads/VoiceInk-dmg).
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-notarization) SKIP_NOTARIZATION=1; shift ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

cd "$REPO_ROOT"

if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    cat >&2 <<'MESSAGE'
error: "Developer ID Application" 証明書がありません。

Xcode → Settings → Accounts → チームを選ぶ → Manage Certificates → 「+」→
Developer ID Application で作成してから、もう一度実行してください。
MESSAGE
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
ARCHIVE="$OUTPUT_DIR/VoiceInk.xcarchive"
DERIVED="$OUTPUT_DIR/dd"
EXPORT_DIR="$OUTPUT_DIR/export"
rm -rf "$ARCHIVE" "$DERIVED" "$EXPORT_DIR"

echo "Archiving VoiceInk..."
xcodebuild archive \
    -project VoiceInk.xcodeproj \
    -scheme VoiceInk \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -derivedDataPath "$DERIVED" \
    -xcconfig LocalBuild.xcconfig \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LOCAL_BUILD' \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    | grep -E "error:|warning: .*sign|ARCHIVE (SUCCEEDED|FAILED)" || true

if [[ ! -d "$ARCHIVE" ]]; then
    echo "error: archive failed" >&2
    exit 1
fi

cat > "$OUTPUT_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>iCloudContainerEnvironment</key>
    <string>Production</string>
</dict>
</plist>
PLIST

echo "Exporting with Developer ID..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$OUTPUT_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates

APP="$EXPORT_DIR/VoiceInk.app"
if [[ ! -d "$APP" ]]; then
    echo "error: exported app not found" >&2
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Packaging DMG..."
DMG=$(VOICEINK_DMG_SIGN_IDENTITY="$IDENTITY" "$SCRIPT_DIR/package-dmg.sh" "$APP" "$OUTPUT_DIR" | tail -n 1)

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
    echo "Submitting for notarization..."
    SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG" \
        --key "$NOTARY_KEY" \
        --key-id "$NOTARY_KEY_ID" \
        --issuer "$NOTARY_ISSUER" 2>&1)
    echo "$SUBMIT_OUTPUT"
    SUBMISSION_ID=$(printf '%s\n' "$SUBMIT_OUTPUT" | awk '/^[[:space:]]*id: /{print $2; exit}')
    if [[ -z "$SUBMISSION_ID" ]]; then
        echo "error: could not read the notarization submission id" >&2
        exit 1
    fi

    # --wait can time out on a slow connection even though Apple keeps processing,
    # so poll the submission instead of failing the whole build.
    while true; do
        INFO=$(xcrun notarytool info "$SUBMISSION_ID" \
            --key "$NOTARY_KEY" \
            --key-id "$NOTARY_KEY_ID" \
            --issuer "$NOTARY_ISSUER" 2>&1)
        STATUS=$(printf '%s\n' "$INFO" | awk '/status: /{print $2; exit}')
        echo "notarization status: ${STATUS:-unknown} ($SUBMISSION_ID)"
        case "$STATUS" in
            Accepted) break ;;
            Invalid|Rejected)
                echo "$INFO" >&2
                xcrun notarytool log "$SUBMISSION_ID" \
                    --key "$NOTARY_KEY" \
                    --key-id "$NOTARY_KEY_ID" \
                    --issuer "$NOTARY_ISSUER" >&2 || true
                exit 1
                ;;
        esac
        sleep 20
    done

    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl -a -t open --context context:primary-signature -v "$DMG"
fi

# Stapling changes the file, so record the final checksums afterwards.
VERSIONED=$(basename "$DMG")
rm -f "$OUTPUT_DIR/VoiceInk.dmg"
cp "$DMG" "$OUTPUT_DIR/VoiceInk.dmg"
(cd "$OUTPUT_DIR" && shasum -a 256 "$VERSIONED" VoiceInk.dmg > SHA256SUMS)

echo ""
echo "Done: $OUTPUT_DIR/VoiceInk.dmg"
cat "$OUTPUT_DIR/SHA256SUMS"
