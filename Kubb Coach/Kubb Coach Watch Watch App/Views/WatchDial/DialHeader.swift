//
//  DialHeader.swift
//  Kubb Coach Watch Watch App
//
//  Two-tier header used above the dial: small caps label sitting over a
//  large value. Optional right-side sub element (e.g. baton glyph).
//  See handoff §04.
//

import SwiftUI

struct DialHeader<RightSub: View>: View {
    let leftLabel: String
    let leftValue: String
    let rightLabel: String
    let rightValue: String
    var rightAccent: Color = Color.Kubb.swedishGold
    var rightValueSize: CGFloat = 20
    @ViewBuilder var rightSub: () -> RightSub

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            column(
                label: leftLabel,
                value: leftValue,
                alignment: .leading,
                color: .white,
                size: 20,
                sub: EmptyView()
            )
            Spacer(minLength: 0)
            column(
                label: rightLabel,
                value: rightValue,
                alignment: .trailing,
                color: rightAccent,
                size: rightValueSize,
                sub: rightSub()
            )
        }
        .padding(.horizontal, 8)
    }

    private func column<Sub: View>(
        label: String,
        value: String,
        alignment: HorizontalAlignment,
        color: Color,
        size: CGFloat,
        sub: Sub
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: size, weight: .heavy))
                .kerning(-0.3)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            sub
        }
    }
}

extension DialHeader where RightSub == EmptyView {
    init(
        leftLabel: String,
        leftValue: String,
        rightLabel: String,
        rightValue: String,
        rightAccent: Color = Color.Kubb.swedishGold,
        rightValueSize: CGFloat = 20
    ) {
        self.leftLabel = leftLabel
        self.leftValue = leftValue
        self.rightLabel = rightLabel
        self.rightValue = rightValue
        self.rightAccent = rightAccent
        self.rightValueSize = rightValueSize
        self.rightSub = { EmptyView() }
    }
}
