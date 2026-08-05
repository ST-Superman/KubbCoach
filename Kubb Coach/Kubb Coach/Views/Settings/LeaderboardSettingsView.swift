// LeaderboardSettingsView.swift
// Manage the current device's leaderboard entry: rename or remove it.
//
// Visual re-skin per the design-system audit — standard Settings scaffold
// (ScrollView + paper background + SettingsCard primitives), no raw List.
// The @State/Task plumbing, sheet, confirmation dialog, error alert, and
// rename/delete service calls are preserved verbatim.

import SwiftUI

struct LeaderboardSettingsView: View {
    @AppStorage("leaderboardDisplayName") private var displayName = ""

    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError = false

    private let service: any LeaderboardServiceProtocol = SupabaseLeaderboardService()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if displayName.isEmpty {
                    InlineNavHeader("You're not on the board yet.")
                    notJoinedCard
                        .padding(.horizontal, 16)
                } else {
                    InlineNavHeader("Your name on the board.")
                    entrySection
                    removeSection
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRename, onDismiss: syncNameChange) {
            LeaderboardNameSheet(displayName: $displayName)
        }
        .confirmationDialog(
            "Remove your leaderboard entry?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Entry", role: .destructive) {
                Task { await deleteEntry() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your display name and stats will be permanently deleted from the leaderboard.")
        }
        .alert("Couldn't remove entry", isPresented: $deleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please check your connection and try again, or contact support.")
        }
        .overlay {
            if isDeleting {
                ProgressView()
                    .tint(Color.Kubb.swedishBlue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.Kubb.paper.opacity(0.65).ignoresSafeArea())
            }
        }
    }

    // MARK: - Joined: entry section

    private var entrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsEyebrow("YOUR ENTRY")
                .padding(.horizontal, 16)

            SettingsCard {
                displayNameRow
                Button {
                    showRename = true
                } label: {
                    SettingsRow(
                        icon: "pencil",
                        tint: Color.Kubb.swedishBlue,
                        label: "Change name…"
                    ) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Text("How you appear to other players. Rankings update the next time your stats submit.")
                .font(KubbFont.inter(12.5))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
        }
    }

    /// Custom row (not `SettingsRow`) — leading circle avatar mirrors
    /// `LeaderboardSection.avatarCircle` so the two surfaces rhyme.
    private var displayNameRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.Kubb.swedishBlue.opacity(0.12))
                Text(initials)
                    .font(KubbFont.mono(11, weight: .semibold))
                    .foregroundStyle(Color.Kubb.swedishBlue)
            }
            .frame(width: 32, height: 32)

            Text("Display name")
                .font(KubbFont.inter(15, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(Color.Kubb.text)

            Spacer(minLength: 8)

            Text(displayName)
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.textSec)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }

    // MARK: - Joined: remove section

    private var removeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsCard {
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.Kubb.miss.opacity(0.10))
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.Kubb.miss)
                        }
                        .frame(width: 32, height: 32)

                        Text("Remove leaderboard entry")
                            .font(KubbFont.inter(15, weight: .medium))
                            .tracking(-0.2)
                            .foregroundStyle(Color.Kubb.miss)

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
            .padding(.horizontal, 16)

            Text("Permanently removes your display name and stats from the public leaderboard. Your local training data is not affected.")
                .font(KubbFont.inter(12.5))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Not-joined: empty state

    private var notJoinedCard: some View {
        SettingsCard {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.Kubb.swedishGold.opacity(0.18))
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.Kubb.pbInk)
                }
                .frame(width: 44, height: 44)

                Text("Not on the leaderboard")
                    .font(KubbFont.inter(15, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)

                Text("Complete a training session, then submit your stats from the Records tab to join.")
                    .font(KubbFont.inter(13))
                    .foregroundStyle(Color.Kubb.textSec)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    // MARK: - Helpers

    /// Two-letter initials from the display name, mirroring
    /// `LeaderboardEntry.initials`.
    private var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? ""
        let last  = parts.dropFirst().first.map { String($0.prefix(1)) } ?? ""
        return (first + last).uppercased()
    }

    private func syncNameChange() {
        guard !displayName.isEmpty else { return }
        Task { _ = await service.updateDisplayName(displayName) }
    }

    private func deleteEntry() async {
        isDeleting = true
        let success = await service.deleteEntry()
        isDeleting = false
        if success {
            displayName = ""
        } else {
            deleteError = true
        }
    }
}

#Preview("Joined") {
    NavigationStack {
        LeaderboardSettingsView()
    }
}

#Preview("Not joined") {
    // Clear the stored name so the empty state renders in previews.
    UserDefaults.standard.removeObject(forKey: "leaderboardDisplayName")
    return NavigationStack {
        LeaderboardSettingsView()
    }
}
