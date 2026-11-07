import Foundation

// The standalone harness only needs this policy dependency from AutoLearnTypes.
enum AIProvider { case voiceInkRefine; var supportsEnhancement: Bool { true } }

@main
struct AutoLearnCorrectionDiffTests {
    static func require(_ condition: Bool, _ message: String) {
        guard condition else { print("FAIL \(message)"); exit(1) }
    }

    static func main() {
        let original = "オーケストレーターが準備してからワーカーはディープシークを使って実行して、レビュアーはソルを使います。"
        let pairs = [("ワーカー", "worker"), ("ディープシーク", "deepseek"), ("ソル", "sol")]
        let corrected = pairs.reduce(original) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
        let candidates = CorrectionDiffEngine.candidates(from: AutoLearnRevision(original: original, corrected: corrected))
        for (source, destination) in pairs {
            require(candidates.contains { $0.originalText.contains(source) && $0.correctedText.contains(destination) },
                    "Japanese sentence loses \(source) -> \(destination)")
        }
        require(candidates.count == 3, "independent Japanese terms should reach review separately")
        print("PASS all three Japanese transliterations reach review independently")

        let english = CorrectionDiffEngine.candidates(from: AutoLearnRevision(
            original: "Please call Prakash Joshi Pages tomorrow.",
            corrected: "Please call Prakash Joshi Pax tomorrow."
        ))
        require(english.count == 1, "English name correction should stay intact")
        require(english[0].originalText.contains("Prakash Joshi Pages"), "original full name context lost")
        require(english[0].correctedText.contains("Prakash Joshi Pax"), "corrected full name context lost")
        require(CorrectionDiffEngine.candidates(from: AutoLearnRevision(original: original, corrected: original)).isEmpty,
                "unchanged Japanese must not create candidates")
        print("PASS English full-name context and unchanged Japanese are preserved")
    }
}
