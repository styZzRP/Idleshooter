import Foundation

/// Maps a dot's rarity to a colour under the currently equipped dot theme.
/// Shared by the renderer and by the particle spawner so pops match the dot
/// that produced them.
enum DotPalette {

    static let goldenRGB: (Double, Double, Double) = (1.0, 0.84, 0.29)

    static func palette(for rarity: Rarity, themeVariant: Int) -> PaletteColor {
        switch themeVariant {
        case 1: // Neon Night
            switch rarity {
            case .common: return .cyan
            case .uncommon: return .mint
            case .rare: return .blue
            case .epic: return .violet
            case .legendary: return .magenta
            case .cosmic: return .pink
            }
        case 2: // Monochrome
            switch rarity {
            case .common: return .slate
            case .uncommon: return .silver
            case .rare: return .white
            case .epic: return .silver
            case .legendary: return .white
            case .cosmic: return .silver
            }
        case 3: // Candy Shell
            switch rarity {
            case .common: return .pink
            case .uncommon: return .lime
            case .rare: return .amber
            case .epic: return .teal
            case .legendary: return .violet
            case .cosmic: return .magenta
            }
        case 4: // Molten
            switch rarity {
            case .common: return .ember
            case .uncommon: return .orange
            case .rare: return .amber
            case .epic: return .gold
            case .legendary: return .crimson
            case .cosmic: return .red
            }
        case 5: // Deep Sea
            switch rarity {
            case .common: return .teal
            case .uncommon: return .cyan
            case .rare: return .blue
            case .epic: return .indigo
            case .legendary: return .mint
            case .cosmic: return .violet
            }
        default:
            return rarity.palette
        }
    }

    static func rgb(for rarity: Rarity, golden: Bool, themeVariant: Int) -> (Double, Double, Double) {
        golden ? goldenRGB : palette(for: rarity, themeVariant: themeVariant).rgb
    }
}
