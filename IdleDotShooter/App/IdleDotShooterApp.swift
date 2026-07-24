import SwiftUI

@main
struct IdleDotShooterApp: App {
    private let container = GameContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView(state: container.state,
                     engine: container.engine,
                     leaderboard: container.leaderboard)
        }
    }
}
