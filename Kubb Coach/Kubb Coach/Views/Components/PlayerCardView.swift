import SwiftUI

struct PlayerCardView: View {
    let level: PlayerLevel
    let streak: Int
    let sessionCount: Int

    @State private var animatedProgress: Double = 0
    @State private var rainbowPhase: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(levelGradient)
                        .frame(width: 56, height: 56)

                    Image(systemName: levelIcon)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        // Prestige title if present
                        if let title = level.prestigeTitle {
                            Text("(\(title))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }

                        // Swedish name (always shown)
                        Text(level.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        // English subtitle (always shown)
                        Text(level.subtitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text("Level \(level.levelNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("·")
                            .foregroundStyle(.secondary)

                        Text("\(sessionCount) sessions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(KubbColors.streakFlame)
                                .scaleEffect(flameScale)

                            Text("\(streak)-day streak")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(KubbColors.streakFlame)
                        }
                    }
                }

                Spacer()
            }

            if !level.isMaxLevel {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(xpBarGradient)
                                .frame(width: geometry.size.width * animatedProgress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(level.currentXP) XP")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(level.xpProgress * 100))% to Level \(level.levelNumber + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.mediumRadius)
        .overlay(prestigeBorderOverlay)
        .cardShadow()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = level.xpProgress
            }

            // Start rainbow animation if GM level
            if level.prestigeLevel >= 4 {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rainbowPhase = 1.0
                }
            }
        }
    }

    private var flameScale: CGFloat {
        switch streak {
        case 1...3: return 1.0
        case 4...7: return 1.15
        case 8...14: return 1.3
        default: return 1.5
        }
    }

    private var levelIcon: String {
        switch level.levelNumber {
        case 1...5: return "figure.walk"
        case 6...15: return "figure.run"
        case 16...30: return "bolt.fill"
        case 31...50: return "shield.fill"
        default: return "crown.fill"
        }
    }

    private var levelGradient: LinearGradient {
        switch level.levelNumber {
        case 1...5:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 6...15:
            return LinearGradient(colors: [KubbColors.swedishBlue, KubbColors.duskBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 16...30:
            return LinearGradient(colors: [KubbColors.forestGreen, KubbColors.meadowGreen], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 31...50:
            return LinearGradient(colors: [KubbColors.midnightNavy, KubbColors.duskBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [KubbColors.swedishGold, KubbColors.celebrationGoldEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var xpBarGradient: LinearGradient {
        LinearGradient(
            colors: [KubbColors.swedishBlue, KubbColors.meadowGreen],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @ViewBuilder
    private var prestigeBorderOverlay: some View {
        switch level.prestigeLevel {
        case 0:
            // No border
            EmptyView()
        case 1:
            // Blue solid border
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(KubbColors.swedishBlue, lineWidth: 3)
        case 2:
            // Purple solid border
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(Color.purple, lineWidth: 3)
        case 3:
            // Gold gradient border
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [KubbColors.swedishGold, KubbColors.celebrationGoldEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        default:
            // Animated rainbow gradient border for GM (level 4+)
            RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.red,
                            Color.orange,
                            Color.yellow,
                            Color.green,
                            Color.blue,
                            Color.purple,
                            Color.red
                        ],
                        center: .center,
                        startAngle: .degrees(rainbowPhase * 360),
                        endAngle: .degrees(rainbowPhase * 360 + 360)
                    ),
                    lineWidth: 3
                )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PlayerCardView(
            level: PlayerLevel(
                levelNumber: 12,
                name: "Spelare",
                subtitle: "Player",
                currentXP: 850,
                xpForCurrentLevel: 700,
                xpForNextLevel: 1000,
                totalSessions: 47,
                prestigeTitle: nil,
                prestigeLevel: 0
            ),
            streak: 8,
            sessionCount: 47
        )

        PlayerCardView(
            level: PlayerLevel(
                levelNumber: 1,
                name: "Nybörjare",
                subtitle: "Beginner",
                currentXP: 25,
                xpForCurrentLevel: 0,
                xpForNextLevel: 50,
                totalSessions: 3,
                prestigeTitle: nil,
                prestigeLevel: 0
            ),
            streak: 0,
            sessionCount: 3
        )
    }
    .padding()
}
