import Foundation
import QuartzCore
import UIKit

/// Drives the simulation from a display link, and decides how often the two
/// observable objects actually publish:
///
/// - the engine publishes every frame (only the canvas listens),
/// - `GameState` publishes at UI rate, so HUD text doesn't re-render 60x/sec,
/// - the save file is written every few seconds and on backgrounding.
final class GameLoop {

    private let state: GameState
    private let engine: GameEngine

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var uiAccumulator: Double = 0
    private var saveAccumulator: Double = 0

    private let uiInterval: Double = 1.0 / 12.0
    private let saveInterval: Double = 15

    init(state: GameState, engine: GameEngine) {
        self.state = state
        self.engine = engine
    }

    var isRunning: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ sender: CADisplayLink) {
        guard lastTimestamp > 0 else {
            lastTimestamp = sender.timestamp
            return
        }
        let dt = sender.timestamp - lastTimestamp
        lastTimestamp = sender.timestamp
        guard dt > 0 else { return }

        engine.update(dt: dt)
        engine.objectWillChange.send()

        uiAccumulator += dt
        if uiAccumulator >= uiInterval {
            uiAccumulator = 0
            state.publishIfNeeded()
        }

        saveAccumulator += dt
        if saveAccumulator >= saveInterval {
            saveAccumulator = 0
            state.persist()
        }
    }
}
