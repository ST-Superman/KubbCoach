// JourneyViewModel.swift
// Aggregates all data needed by JourneyView.

import SwiftUI
import SwiftData
import Foundation

// MARK: – Phase summary row data

struct JourneyPhaseSummary {
    let phase: KubbPhase
    let bigStat: String
    let subLabel: String
    let delta: String
    let deltaPositive: Bool
    let sparkValues: [Double]
}

// MARK: – Heatmap cell

struct HeatCell: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int          // 0 = rest, 1–3 = activity level
    let isToday: Bool
    let isFuture: Bool
}

// MARK: – Ledger row

struct LedgerRow: Identifiable {
    let id: UUID
    let phase: KubbPhase
    let dateLabel: String
    let timeLabel: String
    let statLine: String
    let subLine: String
    let isPersonalBest: Bool
    let session: SessionDisplayItem
}

// MARK: – View model

@Observable
@MainActor
final class JourneyViewModel {

    // MARK: Published state

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var pbsThisWeek: Int = 0
    var form30d: Double = 0          // avg accuracy across phases 0-100
    var last14Days: [Bool] = Array(repeating: false, count: 14)
    var phaseSummaries: [JourneyPhaseSummary] = []
    var heatmap: [[HeatCell]] = []   // 13 weeks × 7 days
    var recentLedger: [LedgerRow] = []
    var totalSessionCount: Int = 0

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: – Refresh

    func refresh(sessions: [SessionDisplayItem]) {
        computeStreak(sessions: sessions)
        computeLast14Days(sessions: sessions)
        computePhaseSummaries(sessions: sessions)
        computeHeatmap(sessions: sessions)
        computeLedger(sessions: sessions)
        totalSessionCount = sessions.count
    }

    // MARK: – Streak

    private func computeStreak(sessions: [SessionDisplayItem]) {
        currentStreak = StreakCalculator.currentStreak(from: sessions)
        longestStreak = StreakCalculator.longestStreak(from: sessions)
    }

    // MARK: – Last 14 days dots

    private func computeLast14Days(sessions: [SessionDisplayItem]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let activeDays = Set(sessions.map { cal.startOfDay(for: $0.createdAt) })
        // index 0 = oldest (13 days ago), index 13 = today
        last14Days = (0..<14).map { offset in
            let day = cal.date(byAdding: .day, value: -(13 - offset), to: today)!
            return activeDays.contains(day)
        }
    }

    // MARK: – Phase summaries (last 30 days)

    private func computePhaseSummaries(sessions: [SessionDisplayItem]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let prior  = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let recent = sessions.filter { $0.createdAt >= cutoff }
        let prev   = sessions.filter { $0.createdAt >= prior && $0.createdAt < cutoff }

        phaseSummaries = [
            eightMeterSummary(recent: recent, prev: prev),
            fourMeterSummary(recent: recent, prev: prev),
            inkastingSummary(recent: recent, prev: prev),
            pressureCookerSummary(recent: recent, prev: prev),
        ]
    }

    private func eightMeterSummary(recent: [SessionDisplayItem], prev: [SessionDisplayItem]) -> JourneyPhaseSummary {
        let rs = recent.filter { $0.phase == .eightMeters }
        let ps = prev.filter   { $0.phase == .eightMeters }
        let avg    = rs.isEmpty ? 0.0 : rs.map(\.accuracy).reduce(0, +) / Double(rs.count)
        let prvAvg = ps.isEmpty ? 0.0 : ps.map(\.accuracy).reduce(0, +) / Double(ps.count)
        let delta  = avg - prvAvg
        let spark  = rs.suffix(10).map { $0.accuracy }
        return JourneyPhaseSummary(
            phase: .eightMeter,
            bigStat: rs.isEmpty ? "—" : String(format: "%.1f%%", avg),
            subLabel: "Avg accuracy",
            delta: delta >= 0 ? String(format: "+%.1f", delta) : String(format: "%.1f", delta),
            deltaPositive: delta >= 0,
            sparkValues: spark.isEmpty ? [0] : spark
        )
    }

    private func fourMeterSummary(recent: [SessionDisplayItem], prev: [SessionDisplayItem]) -> JourneyPhaseSummary {
        let rs = recent.filter { $0.phase == .fourMetersBlasting }
        let ps = prev.filter   { $0.phase == .fourMetersBlasting }
        let scores = rs.compactMap(\.sessionScore)
        let pScores = ps.compactMap(\.sessionScore)
        let avg    = scores.isEmpty ? 0.0  : Double(scores.reduce(0, +)) / Double(scores.count)
        let prvAvg = pScores.isEmpty ? 0.0 : Double(pScores.reduce(0, +)) / Double(pScores.count)
        let delta  = avg - prvAvg
        let spark  = rs.suffix(10).compactMap { $0.sessionScore.map(Double.init) }
        let statStr = scores.isEmpty ? "—" : (avg >= 0 ? String(format: "+%.1f", avg) : String(format: "%.1f", avg))
        let deltaStr = delta <= 0 ? String(format: "%.1f", delta) : String(format: "+%.1f", delta)
        return JourneyPhaseSummary(
            phase: .fourMeter,
            bigStat: statStr,
            subLabel: "Avg score",
            delta: deltaStr,
            deltaPositive: delta <= 0, // lower is better for 4m
            sparkValues: spark.isEmpty ? [0] : spark
        )
    }

