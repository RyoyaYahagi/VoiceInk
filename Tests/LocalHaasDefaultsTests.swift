import Foundation

// Isolate Keychain and unrelated provider metadata; model serialization and HTTP use production code.
final class APIKeyManager {
    static let shared = APIKeyManager()
    func getCustomModelAPIKey(forModelId: UUID) -> String? { nil }
    func saveCustomModelAPIKey(_ key: String, forModelId: UUID) {}
}
enum LanguageDictionary {
    static func forProvider(isMultilingual: Bool, provider: ModelProvider = .whisper) -> [String: String] { [:] }
}
struct TranscriptionRequestContext { let language: String? }
enum CloudTranscriptionError: Error {
    case networkError(Error), apiRequestFailed(statusCode: Int, message: String)
    case noTranscriptionReturned, audioFileNotFound
}

final class ServiceFixtureProtocol: URLProtocol {
    static var punctuation = "ready"
    static var modelID = LocalHaasSettings.modelName
    static var modelsStatus = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let isHealth = request.url!.path == "/_voiceink/health"
        let json: [String: Any] = isHealth
            ? ["punctuation": Self.punctuation] : ["data": [["id": Self.modelID]]]
        let response = HTTPURLResponse(url: request.url!, statusCode: isHealth ? 200 : Self.modelsStatus,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: json))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct LocalHaasDefaultsTests {
    static func main() async throws {
        let suite = "VoiceInkTests.HaasDefaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        LocalHaasSettings.registerDefaults(defaults: defaults)
        let models = try JSONDecoder().decode([CustomCloudModel].self, from: defaults.data(forKey: "customCloudModels")!)
        precondition(models.count == 1)
        precondition(models[0].selectionKey == defaults.string(forKey: "CurrentTranscriptionModel"))
        precondition(models[0].apiEndpoint == LocalHaasSettings.endpoint)
        precondition(models[0].apiKey.isEmpty)
        precondition(!models[0].supportsStreaming)
        precondition(models[0].supportedLanguages["auto"] != nil)
        let saved = Data("[]".utf8)
        defaults.set(saved, forKey: "customCloudModels")
        defaults.set("user-chosen-model", forKey: "CurrentTranscriptionModel")
        LocalHaasSettings.registerDefaults(defaults: defaults)
        precondition(defaults.data(forKey: "customCloudModels") == saved)
        precondition(defaults.string(forKey: "CurrentTranscriptionModel") == "user-chosen-model")
        print("PASS: clean defaults, model round trip, non-streaming, saved settings preserved")

        func verifyFixture() async -> Bool {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [ServiceFixtureProtocol.self]
            return await LocalHaasSettings.verifyService(session: URLSession(configuration: config))
        }
        var ready = await verifyFixture()
        precondition(ready)
        ServiceFixtureProtocol.punctuation = "fallback"
        ready = await verifyFixture()
        precondition(!ready, "Horizon fallback must not pass setup")
        ServiceFixtureProtocol.punctuation = "ready"
        ServiceFixtureProtocol.modelsStatus = 502
        ready = await verifyFixture()
        precondition(!ready, "Stopped upstream must not pass setup")
        ServiceFixtureProtocol.modelsStatus = 200
        ServiceFixtureProtocol.modelID = "unrelated-model"
        ready = await verifyFixture()
        precondition(!ready, "Wrong model must not pass setup")
        print("PASS: service readiness rejects Horizon fallback, stopped upstream and wrong model")

        if let path = CommandLine.arguments.dropFirst().first {
            let ready = await LocalHaasSettings.verifyService()
            precondition(ready, "HaaS + Horizon service unavailable")
            let text = try await OpenAICompatibleTranscriptionService().transcribe(
                audioURL: URL(fileURLWithPath: path), model: models[0],
                context: TranscriptionRequestContext(language: "auto"), timeout: 60)
            precondition(text.contains("会議"), "Expected Japanese fixture transcription")
            precondition(text.contains("、") || text.contains("。"), "Expected punctuation")
            print("PASS: production HTTP client → HaaS + Horizon: \(text)")
        }
    }
}
