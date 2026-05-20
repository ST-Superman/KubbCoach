//
//  ShareCardView.swift
//  Kubb Coach
//
//  Single SwiftUI card used to render every shareable session image.
//  Session-specific content is supplied via `ShareCardData` — see each
//  session type's `shareCardData(...)` extension for the mappers.
//

import SwiftUI

struct ShareCardView: View {
    let data: ShareCardData

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                headerSection
                statsSection
                if !data.personalBests.isEmpty { personalBestsSection }
                dateSection
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .cornerRadius(20)
        .overlay(cardBorder)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("KUBB COACH")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(3)
                .foregroundStyle(.white.opacity(0.7))

            Text(data.mainStat)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(mainStatGradient)

            VStack(spacing: 2) {
                Text(data.subtitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                if let caption = data.subtitleCaption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 6) {
            ForEach(Array(data.statRows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
    }

    @ViewBuilder
    private func rowView(_ row: ShareCardStatRow) -> some View {
        switch row {
        case .single(let label):
            labelView(label)
        case .pair(let a, let b):
            HStack(spacing: 16) {
                labelView(a)
                labelView(b)
            }
        }
    }

    @ViewBuilder
    private func labelView(_ label: ShareCardLabel) -> some View {
        if let tint = label.tint {
            Label(label.text, systemImage: label.icon)
                .foregroundStyle(tint)
        } else {
            Label(label.text, systemImage: label.icon)
        }
    }

    // MARK: - Personal Bests

    private var personalBestsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.Kubb.swedishGold)
                Text("PERSONAL BESTS")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .tracking(2)
            }
            .foregroundStyle(.white.opacity(0.9))

            VStack(spacing: 4) {
                ForEach(data.personalBests, id: \.id) { pb in
                    Text(pb.category.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Kubb.swedishGold.opacity(0.65))
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Date

    private var dateSection: some View {
        Text(data.date, style: .date)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Styling

    private var mainStatGradient: LinearGradient {
        switch data.mainStatTint {
        case .gold:
            return LinearGradient(
                colors: [Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.65)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .dim:
            return LinearGradient(
                colors: [Color.white.opacity(0.7), Color.white.opacity(0.5)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [Color.Kubb.hero, Color.Kubb.card],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.Kubb.swedishGold.opacity(0.3), lineWidth: 1)
    }

    // MARK: - Render

    @MainActor
    func renderImage(width: CGFloat = 340) -> UIImage? {
        let renderer = ImageRenderer(content: self.frame(width: width))
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
