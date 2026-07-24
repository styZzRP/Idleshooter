import Foundation
import SwiftUI

/// The player's account: wallet, upgrade levels, progression, shop unlocks and
/// settings. The simulation reads its numbers from `derived` and reports back
/// through `award(cash:)` / `registerKill()`.
///
/// Publishing is manual and throttled: the game loop marks the state dirty and
/// `publishIfNeeded()` flushes at UI rate rather than 60 times a second.
final class GameState: ObservableObject {

    // MARK: Wallet

    private(set) var cash: Double = 0
    private(set) var gems: Double = 0
    private(set) var starDust: Double = 0

    // MARK: Progression

    private(set) var galaxyIndex: Int = 0
    private(set) var unlockedGalaxyIndex: Int = 0

    private(set) var upgradeLevels: [UpgradeID: Int] = [:]
    private(set) var starUpgradeLevels: [StarUpgradeID: Int] = [:]
    private(set) var abilities: [AbilityID: AbilityState] = [:]

    var stats = GameStats()
    var settings = GameSettings() {
        didSet { applySettings() }
    }

    // MARK: Shop

    private(set) var ownedShopItems: Set<String> = []
    private(set) var ownedCosmetics: Set<String> = []
    private(set) var equippedCosmetics: [String: String] = [:]

    private(set) var shopCashMultiplier: Double = 1
    private(set) var shopDamageMultiplier: Double = 1
    private(set) var shopDropMultiplier: Double = 1
    private(set) var shopOfflineMultiplier: Double = 1
    private(set) var autoCastUnlocked = false
    var autoCastEnabled = false
    private(set) var adsRemoved = false
    private(set) var isVIP = false

    // MARK: Session

    var playerName: String = "Commander"
    private(set) var derived = DerivedStats()
    private(set) var combo: Int = 0
    private(set) var comboTimer: Double = 0
    var recentIncomePerSecond: Double = 0
    var tutorialSeen = false
    /// Bumped whenever the field should be wiped (travel, rebirth, hard reset).
    /// The engine watches it instead of being poked directly.
    private(set) var fieldResetToken = 0
    /// Set when a launch found meaningful offline progress, consumed by the UI.
    var pendingOfflineReport: OfflineReport?

    private var lastSaved = Date()
    private var dirty = false

    // MARK: Init

    init(save: SaveGame = SaveGame()) {
        apply(save)
        refreshDerived()
        applySettings()
    }

    private func apply(_ save: SaveGame) {
        playerName = save.playerName
        cash = save.cash
        gems = save.gems
        starDust = save.starDust
        galaxyIndex = min(save.galaxyIndex, GalaxyCatalog.count - 1)
        unlockedGalaxyIndex = min(max(save.unlockedGalaxyIndex, galaxyIndex), GalaxyCatalog.count - 1)

        upgradeLevels = [:]
        for (key, value) in save.upgradeLevels {
            if let id = UpgradeID(rawValue: key) { upgradeLevels[id] = value }
        }
        starUpgradeLevels = [:]
        for (key, value) in save.starUpgradeLevels {
            if let id = StarUpgradeID(rawValue: key) { starUpgradeLevels[id] = value }
        }
        abilities = [:]
        for (key, value) in save.abilities {
            if let id = AbilityID(rawValue: key) { abilities[id] = value }
        }
        for def in AbilityCatalog.all where abilities[def.id] == nil {
            abilities[def.id] = AbilityState()
        }

        stats = save.stats
        settings = save.settings
        ownedShopItems = Set(save.ownedShopItems)
        ownedCosmetics = Set(save.ownedCosmetics)
        equippedCosmetics = save.equippedCosmetics
        shopCashMultiplier = max(1, save.shopCashMultiplier)
        shopDamageMultiplier = max(1, save.shopDamageMultiplier)
        shopDropMultiplier = max(1, save.shopDropMultiplier)
        shopOfflineMultiplier = max(1, save.shopOfflineMultiplier)
        autoCastUnlocked = save.autoCastUnlocked
        autoCastEnabled = save.autoCastEnabled && save.autoCastUnlocked
        adsRemoved = save.adsRemoved
        isVIP = save.isVIP
        recentIncomePerSecond = save.recentIncomePerSecond
        tutorialSeen = save.tutorialSeen
        lastSaved = save.lastSaved
    }

    // MARK: Publishing

    func setNeedsRefresh() { dirty = true }

    func publishIfNeeded() {
        guard dirty else { return }
        dirty = false
        objectWillChange.send()
    }

