//
//  EmailReportService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/9/26.
//

import Foundation
import SwiftData
import MessageUI

/// Service for generating and sending email training reports
@MainActor
class EmailReportService {

    // MARK: - Report Generation

    /// Generates an HTML email report based on current training data
    static func generateReport(
        sessions: [SessionDisplayItem],
        playerLevel: PlayerLevel,
        streak: Int,
        competitionSettings: CompetitionSettings?,
        inkastingSettings: InkastingSettings,
        modelContext: ModelContext
    ) -> EmailReport {
        let reportPeriod = determineReportPeriod(from: sessions)
        let stats = calculateStatistics(from: sessions, inkastingSettings: inkastingSettings, modelContext: modelContext)

        let htmlBody = buildHTMLReport(
            reportPeriod: reportPeriod,
            playerLevel: playerLevel,
            streak: streak,
            stats: stats,
            competitionSettings: competitionSettings
        )

        return EmailReport(
            subject: "Your Kubb Training Report - \(reportPeriod)",
            htmlBody: htmlBody,
            generatedAt: Date()
        )
    }

    // MARK: - Statistics Calculation

    private static func determineReportPeriod(from sessions: [SessionDisplayItem]) -> String {
        guard let mostRecent = sessions.first?.createdAt else {
            return "All Time"
        }

        let calendar = Calendar.current
        let now = Date()
        let daysSince = calendar.dateComponents([.day], from: mostRecent, to: now).day ?? 0

        if daysSince <= 7 {
            return "This Week"
        } else if daysSince <= 14 {
            return "Last 2 Weeks"
        } else if daysSince <= 30 {
            return "This Month"
        } else {
            return "Recent Training"
        }
    }

    private static func calculateStatistics(
        from sessions: [SessionDisplayItem],
        inkastingSettings: InkastingSettings,
        modelContext: ModelContext
    ) -> ReportStatistics {
        let eightMeterSessions = sessions.filter { $0.phase == .eightMeters }
        let blastingSessions = sessions.filter { $0.phase == .fourMetersBlasting }
        let inkastingSessions = sessions.filter { $0.phase == .inkastingDrilling }

        // 8 Meter Stats
        let best8MAccuracy = eightMeterSessions.map { $0.accuracy }.max() ?? 0.0
        let avg8MAccuracy = eightMeterSessions.isEmpty ? 0.0 : eightMeterSessions.map { $0.accuracy }.reduce(0, +) / Double(eightMeterSessions.count)

        // Blasting Stats
        let bestBlastingScore = blastingSessions.compactMap { $0.sessionScore }.min() ?? 0
        let avgBlastingScore = blastingSessions.isEmpty ? 0 : blastingSessions.compactMap { $0.sessionScore }.reduce(0, +) / blastingSessions.count

        // Inkasting Stats
        var bestInkastingArea: Double?
        var avgInkastingArea: Double?

        if !inkastingSessions.isEmpty {
            var totalArea = 0.0
            var analysisCount = 0
            var bestArea: Double?

            for session in inkastingSessions.prefix(20) {
                if let localSession = session.localSession {
                    let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
                    for analysis in analyses {
                        let area = analysis.clusterAreaSquareMeters
                        totalArea += area
                        analysisCount += 1

                        if bestArea == nil || area < bestArea! {
                            bestArea = area
                        }
                    }
                }
            }

            if analysisCount > 0 {
                avgInkastingArea = totalArea / Double(analysisCount)
                bestInkastingArea = bestArea
            }
        }

        return ReportStatistics(
            totalSessions: sessions.count,
            eightMeterCount: eightMeterSessions.count,
            blastingCount: blastingSessions.count,
            inkastingCount: inkastingSessions.count,
            best8MAccuracy: best8MAccuracy,
            avg8MAccuracy: avg8MAccuracy,
            bestBlastingScore: bestBlastingScore,
            avgBlastingScore: avgBlastingScore,
            bestInkastingArea: bestInkastingArea,
            avgInkastingArea: avgInkastingArea
        )
    }

    // MARK: - HTML Generation

    private static func buildHTMLReport(
        reportPeriod: String,
        playerLevel: PlayerLevel,
        streak: Int,
        stats: ReportStatistics,
        competitionSettings: CompetitionSettings?
    ) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f5f5f5;">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #f5f5f5; padding: 20px 0;">
                <tr>
                    <td align="center">
                        <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff; max-width: 600px;">
                            <!-- Header -->
                            <tr>
                                <td style="padding: 30px 30px 20px 30px; text-align: center; border-bottom: 3px solid #006aa7;">
                                    <h1 style="margin: 0; color: #006aa7; font-size: 28px;">🎯 Kubb Coach Training Report</h1>
                                    <p style="margin: 5px 0 0 0; color: #666666; font-size: 14px;">\(reportPeriod)</p>
                                </td>
                            </tr>

