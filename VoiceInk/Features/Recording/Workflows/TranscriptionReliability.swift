import Foundation
import SwiftUI

/// Local activity accounting, not billing telemetry or a provider quota API.
struct ProviderUsageEntry: Codable, Identifiable {
    var id: String { month + provider }
    let month: String
    let provider: String
    var recordings = 0
    var audioSeconds: Double = 0
    var failures = 0
    var cancellations = 0
}

@MainActor
final class ProviderUsageStore: ObservableObject {
    static let shared = ProviderUsageStore()
    @Published private(set) var entries: [ProviderUsageEntry]
    private let defaults: UserDefaults
    private let key = "VoiceInkProviderUsageV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([ProviderUsageEntry].self, from: $0) } ?? []
    }

    func record(provider: String, seconds: Double, failed: Bool = false, canceled: Bool = false, date: Date = Date()) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: date)
        let index: Int
        if let existing = entries.firstIndex(where: { $0.month == month && $0.provider == provider }) {
            index = existing
        } else {
            entries.append(ProviderUsageEntry(month: month, provider: provider))
            index = entries.count - 1
        }
        entries[index].recordings += 1
        entries[index].audioSeconds += seconds.isFinite ? max(0, seconds) : 0
        entries[index].failures += failed ? 1 : 0
        entries[index].cancellations += canceled ? 1 : 0
        // Bound storage without retaining transcripts or audio filenames.
        let months = Set(entries.map(\.month)).sorted().suffix(24)
        entries = entries.filter { months.contains($0.month) }.sorted { ($0.month, $0.provider) > ($1.month, $1.provider) }
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
}

enum LocalRecoverySettings {
    static let enabledKey = "VoiceInkLocalRecoveryEnabled"
    static let modelKey = "VoiceInkLocalRecoveryModel"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static func isCloud(_ provider: ModelProvider) -> Bool {
        ![.whisper, .fluidAudio, .transcribeCpp, .nativeApple].contains(provider)
    }
}

struct ProviderUsageView: View {
    @ObservedObject private var store = ProviderUsageStore.shared
    var body: some View {
        GroupBox("プロバイダー別の利用記録") {
            VStack(alignment: .leading, spacing: 8) {
                Text("この Mac で記録を開始した後の文字起こし処理を月別（UTC）に集計します。回数は録音単位、時間は録音全体の長さです。同じ録音を別の処理先へ切り替えた場合は、それぞれに記録します。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("API のリクエスト数・送信時間・請求額とは一致しません。AI 補正と辞書の自動学習の利用分は含みません。サービス側の残枠は取得していません。")
                    .font(.caption).foregroundStyle(.secondary)
                if store.entries.isEmpty {
                    Text("まだ記録はありません。")
                }
                ForEach(store.entries) { entry in
                    HStack {
                        Text("\(entry.month) · \(entry.provider)")
                        Spacer()
                        Text("\(entry.recordings) 回 · \(entry.audioSeconds / 60, specifier: "%.1f") 分 · 失敗 \(entry.failures) · 中止 \(entry.cancellations)")
                            .monospacedDigit()
                    }.font(.caption)
                }
            }.padding(8)
        }
    }
}

struct LocalRecoverySettingsView: View {
    @EnvironmentObject private var whisperModelManager: WhisperModelManager
    @AppStorage(LocalRecoverySettings.enabledKey) private var enabled = true
    @AppStorage(LocalRecoverySettings.modelKey) private var model = ""
    var body: some View {
        Section("通信障害時の復旧") {
            Toggle("クラウド文字起こしが失敗したら Mac 内で再処理する", isOn: $enabled)
            if enabled {
                Picker("復旧用 Whisper モデル", selection: $model) {
                    Text("自動選択（対応言語を確認）").tag("")
                    ForEach(whisperModelManager.availableModels) { item in
                        Text(item.name).tag(item.name)
                    }
                    if !model.isEmpty && !whisperModelManager.availableModels.contains(where: { $0.name == model }) {
                        Text("\(model)（未インストール）").tag(model)
                    }
                }
                Text("モデルは AI Models から事前にダウンロードしてください。モデルがない場合は元のエラーを表示します。自動ダウンロードや別のクラウドへの転送は行いません。ローカル処理は別料金不要ですが、時間とメモリを使用します。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
