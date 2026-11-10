#!/usr/bin/env bash
set -euo pipefail

# Packages a built VoiceInk.app with its license and corresponding-source reference.
APP_PATH="${1:-${VOICEINK_APP_PATH:-$HOME/Downloads/VoiceInk.app}}"
OUTPUT_DIR="${2:-${VOICEINK_DMG_OUTPUT:-$HOME/Downloads/VoiceInk-dmg}}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app not found: $APP_PATH" >&2
    exit 1
fi

PLIST="$APP_PATH/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

mkdir -p "$OUTPUT_DIR"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/voiceink-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ditto "$APP_PATH" "$STAGE/VoiceInk.app"
cp "$REPO_ROOT/LICENSE" "$STAGE/LICENSE.txt"
COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD)
cat > "$STAGE/Source Code.txt" <<SOURCE
VoiceInk fork $VERSION ($BUILD)
Source: https://github.com/RyoyaYahagi/VoiceInk/tree/$COMMIT
Source archive: https://github.com/RyoyaYahagi/VoiceInk/archive/$COMMIT.tar.gz
License: GNU GPL version 3 (see LICENSE.txt).
HaaS/Horizon and cloud API keys are installed/configured separately; see README.md.
SOURCE
xattr -cr "$STAGE/VoiceInk.app"
ln -s /Applications "$STAGE/Applications"

VERSIONED="$OUTPUT_DIR/VoiceInk-$VERSION-$BUILD.dmg"
STABLE="$OUTPUT_DIR/VoiceInk.dmg"
rm -f "$VERSIONED" "$STABLE"

hdiutil create -quiet -volname "VoiceInk" -srcfolder "$STAGE" -ov -format UDZO "$VERSIONED"

if [[ -n "${VOICEINK_DMG_SIGN_IDENTITY:-}" ]]; then
    codesign --force --timestamp --sign "$VOICEINK_DMG_SIGN_IDENTITY" "$VERSIONED" >/dev/null
fi

# Stable filename for sharing the latest locally packaged build.
cp "$VERSIONED" "$STABLE"
(cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$VERSIONED")" "$(basename "$STABLE")" > SHA256SUMS)

echo "$VERSIONED"
