import Foundation

/// What a shop item hands over when it is claimed.
enum ShopEffect {
    case gems(Double)
    case starDust(Double)
    /// Cash worth this many hours of the player's current production.
    case cashHours(Double)
    /// Flat cash, used for the very first purchases when production is ~0.
    case flatCash(Double)
    case permanentCashMultiplier(Double)
    case permanentDamageMultiplier(Double)
    case permanentDropMultiplier(Double)
    case offlineMultiplier(Double)
    case removeAds
    case autoCast
    case vip
    case unlockAllAbilities
    case cosmetic(String)

    var summary: String {
        switch self {
        case .gems(let n):                     return "\(Fmt.count(n)) gems"
        case .starDust(let n):                 return "\(Fmt.count(n)) Star Dust"
        case .cashHours(let h):                return "\(Fmt.duration(h * 3600)) of production"
        case .flatCash(let n):                 return "\(Fmt.cash(n)) cash"
        case .permanentCashMultiplier(let m):  return "Permanent \(Fmt.multiplier(m)) cash"
        case .permanentDamageMultiplier(let m):return "Permanent \(Fmt.multiplier(m)) damage"
        case .permanentDropMultiplier(let m):  return "Permanent \(Fmt.multiplier(m)) orb drops"
        case .offlineMultiplier(let m):        return "Offline earnings \(Fmt.multiplier(m))"
        case .removeAds:                       return "No ads, ever"
        case .autoCast:                        return "Abilities cast themselves"
        case .vip:                             return "VIP perks unlocked"
        case .unlockAllAbilities:              return "All abilities unlocked"
        case .cosmetic(let key):
            return CosmeticCatalog.cosmetic(key).map { "\($0.name) \($0.slot.title.lowercased())" } ?? "Cosmetic"
        }
    }
}

enum ShopSection: String, CaseIterable, Identifiable {
    case featured
    case currency
    case boosts
    case cosmetics
    case utilities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured:  return "Featured"
        case .currency:  return "Currency"
        case .boosts:    return "Boosts"
        case .cosmetics: return "Cosmetics"
        case .utilities: return "Utilities"
        }
    }

    var icon: String {
        switch self {
        case .featured:  return "star.fill"
        case .currency:  return "diamond.fill"
        case .boosts:    return "bolt.fill"
        case .cosmetics: return "paintbrush.fill"
        case .utilities: return "gearshape.fill"
        }
    }
}

struct ShopItem: Identifiable {
    let id: String
    let section: ShopSection
    let name: String
    let blurb: String
    let icon: String
    let palette: PaletteColor
    /// The price this pack carries in the original game. Shown struck through —
    /// in this build every single item is handed over for free.
    let listPrice: String
    /// Consumables can be claimed as often as you like; unlocks only once.
    let repeatable: Bool
    let badge: String?
    let effects: [ShopEffect]

    var effectSummary: String {
        effects.map(\.summary).joined(separator: " · ")
    }
}

enum ShopCatalog {

    /// Every item in this build costs nothing. `listPrice` is kept purely so the
    /// storefront can show what each pack would have cost.
    static let freePriceLabel = "FREE"

    static let all: [ShopItem] = featured + currency + boosts + cosmetics + utilities

    static func items(in section: ShopSection) -> [ShopItem] {
        all.filter { $0.section == section }
    }

    static func item(_ id: String) -> ShopItem? {
        all.first { $0.id == id }
    }

    // MARK: Featured bundles

    static let featured: [ShopItem] = [
        ShopItem(id: "pack.starter", section: .featured,
                 name: "Starter Pack",
                 blurb: "Everything a fresh turret needs to get rolling.",
                 icon: "shippingbox.fill", palette: .cyan,
                 listPrice: "€2,99", repeatable: false, badge: "STARTER",
                 effects: [.gems(500), .flatCash(25_000), .permanentCashMultiplier(1.5)]),

        ShopItem(id: "pack.mega", section: .featured,
                 name: "Mega Bundle",
                 blurb: "The whole shop in one box, near enough.",
                 icon: "cube.transparent.fill", palette: .purple,
                 listPrice: "€24,99", repeatable: false, badge: "BEST VALUE",
                 effects: [.gems(12_000), .starDust(50), .cashHours(6),
                           .permanentCashMultiplier(2), .permanentDamageMultiplier(2)]),

        ShopItem(id: "pack.galaxy", section: .featured,
                 name: "Galaxy Pack",
                 blurb: "Jump-start the long haul across the void.",
                 icon: "sparkles.rectangle.stack.fill", palette: .indigo,
                 listPrice: "€9,99", repeatable: false, badge: nil,
                 effects: [.gems(3_500), .cashHours(3), .unlockAllAbilities]),

        ShopItem(id: "pack.stardust", section: .featured,
                 name: "Dust Cache",
                 blurb: "A pouch of Star Dust straight into the vault.",
                 icon: "star.circle.fill", palette: .gold,
                 listPrice: "€14,99", repeatable: true, badge: nil,
                 effects: [.starDust(40)])
    ]

    // MARK: Currency

