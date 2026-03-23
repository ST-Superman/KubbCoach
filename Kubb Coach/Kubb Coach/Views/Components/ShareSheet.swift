//
//  ShareSheet.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/22/26.
//

import SwiftUI
import UIKit

/// SwiftUI wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?

    init(items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Helper to create shareable text for personal bests
extension PersonalBest {
    /// Generate shareable text for social media
    /// - Parameter formatter: Formatter to use for value display
    /// - Returns: Formatted text suitable for sharing
    func shareableText(formatter: PersonalBestFormatter) -> String {
        let value = formatter.format(value: self.value, for: self.category)
        let date = self.achievedAt.formatted(date: .long, time: .omitted)

        return """
        🏆 New Personal Best!
        \(category.displayName): \(value)
        Achieved on \(date)

        #KubbCoach #Kubb #Training
        """
    }
}
