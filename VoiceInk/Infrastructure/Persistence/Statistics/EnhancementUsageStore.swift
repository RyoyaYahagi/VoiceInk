import Foundation
import SwiftUI

/// 月別の AI 補正トークン推計を UserDefaults に保存して推定料金に使う。
/// 文字起こしテキストそのものは保存しない。リクエストと応答を分けて数えておくことで、
/// 入力/出力で単価の違う Gemini Flash の概算に使える。
struct EnhancementUsageEntry: Codable, Identifiable {
    var id: String { month }
    let month: String
    var enhancementRuns = 0
    var requestChars = 0
    var responseChars = 0
    var estimatedTokens = 0
}

@MainActor
final class EnhancementUsageStore: ObservableObject {
    static let shared = EnhancementUsageStore()
    @Published private(set) var entries: [EnhancementUsageEntry]
    private let defaults: UserDefaults
    private let key = "VoiceInkEnhancementUsageV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.data(forKey: key).flatMap {
            try? JSONDecoder().decode([EnhancementUsageEntry].self, from: $0)
        } ?? []
    }

    /// SessionMetric と同じ推計方法で 1 回分を記録する。
    func record(from transcription: Transcription, timestamp: Date = Date()) {
        guard
            let estimate = EnhancementTokenEstimate.estimate(from: transcription),
            estimate.tokenCount > 0
        else { return }

        let requestChars =
            (transcription.aiRequestSystemMessage?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0)
            + (transcription.aiRequestUserMessage?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0)
        let responseChars = transcription.enhancedText?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0

        let month = AutoLearnStatsStore.month(for: timestamp)
        let index: Int
        if let existing = entries.firstIndex(where: { $0.month == month }) {
            index = existing
        } else {
            entries.append(EnhancementUsageEntry(month: month))
            index = entries.count - 1
        }
        entries[index].enhancementRuns += 1
        entries[index].requestChars += max(0, requestChars)
        entries[index].responseChars += max(0, responseChars)
        entries[index].estimatedTokens += estimate.tokenCount
        let months = Set(entries.map(\.month)).sorted().suffix(24)
        entries = entries.filter { months.contains($0.month) }.sorted { $0.month > $1.month }
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
}