                            <!-- Player Card -->
                            <tr>
                                <td style="padding: 30px;">
                                    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #006aa7; color: #ffffff;">
                                        <tr>
                                            <td style="padding: 20px; text-align: center;">
                                                <div style="font-size: 14px; color: #ffffff; margin-bottom: 5px;">\(playerLevel.name) (\(playerLevel.subtitle))</div>
                                                <div style="font-size: 32px; font-weight: bold; color: #ffffff;">Level \(playerLevel.levelNumber)</div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 0 20px 20px 20px;">
                                                <table width="100%" cellpadding="10" cellspacing="0" border="0">
                                                    <tr>
                                                        <td width="33%" align="center" style="color: #ffffff;">
                                                            <div style="font-size: 24px; font-weight: bold;">\(formatXP(playerLevel.currentXP))</div>
                                                            <div style="font-size: 12px; color: #cccccc;">Total XP</div>
                                                        </td>
                                                        <td width="33%" align="center" style="color: #ffffff;">
                                                            <div style="font-size: 24px; font-weight: bold;">\(streak)</div>
                                                            <div style="font-size: 12px; color: #cccccc;">Day Streak</div>
                                                        </td>
                                                        <td width="33%" align="center" style="color: #ffffff;">
                                                            <div style="font-size: 24px; font-weight: bold;">\(stats.totalSessions)</div>
                                                            <div style="font-size: 12px; color: #cccccc;">Sessions</div>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Competition Section -->
                            \(buildCompetitionSection(competitionSettings))

                            <!-- Training Overview -->
                            <tr>
                                <td style="padding: 0 30px 25px 30px;">
                                    <div style="color: #006aa7; font-size: 18px; font-weight: bold; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #e0e0e0;">📊 Training Overview</div>
                                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                        <tr>
                                            <td width="48%" style="padding: 15px; background-color: #f9f9f9; border-left: 4px solid #006aa7;" valign="top">
                                                <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">8 Meter Sessions</div>
                                                <div style="font-size: 20px; font-weight: bold; color: #333333;">\(stats.eightMeterCount)</div>
                                            </td>
                                            <td width="4%"></td>
                                            <td width="48%" style="padding: 15px; background-color: #f9f9f9; border-left: 4px solid #006aa7;" valign="top">
                                                <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Blasting Sessions</div>
                                                <div style="font-size: 20px; font-weight: bold; color: #333333;">\(stats.blastingCount)</div>
                                            </td>
                                        </tr>
                                        <tr><td colspan="3" height="15"></td></tr>
                                        <tr>
                                            <td width="48%" style="padding: 15px; background-color: #f9f9f9; border-left: 4px solid #006aa7;" valign="top">
                                                <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Inkasting Sessions</div>
                                                <div style="font-size: 20px; font-weight: bold; color: #333333;">\(stats.inkastingCount)</div>
                                            </td>
                                            <td width="4%"></td>
                                            <td width="48%" style="padding: 15px; background-color: #f9f9f9; border-left: 4px solid #006aa7;" valign="top">
                                                <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Total Sessions</div>
                                                <div style="font-size: 20px; font-weight: bold; color: #333333;">\(stats.totalSessions)</div>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Personal Bests -->
                            <tr>
                                <td style="padding: 0 30px 25px 30px;">
                                    <div style="color: #006aa7; font-size: 18px; font-weight: bold; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #e0e0e0;">🏆 Personal Bests</div>
                                    \(buildPhaseStats(stats))
                                </td>
                            </tr>

