import Foundation

/// Default local transcription route; model weights and services are installed separately.
enum LocalHaasSettings {
    static let modelID = UUID(uuidString: "53C63B57-9BC8-4CD8-A536-4D7358C8A003")!
    static let endpoint = "http://127.0.0.1:8081/v1/audio/transcriptions"
    static let modelName = "Haas-ja-v1.0"
    static var selectionKey: String { "Custom:\(modelID.uuidString)" }

    static var model: CustomCloudModel {
        CustomCloudModel(
            id: modelID, name: "haas-ja-v1.0", displayName: "HaaS-ja + Horizon",
            description: "ローカルのHaaS-jaで文字起こしし、Horizonで句読点を補完します。サービスの別途導入が必要です。",
            apiEndpoint: endpoint, modelName: modelName, isMultilingual: true,
            supportedLanguages: ["auto": "Auto-detect", "ja": "Japanese"]
        )
    }

    static func registerDefaults(defaults: UserDefaults = .standard) {
        // Registration supplies defaults without overwriting a user's saved model list or selection.
        guard let data = try? JSONEncoder().encode([model]) else { return }
        defaults.register(defaults: [
            "customCloudModels": data,
            "CurrentTranscriptionModel": selectionKey,
        ])
    }

    static func verifyService(session: URLSession = URLSession(configuration: .ephemeral)) async -> Bool {
        defer { session.finishTasksAndInvalidate() }
        do {
            var healthRequest = URLRequest(url: URL(string: "http://127.0.0.1:8081/_voiceink/health")!)
            healthRequest.timeoutInterval = 5
            let (data, response) = try await session.data(for: healthRequest)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                let health = try JSONSerialization.jsonObject(with: data) as? [String: String],
                health["punctuation"] == "ready"
            else { return false }
            // The proxy alone can be running while the recognition service is stopped.
            var modelsRequest = URLRequest(url: URL(string: "http://127.0.0.1:8081/v1/models")!)
            modelsRequest.timeoutInterval = 5
            let (modelsData, modelsResponse) = try await session.data(for: modelsRequest)
            guard (modelsResponse as? HTTPURLResponse)?.statusCode == 200,
                let object = try JSONSerialization.jsonObject(with: modelsData) as? [String: Any],
                let models = object["data"] as? [[String: Any]]
            else { return false }
            return models.contains { ($0["id"] as? String)?.lowercased() == modelName.lowercased() }
        } catch {
            return false
        }
    }
}
