import Foundation
final class FillerWordManager {
    static let shared = FillerWordManager()
    var fillerWords = ["えーと", "あの", "um", "uh"]
}
@main struct TranscriptionOutputFilterTests {
    static func main() {
        let cases = [
            ("えーと、明日の予定です。", "明日の予定です。"),
            ("あの件を確認します。", "あの件を確認します。"),
            ("ここまで、えーと", "ここまで"),
            ("Um, hello world.", "Hello world."),
            ("The word is \"um\".", "The word is \"um\"."),
        ]
        for (input, expected) in cases {
            let actual = TranscriptionOutputFilter.filter(input)
            precondition(actual == expected, "Expected \(expected), got \(actual)")
        }
        print("PASS Japanese filler boundaries and upstream English cleanup/quoted-word preservation")
    }
}
