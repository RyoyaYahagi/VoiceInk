import Foundation
import SwiftUI

/// Target-app identity for one paste observation. No transcription text is kept.
struct AutoLearnAppIdentity: Sendable, Equatable {
    let appID: String
    let appName: String
    /// CFBundleShortVersionString of the target app, when available.
    let appVersion: String?

    init(appID: String, appName: String, appVersion: String? = nil) {
        self.appID = appID
        self.appName = appName
        self.appVersion = appVersion
    }

    static let unknown = AutoLearnAppIdentity(appID: "unknown", appName: "不明なアプリ")
}

/// Per-app, per-month counts of Auto Learn paste observation attempts.
/// Text is never stored; only counters and failure reason keys.
struct AutoLearnCaptureStatEntry: Codable, Identifiable {
    var id: String { month + appID }
    let month: String
    let appID: String
    var appName = ""
    /// Paste captures that successfully armed field observation.
    var observationsArmed = 0
    /// Paste captures rejected before observation could start.
    var captureFailures = 0
    /// Reads (reason keys) where the input field could not be read back.
    var fieldReadFailures: [String: Int] = [:]
    /// Correction candidates actually queued for review from this app.
    var candidatesQueued = 0
}

/// Per-month review runs and their request/response sizes. Text is never stored.
struct AutoLearnReviewUsageEntry: Codable, Identifiable {
    var id: String { month }
    let month: String
    var provider = ""
    var modelName = ""
    var reviewRuns = 0
    var reviewedCandidates = 0
    var requestChars = 0
    var responseChars = 0
}

@MainActor
final class AutoLearnStatsStore: ObservableObject {
    static let shared = AutoLearnStatsStore()

    @Published private(set) var captureEntries: [AutoLearnCaptureStatEntry]
    @Published private(set) var reviewEntries: [AutoLearnReviewUsageEntry]
    @Published private(set) var healthRecords: [AutoLearnAppHealthRecord]

