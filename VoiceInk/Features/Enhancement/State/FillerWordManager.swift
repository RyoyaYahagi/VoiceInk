import Foundation

class FillerWordManager: ObservableObject {
    static let shared = FillerWordManager()

    static let defaultFillerWords = [
        // 英語（空白で語を区切る言語）
        "uh", "um", "uhm", "umm", "uhh", "uhhh",
        "hmm", "hm", "mmm", "mm", "mh", "ehh",
        // 日本語（空白で語を区切らない言語）。表記の揺れは個別に列挙する。
        "えーと", "えーっと", "ええと", "えっと",
        "あのー", "あのね", "あの",
        "うーん", "んー", "んっと",
        "そのー", "その",
        "えー", "あー",
        "まあ", "まー",
        "なんか", "なんというか", "なんていうか",
        "っていうか", "ていうか",
    ]

    private let fillerWordsKey = "FillerWords"

    @Published var fillerWords: [String] {
        didSet {
            UserDefaults.standard.set(fillerWords, forKey: fillerWordsKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: fillerWordsKey) {
            self.fillerWords = saved
        } else {
            self.fillerWords = Self.defaultFillerWords
        }
    }

    func addWord(_ word: String) -> Bool {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        guard !fillerWords.contains(where: { $0.lowercased() == normalized }) else { return false }
        fillerWords.append(normalized)
        return true
    }

    func removeWord(_ word: String) {
        fillerWords.removeAll { $0.lowercased() == word.lowercased() }
    }

}
