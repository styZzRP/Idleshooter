/* The player's account: wallet, upgrade levels, progression, shop unlocks and
   settings. The simulation reads its numbers from `derived` and reports back
   through `awardCash` / `registerKill`. */
(function (global) {
  'use strict';

  var C = global.Catalog;
  var B = C.BALANCE;

  function GameState(save) {
    this.apply(save || global.SaveStore.defaultSave());
    this.refreshDerived();
    this.applySettings();
  }

  GameState.prototype.apply = function (save) {
    this.playerName = save.playerName;
    this.cash = save.cash;
    this.gems = save.gems;
    this.starDust = save.starDust;

    this.galaxyIndex = Math.min(save.galaxyIndex, C.GALAXIES.length - 1);
    this.unlockedGalaxyIndex = Math.min(
      Math.max(save.unlockedGalaxyIndex, this.galaxyIndex),
      C.GALAXIES.length - 1
    );

    this.upgradeLevels = Object.assign({}, save.upgradeLevels);
    this.starUpgradeLevels = Object.assign({}, save.starUpgradeLevels);

    this.abilities = {};
    var saved = save.abilities || {};
    C.ABILITIES.forEach(function (def) {
      var entry = saved[def.id];
      this.abilities[def.id] = {
        unlocked: entry ? !!entry.unlocked : false,
        level: entry ? (entry.level || 0) : 0,
        cooldownRemaining: entry ? (entry.cooldownRemaining || 0) : 0,
        activeRemaining: entry ? (entry.activeRemaining || 0) : 0
      };
    }, this);

    this.stats = save.stats;
    this.settings = save.settings;

    this.ownedShopItems = {};
    (save.ownedShopItems || []).forEach(function (id) { this.ownedShopItems[id] = true; }, this);
    this.ownedCosmetics = {};
    (save.ownedCosmetics || []).forEach(function (id) { this.ownedCosmetics[id] = true; }, this);
    this.equippedCosmetics = Object.assign({}, save.equippedCosmetics);

    this.shopCashMultiplier = Math.max(1, save.shopCashMultiplier);
    this.shopDamageMultiplier = Math.max(1, save.shopDamageMultiplier);
    this.shopDropMultiplier = Math.max(1, save.shopDropMultiplier);
    this.shopOfflineMultiplier = Math.max(1, save.shopOfflineMultiplier);
    this.autoCastUnlocked = !!save.autoCastUnlocked;
    this.autoCastEnabled = !!save.autoCastEnabled && this.autoCastUnlocked;
    this.adsRemoved = !!save.adsRemoved;
    this.isVIP = !!save.isVIP;

    this.recentIncomePerSecond = save.recentIncomePerSecond || 0;
    this.tutorialSeen = !!save.tutorialSeen;
    this.lastSaved = save.lastSaved || Date.now();

    this.combo = 0;
    this.comboTimer = 0;
    this.fieldResetToken = 0;
    this.pendingOfflineReport = null;
    /** Bumped on any change the UI should redraw for. */
    this.revision = 0;
    this.derived = this.derived || {};
  };

  GameState.prototype.touch = function () { this.revision++; };

  GameState.prototype.applySettings = function () {
    global.Feedback.hapticsEnabled = this.settings.haptics;
    global.Feedback.soundEnabled = this.settings.sound;
  };

  // ------------------------------------------------------------- lookups

  GameState.prototype.galaxy = function () { return C.galaxyAt(this.galaxyIndex); };

  GameState.prototype.level = function (id) { return this.upgradeLevels[id] || 0; };

  GameState.prototype.starLevel = function (id) { return this.starUpgradeLevels[id] || 0; };

  GameState.prototype.ability = function (id) { return this.abilities[id]; };

  GameState.prototype.equipped = function (slotId) {
    return C.cosmeticFor(slotId, this.equippedCosmetics[slotId] || C.slot(slotId).defaultKey);
  };

  GameState.prototype.starValue = function (id) {
    return C.starValue(C.starUpgrade(id), this.starLevel(id));
  };

  GameState.prototype.upgradeDiscount = function () {
    return Math.min(0.6, this.starValue('upgradeDiscount'));
  };

  GameState.prototype.abilityPower = function () {
    return 1 + this.starValue('abilityPower');
  };

  GameState.prototype.abilityCooldownReduction = function () {
    return Math.min(0.75, this.starValue('abilityCooldown'));
  };

  GameState.prototype.comboMultiplier = function () {
    return Math.min(B.maxComboMultiplier, 1 + this.combo * B.comboStep);
  };

  GameState.prototype.rebirthUnlocked = function () {
    return this.stats.highestGalaxyIndex >= B.rebirthUnlockIndex || this.stats.rebirths > 0;
  };

  GameState.prototype.pendingStarDust = function () {
    return C.rebirthPayout(this.stats.cashEarnedThisRun, this.galaxyIndex,
                           this.starValue('stardustGain'));
  };

  GameState.prototype.startingCash = function () {
    var levels = this.starValue('startingCash');
    return levels > 0 ? 500 * Math.pow(2.4, levels) : 0;
  };

  // ------------------------------------------------------- derived stats

  GameState.prototype.refreshDerived = function () {
    var self = this;
    var g = this.galaxy();
    var mod = g.modifier;

    function value(id) { return C.upgradeValue(C.upgrade(id), self.level(id)); }

    var d = {};

    // Turret
    d.damage = value('damage') * (1 + this.starValue('cosmicDamage')) * this.shopDamageMultiplier;
    d.fireRate = value('fireRate') * (1 + this.starValue('cosmicFireRate')) * mod.fireRate;
    d.multishot = Math.max(1, Math.round(value('multishot')));
    d.critChance = Math.min(0.95, value('critChance'));
    d.critDamage = value('critDamage');
    d.bulletSpeed = value('bulletSpeed');
    d.pierce = Math.max(0, Math.round(value('pierce')));
    d.explosiveRadius = value('explosive');

    // Drone
    d.droneSpeed = value('droneSpeed');
    d.droneSuction = value('droneSuction') * mod.suction;
    d.droneAgility = value('droneAgility');
    d.droneSize = value('droneSize');
    d.droneMagnet = value('droneMagnet');
    d.droneCount = Math.max(1, Math.round(value('droneCount')) + Math.round(this.starValue('droneCore')));
    d.droneBonus = value('droneBonus');
    d.orbLifetime = value('orbLifetime');

    // Economy
    d.capacity = Math.min(B.maxDots, Math.max(4, Math.round(value('capacity'))));
    d.valueMultiplier = value('dotValue') * (1 + this.starValue('cosmicValue')) * this.shopCashMultiplier;
    d.spawnRate = value('spawnRate') * mod.spawn;
    d.luck = (value('luck') + this.starValue('cosmicLuck')) * (1 + mod.luck);
    d.comboWindow = value('comboWindow');
    d.idleIncome = value('idleIncome') * g.valueMultiplier * d.valueMultiplier;
    d.goldenChance = Math.min(0.6, value('goldenDots') + mod.golden);
    d.offlineRate = Math.min(2.5, value('offlineRate') *
                             (1 + this.starValue('offlineBoost')) * this.shopOfflineMultiplier);

    // Galaxy scaling
    d.dotHealthScale = g.healthMultiplier;
    d.dotValueScale = g.valueMultiplier;
    d.driftScale = mod.drift;
    d.wanderScale = mod.wander;

    d.dps = d.damage * d.fireRate * d.multishot * (1 + d.critChance * (d.critDamage - 1));
    d.averageDotHealth = B.baseDotHealth * d.dotHealthScale * 1.45;
    d.averageDotValue = B.baseDotValue * d.dotValueScale * d.valueMultiplier * 1.9 *
                        (1 + d.goldenChance * 24);

    var killsByDamage = d.dps / Math.max(1, d.averageDotHealth);
    d.estimatedIncomePerSecond =
      Math.min(d.spawnRate, killsByDamage) * d.averageDotValue * (1 + d.droneBonus) + d.idleIncome;

    this.derived = d;
    this.touch();
  };

  // ------------------------------------------------------------- wallet

  GameState.prototype.awardCash = function (amount) {
    if (!(amount > 0) || !isFinite(amount)) return;
    this.cash += amount;
    this.stats.cashEarnedLifetime += amount;
    this.stats.cashEarnedThisRun += amount;
    if (amount > this.stats.biggestSinglePayout) this.stats.biggestSinglePayout = amount;
  };

  GameState.prototype.awardGems = function (amount) {
    if (amount > 0) { this.gems += amount; this.touch(); }
  };

  GameState.prototype.awardStarDust = function (amount) {
    if (amount > 0) {
      this.starDust += amount;
      this.stats.starDustEarnedLifetime += amount;
      this.touch();
    }
  };

  GameState.prototype.spend = function (amount) {
    if (amount > this.cash) return false;
    this.cash -= amount;
    this.stats.cashSpent += amount;
    return true;
  };

  // -------------------------------------------------------------- combo

  GameState.prototype.registerKill = function (rarityIndex, golden) {
    this.stats.dotsDestroyed++;
    if (this.stats.rarityKills[rarityIndex] !== undefined) {
      this.stats.rarityKills[rarityIndex]++;
    }
    if (golden) this.stats.goldenDotsPopped++;
    this.combo++;
    this.comboTimer = this.derived.comboWindow;
    if (this.combo > this.stats.bestCombo) this.stats.bestCombo = this.combo;
  };

  GameState.prototype.tickCombo = function (dt) {
    if (this.combo <= 0) return;
    this.comboTimer -= dt;
    if (this.comboTimer <= 0) {
      this.combo = 0;
      this.comboTimer = 0;
    }
  };

  // ----------------------------------------------------------- upgrades

  /** How many levels a purchase would buy and what it would cost. */
  GameState.prototype.quote = function (id, quantity) {
    var def = C.upgrade(id);
    var current = this.level(id);
    var remaining = def.maxLevel === null ? Infinity : Math.max(0, def.maxLevel - current);
    if (remaining <= 0) return { levels: 0, price: 0 };

    var discount = 1 - this.upgradeDiscount();

    if (quantity > 0) {
      var count = Math.min(quantity, remaining);
      return { levels: count, price: C.upgradeCostRange(def, current, count) * discount };
    }

    // MAX: walk levels until the wallet runs out.
    var bought = 0;
    var spent = 0;
    var budget = this.cash;
    while (bought < remaining && bought < 5000) {
      var next = C.upgradeCost(def, current + bought) * discount;
      if (next > budget) break;
      budget -= next;
      spent += next;
      bought++;
    }
    if (bought === 0) return { levels: 1, price: C.upgradeCost(def, current) * discount };
    return { levels: bought, price: spent };
  };

  GameState.prototype.purchase = function (id, quantity) {
    var quote = this.quote(id, quantity);
    if (quote.levels <= 0 || quote.price > this.cash) {
      global.Feedback.play('denied');
      return false;
    }
    this.spend(quote.price);
    this.upgradeLevels[id] = this.level(id) + quote.levels;
    this.stats.upgradesPurchased += quote.levels;
    this.refreshDerived();
    global.Feedback.tap('light');
    global.Feedback.play('purchase');
    return true;
  };

  // ---------------------------------------------------------- abilities

  GameState.prototype.abilityAvailable = function (id) {
    return this.unlockedGalaxyIndex >= C.ability(id).unlockGalaxy;
  };

  GameState.prototype.abilityReady = function (id) {
    var a = this.ability(id);
    return a.unlocked && a.cooldownRemaining <= 0 && a.activeRemaining <= 0;
  };

  GameState.prototype.unlockAbility = function (id) {
    var def = C.ability(id);
    var a = this.ability(id);
    if (a.unlocked || !this.abilityAvailable(id) || this.cash < def.unlockCost) {
      global.Feedback.play('denied');
      return false;
    }
    this.spend(def.unlockCost);
    a.unlocked = true;
    this.touch();
    global.Feedback.success();
    global.Feedback.play('purchase');
    return true;
  };

  GameState.prototype.upgradeAbility = function (id) {
    var def = C.ability(id);
    var a = this.ability(id);
    var price = C.abilityUpgradeCost(def, a.level) * (1 - this.upgradeDiscount());
    if (!a.unlocked || a.level >= def.maxLevel || this.cash < price) {
      global.Feedback.play('denied');
      return false;
    }
    this.spend(price);
    a.level++;
    this.touch();
    global.Feedback.tap('light');
    global.Feedback.play('purchase');
    return true;
  };

  GameState.prototype.unlockAllAbilities = function () {
    var self = this;
    C.ABILITIES.forEach(function (def) { self.abilities[def.id].unlocked = true; });
    this.touch();
  };

  // ----------------------------------------------------------- galaxies

  GameState.prototype.travelCost = function (index) {
    return index <= this.unlockedGalaxyIndex ? 0 : C.galaxyAt(index).travelCost;
  };

  GameState.prototype.canTravel = function (index) {
    if (index < 0 || index >= C.GALAXIES.length || index === this.galaxyIndex) return false;
    if (index <= this.unlockedGalaxyIndex) return true;
    if (index !== this.unlockedGalaxyIndex + 1) return false;
    return this.cash >= this.travelCost(index);
  };

  GameState.prototype.travel = function (index) {
    if (!this.canTravel(index)) {
      global.Feedback.play('denied');
      return false;
    }
    var price = this.travelCost(index);
    if (price > 0) this.spend(price);

    this.galaxyIndex = index;
    this.unlockedGalaxyIndex = Math.max(this.unlockedGalaxyIndex, index);
    this.stats.highestGalaxyIndex = Math.max(this.stats.highestGalaxyIndex, index);
    this.stats.galaxyTravels++;
    this.combo = 0;
    this.comboTimer = 0;
    this.fieldResetToken++;
    this.refreshDerived();
    global.Feedback.success();
    global.Feedback.play('travel');
    return true;
  };

  // ------------------------------------------------------------ rebirth

  GameState.prototype.rebirth = function () {
    var payout = this.pendingStarDust();
    if (!this.rebirthUnlocked() || payout <= 0) {
      global.Feedback.play('denied');
      return false;
    }

    this.awardStarDust(payout);
    this.stats.rebirths++;
    this.stats.cashEarnedThisRun = 0;

    var warp = Math.min(C.GALAXIES.length - 1, Math.round(this.starValue('startingGalaxy')));
    this.galaxyIndex = warp;
    this.unlockedGalaxyIndex = warp;
    this.upgradeLevels = {};

    var self = this;
    C.ABILITIES.forEach(function (def) {
      var a = self.abilities[def.id];
      a.level = 0;
      a.cooldownRemaining = 0;
      a.activeRemaining = 0;
    });

    this.combo = 0;
    this.comboTimer = 0;
    this.recentIncomePerSecond = 0;
    this.cash = this.startingCash();
    this.fieldResetToken++;

    this.refreshDerived();
    global.Feedback.success();
    global.Feedback.play('rebirth');
    return true;
  };

  GameState.prototype.purchaseStarUpgrade = function (id) {
    var def = C.starUpgrade(id);
    var current = this.starLevel(id);
    var price = C.starCost(def, current);
    if (current >= def.maxLevel || this.starDust < price) {
      global.Feedback.play('denied');
      return false;
    }
    this.starDust -= price;
    this.starUpgradeLevels[id] = current + 1;
    this.refreshDerived();
    global.Feedback.tap('medium');
    global.Feedback.play('purchase');
    return true;
  };

  // ----------------------------------- shop (every item costs nothing)

  GameState.prototype.isOwned = function (item) {
    return !item.repeatable && !!this.ownedShopItems[item.id];
  };

  GameState.prototype.canClaim = function (item) {
    return item.repeatable || !this.ownedShopItems[item.id];
  };

  GameState.prototype.claim = function (item) {
    if (!this.canClaim(item)) return false;
    this.ownedShopItems[item.id] = true;
    var self = this;
    item.effects.forEach(function (effect) { self.applyEffect(effect); });
    this.refreshDerived();
    global.Feedback.success();
    global.Feedback.play('purchase');
    return true;
  };

  GameState.prototype.applyEffect = function (effect) {
    switch (effect.t) {
      case 'gems':
        this.awardGems(effect.v);
        break;
      case 'starDust':
        this.awardStarDust(effect.v);
        break;
      case 'cashHours': {
        var rate = Math.max(this.recentIncomePerSecond, this.derived.estimatedIncomePerSecond);
        this.awardCash(rate * effect.v * 3600);
        break;
      }
      case 'flatCash':
        this.awardCash(effect.v);
        break;
      case 'cashMult':
        this.shopCashMultiplier *= effect.v;
        break;
      case 'damageMult':
        this.shopDamageMultiplier *= effect.v;
        break;
      case 'dropMult':
        this.shopDropMultiplier *= effect.v;
        break;
      case 'offlineMult':
        this.shopOfflineMultiplier = Math.max(this.shopOfflineMultiplier, effect.v);
        break;
      case 'noAds':
        this.adsRemoved = true;
        break;
      case 'autoCast':
        this.autoCastUnlocked = true;
        this.autoCastEnabled = true;
        break;
      case 'vip':
        this.isVIP = true;
        break;
      case 'abilities':
        this.unlockAllAbilities();
        break;
      case 'cosmetic': {
        this.ownedCosmetics[effect.v] = true;
        var cosmetic = C.cosmetic(effect.v);
        if (cosmetic) this.equippedCosmetics[cosmetic.slot] = cosmetic.id;
        break;
      }
      default:
        break;
    }
  };

  GameState.prototype.ownsCosmetic = function (cosmetic) {
    return cosmetic.id === C.slot(cosmetic.slot).defaultKey || !!this.ownedCosmetics[cosmetic.id];
  };

  GameState.prototype.equip = function (cosmetic) {
    if (!this.ownsCosmetic(cosmetic)) return false;
    this.equippedCosmetics[cosmetic.slot] = cosmetic.id;
    this.touch();
    global.Feedback.select();
    return true;
  };

  // --------------------------------------------------- offline progress

  GameState.prototype.applyOfflineProgress = function (now) {
    now = now || Date.now();
    var elapsed = (now - this.lastSaved) / 1000;
    if (!(elapsed > 60)) {
      this.lastSaved = now;
      return;
    }

    var cap = B.offlineCapHours * 3600;
    var counted = Math.min(elapsed, cap);
    var rate = Math.max(this.recentIncomePerSecond, this.derived.estimatedIncomePerSecond);
    var earned = rate * counted * this.derived.offlineRate;

    this.stats.timeOffline += elapsed;
    this.lastSaved = now;

    if (!(earned > 0)) return;
    this.awardCash(earned);
    this.pendingOfflineReport = {
      duration: elapsed,
      cashEarned: earned,
      rate: rate * this.derived.offlineRate,
      capped: elapsed > cap
    };
    this.touch();
  };

  // -------------------------------------------------------- persistence

  GameState.prototype.snapshot = function () {
    return {
      version: 1,
      playerName: this.playerName,
      cash: this.cash,
      gems: this.gems,
      starDust: this.starDust,
      galaxyIndex: this.galaxyIndex,
      unlockedGalaxyIndex: this.unlockedGalaxyIndex,
      upgradeLevels: this.upgradeLevels,
      starUpgradeLevels: this.starUpgradeLevels,
      abilities: this.abilities,
      stats: this.stats,
      settings: this.settings,
      ownedShopItems: Object.keys(this.ownedShopItems),
      ownedCosmetics: Object.keys(this.ownedCosmetics),
      equippedCosmetics: this.equippedCosmetics,
      shopCashMultiplier: this.shopCashMultiplier,
      shopDamageMultiplier: this.shopDamageMultiplier,
      shopDropMultiplier: this.shopDropMultiplier,
      shopOfflineMultiplier: this.shopOfflineMultiplier,
      autoCastUnlocked: this.autoCastUnlocked,
      autoCastEnabled: this.autoCastEnabled,
      adsRemoved: this.adsRemoved,
      isVIP: this.isVIP,
      recentIncomePerSecond: this.recentIncomePerSecond,
      tutorialSeen: this.tutorialSeen,
      lastSaved: Date.now()
    };
  };

  GameState.prototype.persist = function () {
    this.lastSaved = Date.now();
    global.SaveStore.save(this.snapshot());
  };

  GameState.prototype.resetEverything = function () {
    global.SaveStore.wipe();
    this.apply(global.SaveStore.defaultSave());
    this.fieldResetToken++;
    this.refreshDerived();
    this.applySettings();
  };

  GameState.prototype.leaderboardEntry = function () {
    return {
      id: 'player',
      name: this.playerName,
      dotsDestroyed: this.stats.dotsDestroyed,
      galaxyIndex: Math.max(this.galaxyIndex, this.stats.highestGalaxyIndex),
      rebirths: this.stats.rebirths,
      isPlayer: true,
      isVIP: this.isVIP
    };
  };

  global.GameState = GameState;
})(window);
