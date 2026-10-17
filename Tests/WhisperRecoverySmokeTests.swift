// Optional real-model smoke test: compile with production LibWhisper.swift and VADModelManager.swift.
import AVFoundation
import Foundation

enum VoiceInkEngineError: Error { case modelLoadFailed }

@main struct WhisperRecoverySmokeTests {
    static func main() async throws {
        let context = try await WhisperContext.createContext(path: CommandLine.arguments[1])
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: CommandLine.arguments[2]))
        precondition(file.processingFormat.sampleRate == 16_000 && file.processingFormat.channelCount == 1)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        await context.setLanguage("ja")
        let success = await context.fullTranscribe(samples: samples)
        let text = await context.getTranscription()
        await context.releaseResources()
        precondition(success && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        print("PASS real local model Japanese transcription: \(text)")
    }
}
