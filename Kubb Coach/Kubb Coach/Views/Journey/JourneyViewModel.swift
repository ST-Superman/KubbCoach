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
    let session: SessionDisplayItem?         // training session
    let gameSession: GameSession?            // game tracker session
    let pcSession: PressureCookerSession?    // pressure cooker session

    init(id: UUID, phase: KubbPhase, dateLabel: String, timeLabel: String,
         statLine: String, subLine: String, isPersonalBest: Bool,
         session: SessionDisplayItem? = nil,
         gameSession: GameSession? = nil,
         pcSession: PressureCookerSession? = nil) {
        self.id = id; self.phase = phase; self.dateLabel = dateLabel
        self.timeLabel = timeLabel; self.statLine = statLine
        self.subLine = subLine; self.isPersonalBest = isPersonalBest
        self.session = session; self.gameSession = gameSession
        self.pcSession = pcSession
    }
}

// MARK: – View model

@Observable
@MainActor
final class JourneyViewModel {

    // MARK: Published state

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var daysThisMonth: Int = 0
    var prevMonthDays: Int = 0
    var avgTimeThisMonth: Double = 0.0
    var prevMonthAvgTime: Double = 0.0
    var last14Days: [Bool] = Array(repeating: false, count: 14)
    var phaseSummaries: [JourneyPhaseSummary] = []
    var heatmap: [[HeatCell]] = []   // 13 weeks × 7 days
    var recentLedger: [LedgerRow] = []
    var totalSessionCount: Int = 0

    private let modelContext: ModelContext
    private var refreshTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: – Refresh

