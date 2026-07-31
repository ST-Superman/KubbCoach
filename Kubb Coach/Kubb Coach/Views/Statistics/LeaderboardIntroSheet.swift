//
//  LeaderboardIntroSheet.swift
//  Kubb Coach
//
//  Created by Claude Code on 7/31/26.
//
//  A one-time, contextual notice shown after a user completes a leaderboard-eligible
//  training session (8m / 4m blasting / inkasting). It explains where the leaderboard
//  lives, how submission works, and the anonymous privacy model, then offers a
//  "Join now" CTA that reuses the existing LeaderboardNameSheet.
//

import SwiftUI

// MARK: - Intro sheet

struct LeaderboardIntroSheet: View {
    /// Bound to the persisted leaderboard display name so "Join now" can set it directly.
    @Binding var displayName: String
    @Environment(\.dismiss) private var dismiss

    @State private var showNameSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KubbSpacing.xl) {
                    header

                    VStack(spacing: KubbSpacing.l) {
                        infoRow(
                            icon: "trophy.fill",
                            title: "Find it in Records",
                            detail: "Open the Records tab and switch to Leaderboard. Players are ranked by mode — 8m, 4m blasting, and inkasting."
                        )
                        infoRow(
                            icon: "arrow.up.circle.fill",
                            title: "Submits automatically",
                            detail: "Once you pick a display name, your results submit on their own. Only aggregated stats — accuracy, streaks, and scores — are shared, never your individual throws."
                        )
                        infoRow(
                            icon: "lock.fill",
                            title: "Anonymous by design",
                            detail: "There's no account or sign-in. You appear only as the display name you choose — never your real name, email, or identity. You can rename or remove your entry anytime in Settings."
                        )
                    }
                    .padding(.horizontal, KubbSpacing.l)
                }
                .padding(.top, KubbSpacing.xl)
                .padding(.bottom, KubbSpacing.xxxl)
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.top, KubbSpacing.m)
                    .padding(.bottom, KubbSpacing.s)
                    .background(Color.Kubb.paper.ignoresSafeArea())
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showNameSheet, onDismiss: {
            // Whether or not they set a name, the intro's job is done.
            dismiss()
        }) {
            LeaderboardNameSheet(displayName: $displayName)
        }
    }

    private var header: some View {
        VStack(spacing: KubbSpacing.m) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.Kubb.swedishGold)

            Text("Compete on the\nLeaderboard")
                .font(KubbFont.fraunces(30, weight: .medium, italic: true))
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.Kubb.text)

            Text("Nice session — that one counts toward the global rankings.")
                .font(KubbFont.inter(15, weight: .medium))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KubbSpacing.l)
        }
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: KubbSpacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: KubbRadius.m, style: .continuous)
                    .fill(Color.Kubb.swedishBlue.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.Kubb.swedishBlue)
            }

            VStack(alignment: .leading, spacing: KubbSpacing.xs) {
                Text(title)
                    .font(KubbFont.inter(15, weight: .bold))
                    .foregroundStyle(Color.Kubb.text)
                Text(detail)
                    .font(KubbFont.inter(13, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: KubbSpacing.s) {
            Button {
                HapticFeedbackService.shared.buttonTap()
                showNameSheet = true
            } label: {
                Text("Join now")
                    .font(KubbFont.inter(13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.Kubb.midnightNavy)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("Maybe later")
                    .font(KubbFont.inter(13, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Trigger modifier

/// Presents `LeaderboardIntroSheet` once, the first time the user lands on a
/// leaderboard-eligible session-complete screen without having seen it.
private struct LeaderboardIntroModifier: ViewModifier {
    let session: TrainingSession

    @AppStorage("hasSeenLeaderboardIntro") private var hasSeenLeaderboardIntro = false
    @AppStorage("leaderboardDisplayName") private var leaderboardDisplayName = ""

    @State private var showIntro = false

    private static let eligiblePhases: Set<TrainingPhase> = [
        .eightMeters, .fourMetersBlasting, .inkastingDrilling
    ]

    func body(content: Content) -> some View {
        content
            .task {
                // Small delay so the intro doesn't collide with the completion
                // screen's level-up / milestone / personal-best celebrations.
                try? await Task.sleep(nanoseconds: 700_000_000)
                evaluate()
            }
            .sheet(isPresented: $showIntro) {
                LeaderboardIntroSheet(displayName: $leaderboardDisplayName)
            }
            .onChange(of: showIntro) { _, isShowing in
                // Once presented, never show again — regardless of how it's dismissed.
                if isShowing { hasSeenLeaderboardIntro = true }
            }
    }

    private func evaluate() {
        guard !hasSeenLeaderboardIntro else { return }
        guard Self.eligiblePhases.contains(session.safePhase) else { return }

        // Users who already joined the leaderboard clearly know about it — skip silently.
        if !leaderboardDisplayName.trimmingCharacters(in: .whitespaces).isEmpty {
            hasSeenLeaderboardIntro = true
            return
        }

        showIntro = true
    }
}

extension View {
    /// Shows the one-time leaderboard intro after a completed, eligible session.
    func leaderboardIntroPrompt(for session: TrainingSession) -> some View {
        modifier(LeaderboardIntroModifier(session: session))
    }
}
