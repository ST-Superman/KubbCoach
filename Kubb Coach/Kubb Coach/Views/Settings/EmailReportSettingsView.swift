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
        Form {
            Section {
                Toggle("Enable Email Reports", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if newValue && !isEnabled {
                            // Turning ON - show confirmation
                            showOptInAlert = true
                        } else {
                            // Turning OFF - allow immediately
                            isEnabled = newValue
                        }
                    }
                ))
                .tint(Color.Kubb.swedishBlue)
            } footer: {
                Text("Receive weekly progress reports and training reminders via email")
            }

            if isEnabled {
                Section {
                    TextField("your@email.com", text: $emailAddress)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Email Address")
                } footer: {
                    Text("Enter the email address where you'd like to receive reports")
                }

                Section {
                    Picker("Send reports", selection: $selectedFrequency) {
                        ForEach(ReportFrequency.allCases) { frequency in
                            Text(frequency.displayName)
                                .tag(frequency)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Frequency")
                } footer: {
                    Text("Choose how often you want to receive training reports")
                }

                if let lastSent = settings?.lastSentAt {
                    Section {
                        HStack {
                            Text("Last Report Sent")
                            Spacer()
                            Text(formatDate(lastSent))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Next Report Due")
                            Spacer()
                            Text(formatDate(nextReportDate(from: lastSent)))
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Report History")
                    }
                }

                Section {
                    Button {
                        generateTestReport()
                    } label: {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("Preview Report")
                        }
                    }

                    Button {
                        sendTestEmail()
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Test Email")
                        }
                    }
                    .disabled(!MFMailComposeViewController.canSendMail() || emailAddress.isEmpty)
                } header: {
                    Text("Testing")
                } footer: {
                    if !MFMailComposeViewController.canSendMail() {
                        Text("Email is not configured on this device")
                    } else if emailAddress.isEmpty {
                        Text("Enter an email address to send a test report")
                    } else {
                        Text("Preview the report or send a test email to verify the format")
                    }
                }
            }
        }
        .navigationTitle("Email Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveSettings()
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
