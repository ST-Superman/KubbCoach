// TimelineFilterChip.swift
// Pill-shaped filter chip used in JourneyTimelineView's phase filter row.

import SwiftUI

struct TimelineFilterChip: View {
    let label: String
    let color: Color
    let count: Int
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                // Leading color dot
                Circle()
                    .fill(isActive ? Color.white : color)
                    .frame(width: 6, height: 6)

                Text(label)
                    .font(KubbFont.inter(12, weight: .bold))
                    .foregroundStyle(isActive ? .white : Color.Kubb.text)

                // Count badge
                Text("\(count)")
                    .font(KubbFont.inter(10, weight: .bold))
                    .foregroundStyle(isActive ? .white.opacity(0.75) : Color.Kubb.text.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(chipBackground)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 999)
                .fill(color)
                .shadow(color: color.opacity(0.33), radius: 10, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.Kubb.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .strokeBorder(Color.Kubb.sep, lineWidth: 0.5)
                )
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        TimelineFilterChip(label: "8 Meters", color: Color.Kubb.swedishBlue, count: 12, isActive: true, onTap: {})
        TimelineFilterChip(label: "Blasting", color: Color.Kubb.phase4m, count: 5, isActive: false, onTap: {})
        TimelineFilterChip(label: "★ PBs", color: Color.Kubb.swedishGold, count: 3, isActive: false, onTap: {})
    }
    .padding()
    .background(Color(.systemBackground))
}
