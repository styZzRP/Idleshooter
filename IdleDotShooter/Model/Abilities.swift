import Foundation

enum AbilityID: String, Codable, CaseIterable, Identifiable {
    case frenzy
    case dotRain
    case blackHole

    var id: String { rawValue }
}

struct AbilityDef: Identifiable {
    let id: AbilityID
    let name: String
    let blurb: String
    let icon: String
    let palette: PaletteColor
    /// Cash cost to unlock the ability the first time.
    let unlockCost: Double
    /// Galaxy (0-based) at which the ability becomes purchasable at all.
    let unlockGalaxy: Int
    let upgradeBaseCost: Double
    let upgradeGrowth: Double
    let maxLevel: Int

    let baseDuration: Double
    let durationPerLevel: Double
    let baseCooldown: Double
    /// Seconds shaved off the cooldown per level (never below `minCooldown`).
    let cooldownPerLevel: Double
    let minCooldown: Double
    let basePotency: Double
    let potencyPerLevel: Double

    func duration(level: Int) -> Double {
        baseDuration + durationPerLevel * Double(level)
    }

    func cooldown(level: Int, reduction: Double) -> Double {
        let raw = baseCooldown - cooldownPerLevel * Double(level)
        return max(minCooldown, raw * max(0.25, 1 - reduction))
    }

    /// Level 0 potency is the baseline; permanent Star Dust upgrades scale it.
    func potency(level: Int, power: Double) -> Double {
        (basePotency + potencyPerLevel * Double(level)) * power
    }

    func upgradeCost(level: Int) -> Double {
        upgradeBaseCost * pow(upgradeGrowth, Double(level))
    }

    func isMaxed(level: Int) -> Bool { level >= maxLevel }
}

enum AbilityCatalog {

    static let all: [AbilityDef] = [
        AbilityDef(id: .frenzy,
                   name: "Frenzy",
                   blurb: "Unleashes rapid fire — a barrage of shots in the blink of an eye.",
                   icon: "flame.fill",
                   palette: .orange,
                   unlockCost: 2_500,
                   unlockGalaxy: 1,
                   upgradeBaseCost: 3_500,
                   upgradeGrowth: 1.55,
                   maxLevel: 40,
                   baseDuration: 8,
                   durationPerLevel: 0.4,
                   baseCooldown: 90,
                   cooldownPerLevel: 1.1,
                   minCooldown: 25,
                   basePotency: 5,
                   potencyPerLevel: 0.45),

        AbilityDef(id: .dotRain,
                   name: "Dot Rain",
                   blurb: "Showers the field with dots — clear them all for a windfall.",
                   icon: "cloud.rain.fill",
                   palette: .cyan,
                   unlockCost: 40_000,
                   unlockGalaxy: 3,
                   upgradeBaseCost: 55_000,
                   upgradeGrowth: 1.58,
                   maxLevel: 40,
                   baseDuration: 6,
                   durationPerLevel: 0.3,
                   baseCooldown: 150,
                   cooldownPerLevel: 1.8,
                   minCooldown: 45,
                   basePotency: 40,
                   potencyPerLevel: 6),

        AbilityDef(id: .blackHole,
                   name: "Black Hole",
                   blurb: "Drags every dot into the singularity and pays out the lot.",
                   icon: "circle.circle.fill",
                   palette: .purple,
                   unlockCost: 750_000,
                   unlockGalaxy: 5,
                   upgradeBaseCost: 900_000,
                   upgradeGrowth: 1.62,
                   maxLevel: 40,
                   baseDuration: 3.2,
                   durationPerLevel: 0.1,
                   baseCooldown: 240,
                   cooldownPerLevel: 3.2,
                   minCooldown: 70,
                   basePotency: 2.5,
                   potencyPerLevel: 0.35)
    ]

    static func def(_ id: AbilityID) -> AbilityDef {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Live per-ability state (unlock flag, level, cooldown and active timers).
struct AbilityState: Codable {
    var unlocked: Bool = false
    var level: Int = 0
    var cooldownRemaining: Double = 0
    var activeRemaining: Double = 0

    var isActive: Bool { activeRemaining > 0 }
    var isReady: Bool { unlocked && cooldownRemaining <= 0 && activeRemaining <= 0 }
}
