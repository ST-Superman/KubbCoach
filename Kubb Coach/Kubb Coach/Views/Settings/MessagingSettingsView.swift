// MessagingSettingsView.swift
// Messaging preferences, written through set_message_prefs (self-only, server-side).
// Unlike email REPORTS (local notifications), message emails are sent server-side by
// the platform, so there's no iOS notification-permission step here.
//
//   - Direct messages (dm_policy): who may DM you.
//   - Push notifications (dm_push): APNs push for new messages (i2). Enabling it here
//     is the single opt-in point — it requests OS permission + registers the device.
//   - Message emails (dm_email_cadence): in-app only / daily / weekly.
//   - Promotional announcements (announcement_promo): mute promos (critical always shows).

import SwiftUI
import UIKit

struct MessagingSettingsView: View {
    @Environment(MessagingService.self) private var service
    @Environment(KubbPlatformService.self) private var platform

    @State private var dmOn = true
    @State private var promoOn = true
    @State private var pushOn = true
    @State private var cadence = "in_app"
    @State private var loaded = false
    @State private var showPushDeniedAlert = false

    private let cadences: [(value: String, label: String, subtitle: String)] = [
        ("in_app", "In-app only", "No emails — just the badge and the Messages screen."),
        ("daily",  "Daily review", "One email a day recapping unread messages."),
        ("weekly", "Weekly review", "One email each Saturday recapping unread messages."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                InlineNavHeader("Choose who can message you, and how you’re emailed about unread messages.")

                if platform.isConnected {
                    connected
                } else {
                    notConnected
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Messaging")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded, platform.isConnected else { return }
            await service.loadMessagePrefs()
            if let p = service.prefs {
                dmOn = p.dmPolicy == "eligible"
                promoOn = p.announcementPromo
                cadence = p.dmEmailCadence
                pushOn = p.dmPush
            }
            loaded = true
        }
        .alert("Notifications are off", isPresented: $showPushDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("To get push notifications for new messages, turn on notifications for Kubb Coach in iOS Settings.")
        }
    }

    @ViewBuilder
    private var connected: some View {
        SettingsCard {
            SettingsToggle(
                icon: "bubble.left.and.bubble.right.fill",
                tint: Color.Kubb.matchAccent,
                label: "Direct messages",
                subtitle: "When on, players you’ve played or challenged can message you.",
                isOn: dmBinding
            )
        }
        .padding(.horizontal, 16)

        SettingsCard {
            SettingsToggle(
                icon: "bell.badge.fill",
                tint: Color.Kubb.matchAccent,
                label: "Push notifications",
                subtitle: "Get a push when someone messages you, even when the app is closed.",
                isOn: pushBinding
            )
        }
        .padding(.horizontal, 16)

        SettingsEyebrow("Message emails")
            .padding(.horizontal, 20)
        SettingsCard {
            ForEach(cadences, id: \.value) { option in
                Button {
                    guard cadence != option.value else { return }
                    cadence = option.value
                    Task { await service.setMessagePrefs(dmEmailCadence: option.value) }
                } label: {
                    SettingsRow(
                        icon: cadenceIcon(option.value),
                        tint: Color.Kubb.swedishBlue,
                        label: option.label,
                        subtitle: option.subtitle
                    ) {
                        if cadence == option.value {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.Kubb.matchAccent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)

        SettingsCard {
            SettingsToggle(
                icon: "megaphone.fill",
                tint: Color.Kubb.swedishGold,
                label: "Promotional announcements",
                subtitle: "Product news and tips. Off mutes promos — important notices are always shown.",
                isOn: promoBinding
            )
        }
        .padding(.horizontal, 16)
    }

    private var notConnected: some View {
        Text("Connect your Kubb Platform account (in Virtual Matches or Messages) to manage messaging preferences.")
            .font(.subheadline)
            .foregroundStyle(Color.Kubb.textSec)
            .padding(.horizontal, 20)
    }

    private func cadenceIcon(_ value: String) -> String {
        switch value {
        case "daily":  return "calendar"
        case "weekly": return "calendar.badge.clock"
        default:       return "bell.slash"
        }
    }

    private var dmBinding: Binding<Bool> {
        Binding(get: { dmOn }, set: { newValue in
            dmOn = newValue
            Task { await service.setMessagePrefs(dmPolicy: newValue ? "eligible" : "none") }
        })
    }

    private var promoBinding: Binding<Bool> {
        Binding(get: { promoOn }, set: { newValue in
            promoOn = newValue
            Task { await service.setMessagePrefs(announcementPromo: newValue) }
        })
    }

    private var pushBinding: Binding<Bool> {
        Binding(get: { pushOn }, set: { newValue in
            if newValue { enablePush() } else { disablePush() }
        })
    }

    /// Enabling push is the opt-in: request OS permission, then register for APNs and
    /// flip the server pref. If permission is denied, revert and point to iOS Settings.
    private func enablePush() {
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            if granted {
                pushOn = true
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
                await service.setMessagePrefs(dmPush: true)
            } else {
                pushOn = false
                showPushDeniedAlert = true
            }
        }
    }

    private func disablePush() {
        pushOn = false
        Task {
            await service.setMessagePrefs(dmPush: false)
            if let token = UserDefaults.standard.string(forKey: "apnsDeviceToken") {
                await service.unregisterDeviceToken(token)
            }
        }
    }
}
