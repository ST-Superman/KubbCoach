//
//  BatonGlyph.swift
//  Kubb Coach Watch Watch App
//
//  N small wooden batons rendered as upright sticks. Used in the In the Red
//  header (current scenario's baton allowance) and the setup scenario list.
//  See handoff §04 + §06.
//

import SwiftUI

struct BatonGlyph: View {
    let count: Int
    var showsLabel: Bool = false
    var height: CGFloat = 11
    var color: Color = Color.Kubb.birchWood

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2.5) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1.25, style: .continuous)
                        .fill(color)
                        .frame(width: 2.5, height: height)
                }
            }
            if showsLabel {
                Text("BATONS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
    }
}