    private let defaults: UserDefaults
    private let captureKey = "VoiceInkAutoLearnCaptureStatsV1"
    private let reviewKey = "VoiceInkAutoLearnReviewUsageV1"
    private let healthKey = "VoiceInkAutoLearnAppHealthV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        captureEntries = defaults.data(forKey: captureKey).flatMap {
            try? JSONDecoder().decode([AutoLearnCaptureStatEntry].self, from: $0)
        } ?? []
        reviewEntries = defaults.data(forKey: reviewKey).flatMap {
            try? JSONDecoder().decode([AutoLearnReviewUsageEntry].self, from: $0)
        } ?? []
        healthRecords = defaults.data(forKey: healthKey).flatMap {
            try? JSONDecoder().decode([AutoLearnAppHealthRecord].self, from: $0)
        } ?? []
    }

    static func month(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    // MARK: Capture stats

    func recordObservationArmed(app: AutoLearnAppIdentity, date: Date = Date()) {
        upsert(app: app, month: Self.month(for: date)) { $0.observationsArmed += 1 }
        updateHealth(app: app) { $0.recordSuccess(version: app.appVersion, at: date) }
    }

    /// Returns the app's health after this failure.
    @discardableResult
    func recordCaptureFailure(reason: String, app: AutoLearnAppIdentity, date: Date = Date()) -> AutoLearnAppHealthStatus {
        upsert(app: app, month: Self.month(for: date)) { $0.captureFailures += 1 }
        if Self.readFailureReasons.contains(reason) {
            recordFieldReadFailure(reason: reason, app: app, date: date)
        }
        guard AutoLearnAppHealthRecord.healthReasons.contains(reason) else {
            return health(for: app.appID)?.status ?? .healthy
        }
        return updateHealth(app: app) { $0.recordFailure(reason: reason, version: app.appVersion, at: date) }
    }

    func health(for appID: String) -> AutoLearnAppHealthRecord? {
        healthRecords.first { $0.appID == appID }
    }

    @discardableResult
    private func updateHealth(
        app: AutoLearnAppIdentity,
        mutate: (inout AutoLearnAppHealthRecord) -> Void
    ) -> AutoLearnAppHealthStatus {
        guard app.appID != AutoLearnAppIdentity.unknown.appID else { return .healthy }
        let index: Int
        if let existing = healthRecords.firstIndex(where: { $0.appID == app.appID }) {
            index = existing
        } else {
            healthRecords.append(AutoLearnAppHealthRecord(appID: app.appID, appName: app.appName))
            index = healthRecords.count - 1
        }
        healthRecords[index].appName = app.appName
        mutate(&healthRecords[index])
        let status = healthRecords[index].status
        // Keep the apps used most recently; old ones carry no diagnostic value.
        healthRecords = Array(healthRecords
            .sorted { max($0.lastSuccessAt ?? .distantPast, $0.lastFailureAt ?? .distantPast)
                > max($1.lastSuccessAt ?? .distantPast, $1.lastFailureAt ?? .distantPast) }
            .prefix(50))
        if let data = try? JSONEncoder().encode(healthRecords) {
            defaults.set(data, forKey: healthKey)
        }
        return status
    }

    private static let readFailureReasons: Set<String> = [
        "focused-text-reading-unavailable",
        "pasted-range-invalid",
        "target-text-unreadable",
        "field-too-large",
        "snapshot-no-session",
    ]

    func recordFieldReadFailure(reason: String, app: AutoLearnAppIdentity, date: Date = Date()) {
        upsert(app: app, month: Self.month(for: date)) { entry in
            entry.fieldReadFailures[reason, default: 0] += 1
        }
    }

    func recordCandidatesQueued(_ count: Int, app: AutoLearnAppIdentity, date: Date = Date()) {
        guard count > 0 else { return }
        upsert(app: app, month: Self.month(for: date)) { $0.candidatesQueued += count }
    }

    // MARK: Review usage

    func recordReviewRun(
        provider: String,
        modelName: String,
        candidates: Int,
        requestChars: Int,
        responseChars: Int,
        date: Date = Date()
    ) {
        let month = Self.month(for: date)
        let index: Int
        if let existing = reviewEntries.firstIndex(where: { $0.month == month }) {
            index = existing
        } else {
            reviewEntries.append(AutoLearnReviewUsageEntry(month: month))
            index = reviewEntries.count - 1
        }
        reviewEntries[index].provider = provider
        reviewEntries[index].modelName = modelName
        reviewEntries[index].reviewRuns += 1
        reviewEntries[index].reviewedCandidates += candidates
        reviewEntries[index].requestChars += max(0, requestChars)
        reviewEntries[index].responseChars += max(0, responseChars)
        pruneAndPersistReview()
    }

    // MARK: Private

    private func upsert(
        app: AutoLearnAppIdentity,
        month: String,
        mutate: (inout AutoLearnCaptureStatEntry) -> Void
    ) {
        let index: Int
        if let existing = captureEntries.firstIndex(where: { $0.month == month && $0.appID == app.appID }) {
            index = existing
        } else {
            captureEntries.append(AutoLearnCaptureStatEntry(month: month, appID: app.appID))
            index = captureEntries.count - 1
        }
        if captureEntries[index].appName.isEmpty {
            captureEntries[index].appName = app.appName
        }
        mutate(&captureEntries[index])
        pruneAndPersistCapture()
    }

    private func pruneAndPersistCapture() {
        let months = Set(captureEntries.map(\.month)).sorted().suffix(24)
        captureEntries = captureEntries
            .filter { months.contains($0.month) }
            .sorted { ($0.month, $0.appID) > ($1.month, $1.appID) }
        if let data = try? JSONEncoder().encode(captureEntries) {
            defaults.set(data, forKey: captureKey)
        }
    }

    private func pruneAndPersistReview() {
        let months = Set(reviewEntries.map(\.month)).sorted().suffix(24)
        reviewEntries = reviewEntries.filter { months.contains($0.month) }.sorted { $0.month > $1.month }
        if let data = try? JSONEncoder().encode(reviewEntries) {
            defaults.set(data, forKey: reviewKey)
        }
    }
}

@MainActor
struct AutoLearnCaptureStatsView: View {
    @ObservedObject private var store = AutoLearnStatsStore.shared

