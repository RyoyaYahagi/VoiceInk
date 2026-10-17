// Standalone tests. UI/model stubs below are only for compiling the production usage view.
import Foundation
import SwiftUI

enum ModelProvider: String { case whisper, fluidAudio, transcribeCpp, nativeApple, gemini, soniox }
struct TestModelFile: Identifiable { let name: String; var id: String { name } }
@MainActor final class WhisperModelManager: ObservableObject { @Published var availableModels: [TestModelFile] = [] }
enum DictionaryImportExportService {}

@main
struct ReliabilityStorageTests {
    @MainActor static func main() throws {
        let suite = "VoiceInkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProviderUsageStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.record(provider: "Gemini", seconds: 60, date: date)
        store.record(provider: "Gemini", seconds: 120, failed: true, date: date)
        store.record(provider: "Gemini", seconds: .nan, canceled: true, date: date)
        precondition(store.entries.count == 1)
        let entry = store.entries[0]
        precondition(entry.recordings == 3 && entry.audioSeconds == 180 && entry.failures == 1 && entry.cancellations == 1)
        let reopened = ProviderUsageStore(defaults: defaults)
        precondition(reopened.entries[0].recordings == 3)
        for year in 1990...2025 {
            let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 1, day: 1))!
            store.record(provider: "Soniox", seconds: -10, date: date)
        }
        precondition(Set(store.entries.map(\.month)).count == 24)
        precondition(store.entries.allSatisfy { $0.audioSeconds >= 0 && $0.audioSeconds.isFinite })
        precondition(LocalRecoverySettings.isCloud(.gemini) && LocalRecoverySettings.isCloud(.soniox))
        for provider: ModelProvider in [.whisper, .fluidAudio, .transcribeCpp, .nativeApple] {
            precondition(!LocalRecoverySettings.isCloud(provider))
        }
        print("PASS usage aggregation, persistence, invalid durations, retention and cloud classification")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = DictionaryArchive(
            vocabulary: [DictionaryVocabularyEntry(term: "テスト語", createdAt: date)],
            replacements: [DictionaryReplacementEntry(sources: ["ごにんしき"], replacement: "誤認識", createdAt: date)]
        )
        let data = try DictionaryImportExportService.encodeArchive(archive)
        var latest: URL!
        for _ in 0..<35 { latest = try DictionaryBackupArchiveWriter.write(data, to: folder) }
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        print("archive count=\(files.count), newest exists=\(FileManager.default.fileExists(atPath: latest.path))")
        precondition(files.count == 30 && FileManager.default.fileExists(atPath: latest.path))
        let restored = try DictionaryImportExportService.decodeArchiveData(Data(contentsOf: latest))
        precondition(restored.archive.vocabulary[0].term == "テスト語")
        precondition(restored.archive.replacements[0].replacement == "誤認識")
        let unrelated = folder.appendingPathComponent("unrelated.json")
        try Data("keep".utf8).write(to: unrelated)
        do {
            _ = try DictionaryBackupArchiveWriter.write(Data("invalid".utf8), to: folder)
            preconditionFailure("Corrupt backup must fail")
        } catch {}
        let afterFailure = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        precondition(afterFailure.count == 31)
        _ = try DictionaryBackupArchiveWriter.write(data, to: folder)
        precondition(FileManager.default.fileExists(atPath: unrelated.path))
        print("PASS archive round trip, 30-generation retention, newest preserved, invalid writes and unrelated files")
    }
}
