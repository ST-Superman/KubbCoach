//
//  CrownHint.swift
//  Kubb Coach Watch Watch App
//
//  Subtle three-tick mark anchored to the screen's right edge, near the
//  physical Digital Crown — signals "this surface responds to the crown".
//  See handoff §07.
//

import SwiftUI

struct CrownHint: View {
    var color: Color = .white

    var body: some View {
        VStack(spacing: 4) {
            tick(height: 8, opacity: 0.35)
            tick(height: 20, opacity: 0.7)
            tick(height: 8, opacity: 0.35)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 2)
    }

    private func tick(height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 1.25, style: .continuous)
            .fill(color.opacity(opacity * 0.38))
            .frame(width: 3, height: height)
    }
}
