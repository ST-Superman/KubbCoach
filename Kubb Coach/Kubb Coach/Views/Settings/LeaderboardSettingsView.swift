// LeaderboardSettingsView.swift
// Manage the current device's leaderboard entry: rename or remove it.

import SwiftUI

struct LeaderboardSettingsView: View {
    @AppStorage("leaderboardDisplayName") private var displayName = ""

    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError = false

    private let service: any LeaderboardServiceProtocol = SupabaseLeaderboardService()

    var body: some View {
        List {
            if displayName.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not on the leaderboard yet.")
                            .font(.body)
                        Text("Open the Records tab and submit your stats to join.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section("Your Entry") {
                    HStack {
                        Text("Display name")
                        Spacer()
                        Text(displayName)
                            .foregroundStyle(.secondary)
                    }
                    Button("Change name…") {
                        showRename = true
                    }
                }

                Section {
                    Button("Remove leaderboard entry", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("Permanently removes your display name and stats from the public leaderboard. Your local training data is not affected.")
                }
            }
        }
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
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

#Preview {
    NavigationStack {
        LeaderboardSettingsView()
    }
}
