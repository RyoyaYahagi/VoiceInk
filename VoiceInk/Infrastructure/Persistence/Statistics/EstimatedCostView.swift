import Foundation
import SwiftUI

/// 公開料金に基づく月別の推定利用料金の表示。
/// 料金: https://ai.google.dev/gemini-api/docs/pricing (最終確認 2026-10-16,
/// 期間限定価格は 2026-12-31 まで). 実請求とは一致しない概算値。
enum EstimatedCostPricing {
    /// Gemini 音声文字起こしの混合実効単価（音声入力 $2/1M トークン + テキスト出力 $12/1M トークン）。
    static let geminiTranscriptionPerMinute: Double = 0.0051
    /// Gemini Flash 補正の入力単価。
    static let geminiFlashInputPerMillionTokens: Double = 0.75
    /// Gemini Flash 補正の出力単価。
    static let geminiFlashOutputPerMillionTokens: Double = 3.75

    static let geminiProviderRawValue = ModelProvider.gemini.rawValue

    static func transcriptionCost(minutes: Double) -> Double {
        minutes * geminiTranscriptionPerMinute
    }

    static func enhancementCost(requestChars: Int, responseChars: Int) -> Double {
        let requestTokens = tokenEstimate(fromCharacters: requestChars)
        let responseTokens = tokenEstimate(fromCharacters: responseChars)
        return Double(requestTokens) / 1_000_000 * geminiFlashInputPerMillionTokens
            + Double(responseTokens) / 1_000_000 * geminiFlashOutputPerMillionTokens
    }

    /// `EstimatedTokenCounter`（文字数 ÷ 4）と同じ方法で文字数からトークンを概算する。
    static func tokenEstimate(fromCharacters chars: Int) -> Int {
        guard chars > 0 else { return 0 }
        return max(1, (chars + 3) / 4)
    }
}

struct EstimatedCostView: View {
    @ObservedObject private var providerUsage = ProviderUsageStore.shared
    @ObservedObject private var enhancementUsage = EnhancementUsageStore.shared
    @ObservedObject private var autoLearnStats = AutoLearnStatsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("公開されている単価に基づいて、この Mac で記録した利用分の推定料金を月別（UTC）に合計表示します。行にマウスを乗せると内訳を見られます。推定値であり実請求とは一致しません。")
                .font(.caption)
                .foregroundStyle(.secondary)
            rows
        }
        .padding(8)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(mergedMonths, id: \.self) { month in
                row(for: month)
            }
            if mergedMonths.isEmpty {
                Text("まだ記録はありません。")
                    .font(.caption)
            }
        }
    }

    private var mergedMonths: [String] {
        let months = Set(providerUsage.entries.map(\.month))
            .union(enhancementUsage.entries.map(\.month))
            .union(autoLearnStats.reviewEntries.map(\.month))
        return months.sorted { $0 > $1 }
    }

    private func row(for month: String) -> some View {
        let transcription = transcriptionCost(for: month)
        let enhancement = enhancementCost(for: month)
        let review = reviewCost(for: month)
        let total = transcription.cost + enhancement + review

        return HStack {
            Text(month)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(total, format: .currency(code: "USD"))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(total > 0 ? AppTheme.Text.primary : .secondary)
        }
        .help(helpText(
            transcription: transcription,
            enhancement: enhancement,
            review: review
        ))
    }

    private func transcriptionCost(for month: String) -> (cost: Double, includedMinutes: Double, excludedMinutes: Double) {
        let entries = providerUsage.entries.filter { $0.month == month }
        var cost = 0.0
        var includedMinutes = 0.0
        var excludedMinutes = 0.0
        for entry in entries {
            let minutes = entry.audioSeconds / 60
            if entry.provider == EstimatedCostPricing.geminiProviderRawValue {
                cost += EstimatedCostPricing.transcriptionCost(minutes: minutes)
                includedMinutes += minutes
            } else {
                excludedMinutes += minutes
            }
        }
        return (cost, includedMinutes, excludedMinutes)
    }

    private func enhancementCost(for month: String) -> Double {
        let entries = enhancementUsage.entries.filter { $0.month == month }
        return entries.reduce(0.0) { total, entry in
            total + EstimatedCostPricing.enhancementCost(
                requestChars: entry.requestChars,
                responseChars: entry.responseChars
            )
        }
    }

    private func reviewCost(for month: String) -> Double {
        autoLearnStats.reviewEntries.filter { $0.month == month }
            .reduce(0.0) { partial, item in
                partial + EstimatedCostPricing.enhancementCost(
                    requestChars: item.requestChars,
                    responseChars: item.responseChars
                )
            }
    }

    private func helpText(
        transcription: (cost: Double, includedMinutes: Double, excludedMinutes: Double),
        enhancement: Double,
        review: Double
    ) -> String {
        var lines = [
            String(
                format: "文字起こし（Gemini）: %.1f 分 → %.4f\u{24}",
                transcription.includedMinutes,
                transcription.cost
            )
        ]
        if transcription.excludedMinutes > 0 {
            lines.append(String(format: "文字起こし（Gemini 以外・対象外）: %.1f 分", transcription.excludedMinutes))
        }
        lines.append(String(format: "AI 補正の推計: %.4f\u{24}", enhancement))
        lines.append(String(format: "辞書学習レビューの推計: %.4f\u{24}", review))
        lines.append("・推定値であり実請求とは一致しません")
        lines.append("・料金は公開情報（https://ai.google.dev/gemini-api/docs/pricing、最終確認 2026-10-16）")
        lines.append("・AI 補正は入力・出力の文字数から Gemini Flash の単価で概算")
        if transcription.excludedMinutes > 0 {
            lines.append("・Soniox などの他プロバイダの文字起こし料金は計算対象外")
        }
        return lines.joined(separator: "\n")
    }
}
