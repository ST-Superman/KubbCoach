//
//  CelebrationView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct CelebrationView: View {
    let accuracy: Double
    @State private var animate = false
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var goldenTakeover = false
    @State private var flagSweep = false
    @State private var showPerfektText = false
    @State private var particleRain: [GoldenParticle] = []

    private var tier: CelebrationTier {
        CelebrationTier.from(accuracy: accuracy)
    }

    var body: some View {
        ZStack {
            if tier == .perfekt {
                perfektBackground
            }

            ForEach(particleRain) { particle in
                particle
            }

            ForEach(confettiPieces) { piece in
                piece
            }

            VStack(spacing: 20) {
                if tier == .perfekt {
                    perfektContent
                } else {
                    standardContent
                }
            }
        }
        .onAppear {
            spawnParticles()

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animate = true
            }

            if tier == .perfekt {
                withAnimation(.easeInOut(duration: 0.8)) {
                    goldenTakeover = true
                }
                withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                    flagSweep = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.6)) {
                    showPerfektText = true
                }
            }

            HapticFeedbackService.shared.success()
        }
    }

    @ViewBuilder
    private var standardContent: some View {
        Image(systemName: tier.icon)
            .font(.system(size: tier.iconSize))
            .foregroundStyle(tier.primaryColor)
            .scaleEffect(animate ? 1.0 : 0.5)
            .rotationEffect(.degrees(animate ? (tier == .incredible ? 360 : 0) : 0))

        Text(tier.message)
            .font(tier == .incredible ? .largeTitle : .title)
            .fontWeight(.bold)
            .foregroundStyle(tier.textColor)
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)

        if let subtitle = tier.subtitle {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 10)
        }
    }

    @ViewBuilder
    private var perfektContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(showPerfektText ? 1.2 : 0.3)
                .opacity(showPerfektText ? 1 : 0)

            Text("PERFEKT")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(showPerfektText ? 1.0 : 0.5)
                .opacity(showPerfektText ? 1 : 0)

            Text("100% Accuracy")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.9))
                .opacity(showPerfektText ? 1 : 0)
        }
    }

    @ViewBuilder
    private var perfektBackground: some View {
        ZStack {
            Color.Kubb.hero
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.Kubb.swedishGold.opacity(goldenTakeover ? 0.4 : 0),
                    Color.Kubb.swedishGold.opacity(0.65).opacity(goldenTakeover ? 0.2 : 0),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                Color.Kubb.swedishBlue.opacity(flagSweep ? 0.15 : 0)
                Color.Kubb.swedishGold.opacity(flagSweep ? 0.15 : 0)
            }
            .ignoresSafeArea()
        }
    }

    private func spawnParticles() {
        switch tier {
        case .keepAtIt:
            break
        case .solid:
            confettiPieces = (0..<8).map { _ in ConfettiPiece(style: .subtle) }
        case .great:
            confettiPieces = (0..<25).map { _ in ConfettiPiece(style: .full) }
        case .incredible:
            confettiPieces = (0..<35).map { _ in ConfettiPiece(style: .full) }
            particleRain = (0..<20).map { _ in GoldenParticle() }
        case .perfekt:
            confettiPieces = (0..<50).map { _ in ConfettiPiece(style: .full) }
            particleRain = (0..<40).map { _ in GoldenParticle() }
        }
    }
}

enum CelebrationTier {
    case keepAtIt
    case solid
    case great
    case incredible
    case perfekt

    static func from(accuracy: Double) -> CelebrationTier {
        switch accuracy {
        case 100: return .perfekt
        case 85..<100: return .incredible
        case 70..<85: return .great
        case 50..<70: return .solid
        default: return .keepAtIt
        }
    }

    var icon: String {
        switch self {
        case .keepAtIt: return "arrow.up.heart.fill"
        case .solid: return "hands.clap.fill"
        case .great: return "trophy.fill"
        case .incredible: return "crown.fill"
        case .perfekt: return "crown.fill"
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .keepAtIt: return 60
        case .solid: return 70
        case .great: return 80
        case .incredible: return 90
        case .perfekt: return 90
        }
    }

    var message: String {
        switch self {
        case .keepAtIt: return "Keep At It!"
        case .solid: return "Solid Session"
        case .great: return "Great Session!"
        case .incredible: return "Incredible!"
        case .perfekt: return "PERFEKT"
        }
    }