    func refresh(sessions: [SessionDisplayItem], gameSessions: [GameSession] = [], pcSessions: [PressureCookerSession] = []) {
        refreshTask?.cancel()
        refreshTask = Task {
            await performRefresh(sessions: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        }
    }

    private func performRefresh(sessions: [SessionDisplayItem], gameSessions: [GameSession], pcSessions: [PressureCookerSession]) async {
        totalSessionCount = sessions.count + gameSessions.count + pcSessions.count
        guard !Task.isCancelled else { return }; await Task.yield()

        computeStreak(sessions: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        guard !Task.isCancelled else { return }; await Task.yield()

        computeLast14Days(sessions: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        guard !Task.isCancelled else { return }; await Task.yield()

        computeHeatmap(sessions: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        guard !Task.isCancelled else { return }; await Task.yield()

        computeLedger(sessions: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        guard !Task.isCancelled else { return }; await Task.yield()

        computeMonthStats(sessions: sessions)
        guard !Task.isCancelled else { return }; await Task.yield()

        computePhaseSummaries(sessions: sessions, pcSessions: pcSessions)
    }

    // MARK: – Streak

    private func computeStreak(sessions: [SessionDisplayItem], gameSessions: [GameSession], pcSessions: [PressureCookerSession]) {
        currentStreak = StreakCalculator.currentStreak(from: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        longestStreak = StreakCalculator.longestStreak(from: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
    }

    // MARK: – Last 14 days dots

    private func computeLast14Days(sessions: [SessionDisplayItem], gameSessions: [GameSession], pcSessions: [PressureCookerSession]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let completedGames = gameSessions.filter {
            $0.completedAt != nil && $0.endReason != GameEndReason.abandoned.rawValue
        }
        let completedPC = pcSessions.filter { $0.completedAt != nil }
        var activeDays = Set(sessions.map { cal.startOfDay(for: $0.createdAt) })
        activeDays.formUnion(completedGames.map { cal.startOfDay(for: $0.createdAt) })
        activeDays.formUnion(completedPC.map { cal.startOfDay(for: $0.createdAt) })
        // index 0 = oldest (13 days ago), index 13 = today
        last14Days = (0..<14).map { offset in
            let day = cal.date(byAdding: .day, value: -(13 - offset), to: today)!
            return activeDays.contains(day)
        }
    }

    // MARK: – Phase summaries (last 30 days)

    private func computePhaseSummaries(sessions: [SessionDisplayItem], pcSessions: [PressureCookerSession]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let prior  = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let recent = sessions.filter { $0.createdAt >= cutoff }
        let prev   = sessions.filter { $0.createdAt >= prior && $0.createdAt < cutoff }
        let recentPC = pcSessions.filter { $0.createdAt >= cutoff }
        let prevPC   = pcSessions.filter { $0.createdAt >= prior && $0.createdAt < cutoff }

        phaseSummaries = [
            eightMeterSummary(recent: recent, prev: prev),
            fourMeterSummary(recent: recent, prev: prev),
            inkastingSummary(recent: recent, prev: prev),
            pcModeSummary(phase: .pressureCooker343,
                          mode: .threeForThree,
                          recent: recentPC, prev: prevPC),
            pcModeSummary(phase: .pressureCookerInTheRed,
                          mode: .inTheRed,
                          recent: recentPC, prev: prevPC),
        ]
    }

    private func eightMeterSummary(recent: [SessionDisplayItem], prev: [SessionDisplayItem]) -> JourneyPhaseSummary {
        let rs = recent.filter { $0.phase == .eightMeters }
        let ps = prev.filter   { $0.phase == .eightMeters }
        let avg    = rs.isEmpty ? 0.0 : rs.map(\.accuracy).reduce(0, +) / Double(rs.count)
        let prvAvg = ps.isEmpty ? 0.0 : ps.map(\.accuracy).reduce(0, +) / Double(ps.count)
        let delta  = avg - prvAvg
        let spark  = rs.sorted { $0.createdAt < $1.createdAt }.suffix(10).map { $0.accuracy }
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
        let spark  = rs.sorted { $0.createdAt < $1.createdAt }.suffix(10).compactMap { $0.sessionScore.map(Double.init) }
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

        // Headline: avg cluster radius (lower is better). Drop sessions that have
        // no analyses (e.g. cloud-only or skipped capture) so they don't skew the avg.
        let rRadii = rs.compactMap { $0.averageClusterRadius(context: modelContext) }
        let pRadii = ps.compactMap { $0.averageClusterRadius(context: modelContext) }
        let avg    = rRadii.isEmpty ? 0.0 : rRadii.reduce(0, +) / Double(rRadii.count)
        let prvAvg = pRadii.isEmpty ? 0.0 : pRadii.reduce(0, +) / Double(pRadii.count)
        let delta  = avg - prvAvg
        let spark  = rs.sorted { $0.createdAt < $1.createdAt }
                        .compactMap { $0.averageClusterRadius(context: modelContext) }
                        .suffix(10)

        let bigStat = rRadii.isEmpty ? "—" : String(format: "%.2fm", avg)
        // Lower radius = better, so flip the sign convention for "positive" delta.
        let deltaStr: String
        if rRadii.isEmpty || pRadii.isEmpty {
            deltaStr = "—"
        } else {
            deltaStr = delta <= 0 ? String(format: "%.2fm", delta) : String(format: "+%.2fm", delta)
        }
        return JourneyPhaseSummary(
            phase: .inkasting,
            bigStat: bigStat,
            subLabel: "Avg cluster radius",
            delta: deltaStr,
            deltaPositive: delta <= 0,
            sparkValues: spark.isEmpty ? [0] : Array(spark)
        )
    }

    private func pcModeSummary(
        phase: KubbPhase,
        mode: PressureCookerGameType,
        recent: [PressureCookerSession],
        prev: [PressureCookerSession]
    ) -> JourneyPhaseSummary {
        let rs = recent.filter { $0.gameType == mode.rawValue }
        let ps = prev.filter   { $0.gameType == mode.rawValue }
        let best   = rs.map { $0.totalScore }.max() ?? 0
        let pBest  = ps.map { $0.totalScore }.max() ?? 0
        let delta  = best - pBest
        let spark  = rs.sorted { $0.createdAt < $1.createdAt }.suffix(10).map { Double($0.totalScore) }

        let bigStat: String
        let deltaStr: String
        if rs.isEmpty {
            bigStat = "—"
            deltaStr = "+0"
        } else {
            switch mode {
            case .threeForThree:
                bigStat = "\(best)"
                deltaStr = delta >= 0 ? "+\(delta)" : "\(delta)"
            case .inTheRed:
                bigStat = best >= 0 ? "+\(best)" : "\(best)"
                deltaStr = delta >= 0 ? "+\(delta)" : "\(delta)"
            }
        }

        return JourneyPhaseSummary(
            phase: phase,
            bigStat: bigStat,
            subLabel: "Best score",
            delta: deltaStr,
            deltaPositive: delta >= 0,
            sparkValues: spark.isEmpty ? [0] : Array(spark)
        )
    }

    // MARK: – Heatmap (13 weeks × 7 days, col-major, Sun→Sat)

    func computeHeatmap(sessions: [SessionDisplayItem], gameSessions: [GameSession] = [], pcSessions: [PressureCookerSession] = []) {
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
        for g in gameSessions where g.completedAt != nil && g.endReason != GameEndReason.abandoned.rawValue {
            let d = cal.startOfDay(for: g.createdAt)
            countsByDay[d, default: 0] += 1
        }
        for p in pcSessions where p.completedAt != nil {
            let d = cal.startOfDay(for: p.createdAt)
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

    // MARK: – Ledger (6 most recent across all session types)

    private func computeLedger(sessions: [SessionDisplayItem], gameSessions: [GameSession], pcSessions: [PressureCookerSession]) {
        let trainingRows: [(Date, LedgerRow)] = sessions.compactMap { s in
            guard let kp = kubbPhase(for: s.phase) else { return nil }
            return (s.createdAt, LedgerRow(
                id: s.id,
                phase: kp,
                dateLabel: relativeDateLabel(s.createdAt),
                timeLabel: timeLabel(s.createdAt),
                statLine: statLine(for: s),
                subLine: subLine(for: s),
                isPersonalBest: false,
                session: s
            ))
        }

        let gameRows: [(Date, LedgerRow)] = gameSessions.map { g in
            (g.createdAt, LedgerRow(
                id: g.id,
                phase: .gameTracker,
                dateLabel: relativeDateLabel(g.createdAt),
                timeLabel: timeLabel(g.createdAt),
                statLine: gameStatLine(for: g),
                subLine: gameSubLine(for: g),
                isPersonalBest: false,
                gameSession: g
            ))
        }

        let pcRows: [(Date, LedgerRow)] = pcSessions.filter { $0.completedAt != nil }.map { p in
            (p.createdAt, LedgerRow(
                id: p.id,
                phase: .pressureCooker,
                dateLabel: relativeDateLabel(p.createdAt),
                timeLabel: timeLabel(p.createdAt),
                statLine: pcStatLine(for: p),
                subLine: pcSubLine(for: p),
                isPersonalBest: false,
                pcSession: p
            ))
        }

        recentLedger = (trainingRows + gameRows + pcRows)
            .sorted { $0.0 > $1.0 }
            .prefix(6)
            .map { $0.1 }
    }

    private func kubbPhase(for tp: TrainingPhase) -> KubbPhase? {
        switch tp {
        case .eightMeters:        return .eightMeter
        case .fourMetersBlasting: return .fourMeter
        case .inkastingDrilling:  return .inkasting
        case .pressureCooker:     return .pressureCooker
        case .gameTracker:        return nil  // game sessions handled separately
        }
    }

    private func statLine(for s: SessionDisplayItem) -> String {
        switch s.phase {
        case .eightMeters:        return String(format: "%.1f%%", s.accuracy)
        case .fourMetersBlasting: return s.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .inkastingDrilling:
            return s.averageClusterRadius(context: modelContext)
                .map { String(format: "%.2fm", $0) } ?? "—"
        case .pressureCooker:     return s.sessionScore.map { "\($0)" } ?? "—"
        case .gameTracker:        return "—"
        }
    }

    private func gameStatLine(for g: GameSession) -> String {
        switch g.gameMode {
        case .competitive:
            if let won = g.userWon { return won ? "Win" : "Loss" }
            return "Abandoned"
        case .phantom:
            return "Phantom"
        }
    }

    private func gameSubLine(for g: GameSession) -> String {
        let turns = "\(g.turns.count) turn\(g.turns.count == 1 ? "" : "s")"
        guard let completed = g.completedAt else { return turns }
        let secs = Int(completed.timeIntervalSince(g.createdAt))
        let dur = secs >= 60 ? "\(secs / 60)m" : "\(secs)s"
        return "\(turns) · \(dur)"
    }

    private func pcStatLine(for p: PressureCookerSession) -> String {
        "\(p.totalScore)"
    }

    private func pcSubLine(for p: PressureCookerSession) -> String {
        let type = PressureCookerGameType(rawValue: p.gameType)?.displayName ?? "Pressure Cooker"
        let frames = "\(p.framesCompleted) frame\(p.framesCompleted == 1 ? "" : "s")"
        guard let completed = p.completedAt else { return "\(type) · \(frames)" }
        let secs = Int(completed.timeIntervalSince(p.createdAt))
        let dur = secs >= 60 ? "\(secs / 60)m" : "\(secs)s"
        return "\(type) · \(frames) · \(dur)"
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

    // MARK: – Month consistency stats

    private func computeMonthStats(sessions: [SessionDisplayItem]) {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let thisMonthStart = cal.date(from: comps),
              let prevMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart)
        else { return }

        let thisMonth = sessions.filter { $0.createdAt >= thisMonthStart && $0.completedAt != nil }
        let prevMonth = sessions.filter { $0.createdAt >= prevMonthStart && $0.createdAt < thisMonthStart && $0.completedAt != nil }

        let thisMonthDaySet = Set(thisMonth.map { cal.startOfDay(for: $0.createdAt) })
        daysThisMonth = thisMonthDaySet.count

        let prevMonthDaySet = Set(prevMonth.map { cal.startOfDay(for: $0.createdAt) })
        prevMonthDays = prevMonthDaySet.count

        let thisMinutes = thisMonth.reduce(0.0) { acc, s in
            guard let completed = s.completedAt else { return acc }
            return acc + completed.timeIntervalSince(s.createdAt) / 60.0
        }
        avgTimeThisMonth = daysThisMonth > 0 ? thisMinutes / Double(daysThisMonth) : 0.0

        let prevMinutes = prevMonth.reduce(0.0) { acc, s in
            guard let completed = s.completedAt else { return acc }
            return acc + completed.timeIntervalSince(s.createdAt) / 60.0
        }
        prevMonthAvgTime = prevMonthDays > 0 ? prevMinutes / Double(prevMonthDays) : 0.0
    }
}
