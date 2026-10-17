import Foundation

/// Atomic, bounded archive storage; never prune until the new archive is validated.
enum DictionaryBackupArchiveWriter {
    static func write(_ data: Data, to folder: URL, now: Date = Date()) throws -> URL {
        _ = try DictionaryImportExportService.decodeArchiveData(data)
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = "voiceink-dictionary-\(Int(now.timeIntervalSince1970))-\(UUID().uuidString).json"
        let destination = folder.appendingPathComponent(filename)
        try data.write(to: destination, options: .atomic)
        _ = try DictionaryImportExportService.decodeArchiveData(Data(contentsOf: destination))
        let backups = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
            .filter {
                guard $0.lastPathComponent != filename, $0.lastPathComponent.hasPrefix("voiceink-dictionary-"), $0.pathExtension == "json",
                    let values = try? $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
                return values.isRegularFile == true && values.isSymbolicLink != true
            }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs > rhs
            }
        for old in backups.dropFirst(29) { try fm.removeItem(at: old) }
        return destination
    }
}
