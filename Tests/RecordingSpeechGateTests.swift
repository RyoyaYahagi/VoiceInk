// Standalone integration harness: compile with RecordingSpeechGate.swift and the whisper framework.
// Place ggml-silero-v5.1.2.bin in the executable's app bundle Resources directory.
import AVFoundation
import Foundation

private final class Output: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [Data] = []
    func append(_ data: Data) { lock.lock(); frames.append(data); lock.unlock() }
    var bytes: Int { lock.lock(); defer { lock.unlock() }; return frames.reduce(0) { $0 + $1.count } }
}

@main
struct RecordingSpeechGateTests {
    static func pcm(_ samples: [Float]) -> Data {
        let integers = samples.map { Int16(max(-32_768, min(32_767, $0 * 32_767))) }
        return integers.withUnsafeBytes { Data($0) }
    }

    static func run(_ name: String, data: Data, expected: Bool, sends: Bool) async throws -> Int {
        let output = Output()
        let gate = try await RecordingSpeechGate.create(output: output.append)
        // Deliberately use odd chunk lengths to test sample/frame boundaries.
        var offset = 0
        while offset < data.count {
            let end = min(offset + 777, data.count)
            gate.receive(data.subdata(in: offset..<end))
            offset = end
        }
        let detected = try await gate.finish()
        precondition(detected == expected, "\(name): wrong speech verdict")
        precondition((output.bytes > 0) == sends, "\(name): unexpected transmission")
        let bytes = output.bytes
        gate.receive(Data(count: 2_048))
        _ = try await gate.finish()
        precondition(output.bytes == bytes, "\(name): audio sent after finish")
        print("PASS \(name): speech=\(detected), sent=\(bytes) bytes / input=\(data.count) bytes")
        return bytes
    }

    static func main() async throws {
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: CommandLine.arguments[1]))
        precondition(file.processingFormat.sampleRate == 16_000 && file.processingFormat.channelCount == 1)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        let speechSamples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        let speech = pcm(speechSamples)
        let silence = Data(count: 32_000 * 3)
        _ = try await run("empty", data: Data(), expected: false, sends: false)
        _ = try await run("silence", data: silence, expected: false, sends: false)
        _ = try await run("short silence", data: Data(count: 100), expected: false, sends: false)
        var click = [Float](repeating: 0, count: 48_000)
        click[16_000] = 0.8
        _ = try await run("click only", data: pcm(click), expected: false, sends: false)
        // Deterministic low-level noise.
        let noise = (0..<48_000).map { Float(($0 * 7919 % 2001) - 1000) / 1_000_000 }
        _ = try await run("quiet noise", data: pcm(noise), expected: false, sends: false)
        let speechBytes = try await run("speech", data: speech, expected: true, sends: true)
        _ = try await run("quiet speech", data: pcm(speechSamples.map { $0 * 0.1 }), expected: true, sends: true)
        let delayedBytes = try await run("speech after 3 seconds silence", data: silence + speech + silence, expected: true, sends: true)
        precondition(delayedBytes < speechBytes + 32_000, "Too much silence transmitted")
        let twiceBytes = try await run("speech, pause, speech", data: speech + silence + speech, expected: true, sends: true)
        precondition(twiceBytes > speechBytes, "Second utterance missing")
        let output = Output()
        let canceled = try await RecordingSpeechGate.create(output: output.append)
        canceled.cancel()
        canceled.receive(speech)
        let canceledHasSpeech = try await canceled.finish()
        precondition(!canceledHasSpeech)
        precondition(output.bytes == 0)
        print("PASS canceled gate sends nothing")
    }
}
