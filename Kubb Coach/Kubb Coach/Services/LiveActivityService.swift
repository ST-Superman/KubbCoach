import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    private var activity: Activity<TrainingActivityAttributes>?

    func start(for session: TrainingSession, currentRound: TrainingRound?) {
        guard session.phase != .inkastingDrilling else { return }

        let phase = session.safePhase
        AppLogger.training.debug("LiveActivity start called: phase=\(String(describing: phase)), enabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
        guard phase == .eightMeters || phase == .fourMetersBlasting else {
            AppLogger.training.warning("LiveActivity skipped: phase \(String(describing: phase)) not supported")
            return
        }

        endAllStale()

        let phaseLabel: String
        switch phase {
        case .eightMeters:
            let typeName = session.safeSessionType.displayName.uppercased()
            phaseLabel = "8 METERS · \(typeName)"
        case .fourMetersBlasting:
            phaseLabel = "4 METERS · BLASTING"
        default:
            return
        }

        let attributes = TrainingActivityAttributes(
            phaseLabel: phaseLabel,
            totalRounds: session.configuredRounds
        )
        let state = TrainingActivityAttributes.ContentState(
            currentRound: currentRound?.roundNumber ?? 1,
            accuracy: session.accuracy,
            isComplete: false
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            AppLogger.training.info("LiveActivity started: id=\(self.activity?.id ?? "nil")")
        } catch {
            AppLogger.training.error("LiveActivity start failed: \(error) | code=\((error as NSError).code) domain=\((error as NSError).domain)")
        }
    }

    func update(session: TrainingSession, round: TrainingRound?) {
        guard let activity else { return }
        let roundNum = round?.roundNumber ?? session.currentRoundNumber ?? 1
        let state = TrainingActivityAttributes.ContentState(
            currentRound: roundNum,
            accuracy: session.accuracy,
            isComplete: session.isComplete
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(dismissedAfter seconds: TimeInterval = 8) {
        guard let current = activity else { return }
        activity = nil
        Task {
            await current.end(nil, dismissalPolicy: .after(.now + seconds))
        }
    }

    func startGame(mode: GameMode, state: GameState) {
        endAllStale()
        let label = mode == .phantom ? "PHANTOM GAME" : "COMPETITIVE"
        let attrs = TrainingActivityAttributes(phaseLabel: label, totalRounds: 0)
        let content = TrainingActivityAttributes.ContentState(
            currentRound: 1,
            accuracy: 0,
            isComplete: false,
            scoreA: state.sideABaseline,
            scoreB: state.sideBBaseline
        )
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: content, staleDate: nil),
                pushType: nil
            )
            AppLogger.training.info("LiveActivity startGame: id=\(self.activity?.id ?? "nil")")
        } catch {
            AppLogger.training.error("LiveActivity startGame failed: \(error)")
        }
    }

    func updateGame(turnNumber: Int, state: GameState) {
        guard let activity else { return }
        let content = TrainingActivityAttributes.ContentState(
            currentRound: turnNumber,
            accuracy: 0,
            isComplete: state.isComplete,
            scoreA: state.sideABaseline,
            scoreB: state.sideBBaseline
        )
        Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
    }

    private func endAllStale() {
        let staleActivities = Array(Activity<TrainingActivityAttributes>.activities)
        Task {
            for stale in staleActivities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        }
        activity = nil
    }
}
