// JourneyView.swift
// Kubbly Stats · Journey screen
// Hero band (dark, sticky) + bento body (paper, scrolls).

import SwiftUI
import SwiftData

// MARK: – Root

struct JourneyView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncService.self) private var cloudSyncService

    @Query(
        filter: #Predicate<TrainingSession> {
            $0.completedAt != nil || $0.deviceType == "Watch"
        },
        sort: \TrainingSession.createdAt, order: .reverse
    ) private var rawSessions: [TrainingSession]

    @State private var vm: JourneyViewModel?
    @State private var selectedSession: LedgerRow?
    @State private var navigationPath = NavigationPath()

    private var sessions: [SessionDisplayItem] {
        rawSessions.map { .local($0) }
    }

    // Approximate hero height — used to offset the bento so it starts below the hero
    private let heroHeight: CGFloat = 310

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                // Scrollable bento (sits behind hero, has top padding)
                ScrollView(showsIndicators: false) {
                    Color.clear.frame(height: heroHeight)
                    if let vm {
                        BentoBody(vm: vm, onPhase: { phase in
                            navigationPath.append(phase)
                        }, onSession: { row in
                            selectedSession = row
                        })
                    }
                }
                .background(Color.Kubb.paper2)
                .refreshable { await sync() }

                // Hero pinned at top (not in scroll)
                if let vm {
                    HeroBand(vm: vm)
                        .frame(height: heroHeight)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .navigationDestination(for: KubbPhase.self) { phase in
                PhaseAnalysisView(phase: phase)
            }
            .sheet(item: $selectedSession) { row in
                SessionLedgerDetailSheet(row: row)
            }
        }
        .task { await setup() }
        .onChange(of: rawSessions.count) { _, _ in vm?.refresh(sessions: sessions) }
    }

    private func setup() async {
        let model = JourneyViewModel(modelContext: modelContext)
        vm = model
        await sync()
        model.refresh(sessions: sessions)
    }

    private func sync() async {
        do {
            try await cloudSyncService.syncCloudSessions(modelContext: modelContext)
            vm?.refresh(sessions: sessions)
        } catch {}
    }
}

// MARK: – Hero band

private struct HeroBand: View {
    let vm: JourneyViewModel

    private let today: String = {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: Date()).uppercased()
    }()

    var body: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [Color(hex: 0x0B1B38), Color(hex: 0x0D1726)],
                startPoint: .top, endPoint: .bottom
            )

            // Subtle grid texture (top-right quadrant)
            GeometryReader { geo in
                Canvas { ctx, size in
                    let gridSpacing: CGFloat = 24
                    let cols = Int(size.width / gridSpacing) + 2
                    let rows = Int(size.height / gridSpacing) + 2
                    for c in 0...cols {
                        var path = Path()
                        path.move(to: CGPoint(x: CGFloat(c) * gridSpacing, y: 0))
                        path.addLine(to: CGPoint(x: CGFloat(c) * gridSpacing, y: size.height))
                        ctx.stroke(path, with: .color(Color.Kubb.swedishGold.opacity(0.05)), lineWidth: 0.5)
                    }
                    for r in 0...rows {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: CGFloat(r) * gridSpacing))
                        path.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * gridSpacing))
                        ctx.stroke(path, with: .color(Color.Kubb.swedishGold.opacity(0.05)), lineWidth: 0.5)
                    }
                }
                .mask(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: UnitPoint(x: 1, y: 0),
                        endPoint: UnitPoint(x: 0.2, y: 0.8)
                    )
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 56) // safe area

                // Meta strip
                HStack {
                    Text("JOURNEY / \(today)")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, KubbSpacing.xl)

                // Gold rule + streak composition
                HStack(alignment: .top, spacing: KubbSpacing.m2) {
                    // Left gold rule
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.2)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                        .padding(.top, KubbSpacing.l)

                    VStack(alignment: .leading, spacing: 0) {
                        // Streak number + "days / in a row."
                        HStack(alignment: .top, spacing: KubbSpacing.s2) {
                            Text("\(vm.currentStreak)")
                                .font(KubbType.displayXXL)
                                .tracking(KubbTracking.displayXXL)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("days")
                                    .font(KubbType.display)
                                    .foregroundStyle(.white)
                                Text("in a row.")
                                    .font(KubbType.display)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.top, 18)
                        }

                        // 14-day dot strip
                        HStack(spacing: 5) {
                            ForEach(Array(vm.last14Days.enumerated()), id: \.offset) { _, active in
                                Circle()
                                    .fill(active
                                          ? Color.Kubb.swedishGold
                                          : Color.clear)
                                    .overlay(
                                        Circle().stroke(
                                            active ? Color.clear : Color.white.opacity(0.25),
                                            lineWidth: 1
                                        )
                                    )
                                    .frame(width: 8, height: 8)
                            }
                            Text("LAST 14 DAYS")
                                .font(KubbType.monoXS)
                                .tracking(0.3)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.leading, KubbSpacing.xs2)
                        }
                        .padding(.top, KubbSpacing.m)
                    }
                }
                .padding(.horizontal, KubbSpacing.xl)
                .padding(.top, KubbSpacing.m)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.horizontal, KubbSpacing.xl)
                    .padding(.top, KubbSpacing.l)

                // 3-col footer
                HStack(spacing: 0) {
                    HeroFooterStat(val: "\(vm.longestStreak)d", label: "BEST EVER")
                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.5)
                    HeroFooterStat(val: String(format: "%.1f%%", vm.form30d),
                                   label: "30D FORM",
                                   accent: Color.Kubb.forestGreen)
                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.5)
                    HeroFooterStat(val: "\(vm.pbsThisWeek)",
                                   label: "PBs THIS WK",
                                   accent: Color.Kubb.swedishGold)
                }
                .padding(.top, KubbSpacing.m)
                .padding(.horizontal, KubbSpacing.l)

                Spacer(minLength: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous),
                   style: FillStyle())
        // Only round the bottom corners
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

