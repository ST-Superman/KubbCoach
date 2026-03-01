import SwiftUI

struct SoundSettingsView: View {
    @AppStorage("soundEffectsEnabled") private var soundEnabled = false

    var body: some View {
        List {
            Section {
                Toggle("Sound Effects", isOn: $soundEnabled)
            } header: {
                Text("Audio")
            } footer: {
                Text("Play sound effects for hits, misses, and achievements during training")
            }

            if soundEnabled {
                Section("Preview Sounds") {
                    Button("Hit Sound") {
                        SoundService.shared.play(.hit)
                    }

                    Button("Miss Sound") {
                        SoundService.shared.play(.miss)
                    }

                    Button("Streak Sound") {
                        SoundService.shared.play(.streakMilestone)
                    }

                    Button("Round Complete") {
                        SoundService.shared.play(.roundComplete)
                    }
                }
            }
        }
        .navigationTitle("Sound Settings")
    }
}

#Preview {
    NavigationStack {
        SoundSettingsView()
    }
}
