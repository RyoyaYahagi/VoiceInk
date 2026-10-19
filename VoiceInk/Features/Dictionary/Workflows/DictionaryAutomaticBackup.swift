import AppKit
import CryptoKit
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class DictionaryAutomaticBackup: ObservableObject {
    static let shared = DictionaryAutomaticBackup()
    static let enabledKey = "VoiceInkDictionaryAutomaticBackup"
    private static let bookmarkKey = "VoiceInkDictionaryBackupFolder"
    @Published private(set) var lastBackup: Date?
    @Published private(set) var errorMessage: String?
    private var task: Task<Void, Never>?
    private var context: ModelContext?
    private var isWriting = false
    private var lastDigest: String?

    private init() { lastBackup = UserDefaults.standard.object(forKey: "VoiceInkDictionaryLastBackup") as? Date }

    var enabled: Bool { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
    var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(AppPaths.appSupportFolderName)/DictionaryBackups", isDirectory: true)
    }

    func start(context: ModelContext) {
        self.context = context
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.backup()
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "辞書のバックアップ先を選んでください。iCloud Drive のフォルダも選べます。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            lastDigest = nil
            lastBackup = nil
            UserDefaults.standard.removeObject(forKey: "VoiceInkDictionaryLastBackup")
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func folder() throws -> URL {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return defaultFolder }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            UserDefaults.standard.set(try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil), forKey: Self.bookmarkKey)
        }
        return url
    }

    func backup(force: Bool = false) async {
        guard !isWriting, enabled || force, let context else { return }
        isWriting = true
        defer { isWriting = false }
        do {
            let archive = try DictionaryImportExportService.makeArchive(modelContext: context)
            // Ignore export timestamps when checking whether dictionary content changed.
            let comparable = DictionaryArchive(exportedAt: Date(timeIntervalSince1970: 0), vocabulary: archive.vocabulary, replacements: archive.replacements)
            let digestData = try DictionaryImportExportService.encodeArchive(comparable)
            let digest = SHA256.hash(data: digestData).map { String(format: "%02x", $0) }.joined()
            guard force || digest != lastDigest else { return }
            let data = try DictionaryImportExportService.encodeArchive(archive)
            let folder = try folder()
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            try await Task.detached(priority: .utility) {
                _ = try DictionaryBackupArchiveWriter.write(data, to: folder)
            }.value
            lastDigest = digest
            lastBackup = Date()
            UserDefaults.standard.set(lastBackup, forKey: "VoiceInkDictionaryLastBackup")
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

struct DictionaryAutomaticBackupSettings: View {
    @ObservedObject private var backup = DictionaryAutomaticBackup.shared
    @AppStorage(DictionaryAutomaticBackup.enabledKey) private var enabled = true
    var body: some View {
        Section("辞書の自動バックアップ") {
            Toggle("辞書を自動でバックアップする", isOn: $enabled)
            Text("起動時と 5 分ごとに変更を確認し、変更があれば保存します。最新 30 世代を保持します。初期の保存先はこの Mac 内です。別の保存先を選ばない限りクラウドへは送りません。")
                .font(.caption).foregroundStyle(.secondary)
            Text((try? backup.folder().path) ?? "保存先を開けません。選び直してください。")
                .font(.caption).textSelection(.enabled)
            HStack {
                Button("保存先を選ぶ…") { backup.chooseFolder() }
                Button("今すぐバックアップ") { Task { await backup.backup(force: true) } }
                Button("保存先を開く") {
                    if let folder = try? backup.folder() {
                        let access = folder.startAccessingSecurityScopedResource()
                        defer { if access { folder.stopAccessingSecurityScopedResource() } }
                        NSWorkspace.shared.open(folder)
                    }
                }
            }
            if let date = backup.lastBackup {
                Text("最終保存: \(date.formatted())").font(.caption)
            }
            if let error = backup.errorMessage {
                Text("バックアップに失敗しました: \(error)").font(.caption).foregroundStyle(.red)
            }
            Text("復元するには Dictionary Settings の Import で保存した JSON を選び、内容を確認して読み込みます。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
