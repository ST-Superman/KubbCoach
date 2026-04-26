//
//  JourneyTutorialOverlay.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI

struct JourneyTutorialOverlay: View {
    let onDismiss: () -> Void

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTutorial()
                }

            VStack {
                Spacer()

                // Tutorial card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "point.topright.filled.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                            .font(.title2)
                            .foregroundStyle(Color.Kubb.swedishBlue)
                        Text("Journey Tab Unlocked!")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    Text("View all your training sessions here. Track your progress over time, see your streaks, and review past performances.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Button {
                        dismissTutorial()
                    } label: {
                        Text("Got it!")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.Kubb.swedishBlue)
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

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                opacity = 1
                scale = 1
            }
        }
    }

    private func dismissTutorial() {
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
