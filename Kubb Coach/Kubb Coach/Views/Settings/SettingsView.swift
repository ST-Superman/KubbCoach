import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Training") {
                NavigationLink("Email Reports") {
                    EmailReportSettingsView()
                }

                NavigationLink("Competition") {
                    CompetitionSettingsView()
                }
            }

            Section("Audio") {
                NavigationLink("Sound Effects") {
                    SoundSettingsView()
                }
            }

            Section("Data") {
                NavigationLink("Data Management") {
                    DataManagementView()
                }
            }

            #if DEBUG
            Section {
                NavigationLink("Debug Tools") {
                    DebugSettingsView()
                }
            } header: {
                Text("Development")
            } footer: {
                Text("⚠️ Debug tools only visible in development builds")
            }
            #endif
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
