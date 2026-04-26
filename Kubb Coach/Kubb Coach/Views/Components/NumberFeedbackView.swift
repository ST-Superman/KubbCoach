//
//  NumberFeedbackView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct NumberFeedbackView: View {
    let count: Int
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("\(count)")
                .font(.system(size: 100, weight: .bold))
                .foregroundStyle(feedbackColor)

            Text(count == 1 ? "kubb" : "kubbs")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .opacity(opacity)
        .scaleEffect(scale)
        .offset(y: offset)
        .onAppear {
            // Quick scale-in animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }

            // Fade and float up
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                opacity = 0
                offset = -80
            }
        }
    }

    private var feedbackColor: Color {
        switch count {
        case 5...:
            return Color.Kubb.forestGreen
        case 3..<5:
            return Color.Kubb.swedishGold
        case 1..<3:
            return .orange
        default:
            return .gray
        }
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
        NumberFeedbackView(count: 5)
    }
}
