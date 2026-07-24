import Foundation

enum CosmeticSlot: String, Codable, CaseIterable, Identifiable {
    case turret
    case dots
    case drone
    case background
    case trail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .turret:     return "Turret"
        case .dots:       return "Dot Theme"
        case .drone:      return "Drone"
        case .background: return "Backdrop"
        case .trail:      return "Bullet Trail"
        }
    }

    var icon: String {
        switch self {
        case .turret:     return "triangle.fill"
        case .dots:       return "circle.grid.2x2.fill"
        case .drone:      return "airplane"
        case .background: return "sparkles"
        case .trail:      return "line.diagonal"
        }
    }

    var defaultKey: String {
        switch self {
        case .turret:     return "turret.standard"
        case .dots:       return "dots.classic"
        case .drone:      return "drone.scout"
        case .background: return "bg.void"
        case .trail:      return "trail.plain"
        }
    }
}

struct Cosmetic: Identifiable, Hashable {
    let id: String
    let slot: CosmeticSlot
    let name: String
    let blurb: String
    let primary: PaletteColor
    let secondary: PaletteColor
    /// Shape / rendering variant within the slot.
    let variant: Int

    static func == (lhs: Cosmetic, rhs: Cosmetic) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum CosmeticCatalog {

    static let all: [Cosmetic] = turrets + dotThemes + drones + backgrounds + trails

    static func cosmetic(_ id: String) -> Cosmetic? {
        lookup[id]
    }

    static func cosmetic(for slot: CosmeticSlot, key: String) -> Cosmetic {
        lookup[key] ?? lookup[slot.defaultKey] ?? all[0]
    }

    static func items(in slot: CosmeticSlot) -> [Cosmetic] {
        all.filter { $0.slot == slot }
    }

    private static let lookup: [String: Cosmetic] = {
        var map: [String: Cosmetic] = [:]
        for item in all { map[item.id] = item }
        return map
    }()

    // MARK: Turrets

    static let turrets: [Cosmetic] = [
        Cosmetic(id: "turret.standard", slot: .turret, name: "Standard Issue",
                 blurb: "The barrel you started with.", primary: .cyan, secondary: .blue, variant: 0),
        Cosmetic(id: "turret.ember", slot: .turret, name: "Ember Lance",
                 blurb: "Runs hot, always has.", primary: .ember, secondary: .amber, variant: 1),
        Cosmetic(id: "turret.frost", slot: .turret, name: "Frostbite",
                 blurb: "Cold-forged and razor thin.", primary: .mint, secondary: .cyan, variant: 2),
        Cosmetic(id: "turret.void", slot: .turret, name: "Void Caster",
                 blurb: "Bends the dark around the muzzle.", primary: .violet, secondary: .void, variant: 3),
        Cosmetic(id: "turret.gilded", slot: .turret, name: "Gilded Cannon",
                 blurb: "Solid gold. Recoil not included.", primary: .gold, secondary: .amber, variant: 4),
        Cosmetic(id: "turret.bloom", slot: .turret, name: "Bloom",
                 blurb: "Petals of plasma on every shot.", primary: .pink, secondary: .magenta, variant: 5),
        Cosmetic(id: "turret.sentinel", slot: .turret, name: "Sentinel",
                 blurb: "Heavy plating, heavier presence.", primary: .slate, secondary: .silver, variant: 6),
        Cosmetic(id: "turret.prism", slot: .turret, name: "Prism",
                 blurb: "Splits light into ordnance.", primary: .teal, secondary: .indigo, variant: 7)
    ]

    // MARK: Dot themes

    static let dotThemes: [Cosmetic] = [
        Cosmetic(id: "dots.classic", slot: .dots, name: "Classic",
                 blurb: "Rarity colours, exactly as intended.", primary: .white, secondary: .slate, variant: 0),
        Cosmetic(id: "dots.neon", slot: .dots, name: "Neon Night",
                 blurb: "Everything glows a little harder.", primary: .magenta, secondary: .cyan, variant: 1),
        Cosmetic(id: "dots.mono", slot: .dots, name: "Monochrome",
                 blurb: "For the purists.", primary: .silver, secondary: .slate, variant: 2),
        Cosmetic(id: "dots.candy", slot: .dots, name: "Candy Shell",
                 blurb: "Sweet, brittle, satisfying.", primary: .pink, secondary: .lime, variant: 3),
        Cosmetic(id: "dots.molten", slot: .dots, name: "Molten",
                 blurb: "Straight from the forge.", primary: .ember, secondary: .gold, variant: 4),
        Cosmetic(id: "dots.deepsea", slot: .dots, name: "Deep Sea",
                 blurb: "Bioluminescence in a vacuum.", primary: .teal, secondary: .indigo, variant: 5)
    ]

    // MARK: Drones

    static let drones: [Cosmetic] = [
        Cosmetic(id: "drone.scout", slot: .drone, name: "Scout",
                 blurb: "Reliable little collector.", primary: .cyan, secondary: .white, variant: 0),
        Cosmetic(id: "drone.wasp", slot: .drone, name: "Wasp",
                 blurb: "Angry, fast, striped.", primary: .amber, secondary: .slate, variant: 1),
        Cosmetic(id: "drone.orbital", slot: .drone, name: "Orbital",
                 blurb: "Rings that never stop turning.", primary: .violet, secondary: .indigo, variant: 2),
        Cosmetic(id: "drone.husk", slot: .drone, name: "Husk",
                 blurb: "Salvaged from a dead galaxy.", primary: .slate, secondary: .ember, variant: 3),
        Cosmetic(id: "drone.starling", slot: .drone, name: "Starling",
                 blurb: "Leaves a trail of dust behind it.", primary: .gold, secondary: .white, variant: 4)
    ]

    // MARK: Backgrounds

    static let backgrounds: [Cosmetic] = [
        Cosmetic(id: "bg.void", slot: .background, name: "The Void",
                 blurb: "Plain, dark, endless.", primary: .void, secondary: .slate, variant: 0),
        Cosmetic(id: "bg.nebula", slot: .background, name: "Nebula",
                 blurb: "Violet clouds drifting past.", primary: .purple, secondary: .indigo, variant: 1),
        Cosmetic(id: "bg.aurora", slot: .background, name: "Aurora",
                 blurb: "Green light bleeding across the field.", primary: .green, secondary: .teal, variant: 2),
        Cosmetic(id: "bg.ember", slot: .background, name: "Ember Sky",
                 blurb: "The last warmth of a dying star.", primary: .ember, secondary: .crimson, variant: 3),
        Cosmetic(id: "bg.grid", slot: .background, name: "Grid",
                 blurb: "Clean lines for clean runs.", primary: .cyan, secondary: .blue, variant: 4),
        Cosmetic(id: "bg.singularity", slot: .background, name: "Singularity",
                 blurb: "Something enormous, just out of frame.", primary: .magenta, secondary: .void, variant: 5)
    ]

    // MARK: Trails

    static let trails: [Cosmetic] = [
        Cosmetic(id: "trail.plain", slot: .trail, name: "Standard",
                 blurb: "A clean streak of light.", primary: .white, secondary: .cyan, variant: 0),
        Cosmetic(id: "trail.plasma", slot: .trail, name: "Plasma",
                 blurb: "Thick, hot, hard to miss.", primary: .ember, secondary: .amber, variant: 1),
        Cosmetic(id: "trail.frost", slot: .trail, name: "Frost",
                 blurb: "Leaves the air crystallised.", primary: .cyan, secondary: .white, variant: 2),
        Cosmetic(id: "trail.void", slot: .trail, name: "Void Streak",
                 blurb: "A tear in the backdrop.", primary: .violet, secondary: .magenta, variant: 3),
        Cosmetic(id: "trail.gold", slot: .trail, name: "Gold Rush",
                 blurb: "Every shot looks expensive.", primary: .gold, secondary: .amber, variant: 4)
    ]
}
