/* Save file handling. localStorage where available, in-memory otherwise (some
   browsers block storage on file:// origins — the game still runs, it just
   won't survive a reload). */
(function (global) {
  'use strict';

  var KEY = 'idleDotShooter.save.v1';
  var memory = {};
  var usable = (function () {
    try {
      var probe = '__ids_probe__';
      global.localStorage.setItem(probe, '1');
      global.localStorage.removeItem(probe);
      return true;
    } catch (e) {
      return false;
    }
  })();

  function read(key) {
    if (usable) {
      try { return global.localStorage.getItem(key); } catch (e) { /* fall through */ }
    }
    return Object.prototype.hasOwnProperty.call(memory, key) ? memory[key] : null;
  }

  function write(key, value) {
    if (usable) {
      try { global.localStorage.setItem(key, value); return; } catch (e) { /* fall through */ }
    }
    memory[key] = value;
  }

  function remove(key) {
    if (usable) {
      try { global.localStorage.removeItem(key); } catch (e) { /* fall through */ }
    }
    delete memory[key];
  }

  function defaultStats() {
    return {
      dotsDestroyed: 0,
      shotsFired: 0,
      bulletsHit: 0,
      criticalHits: 0,
      orbsCollected: 0,
      orbsLost: 0,
      cashEarnedLifetime: 0,
      cashEarnedThisRun: 0,
      cashSpent: 0,
      biggestSingleHit: 0,
      biggestSinglePayout: 0,
      timeActive: 0,
      timeOffline: 0,
      sessionsPlayed: 0,
      upgradesPurchased: 0,
      abilitiesCast: 0,
      frenzyCasts: 0,
      dotRainCasts: 0,
      blackHoleCasts: 0,
      galaxyTravels: 0,
      highestGalaxyIndex: 0,
      rebirths: 0,
      starDustEarnedLifetime: 0,
      bestCombo: 0,
      goldenDotsPopped: 0,
      rarityKills: [0, 0, 0, 0, 0, 0],
      firstPlayed: Date.now()
    };
  }

  function defaultSettings() {
    return {
      haptics: true,
      sound: true,
      particles: true,
      damageNumbers: true,
      reducedMotion: false,
      confirmRebirth: true,
      buyQuantity: 1
    };
  }

  function defaultSave() {
    return {
      version: 1,
      playerName: 'Commander',
      cash: 0,
      gems: 0,
      starDust: 0,
      galaxyIndex: 0,
      unlockedGalaxyIndex: 0,
      upgradeLevels: {},
      starUpgradeLevels: {},
      abilities: {},
      stats: defaultStats(),
      settings: defaultSettings(),
      ownedShopItems: [],
      ownedCosmetics: [],
      equippedCosmetics: {},
      shopCashMultiplier: 1,
      shopDamageMultiplier: 1,
      shopDropMultiplier: 1,
      shopOfflineMultiplier: 1,
      autoCastUnlocked: false,
      autoCastEnabled: false,
      adsRemoved: false,
      isVIP: false,
      recentIncomePerSecond: 0,
      tutorialSeen: false,
      lastSaved: Date.now()
    };
  }

  /** Shallow-merges a decoded save over the defaults so older files still load
      after new fields are added. */
  function migrate(raw) {
    var base = defaultSave();
    if (!raw || typeof raw !== 'object') return base;

    Object.keys(base).forEach(function (key) {
      if (raw[key] === undefined || raw[key] === null) return;
      if (key === 'stats' || key === 'settings') return;
      base[key] = raw[key];
    });

    if (raw.stats && typeof raw.stats === 'object') {
      Object.keys(base.stats).forEach(function (key) {
        if (typeof raw.stats[key] === typeof base.stats[key] && raw.stats[key] !== null) {
          base.stats[key] = raw.stats[key];
        }
      });
      if (Array.isArray(raw.stats.rarityKills)) {
        for (var i = 0; i < base.stats.rarityKills.length; i++) {
          base.stats.rarityKills[i] = raw.stats.rarityKills[i] || 0;
        }
      }
    }

    if (raw.settings && typeof raw.settings === 'object') {
      Object.keys(base.settings).forEach(function (key) {
        if (raw.settings[key] !== undefined && raw.settings[key] !== null) {
          base.settings[key] = raw.settings[key];
        }
      });
    }

    return base;
  }

  global.SaveStore = {
    storageAvailable: usable,
    defaultSave: defaultSave,

    load: function () {
      var text = read(KEY);
      if (!text) return null;
      try {
        return migrate(JSON.parse(text));
      } catch (e) {
        return null;
      }
    },

    save: function (snapshot) {
      try {
        write(KEY, JSON.stringify(snapshot));
      } catch (e) { /* quota or serialisation problem — skip this write */ }
    },

    wipe: function () { remove(KEY); },

    readRaw: read,
    writeRaw: write
  };
})(window);
