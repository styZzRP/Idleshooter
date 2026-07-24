import Foundation

// MARK: - Categories

enum UpgradeCategory: String, Codable, CaseIterable, Identifiable {
    case defence
    case drone
    case economy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defence: return "Defence"
        case .drone:   return "Drone"
        case .economy: return "Economy"
        }
    }

    var blurb: String {
        switch self {
        case .defence: return "Push fire rate and damage to bullet hell levels."
        case .drone:   return "Speed, suction, agility and size — your drone vacuums up the earnings."
        case .economy: return "Stack capacity, value, spawn rate and luck."
        }
    }

    var icon: String {
        switch self {
        case .defence: return "target"
        case .drone:   return "sparkles"
        case .economy: return "dollarsign.circle"
        }
    }

    var accent: PaletteColor {
        switch self {
        case .defence: return .red
        case .drone:   return .cyan
        case .economy: return .gold
        }
    }
}

// MARK: - Identifiers

enum UpgradeID: String, Codable, CaseIterable, Identifiable {
    // Defence
    case damage, fireRate, multishot, critChance, critDamage, bulletSpeed, pierce, explosive
    // Drone
    case droneSpeed, droneSuction, droneAgility, droneSize, droneMagnet, droneCount, droneBonus, orbLifetime
    // Economy
    case capacity, dotValue, spawnRate, luck, comboWindow, idleIncome, goldenDots, offlineRate

    var id: String { rawValue }
}

// MARK: - Value presentation

enum UpgradeValueStyle {
    case flat(decimals: Int)
    case perSecond(decimals: Int)
    case percent(decimals: Int)
    case multiplier
    case seconds
    case points

    func string(_ value: Double) -> String {
        switch self {
        case .flat(let d):      return String(format: "%.\(d)f", value)
        case .perSecond(let d): return String(format: "%.\(d)f", value) + "/s"
        case .percent(let d):   return String(format: "%.\(d)f%%", value * 100)
        case .multiplier:       return Fmt.multiplier(value)
        case .seconds:          return String(format: "%.1fs", value)
        case .points:           return String(format: "%.0f", value)
        }
    }
}

// MARK: - Definition

struct UpgradeDef: Identifiable {
    let id: UpgradeID
    let category: UpgradeCategory
    let name: String
    let blurb: String
    let icon: String
    let baseCost: Double
    let costGrowth: Double
    /// Effective value at level 0.
    let base: Double
    /// Added to the value by each purchased level.
    let perLevel: Double
    /// `nil` means the upgrade never caps out.
    let maxLevel: Int?
    let style: UpgradeValueStyle

    func value(at level: Int) -> Double {
        base + perLevel * Double(level)
    }

    func displayValue(at level: Int) -> String {
        style.string(value(at: level))
    }

    func isMaxed(at level: Int) -> Bool {
        guard let maxLevel else { return false }
        return level >= maxLevel
    }

    /// Cost of the single next level, before any global discount.
    func rawCost(at level: Int) -> Double {
        baseCost * pow(costGrowth, Double(level))
    }

    /// Cost of buying `count` levels starting from `level` (geometric sum).
    func rawCost(at level: Int, count: Int) -> Double {
        guard count > 0 else { return 0 }
        let first = rawCost(at: level)
        if costGrowth == 1 { return first * Double(count) }
        return first * (pow(costGrowth, Double(count)) - 1) / (costGrowth - 1)
    }
}

// MARK: - Catalog

enum UpgradeCatalog {

    static let all: [UpgradeDef] = defence + drone + economy

    private static let table: [UpgradeID: UpgradeDef] = {
        var map: [UpgradeID: UpgradeDef] = [:]
        for def in all { map[def.id] = def }
        return map
    }()

    static func def(_ id: UpgradeID) -> UpgradeDef {
        // Every case in `UpgradeID` has an entry below; the fallback keeps the
        // lookup non-optional at every call site.
        table[id] ?? defence[0]
    }

    static func upgrades(in category: UpgradeCategory) -> [UpgradeDef] {
        switch category {
        case .defence: return defence
        case .drone:   return drone
        case .economy: return economy
        }
    }

    // MARK: Defence

