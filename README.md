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

## フォーク独自の変更一覧（日本語）

このリポジトリは `Beingpax/VoiceInk` を元にした `RyoyaYahagi/VoiceInk`。
カスタマイズの統合先はこのフォークの `main`。上のダウンロード先・Homebrew・リリースバッジは
フォーク元の配布版を指し、以下の変更を含むビルドの入手先ではない。

以下はフォーク元との共通祖先以降に追加した変更の一覧。コミット番号は実装を確認するための参照。

| 変更 | 動作・利用条件 | 実装コミット |
| --- | --- | --- |
| 日本語のフィラー除去 | 「えーと」「あのー」などを既定候補に追加し、空白のない日本語でも除去できるようにした。保存済みの独自リストは維持する。 | `7b34b4bb` |
| ローカル音声検出 | Silero VAD で発話を検出する。リアルタイム送信では発話前後の余白を残し、無音だけの送信を抑制する。 | `ac5db988` |
| 通信障害時の復旧 | クラウド文字起こしが失敗した場合、導入済みの Whisper モデルで Mac 内で再処理する。設定で無効化・モデル指定が可能。モデル未導入時は元のエラーを表示し、自動ダウンロードや別クラウドへの転送はしない。 | `466a2a85` |
| 辞書の自動バックアップ | 既定で起動時と5分ごとに変更を確認し、JSONを保存して最新30世代を保持する。既定の保存先はアプリのデータフォルダ内の `DictionaryBackups`。設定で保存先を変更でき、復元は辞書設定の Import から行う。 | `187e3d1b` |
| Web入力欄での自動学習 | Web入力欄の取得・貼り付け範囲の復元、送信後に空になる欄、WebKitの隠れた欄、日本語の差分抽出、製品名・短いAIモデル名の審査を改善した。詳細は次節。 | `1ed58056`, `5e51e1b0`, `0736c200`, `195fa9e8`, `c3178d64` |
| 手動の修正登録 | 自動取得できない入力欄で手動登録を案内する。辞書設定から置換登録を開けるほか、履歴の元テキストを使って修正を登録できる。 | `98e2dd35`, `12984c9e` |
| 自動学習の統計 | アプリ別の取得・候補生成などの状況と、AI審査の利用量を記録する。入力欄ごとの学習状況を確認するために使う。 | `12984c9e` |
| 利用量と推定料金 | 文字起こしの処理先別に回数・録音時間・失敗・中止を月別（UTC）で記録する。AI補正と自動学習の審査も別に集計し、組み込み単価と文字数などから推定料金を表示する。実請求やサービス側の残枠とは一致しない。料金表示の文字色も調整した。 | `466a2a85`, `12984c9e`, `fc1dfdce` |
| iCloud辞書同期 | ローカルビルドで `iCloud.com.ryoyayahagi.KoeInk` を使ってMacとiOSの辞書を同期する。CloudKitの取り込み完了後に重複エントリを整理する。対応する署名・権限・iCloudアカウントが必要。 | `5c8b1302`, `6e03f810` |
| フォークのデータ分離 | bundle id・データ保存先・キーチェーンを配布版から分離し、フォーク元の自動更新を無効化した。詳細は後述のローカルビルドの制約を参照。 | `8a4f2b31`, `5c8b1302` |
| ビルド・個人配布 | ローカルビルドと起動手順、DMG作成を追加した。GitHubリリース公開用の構成を経て、現在はDeveloper ID署名・Apple公証を行う個人配布用DMGを作る。公証は状態をポーリングして待つ。 | `9e3d6aef`, `b1a0903f`, `6ec2663b`, `3a1b3941` |
| README整備 | データ保存先・iCloud・起動手順・Auto Learnの変更と利用条件を記載した。 | `805b6277`, `b3008b95` |

音声認識の実行先、AI補正、自動学習の審査、iCloud同期はそれぞれ独立した設定・通信経路になる。
上の「100% offline」はローカル処理を選んだ場合の説明であり、クラウド機能を使う場合には当てはまらない。

## このフォークの Auto Learn 修正（日本語）

以下はこのフォークの `main` に統合する Auto Learn の変更。
AI審査による候補の却下や応答形式エラー、入力欄の取得失敗は起こり得るため、
修正操作が必ず登録につながるわけではない。

- **送信時に空になる入力欄**: T3 Code などの Chromium / Electron のチャット欄で、
  送信後に入力欄が空になっても、最後に取得できた空でない内容から修正を検出する。
  値の変更通知でも読み直し、貼り付け直後に本文を取得できない場合は短時間再試行する。
