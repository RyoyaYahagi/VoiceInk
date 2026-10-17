import Foundation
import OSLog

enum FinalSnapshotDiffEngine {
    private static let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink",
        category: "AutoLearnDiff"
    )

    /// まず貼り付けた範囲の前後を目印にして切り出す（元の方式）。
    /// 目印が見つからない場合は、変更された範囲を直接求める方式で復旧する。
    /// リッチテキストの入力欄（Web 系アプリ）では、不可視の文字が
    /// 入ったり消えたりして目印が一致しなくなることがあるため。
    static func revision(from snapshot: AutoLearnFieldSnapshot) -> AutoLearnRevision? {
        if let revision = anchoredRevision(from: snapshot) {
            return revision
        }
        if let revision = changedSpanRevision(from: snapshot) {
            logger.notice("Auto Learn diff: recovered by changed-span fallback")
            return revision
        }
        return nil
    }

    private static func anchoredRevision(from snapshot: AutoLearnFieldSnapshot) -> AutoLearnRevision? {
        let baseline = snapshot.baselineFieldText as NSString

        guard isValid(snapshot.pastedRange, inUTF16Length: baseline.length) else {
            logger.notice("Auto Learn diff: invalid pasted range")
            return nil
        }
        guard !textIsExactlyEqual(snapshot.baselineFieldText, snapshot.finalFieldText) else {
            logger.notice("Auto Learn diff: baseline equals final")
            return nil
        }

        let baselinePastedText = baseline.substring(with: snapshot.pastedRange)
        guard textIsExactlyEqual(baselinePastedText, snapshot.originalPastedText) else {
            logger.notice("Auto Learn diff: pasted text mismatch")
            return nil
        }

        let beforeRange = NSRange(location: 0, length: snapshot.pastedRange.location)
        let afterLocation = NSMaxRange(snapshot.pastedRange)
        let afterRange = NSRange(
            location: afterLocation,
            length: baseline.length - afterLocation
        )
        let beforeText = baseline.substring(with: beforeRange)
        let afterText = baseline.substring(with: afterRange)

        guard let correctedText = correctedPastedText(
            in: snapshot.finalFieldText,
            beforeText: beforeText,
            afterText: afterText
        ) else {
            logger.notice(
                "Auto Learn diff: anchor lookup failed before=\(beforeText.utf16.count, privacy: .public) after=\(afterText.utf16.count, privacy: .public)"
            )
            return nil
        }
        let normalizedOriginalText = AutoLearnTextNormalizer.accessibilityComparable(
            snapshot.originalPastedText
        )
        let normalizedCorrectedText = AutoLearnTextNormalizer.accessibilityComparable(
            correctedText
        )
        guard !textIsExactlyEqual(normalizedOriginalText, normalizedCorrectedText) else {
            logger.notice("Auto Learn diff: normalized texts are equal")
            return nil
        }

        return AutoLearnRevision(
            original: normalizedOriginalText,
            corrected: normalizedCorrectedText
        )
    }

    /// 変更された範囲を前後の一致部分から直接求める復旧経路。
    /// 貼り付けた範囲と重ならない変更は、貼り付け以外の編集なので採用しない。
    private static func changedSpanRevision(
        from snapshot: AutoLearnFieldSnapshot
    ) -> AutoLearnRevision? {
        let baselineUnits = Array(snapshot.baselineFieldText.utf16)
        let finalUnits = Array(snapshot.finalFieldText.utf16)
        let baselineLength = baselineUnits.count
        let finalLength = finalUnits.count

        guard baselineLength > 0, finalLength > 0 else { return nil }

        var prefix = 0
        while prefix < baselineLength, prefix < finalLength,
            baselineUnits[prefix] == finalUnits[prefix]
        {
            prefix += 1
        }

        var suffix = 0
        while suffix < baselineLength - prefix, suffix < finalLength - prefix,
            baselineUnits[baselineLength - 1 - suffix] == finalUnits[finalLength - 1 - suffix]
        {
            suffix += 1
        }

        let baselineChanged = NSRange(
            location: prefix,
            length: baselineLength - prefix - suffix
        )
        let finalChanged = NSRange(location: prefix, length: finalLength - prefix - suffix)

        guard baselineChanged.length > 0 || finalChanged.length > 0 else { return nil }
        guard NSIntersectionRange(baselineChanged, snapshot.pastedRange).length > 0 else {
            logger.notice("Auto Learn diff: change is outside the pasted range")
            return nil
        }

        let original = (snapshot.baselineFieldText as NSString).substring(with: baselineChanged)
        let corrected = (snapshot.finalFieldText as NSString).substring(with: finalChanged)
        let normalizedOriginal = AutoLearnTextNormalizer.accessibilityComparable(original)
        let normalizedCorrected = AutoLearnTextNormalizer.accessibilityComparable(corrected)

        guard !normalizedOriginal.isEmpty, !normalizedCorrected.isEmpty,
            !textIsExactlyEqual(normalizedOriginal, normalizedCorrected)
        else {
            logger.notice("Auto Learn diff: fallback produced no usable change")
            return nil
        }

        return AutoLearnRevision(original: normalizedOriginal, corrected: normalizedCorrected)
    }

    private static func correctedPastedText(
        in finalText: String,
        beforeText: String,
        afterText: String
    ) -> String? {
        let leftBoundary: String.Index
        if beforeText.isEmpty {
            leftBoundary = finalText.startIndex
        } else {
            let anchor = String(beforeText.suffix(16))
            guard let range = uniqueRange(of: anchor, in: finalText) else { return nil }
            leftBoundary = range.upperBound
        }

        let rightBoundary: String.Index
        if afterText.isEmpty {
            rightBoundary = finalText.endIndex
        } else {
            let anchor = String(afterText.prefix(16))
            guard let range = uniqueRange(of: anchor, in: finalText),
                range.lowerBound >= leftBoundary
            else { return nil }
            rightBoundary = range.lowerBound
        }

        return String(finalText[leftBoundary..<rightBoundary])
    }

    private static func uniqueRange(of value: String, in text: String) -> Range<String.Index>? {
        guard !value.isEmpty,
            let firstRange = text.range(of: value, options: .literal)
        else { return nil }

        let nextSearchStart = text.index(after: firstRange.lowerBound)
        guard nextSearchStart >= text.endIndex
            || text.range(
                of: value,
                options: .literal,
                range: nextSearchStart..<text.endIndex
            ) == nil
        else { return nil }

        return firstRange
    }

    private static func textIsExactlyEqual(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf16.elementsEqual(rhs.utf16)
    }

    private static func isValid(_ range: NSRange, inUTF16Length length: Int) -> Bool {
        range.location != NSNotFound
            && range.location >= 0
            && range.length >= 0
            && range.location <= length
            && range.length <= length - range.location
    }
}
