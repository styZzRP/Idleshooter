import Foundation

/// A per-galaxy twist on the simulation. Every galaxy carries exactly one.
enum GalaxyModifier: Int, Codable, CaseIterable {
    case calm
    case dense
    case swift
    case armoured
    case rich
    case lucky
    case volatile
    case magnetic
    case frenzied
    case gilded
    case crushing
    case nebula

    var title: String {
        switch self {
        case .calm:     return "Calm Space"
        case .dense:    return "Dense Field"
        case .swift:    return "Solar Wind"
        case .armoured: return "Armoured Shells"
        case .rich:     return "Rich Deposits"
        case .lucky:    return "Lucky Streak"
        case .volatile: return "Volatile Matter"
        case .magnetic: return "Magnetic Storm"
        case .frenzied: return "Overclocked"
        case .gilded:   return "Gilded Belt"
        case .crushing: return "Crushing Gravity"
        case .nebula:   return "Nebula Drift"
        }
    }

    var detail: String {
        switch self {
        case .calm:     return "No modifiers. Just you and the void."
        case .dense:    return "+40% spawn rate, +15% dot health."
        case .swift:    return "Dots drift 70% faster, +25% value."
        case .armoured: return "+70% dot health, +60% dot value."
        case .rich:     return "+50% dot value."
        case .lucky:    return "+60% luck on every spawn roll."
        case .volatile: return "-30% dot health, +60% spawn rate, -15% value."
        case .magnetic: return "+45% drone suction, +20% value."
        case .frenzied: return "+25% fire rate, +10% dot health."
        case .gilded:   return "+6% golden dot chance."
        case .crushing: return "+130% dot health, +150% dot value."
        case .nebula:   return "Dots wander unpredictably, +35% value."
        }
    }

    var icon: String {
        switch self {
        case .calm:     return "moon.stars.fill"
        case .dense:    return "circle.grid.3x3.fill"
        case .swift:    return "wind"
        case .armoured: return "shield.fill"
        case .rich:     return "dollarsign.circle.fill"
        case .lucky:    return "clover.fill"
        case .volatile: return "waveform.path.ecg"
        case .magnetic: return "tornado"
        case .frenzied: return "flame.fill"
        case .gilded:   return "star.circle.fill"
        case .crushing: return "arrow.down.circle.fill"
        case .nebula:   return "cloud.fog.fill"
        }
    }

    var healthScale: Double {
        switch self {
        case .dense:    return 1.15
        case .armoured: return 1.7
        case .volatile: return 0.7
        case .frenzied: return 1.1
        case .crushing: return 2.3
        default:        return 1
        }
    }

    var valueScale: Double {
        switch self {
        case .swift:    return 1.25
        case .armoured: return 1.6
        case .rich:     return 1.5
        case .volatile: return 0.85
        case .magnetic: return 1.2
        case .crushing: return 2.5
        case .nebula:   return 1.35
        default:        return 1
        }
    }

    var spawnScale: Double {
        switch self {
        case .dense:    return 1.4
        case .volatile: return 1.6
        default:        return 1
        }
    }

    var driftScale: Double {
        switch self {
        case .swift:  return 1.7
        case .nebula: return 1.25
        default:      return 1
        }
    }

    var luckBonus: Double {
        self == .lucky ? 0.6 : 0
    }

    var suctionScale: Double {
        self == .magnetic ? 1.45 : 1
    }

    var fireRateScale: Double {
        self == .frenzied ? 1.25 : 1
    }

    var goldenBonus: Double {
        self == .gilded ? 0.06 : 0
    }

    /// Extra random steering applied to dot velocity each second.
    var wanderScale: Double {
        self == .nebula ? 1 : 0
    }
}

struct Galaxy: Identifiable, Hashable {
    let index: Int
    let name: String
    let modifierRaw: Int

    var id: Int { index }
    var number: Int { index + 1 }
    var modifier: GalaxyModifier { GalaxyModifier(rawValue: modifierRaw) ?? .calm }

    /// Base dot health scaling for this galaxy, modifier included.
    var healthMultiplier: Double {
        pow(1.4, Double(index)) * modifier.healthScale
    }

    /// Base dot value scaling for this galaxy, modifier included.
    var valueMultiplier: Double {
        pow(1.8, Double(index)) * modifier.valueScale
    }

    /// Cash needed to travel here. Galaxy 1 is the starting point.
    var travelCost: Double {
        index == 0 ? 0 : 2_500 * pow(3.0, Double(index))
    }

    var palette: PaletteColor {
        PaletteColor.galaxyRamp[index % PaletteColor.galaxyRamp.count]
    }
}

enum GalaxyCatalog {

    /// Rebirth becomes available once the player has reached this galaxy.
    static let rebirthUnlockIndex = 9

    static let all: [Galaxy] = names.enumerated().map { offset, name in
        Galaxy(index: offset,
               name: name,
               modifierRaw: modifierOrder[offset % modifierOrder.count].rawValue)
    }

    static var count: Int { all.count }

    static func galaxy(at index: Int) -> Galaxy {
        all[min(max(index, 0), all.count - 1)]
    }

    private static let modifierOrder: [GalaxyModifier] = [
        .calm, .dense, .rich, .swift, .lucky, .armoured, .magnetic, .volatile,
        .gilded, .frenzied, .nebula, .crushing
    ]

    private static let names: [String] = [
        "The Void", "Ember Reach", "Cobalt Drift", "Halcyon Belt", "Vermilion Rift",
        "Silent Expanse", "Auric Cluster", "Pale Meridian", "Cinder Gate", "Verdant Coil",
        "Obsidian Span", "Lumen Hollow", "Saffron Wake", "Ashen Spiral", "Tidal Crown",
        "Quartz Divide", "Umbra Field", "Solace Arc", "Ferrite Chain", "Glass Horizon",
        "Iron Requiem", "Nova Threshold", "Zephyr Bloom", "Crimson Lattice", "Mirror Deep",
        "Hollow Ascent", "Starless March", "Onyx Cascade", "Radiant Fault", "Sable Current",
        "Prism Verge", "Echo Sanctum", "Basalt Ring", "Twilight Furrow", "Aether Shoal",
        "Ivory Descent", "Molten Chorus", "Frost Meridian", "Cerulean Maw", "Ochre Passage",
        "Spectral Reef", "Titan's Ledger", "Wandering Ash", "Gilded Abyss", "Storm Chalice",
        "Final Aurora", "Null Cathedral", "Eventide Crown", "Singularity's Edge", "Origin"
    ]
}