- **WebKit の入力欄**: フォーカスされた Web 領域の選択位置から編集可能な親要素を探し、
  通常の子要素一覧に現れない入力欄にも対応する。ページ全体の本文は探索しない。
- **日本語文中の修正**: ひらがな・カタカナ・漢字・英数字の境界で差分を分け、
  空白のない日本語の文全体ではなく、修正された語の周辺を候補として扱う。
- **製品名・AI モデル名の表記**: 日本語音声認識で誤認識した公開製品名や、短い AI モデル名の
  カナ表記を対応する英字識別子へ直した場合、AI 審査で置換のみの登録対象にできる。
  一般的な役割名、名前の断片、大文字・小文字だけの変更は引き続き対象外とする。
- **審査の待ち時間**: Auto Learn の AI 審査には専用の 45 秒のタイムアウトを使う。

辞書設定の **Auto-Learn Dictionary** を有効にし、利用可能な AI プロバイダーとモデルを
設定する。入力欄の読み取りには macOS のアクセシビリティ許可が必要。
AI 審査を使うため、音声認識をローカルで実行していても、クラウドの審査プロバイダーを
選んだ場合は修正候補のテキストがそのサービスへ送信される。
入力欄のアクセシビリティ対応状況によっては修正を取得できないことがあり、
すべてのアプリでの動作を保証するものではない。

差分抽出と WebKit のフォーカス解決は、次の単体テストで確認できる。
これらは実際のアプリでの入力操作や AI 審査結果を検証するテストではない。

```shell
bash Tests/run-auto-learn-correction-diff-tests.sh
bash Tests/run-auto-learn-web-focus-tests.sh
```

## この Mac の HaaS-ja / Horizon 構成（日本語）

以下はアプリ内蔵の機能ではなく、この Mac に別途配置したローカルサービス。
このリポジトリの clone や `make local` だけでは導入されない。

処理経路は VoiceInk のカスタム文字起こし接続先 → 8081 の互換プロキシ →
8080 の HaaS-ja 音声認識で、認識結果を返す際にプロキシが Horizon で句読点を補完する。
カスタム接続先には `http://127.0.0.1:8081/v1/audio/transcriptions` を使う。
この Mac の保存済み設定では表示名・リクエストのモデル名ともに `Haas-ja-v1.0` を使っている。
サーバーの起動時モデル識別子 `haas-ja-v1.0:q4_k` とは区別する。

| 構成要素 | この Mac での配置・役割 |
| --- | --- |
| HaaS-ja / speech.cpp | `~/.local/bin/speech serve haas-ja-v1.0:q4_k --port 8080` で日本語を文字起こしする。 |
| 互換プロキシ | `~/.local/share/speech-proxy/proxy-horizon.py`。VoiceInkが送る `temperature` を取り除いて8080へ中継する。 |
| Horizon | プロキシの `horizon-venv` と `horizon-model` に配置したPython環境・ローカルONNXモデルで句読点を補完する。補完失敗時は認識結果をそのまま返す。 |
| 自動起動 | `~/Library/LaunchAgents/com.yappa.speech-haas.plist` と `com.yappa.speech-proxy.plist` がサービスを起動する。 |
| ログ | `~/Library/Logs/speech-haas.log` と `speech-proxy.log`。 |

`GET http://127.0.0.1:8081/_voiceink/health` の `punctuation` で補完モデルの準備状態を確認できる。
文字起こし応答の `X-VoiceInk-Punctuation` ヘッダーでも補完の適用状況を確認できる。
この確認はプロキシの状態確認であり、音声認識の精度やVoiceInkからの接続成功を保証するものではない。

Horizonは `horizon_punctuation.py` を使い、`requirements.txt` のPython依存と
`tokenizer.json`・`config.json`・`onnx/model_quantized.onnx` を必要とする。
補完対象は成功した通常のJSON文字起こし応答の `text`（16,000文字以下）。
`segments` / `words` を含む応答、JSON以外、エラー応答は変更しない。
元の文字・空白・既存の句読点を保ち、句読点だけを追加する。

上記の実行ファイル、Pythonコード・環境、モデル、LaunchAgent、VoiceInkの接続設定は
このリポジトリに含まれない。別のMacで再現するには、これらを別途用意して設定する必要がある。
また、ローカル文字起こしを使っていても、AI補正やAuto Learnにクラウドを選んだ場合は
その処理のテキストが外部送信される。

## 個人配布用の DMG（日本語）

