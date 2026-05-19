//
//  CoachingTipCard.swift
//  Kubb Coach
//
//  Reusable card displaying a curated coaching tip with inline attribution.
//  Tapping the card presents `CoachingTipSourceSheet` with the full quote
//  and source link.
//

import SwiftUI

struct CoachingTipCard: View {
    let tip: CoachingTip
    /// Accent color to tint the icon, label, and border. Defaults to swedishGold
    /// — pass a phase color (e.g. `Color.Kubb.phase4m`) when the surrounding
    /// surface is phase-specific.
    var accent: Color = Color.Kubb.swedishGold

    @State private var showSourceSheet = false

    var body: some View {
        Button {
            showSourceSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                header
                Text(tip.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.Kubb.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                footer
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: KubbRadius.xl)
                    .strokeBorder(accent.opacity(0.2), lineWidth: 1)
            )
            .kubbCardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pro tip from \(tip.attributionShort). \(tip.body)")
        .accessibilityHint("Double-tap to see the original quote and source.")
        .sheet(isPresented: $showSourceSheet) {
            CoachingTipSourceSheet(tip: tip, accent: accent)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundStyle(accent)
            Text("PRO TIP")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundStyle(Color.Kubb.textSec)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Color.Kubb.textTer)
        }
    }

    private var footer: some View {
        Text("— \(tip.attributionShort)")
            .font(.caption)
            .italic()
            .foregroundStyle(Color.Kubb.textSec)
    }
}

#Preview("Magazine quote") {
    let tip = CoachingTip(
        id: "ink-crash-the-plane",
        category: .inkasting,
        subcategory: "release-angle",
        body: "Crash the plane, don't land it — angle the kubb's nose down so it digs into the ground rather than tumbling away.",
        quote: "When drilling a kubb, don't land the shuttle, you want to crash the plane.",
        attributionShort: "Josh Feathers",
        attributionLong: "Josh Feathers, 2011 U.S. Champion (Knockerheads)",
        sourceTitle: "Kubbnation Magazine 2012, \"The Drill\" article (p. 28)",
        sourceURL: nil,
        tags: ["release", "angle"]
    )
    return CoachingTipCard(tip: tip, accent: Color.Kubb.forestGreen)
        .padding()
        .background(Color.Kubb.paper)
}

#Preview("Web source with URL") {
    let tip = CoachingTip(
        id: "8m-180-rotation",
        category: .eightMeter,
        subcategory: "rotation",
        body: "Aim for a clean 180-degree end-over-end rotation on every baton. Consistency in rotation matters far more than how hard you throw.",
        quote: nil,
        attributionShort: "Tyrstre Kubb",
        attributionLong: "Kubb Tips, Strategies, and Rules — tyrstrekubb.com",
        sourceTitle: "Kubb Tips, Strategies, and Rules",
        sourceURL: URL(string: "https://www.tyrstrekubb.com/tips-rules"),
        tags: ["rotation"]
    )
    return CoachingTipCard(tip: tip, accent: Color.Kubb.swedishBlue)
        .padding()
        .background(Color.Kubb.paper)
}
