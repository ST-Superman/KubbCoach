//
//  BlastingRoundCompletionView.swift
//  Kubb Coach
//
//  Final-round result hero shown after round 9 of a blasting session.
//  Visual matches the V1A round-result spec; primary CTA proceeds to the
//  shared SessionCompleteView (Recap).
//

import SwiftUI
import SwiftData

struct BlastingRoundCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let session: TrainingSession
    let round: TrainingRound
    let sessionManager: TrainingSessionManager
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var showSessionComplete = false

    var body: some View {
        ZStack {
            KubbColors.activeBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header eyebrow
                HStack {
                    Text("ROUND \(round.roundNumber) COMPLETE · FINAL")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(KubbColors.activeTextFaint)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Hero
                VStack(spacing: 8) {
                    Text("ROUND SCORE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(KubbColors.activeTextFaint)
                        .textCase(.uppercase)

                    Text(scoreText)
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .tracking(-3)
                        .foregroundStyle(KubbColors.scoreColor(round.score))
                        .shadow(
                            color: colorScheme == .dark
                                ? KubbColors.scoreColor(round.score).opacity(0.3)
                                : .clear,
                            radius: 20
                        )
                        .monospacedDigit()

                    Text(golfTerm(for: round.score))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(KubbColors.scoreColor(round.score).opacity(0.85))

                    Text("\(round.totalKubbsKnockedDown)/\(round.targetKubbCount ?? 0) kubbs cleared")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(KubbColors.activeTextDim)
                        .padding(.top, 4)

                    // Per-throw kubb-count chips
                    HStack(spacing: 6) {
                        ForEach(round.throwRecords.sorted { $0.throwNumber < $1.throwNumber }) { record in
                            throwResultChip(for: record)
                        }
                    }
                    .padding(.top, 20)

                    // Session total summary
                    if let total = session.totalSessionScore {
                        let signed = total > 0 ? "+\(total)" : "\(total)"
                        HStack(spacing: 6) {
                            Text("SESSION TOTAL")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1.4)
                                .foregroundStyle(KubbColors.activeTextFaint)
                            Text(signed)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(KubbColors.scoreColor(total))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(KubbColors.activeSurfaceTinted)
                        .overlay(
                            Capsule().strokeBorder(KubbColors.activeBorderSoft, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .padding(.top, 18)
                    }
                }

                Spacer()

                // Edit Round (secondary)
                Button {
                    round.completedAt = nil
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit Round")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KubbColors.activeTextDim)
                }
                .padding(.bottom, 12)

                // Primary CTA
                Button {
                    Task { @MainActor in
                        await sessionManager.completeSession()
                        showSessionComplete = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("VIEW RESULTS")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(1.5)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(KubbColors.swedishBlueDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: KubbColors.swedishBlueDeep.opacity(0.27), radius: 12, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showSessionComplete) {
            BlastingSessionCompleteView(
                session: session,
                sessionManager: sessionManager,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        }
    }

    @ViewBuilder
    private func throwResultChip(for record: ThrowRecord) -> some View {
        let kubbs = record.kubbsKnockedDown ?? 0
        let isHit = kubbs > 0
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isHit ? Color.Kubb.forestGreen : Color.Kubb.phasePC)
                .frame(width: 22, height: 22)
            Text("\(kubbs)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
        }
    }

    private var scoreText: String {
        round.score > 0 ? "+\(round.score)" : "\(round.score)"
    }

    private func golfTerm(for score: Int) -> String {
        switch score {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        default: return "Triple+"
        }
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session = TrainingSession(phase: .fourMetersBlasting, sessionType: .blasting, configuredRounds: 9, startingBaseline: .north)
    @Previewable @State var round: TrainingRound = {
        let r = TrainingRound(roundNumber: 9, targetBaseline: .north)
        for i in 1...6 {
            let t = ThrowRecord(throwNumber: i, result: .hit, targetType: .baselineKubb)
            t.kubbsKnockedDown = Int.random(in: 0...3)
            r.throwRecords.append(t)
        }
        return r
    }()
    @Previewable @State var selectedTab: AppTab = .lodge
    @Previewable @State var navigationPath = NavigationPath()

    round.session = session
    session.rounds = [round]

    return NavigationStack {
        BlastingRoundCompletionView(
            session: session,
            round: round,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
}
