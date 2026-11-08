import CoreData
import Foundation
import SwiftData

@MainActor
final class DictionarySyncMaintenance {
    static let shared = DictionarySyncMaintenance()

    private var observer: NSObjectProtocol?
    private var container: ModelContainer?

    private init() {}

    func start(container: ModelContainer) {
        self.container = container
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handle(notification)
            }
        }
    }

    private func handle(_ notification: Notification) {
        guard
            let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event,
            event.type == .import,
            event.endDate != nil,
            event.succeeded,
            let container
        else { return }

        DictionaryService.cleanUpDictionaryContent(
            context: container.mainContext,
            source: "cloudkit import"
        )
    }
}
