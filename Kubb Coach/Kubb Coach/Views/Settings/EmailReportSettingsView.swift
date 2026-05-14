//
//  EmailReportSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import SwiftData
import MessageUI
import OSLog

/// Settings view for configuring email progress reports
struct EmailReportSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [EmailReportSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var localSessions: [TrainingSession]
    @Query private var prestigeQuery: [PlayerPrestige]
    @Query private var competitionSettingsQuery: [CompetitionSettings]
    @Query private var inkastingSettingsQuery: [InkastingSettings]

    @State private var emailAddress: String = ""
    @State private var selectedFrequency: ReportFrequency = .weekly
    @State private var isEnabled: Bool = false
    @State private var showingSaveConfirmation: Bool = false
    @State private var showOptInAlert: Bool = false
    @State private var previewReport: EmailReportPreview?
    @State private var emailReport: EmailReportItem?
    @State private var mailComposeResult: Result<MFMailComposeResult, Error>?

    private var settings: EmailReportSettings? {
        settingsQuery.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                enableHero
                    .padding(.horizontal, 16)

                if isEnabled {
                    frequencySection
                        .padding(.horizontal, 16)

                    if let lastSent = settings?.lastSentAt {
                        historyCard(lastSent: lastSent)
                            .padding(.horizontal, 16)
                    }

                    testingRow
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Email Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveSettings()
                } label: {
                    Text("Save")
                        .font(KubbFont.inter(16, weight: .semibold))
                        .foregroundStyle(Color.Kubb.swedishBlue)
                }
                .disabled(!isFormValid)
            }
        }
        .onAppear {
            loadSettings()
        }
        .alert("Enable Email Reports?", isPresented: $showOptInAlert) {
            Button("Enable", role: .none) {
                isEnabled = true
            }
            Button("Cancel", role: .cancel) {
                isEnabled = false
            }
        } message: {
            Text("You'll receive weekly training reports at your email address. You can disable this anytime in settings.")
        }
        .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your email report settings have been updated")
        }
        .sheet(item: $previewReport) { report in
            NavigationStack {
                EmailReportPreviewView(htmlContent: report.html)
                    .navigationTitle("Report Preview")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                previewReport = nil
                            }
                        }
                    }
            }
        }
        .sheet(item: $emailReport) { report in
            MailComposeView(
                recipients: [report.recipient],
                subject: "Test Report - Kubb Coach Training",
                messageBody: report.html,
                isHTML: true,
                result: $mailComposeResult
            )
        }
    }

    // MARK: - Enable hero card

    private var enableHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                gradientEnvelope

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sunday morning digest")
                        .font(KubbFont.fraunces(20, weight: .regular, italic: true))
                        .foregroundStyle(Color.Kubb.text)
                    Text("A recap of the week, in your inbox.")
                        .font(KubbFont.inter(12))
                        .foregroundStyle(Color.Kubb.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if newValue && !isEnabled {
                            showOptInAlert = true
                        } else {
                            isEnabled = newValue
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color.Kubb.phase4m)
            }

            if isEnabled {
                emailChip
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private var gradientEnvelope: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.Kubb.phase4m, Color.Kubb.swedishGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "envelope.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
    }

    private var emailChip: some View {
        HStack(spacing: 0) {
            TextField("your@email.com", text: $emailAddress)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .font(KubbFont.mono(13, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.Kubb.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Frequency segmented tiles

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("Frequency")
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                ForEach(ReportFrequency.allCases) { frequency in
                    FrequencyTile(
                        frequency: frequency,
                        isActive: frequency == selectedFrequency
                    ) {
                        HapticFeedbackService.shared.selection()
                        selectedFrequency = frequency
                    }
                }
            }
        }
    }

    // MARK: - History card

    private func historyCard(lastSent: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("History")
                .padding(.horizontal, 4)

            SettingsCard {
                historyRow(label: "Last sent",
                           value: formatDate(lastSent),
                           valueColor: Color.Kubb.textSec)
                historyRow(label: "Next report",
                           value: formatDate(nextReportDate(from: lastSent)),
                           valueColor: Color.Kubb.forestGreen)
            }
        }
    }

    private func historyRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(KubbFont.inter(15, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
            Spacer()
            Text(value)
                .font(KubbFont.inter(14, weight: .semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 56)
    }

    // MARK: - Testing row

    private var testingRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("Testing")
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Button {
                    generateTestReport()
                } label: {
                    testActionFace(icon: "eye.fill",
                                   title: "Preview",
                                   isPrimary: false)
                }
                .buttonStyle(.plain)

                Button {
                    sendTestEmail()
                } label: {
                    testActionFace(icon: "envelope.fill",
                                   title: "Send test",
                                   isPrimary: true)
                }
                .buttonStyle(.plain)
                .disabled(!MFMailComposeViewController.canSendMail() || emailAddress.isEmpty)
                .opacity((!MFMailComposeViewController.canSendMail() || emailAddress.isEmpty) ? 0.45 : 1)
            }
        }
    }

    private func testActionFace(icon: String, title: String, isPrimary: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(KubbFont.inter(15, weight: .semibold))
        }
        .foregroundStyle(isPrimary ? .white : Color.Kubb.swedishBlue)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isPrimary ? Color.Kubb.swedishBlue : Color.Kubb.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isPrimary ? Color.clear : Color.Kubb.sep, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helper Methods

    private func loadSettings() {
        guard let settings = settings else {
            // Create default settings if none exist
            let newSettings = EmailReportSettings()
            modelContext.insert(newSettings)
            return
        }

        emailAddress = settings.email ?? ""
        selectedFrequency = settings.frequency
        isEnabled = settings.isEnabled
    }

    private func saveSettings() {
        let settingsToUpdate: EmailReportSettings

        if let existing = settings {
            settingsToUpdate = existing
        } else {
            let newSettings = EmailReportSettings()
            modelContext.insert(newSettings)
            settingsToUpdate = newSettings
        }

        settingsToUpdate.email = emailAddress.isEmpty ? nil : emailAddress
        settingsToUpdate.frequency = selectedFrequency
        settingsToUpdate.isEnabled = isEnabled

        do {
            try modelContext.save()
            HapticFeedbackService.shared.success()
            showingSaveConfirmation = true
        } catch {
            AppLogger.general.error("Failed to save email settings: \(error)")
        }
    }

    private var isFormValid: Bool {
        if !isEnabled {
            return true // Can save if disabled
        }
        // If enabled, email must be valid
        return !emailAddress.isEmpty && emailAddress.contains("@")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func nextReportDate(from lastSent: Date) -> Date {
        let days = selectedFrequency.dayInterval
        return Calendar.current.date(byAdding: .day, value: days, to: lastSent) ?? lastSent
    }

    private func generateTestReport() {
        let allSessions = localSessions.map { SessionDisplayItem.local($0) }
        let prestige = prestigeQuery.first ?? PlayerPrestige()
        let playerLevel = PlayerLevelService.computeLevel(from: allSessions, context: modelContext, prestige: prestige)
        let streak = calculateCurrentStreak(from: allSessions)
        let competitionSettings = competitionSettingsQuery.first
        let inkastingSettings = inkastingSettingsQuery.first ?? InkastingSettings()

        AppLogger.general.debug(" Generating test report...")
        AppLogger.general.debug(" Sessions: \(allSessions.count)")
        AppLogger.general.debug(" Level: \(playerLevel.levelNumber)")
        AppLogger.general.debug(" Streak: \(streak)")

        let report = EmailReportService.generateReport(
            sessions: allSessions,
            playerLevel: playerLevel,
            streak: streak,
            competitionSettings: competitionSettings,
            inkastingSettings: inkastingSettings,
            modelContext: modelContext
        )

        AppLogger.general.debug(" HTML length: \(report.htmlBody.count) characters")
        AppLogger.general.debug(" HTML preview (first 200 chars): \(String(report.htmlBody.prefix(200)))")

        // Create preview item with the HTML
        AppLogger.general.debug(" About to show test report sheet")
        previewReport = EmailReportPreview(html: report.htmlBody)
    }

    private func sendTestEmail() {
        // Generate HTML immediately before showing composer
        let allSessions = localSessions.map { SessionDisplayItem.local($0) }
        let prestige = prestigeQuery.first ?? PlayerPrestige()
        let playerLevel = PlayerLevelService.computeLevel(from: allSessions, context: modelContext, prestige: prestige)
        let streak = calculateCurrentStreak(from: allSessions)
        let competitionSettings = competitionSettingsQuery.first
        let inkastingSettings = inkastingSettingsQuery.first ?? InkastingSettings()

        let report = EmailReportService.generateReport(
            sessions: allSessions,
            playerLevel: playerLevel,
            streak: streak,
            competitionSettings: competitionSettings,
            inkastingSettings: inkastingSettings,
            modelContext: modelContext
        )

        AppLogger.general.debug(" Email: Generated HTML, length: \(report.htmlBody.count)")

        // Create email item with the HTML
        emailReport = EmailReportItem(recipient: emailAddress, html: report.htmlBody)
    }

    private func calculateCurrentStreak(from sessions: [SessionDisplayItem]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var currentDate = today
        var streak = 0

        let sortedSessions = sessions
            .filter { $0.completedAt != nil }
            .sorted { $0.createdAt > $1.createdAt }

        guard !sortedSessions.isEmpty else { return 0 }

        let sessionsByDay = Dictionary(grouping: sortedSessions) { session in
            calendar.startOfDay(for: session.createdAt)
        }

        while true {
            if sessionsByDay[currentDate] != nil {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - Frequency tile

private struct FrequencyTile: View {
    let frequency: ReportFrequency
    let isActive: Bool
    let onTap: () -> Void

    private var caption: String {
        switch frequency {
        case .weekly:   return "EVERY 7 DAYS"
        case .biweekly: return "EVERY 14 DAYS"
        case .monthly:  return "EVERY 30 DAYS"
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.Kubb.forestGreen)
                        .padding(8)
                }

                VStack(spacing: 4) {
                    Text(frequency.displayName)
                        .font(KubbFont.fraunces(18, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                    Text(caption)
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(isActive ? Color.Kubb.card : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isActive ? Color.clear : Color.Kubb.sep, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isActive ? Color.black.opacity(0.05) : .clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Email Report Items

struct EmailReportPreview: Identifiable {
    let id = UUID()
    let html: String
}

struct EmailReportItem: Identifiable {
    let id = UUID()
    let recipient: String
    let html: String
}

// MARK: - Email Report Preview View

struct EmailReportPreviewView: View {
    let htmlContent: String
    @State private var showRawHTML = false

    var body: some View {
        VStack(spacing: 0) {
            if showRawHTML {
                ScrollView {
                    Text(htmlContent)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                }
            } else {
                if htmlContent.isEmpty {
                    ContentUnavailableView(
                        "No Content",
                        systemImage: "doc.text",
                        description: Text("The email report is empty")
                    )
                } else {
                    ScrollView {
                        WebView(htmlContent: htmlContent)
                            .frame(minHeight: 800)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(showRawHTML ? "Preview" : "View HTML") {
                    showRawHTML.toggle()
                }
            }
        }
        .onAppear {
            AppLogger.general.debug(" EmailReportPreviewView appeared")
            AppLogger.general.debug(" htmlContent length: \(htmlContent.count)")
            AppLogger.general.debug(" htmlContent isEmpty: \(htmlContent.isEmpty)")
            if !htmlContent.isEmpty {
                AppLogger.general.debug(" htmlContent preview: \(String(htmlContent.prefix(100)))")
            }
        }
    }
}

// MARK: - WebView for HTML Preview

import WebKit

struct WebView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Configure preferences
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor.systemBackground
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Write HTML to a temporary file and load from there
        // This avoids sandbox restrictions with loadHTMLString
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("email-preview.html")

        do {
            try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
            webView.loadFileURL(fileURL, allowingReadAccessTo: tempDir)
            AppLogger.general.debug(" WebView: Loading HTML from \(fileURL)")
        } catch {
            AppLogger.general.debug(" WebView: Failed to write HTML file: \(error)")
            // Fallback to loadHTMLString
            webView.loadHTMLString(htmlContent, baseURL: tempDir)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            AppLogger.general.debug(" WebView: Finished loading")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            AppLogger.general.debug(" WebView: Failed to load: \(error)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            AppLogger.general.debug(" WebView: Failed provisional navigation: \(error)")
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let messageBody: String
    let isHTML: Bool
    @Binding var result: Result<MFMailComposeResult, Error>?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: isHTML)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                parent.result = .failure(error)
            } else {
                parent.result = .success(result)
            }
            controller.dismiss(animated: true)
        }
    }
}


#Preview {
    NavigationStack {
        EmailReportSettingsView()
            .modelContainer(
                for: [
                    EmailReportSettings.self,
                    TrainingSession.self,
                    PlayerPrestige.self,
                    CompetitionSettings.self,
                    InkastingSettings.self
                ],
                inMemory: true
            )
    }
}
