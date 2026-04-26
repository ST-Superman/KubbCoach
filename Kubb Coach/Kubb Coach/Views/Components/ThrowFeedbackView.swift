//
//  ThrowFeedbackView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct ThrowFeedbackView: View {
    let result: ThrowResult
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5
    @State private var offset: CGFloat = 0

    var body: some View {
        Image(systemName: result == .hit ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 80))
            .foregroundStyle(result == .hit ? Color.Kubb.forestGreen : Color.Kubb.phasePC)
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
}

#Preview {
    ZStack {
        Color(.systemBackground)
        ThrowFeedbackView(result: .hit)
    }
}