    static let defence: [UpgradeDef] = [
        UpgradeDef(id: .damage, category: .defence,
                   name: "Damage",
                   blurb: "Raw punch behind every round that leaves the barrel.",
                   icon: "bolt.fill",
                   baseCost: 15, costGrowth: 1.115,
                   base: 5, perLevel: 2.4, maxLevel: nil,
                   style: .flat(decimals: 1)),

        UpgradeDef(id: .fireRate, category: .defence,
                   name: "Fire Rate",
                   blurb: "Shots per second. Stack it until the barrel glows.",
                   icon: "flame.fill",
                   baseCost: 25, costGrowth: 1.135,
                   base: 1.4, perLevel: 0.11, maxLevel: 400,
                   style: .perSecond(decimals: 2)),

        UpgradeDef(id: .multishot, category: .defence,
                   name: "Multishot",
                   blurb: "Extra rounds per volley, fanned across the field.",
                   icon: "arrow.triangle.branch",
                   baseCost: 450, costGrowth: 1.62,
                   base: 1, perLevel: 1, maxLevel: 24,
                   style: .points),

        UpgradeDef(id: .critChance, category: .defence,
                   name: "Crit Chance",
                   blurb: "Odds that a round lands as a critical hit.",
                   icon: "burst.fill",
                   baseCost: 180, costGrowth: 1.27,
                   base: 0.03, perLevel: 0.007, maxLevel: 96,
                   style: .percent(decimals: 1)),

        UpgradeDef(id: .critDamage, category: .defence,
                   name: "Crit Damage",
                   blurb: "How hard a critical hit lands when it does.",
                   icon: "scope",
                   baseCost: 220, costGrowth: 1.19,
                   base: 2.0, perLevel: 0.15, maxLevel: nil,
                   style: .multiplier),

        UpgradeDef(id: .bulletSpeed, category: .defence,
                   name: "Bullet Speed",
                   blurb: "Rounds reach drifting targets sooner.",
                   icon: "hare.fill",
                   baseCost: 60, costGrowth: 1.145,
                   base: 420, perLevel: 16, maxLevel: 120,
                   style: .points),

        UpgradeDef(id: .pierce, category: .defence,
                   name: "Pierce",
                   blurb: "Rounds punch through this many extra dots.",
                   icon: "arrow.right.to.line",
                   baseCost: 1_400, costGrowth: 1.78,
                   base: 0, perLevel: 1, maxLevel: 12,
                   style: .points),

        UpgradeDef(id: .explosive, category: .defence,
                   name: "Explosive Rounds",
                   blurb: "Kills detonate, splashing damage onto neighbours.",
                   icon: "circle.hexagongrid.fill",
                   baseCost: 3_200, costGrowth: 1.34,
                   base: 0, perLevel: 4.5, maxLevel: 60,
                   style: .points)
    ]

    // MARK: Drone

    static let drone: [UpgradeDef] = [
        UpgradeDef(id: .droneSpeed, category: .drone,
                   name: "Drone Speed",
                   blurb: "Top speed while chasing loose orbs.",
                   icon: "figure.run",
                   baseCost: 40, costGrowth: 1.125,
                   base: 150, perLevel: 11, maxLevel: 150,
                   style: .points),

        UpgradeDef(id: .droneSuction, category: .drone,
                   name: "Suction",
                   blurb: "Radius in which orbs get dragged towards the drone.",
                   icon: "tornado",
                   baseCost: 55, costGrowth: 1.145,
                   base: 46, perLevel: 6, maxLevel: 150,
                   style: .points),

        UpgradeDef(id: .droneAgility, category: .drone,
                   name: "Agility",
                   blurb: "How sharply the drone can change heading.",
                   icon: "arrow.triangle.turn.up.right.diamond.fill",
                   baseCost: 70, costGrowth: 1.155,
                   base: 2.2, perLevel: 0.32, maxLevel: 120,
                   style: .flat(decimals: 2)),

        UpgradeDef(id: .droneSize, category: .drone,
                   name: "Size",
                   blurb: "A bigger hull sweeps up orbs on contact.",
                   icon: "circle.circle.fill",
                   baseCost: 90, costGrowth: 1.165,
                   base: 10, perLevel: 1.1, maxLevel: 90,
                   style: .flat(decimals: 1)),

        UpgradeDef(id: .droneMagnet, category: .drone,
                   name: "Magnet Power",
                   blurb: "Force with which caught orbs are reeled in.",
                   icon: "bolt.horizontal.fill",
                   baseCost: 320, costGrowth: 1.2,
                   base: 90, perLevel: 22, maxLevel: 120,
                   style: .points),

        UpgradeDef(id: .droneCount, category: .drone,
                   name: "Drone Count",
                   blurb: "Additional drones working the field with you.",
                   icon: "square.stack.3d.up.fill",
                   baseCost: 28_000, costGrowth: 6.5,
                   base: 1, perLevel: 1, maxLevel: 5,
                   style: .points),

        UpgradeDef(id: .droneBonus, category: .drone,
                   name: "Collector Bonus",
                   blurb: "Extra cash on every orb the drone brings home.",
                   icon: "plus.circle.fill",
                   baseCost: 500, costGrowth: 1.225,
                   base: 0, perLevel: 0.03, maxLevel: 200,
                   style: .percent(decimals: 0)),

        UpgradeDef(id: .orbLifetime, category: .drone,
                   name: "Orb Lifetime",
                   blurb: "How long dropped orbs linger before fading out.",
                   icon: "clock.fill",
                   baseCost: 160, costGrowth: 1.175,
                   base: 6, perLevel: 0.55, maxLevel: 80,
                   style: .seconds)
    ]

