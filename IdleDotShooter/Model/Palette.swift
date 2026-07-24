import SwiftUI

/// A small, fixed palette so every screen, dot tier and cosmetic pulls from the
/// same set of colours.
enum PaletteColor: String, Codable, CaseIterable {
    case red, crimson, orange, amber, gold, lime, green, mint, teal
    case cyan, blue, indigo, violet, purple, magenta, pink
    case slate, silver, white, ember, void

    var color: Color {
        Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }

    var rgb: (Double, Double, Double) {
        switch self {
        case .red:     return (1.00, 0.27, 0.31)
        case .crimson: return (0.85, 0.11, 0.35)
        case .orange:  return (1.00, 0.53, 0.20)
        case .amber:   return (1.00, 0.72, 0.20)
        case .gold:    return (1.00, 0.84, 0.29)
        case .lime:    return (0.72, 0.93, 0.29)
        case .green:   return (0.33, 0.89, 0.47)
        case .mint:    return (0.40, 0.96, 0.76)
        case .teal:    return (0.20, 0.80, 0.76)
        case .cyan:    return (0.24, 0.82, 1.00)
        case .blue:    return (0.29, 0.55, 1.00)
        case .indigo:  return (0.45, 0.42, 1.00)
        case .violet:  return (0.63, 0.40, 1.00)
        case .purple:  return (0.76, 0.35, 0.98)
        case .magenta: return (0.95, 0.33, 0.85)
        case .pink:    return (1.00, 0.45, 0.68)
        case .slate:   return (0.62, 0.68, 0.78)
        case .silver:  return (0.82, 0.86, 0.92)
        case .white:   return (0.98, 0.99, 1.00)
        case .ember:   return (0.99, 0.40, 0.12)
        case .void:    return (0.36, 0.30, 0.62)
        }
    }

    /// Colour cycle used to give every galaxy its own tint.
    static let galaxyRamp: [PaletteColor] = [
        .slate, .ember, .cyan, .mint, .crimson, .silver, .gold, .violet,
        .orange, .green, .indigo, .purple, .amber, .red, .teal, .blue, .pink, .magenta
    ]
}

extension Color {
    /// Deep space background used behind the whole app.
    static let fieldBackground = Color(red: 0.043, green: 0.047, blue: 0.078)
    static let panel = Color(red: 0.086, green: 0.094, blue: 0.145)
    static let panelRaised = Color(red: 0.125, green: 0.137, blue: 0.204)
    static let hairline = Color(red: 0.22, green: 0.24, blue: 0.32)
    static let dimText = Color(red: 0.60, green: 0.64, blue: 0.74)
}
