import Foundation

struct TranscriptionOutputFilter {
    private static let hallucinationPatterns = [
        #"\[.*?\]"#,  // []
        #"\(.*?\)"#,  // ()
        #"\{.*?\}"#,  // {}
    ]

    static func filter(_ text: String) -> String {
        var filteredText = text

        // Remove <TAG>...</TAG> blocks
        let tagBlockPattern = #"<([A-Za-z][A-Za-z0-9:_-]*)[^>]*>[\s\S]*?</\1>"#
        if let regex = try? NSRegularExpression(pattern: tagBlockPattern) {
            let range = NSRange(filteredText.startIndex..., in: filteredText)
            filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
        }

        // Remove bracketed hallucinations
        for pattern in hallucinationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(
                    in: filteredText, options: [], range: range, withTemplate: "")
            }
        }

        // Remove configured filler words. An empty list is naturally a no-op.
        // 長い表記から処理し、短いフィラーが長いフィラーの一部だけを消すのを防ぐ。
        let fillerWords = FillerWordManager.shared.fillerWords.sorted { $0.count > $1.count }
        for fillerWord in fillerWords {
            guard let pattern = fillerPattern(for: fillerWord) else { continue }
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(
                    in: filteredText, options: [], range: range, withTemplate: "")
            }
        }

        // Clean whitespace
        filteredText = filteredText.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)

        return filteredText
    }

    /// フィラー 1 件を削除するための正規表現を作る。判定できない場合は nil。
    ///
    /// 英語のように空白で語を区切る言語では語境界 `\b` を使う。日本語・中国語・
    /// 韓国語・タイ語のように空白で語を区切らない言語では、`\b` は文字と文字の
    /// 間を境界と見なさないため一致しない（例: `\bえーと\b` は「えーと、」に一致しない）。
    /// 代わりに「直後が読点ならそれを含めて削除」「直後が区切り記号か文末なら削除」
    /// という条件にする。これにより「あの件」の「あの」のような複合語の一部や、
    /// 読点の付かない語中の文字列を消さない。
    private static func fillerPattern(for fillerWord: String) -> String? {
        let trimmed = fillerWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: trimmed)

        guard usesWordBoundaries(for: trimmed) else {
            // 直後が読点ならそれを含めて削除する。読点が無い場合も、直後が区切り
            // 記号か文末であれば削除する。そのとき直前の読点も一緒に消し、
            // 「…ここまで、えーと」のように読点だけが残るのを防ぐ。
            return "(?:\(escaped))[、,，]|[、,，]?(?:\(escaped))(?=[\(delimiterCharacters)]|$)"
        }

        return "\\b\(escaped)\\b[,.]?"
    }

    /// 空白で語を区切らない言語で、フィラーの直後に置かれたときに削除を許可する文字。
    private static let delimiterCharacters = #"\s。．.！!？?；;：:）)」』】、,，"#

    /// 空白で語を区切る言語のフィラーかどうかを判定する。
    private static func usesWordBoundaries(for fillerWord: String) -> Bool {
        let nonSpacedScripts: [ClosedRange<UInt32>] = [
            0x0E00...0x0E7F,  // タイ文字
            0x3040...0x309F,  // ひらがな
            0x30A0...0x30FF,  // カタカナ
            0x31F0...0x31FF,  // カタカナ拡張
            0x3400...0x4DBF,  // CJK 統合漢字拡張 A
            0x4E00...0x9FFF,  // CJK 統合漢字
            0xAC00...0xD7AF,  // ハングル音節
            0xF900...0xFAFF,  // CJK 互換漢字
        ]
        return !fillerWord.unicodeScalars.contains { scalar in
            nonSpacedScripts.contains { $0.contains(scalar.value) }
        }
    }
}
