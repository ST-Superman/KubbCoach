import SwiftUI

struct MomentumBackgroundView: View {
    let streakCount: Int

    @State private var animateGlow = false

    private var momentumColor: Color {
        switch streakCount {
        case 0...2:
            return KubbColors.momentumNeutral
        case 3...4:
            return KubbColors.momentumWarm
        case 5...:
            return KubbColors.momentumHot
        default:
            return KubbColors.momentumCold
        }
    }

    private var glowOpacity: Double {
        switch streakCount {
        case 0...2: return 0.0
        case 3...4: return 0.06
        case 5...7: return 0.1
        case 8...14: return 0.15
        default: return 0.2
        }
    }

    private var showEdgeGlow: Bool {
        streakCount >= 5
    }

    var body: some View {
        ZStack {
            KubbColors.trainingCharcoal

            momentumColor
                .opacity(glowOpacity)
                .animation(.easeInOut(duration: 0.6), value: streakCount)

            if showEdgeGlow {
                RadialGradient(
                    colors: [
                        KubbColors.streakGlow.opacity(animateGlow ? 0.08 : 0.04),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateGlow)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            animateGlow = true
        }
    }
}

#Preview {
    VStack {
        Text("Streak: 7")
            .foregroundStyle(.white)
            .font(.title)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
        MomentumBackgroundView(streakCount: 7)
    }
}
