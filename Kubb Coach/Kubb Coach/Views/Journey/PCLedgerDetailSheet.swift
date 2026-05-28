// PCLedgerDetailSheet.swift
// Read-only Pressure Cooker session detail shown when tapping a PC row in
// the Journey Recent Sessions list. Mirrors the lightweight feel of
// SessionLedgerDetailSheet without the play-again / milestone announcement
// flow used by the post-game summary views.

import SwiftUI

struct PCLedgerDetailSheet: View {
    let session: PressureCookerSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var noteText: String = ""
    @FocusState private var noteFocused: Bool

    private static let notesMaxLength = 500

    private var gameType: PressureCookerGameType {
        PressureCookerGameType(rawValue: session.gameType) ?? .threeForThree
    }

    private var durationText: String {
        guard let completed = session.completedAt else { return "—" }
        let secs = Int(completed.timeIntervalSince(session.createdAt))
        return secs >= 60 ? "\(secs / 60)m \(secs % 60)s" : "\(secs)s"
    }

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: session.createdAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    stats
                    frames
                    notesSection
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .background(Color(hex: "FBFAF6"))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { noteText = session.notes ?? "" }
        .onDisappear { persistNotesIfChanged() }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("NOTES")
                        .font(KubbFont.inter(9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.Kubb.textSec)
                    Text("What did you learn?")
                        .font(KubbFont.inter(15, weight: .heavy))
                        .foregroundStyle(Color.Kubb.midnightNavy)
                        .tracking(-0.2)
                }
                Spacer()
                Text("\(noteText.count) / \(Self.notesMaxLength)")
                    .font(KubbFont.mono(10, weight: .regular))
                    .foregroundStyle(noteText.count >= Self.notesMaxLength ? Color(hex: "C53030") : Color.Kubb.textTer)
            }

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("Add notes about wind, grip, mental cues, anything to remember…")
                        .font(KubbFont.inter(15, weight: .regular))
                        .foregroundStyle(Color.Kubb.textTer)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteText)
                    .focused($noteFocused)
                    .font(KubbFont.inter(15, weight: .regular))
                    .foregroundStyle(Color.Kubb.text)
                    .tint(Color.Kubb.swedishBlue)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: noteFocused ? 180 : 110)
                    .animation(.easeInOut(duration: 0.18), value: noteFocused)
                    .padding(4)
                    .onChange(of: noteText) { _, newValue in
                        if newValue.count > Self.notesMaxLength {
                            noteText = String(newValue.prefix(Self.notesMaxLength))
                        }
                    }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    persistNotesIfChanged()
                    noteFocused = false
                }
                .font(KubbFont.inter(14, weight: .bold))
                .foregroundStyle(Color.Kubb.swedishBlue)
            }
        }
    }

    private func persistNotesIfChanged() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String? = trimmed.isEmpty ? nil : trimmed
        guard session.notes != newValue else { return }
        session.notes = newValue
        try? modelContext.save()
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.Kubb.phasePC, Color.Kubb.phasePC.opacity(0.847)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .background(.ultraThinMaterial, in: Circle())
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)

                    Text("PRESSURE COOKER · \(gameType.displayName.uppercased()) · \(dateText.uppercased())")
                        .font(KubbFont.inter(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(gameType.displayName)
                        .font(KubbFont.inter(13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    Text("\(session.totalScore)")
                        .font(KubbFont.inter(56, weight: .heavy))
                        .tracking(-2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("total score")
                        .font(KubbFont.inter(12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 2)
                }
            }
            .padding(.top, 52)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            statTile(label: "Frames", value: "\(session.framesCompleted)", color: Color.Kubb.text)
            statTile(label: "Best frame", value: "\(session.frameScores.max() ?? 0)", color: Color.Kubb.swedishGold)
            statTile(label: "Duration", value: durationText, color: Color.Kubb.textSec)
            statTile(label: "XP earned", value: "\(Int(session.xpEarned))", color: Color.Kubb.swedishBlue)
        }
    }

    private func statTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(KubbFont.inter(9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textSec)
            Text(value)
                .font(KubbFont.inter(17, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }

    private var frames: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FRAME SCORES")
                .font(KubbFont.inter(9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Color.Kubb.textSec)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
                spacing: 6
            ) {
                ForEach(Array(session.frameScores.enumerated()), id: \.offset) { idx, score in
                    VStack(spacing: 2) {
                        Text("F\(idx + 1)")
                            .font(KubbFont.inter(9, weight: .bold))
                            .foregroundStyle(Color.Kubb.textSec)
                        Text("\(score)")
                            .font(KubbFont.inter(14, weight: .heavy))
                            .foregroundStyle(Color.Kubb.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
                }
            }
        }
    }
}