    // MARK: Economy

    static let economy: [UpgradeDef] = [
        UpgradeDef(id: .capacity, category: .economy,
                   name: "Capacity",
                   blurb: "Maximum number of dots drifting on the field.",
                   icon: "square.grid.3x3.fill",
                   baseCost: 30, costGrowth: 1.185,
                   base: 12, perLevel: 2, maxLevel: 114,
                   style: .points),

        UpgradeDef(id: .dotValue, category: .economy,
                   name: "Dot Value",
                   blurb: "Every popped dot is worth this much more.",
                   icon: "banknote.fill",
                   baseCost: 20, costGrowth: 1.12,
                   base: 1, perLevel: 0.12, maxLevel: nil,
                   style: .multiplier),

        UpgradeDef(id: .spawnRate, category: .economy,
                   name: "Spawn Rate",
                   blurb: "Fresh dots pushed into the field each second.",
                   icon: "arrow.clockwise",
                   baseCost: 35, costGrowth: 1.155,
                   base: 1.1, perLevel: 0.22, maxLevel: 200,
                   style: .perSecond(decimals: 2)),

        UpgradeDef(id: .luck, category: .economy,
                   name: "Luck",
                   blurb: "Weights every spawn roll towards the rare tiers.",
                   icon: "clover.fill",
                   baseCost: 140, costGrowth: 1.21,
                   base: 0.02, perLevel: 0.006, maxLevel: 130,
                   style: .percent(decimals: 1)),

        UpgradeDef(id: .comboWindow, category: .economy,
                   name: "Combo Window",
                   blurb: "Seconds you have to keep a kill combo alive.",
                   icon: "flame.circle.fill",
                   baseCost: 260, costGrowth: 1.215,
                   base: 1.6, perLevel: 0.12, maxLevel: 70,
                   style: .seconds),

        UpgradeDef(id: .idleIncome, category: .economy,
                   name: "Idle Income",
                   blurb: "Passive cash that keeps ticking, dots or no dots.",
                   icon: "infinity",
                   baseCost: 6_000, costGrowth: 1.46,
                   base: 0, perLevel: 0.9, maxLevel: nil,
                   style: .perSecond(decimals: 1)),

        UpgradeDef(id: .goldenDots, category: .economy,
                   name: "Golden Dots",
                   blurb: "Chance for a golden dot worth 25x the usual haul.",
                   icon: "star.circle.fill",
                   baseCost: 9_500, costGrowth: 1.43,
                   base: 0, perLevel: 0.004, maxLevel: 60,
                   style: .percent(decimals: 1)),

        UpgradeDef(id: .offlineRate, category: .economy,
                   name: "Offline Rate",
                   blurb: "Share of your live income that accrues while away.",
                   icon: "moon.zzz.fill",
                   baseCost: 4_000, costGrowth: 1.4,
                   base: 0.25, perLevel: 0.05, maxLevel: 15,
                   style: .percent(decimals: 0))
    ]
}
