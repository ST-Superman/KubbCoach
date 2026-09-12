// NewMatchView.swift
// Managed-match setup (C1 scorekeeper scope): pick an existing managed opponent
// or name a new one, choose race-to, then create. Creating calls
// `create_managed_player` (when a new name is given) then `create_challenge`,
// which for a managed opponent returns an immediate match; `onCreated` hands the
// new match id back to the root, which pushes `MatchPlayView`.

import SwiftUI

struct NewMatchView: View {
    @Bindable var service: VirtualMatchService
    /// Called with the new match id once the match is created.
    let onCreated: (String) -> Void

    @State private var selectedOpponentId: String?
    @State private var newName: String = ""
    @State private var raceTo: Int = 1

    private let raceToChoices = [1, 2, 3, 5]

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ready when the caller either typed a new name or picked an existing opponent.
    private var canStart: Bool {
        !trimmedName.isEmpty || selectedOpponentId != nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                opponentSection
                raceToSection

                if let err = service.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(Color.Kubb.miss)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                startButton
            }
            .padding(.top, 12)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("New Match")
        .navigationBarTitleDisplayMode(.inline)
        .task { await service.listManagedOpponents() }
    }

    // MARK: - Opponent

    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("OPPONENT")
                .padding(.horizontal, 20)

            SettingsCard {
                // New-opponent name field.
                SettingsRow(
                    icon: "person.badge.plus",
                    tint: Color.Kubb.forestGreen,
                    label: "New opponent"
                ) {
                    TextField("Name", text: $newName)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .frame(maxWidth: 160)
                        .onChange(of: newName) { _, value in
                            if !value.trimmingCharacters(in: .whitespaces).isEmpty {
                                selectedOpponentId = nil
                            }
                        }
                }

                // Existing managed opponents.
                ForEach(service.managedOpponents) { opp in
                    Button {
                        selectedOpponentId = opp.playerId
                        newName = ""
                    } label: {
                        SettingsRow(
                            icon: "person.fill",
                            tint: Color.Kubb.matchAccent,
                            label: opp.displayName
                        ) {
                            if selectedOpponentId == opp.playerId {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.Kubb.matchAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Text("A managed opponent has no account — you keep score for both sides on this device.")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Race to

    private var raceToSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("RACE TO")
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                ForEach(raceToChoices, id: \.self) { n in
                    Button {
                        raceTo = n
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                raceTo == n ? Color.Kubb.matchAccent : Color.Kubb.card,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .foregroundStyle(raceTo == n ? .white : Color.Kubb.text)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Text("First to \(raceTo) game\(raceTo == 1 ? "" : "s") wins the match.")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Button {
            Task {
                let id = await service.createManagedMatch(
                    playerId: trimmedName.isEmpty ? selectedOpponentId : nil,
                    newOpponentName: trimmedName.isEmpty ? nil : trimmedName,
                    raceTo: raceTo
                )
                if let id { onCreated(id) }
            }
        } label: {
            HStack(spacing: 8) {
                if service.isBusy { ProgressView().tint(.white) }
                Text(service.isBusy ? "Creating…" : "Start match")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                (canStart ? Color.Kubb.matchAccent : Color.Kubb.textSec).opacity(canStart ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
        }
        .disabled(!canStart || service.isBusy)
        .padding(.horizontal, 16)
    }
}
