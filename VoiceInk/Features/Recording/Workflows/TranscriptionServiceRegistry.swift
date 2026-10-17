import Foundation
import SwiftData
import SwiftUI
import os

@MainActor
class TranscriptionServiceRegistry {
    private weak var modelProvider: (any WhisperModelProvider)?
    private let modelsDirectory: URL
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionServiceRegistry")

    private(set) lazy var localTranscriptionService = WhisperTranscriptionService(
        modelsDirectory: modelsDirectory,
        modelProvider: modelProvider
    )
    private(set) lazy var cloudTranscriptionService = CloudTranscriptionService(modelContext: modelContext)
    private(set) lazy var nativeAppleTranscriptionService = NativeAppleTranscriptionService()
    private(set) lazy var fluidAudioTranscriptionService = FluidAudioTranscriptionService()
    private var cachedTranscribeCppTranscriptionService: TranscribeCppTranscriptionService?

    var transcribeCppTranscriptionService: TranscribeCppTranscriptionService {
        if let cachedTranscribeCppTranscriptionService {
            return cachedTranscribeCppTranscriptionService
        }
        let service = TranscribeCppTranscriptionService()
        cachedTranscribeCppTranscriptionService = service
        return service
    }

    init(modelProvider: any WhisperModelProvider, modelsDirectory: URL, modelContext: ModelContext) {
        self.modelProvider = modelProvider
        self.modelsDirectory = modelsDirectory
        self.modelContext = modelContext
    }

    func service(for provider: ModelProvider) -> TranscriptionService {
        switch provider {
        case .whisper:
            return localTranscriptionService
        case .fluidAudio:
            return fluidAudioTranscriptionService
        case .transcribeCpp:
            return transcribeCppTranscriptionService
        case .nativeApple:
            return nativeAppleTranscriptionService
        default:
            return cloudTranscriptionService
        }
    }

    func transcribe(
        audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext = .currentDefaults
    ) async throws -> String {
        let service = service(for: model.provider)
        logger.debug(
            "Transcribing with \(model.displayName, privacy: .public) using \(String(describing: type(of: service)), privacy: .public)"
        )
        return try await service.transcribe(audioURL: audioURL, model: model, context: context.scoped(to: model))
    }

    /// One activity record per recording/provider, including local recovery. Never recover a canceled request.
    func transcribeRecording(
        audioURL: URL, configuration: TranscriptionRuntimeConfiguration,
        session: TranscriptionSession?, shouldCancel: () -> Bool
    ) async throws -> (text: String, modelName: String) {
        let model = configuration.model
        let duration = await AudioFileMetadata.duration(for: audioURL)
        func checkCancellation() throws {
            try Task.checkCancellation()
            if shouldCancel() { throw CancellationError() }
        }
        try checkCancellation()
        do {
            let text: String
            if let session {
                text = try await session.transcribe(audioURL: audioURL)
            } else {
                text = try await transcribe(audioURL: audioURL, model: model, context: configuration.requestContext)
            }
            try checkCancellation()
            ProviderUsageStore.shared.record(provider: model.provider.rawValue, seconds: duration)
            return (text, model.displayName)
        } catch {
            let canceled = shouldCancel() || Task.isCancelled || error is CancellationError
                || (error as? URLError)?.code == .cancelled
            ProviderUsageStore.shared.record(provider: model.provider.rawValue, seconds: duration, failed: !canceled, canceled: canceled)
            if canceled { throw CancellationError() }
            guard LocalRecoverySettings.isEnabled, LocalRecoverySettings.isCloud(model.provider) else { throw error }
            let language = configuration.requestContext.language?.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first.map(String.init)
            let selectedName = UserDefaults.standard.string(forKey: LocalRecoverySettings.modelKey) ?? ""
            let available = (modelProvider?.availableModels ?? []).filter {
                FileManager.default.fileExists(atPath: $0.url.path)
                    && (!$0.name.hasSuffix(".en") || language == "en")
            }.sorted { $0.name < $1.name }
            guard let file = selectedName.isEmpty ? available.first : available.first(where: { $0.name == selectedName }) else {
                NotificationManager.shared.showNotification(
                    title: "ローカル復旧用の対応モデルがありません。AI Models から Whisper モデルを追加してください。",
                    type: .warning, duration: 7
                )
                throw error
            }
            try checkCancellation()
            session?.cancel()
            NotificationManager.shared.showNotification(title: "クラウド処理に失敗したため、Mac 内の \(file.name) で再処理します。", type: .warning, duration: 5)
            let localModel = ImportedWhisperModel(fileBaseName: file.name)
            do {
                let text = try await localTranscriptionService.transcribe(
                    audioURL: audioURL, model: localModel,
                    context: TranscriptionRequestContext(language: language, prompt: configuration.requestContext.prompt)
                )
                try checkCancellation()
                ProviderUsageStore.shared.record(provider: ModelProvider.whisper.rawValue, seconds: duration)
                return (text, "\(file.name) (local recovery)")
            } catch {
                let canceled = shouldCancel() || Task.isCancelled || error is CancellationError
                ProviderUsageStore.shared.record(provider: ModelProvider.whisper.rawValue, seconds: duration, failed: !canceled, canceled: canceled)
                throw error
            }
        }
    }

    /// Creates a streaming or file-based session for the resolved transcription configuration.
    func createSession(
        for configuration: TranscriptionRuntimeConfiguration, onPartialTranscript: ((String) -> Void)? = nil
    ) -> TranscriptionSession {
        let model = configuration.model

        if shouldUseRealtimeTranscription(for: configuration) {
            let streamingService = StreamingTranscriptionService(
                modelContext: modelContext,
                fluidAudioService: model.provider == .fluidAudio ? fluidAudioTranscriptionService : nil,
                onPartialTranscript: onPartialTranscript
            )
            let fallback = service(for: model.provider)
            return StreamingTranscriptionSession(streamingService: streamingService, fallbackService: fallback)
        } else {
            return FileTranscriptionSession(service: service(for: model.provider))
        }
    }

    /// Whether the resolved transcription configuration should use real-time transcription.
    func shouldUseRealtimeTranscription(for configuration: TranscriptionRuntimeConfiguration) -> Bool {
        configuration.isRealtimeEnabled
    }

    func cleanup() async {
        await fluidAudioTranscriptionService.cleanup()
        cachedTranscribeCppTranscriptionService?.cleanup()
    }
}