private struct HeroFooterStat: View {
    let val: String
    let label: String
    var accent: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
            Text(label)
                .font(KubbType.monoXS)
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.5))
            Text(val)
                .font(KubbType.titleL)
                .tracking(KubbTracking.title)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, KubbSpacing.m)
        .padding(.horizontal, KubbSpacing.l)
    }
}

// MARK: – Bento body

private struct BentoBody: View {
    let vm: JourneyViewModel
    let onPhase: (KubbPhase) -> Void
    let onSession: (LedgerRow) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: KubbSpacing.m) {
                // §01 Form by phase
                JourneySectionHeader(num: "01", title: "Form by phase", sub: "Last 30 days")
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.top, KubbSpacing.l)

                VStack(spacing: KubbSpacing.s) {
                    ForEach(vm.phaseSummaries, id: \.phase) { summary in
                        PhaseRowCard(summary: summary, onTap: { onPhase(summary.phase) })
                    }
                }
                .padding(.horizontal, KubbSpacing.l)

                // §02 Training volume
                JourneySectionHeader(num: "02", title: "Training volume", sub: "Last 13 weeks")
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.top, KubbSpacing.xs)

                VolumeHeatmapCard(weeks: vm.heatmap)
                    .padding(.horizontal, KubbSpacing.l)

                // §03 Recent sessions
                JourneySectionHeader(
                    num: "03",
                    title: "Recent sessions",
                    sub: "\(vm.totalSessionCount) total"
                )
                .padding(.horizontal, KubbSpacing.l)
                .padding(.top, KubbSpacing.xs)

                SessionLedgerCard(rows: vm.recentLedger, onTap: onSession)
                    .padding(.horizontal, KubbSpacing.l)
            }
            .padding(.bottom, 120)
        }
    }
}

// MARK: – Section header

private struct JourneySectionHeader: View {
    let num: String
    let title: String
    let sub: String

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: KubbSpacing.s) {
            Text(num)
                .font(KubbType.monoXS)
                .tracking(1.2)
                .foregroundStyle(Color.Kubb.swedishBlue)
            Text(title)
                .font(KubbFont.inter(13, weight: .bold))
                .foregroundStyle(Color.Kubb.text)
                .tracking(-0.2)
            Spacer()
            Text(sub)
                .font(KubbType.monoXS)
                .tracking(0.3)
                .foregroundStyle(Color.Kubb.textSec)
        }
    }
}

// MARK: – Phase row card

