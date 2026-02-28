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

    var body: some View {
        ZStack {
            // Confetti particles
            ForEach(confettiPieces) { piece in
                piece
            }

            // Success icon and message
            VStack(spacing: 20) {
                Image(systemName: celebrationIcon)
                    .font(.system(size: 90))
                    .foregroundStyle(celebrationColor)
                    .scaleEffect(animate ? 1.0 : 0.5)
                    .rotationEffect(.degrees(animate ? 360 : 0))

                Text(celebrationMessage)
                    .font(.title)
                    .fontWeight(.bold)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 20)
            }
        }
        .onAppear {
            // Generate confetti pieces only for great performances
            if accuracy >= 60 {
                let count = accuracy >= 90 ? 30 : (accuracy >= 75 ? 20 : 15)
                confettiPieces = (0..<count).map { _ in
                    ConfettiPiece()
                }
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animate = true
            }

            HapticFeedbackService.shared.success()
        }
    }

    private var celebrationIcon: String {
        switch accuracy {
        case 90...: return "star.fill"
        case 75..<90: return "trophy.fill"
        case 60..<75: return "hands.clap.fill"
        default: return "checkmark.circle.fill"
        }
    }

    private var celebrationColor: Color {
        switch accuracy {
        case 90...: return KubbColors.swedishGold
        case 75..<90: return KubbColors.phase4m
        case 60..<75: return KubbColors.forestGreen
        default: return KubbColors.swedishBlue
        }
    }

    private var celebrationMessage: String {
        switch accuracy {
        case 90...: return "Outstanding!"
        case 75..<90: return "Great Job!"
        case 60..<75: return "Well Done!"
        default: return "Session Complete!"
        }
    }
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

    init() {
        // Random properties
        self.color = [KubbColors.swedishBlue, KubbColors.swedishGold, KubbColors.forestGreen, KubbColors.meadowGreen, KubbColors.phase4m].randomElement()!
        self.size = CGFloat.random(in: 8...14)
        self.angle = Double.random(in: 0..<360)
        self.distance = CGFloat.random(in: 120...220)

        // Start from center of screen
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        _position = State(initialValue: CGPoint(x: screenWidth / 2, y: screenHeight / 2))
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(position)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height

                let finalX = screenWidth / 2 + cos(angle * .pi / 180) * distance
                let finalY = screenHeight / 2 + sin(angle * .pi / 180) * distance

                withAnimation(.easeOut(duration: 1.5)) {
                    position = CGPoint(x: finalX, y: finalY)
                    opacity = 0
                    rotation = Double.random(in: 0...720)
                }
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        Text("90%+ Accuracy")
            .font(.headline)
        CelebrationView(accuracy: 95)
            .frame(height: 200)
            .background(Color(.systemBackground))

        Text("75-89% Accuracy")
            .font(.headline)
        CelebrationView(accuracy: 80)
            .frame(height: 200)
            .background(Color(.systemBackground))

        Text("60-74% Accuracy")
            .font(.headline)
        CelebrationView(accuracy: 65)
            .frame(height: 200)
            .background(Color(.systemBackground))
    }
    .padding()
}
