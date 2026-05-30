//
//  WatchGameSessionCompleteView.swift
//  Kubb Coach Watch Watch App
//
//  Post-game summary — "Pitch" redesign.
//  The final field stands as the artifact (won side's kubbs down, King toppled),
//  followed by result + three stats + Save & finish.
//

import SwiftUI
import SwiftData

struct WatchGameSessionCompleteView: View {
    let session: GameSession
    @Binding var navigationPath: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncService.self) private var cloudSyncService

    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var uploadError: Error?
    @State private var showErrorAlert = false

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.height / 430
            ScrollView {
                VStack(spacing: pitchScale(k, 11, 8, 15)) {
                    resultHeader(k: k)
                    finalFieldCard(k: k)
                    statsRow(k: k)
                    saveButton(k: k)
                }
                .padding(.horizontal, pitchScale(k, 12, 10, 16))
                .padding(.top, pitchScale(k, 8, 6, 12))
                .padding(.bottom, pitchScale(k, 6, 4, 10))
            }
        }
        .focusable()
        .containerBackground(Pitch.bg, for: .navigation)
        .navigationBarBackButtonHidden(true)
        .alert("Upload Failed", isPresented: $showErrorAlert) {
            Button("Retry") {
                Task { await upload() }
            }
            Button("Skip") {
                finishAndDismiss()
            }
        } message: {
            if let error = uploadError {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Header

    private func resultHeader(k: CGFloat) -> some View {
        VStack(spacing: pitchScale(k, 4, 3, 6)) {
            Text(eyebrow.uppercased())
                .font(.system(size: pitchScale(k, 9, 8, 11), weight: .bold))
                .tracking(1.2)
                .foregroundStyle(eyebrowColor)
            Text(resultTitle)
                .font(.system(size: pitchScale(k, 24, 19, 30), weight: .heavy))
                .foregroundStyle(eyebrowColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Final field card

    /// The artifact: a static mini-pitch with the winner's opposition cleared and
    /// the King toppled.
    private func finalFieldCard(k: CGFloat) -> some View {
        let pipW   = pitchScale(k, 13, 11, 17)
        let pipH   = pitchScale(k, 25, 20, 32)
        let pipGap = pitchScale(k, 7, 6, 9)
        let kingW  = pitchScale(k, 14, 11, 17)
        let kingH  = pitchScale(k, 28, 22, 35)

        // Show the winner attacking from the bottom. For abandoned games show a
        // neutral field with all kubbs standing.
        let win = session.winnerSide
        let kingDown = win != nil
        // Whichever side won, their opponent's baseline is fully knocked.
        let topAllDown = win != nil

        return VStack(spacing: pitchScale(k, 12, 9, 16)) {
            // Opponent (loser) baseline — toppled green
            PitchKubbRow(
                total: 4,
                down: topAllDown ? 4 : 0,
                width: pipW,
                height: pipH,
                gap: pipGap,
                standColor: Pitch.wood,
                downColor: Pitch.attack
            )

            // King — toppled/gold if there's a winner; otherwise small + dim
            PitchKing(
                width: kingW,
                height: kingH,
                color: kingDown ? Pitch.king : Pitch.king.opacity(0.4),
                glow: kingDown
            )
            .rotationEffect(.degrees(kingDown ? 18 : 0))
            .opacity(kingDown ? 0.95 : 0.6)

            // Your baseline — dim
            PitchKubbRow(
                total: 5,
                down: 0,
                width: pipW,
                height: pipH,
                gap: pipGap,
                standColor: Pitch.woodDim,
                downColor: Pitch.attack
            )
            .opacity(0.5)
        }
        .padding(.vertical, pitchScale(k, 14, 11, 18))
        .padding(.horizontal, pitchScale(k, 12, 10, 16))
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: pitchScale(k, 16, 13, 20), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 31/255, green: 122/255, blue: 77/255).opacity(0.14),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: pitchScale(k, 16, 13, 20), style: .continuous)
                        .stroke(Pitch.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Stats

    private func statsRow(k: CGFloat) -> some View {
        let avgProg = session.averageUserProgress
        let avgSign = avgProg >= 0 ? "+" : ""
        let avgValue = "\(avgSign)\(String(format: "%.1f", avgProg))"

        let cleared = max(0, session.userTurns.count - session.advantageLineTurns.count)
        let total = max(1, session.userTurns.count)
        let fieldPct = Int(round(Double(cleared) * 100.0 / Double(total)))

        return HStack(spacing: pitchScale(k, 8, 6, 11)) {
            statTile(value: "\(session.totalTurns)", label: "TURNS", k: k)
            statTile(value: avgValue, label: "AVG", k: k)
            statTile(value: "\(fieldPct)%", label: "FIELD", k: k)
        }
    }

    private func statTile(value: String, label: String, k: CGFloat) -> some View {
        VStack(spacing: pitchScale(k, 3, 2, 4)) {
            Text(value)
                .font(.system(size: pitchScale(k, 16, 13, 20), weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Pitch.attack)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: pitchScale(k, 8, 7, 10), weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Pitch.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, pitchScale(k, 8, 7, 11))
        .background(
            RoundedRectangle(cornerRadius: pitchScale(k, 11, 9, 14), style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: pitchScale(k, 11, 9, 14), style: .continuous)
                        .stroke(Pitch.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Save button

    private func saveButton(k: CGFloat) -> some View {
        Button {
            if isUploading { return }
            if uploadSuccess {
                finishAndDismiss()
            } else {
                Task { await upload() }
            }
        } label: {
            Group {
                if isUploading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                        Text("Syncing…")
                    }
                } else {
                    Text(uploadSuccess ? "Done" : "Save & finish")
                }
            }
            .font(.system(size: pitchScale(k, 13, 12, 16), weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, pitchScale(k, 11, 9, 14))
            .background(uploadSuccess ? Pitch.attack : Pitch.attackDeep)
            .foregroundStyle(.white)
            .cornerRadius(pitchScale(k, 22, 18, 28))
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
    }

    // MARK: - Upload

    private func upload() async {
        isUploading = true
        uploadError = nil

        do {
            _ = try await cloudSyncService.uploadGameSession(session)
            uploadSuccess = true
            isUploading = false

            await MainActor.run {
                modelContext.delete(session)
                try? modelContext.save()
            }

            try? await Task.sleep(nanoseconds: 400_000_000)
            finishAndDismiss()
        } catch {
            isUploading = false
            uploadError = error
            showErrorAlert = true
        }
    }

    private func finishAndDismiss() {
        navigationPath.removeLast(navigationPath.count)
    }

    // MARK: - Display strings

    private var eyebrow: String {
        if session.endReason == GameEndReason.abandoned.rawValue { return "Abandoned" }
        return "Final"
    }

    private var eyebrowColor: Color {
        if session.endReason == GameEndReason.abandoned.rawValue { return Pitch.textDim }
        switch session.gameMode {
        case .phantom: return Pitch.king
        case .competitive:
            if let won = session.userWon {
                return won ? Pitch.king : Pitch.lossBright
            }
            return Pitch.king
        }
    }

    private var resultTitle: String {
        switch session.gameMode {
        case .phantom:
            return "Game complete"
        case .competitive:
            if let won = session.userWon {
                return won ? "You won" : "They won"
            }
            return session.endReason == GameEndReason.abandoned.rawValue ? "Abandoned" : "Game over"
        }
    }
}