    func publishNow() {
        dirty = false
        objectWillChange.send()
    }

    private func applySettings() {
        Feedback.shared.hapticsEnabled = settings.haptics
        Feedback.shared.soundEnabled = settings.sound
    }

    // MARK: Lookups

    var galaxy: Galaxy { GalaxyCatalog.galaxy(at: galaxyIndex) }

    func level(_ id: UpgradeID) -> Int { upgradeLevels[id] ?? 0 }

    func starLevel(_ id: StarUpgradeID) -> Int { starUpgradeLevels[id] ?? 0 }

    func ability(_ id: AbilityID) -> AbilityState { abilities[id] ?? AbilityState() }

    func setAbility(_ id: AbilityID, _ state: AbilityState) { abilities[id] = state }

    func equipped(_ slot: CosmeticSlot) -> Cosmetic {
        CosmeticCatalog.cosmetic(for: slot, key: equippedCosmetics[slot.rawValue] ?? slot.defaultKey)
    }

    var rebirthUnlocked: Bool {
        stats.highestGalaxyIndex >= GalaxyCatalog.rebirthUnlockIndex || stats.rebirths > 0
    }

    var pendingStarDust: Double {
        RebirthCatalog.payout(runEarnings: stats.cashEarnedThisRun,
                              galaxyIndex: galaxyIndex,
                              gainBonus: starValue(.stardustGain))
    }

    /// Total value of a Star Dust perk at its current level.
    func starValue(_ id: StarUpgradeID) -> Double {
        RebirthCatalog.def(id).value(at: starLevel(id))
    }

    var upgradeDiscount: Double {
        min(0.6, starValue(.upgradeDiscount))
    }

    var abilityPower: Double {
        1 + starValue(.abilityPower)
    }

    var abilityCooldownReduction: Double {
        min(0.75, starValue(.abilityCooldown))
    }

    var comboMultiplier: Double {
        min(GameBalance.maxComboMultiplier, 1 + Double(combo) * GameBalance.comboStep)
    }

    // MARK: Derived stats

    func refreshDerived() {
        var d = DerivedStats()
        let g = galaxy
        let mod = g.modifier

        func value(_ id: UpgradeID) -> Double {
            UpgradeCatalog.def(id).value(at: level(id))
        }

        // Turret
        d.damage = value(.damage) * (1 + starValue(.cosmicDamage)) * shopDamageMultiplier
        d.fireRate = value(.fireRate) * (1 + starValue(.cosmicFireRate)) * mod.fireRateScale
        d.multishot = max(1, Int(value(.multishot).rounded()))
        d.critChance = min(0.95, value(.critChance))
        d.critDamage = value(.critDamage)
        d.bulletSpeed = value(.bulletSpeed)
        d.pierce = max(0, Int(value(.pierce).rounded()))
        d.explosiveRadius = value(.explosive)

        // Drone
        d.droneSpeed = value(.droneSpeed)
        d.droneSuction = value(.droneSuction) * mod.suctionScale
        d.droneAgility = value(.droneAgility)
        d.droneSize = value(.droneSize)
        d.droneMagnet = value(.droneMagnet)
        d.droneCount = max(1, Int(value(.droneCount).rounded()) + Int(starValue(.droneCore).rounded()))
        d.droneBonus = value(.droneBonus)
        d.orbLifetime = value(.orbLifetime)

        // Economy
        d.capacity = min(GameBalance.maxDots, max(4, Int(value(.capacity).rounded())))
        d.valueMultiplier = value(.dotValue)
            * (1 + starValue(.cosmicValue))
            * shopCashMultiplier
        d.spawnRate = value(.spawnRate) * mod.spawnScale
        d.luck = (value(.luck) + starValue(.cosmicLuck)) * (1 + mod.luckBonus)
        d.comboWindow = value(.comboWindow)
        d.idleIncome = value(.idleIncome) * g.valueMultiplier * d.valueMultiplier
        d.goldenChance = min(0.6, value(.goldenDots) + mod.goldenBonus)
        d.offlineRate = min(2.5, value(.offlineRate) * (1 + starValue(.offlineBoost)) * shopOfflineMultiplier)

        // Galaxy scaling
        d.dotHealthScale = g.healthMultiplier
        d.dotValueScale = g.valueMultiplier
        d.driftScale = mod.driftScale
        d.wanderScale = mod.wanderScale

        derived = d
        setNeedsRefresh()
    }

    // MARK: Wallet operations

