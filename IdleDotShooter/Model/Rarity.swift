import Foundation

/// Spawn tiers for dots. Higher tiers are tougher but pay out far better;
/// the Luck upgrade shifts the roll towards the top of the table.
enum Rarity: Int, Codable, CaseIterable, Identifiable {
    case common = 0
    case uncommon
    case rare
    case epic
    case legendary
    case cosmic

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        case .cosmic:    return "Cosmic"
        }
    }

    var valueMultiplier: Double {
        switch self {
        case .common:    return 1
        case .uncommon:  return 2.6
        case .rare:      return 6.5
        case .epic:      return 17
        case .legendary: return 46
        case .cosmic:    return 130
        }
    }

    var healthMultiplier: Double {
        switch self {
        case .common:    return 1
        case .uncommon:  return 1.7
        case .rare:      return 2.8
        case .epic:      return 4.8
        case .legendary: return 8.5
        case .cosmic:    return 16
        }
    }

    var radius: Double {
        switch self {
        case .common:    return 10
        case .uncommon:  return 11.5
        case .rare:      return 13
        case .epic:      return 15
        case .legendary: return 17
        case .cosmic:    return 19.5
        }
    }

    var palette: PaletteColor {
        switch self {
        case .common:    return .slate
        case .uncommon:  return .green
        case .rare:      return .cyan
        case .epic:      return .purple
        case .legendary: return .orange
        case .cosmic:    return .pink
        }
    }

    /// Rolls a rarity given the player's luck stat (0...1-ish).
    static func roll(luck: Double) -> Rarity {
        let l = max(0, luck)
        let cosmic = min(0.05, l * 0.02)
        let legendary = min(0.10, l * 0.07)
        let epic = min(0.16, l * 0.18)
        let rare = min(0.24, l * 0.45)
        let uncommon = min(0.34, l * 1.3)

        let roll = Double.random(in: 0..<1)
        var floorValue = 0.0

        floorValue += cosmic
        if roll < floorValue { return .cosmic }
        floorValue += legendary
        if roll < floorValue { return .legendary }
        floorValue += epic
        if roll < floorValue { return .epic }
        floorValue += rare
        if roll < floorValue { return .rare }
        floorValue += uncommon
        if roll < floorValue { return .uncommon }
        return .common
    }
}
