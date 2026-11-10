import Foundation

enum AutoLearnReviewEligibility {
    static func accepts(source: String?, destination: String, aiReviewConfigurationID: String? = nil,
        reviewerSelection: AutoLearnSettings.ReviewerSelection? = AutoLearnSettings.reviewerSelection) -> Bool {
        if let aiReviewConfigurationID {
            guard let selection = reviewerSelection,
                aiReviewConfigurationID == selection.configurationID
                    || aiReviewConfigurationID == selection.legacyConfigurationID else { return false }
            return AutoLearnLocalReviewPolicy.fitsLimits(source: source, destination: destination)
        }
        return reviewerSelection == nil
            && AutoLearnLocalReviewPolicy.accepts(source: source, destination: destination)
    }
}