    func award(cash amount: Double) {
        guard amount > 0, amount.isFinite else { return }
        cash += amount
        stats.cashEarnedLifetime += amount
        stats.cashEarnedThisRun += amount
        stats.biggestSinglePayout = max(stats.biggestSinglePayout, amount)
        setNeedsRefresh()
    }

    func award(gems amount: Double) {
        guard amount > 0 else { return }
        gems += amount
        setNeedsRefresh()
    }

    func award(starDust amount: Double) {
        guard amount > 0 else { return }
        starDust += amount
        stats.starDustEarnedLifetime += amount
        setNeedsRefresh()
    }

    @discardableResult
    func spend(cash amount: Double) -> Bool {
        guard amount <= cash else { return false }
        cash -= amount
        stats.cashSpent += amount
        setNeedsRefresh()
        return true
    }

    // MARK: Combo

    func registerKill(rarity: Rarity, golden: Bool) {
        stats.recordKill(rarity: rarity)
        if golden { stats.goldenDotsPopped += 1 }
        combo += 1
        comboTimer = derived.comboWindow
        stats.bestCombo = max(stats.bestCombo, combo)
        setNeedsRefresh()
    }

    func tickCombo(_ dt: Double) {
        guard combo > 0 else { return }
        comboTimer -= dt
        if comboTimer <= 0 {
            combo = 0
            comboTimer = 0
            setNeedsRefresh()
        }
    }

    // MARK: Upgrades

    /// How many levels a purchase would buy and what it would cost.
    func quote(_ id: UpgradeID, quantity: BuyQuantity) -> (levels: Int, price: Double) {
        let def = UpgradeCatalog.def(id)
        let current = level(id)
        let remaining = def.maxLevel.map { max(0, $0 - current) } ?? Int.max
        guard remaining > 0 else { return (0, 0) }

        let discount = 1 - upgradeDiscount

        if let requested = quantity.count {
            let count = min(requested, remaining)
            return (count, def.rawCost(at: current, count: count) * discount)
        }

        // MAX: walk levels until the wallet runs out.
        var bought = 0
        var spent = 0.0
        var budget = cash
        while bought < remaining && bought < 5_000 {
            let next = def.rawCost(at: current + bought) * discount
            if next > budget { break }
            budget -= next
            spent += next
            bought += 1
        }
        if bought == 0 {
            // Nothing affordable — quote a single level so the UI can show the price.
            return (1, def.rawCost(at: current) * discount)
        }
        return (bought, spent)
    }

    @discardableResult
    func purchase(_ id: UpgradeID, quantity: BuyQuantity) -> Bool {
        let quote = quote(id, quantity: quantity)
        guard quote.levels > 0, quote.price <= cash else {
            Feedback.shared.play(.denied)
            return false
        }
        spend(cash: quote.price)
        upgradeLevels[id] = level(id) + quote.levels
        stats.upgradesPurchased += Double(quote.levels)
        refreshDerived()
        publishNow()
        Feedback.shared.tap(.light)
        Feedback.shared.play(.purchase)
        return true
    }

    func canAfford(_ id: UpgradeID, quantity: BuyQuantity) -> Bool {
        let quote = quote(id, quantity: quantity)
        return quote.levels > 0 && quote.price <= cash
    }

    // MARK: Abilities

    func abilityAvailableForPurchase(_ id: AbilityID) -> Bool {
        unlockedGalaxyIndex >= AbilityCatalog.def(id).unlockGalaxy
    }

    @discardableResult
    func unlockAbility(_ id: AbilityID) -> Bool {
        let def = AbilityCatalog.def(id)
        var abilityState = ability(id)
        guard !abilityState.unlocked, abilityAvailableForPurchase(id), cash >= def.unlockCost else {
            Feedback.shared.play(.denied)
            return false
        }
        spend(cash: def.unlockCost)
        abilityState.unlocked = true
        abilities[id] = abilityState
        publishNow()
        Feedback.shared.success()
        Feedback.shared.play(.purchase)
        return true
    }

    @discardableResult
    func upgradeAbility(_ id: AbilityID) -> Bool {
        let def = AbilityCatalog.def(id)
        var abilityState = ability(id)
        let price = def.upgradeCost(level: abilityState.level) * (1 - upgradeDiscount)
        guard abilityState.unlocked, !def.isMaxed(level: abilityState.level), cash >= price else {
            Feedback.shared.play(.denied)
            return false
        }
        spend(cash: price)
        abilityState.level += 1
        abilities[id] = abilityState
        publishNow()
        Feedback.shared.tap(.light)
        Feedback.shared.play(.purchase)
        return true
    }