    static let currency: [ShopItem] = [
        ShopItem(id: "gems.handful", section: .currency,
                 name: "Handful of Gems", blurb: "A modest pile.",
                 icon: "diamond.fill", palette: .cyan,
                 listPrice: "€0,99", repeatable: true, badge: nil,
                 effects: [.gems(120)]),

        ShopItem(id: "gems.pouch", section: .currency,
                 name: "Pouch of Gems", blurb: "Enough for a skin or two.",
                 icon: "bag.fill", palette: .teal,
                 listPrice: "€4,99", repeatable: true, badge: nil,
                 effects: [.gems(700)]),

        ShopItem(id: "gems.chest", section: .currency,
                 name: "Chest of Gems", blurb: "Now we're talking.",
                 icon: "shippingbox.fill", palette: .violet,
                 listPrice: "€19,99", repeatable: true, badge: "POPULAR",
                 effects: [.gems(3_200)]),

        ShopItem(id: "gems.vault", section: .currency,
                 name: "Vault of Gems", blurb: "Absurd quantities of the stuff.",
                 icon: "lock.rectangle.stack.fill", palette: .magenta,
                 listPrice: "€99,99", repeatable: true, badge: nil,
                 effects: [.gems(20_000)]),

        ShopItem(id: "cash.small", section: .currency,
                 name: "Cash Injection", blurb: "One hour of production, instantly.",
                 icon: "banknote.fill", palette: .green,
                 listPrice: "€1,99", repeatable: true, badge: nil,
                 effects: [.cashHours(1), .flatCash(5_000)]),

        ShopItem(id: "cash.large", section: .currency,
                 name: "Cash Windfall", blurb: "Eight hours of production, instantly.",
                 icon: "dollarsign.square.fill", palette: .lime,
                 listPrice: "€9,99", repeatable: true, badge: nil,
                 effects: [.cashHours(8), .flatCash(50_000)])
    ]

    // MARK: Boosts

    static let boosts: [ShopItem] = [
        ShopItem(id: "boost.cash2x", section: .boosts,
                 name: "Double Cash", blurb: "Permanently doubles every payout.",
                 icon: "multiply.circle.fill", palette: .gold,
                 listPrice: "€6,99", repeatable: false, badge: nil,
                 effects: [.permanentCashMultiplier(2)]),

        ShopItem(id: "boost.damage2x", section: .boosts,
                 name: "Double Damage", blurb: "Permanently doubles turret damage.",
                 icon: "bolt.badge.a.fill", palette: .red,
                 listPrice: "€6,99", repeatable: false, badge: nil,
                 effects: [.permanentDamageMultiplier(2)]),

        ShopItem(id: "boost.drops", section: .boosts,
                 name: "Rich Orbs", blurb: "Every orb the drone collects is worth half again as much.",
                 icon: "circle.hexagonpath.fill", palette: .amber,
                 listPrice: "€4,99", repeatable: false, badge: nil,
                 effects: [.permanentDropMultiplier(1.5)]),

        ShopItem(id: "boost.offline", section: .boosts,
                 name: "Offline Overdrive", blurb: "Quadruples what you earn while the app is closed.",
                 icon: "moon.stars.fill", palette: .indigo,
                 listPrice: "€7,99", repeatable: false, badge: nil,
                 effects: [.offlineMultiplier(4)]),

        ShopItem(id: "boost.abilities", section: .boosts,
                 name: "Ability Unlock", blurb: "Frenzy, Dot Rain and Black Hole, right now.",
                 icon: "sparkles", palette: .orange,
                 listPrice: "€3,99", repeatable: false, badge: nil,
                 effects: [.unlockAllAbilities])
    ]

    // MARK: Cosmetics (generated from the cosmetic catalog)

    static let cosmetics: [ShopItem] = CosmeticCatalog.all
        .filter { $0.id != $0.slot.defaultKey }
        .map { cosmetic in
            ShopItem(id: "cosmetic.\(cosmetic.id)",
                     section: .cosmetics,
                     name: cosmetic.name,
                     blurb: cosmetic.blurb,
                     icon: cosmetic.slot.icon,
                     palette: cosmetic.primary,
                     listPrice: "€1,99",
                     repeatable: false,
                     badge: cosmetic.slot.title.uppercased(),
                     effects: [.cosmetic(cosmetic.id)])
        }

    // MARK: Utilities

    static let utilities: [ShopItem] = [
        ShopItem(id: "util.noads", section: .utilities,
                 name: "Remove Ads", blurb: "There are no ads in this build. Claim it anyway.",
                 icon: "nosign", palette: .slate,
                 listPrice: "€3,99", repeatable: false, badge: nil,
                 effects: [.removeAds]),

        ShopItem(id: "util.autocast", section: .utilities,
                 name: "Auto Cast", blurb: "Abilities fire themselves the moment they come off cooldown.",
                 icon: "wand.and.stars", palette: .violet,
                 listPrice: "€5,99", repeatable: false, badge: nil,
                 effects: [.autoCast]),

        ShopItem(id: "util.vip", section: .utilities,
                 name: "VIP Pass", blurb: "A permanent 25% cash bonus and a badge on the leaderboard.",
                 icon: "crown.fill", palette: .gold,
                 listPrice: "€9,99 / maand", repeatable: false, badge: "SUBSCRIPTION",
                 effects: [.vip, .permanentCashMultiplier(1.25)])
    ]
}
