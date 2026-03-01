import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
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
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
