// Compile this harness with the production TranscriptionServiceRegistry.swift only.
// Providers are fakes: these tests never contact a network or load a speech model.
import Foundation

enum ModelProvider: String { case whisper, fluidAudio, transcribeCpp, nativeApple, gemini }
protocol TranscriptionModel { var name: String { get }; var displayName: String { get }; var provider: ModelProvider { get } }
struct ImportedWhisperModel: TranscriptionModel {
    let name: String
    var displayName: String { name }
    let provider: ModelProvider = .whisper
    init(fileBaseName: String) { name = fileBaseName }
}
struct CloudModel: TranscriptionModel { let name = "cloud"; let displayName = "Cloud"; let provider: ModelProvider = .gemini }
struct ModelContext {}
struct TranscriptionRequestContext {
    var language: String? = "ja-JP"
    var prompt: String? = nil
    static let currentDefaults = Self()
    func scoped(to model: any TranscriptionModel) -> Self { self }
}
struct TranscriptionRuntimeConfiguration {
    let model: any TranscriptionModel
    let requestContext = TranscriptionRequestContext()
    var isRealtimeEnabled = false
}
struct ModelFile { let name: String; let url: URL }
@MainActor protocol WhisperModelProvider: AnyObject { var availableModels: [ModelFile] { get } }
@MainActor final class FakeModelProvider: WhisperModelProvider { var availableModels: [ModelFile] = [] }
protocol TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String
}
enum TestError: Error { case offline }
@MainActor final class FakeCalls {
    static var primary = 0
    static var local = 0
    static var localLanguage: String?
    static var localFails = false
    static var cancelDuringPrimary: (() -> Void)?
}
struct WhisperTranscriptionService: TranscriptionService {
    init(modelsDirectory: URL, modelProvider: (any WhisperModelProvider)?) {}
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String {
        await MainActor.run { FakeCalls.local += 1; FakeCalls.localLanguage = context.language }
        if await FakeCalls.localFails { throw TestError.offline }
        return "local text"
    }
}
struct CloudTranscriptionService: TranscriptionService {
    init(modelContext: ModelContext) {}
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String {
        await MainActor.run { FakeCalls.primary += 1; FakeCalls.cancelDuringPrimary?() }
        throw TestError.offline
    }
}
struct NativeAppleTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String { throw TestError.offline }
}
struct FluidAudioTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String { throw TestError.offline }
    func cleanup() async {}
}
struct TranscribeCppTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String { throw TestError.offline }
    func cleanup() {}
}
@MainActor protocol TranscriptionSession { func transcribe(audioURL: URL) async throws -> String; func cancel() }
@MainActor class FileTranscriptionSession: TranscriptionSession {
    init(service: any TranscriptionService) {}
    var canceled = false
    func transcribe(audioURL: URL) async throws -> String { throw TestError.offline }
    func cancel() { canceled = true }
}
@MainActor final class StreamingTranscriptionSession: FileTranscriptionSession {
    init(streamingService: StreamingTranscriptionService, fallbackService: any TranscriptionService) { super.init(service: fallbackService) }
}
struct StreamingTranscriptionService {
    init(modelContext: ModelContext, fluidAudioService: FluidAudioTranscriptionService?, onPartialTranscript: ((String) -> Void)?) {}
}
enum AudioFileMetadata { static func duration(for url: URL) async -> Double { 30 } }
@MainActor final class ProviderUsageStore {
    static let shared = ProviderUsageStore()
    var events: [(String, Bool, Bool)] = []
    func record(provider: String, seconds: Double, failed: Bool = false, canceled: Bool = false) { events.append((provider, failed, canceled)) }
}
enum LocalRecoverySettings {
    static let modelKey = "VoiceInkTestModel.\(UUID().uuidString)"
    static var isEnabled = true
    static func isCloud(_ provider: ModelProvider) -> Bool { provider == .gemini }
}
@MainActor final class NotificationManager {
    static let shared = NotificationManager()
    enum Kind { case warning }
    func showNotification(title: String, type: Kind, duration: Double) {}
}

@main struct RecordingRecoveryTests {
    @MainActor static func main() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp); UserDefaults.standard.removeObject(forKey: LocalRecoverySettings.modelKey) }
        let provider = FakeModelProvider()
        provider.availableModels = [ModelFile(name: "multilingual", url: temp)]
        let registry = TranscriptionServiceRegistry(modelProvider: provider, modelsDirectory: temp.deletingLastPathComponent(), modelContext: ModelContext())
        let configuration = TranscriptionRuntimeConfiguration(model: CloudModel())
        let result = try await registry.transcribeRecording(audioURL: temp, configuration: configuration, session: nil, shouldCancel: { false })
        precondition(result.text == "local text" && result.modelName.contains("local recovery"))
        precondition(FakeCalls.primary == 1 && FakeCalls.local == 1 && FakeCalls.localLanguage == "ja")
        precondition(ProviderUsageStore.shared.events.count == 2)
        precondition(ProviderUsageStore.shared.events[0].1 && !ProviderUsageStore.shared.events[1].1)
        print("PASS cloud failure recovers locally, normalizes language and records both providers")

        func expectFailure(_ operation: () async throws -> Void) async {
            do { try await operation(); preconditionFailure("Expected error") } catch {}
        }
        LocalRecoverySettings.isEnabled = false
        await expectFailure { _ = try await registry.transcribeRecording(audioURL: temp, configuration: configuration, session: nil, shouldCancel: { false }) }
        precondition(FakeCalls.local == 1)
        LocalRecoverySettings.isEnabled = true
        provider.availableModels = [ModelFile(name: "english.en", url: temp)]
        await expectFailure { _ = try await registry.transcribeRecording(audioURL: temp, configuration: configuration, session: nil, shouldCancel: { false }) }
        precondition(FakeCalls.local == 1)
        provider.availableModels = [ModelFile(name: "multilingual", url: temp)]
        UserDefaults.standard.set("missing", forKey: LocalRecoverySettings.modelKey)
        await expectFailure { _ = try await registry.transcribeRecording(audioURL: temp, configuration: configuration, session: nil, shouldCancel: { false }) }
        precondition(FakeCalls.local == 1)
        UserDefaults.standard.removeObject(forKey: LocalRecoverySettings.modelKey)
        print("PASS disabled recovery, incompatible language and missing selected model do not retry")

        var canceled = false
        FakeCalls.cancelDuringPrimary = { canceled = true }
        await expectFailure { _ = try await registry.transcribeRecording(audioURL: temp, configuration: configuration, session: nil, shouldCancel: { canceled }) }
        precondition(FakeCalls.local == 1 && ProviderUsageStore.shared.events.last!.2)
        FakeCalls.cancelDuringPrimary = nil
        let session = FileTranscriptionSession(service: CloudTranscriptionService(modelContext: ModelContext()))
        _ = try await registry.transcribeRecording(audioURL: temp, configuration: configuration, session: session, shouldCancel: { false })
        precondition(session.canceled && FakeCalls.local == 2)
        FakeCalls.localFails = true
        await expectFailure { _ = try await registry.transcribeRecording(audioURL: temp, configuration: configuration, session: nil, shouldCancel: { false }) }
        precondition(FakeCalls.local == 3)
        print("PASS cancellation never recovers, failed stream is canceled, local error does not recurse")
    }
}
