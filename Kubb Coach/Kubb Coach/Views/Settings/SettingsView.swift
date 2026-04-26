import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KubbSpacing.l2) {
                settingsSection("Training") {
                    settingsRow("Email Reports", icon: "envelope.fill", color: Color.Kubb.swedishBlue) {
                        EmailReportSettingsView()
                    }
                    settingsDivider
                    settingsRow("Competition", icon: "trophy.fill", color: Color.Kubb.swedishGold) {
                        CompetitionSettingsView()
                    }
                }

                settingsSection("Audio") {
                    settingsRow("Sound Effects", icon: "speaker.wave.2.fill", color: Color.Kubb.forestGreen) {
                        SoundSettingsView()
                    }
                }

                settingsSection("Data") {
                    settingsRow("Data Management", icon: "externaldrive.fill", color: Color.Kubb.textSec) {
                        DataManagementView()
                    }
                }

                #if DEBUG
                settingsSection("Development") {
                    settingsRow("Debug Tools", icon: "wrench.and.screwdriver.fill", color: Color.Kubb.phasePC) {
                        DebugSettingsView()
                    }
                }
                #endif
            }
            .padding(.horizontal, KubbSpacing.l)
            .padding(.top, KubbSpacing.l)
            .padding(.bottom, 100)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Settings")
    }

    private var settingsDivider: some View {
        Color.Kubb.sep
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: KubbSpacing.xs2) {
            Text(title.uppercased())
                .font(KubbType.monoXS)
                .foregroundStyle(Color.Kubb.textSec)
                .tracking(KubbTracking.monoXS)
                .padding(.horizontal, KubbSpacing.xs)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
            .kubbCardShadow()
        }
    }

    @ViewBuilder
    private func settingsRow<Destination: View>(
        _ label: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: KubbSpacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: KubbRadius.s)
                        .fill(color)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(label)
                    .font(KubbType.body)
                    .foregroundStyle(Color.Kubb.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .padding(.horizontal, KubbSpacing.l)
            .padding(.vertical, KubbSpacing.m2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