    var subtitle: String? {
        switch self {
        case .keepAtIt: return "Every session makes you better"
        case .solid: return "Building consistency"
        case .great, .incredible, .perfekt: return nil
        }
    }

    var primaryColor: Color {
        switch self {
        case .keepAtIt: return Color.Kubb.swedishBlue
        case .solid: return Color.Kubb.swedishBlue.opacity(0.6)
        case .great: return Color.Kubb.forestGreen
        case .incredible: return Color.Kubb.swedishGold
        case .perfekt: return Color.Kubb.swedishGold
        }
    }

    var textColor: Color {
        switch self {
        case .keepAtIt: return .primary
        case .solid: return .primary
        case .great: return Color.Kubb.forestGreen
        case .incredible: return Color.Kubb.swedishGold
        case .perfekt: return Color.Kubb.swedishGold
        }
    }
}

enum ConfettiStyle {
    case subtle
    case full
}

struct ConfettiPiece: View, Identifiable {
    let id = UUID()

    @State private var position: CGPoint
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0

    private let color: Color
    private let size: CGFloat
    private let angle: Double
    private let distance: CGFloat
    private let style: ConfettiStyle

    init(style: ConfettiStyle = .full) {
        self.style = style

        let colors: [Color] = style == .subtle
            ? [Color.Kubb.swedishBlue.opacity(0.6), Color.Kubb.swedishBlue.opacity(0.6).opacity(0.6), Color.Kubb.forestGreen.opacity(0.65).opacity(0.6)]
            : [Color.Kubb.swedishBlue, Color.Kubb.swedishGold, Color.Kubb.forestGreen, Color.Kubb.forestGreen.opacity(0.65), Color.Kubb.phase4m, Color.Kubb.swedishBlue.opacity(0.6)]

        self.color = colors.randomElement()!
        self.size = style == .subtle ? CGFloat.random(in: 6...10) : CGFloat.random(in: 8...14)
        self.angle = Double.random(in: 0..<360)
        self.distance = style == .subtle ? CGFloat.random(in: 80...150) : CGFloat.random(in: 120...220)

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        _position = State(initialValue: CGPoint(x: screenWidth / 2, y: screenHeight / 2))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: style == .subtle ? size / 2 : 2)
            .fill(color)
            .frame(width: size, height: style == .subtle ? size : size * CGFloat.random(in: 0.5...1.5))
            .position(position)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height

                let finalX = screenWidth / 2 + cos(angle * .pi / 180) * distance
                let finalY = screenHeight / 2 + sin(angle * .pi / 180) * distance

                let duration = style == .subtle ? 1.2 : 1.5

                withAnimation(.easeOut(duration: duration)) {
                    position = CGPoint(x: finalX, y: finalY)
                    opacity = 0
                    rotation = Double.random(in: 0...720)
                }
            }
    }
}

struct GoldenParticle: View, Identifiable {
    let id = UUID()

    @State private var yOffset: CGFloat = -20
    @State private var opacity: Double = 0

    private let xPosition: CGFloat
    private let size: CGFloat
    private let delay: Double

    init() {
        self.xPosition = CGFloat.random(in: 0...UIScreen.main.bounds.width)
        self.size = CGFloat.random(in: 3...8)
        self.delay = Double.random(in: 0...1.5)
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
            .position(x: xPosition, y: yOffset)
            .opacity(opacity)
            .onAppear {
                let screenHeight = UIScreen.main.bounds.height

                withAnimation(.linear(duration: 0.3).delay(delay)) {
                    opacity = 0.8
                }

                withAnimation(.easeIn(duration: 2.5).delay(delay)) {
                    yOffset = screenHeight + 20
                }

                withAnimation(.linear(duration: 0.5).delay(delay + 2.0)) {
                    opacity = 0
                }
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        Text("100% — PERFEKT")
            .font(.headline)
        CelebrationView(accuracy: 100)
            .frame(height: 200)
            .background(Color(.systemBackground))

        Text("90% — Incredible")
            .font(.headline)
        CelebrationView(accuracy: 90)
            .frame(height: 200)
            .background(Color(.systemBackground))

        Text("75% — Great")
            .font(.headline)
        CelebrationView(accuracy: 75)
            .frame(height: 200)
            .background(Color(.systemBackground))
    }
    .padding()
}
