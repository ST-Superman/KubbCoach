// SoundSettingsView.swift
// Master toggle hero + four-row preview list with mini-waveform thumbnails.
// Auto-saves via `@AppStorage("soundEffectsEnabled")`.

import SwiftUI

struct SoundSettingsView: View {
    @AppStorage("soundEffectsEnabled") private var soundEnabled = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                heroCard
                    .padding(.horizontal, 16)

                if soundEnabled {
                    previewSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
            .animation(.easeInOut(duration: 0.2), value: soundEnabled)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.Kubb.forestGreen)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sound effects")
                    .font(KubbFont.fraunces(20, weight: .regular, italic: true))
                    .foregroundStyle(Color.Kubb.text)
                Text("Sharp confirmation on every hit, miss, and milestone.")
                    .font(KubbFont.inter(12))
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $soundEnabled)
                .labelsHidden()
                .tint(Color.Kubb.forestGreen)
                .onChange(of: soundEnabled) { _, _ in
                    HapticFeedbackService.shared.selection()
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    // MARK: - Preview rows

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsEyebrow("Preview")
                .padding(.horizontal, 20)

            SettingsCard {
                SoundPreviewRow(
                    color: Color.Kubb.forestGreen,
                    label: "Hit",
                    caption: "Kubb knocked down",
                    effect: .hit
                )
                SoundPreviewRow(
                    color: Color.Kubb.miss,
                    label: "Miss",
                    caption: "Throw missed",
                    effect: .miss
                )
                SoundPreviewRow(
                    color: Color.Kubb.swedishGold,
                    label: "Streak milestone",
                    caption: "Multi-hit run",
                    effect: .streakMilestone
                )
                SoundPreviewRow(
                    color: Color.Kubb.swedishBlue,
                    label: "Round complete",
                    caption: "End of round",
                    effect: .roundComplete
                )
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - SoundPreviewRow

private struct SoundPreviewRow: View {
    let color: Color
    let label: String
    let caption: String
    let effect: SoundService.SoundEffect

    var body: some View {
        Button {
            SoundService.shared.play(effect)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.09))
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(KubbFont.inter(15, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                    Text(caption.uppercased())
                        .font(KubbFont.mono(9.5, weight: .bold))
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                }

                Spacer(minLength: 8)

                SoundWaveformBar(color: color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(label). Tap to preview."))
    }
}

#Preview {
    NavigationStack {
        SoundSettingsView()
    }
}
