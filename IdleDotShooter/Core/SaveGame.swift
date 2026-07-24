import Foundation

enum BuyQuantity: String, Codable, CaseIterable, Identifiable {
    case one
    case ten
    case twentyFive
    case max

    var id: String { rawValue }

    var label: String {
        switch self {
        case .one:        return "x1"
        case .ten:        return "x10"
        case .twentyFive: return "x25"
        case .max:        return "MAX"
        }
    }

    var count: Int? {
        switch self {
        case .one:        return 1
        case .ten:        return 10
        case .twentyFive: return 25
        case .max:        return nil
        }
    }
}

struct GameSettings: Codable {
    var haptics = true
    var sound = true
    var particles = true
    var damageNumbers = true
    var reducedMotion = false
    var confirmRebirth = true
    var buyQuantity: BuyQuantity = .one

    enum CodingKeys: String, CodingKey {
        case haptics, sound, particles, damageNumbers, reducedMotion, confirmRebirth, buyQuantity
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        particles = try c.decodeIfPresent(Bool.self, forKey: .particles) ?? true
        damageNumbers = try c.decodeIfPresent(Bool.self, forKey: .damageNumbers) ?? true
        reducedMotion = try c.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? false
        confirmRebirth = try c.decodeIfPresent(Bool.self, forKey: .confirmRebirth) ?? true
        buyQuantity = try c.decodeIfPresent(BuyQuantity.self, forKey: .buyQuantity) ?? .one
    }
}

/// Flat, versioned snapshot of everything worth keeping between launches.
struct SaveGame: Codable {
    var version: Int = 1

    var playerName: String = "Commander"

    var cash: Double = 0
    var gems: Double = 0
    var starDust: Double = 0

    var galaxyIndex: Int = 0
    var unlockedGalaxyIndex: Int = 0

    /// Keyed by `UpgradeID.rawValue`.
    var upgradeLevels: [String: Int] = [:]
    /// Keyed by `StarUpgradeID.rawValue`.
    var starUpgradeLevels: [String: Int] = [:]
    /// Keyed by `AbilityID.rawValue`.
    var abilities: [String: AbilityState] = [:]

    var stats = GameStats()
    var settings = GameSettings()

    var ownedShopItems: [String] = []
    var ownedCosmetics: [String] = []
    /// Keyed by `CosmeticSlot.rawValue`.
    var equippedCosmetics: [String: String] = [:]

    var shopCashMultiplier: Double = 1
    var shopDamageMultiplier: Double = 1
    var shopDropMultiplier: Double = 1
    var shopOfflineMultiplier: Double = 1
    var autoCastUnlocked = false
    var autoCastEnabled = false
    var adsRemoved = false
    var isVIP = false

    var recentIncomePerSecond: Double = 0
    var tutorialSeen = false
    var lastSaved: Date = Date()

    init() {}
}

/// Reads and writes the save file. Falls back to `UserDefaults` if the
/// Documents directory is unavailable for any reason.
enum SaveStore {

    private static let fileName = "idledotshooter.save.json"
    private static let defaultsKey = "idleDotShooter.save.v1"

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    static func load() -> SaveGame? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let save = try? decoder.decode(SaveGame.self, from: data) {
            return save
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let save = try? decoder.decode(SaveGame.self, from: data) {
            return save
        }
        return nil
    }

    static func save(_ snapshot: SaveGame) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return }

        if let url = fileURL {
            do {
                try data.write(to: url, options: .atomic)
                return
            } catch {
                // Fall through to UserDefaults.
            }
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func wipe() {
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
