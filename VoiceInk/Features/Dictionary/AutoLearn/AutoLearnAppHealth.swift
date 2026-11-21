import Foundation

/// Per-app capture health that survives month boundaries. It answers "did this
/// app work before, and when and with which app version did it stop?" so an
/// app update that breaks capture is visible without reading system logs.
/// Text is never stored; only dates, versions and failure reason keys.
struct AutoLearnAppHealthRecord: Codable, Equatable, Identifiable {
    var id: String { appID }
    let appID: String
    var appName: String
    var lastSuccessAt: Date?
    var lastSuccessVersion: String?
    var lastFailureAt: Date?
    var lastFailureReason: String?
    var lastFailureVersion: String?
    /// Field-read failures since the last successful capture.
    var consecutiveFailures = 0

    /// Failures that mean the app's input field could not be read. Permission
    /// problems or empty pastes say nothing about the app and are ignored.
    static let healthReasons: Set<String> = ["focused-text-reading-unavailable", "pasted-range-invalid"]
    static let alertThreshold = 3

    init(appID: String, appName: String) {
        self.appID = appID
        self.appName = appName
    }

    mutating func recordSuccess(version: String?, at date: Date) {
        lastSuccessAt = date
        lastSuccessVersion = version
        consecutiveFailures = 0
    }

    /// Returns false when the reason does not concern the app's field.
    @discardableResult
    mutating func recordFailure(reason: String, version: String?, at date: Date) -> Bool {
        guard Self.healthReasons.contains(reason) else { return false }
        lastFailureAt = date
        lastFailureReason = reason
        lastFailureVersion = version
        consecutiveFailures += 1
        return true
    }

    var status: AutoLearnAppHealthStatus {
        guard consecutiveFailures >= Self.alertThreshold else { return .healthy }
        guard lastSuccessAt != nil else { return .neverWorked(failures: consecutiveFailures) }
        let changed = lastSuccessVersion != nil && lastFailureVersion != nil && lastSuccessVersion != lastFailureVersion
        return .stoppedWorking(
            failures: consecutiveFailures,
            previousVersion: changed ? lastSuccessVersion : nil,
            currentVersion: changed ? lastFailureVersion : nil
        )
    }
}

enum AutoLearnAppHealthStatus: Equatable {
    case healthy
    /// Capture has never succeeded in this app.
    case neverWorked(failures: Int)
    /// Capture used to work and now fails repeatedly. Versions are set only
    /// when the app's version differs between the last success and failure.
    case stoppedWorking(failures: Int, previousVersion: String?, currentVersion: String?)
}
