//
//  OnboardingTooltip.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI

enum TooltipPosition {
    case top
    case center
    case bottom
}

struct OnboardingTooltip: View {
    let title: String
    let message: String
    let position: TooltipPosition
    let onDismiss: () -> Void

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTooltip()
                }

            VStack {
                if position == .bottom { Spacer() }
                if position == .center { Spacer() }

                // Tooltip card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.title2)
                            .foregroundStyle(KubbColors.swedishGold)
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button {
                        dismissTooltip()
                    } label: {
                        Text("Got it!")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(KubbColors.swedishBlue)
                            .cornerRadius(12)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 20)
                .scaleEffect(scale)
                .opacity(opacity)
                .padding(.horizontal, 40)

                if position == .top { Spacer() }
                if position == .center { Spacer() }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                opacity = 1
                scale = 1
            }
        }
    }

    private func dismissTooltip() {
        withAnimation(.easeOut(duration: 0.2)) {
            opacity = 0
            scale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
        HapticFeedbackService.shared.buttonTap()
    }
}