private struct PhaseRowCard: View {
    let summary: JourneyPhaseSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KubbSpacing.m) {
                // Phase icon circle
                Image(systemName: summary.phase.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.Kubb.phase(summary.phase))
                    .frame(width: 34, height: 34)
                    .background(Color.Kubb.phase(summary.phase).opacity(0.12))
                    .clipShape(Circle())

                // Name + sub-label
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.phase.fullName)
                        .font(KubbType.body)
                        .foregroundStyle(Color.Kubb.text)
                    Text(summary.subLabel)
                        .font(KubbType.label)
                        .foregroundStyle(Color.Kubb.textSec)
                }

                Spacer()

                // Inline sparkline
                MiniSparkline(values: summary.sparkValues,
                              color: Color.Kubb.phase(summary.phase))
                    .frame(width: 52, height: 20)

                // Big stat + delta
                VStack(alignment: .trailing, spacing: 2) {
                    Text(summary.bigStat)
                        .font(KubbFont.fraunces(18, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                    Text(summary.delta)
                        .font(KubbType.monoXS)
                        .tracking(0.5)
                        .foregroundStyle(summary.deltaPositive
                                         ? Color.Kubb.forestGreen
                                         : Color(hex: 0xC53030))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .padding(.horizontal, KubbSpacing.m2)
            .frame(height: 56)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
            .kubbCardShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Mini sparkline (Canvas)

struct MiniSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.001)
            let w = size.width, h = size.height

            func pt(_ i: Int) -> CGPoint {
                CGPoint(
                    x: CGFloat(i) / CGFloat(values.count - 1) * w,
                    y: h - (CGFloat(values[i] - minV) / CGFloat(range)) * (h - 2) - 1
                )
            }

            var path = Path()
            path.move(to: pt(0))
            for i in 1..<values.count { path.addLine(to: pt(i)) }
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: – Volume heatmap card

private struct VolumeHeatmapCard: View {
    let weeks: [[HeatCell]]

    private let cellSize: CGFloat = 10
    private let gap: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: gap) {
                            ForEach(week) { cell in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(cell))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        cell.isToday
                                        ? RoundedRectangle(cornerRadius: 2)
                                            .stroke(Color.Kubb.textSec, lineWidth: 1)
                                        : nil
                                    )
                            }
                        }
                    }
                }
                .padding(KubbSpacing.m2)
            }

            // Legend
            HStack(spacing: KubbSpacing.xs) {
                Text("Less")
                    .font(KubbType.monoXS)
                    .foregroundStyle(Color.Kubb.textTer)
                ForEach(0...3, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(legendColor(level))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(KubbType.monoXS)
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .padding(.horizontal, KubbSpacing.m2)
            .padding(.bottom, KubbSpacing.m2)
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
    }

    private func cellColor(_ cell: HeatCell) -> Color {
        if cell.isFuture { return Color.clear }
        switch cell.count {
        case 0: return Color.Kubb.sep.opacity(0.6)
        case 1: return Color.Kubb.forestGreen.opacity(0.35)
        case 2: return Color.Kubb.forestGreen.opacity(0.65)
        default: return Color.Kubb.forestGreen
        }
    }

    private func legendColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color.Kubb.sep.opacity(0.6)
        case 1: return Color.Kubb.forestGreen.opacity(0.35)
        case 2: return Color.Kubb.forestGreen.opacity(0.65)
        default: return Color.Kubb.forestGreen
        }
    }
}

// MARK: – Session ledger card

private struct SessionLedgerCard: View {
    let rows: [LedgerRow]
    let onTap: (LedgerRow) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if rows.isEmpty {
                Text("No sessions yet")
                    .font(KubbType.bodyS)
                    .foregroundStyle(Color.Kubb.textTer)
                    .frame(maxWidth: .infinity)
                    .padding(KubbSpacing.xxl)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    Button { onTap(row) } label: {
                        LedgerRowView(row: row, isLast: idx == rows.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .kubbCardShadow()
    }
}

private struct LedgerRowView: View {
    let row: LedgerRow
    let isLast: Bool

    var body: some View {
        HStack(spacing: KubbSpacing.m) {
            // Date / time column
            VStack(alignment: .center, spacing: 2) {
                Text(row.dateLabel)
                    .font(KubbType.monoXS)
                    .tracking(0.4)
                    .foregroundStyle(Color.Kubb.textSec)
                Text(row.timeLabel)
                    .font(KubbFont.mono(8, weight: .regular))
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .frame(width: 38)

            // Phase badge
            Image(systemName: row.phase.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.Kubb.phase(row.phase))
                .frame(width: 28, height: 28)
                .background(Color.Kubb.phase(row.phase).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            // Stat + sub
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: KubbSpacing.xs) {
                    Text(row.statLine)
                        .font(KubbFont.inter(13, weight: .bold))
                        .foregroundStyle(Color.Kubb.text)
                    if row.isPersonalBest {
                        Text("PB")
                            .font(KubbType.monoXS)
                            .tracking(0.4)
                            .foregroundStyle(Color(hex: 0x8A6700))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.Kubb.swedishGold.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xs))
                    }
                }
                Text(row.subLine)
                    .font(KubbType.monoXS)
                    .tracking(0.3)
                    .foregroundStyle(Color.Kubb.textSec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.Kubb.textTer)
        }
        .padding(.horizontal, KubbSpacing.m2)
        .padding(.vertical, KubbSpacing.m)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.Kubb.sep)
                    .frame(height: 0.5)
                    .padding(.leading, KubbSpacing.m2 + 38 + KubbSpacing.m)
            }
        }
    }
}

// MARK: – Preview

#Preview {
    @Previewable @State var tab: AppTab = .history
    JourneyView(selectedTab: $tab)
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
}
