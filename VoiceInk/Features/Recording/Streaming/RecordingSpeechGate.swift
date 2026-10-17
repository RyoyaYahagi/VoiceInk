import Foundation
import whisper

/// Per-recording local Silero VAD. All inference and mutable state stay on one queue.
/// Input/output: signed 16-bit little-endian PCM, 16 kHz, mono.
final class RecordingSpeechGate: @unchecked Sendable {
    enum DetectionError: Error { case modelUnavailable, inferenceFailed }

    private let queue = DispatchQueue(label: "com.voiceink.speechGate", qos: .userInitiated)
    private let context: OpaquePointer
    private let output: (Data) -> Void
    private var pending = Data()
    private var preRoll: [Data] = []
    private var consecutiveSpeechFrames = 0
    private var hangoverFrames = 0
    private var hasSpeech = false
    private var failed = false
    private var closed = false

    static func create(output: @escaping (Data) -> Void) async throws -> RecordingSpeechGate {
        guard let path = Bundle.main.url(forResource: "ggml-silero-v5.1.2", withExtension: "bin")?.path else {
            throw DetectionError.modelUnavailable
        }
        return try await Task.detached(priority: .userInitiated) {
            var params = whisper_vad_default_context_params()
            params.n_threads = 1
            params.use_gpu = false
            guard let context = whisper_vad_init_from_file_with_params(path, params) else {
                throw DetectionError.modelUnavailable
            }
            return RecordingSpeechGate(context: context, output: output)
        }.value
    }

    private init(context: OpaquePointer, output: @escaping (Data) -> Void) {
        self.context = context
        self.output = output
    }

    deinit { whisper_vad_free(context) }

    func receive(_ data: Data) {
        queue.async { [self] in
            guard !closed, !failed else { return }
            pending.append(data)
            // Silero uses 512 samples (32 ms) per inference window.
            while pending.count >= 1_024 {
                let frame = Data(pending.prefix(1_024))
                pending.removeFirst(1_024)
                process(frame)
            }
        }
    }

    /// Called after the recorder has drained its audio queue. Does not wait for the network.
    func finish() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                if !closed, !pending.isEmpty {
                    var frame = Data(pending)
                    frame.append(Data(count: 1_024 - frame.count))
                    process(frame)
                }
                closed = true
                pending.removeAll()
                preRoll.removeAll()
                if failed {
                    continuation.resume(throwing: DetectionError.inferenceFailed)
                } else {
                    continuation.resume(returning: hasSpeech)
                }
            }
        }
    }

    func cancel() {
        queue.async { [self] in
            closed = true
            pending.removeAll()
            preRoll.removeAll()
        }
    }

    private func process(_ frame: Data) {
        guard !failed else { return }
        let samples: [Float] = stride(from: 0, to: frame.count, by: 2).map { index in
            Float(Int16(bitPattern: UInt16(frame[index]) | UInt16(frame[index + 1]) << 8)) / 32_768
        }
        guard whisper_vad_detect_speech_no_reset(context, samples, Int32(samples.count)),
            whisper_vad_n_probs(context) == 1,
            let probabilities = whisper_vad_probs(context), probabilities[0].isFinite
        else {
            failed = true
            return
        }

        let isSpeech = probabilities[0] >= 0.5
        consecutiveSpeechFrames = isSpeech ? consecutiveSpeechFrames + 1 : 0
        if consecutiveSpeechFrames >= 2 {
            hasSpeech = true
            hangoverFrames = 10
        }

        if hangoverFrames > 0 {
            for buffered in preRoll { output(buffered) }
            preRoll.removeAll(keepingCapacity: true)
            output(frame)
            hangoverFrames -= 1
        } else {
            // Keep 320 ms locally to preserve word beginnings; never send silence alone.
            preRoll.append(frame)
            if preRoll.count > 10 { preRoll.removeFirst() }
        }
    }
}