このフォークのビルドは GitHub では配布しない。Developer ID で署名し、Apple の公証を通した
DMG を個人的に配る。

必要なもの:

- Developer ID Application 証明書
  （Xcode → Settings → Accounts → チームを選ぶ → Manage Certificates → 「+」）
- App Store Connect API キー（`~/.appstoreconnect/private_keys/AuthKey_*.p8`）

```shell
make personal-dmg
```

`scripts/build-personal-dmg.sh` が archive → Developer ID で書き出し → DMG 作成 → 公証 →
staple まで行う。出力は `~/Downloads/VoiceInk-dmg/VoiceInk.dmg`。証明書がない場合は作成手順を
表示して止まる。公証を飛ばして署名と DMG だけ作る場合は `--skip-notarization`。

## このフォークを使う場合のビルドと起動（日本語）

このフォーク（`RyoyaYahagi/VoiceInk`）は配布版と同じ
`make local` でビルドするが、**起動手順に 1 点だけ違いがある**: 成果物は `~/Downloads/VoiceInk.app`
に作られるので、ランチャー（Raycast など）やアクセシビリティ許可の管理で standard に扱うため
`/Applications` に置くこと。

### ビルドから起動まで

前提: Xcode（この Mac の環境は Xcode 27 / Swift 6.4）、Homebrew が導入済みであること。
`make local` は Apple Development による自動署名が必須で、ad-hoc署名へのフォールバックはない。
`LocalBuild.xcconfig` の `DEVELOPMENT_TEAM` はこのフォークのチーム `2L6CD9CNHL` に固定されている。
別の開発者がビルドする場合は、自分のチーム・bundle id・iCloudコンテナと権限に合わせて
`LocalBuild.xcconfig` と `VoiceInk/VoiceInk.local.entitlements` を調整する。初回は Metal
ツールチェーンが必要になる場合がある（`xcodebuild -downloadComponent MetalToolchain`）。

```shell
# 1. 依存物の確認（whisper.cpp の XCFramework が無ければ自動構築される）
make check

# 2. ローカルビルド（約 8 分。毎回フルビルドになる）
make local

# 出力先を変える場合: make local APP_OUTPUT_DIR=/path/to/output
# 署名証明書を指定する場合: make local LOCAL_CODESIGN_IDENTITY="Apple Development: ..."

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
この補助スクリプトのソース参照先は `/Users/yappa/code/app/voiceink`、成果物の参照先は
`~/Downloads/VoiceInk.app` に固定されている。別のMacや出力先で使う場合は調整が必要。
既存アプリをDMGにまとめるだけなら `make package-dmg` を使える（ビルド・署名は行わない）。

### よく出る確認ダイアログ

- **キーチェーンの確認**（「VoiceInkがキーチェーン内の "`com.prakashjoshipax.VoiceInk.Local`"
  の…を使用しようとしています」）: ローカルビルドが API キーやライセンスキーを保存・読み出す
  ときに macOS が確認しているだけ。**「常に許可」か「許可」で問題ない**。ad-hoc 署名や別の
  署名に変えるたびに再確認を求められるが、安定した Apple Development 証明書（`make local`
  が指定する）を使い続けることで、再確認を抑えられる。
- **アクセシビリティ／マイクの許可**: 署名を変えてインストールし直すたびにやり直しが必要。
  安定した証明書を 1 つ使い続ければ再設定は不要。

### ローカルビルドの制約

- ライセンス判定は常に「購入済み」になる（`#if LOCAL_BUILD` のブロックによる）。
- 自動更新は無効。更新は新しいリリースを入れ直すか、`git pull` して再ビルドする。
- 辞書は iCloud コンテナ `iCloud.com.ryoyayahagi.KoeInk` で Mac と iOS の間で同期する。
- bundle id は `com.ryoyayahagi.VoiceInk` で配布版と別。データは
  `~/Library/Application Support/com.ryoyayahagi.VoiceInk/` に保存され、配布版
  （`com.prakashjoshipax.VoiceInk`）と共存する。消すと履歴・辞書・設定が失われる。
- 初回起動時に旧bundle id `com.prakashjoshipax.VoiceInk` の設定を、現在の設定にないキーだけ
  コピーする。履歴DB・辞書DB・モデルファイルをコピーする処理ではない。
- データ分離には Whisper / TranscribeCpp / Refine のモデル保存先も含む。RefineのXPCサービスも
  ローカルビルドでは専用bundle idを使う。Debugビルドでは辞書のCloudKit同期を無効にする。
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