    func unlockAllAbilities() {
        for def in AbilityCatalog.all {
            var abilityState = ability(def.id)
            abilityState.unlocked = true
            abilities[def.id] = abilityState
        }
        setNeedsRefresh()
    }

    // MARK: Galaxies

    func travelCost(to index: Int) -> Double {
        index <= unlockedGalaxyIndex ? 0 : GalaxyCatalog.galaxy(at: index).travelCost
    }

    func canTravel(to index: Int) -> Bool {
        guard index >= 0, index < GalaxyCatalog.count, index != galaxyIndex else { return false }
        if index <= unlockedGalaxyIndex { return true }
        // Galaxies unlock strictly in order.
        guard index == unlockedGalaxyIndex + 1 else { return false }
        return cash >= travelCost(to: index)
    }

    @discardableResult
    func travel(to index: Int) -> Bool {
        guard canTravel(to: index) else {
            Feedback.shared.play(.denied)
            return false
        }
        let price = travelCost(to: index)
        if price > 0 { spend(cash: price) }
        galaxyIndex = index
        unlockedGalaxyIndex = max(unlockedGalaxyIndex, index)
        stats.highestGalaxyIndex = max(stats.highestGalaxyIndex, index)
        stats.galaxyTravels += 1
        combo = 0
        comboTimer = 0
        fieldResetToken += 1
        refreshDerived()
        publishNow()
        Feedback.shared.success()
        Feedback.shared.play(.travel)
        return true
    }

    // MARK: Rebirth

    @discardableResult
    func rebirth() -> Bool {
        let payout = pendingStarDust
        guard rebirthUnlocked, payout > 0 else {
            Feedback.shared.play(.denied)
            return false
        }

        award(starDust: payout)
        stats.rebirths += 1
        stats.beginNewRun()

        let warp = min(GalaxyCatalog.count - 1, Int(starValue(.startingGalaxy).rounded()))
        galaxyIndex = warp
        unlockedGalaxyIndex = warp
        upgradeLevels.removeAll()
        for id in AbilityID.allCases {
            var abilityState = ability(id)
            abilityState.level = 0
            abilityState.cooldownRemaining = 0
            abilityState.activeRemaining = 0
            abilities[id] = abilityState
        }
        combo = 0
        comboTimer = 0
        recentIncomePerSecond = 0
        cash = startingCash
        fieldResetToken += 1

        refreshDerived()
        publishNow()
        Feedback.shared.success()
        Feedback.shared.play(.rebirth)
        return true
    }

    /// Cash granted by the Head Start perk at the beginning of a run.
    var startingCash: Double {
        let levels = starValue(.startingCash)
        guard levels > 0 else { return 0 }
        return 500 * pow(2.4, levels)
    }

    @discardableResult
    func purchaseStarUpgrade(_ id: StarUpgradeID) -> Bool {
        let def = RebirthCatalog.def(id)
        let current = starLevel(id)
        let price = def.cost(at: current)
        guard !def.isMaxed(at: current), starDust >= price else {
            Feedback.shared.play(.denied)
            return false
        }
        starDust -= price
        starUpgradeLevels[id] = current + 1
        refreshDerived()
        publishNow()
        Feedback.shared.tap(.medium)
        Feedback.shared.play(.purchase)
        return true
    }

    // MARK: Shop — every item is free in this build

    func isOwned(_ item: ShopItem) -> Bool {
        !item.repeatable && ownedShopItems.contains(item.id)
    }

    func canClaim(_ item: ShopItem) -> Bool {
        item.repeatable || !ownedShopItems.contains(item.id)
    }

    @discardableResult
    func claim(_ item: ShopItem) -> Bool {
        guard canClaim(item) else { return false }
        ownedShopItems.insert(item.id)
        for effect in item.effects { apply(effect) }
        refreshDerived()
        publishNow()
        Feedback.shared.success()
        Feedback.shared.play(.purchase)
        return true
    }

