//
//  WatchGameSessionCompleteView.swift
//  Kubb Coach Watch Watch App
//
//  Post-game summary on Apple Watch.
//  Displays result and key stats, then uploads to CloudKit before dismissing.
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
        ScrollView {
            VStack(spacing: 14) {
                resultHeader

                statsCard

                uploadButton
            }
            .padding()
        }
        .focusable()
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

    // MARK: - Result header

    private var resultHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: resultIcon)
                .font(.system(size: 36))
                .foregroundStyle(resultColor)

            Text(resultTitle)
                .font(.headline)
                .multilineTextAlignment(.center)

            if session.gameMode == .competitive {
                Text(session.winnerSide.map { session.name(for: $0) } ?? "No winner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(spacing: 8) {
            statRow(label: "Turns Played", value: "\(session.totalTurns)")

            if !session.userTurns.isEmpty {
                let avgProg = session.averageUserProgress
                let sign = avgProg >= 0 ? "+" : ""
                statRow(label: "Avg Progress", value: "\(sign)\(String(format: "%.1f", avgProg))")
            }

            if let best = session.bestUserTurn {
                let sign = best.progress >= 0 ? "+" : ""
                statRow(label: "Best Turn", value: "\(sign)\(best.progress)")
            }

            let negCount = session.advantageLineTurns.count
            if negCount > 0 {
                statRow(label: "Field Misses", value: "\(negCount)")
            }
        }
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Upload button

    private var uploadButton: some View {
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
                        Text("SYNCING...")
                    }
                } else {
                    Text(uploadSuccess ? "DONE" : "SAVE & FINISH")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(uploadSuccess ? KubbColors.forestGreen : KubbColors.swedishBlue)
            .foregroundStyle(.white)
            .cornerRadius(25)
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

            // Delete local copy after successful upload (Watch storage is precious)
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

    // MARK: - Computed display

    private var resultTitle: String {
        switch session.gameMode {
        case .phantom:
            return "Game Complete!"
        case .competitive:
            if let won = session.userWon {
                return won ? "You Won!" : "They Won"
            }
            return session.endReason == GameEndReason.abandoned.rawValue ? "Game Abandoned" : "Game Over"
        }
    }

    private var resultIcon: String {
        if session.endReason == GameEndReason.abandoned.rawValue {
            return "xmark.circle.fill"
        }
        switch session.gameMode {
        case .phantom:
            return "flag.checkered"
        case .competitive:
            if let won = session.userWon {
                return won ? "trophy.fill" : "flag.fill"
            }
            return "flag.checkered"
        }
    }

    private var resultColor: Color {
        if session.endReason == GameEndReason.abandoned.rawValue { return .secondary }
        switch session.gameMode {
        case .phantom: return KubbColors.swedishGold
        case .competitive:
            if let won = session.userWon {
                return won ? KubbColors.swedishGold : KubbColors.miss
            }
            return KubbColors.swedishGold
        }
    }
}
