import Foundation

enum AppPaths {
    static let appSupportFolderName = "com.ryoyayahagi.VoiceInk"

    static var appSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appSupportFolderName, isDirectory: true)
    }
}
