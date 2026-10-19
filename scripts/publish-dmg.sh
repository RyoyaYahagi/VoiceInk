#!/usr/bin/env bash
set -euo pipefail

# Builds (unless --skip-build), packages, and publishes a DMG to this fork's
# GitHub Releases. Never touches tags or branches other than the current one.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO="${VOICEINK_RELEASE_REPO:-RyoyaYahagi/VoiceInk}"
OUTPUT_DIR="${VOICEINK_DMG_OUTPUT:-$HOME/Downloads/VoiceInk-dmg}"
APP_PATH="${VOICEINK_APP_PATH:-$HOME/Downloads/VoiceInk.app}"
SKIP_BUILD=0
NOTES_PATH=""

usage() {
    cat <<'USAGE'
Usage: scripts/publish-dmg.sh [options]

Builds the local fork app, packages VoiceInk.dmg, and creates a GitHub release.

Options:
  --skip-build     Use the existing ~/Downloads/VoiceInk.app instead of building.
  --app <path>     Use a specific VoiceInk.app.
  --notes <file>   Use custom release notes instead of generated ones.
  --repo <owner/repo>  Publish to another repository (default RyoyaYahagi/VoiceInk).
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=1; shift ;;
        --app) APP_PATH="$2"; shift 2 ;;
        --notes) NOTES_PATH="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

cd "$REPO_ROOT"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    make local
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app not found: $APP_PATH (build with make local)" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
COMMIT=$(git rev-parse --short HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
TAG="${VOICEINK_RELEASE_TAG_PREFIX:-koeink}-v${VERSION}-${BUILD}-$(date '+%Y%m%d-%H%M%S')"

DMG_PATH=$("$SCRIPT_DIR/package-dmg.sh" "$APP_PATH" "$OUTPUT_DIR" | tail -n 1)

NOTES_FILE=""
if [[ -n "$NOTES_PATH" ]]; then
    NOTES_FILE="$NOTES_PATH"
else
    NOTES_FILE=$(mktemp "${TMPDIR:-/tmp}/voiceink-notes.XXXXXX")
    trap 'rm -f "$NOTES_FILE"' EXIT
    cat > "$NOTES_FILE" <<NOTES
## KoeInk fork build $VERSION ($BUILD)

自分用フォーク（\`$BRANCH\` @ \`$COMMIT\`）のローカルビルドです。

### インストール
1. \`VoiceInk.dmg\` をダウンロードして開く
2. \`VoiceInk.app\` を \`/Applications\` にドラッグ
3. 初回起動は右クリック →「開く」。それでも開かない場合は
   \`xattr -cr /Applications/VoiceInk.app\`

### 注意
- 署名は Apple Development のため未公証。ほかの Mac では Gatekeeper に止められる場合があります。
  Developer ID 証明書（Account Holder が Xcode で作成）があれば公証済みにできます。
- 自動更新は無効です。更新は新しいリリースを入れ直してください。
- 辞書は iCloud（\`iCloud.com.ryoyayahagi.KoeInk\`）で Mac と iOS の間で同期します。
- データの保存先は \`~/Library/Application Support/com.ryoyayahagi.VoiceInk\` です。

### SHA-256
\`\`\`
$(cat "$OUTPUT_DIR/SHA256SUMS")
\`\`\`
NOTES
fi

gh release create "$TAG" \
    --repo "$REPO" \
    --target "$(git rev-parse HEAD)" \
    --title "KoeInk $VERSION ($BUILD)" \
    --notes-file "$NOTES_FILE" \
    --latest \
    "$DMG_PATH" "$OUTPUT_DIR/VoiceInk.dmg" "$OUTPUT_DIR/SHA256SUMS"

echo ""
echo "Published: https://github.com/$REPO/releases/tag/$TAG"
echo "Direct download: https://github.com/$REPO/releases/latest/download/VoiceInk.dmg"
