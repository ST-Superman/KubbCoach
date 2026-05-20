//
//  EmailReportComposerHost.swift
//  Kubb Coach
//

import SwiftUI
import SwiftData
import MessageUI
import OSLog

/// Listens for `.presentEmailReportComposer` (posted by AppDelegate when the
/// user taps the weekly email-report notification) and presents
/// `MFMailComposeViewController` pre-populated with the generated report.
///
/// Apply once at the root content view via `.emailReportComposerHost()` so
/// the composer can be presented from anywhere in the app.
struct EmailReportComposerHost: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var emailSettingsQuery: [EmailReportSettings]
    @State private var pendingItem: ComposerItem?
    @State private var noMailAccountAlert = false
    @State private var composeResult: Result<MFMailComposeResult, Error>?

    private static let logger = Logger(subsystem: "com.sathomps.kubbcoach", category: "email-composer-host")

    private var settings: EmailReportSettings? {
        emailSettingsQuery.first
    }

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .presentEmailReportComposer)) { _ in
                handleNotificationTap()
            }
            .sheet(item: $pendingItem) { item in
                MailComposeView(
                    recipients: [item.recipient],
                    subject: item.subject,
                    messageBody: item.html,
                    isHTML: true,
                    result: $composeResult,
                    onComplete: { result, error in
                        handleCompose(result: result, error: error)
                    }
                )
            }
            .alert("Mail Not Configured", isPresented: $noMailAccountAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please configure a mail account in iOS Settings before sending your training report.")
            }
    }

    private func handleNotificationTap() {
        guard let settings, settings.isEnabled, let email = settings.email, !email.isEmpty else {
            Self.logger.warning("Email-report tap received but settings disabled or email empty")
            return
        }
        guard MFMailComposeViewController.canSendMail() else {
            Self.logger.warning("Email-report tap received but Mail not configured on device")
            noMailAccountAlert = true
            // Still reschedule so the user gets another chance next cycle.
            Task { await EmailReportScheduler.shared.scheduleNext(for: settings) }
            return
        }

        let inputs = EmailReportInputBuilder.build(from: modelContext)
        let report = EmailReportService.generateReport(
            sessions: inputs.sessions,
            gameSessions: inputs.gameSessions,
            pressureCookerSessions: inputs.pcSessions,
            playerLevel: inputs.playerLevel,
            streak: inputs.streak,
            competitionSettings: inputs.competitionSettings,
            inkastingSettings: inputs.inkastingSettings,
            modelContext: modelContext,
            frequency: settings.frequency
        )

        pendingItem = ComposerItem(
            recipient: email,
            subject: report.subject,
            html: report.htmlBody
        )
    }

    private func handleCompose(result: MFMailComposeResult, error: Error?) {
        // Capture before defer so the closure sees a stable reference.
        let currentSettings = settings

        defer {
            // Always reschedule the next occurrence — even on cancel — so the
            // user gets another notification next cycle.
            if let currentSettings {
                Task { await EmailReportScheduler.shared.scheduleNext(for: currentSettings) }
            }
            pendingItem = nil
            composeResult = nil
        }

        if let error {
            Self.logger.error("Mail compose failed: \(error.localizedDescription)")
            return
        }

        switch result {
        case .sent:
            currentSettings?.lastSentAt = Date()
            try? modelContext.save()
            Self.logger.info("Email report sent — lastSentAt updated")
        case .cancelled:
            Self.logger.info("Email report compose cancelled by user")
        case .saved:
            Self.logger.info("Email report saved as draft")
        case .failed:
            Self.logger.warning("Email report send failed")
        @unknown default:
            break
        }
    }
}

private struct ComposerItem: Identifiable {
    let id = UUID()
    let recipient: String
    let subject: String
    let html: String
}

extension View {
    /// Listens for `.presentEmailReportComposer` and presents the pre-populated
    /// mail composer. Apply once at the root content view (after `.modelContainer`).
    func emailReportComposerHost() -> some View {
        modifier(EmailReportComposerHost())
    }
}
