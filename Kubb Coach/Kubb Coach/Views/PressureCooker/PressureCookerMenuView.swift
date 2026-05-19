//
//  PressureCookerMenuView.swift
//  Kubb Coach
//

import SwiftUI
import SwiftData

// MARK: - Game Definitions

enum PressureCookerGame: String, CaseIterable, Identifiable, Hashable {
    case threeForThree = "three-for-three"
    case inTheRed      = "in-the-red"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeForThree: return "3-4-3"
        case .inTheRed:      return "In the Red"
        }
    }

    var focus: String {
        switch self {
        case .threeForThree: return "Early Game Field Efficiency"
        case .inTheRed:      return "Late Game Perfection"
        }
    }

    var description: String {
        switch self {
        case .threeForThree:
            return "This mode focuses on inkasting small groups of kubbs and blasting them with efficiency."
        case .inTheRed:
            return "This mode focuses on high pressure late game situations that demand perfection in order to win."
        }
    }

    var iconImage: Image {
        switch self {
        case .threeForThree: return Image("three_four_three")
        case .inTheRed:      return Image("in_the_red")
        }
    }

    var isSystemIcon: Bool {
        switch self {
        case .threeForThree: return false
        case .inTheRed:      return false
        }
    }

    /// Whether to render the icon as a template (single tinted color).
    /// Full-color images like in_the_red should use original rendering.
    var isTemplateIcon: Bool {
        switch self {
        case .threeForThree: return true
        case .inTheRed:      return false
        }
    }

    var accentColor: Color {
        return Color.Kubb.phasePC
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
                    Text("CHOOSE A CHALLENGE")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Kubb.textSec)
                        .padding(.horizontal)

                    ForEach(PressureCookerGame.allCases) { game in
                        NavigationLink(value: game) {
                            PressureCookerGameCard(
                                game: game,
                                sessionCount: sessionCount(for: game)
                            )
                        }
                        .buttonStyle(PressableCardButtonStyle())
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 120)
            }
            .padding(.vertical)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.Kubb.phasePC.opacity(0.08),
                    Color.Kubb.card
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Pressure Cooker")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: PressureCookerGame.self) { game in
            switch game {
            case .threeForThree:
                ThreeForThreeEntryView()
            case .inTheRed:
                InTheRedEntryView()
            }
        }
    }

    private func sessionCount(for game: PressureCookerGame) -> Int {
        switch game {
        case .threeForThree:
            return completedPCSessions.filter { $0.gameType == PressureCookerGameType.threeForThree.rawValue }.count
        case .inTheRed:
            return completedPCSessions.filter { $0.gameType == PressureCookerGameType.inTheRed.rawValue }.count
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.Kubb.phasePC.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image("pressure_cooker")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundStyle(Color.Kubb.phasePC)
            }

            Text("Mini-games that target specific Kubb skills and high-pressure game scenarios.")
                .font(KubbFont.fraunces(17, weight: .regular, italic: true))
                .foregroundStyle(Color.Kubb.textSec)
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
                } else if game.isTemplateIcon {
                    game.iconImage
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(game.accentColor)
                } else {
                    game.iconImage
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(game.title)
                        .font(KubbFont.fraunces(20, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)

                    if sessionCount > 0 {
                        Text("\(sessionCount)")
                            .font(KubbFont.mono(10, weight: .bold))
                            .kerning(0.5)
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(game.accentColor.opacity(0.8))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text("FOCUS")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Kubb.textSec)
                    Text(game.focus)
                        .font(KubbFont.inter(13, weight: .medium))
                        .foregroundStyle(game.accentColor)
                }

                Text(game.description)
                    .font(KubbFont.inter(13))
                    .foregroundStyle(Color.Kubb.textSec)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.Kubb.textTer)
        }
        .padding(KubbSpacing.l2)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.xl)
                .strokeBorder(game.accentColor.opacity(0.2), lineWidth: 1.5)
        )
        .kubbCardShadow()
    }
}

#Preview {
    NavigationStack {
        PressureCookerMenuView()
    }
    .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
