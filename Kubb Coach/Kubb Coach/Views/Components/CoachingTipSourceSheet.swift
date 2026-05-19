//
//  CoachingTipSourceSheet.swift
//  Kubb Coach
//
//  Detail sheet shown when a `CoachingTipCard` is tapped: full verbatim quote
//  (if one exists), expanded attribution, source title, and an "Open source"
//  button when a URL is available.
//

import SwiftUI

struct CoachingTipSourceSheet: View {
    let tip: CoachingTip
    var accent: Color = Color.Kubb.swedishGold

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let quote = tip.quote {
                        quoteBlock(quote)
                    } else {
                        bodyBlock
                    }

                    attributionBlock
                    sourceBlock
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.Kubb.paper)
            .navigationTitle("Pro Tip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func quoteBlock(_ quote: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundStyle(accent)
            Text("\u{201C}\(quote)\u{201D}")
                .font(.title3)
                .italic()
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)

            if !tip.body.isEmpty && tip.body != quote {
                Text(tip.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private var bodyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title)
                .foregroundStyle(accent)
            Text(tip.body)
                .font(.title3)
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var attributionBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ATTRIBUTED TO")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundStyle(Color.Kubb.textTer)
            Text(tip.attributionLong)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCE")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundStyle(Color.Kubb.textTer)
            Text(tip.sourceTitle)
                .font(.subheadline)
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)

            if let url = tip.sourceURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open source")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(accent)
                }
                .padding(.top, 4)
            }
        }
    }
}

#Preview("With quote") {
    CoachingTipSourceSheet(
        tip: CoachingTip(
            id: "ink-crash-the-plane",
            category: .inkasting,
            subcategory: "release-angle",
            body: "Crash the plane, don't land it — angle the kubb's nose down so it digs into the ground rather than tumbling away.",
            quote: "When drilling a kubb, don't land the shuttle, you want to crash the plane.",
            attributionShort: "Josh Feathers",
            attributionLong: "Josh Feathers, 2011 U.S. Champion (Knockerheads)",
            sourceTitle: "Kubbnation Magazine 2012, \"The Drill\" article (p. 28)",
            sourceURL: nil,
            tags: []
        ),
        accent: Color.Kubb.forestGreen
    )
}

#Preview("Web tip with URL") {
    CoachingTipSourceSheet(
        tip: CoachingTip(
            id: "8m-180-rotation",
            category: .eightMeter,
            subcategory: "rotation",
            body: "Aim for a clean 180-degree end-over-end rotation on every baton. Consistency in rotation matters far more than how hard you throw.",
            quote: nil,
            attributionShort: "Tyrstre Kubb",
            attributionLong: "Kubb Tips, Strategies, and Rules — tyrstrekubb.com",
            sourceTitle: "Kubb Tips, Strategies, and Rules",
            sourceURL: URL(string: "https://www.tyrstrekubb.com/tips-rules"),
            tags: []
        ),
        accent: Color.Kubb.swedishBlue
    )
}
