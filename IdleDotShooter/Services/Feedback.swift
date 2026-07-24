import AudioToolbox
import QuartzCore
import UIKit

/// Haptics and UI sound, both gated on the player's settings and throttled so a
/// bullet-hell frame can't machine-gun the taptic engine.
final class Feedback {

    static let shared = Feedback()

    var hapticsEnabled = true
    var soundEnabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notice = UINotificationFeedbackGenerator()

    private var lastHaptic: TimeInterval = 0
    private var lastSound: TimeInterval = 0

    private init() {}

    func prepare() {
        light.prepare()
        medium.prepare()
        selection.prepare()
    }

    enum Strength { case light, medium, heavy }

    func tap(_ strength: Strength = .light, throttle: TimeInterval = 0.05) {
        guard hapticsEnabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastHaptic >= throttle else { return }
        lastHaptic = now
        switch strength {
        case .light:  light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .heavy:  heavy.impactOccurred()
        }
    }

    func select() {
        guard hapticsEnabled else { return }
        selection.selectionChanged()
    }

    func success() {
        guard hapticsEnabled else { return }
        notice.notificationOccurred(.success)
    }

    func warning() {
        guard hapticsEnabled else { return }
        notice.notificationOccurred(.warning)
    }

    enum Cue: SystemSoundID {
        case purchase = 1_104
        case ability = 1_113
        case travel = 1_057
        case denied = 1_053
        case rebirth = 1_025
    }

    func play(_ cue: Cue, throttle: TimeInterval = 0.08) {
        guard soundEnabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastSound >= throttle else { return }
        lastSound = now
        AudioServicesPlaySystemSound(cue.rawValue)
    }
}
