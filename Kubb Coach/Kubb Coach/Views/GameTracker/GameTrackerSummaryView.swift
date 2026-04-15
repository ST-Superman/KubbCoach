//
//  GameTrackerSummaryView.swift
//  Kubb Coach
//
//  Post-game summary: result, stats, and turn history for a completed game.
//

import SwiftUI
import SwiftData

struct GameTrackerSummaryView: View {
    let session: GameSession
    /// Called when the user taps Done. When nil, falls back to the environment dismiss action.
    var onDone: (() -> Void)? = nil
    /// When false (e.g. viewing from history), shows the standard back button instead.
    var isPostGame: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    private var sorted: [GameTurn] { session.sortedTurns }
    private var userTurns: [GameTurn] { session.userTurns }
    private var analysis: GamePerformanceAnalysis { GamePerformanceAnalyzer.analyze(session: session) }

    private var displayWinnerName: String {
        guard let winner = session.winnerSide else { return "Game Abandoned" }
        return session.name(for: winner)
    }

    private var userWon: Bool {
        session.userWon ?? true
    }

    private var endReasonText: String {
        switch GameEndReason(rawValue: session.endReason ?? "") {
        case .kingKnocked: return "King knocked to end the game"
        case .earlyKing: return "King knocked early — rules violation"
        case .abandoned: return "Game was abandoned"
        case nil: return ""
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                resultHeader
                statsGrid
                if analysis.hasAnyData { performanceBreakdownSection }
                turnHistorySection
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(DesignGradients.stats.ignoresSafeArea())
        .navigationTitle("Game Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isPostGame)
        .toolbar {
            if isPostGame {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if session.isComplete && session.endReason != GameEndReason.abandoned.rawValue {
                        Button { showShareSheet = true } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button("Done") { onDone?() ?? dismiss() }
                        .fontWeight(.semibold)
                }
            } else if session.isComplete && session.endReason != GameEndReason.abandoned.rawValue {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            GameShareSheetView(session: session)
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        VStack(spacing: 10) {
            // Icon — crown for win, flag for phantom, x for abandoned
            resultIcon

            Text(displayWinnerName + (session.winnerSide != nil ? " Wins" : ""))
                .titleStyle(tracking: 0.3)
                .multilineTextAlignment(.center)

            if !endReasonText.isEmpty {
                Text(endReasonText)
                    .descriptionStyle()
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                // Mode pill
                Text(session.gameMode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(KubbColors.swedishBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(KubbColors.swedishBlue.opacity(0.1)))

                Text(session.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // XP earned badge (only shown for non-abandoned, post-game summaries)
            if isPostGame && session.xpEarned > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishGold)
                    Text("+\(Int(session.xpEarned.rounded())) XP")
                        .font(.caption.bold())
                        .foregroundStyle(KubbColors.swedishGold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(KubbColors.swedishGold.opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity)
        .compactCardPadding
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .fill(Color.adaptiveBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                        .strokeBorder(resultAccentColor.opacity(0.2), lineWidth: 1.5)
                )
        )
        .cardShadow()
    }

    private var resultIcon: some View {
        ZStack {
            Circle()
                .fill(resultAccentColor.opacity(0.12))
                .frame(width: 64, height: 64)
            Image(systemName: resultIconName)
                .font(.system(size: 28))
                .foregroundStyle(resultAccentColor)
        }
    }

    private var resultIconName: String {
        guard session.winnerSide != nil else { return "flag.slash.fill" }
        if session.gameMode == .phantom { return "crown.fill" }
        return userWon ? "crown.fill" : "flag.2.crossed.fill"
    }

    private var resultAccentColor: Color {
        guard session.winnerSide != nil else { return .secondary }
        if session.gameMode == .phantom { return KubbColors.swedishGold }
        return userWon ? KubbColors.forestGreen : KubbColors.swedishBlue
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(KubbColors.swedishBlue)
                Text(session.gameMode == .competitive ? "Your Performance" : "Game Stats")
                    .headlineStyle()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCell(
                    label: "Total Turns",
                    value: "\(userTurns.count)",
                    icon: "arrow.clockwise",
                    valueColor: .primary
                )
                statCell(
                    label: "Avg Progress",
                    value: formattedAvg,
                    icon: "chart.bar.fill",
                    valueColor: avgColor
                )
                statCell(
                    label: "Best Turn",
                    value: bestTurnLabel,
                    icon: "star.fill",
                    valueColor: KubbColors.forestGreen
                )
                statCell(
                    label: "Worst Turn",
                    value: worstTurnLabel,
                    icon: "arrow.down.circle.fill",
                    valueColor: KubbColors.miss
                )
                statCell(
                    label: "Advantage Lines",
                    value: "\(session.advantageLineTurns.count)",
                    icon: "exclamationmark.triangle.fill",
                    valueColor: session.advantageLineTurns.isEmpty ? .primary : KubbColors.phase4m
                )
                statCell(
                    label: "King Shots",
                    value: "\(session.kingOpportunityTurns.count)",
                    icon: "crown.fill",
                    valueColor: KubbColors.swedishGold
                )
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    private func statCell(
        label: String,
        value: String,
        icon: String,
        valueColor: Color
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(valueColor.opacity(0.8))

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .dataCard()
    }

    // MARK: - Performance Breakdown

    private var performanceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.subheadline)
                    .foregroundStyle(KubbColors.swedishBlue)
                Text("Performance Breakdown")
                    .headlineStyle()
            }

            // Metric tiles row
            HStack(spacing: 10) {
                fieldEfficiencyTile
                eightMeterTile
            }

            // Practice recommendation
            if let rec = recommendationContent {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .font(.subheadline)
                            .foregroundStyle(KubbColors.phase8m)
                        Text("Practice Recommendation")
                            .font(.subheadline.weight(.semibold))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(rec.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .descriptionStyle()
                                Text(bullet)
                                    .descriptionStyle()
                            }
                        }
                    }
                }
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    private var fieldEfficiencyTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Field Clearing")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let eff = analysis.fieldEfficiency {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", eff))
                        .font(.title2.bold())
                        .foregroundStyle(eff >= 2.0 ? KubbColors.forestGreen : KubbColors.miss)
                    Text("kubbs/baton")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !analysis.isFieldDataComplete && analysis.fieldTurnsEligible > 0 {
                    Text("Based on \(analysis.fieldTurnsWithData) of \(analysis.fieldTurnsEligible) turns")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("—")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                Text("No data recorded")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.adaptiveBackground)
        )
    }

