import Foundation

/// Every number the simulation needs, folded together from upgrade levels,
/// Star Dust perks, shop boosts and the current galaxy's modifier.
struct DerivedStats {
    // Turret
    var damage: Double = 5
    var fireRate: Double = 1.4
    var multishot: Int = 1
    var critChance: Double = 0.03
    var critDamage: Double = 2
    var bulletSpeed: Double = 420
    var pierce: Int = 0
    var explosiveRadius: Double = 0

    // Drone
    var droneSpeed: Double = 150
    var droneSuction: Double = 46
    var droneAgility: Double = 2.2
    var droneSize: Double = 10
    var droneMagnet: Double = 90
    var droneCount: Int = 1
    var droneBonus: Double = 0
    var orbLifetime: Double = 6

    // Economy
    var capacity: Int = 12
    var valueMultiplier: Double = 1
    var spawnRate: Double = 1.1
    var luck: Double = 0.02
    var comboWindow: Double = 1.6
    var idleIncome: Double = 0
    var goldenChance: Double = 0
    var offlineRate: Double = 0.25

    // Galaxy scaling
    var dotHealthScale: Double = 1
    var dotValueScale: Double = 1
    var driftScale: Double = 1
    var wanderScale: Double = 0

    /// Damage-per-second the turret theoretically outputs.
    var dps: Double {
        damage * fireRate * Double(multishot) * (1 + critChance * (critDamage - 1))
    }

    /// Rough health of an average spawn in the current galaxy.
    var averageDotHealth: Double {
        GameBalance.baseDotHealth * dotHealthScale * 1.45
    }

    /// Rough payout of an average spawn in the current galaxy.
    var averageDotValue: Double {
        GameBalance.baseDotValue * dotValueScale * valueMultiplier * 1.9 * (1 + goldenChance * 24)
    }

    /// Fallback income estimate, used before the engine has measured anything
    /// real (fresh install, or the very first offline window).
    var estimatedIncomePerSecond: Double {
        let killsByDamage = dps / max(1, averageDotHealth)
        let kills = min(spawnRate, killsByDamage)
        return kills * averageDotValue * (1 + droneBonus) + idleIncome
    }
}

enum GameBalance {
    /// Health of a common dot in galaxy 1.
    static let baseDotHealth: Double = 6
    /// Cash a common dot in galaxy 1 is worth.
    static let baseDotValue: Double = 1.7
    /// Hard ceiling on simultaneous entities, so bullet hell stays playable.
    static let maxDots = 320
    static let maxBullets = 900
    static let maxOrbs = 400
    static let maxParticles = 260
    static let maxFloatingLabels = 40
    /// Combo multiplier ceiling.
    static let maxComboMultiplier: Double = 6
    /// Cash multiplier added per point of combo.
    static let comboStep: Double = 0.012
    /// Offline earnings are capped at this many hours.
    static let offlineCapHours: Double = 24
}
