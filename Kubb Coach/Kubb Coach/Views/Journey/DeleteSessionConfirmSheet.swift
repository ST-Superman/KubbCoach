import SwiftUI

struct DeleteImpactSummary {
    let throwCount: Int
    let phaseLabel: String
    let willBreakStreak: Bool
    let currentStreakLength: Int
    let holdsPB: Bool
}

struct DeleteSessionConfirmSheet: View {
    let impact: DeleteImpactSummary
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: KubbSpacing.l) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color.Kubb.miss.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.Kubb.miss)
            }
            .padding(.top, KubbSpacing.xl)

            // Title
            Text("Delete this session?")
                .font(KubbFont.fraunces(19, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
                .multilineTextAlignment(.center)

            // Impact body
            impactBody
                .font(KubbFont.inter(13.5, weight: .regular))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, KubbSpacing.xl)

            Spacer()

            // Buttons
            VStack(spacing: KubbSpacing.s) {
                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Delete Session")
                        .font(KubbFont.inter(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.Kubb.miss)
                        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(KubbFont.inter(15, weight: .semibold))
                        .foregroundStyle(Color.Kubb.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.Kubb.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, KubbSpacing.l)
            .padding(.bottom, KubbSpacing.xl)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var impactBody: Text {
        var body = Text("This removes ")
            + Text("\(impact.throwCount) throws")
                .fontWeight(.bold)
                .foregroundStyle(Color.Kubb.text)
            + Text(" from your \(impact.phaseLabel) stats.")

        if impact.willBreakStreak {
            body = body
                + Text(" It will break your ")
                + Text("\(impact.currentStreakLength)-day streak.")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Kubb.text)
        }

        return body
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        DeleteSessionConfirmSheet(
            impact: DeleteImpactSummary(
                throwCount: 14,
                phaseLabel: "8m",
                willBreakStreak: true,
                currentStreakLength: 6,
                holdsPB: false
            ),
            onConfirm: {}
        )
    }
}