                            <!-- Footer -->
                            <tr>
                                <td style="padding: 20px 30px 30px 30px; text-align: center; border-top: 2px solid #e0e0e0;">
                                    <p style="margin: 0; color: #666666; font-size: 12px;">Generated by Kubb Coach on \(formatDate(Date()))</p>
                                    <p style="margin: 5px 0 0 0; color: #666666; font-size: 12px;">Keep training hard! 🎯</p>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
        </body>
        </html>
        """
    }

    private static func buildCompetitionSection(_ settings: CompetitionSettings?) -> String {
        if let settings = settings,
           let competitionName = settings.competitionName,
           let daysRemaining = settings.daysUntilCompetition,
           !settings.isPast {
            let location = settings.competitionLocation ?? "TBD"
            return """
            <tr>
                <td style="padding: 0 30px 25px 30px;">
                    <table width="100%" cellpadding="20" cellspacing="0" border="0" style="background-color: #d4af37; color: #ffffff;">
                        <tr>
                            <td align="center">
                                <div style="font-size: 14px; color: #ffffff;">🏆 UPCOMING COMPETITION</div>
                                <div style="font-size: 24px; font-weight: bold; color: #ffffff; margin: 10px 0;">\(competitionName)</div>
                                <div style="font-size: 14px; color: #ffffff; margin-bottom: 10px;">📍 \(location)</div>
                                <div style="font-size: 36px; font-weight: bold; color: #ffffff; margin: 10px 0;">\(daysRemaining)</div>
                                <div style="font-size: 14px; color: #ffffff;">days remaining</div>
                                <div style="margin-top: 15px; font-size: 13px; color: #ffffff;">
                                    Stay focused on your training and bring your A-game!
                                </div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            """
        } else {
            return """
            <tr>
                <td style="padding: 0 30px 25px 30px;">
                    <table width="100%" cellpadding="20" cellspacing="0" border="0" style="background-color: #fff3cd; border: 2px solid #ffc107;">
                        <tr>
                            <td>
                                <div style="font-weight: bold; font-size: 16px; margin-bottom: 10px; color: #333333;">🎯 Ready to compete?</div>
                                <p style="margin: 10px 0; color: #333333; line-height: 1.6;">Training is great, but competing takes your skills to the next level! Consider finding a local Kubb tournament to test your abilities and meet other players.</p>
                                <p style="margin: 10px 0; font-size: 14px; color: #666666;">Visit <strong>kubbworldchampionship.com</strong> or search for local tournaments in your area.</p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            """
        }
    }

    private static func buildPhaseStats(_ stats: ReportStatistics) -> String {
        var html = ""

        // 8 Meter Stats
        if stats.eightMeterCount > 0 {
            html += """
            <table width="100%" cellpadding="15" cellspacing="0" border="0" style="background-color: #f9f9f9; border-left: 4px solid #d4af37; margin-bottom: 15px;">
                <tr>
                    <td colspan="2" style="font-weight: bold; font-size: 16px; color: #333333; padding-bottom: 10px;">8 Meter Precision</td>
                </tr>
                <tr>
                    <td width="50%" valign="top">
                        <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Best Accuracy</div>
                        <div style="font-size: 20px; font-weight: bold; color: #333333;">\(String(format: "%.1f%%", stats.best8MAccuracy))</div>
                    </td>
                    <td width="50%" valign="top">
                        <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Average Accuracy</div>
                        <div style="font-size: 20px; font-weight: bold; color: #333333;">\(String(format: "%.1f%%", stats.avg8MAccuracy))</div>
                    </td>
                </tr>
            </table>
            """
        }

        // Blasting Stats
        if stats.blastingCount > 0 {
            let bestScoreStr = stats.bestBlastingScore < 0 ? "\(stats.bestBlastingScore)" : "+\(stats.bestBlastingScore)"
            let avgScoreStr = stats.avgBlastingScore < 0 ? "\(stats.avgBlastingScore)" : "+\(stats.avgBlastingScore)"

            html += """
            <table width="100%" cellpadding="15" cellspacing="0" border="0" style="background-color: #f9f9f9; border-left: 4px solid #ff6b35; margin-bottom: 15px;">
                <tr>
                    <td colspan="2" style="font-weight: bold; font-size: 16px; color: #333333; padding-bottom: 10px;">4 Meter Blasting</td>
                </tr>
                <tr>
                    <td width="50%" valign="top">
                        <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Best Score</div>
                        <div style="font-size: 20px; font-weight: bold; color: #333333;">\(bestScoreStr)</div>
                    </td>
                    <td width="50%" valign="top">
                        <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Average Score</div>
                        <div style="font-size: 20px; font-weight: bold; color: #333333;">\(avgScoreStr)</div>
                    </td>
                </tr>
            </table>
            """
        }

        // Inkasting Stats
        if stats.inkastingCount > 0, let bestArea = stats.bestInkastingArea, let avgArea = stats.avgInkastingArea {
            let settings = InkastingSettings()
            html += """
            <table width="100%" cellpadding="15" cellspacing="0" border="0" style="background-color: #f9f9f9; border-left: 4px solid #4ecdc4;">
                <tr>
                    <td colspan="2" style="font-weight: bold; font-size: 16px; color: #333333; padding-bottom: 10px;">Inkasting Drilling</td>
                </tr>
                <tr>
                    <td width="50%" valign="top">
                        <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Best Core Area</div>
                        <div style="font-size: 20px; font-weight: bold; color: #333333;">\(settings.formatArea(bestArea))</div>
                    </td>
                    <td width="50%" valign="top">
                        <div style="font-size: 12px; color: #666666; margin-bottom: 5px;">Average Core Area</div>
                        <div style="font-size: 20px; font-weight: bold; color: #333333;">\(settings.formatArea(avgArea))</div>
                    </td>
                </tr>
            </table>
            """
        }

        if html.isEmpty {
            html = "<p style='color: #666666;'>Complete some training sessions to see your personal bests!</p>"
        }

        return html
    }

    private static func formatXP(_ xp: Int) -> String {
        if xp >= 1000 {
            return String(format: "%.1fk", Double(xp) / 1000.0)
        }
        return "\(xp)"
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct EmailReport {
    let subject: String
    let htmlBody: String
    let generatedAt: Date
}

struct ReportStatistics {
    let totalSessions: Int
    let eightMeterCount: Int
    let blastingCount: Int
    let inkastingCount: Int
    let best8MAccuracy: Double
    let avg8MAccuracy: Double
    let bestBlastingScore: Int
    let avgBlastingScore: Int
    let bestInkastingArea: Double?
    let avgInkastingArea: Double?
}