    private var eightMeterTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("8m Throws")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let rate = analysis.eightMeterHitRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int((rate * 100).rounded()))%")
                        .font(.title2.bold())
                        .foregroundStyle(rate >= 0.40 ? KubbColors.forestGreen : KubbColors.miss)
                    Text("hit rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(analysis.eightMeterAttempts) attempts")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                Text("No data recorded")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.adaptiveBackground)
        )
    }

    private struct RecommendationContent {
        let bullets: [String]
    }

    private var recommendationContent: RecommendationContent? {
        let areas = analysis.recommendations
        guard !areas.contains(.insufficientData) else { return nil }

        if areas.contains(.solidPerformance) {
            return RecommendationContent(bullets: [
                "Strong performance this game — field clearing and 8m accuracy both on target."
            ])
        }

        var bullets: [String] = []

        if areas.contains(.inkasting) || areas.contains(.blasting) {
            let eff = analysis.fieldEfficiency.map { String(format: "%.1f kubbs/baton", $0) } ?? "below target"
            bullets.append(
                "Field clearing was \(eff) (goal: 2+/baton) — practice Inkasting for tighter kubb placement and 4m Blasting for field accuracy."
            )
        }

        if areas.contains(.eightMeter) {
            let rate = analysis.eightMeterHitRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "below target"
            bullets.append(
                "8m throwing was \(rate) this game (goal: 40%+) — more 8-Meter practice sessions recommended."
            )
        }

        return bullets.isEmpty ? nil : RecommendationContent(bullets: bullets)
    }

    // MARK: - Turn History

    private var turnHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.subheadline)
                    .foregroundStyle(KubbColors.swedishBlue)
                Text("Turn History")
                    .headlineStyle()
            }

            if sorted.isEmpty {
                Text("No turns were recorded.")
                    .descriptionStyle()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(sorted, id: \.id) { turn in
                        turnRow(turn)
                    }
                }
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    private func turnRow(_ turn: GameTurn) -> some View {
        let side = turn.attackingGameSide
        let sideName = session.name(for: side)
        let isUserTurn: Bool = {
            if session.gameMode == .phantom { return true }
            return side == session.userGameSide
        }()

        return HStack(spacing: 12) {
            Text("\(turn.turnNumber)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 20, alignment: .trailing)

            Text(sideName)
                .font(.subheadline)
                .foregroundStyle(isUserTurn ? KubbColors.swedishBlue : .secondary)
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)

            Spacer()

            if turn.wasEarlyKing {
                Label("Early King", systemImage: "crown.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(KubbColors.miss)
            } else {
                Text(formattedProgress(turn.progress))
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(progressColor(turn.progress))
                    .frame(width: 44, alignment: .trailing)
            }

            if turn.kingThrown && !turn.wasEarlyKing {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(KubbColors.swedishGold)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isUserTurn ? KubbColors.swedishBlue.opacity(0.04) : Color.clear)
        )
    }

    // MARK: - Computed helpers

    private var formattedAvg: String {
        guard !userTurns.isEmpty else { return "—" }
        let avg = session.averageUserProgress
        return String(format: avg >= 0 ? "+%.1f" : "%.1f", avg)
    }

    private var avgColor: Color {
        guard !userTurns.isEmpty else { return .secondary }
        return session.averageUserProgress >= 0 ? KubbColors.forestGreen : KubbColors.miss
    }

    private var bestTurnLabel: String {
        guard let best = session.bestUserTurn else { return "—" }
        return formattedProgress(best.progress)
    }

    private var worstTurnLabel: String {
        guard let worst = session.worstUserTurn else { return "—" }
        return formattedProgress(worst.progress)
    }

    private func formattedProgress(_ n: Int) -> String {
        n > 0 ? "+\(n)" : "\(n)"
    }

    private func progressColor(_ n: Int) -> Color {
        if n < 0 { return KubbColors.miss }
        if n == 0 { return .secondary }
        return KubbColors.forestGreen
    }
}

// MARK: - Game Share Sheet

struct GameShareSheetView: View {
    let session: GameSession
    @Environment(\.dismiss) private var dismiss
    @Query private var allPersonalBests: [PersonalBest]

    private var sessionPersonalBests: [PersonalBest] {
        allPersonalBests.filter { $0.sessionId == session.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                GameShareCardView(session: session, newPersonalBests: sessionPersonalBests)
                    .padding(.horizontal)

                Button {
                    shareImage()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Image")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KubbColors.forestGreen)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Share Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func shareImage() {
        let cardView = GameShareCardView(session: session, newPersonalBests: sessionPersonalBests).frame(width: 350)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = presentingVC.view
            presentingVC.present(activityVC, animated: true)
        }
    }
}
