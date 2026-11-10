import Foundation

// The standalone harness only needs this policy dependency from AutoLearnTypes.
enum AIProvider: String { case voiceInkRefine; var supportsEnhancement: Bool { true }; var defaultModel: String { "test" } }

@main
struct AutoLearnCorrectionDiffTests {
    static func require(_ condition: Bool, _ message: String) {
        guard condition else { print("FAIL \(message)"); exit(1) }
    }

    static func main() async throws {
        let suite = "VoiceInkMergeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("test-provider", forKey: "AutoLearnDictionaryProvider")
        defaults.set("test-model", forKey: "AutoLearnDictionaryModel")
        defaults.set("manually", forKey: "AutoLearnDictionaryReviewSchedule")
        AutoLearnSettings.registerDefaults(defaults: defaults)
        require(defaults.string(forKey: AutoLearnSettings.aiReviewModeKey) == "manual", "manual-send preference lost")
        require(defaults.string(forKey: AutoLearnSettings.reviewerModelKey) == "test-model", "reviewer model lost")
        print("PASS legacy reviewer and manual-send preferences survive migration")
        let original = "オーケストレーターが準備してからワーカーはディープシークを使って実行して、レビュアーはソルを使います。"
        let pairs = [("ワーカー", "worker"), ("ディープシーク", "deepseek"), ("ソル", "sol")]
        let corrected = pairs.reduce(original) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
        let candidates = CorrectionDiffEngine.candidates(from: AutoLearnRevision(original: original, corrected: corrected), usesAIReviewer: true)
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
        let localID = UUID()
        let local = try await AutoLearnLocalReviewer().review([
            .init(candidateID: localID, originalText: "ギットハブ", correctedText: "GitHub"),
            .init(candidateID: UUID(), originalText: "cats", correctedText: "cat")
        ])
        require(local.count == 1 && local[0].candidateID == localID, "local review loses Japanese pair or learns inflection")
        require(local[0].learningAction == .addReplacementOnly, "new review must not add public products to vocabulary")
        let selection = AutoLearnSettings.ReviewerSelection(providerName: "test", modelName: "test")
        require(AutoLearnReviewEligibility.accepts(source: "ギットハブ", destination: "GitHub",
            aiReviewConfigurationID: selection.configurationID, reviewerSelection: selection), "AI approval should survive matching settings")
        require(!AutoLearnReviewEligibility.accepts(source: "ギットハブ", destination: "GitHub",
            aiReviewConfigurationID: "other", reviewerSelection: selection), "approval must not survive a different reviewer")
        print("PASS local Japanese replacement, inflection rejection and reviewer approval isolation")

    }
}
