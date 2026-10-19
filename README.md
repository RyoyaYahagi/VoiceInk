<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>VoiceInk</h1>
  <p>Voice to text app for macOS to transcribe what you say to text almost instantly</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2015.0%2B-brightgreen)
  [![GitHub release (latest by date)](https://img.shields.io/github/v/release/Beingpax/VoiceInk)](https://github.com/Beingpax/VoiceInk/releases)
  ![GitHub all releases](https://img.shields.io/github/downloads/Beingpax/VoiceInk/total)
  ![GitHub stars](https://img.shields.io/github/stars/Beingpax/VoiceInk?style=social)
  <p>
    <a href="https://tryvoiceink.com">Website</a> •
    <a href="https://www.youtube.com/@tryvoiceink">YouTube</a>
  </p>

  <a href="https://tryvoiceink.com">
    <img src="https://img.shields.io/badge/Download%20Now-Latest%20Version-blue?style=for-the-badge&logo=apple" alt="Download VoiceInk" width="250"/>
  </a>
</div>

---

VoiceInk is a native macOS application that transcribes what you say to text almost instantly. You can find all the information and download the app from [here](https://tryvoiceink.com). 

![VoiceInk Mac App](https://github.com/user-attachments/assets/12367379-83e7-48a6-b52c-4488a6a04bba)

After dedicating the past 5 months to developing this app, I've decided to open source it for the greater good. 

My goal is to make it **the most efficient and privacy-focused voice-to-text solution for macOS** that is a joy to use. While the source code is now open for experienced developers to build and contribute, purchasing a license helps support continued development and gives you access to automatic updates, priority support, and upcoming features.

## Features

- 🎙️ **Accurate Transcription**: Local AI models that transcribe your voice to text with 99% accuracy, almost instantly
- 🔒 **Privacy First**: 100% offline processing ensures your data never leaves your device
- ⚡ **Modes**: Intelligent app detection automatically applies your perfect pre-configured settings based on the app/ URL you're on
- 🧠 **Context Aware**: Smart AI that understands your screen content and adapts to the context
- 🎯 **Global Shortcuts**: Configurable keyboard or mouse shortcuts for quick recording and push-to-talk functionality
- 📝 **Personal Dictionary**: Train the AI to understand your unique terminology with custom words, industry terms, and smart text replacements
- 🔄 **Smart Modes**: Instantly switch between AI-powered modes optimized for different writing styles and contexts
- 🤖 **AI Assistant**: Built-in voice assistant mode for a quick chatGPT like conversational assistant

## Get Started

### Download
Get the latest version with a free trial from [tryvoiceink.com](https://tryvoiceink.com). Your purchase helps me work on VoiceInk full-time and continuously improve it with new features and updates.

#### Homebrew
Alternatively, you can install VoiceInk via `brew`:

```shell
brew install --cask voiceink
```

### Build from Source
As an open-source project, you can build VoiceInk yourself by following the instructions in [BUILDING.md](BUILDING.md). However, the compiled version includes additional benefits like automatic updates, priority support via Discord and email, and helps fund ongoing development.

## このフォークのビルドをダウンロードする（日本語）

自分用フォークのビルドは GitHub Releases に置いてある。ビルドしなくても、ダウンロードして
`/Applications` に入れるだけで使える。

- 最新版（常にこの URL）: https://github.com/RyoyaYahagi/VoiceInk/releases/latest/download/VoiceInk.dmg
- 過去のビルド一覧: https://github.com/RyoyaYahagi/VoiceInk/releases

初回起動では Gatekeeper の確認が出るので、`VoiceInk.app` を右クリック →「開く」。
それでも開かないときは `xattr -cr /Applications/VoiceInk.app`。Developer ID で公証して
いないため、この確認は避けられない。加えて、いまのリリースは Apple Development 署名なので、
署名に含まれる端末以外の Mac では起動できないことがある。Developer ID 証明書を Xcode で
作成すれば、`scripts/publish-dmg.sh` のまま公証済みの DMG を配れる。

DMG の作成と公開は次のコマンドで行う（`make local` を含むので約 8 分）:

```shell
make publish-dmg                          # ビルド → DMG → gh release create
./scripts/publish-dmg.sh --skip-build     # ビルド済みの ~/Downloads/VoiceInk.app を使う
```

アップロードされるもの: `VoiceInk.dmg`（固定名）, `VoiceInk-<version>-<build>.dmg`,
`SHA256SUMS`。

## このフォークを使う場合のビルドと起動（日本語）

このフォーク（`RyoyaYahagi/VoiceInk`、ブランチ `local/mac-customizations`）は配布版と同じ
`make local` でビルドするが、**起動手順に 1 点だけ違いがある**: 成果物は `~/Downloads/VoiceInk.app`
に作られるので、ランチャー（Raycast など）やアクセシビリティ許可の管理で standard に扱うため
`/Applications` に置くこと。

### ビルドから起動まで

前提: Xcode（現在 Xcode 27 / Swift 6.4）、Homebrew が導入済みであること。初回は Metal
ツールチェーンが必要になる場合がある（`xcodebuild -downloadComponent MetalToolchain`）。

```shell
# 1. 依存物の確認（whisper.cpp の XCFramework が無ければ自動構築される）
make check

# 2. ローカルビルド（約 8 分。毎回フルビルドになる）
make local

# 3. 起動中の VoiceInk を終了してから、確実に新しい方を使わせる
osascript -e 'tell application "VoiceInk" to quit'
rm -rf /Applications/VoiceInk.app
ditto ~/Downloads/VoiceInk.app /Applications/VoiceInk.app
xattr -cr /Applications/VoiceInk.app   # 隔離属性の除去
open -a /Applications/VoiceInk.app
```

```shell
# この Mac 用の 1 コマンド版（上記の 2〜3 を自動化）
voiceink-rebuild           # ビルドしない場合は --skip-build
```

実装は `~/.local/bin/voiceink-rebuild`（このリポジトリには含まれない）。

### よく出る確認ダイアログ

- **キーチェーンの確認**（「VoiceInkがキーチェーン内の "`com.prakashjoshipax.VoiceInk.Local`"
  の…を使用しようとしています」）: ローカルビルドが API キーやライセンスキーを保存・読み出す
  ときに macOS が確認しているだけ。**「常に許可」か「許可」で問題ない**。ad-hoc 署名や別の
  署名に変えるたびに再確認を求められるが、安定した Apple Development 証明書（`make local`
  が自動で選ぶ）で署名されていれば再表示されない。
- **アクセシビリティ／マイクの許可**: 署名を変えてインストールし直すたびにやり直しが必要。
  安定した証明書を 1 つ使い続ければ再設定は不要。

### ローカルビルドの制約

- ライセンス判定は常に「購入済み」になる（`#if LOCAL_BUILD` のブロックによる）。
- 自動更新は無効。更新は新しいリリースを入れ直すか、`git pull` して再ビルドする。
- 辞書は iCloud コンテナ `iCloud.com.ryoyayahagi.KoeInk` で Mac と iOS の間で同期する。
- bundle id は `com.ryoyayahagi.VoiceInk` で配布版と別。データは
  `~/Library/Application Support/com.ryoyayahagi.VoiceInk/` に保存され、配布版
  （`com.prakashjoshipax.VoiceInk`）と共存する。消すと履歴・辞書・設定が失われる。
- API キーの保存先もローカルビルド専用のキーチェーン名前空間になる。配布版で入れた
  キーは引き継がれない。


## Requirements

- macOS 15.0 or later

## Documentation

- [Building from Source](BUILDING.md) - Detailed instructions for building the project
- [Contributing Guidelines](CONTRIBUTING.md) - How to contribute to VoiceInk
- [Code of Conduct](CODE_OF_CONDUCT.md) - Our community standards

## Contributing

This project is **not accepting pull requests** at this time. You're welcome to fork and modify VoiceInk for your own use.

You can still contribute by:
- Reporting bugs via [issues](https://github.com/Beingpax/VoiceInk/issues)
- Suggesting features or enhancements
- Improving documentation via issues

For more details, see our [Contributing Guidelines](CONTRIBUTING.md). For build instructions, see our [Building Guide](BUILDING.md).

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please:
1. Check the existing issues in the GitHub repository
2. Create a new issue if your problem isn't already reported
3. Provide as much detail as possible about your environment and the problem

## Acknowledgments

### Core Technology
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance inference of OpenAI's Whisper model
- [FluidAudio](https://github.com/FluidInference/FluidAudio) - Used for Parakeet model implementation
- [TranscribeCpp for Swift](https://github.com/Beingpax/Transcribe-cpp-swift) - SwiftPM distribution of [transcribe.cpp](https://github.com/handy-computer/transcribe.cpp), used for local GGUF transcription models
- [SenseVoice Small](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) by FunAudioLLM / Alibaba - Multilingual model available under the [FunASR Model Open Source License Agreement](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE)

### Essential Dependencies
- [Sparkle](https://github.com/sparkle-project/Sparkle) - Keeping VoiceInk up to date
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - User-customizable keyboard shortcuts
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Launch at login functionality
- [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter) - Media playback control during recording
- [Zip](https://github.com/marmelroy/Zip) - File compression and decompression utilities
- [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) - A modern macOS library for getting selected text
- [Swift Atomics](https://github.com/apple/swift-atomics) - Low-level atomic operations for thread-safe concurrent programming


---

Made with ❤️ by Pax
