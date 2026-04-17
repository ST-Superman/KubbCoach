//
//  PressureCookerMenuView.swift
//  Kubb Coach
//

import SwiftUI
import SwiftData

// MARK: - Game Definitions

enum PressureCookerGame: String, CaseIterable, Identifiable {
    case threeForThree = "three-for-three"
    case fieldBlitz = "field-blitz"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeForThree: return "3-4-3"
        case .fieldBlitz: return "Field Blitz"
        }
    }

    var description: String {
        switch self {
        case .threeForThree:
            return "Inkast in a 3-4-3 pattern, then clear all 10 field kubbs in 6 batons across 10 rounds."
        case .fieldBlitz:
            return "Clear a wave of field kubbs as fast as possible. Accuracy and speed both count toward your score."
        }
    }

    var iconImage: Image {
        switch self {
        case .threeForThree: return Image("three_four_three")
        case .fieldBlitz: return Image(systemName: "bolt.fill")
        }
    }

    var isSystemIcon: Bool {
        switch self {
        case .threeForThree: return false
        case .fieldBlitz: return true
        }
    }

    var accentColor: Color {
        return KubbColors.phasePressureCooker
    }
}

// MARK: - Menu View

struct PressureCookerMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<PressureCookerSession> { $0.completedAt != nil })
    private var completedPCSessions: [PressureCookerSession]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a Challenge")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(PressureCookerGame.allCases) { game in
                        if game == .threeForThree {
                            NavigationLink {
                                ThreeForThreeEntryView()
                            } label: {
                                PressureCookerGameCard(game: game, sessionCount: threeForThreeCount)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        } else {
                            NavigationLink {
                                PressureCookerGamePlaceholderView(game: game)
                            } label: {
                                PressureCookerGameCard(game: game, sessionCount: 0)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(
            LinearGradient(
                colors: [
                    KubbColors.phasePressureCooker.opacity(0.08),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Pressure Cooker")
        .navigationBarTitleDisplayMode(.large)
    }

    private var threeForThreeCount: Int {
        completedPCSessions.filter { $0.gameType == PressureCookerGameType.threeForThree.rawValue }.count
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KubbColors.phasePressureCooker.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image("pressure_cooker")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundStyle(KubbColors.phasePressureCooker)
            }

            Text("Mini-games that target specific Kubb skills and high-pressure game scenarios.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Game Card

private struct PressureCookerGameCard: View {
    let game: PressureCookerGame
    let sessionCount: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(game.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                if game.isSystemIcon {
                    game.iconImage
                        .font(.title2)
                        .foregroundStyle(game.accentColor)
                } else {
                    game.iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(game.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    if sessionCount > 0 {
                        Text("\(sessionCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(game.accentColor.opacity(0.8))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                Text(game.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(game.accentColor.opacity(0.2), lineWidth: 1.5)
        )
        .cardShadow()
        .pressableCard()
    }
}

#Preview {
    NavigationStack {
        PressureCookerMenuView()
    }
    .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