    private func inkastingSummary(recent: [SessionDisplayItem], prev: [SessionDisplayItem]) -> JourneyPhaseSummary {
        let rs = recent.filter { $0.phase == .inkastingDrilling }
        let ps = prev.filter   { $0.phase == .inkastingDrilling }
        // Use accuracy as proxy for cluster tightness (higher = better in session model)
        let avg    = rs.isEmpty ? 0.0 : rs.map(\.accuracy).reduce(0, +) / Double(rs.count)
        let prvAvg = ps.isEmpty ? 0.0 : ps.map(\.accuracy).reduce(0, +) / Double(ps.count)
        let delta  = avg - prvAvg
        let spark  = rs.suffix(10).map { $0.accuracy }
        return JourneyPhaseSummary(
            phase: .inkasting,
            bigStat: rs.isEmpty ? "—" : String(format: "%.1f%%", avg),
            subLabel: "Avg accuracy",
            delta: delta >= 0 ? String(format: "+%.1f%%", delta) : String(format: "%.1f%%", delta),
            deltaPositive: delta >= 0,
            sparkValues: spark.isEmpty ? [0] : spark
        )
    }

    private func pressureCookerSummary(recent: [SessionDisplayItem], prev: [SessionDisplayItem]) -> JourneyPhaseSummary {
        let rs = recent.filter { $0.phase == .pressureCooker }
        let ps = prev.filter   { $0.phase == .pressureCooker }
        let scores = rs.compactMap(\.sessionScore)
        let pScores = ps.compactMap(\.sessionScore)
        let best   = scores.max() ?? 0
        let pBest  = pScores.max() ?? 0
        let delta  = best - pBest
        let spark  = rs.suffix(10).compactMap { $0.sessionScore.map(Double.init) }
        return JourneyPhaseSummary(
            phase: .pressureCooker,
            bigStat: rs.isEmpty ? "—" : "\(best)",
            subLabel: "Best score",
            delta: delta >= 0 ? "+\(delta)" : "\(delta)",
            deltaPositive: delta >= 0,
            sparkValues: spark.isEmpty ? [0] : spark
        )
    }

    // MARK: – Heatmap (13 weeks × 7 days, col-major, Sun→Sat)

    func computeHeatmap(sessions: [SessionDisplayItem]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dow = cal.component(.weekday, from: today) - 1  // 0=Sun

        let totalDays = 13 * 7 + dow + 1
        guard let startDate = cal.date(byAdding: .day, value: -(totalDays - 1), to: today) else { return }

        var countsByDay: [Date: Int] = [:]
        for s in sessions {
            let d = cal.startOfDay(for: s.createdAt)
            countsByDay[d, default: 0] += 1
        }

        var allCells: [HeatCell] = []
        for i in 0..<totalDays {
            guard let date = cal.date(byAdding: .day, value: i, to: startDate) else { continue }
            let isFuture = date > today
            let count = isFuture ? 0 : min(3, countsByDay[date] ?? 0)
            allCells.append(HeatCell(date: date, count: count,
                                     isToday: date == today, isFuture: isFuture))
        }

        // Chunk into 7-day columns
        heatmap = stride(from: 0, to: allCells.count, by: 7).map { start in
            Array(allCells[start..<min(start + 7, allCells.count)])
        }
    }

    // MARK: – Ledger (6 most recent)

    private func computeLedger(sessions: [SessionDisplayItem]) {
        let sorted = sessions.sorted { $0.createdAt > $1.createdAt }
        recentLedger = sorted.prefix(6).compactMap { s -> LedgerRow? in
            guard let kp = kubbPhase(for: s.phase) else { return nil }
            return LedgerRow(
                id: s.id,
                phase: kp,
                dateLabel: relativeDateLabel(s.createdAt),
                timeLabel: timeLabel(s.createdAt),
                statLine: statLine(for: s),
                subLine: subLine(for: s),
                isPersonalBest: false,
                session: s
            )
        }
    }

    private func kubbPhase(for tp: TrainingPhase) -> KubbPhase? {
        switch tp {
        case .eightMeters:       return .eightMeter
        case .fourMetersBlasting: return .fourMeter
        case .inkastingDrilling:  return .inkasting
        case .pressureCooker:     return .pressureCooker
        case .gameTracker:        return nil
        }
    }

    private func statLine(for s: SessionDisplayItem) -> String {
        switch s.phase {
        case .eightMeters:       return String(format: "%.1f%%", s.accuracy)
        case .fourMetersBlasting: return s.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .inkastingDrilling:  return String(format: "%.1f%%", s.accuracy)
        case .pressureCooker:     return s.sessionScore.map { "\($0)" } ?? "—"
        case .gameTracker:        return "—"
        }
    }

    private func subLine(for s: SessionDisplayItem) -> String {
        let rounds = "\(s.roundCount)/\(s.configuredRounds)"
        let dur = s.durationFormatted ?? ""
        return [rounds, dur].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func relativeDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let d = cal.startOfDay(for: date)
        let diff = cal.dateComponents([.day], from: d, to: today).day ?? 0
        switch diff {
        case 0:  return "TODAY"
        case 1:  return "YSTD"
        default:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return fmt.string(from: date).uppercased()
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: date)
    }
}
