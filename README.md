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

このリポジトリは上流の VoiceInk を元にしたフォーク。
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
| iCloud辞書同期 | 設定したiCloudコンテナを使ってMacとiOSの辞書を同期する。CloudKitの取り込み完了後に重複エントリを整理する。対応する署名・権限・iCloudアカウントが必要。 | `5c8b1302`, `6e03f810` |
| フォークのデータ分離 | bundle id・データ保存先・キーチェーンを配布版から分離し、フォーク元の自動更新を無効化した。詳細は後述のローカルビルドの制約を参照。 | `8a4f2b31`, `5c8b1302` |
| ビルド・個人配布 | ローカルビルドと起動手順、DMG作成を追加した。GitHubリリース公開用の構成を経て、現在はDeveloper ID署名・Apple公証を行う個人配布用DMGを作る。公証は状態をポーリングして待つ。 | `9e3d6aef`, `b1a0903f`, `6ec2663b`, `3a1b3941` |
| README整備 | データ保存先・iCloud・起動手順・Auto Learnの変更と利用条件を記載した。 | `805b6277`, `b3008b95` |

音声認識の実行先、AI補正、自動学習の審査、iCloud同期はそれぞれ独立した設定・通信経路になる。
上の「100% offline」はローカル処理を選んだ場合の説明であり、クラウド機能を使う場合には当てはまらない。

## 本家2.26の試験統合（日本語）

このブランチは本家の2.26（`4bc74cad`）を統合して検証するためのもの。
既存のフォークのmainや、インストール済みアプリは自動で更新しない。
本家のAuto Learn、Smart Punctuation、入力・録音・ストリーミングの改善を取り込み、
日本語フィラー除去、WebKit入力欄の取得、利用量集計、辞書バックアップ、
iCloud同期、ローカルビルドのデータ分離を維持する。

### Auto Learnの変更と利用条件

本家の新方式に合わせ、学習は主に置換候補の提示として扱う。
新規設定では外部AIを使わないルール審査を利用でき、必要な訂正回数を1〜3回で選べる。
AI審査を設定した場合は自動／手動を選択できる。手動審査では「Review Now」で審査し、
承認された候補を登録する。既存のAIプロバイダー・モデルと手動送信の設定は移行する。
旧方式の「置換と語彙を同時登録する」審査指示は使わない。

- 日本語の製品名やAIモデル名の音声認識誤りは、同じ語の表記を復元する場合に置換候補とする。
  一般的な役割名や、長い名前の一部だけの危険な置換は審査対象から除外する。
- 送信後に空になるWeb入力欄は、最後に読めた空でない内容から訂正を検出する。
  値の変更通知、定期的な読み直し、貼り付け直後の短時間の再試行を維持する。
- WebKitでは選択位置から編集可能な親要素を探す。日本語の差分は文字種の境界で分割する。
- 取得失敗時の手動登録案内、辞書画面からの手動登録、取得統計、AI審査の利用量集計を維持する。
- AI審査には専用の45秒以上のタイムアウトを使う。

入力欄の読み取りにはmacOSのアクセシビリティ許可が必要。
入力欄によって取得できない場合があり、すべての訂正が登録される保証はない。
クラウドのAI審査を選ぶと修正候補のテキストがそのプロバイダーへ送信される。
本家のSmart Punctuationは入力位置に合わせた空白・大文字・句読点の調整であり、
次節のHorizonによる日本語の句読点補完とは別の処理。

オフラインの確認:

```shell
bash Tests/run-auto-learn-correction-diff-tests.sh
bash Tests/run-auto-learn-web-focus-tests.sh
bash Tests/run-output-filter-tests.sh
bash Tests/run-reliability-tests.sh
bash Tests/run-recording-speech-gate-tests.sh
```

これらは本番の外部AIや実際のアプリ入力欄での審査・登録、iCloudの端末間同期を
検証するものではない。試験ビルドも通常のフォークと同じデータ保存先を使うため、
起動して試す前に辞書を書き出して保管する。新しいAuto Learnは候補ファイルを移行するので、
旧版へ戻しても新しい候補が旧版で読めるとは限らない。

## HaaS-ja / Horizon の外部連携（日本語）

HaaS-jaによる日本語音声認識と、Horizonによる句読点補完をローカルサービス経由で利用できる。
これらはアプリ内蔵ではなく、実行ファイル・プロキシ・Python環境・モデルを別途用意する構成。
このリポジトリの clone や `make local` だけでは導入されない。

処理経路は VoiceInk のカスタム文字起こし接続先 → 互換プロキシ → HaaS-ja。
認識結果を返す際にプロキシがHorizonで句読点を補完する。
VoiceInk側には、プロキシのOpenAI互換文字起こしエンドポイントと対応するモデル名を設定する。

- **互換プロキシ**: VoiceInkが送る `temperature` を取り除いて音声認識サーバーへ中継する。
- **Horizon**: ローカルONNXモデルで元の文字・空白・既存の句読点を保ちながら句読点を追加する。
  Python依存、トークナイザー、モデル設定、ONNXモデルが必要。補完失敗時は認識結果をそのまま返す。
- **補完対象**: 成功した通常のJSON文字起こし応答の `text`（16,000文字以下）。
  `segments` / `words` を含む応答、JSON以外、エラー応答は変更しない。
- **状態確認**: プロキシの `/_voiceink/health` と `X-VoiceInk-Punctuation` 応答ヘッダーで確認する。
  これらは音声認識の精度やVoiceInkからの接続成功を保証するものではない。

自動起動・ログ出力先・接続ポートは利用環境に合わせて設定する。
ローカル文字起こしを使っていても、AI補正やAuto Learnにクラウドを選んだ場合は
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

このフォークは配布版と同じ
`make local` でビルドするが、**起動手順に 1 点だけ違いがある**: 成果物は `~/Downloads/VoiceInk.app`
に作られるので、ランチャー（Raycast など）やアクセシビリティ許可の管理で standard に扱うため
`/Applications` に置くこと。

### ビルドから起動まで

前提: 対応するXcodeとHomebrewが導入済みであること。
`make local` は Apple Development による自動署名が必須で、ad-hoc署名へのフォールバックはない。
署名チームは `LocalBuild.xcconfig` の `DEVELOPMENT_TEAM` で設定する。
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
- 辞書は設定したiCloudコンテナでMacとiOSの間で同期する。
- フォーク専用のbundle idとApplication Support内のデータフォルダを使い、配布版と共存する。
  実際の識別子・保存先はビルド設定と `AppPaths` を参照。データを消すと履歴・辞書・設定が失われる。
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
- [Swift Atomics](https://github.com/apple/swift-atomics) - Low-level atomic operations for thread-safe concurrent programming


---

Made with ❤️ by Pax
