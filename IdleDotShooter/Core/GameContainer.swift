import Foundation
import SwiftUI

/// Wires the save file, state, engine and loop together, and owns the
/// foreground/background handling.
final class GameContainer: ObservableObject {

    static let shared = GameContainer()

    let state: GameState
    let engine: GameEngine
    let leaderboard: LocalLeaderboardService
    private let loop: GameLoop

    private init() {
        let save = SaveStore.load() ?? GameContainer.freshSave()
        let state = GameState(save: save)
        let engine = GameEngine(state: state)

        self.state = state
        self.engine = engine
        self.leaderboard = LocalLeaderboardService()
        self.loop = GameLoop(state: state, engine: engine)

        state.stats.sessionsPlayed += 1
        state.applyOfflineProgress()
        Feedback.shared.prepare()
    }

    private static func freshSave() -> SaveGame {
        var save = SaveGame()
        save.lastSaved = Date()
        save.stats.firstPlayed = Date()
        return save
    }

    func enterForeground() {
        state.applyOfflineProgress()
        loop.start()
    }

    func enterBackground() {
        loop.stop()
        state.persist()
    }

    func start() {
        loop.start()
    }
}
