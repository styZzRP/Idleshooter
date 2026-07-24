import Foundation

enum StarUpgradeID: String, Codable, CaseIterable, Identifiable {
    case cosmicDamage
    case cosmicValue
    case cosmicFireRate
    case cosmicLuck
    case startingCash
    case abilityPower
    case abilityCooldown
    case stardustGain
    case offlineBoost
    case upgradeDiscount
    case startingGalaxy
    case droneCore

    var id: String { rawValue }
}

struct StarUpgradeDef: Identifiable {
    let id: StarUpgradeID
    let name: String
    let blurb: String
    let icon: String
    let baseCost: Double
    let costGrowth: Double
    let perLevel: Double
    let maxLevel: Int
    let style: UpgradeValueStyle

    func cost(at level: Int) -> Double {
        (baseCost * pow(costGrowth, Double(level))).rounded()
    }

    func value(at level: Int) -> Double {
        perLevel * Double(level)
    }

    func displayValue(at level: Int) -> String {
        style.string(value(at: level))
    }

    func isMaxed(at level: Int) -> Bool { level >= maxLevel }
}

enum RebirthCatalog {

    static let all: [StarUpgradeDef] = [
        StarUpgradeDef(id: .cosmicDamage,
                       name: "Cosmic Damage",
                       blurb: "Permanent bonus damage on every round you ever fire.",
                       icon: "bolt.fill",
                       baseCost: 2, costGrowth: 1.55, perLevel: 0.12, maxLevel: 100,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .cosmicValue,
                       name: "Cosmic Value",
                       blurb: "Permanent bonus cash from every dot you pop.",
                       icon: "dollarsign.circle.fill",
                       baseCost: 2, costGrowth: 1.55, perLevel: 0.12, maxLevel: 100,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .cosmicFireRate,
                       name: "Cosmic Cadence",
                       blurb: "Permanent bonus fire rate that survives every rebirth.",
                       icon: "flame.fill",
                       baseCost: 4, costGrowth: 1.6, perLevel: 0.05, maxLevel: 60,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .cosmicLuck,
                       name: "Cosmic Luck",
                       blurb: "Permanently weights spawn rolls towards rare tiers.",
                       icon: "clover.fill",
                       baseCost: 5, costGrowth: 1.62, perLevel: 0.06, maxLevel: 60,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .startingCash,
                       name: "Head Start",
                       blurb: "Cash handed to you the moment a new run begins.",
                       icon: "banknote.fill",
                       baseCost: 3, costGrowth: 1.7, perLevel: 1, maxLevel: 40,
                       style: .points),

        StarUpgradeDef(id: .abilityPower,
                       name: "Ability Power",
                       blurb: "Frenzy, Dot Rain and Black Hole all hit harder.",
                       icon: "sparkles",
                       baseCost: 6, costGrowth: 1.65, perLevel: 0.08, maxLevel: 50,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .abilityCooldown,
                       name: "Ability Recharge",
                       blurb: "Shorter cooldowns between big moments.",
                       icon: "clock.arrow.circlepath",
                       baseCost: 8, costGrowth: 1.7, perLevel: 0.03, maxLevel: 25,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .stardustGain,
                       name: "Dust Affinity",
                       blurb: "Every future rebirth yields more Star Dust.",
                       icon: "star.fill",
                       baseCost: 10, costGrowth: 1.8, perLevel: 0.1, maxLevel: 50,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .offlineBoost,
                       name: "Night Shift",
                       blurb: "Your turret keeps a bigger share of its income while away.",
                       icon: "moon.zzz.fill",
                       baseCost: 5, costGrowth: 1.6, perLevel: 0.1, maxLevel: 40,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .upgradeDiscount,
                       name: "Bulk Contracts",
                       blurb: "Every cash upgrade in the game costs less.",
                       icon: "tag.fill",
                       baseCost: 12, costGrowth: 1.75, perLevel: 0.02, maxLevel: 30,
                       style: .percent(decimals: 0)),

        StarUpgradeDef(id: .startingGalaxy,
                       name: "Warp Memory",
                       blurb: "Start each new run this many galaxies ahead.",
                       icon: "location.north.circle.fill",
                       baseCost: 25, costGrowth: 2.2, perLevel: 1, maxLevel: 20,
                       style: .points),

        StarUpgradeDef(id: .droneCore,
                       name: "Drone Core",
                       blurb: "Extra drones that are already online at the start of a run.",
                       icon: "square.stack.3d.up.fill",
                       baseCost: 40, costGrowth: 3.0, perLevel: 1, maxLevel: 4,
                       style: .points)
    ]

    static func def(_ id: StarUpgradeID) -> StarUpgradeDef {
        all.first { $0.id == id } ?? all[0]
    }

    /// Star Dust a rebirth would pay out right now.
    /// Scales with lifetime earnings of the current run and how far it got.
    static func payout(runEarnings: Double, galaxyIndex: Int, gainBonus: Double) -> Double {
        guard galaxyIndex >= GalaxyCatalog.rebirthUnlockIndex else { return 0 }
        let normalised = max(0, runEarnings) / 1e9
        guard normalised > 0 else { return 0 }
        let base = pow(normalised, 0.42) * 6
        let depth = 1 + Double(galaxyIndex - GalaxyCatalog.rebirthUnlockIndex + 1) * 0.18
        return floor(base * depth * (1 + gainBonus))
    }
}
