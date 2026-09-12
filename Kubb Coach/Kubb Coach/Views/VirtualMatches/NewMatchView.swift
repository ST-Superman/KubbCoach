// NewMatchView.swift
// Match setup. Two paths from one screen:
//  • Scorekeeper opponent (a managed player, or a new name) → `create_challenge`
//    returns an immediate match; `onCreated` hands the id back to push MatchPlayView.
//  • Challenge an account → `create_challenge` returns a pending challenge; we show a
//    "sent" confirmation and pop back to the hub (the opponent accepts on their device).

import SwiftUI

struct NewMatchView: View {
    @Bindable var service: VirtualMatchService
    /// Called with the new match id once an immediate (scorekeeper) match is created.
    let onCreated: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOpponent: Opponent?
    @State private var newName: String = ""
    @State private var raceTo: Int = 1
    @State private var challengeSentTo: String?

    private let raceToChoices = [1, 2, 3, 5]

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ready when the caller typed a new name or picked an existing opponent.
    private var canStart: Bool {
        !trimmedName.isEmpty || selectedOpponent != nil
    }

    /// True when the chosen opponent is a real account (→ send a challenge, not score).
    private var isChallenge: Bool {
        trimmedName.isEmpty && selectedOpponent?.kind == .account
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let name = challengeSentTo {
                challengeSentConfirmation(name)
            } else {
                VStack(spacing: 22) {
                    scorekeeperSection
                    if !service.accountOpponents.isEmpty { accountSection }
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
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("New Match")
        .navigationBarTitleDisplayMode(.inline)
        .task { await service.loadOpponents() }
    }

    private func select(_ opp: Opponent) {
        selectedOpponent = opp
        newName = ""
    }

    private func isSelected(_ opp: Opponent) -> Bool {
        selectedOpponent?.playerId == opp.playerId
    }

    // MARK: - Scorekeeper opponent (managed)

    private var scorekeeperSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("SCOREKEEPER OPPONENT")
                .padding(.horizontal, 20)

            SettingsCard {
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
                                selectedOpponent = nil
                            }
                        }
                }

                ForEach(service.managedOpponents) { opp in
                    Button { select(opp) } label: {
                        SettingsRow(icon: "person.fill", tint: Color.Kubb.matchAccent, label: opp.displayName) {
                            if isSelected(opp) { checkmark }
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

    // MARK: - Challenge an account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("CHALLENGE AN ACCOUNT")
                .padding(.horizontal, 20)

            SettingsCard {
                ForEach(service.accountOpponents) { opp in
                    Button { select(opp) } label: {
                        SettingsRow(
                            icon: "at.circle.fill",
                            tint: Color.Kubb.matchAccent,
                            label: opp.displayName,
                            subtitle: opp.handle.map { "@\($0)" }
                        ) {
                            if isSelected(opp) { checkmark }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Text("They play their own side, live, on their device. They'll get the challenge to accept.")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
                .padding(.horizontal, 20)
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.Kubb.matchAccent)
    }

    // MARK: - Race to

    private var raceToSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("RACE TO")
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                ForEach(raceToChoices, id: \.self) { n in
                    Button { raceTo = n } label: {
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
        Button { Task { await start() } } label: {
            HStack(spacing: 8) {
                if service.isBusy { ProgressView().tint(.white) }
                Text(ctaTitle)
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

    private var ctaTitle: String {
        if service.isBusy { return isChallenge ? "Sending…" : "Creating…" }
        return isChallenge ? "Send challenge" : "Start match"
    }

    private func start() async {
        // Challenge an account → pending challenge, no immediate match.
        if let opp = selectedOpponent, isChallenge {
            let outcome = await service.createChallenge(opponentPlayerId: opp.playerId, raceTo: raceTo)
            switch outcome {
            case .match(let id):        onCreated(id)               // (managed-return safety)
            case .challenge:            challengeSentTo = opp.displayName
            case .failed:               break
            }
            return
        }
        // Scorekeeper: an existing managed opponent, or a new name.
        let id = await service.createManagedMatch(
            playerId: trimmedName.isEmpty ? selectedOpponent?.playerId : nil,
            newOpponentName: trimmedName.isEmpty ? nil : trimmedName,
            raceTo: raceTo
        )
        if let id { onCreated(id) }
    }

    // MARK: - Challenge-sent confirmation

    private func challengeSentConfirmation(_ name: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.Kubb.matchAccent)
                .padding(.top, 60)
            Text("Challenge sent")
                .font(.title3.weight(.bold))
            Text("We let \(firstName(name)) know. Once they accept, the match shows up here under Current.")
                .font(.subheadline)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.Kubb.matchAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }
}