    private func apply(_ effect: ShopEffect) {
        switch effect {
        case .gems(let amount):
            award(gems: amount)
        case .starDust(let amount):
            award(starDust: amount)
        case .cashHours(let hours):
            let rate = max(recentIncomePerSecond, derived.estimatedIncomePerSecond)
            award(cash: rate * hours * 3600)
        case .flatCash(let amount):
            award(cash: amount)
        case .permanentCashMultiplier(let m):
            shopCashMultiplier *= m
        case .permanentDamageMultiplier(let m):
            shopDamageMultiplier *= m
        case .permanentDropMultiplier(let m):
            shopDropMultiplier *= m
        case .offlineMultiplier(let m):
            shopOfflineMultiplier = max(shopOfflineMultiplier, m)
        case .removeAds:
            adsRemoved = true
        case .autoCast:
            autoCastUnlocked = true
            autoCastEnabled = true
        case .vip:
            isVIP = true
        case .unlockAllAbilities:
            unlockAllAbilities()
        case .cosmetic(let key):
            ownedCosmetics.insert(key)
            if let cosmetic = CosmeticCatalog.cosmetic(key) {
                equippedCosmetics[cosmetic.slot.rawValue] = cosmetic.id
            }
        }
    }

    func owns(cosmetic: Cosmetic) -> Bool {
        cosmetic.id == cosmetic.slot.defaultKey || ownedCosmetics.contains(cosmetic.id)
    }

    @discardableResult
    func equip(_ cosmetic: Cosmetic) -> Bool {
        guard owns(cosmetic: cosmetic) else { return false }
        equippedCosmetics[cosmetic.slot.rawValue] = cosmetic.id
        publishNow()
        Feedback.shared.select()
        return true
    }

    // MARK: Offline progress

    struct OfflineReport {
        let duration: Double
        let cashEarned: Double
        let rate: Double
        let capped: Bool
    }

    func applyOfflineProgress(now: Date = Date()) {
        let elapsed = now.timeIntervalSince(lastSaved)
        guard elapsed > 60 else {
            lastSaved = now
            return
        }
        let cap = GameBalance.offlineCapHours * 3600
        let counted = min(elapsed, cap)
        let rate = max(recentIncomePerSecond, derived.estimatedIncomePerSecond)
        let earned = rate * counted * derived.offlineRate

        stats.timeOffline += elapsed
        lastSaved = now

        guard earned > 0 else { return }
        award(cash: earned)
        pendingOfflineReport = OfflineReport(duration: elapsed,
                                             cashEarned: earned,
                                             rate: rate * derived.offlineRate,
                                             capped: elapsed > cap)
        publishNow()
    }

    // MARK: Persistence

    func snapshot() -> SaveGame {
        var save = SaveGame()
        save.playerName = playerName
        save.cash = cash
        save.gems = gems
        save.starDust = starDust
        save.galaxyIndex = galaxyIndex
        save.unlockedGalaxyIndex = unlockedGalaxyIndex
        save.upgradeLevels = Dictionary(uniqueKeysWithValues: upgradeLevels.map { ($0.key.rawValue, $0.value) })
        save.starUpgradeLevels = Dictionary(uniqueKeysWithValues: starUpgradeLevels.map { ($0.key.rawValue, $0.value) })
        save.abilities = Dictionary(uniqueKeysWithValues: abilities.map { ($0.key.rawValue, $0.value) })
        save.stats = stats
        save.settings = settings
        save.ownedShopItems = Array(ownedShopItems)
        save.ownedCosmetics = Array(ownedCosmetics)
        save.equippedCosmetics = equippedCosmetics
        save.shopCashMultiplier = shopCashMultiplier
        save.shopDamageMultiplier = shopDamageMultiplier
        save.shopDropMultiplier = shopDropMultiplier
        save.shopOfflineMultiplier = shopOfflineMultiplier
        save.autoCastUnlocked = autoCastUnlocked
        save.autoCastEnabled = autoCastEnabled
        save.adsRemoved = adsRemoved
        save.isVIP = isVIP
        save.recentIncomePerSecond = recentIncomePerSecond
        save.tutorialSeen = tutorialSeen
        save.lastSaved = Date()
        return save
    }

    func persist() {
        lastSaved = Date()
        SaveStore.save(snapshot())
    }

    func resetEverything() {
        SaveStore.wipe()
        apply(SaveGame())
        stats = GameStats()
        fieldResetToken += 1
        refreshDerived()
        publishNow()
    }

    var leaderboardEntry: LeaderboardEntry {
        LeaderboardEntry(id: "player",
                         name: playerName,
                         dotsDestroyed: stats.dotsDestroyed,
                         galaxyIndex: max(galaxyIndex, stats.highestGalaxyIndex),
                         rebirths: stats.rebirths,
                         isPlayer: true,
                         isVIP: isVIP)
    }
}
