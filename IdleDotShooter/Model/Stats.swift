import Foundation

/// Everything the Command Centre reports on.
struct GameStats: Codable {
    var dotsDestroyed: Double = 0
    var shotsFired: Double = 0
    var bulletsHit: Double = 0
    var criticalHits: Double = 0
    var orbsCollected: Double = 0
    var orbsLost: Double = 0

    var cashEarnedLifetime: Double = 0
    var cashEarnedThisRun: Double = 0
    var cashSpent: Double = 0
    var biggestSingleHit: Double = 0
    var biggestSinglePayout: Double = 0

    var timeActive: Double = 0
    var timeOffline: Double = 0
    var sessionsPlayed: Int = 0

    var upgradesPurchased: Double = 0
    var abilitiesCast: Double = 0
    var frenzyCasts: Double = 0
    var dotRainCasts: Double = 0
    var blackHoleCasts: Double = 0

    var galaxyTravels: Double = 0
    var highestGalaxyIndex: Int = 0
    var rebirths: Int = 0
    var starDustEarnedLifetime: Double = 0

    var bestCombo: Int = 0
    var goldenDotsPopped: Double = 0
    /// Indexed by `Rarity.rawValue`.
    var rarityKills: [Double] = Array(repeating: 0, count: Rarity.allCases.count)

    var firstPlayed: Date = Date()

    // MARK: Derived

    var accuracy: Double {
        shotsFired > 0 ? min(1, bulletsHit / shotsFired) : 0
    }

    var critRateObserved: Double {
        bulletsHit > 0 ? min(1, criticalHits / bulletsHit) : 0
    }

    var collectionRate: Double {
        let total = orbsCollected + orbsLost
        return total > 0 ? orbsCollected / total : 1
    }

    var averagePayout: Double {
        dotsDestroyed > 0 ? cashEarnedLifetime / dotsDestroyed : 0
    }

    mutating func recordKill(rarity: Rarity) {
        dotsDestroyed += 1
        let index = rarity.rawValue
        if rarityKills.count < Rarity.allCases.count {
            rarityKills.append(contentsOf: Array(repeating: 0,
                                                 count: Rarity.allCases.count - rarityKills.count))
        }
        if index < rarityKills.count { rarityKills[index] += 1 }
    }

    func kills(of rarity: Rarity) -> Double {
        let index = rarity.rawValue
        return index < rarityKills.count ? rarityKills[index] : 0
    }

    /// Reset the parts that only describe the current run.
    mutating func beginNewRun() {
        cashEarnedThisRun = 0
    }
}

/// One row in the Command Centre.
struct StatRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let icon: String
    let palette: PaletteColor
}

/// A grouped block of Command Centre rows.
struct StatSection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [StatRow]
}