    var body: some View {
        GroupBox("辞書自動学習の監視記録（アプリ別）") {
            VStack(alignment: .leading, spacing: 8) {
                Text("アプリごとの貼り付け後の監視回数と、入力欄を読めなかった回数・理由を月別（UTC）に集計します。文字起こしの内容そのものは保存しません。")
                    .font(.caption).foregroundStyle(.secondary)
                let attention = store.healthRecords.filter { $0.status != .healthy }
                if !attention.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(attention) { record in
                            Label(Self.healthMessage(for: record), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                let visible = store.captureEntries.filter(hasActivity)
                if visible.isEmpty {
                    Text("まだ記録はありません。")
                }
                ForEach(visible) { entry in
                    HStack(alignment: .top) {
                        Text("\(entry.month) · \(displayName(for: entry))")
                            .font(.caption)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(statLine(for: entry))
                                .font(.caption)
                                .monospacedDigit()
                            if let reasons = failureReasonLine(for: entry) {
                                Text(reasons)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }.padding(8)
        }
    }

    private func hasActivity(_ entry: AutoLearnCaptureStatEntry) -> Bool {
        entry.observationsArmed > 0 || entry.captureFailures > 0 || !entry.fieldReadFailures.isEmpty
    }

    private func displayName(for entry: AutoLearnCaptureStatEntry) -> String {
        entry.appName.isEmpty ? entry.appID : entry.appName
    }

    private func statLine(for entry: AutoLearnCaptureStatEntry) -> String {
        var parts: [String] = ["監視開始 \(entry.observationsArmed)"]
        if entry.captureFailures > 0 { parts.append("失敗 \(entry.captureFailures)") }
        let queued = entry.candidatesQueued
        if queued > 0 { parts.append("候補 \(queued) 件") }
        return parts.joined(separator: " · ")
    }

    private func failureReasonLine(for entry: AutoLearnCaptureStatEntry) -> String? {
        let sorted = entry.fieldReadFailures.sorted { $0.value > $1.value }
        let fragments = sorted.compactMap { key, count -> String? in
            let label = Self.reasonLabel(key)
            return label.map { "\($0) \(count)" }
        }
        guard !fragments.isEmpty else { return nil }
        return fragments.joined(separator: " · ")
    }

    static func healthMessage(for record: AutoLearnAppHealthRecord) -> String {
        let reason = record.lastFailureReason.flatMap(reasonLabel) ?? "不明"
        let last = record.lastFailureAt.map {
            " 最後の失敗: \($0.formatted(date: .numeric, time: .shortened))（\(reason)）。"
        } ?? ""
        switch record.status {
        case .healthy:
            return ""
        case .neverWorked(let failures):
            return "\(record.appName): まだ一度も監視できていません（\(failures) 回連続で失敗）。\(last)"
        case .stoppedWorking(let failures, let previous, let current):
            let since = record.lastSuccessAt.map { "\($0.formatted(date: .numeric, time: .omitted)) までは監視できていましたが、" } ?? "以前は監視できていましたが、"
            let update: String
            if let previous, let current {
                update = " \(previous) から \(current) への更新後に起きています。"
            } else {
                update = ""
            }
            return "\(record.appName): \(since)\(failures) 回連続で入力欄を読めていません。\(update)\(last)"
        }
    }

    static func reasonLabel(_ reason: String) -> String? {
        switch reason {
        case "accessibility-not-trusted": return "アクセシビリティ未許可"
        case "target-is-voiceink": return "VoiceInk 自身の入力欄"
        case "empty-pasted-text": return "貼り付けテキストが空"
        case "pasted-text-too-large": return "テキストが長すぎ"
        case "focused-text-reading-unavailable", "target-text-unreadable": return "入力欄を読めず"
        case "pasted-range-invalid": return "貼り付け位置を特定できず"
        case "field-too-large": return "入力欄が長すぎ"
        case "field-text-unchanged": return "修正が見られず"
        case "snapshot-no-session": return "監視セッションなし"
        case "revision-unavailable": return "差分を計算できず"
        default: return nil
        }
    }
}
