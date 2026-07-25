/* All static game data: balance constants, rarities, upgrades, galaxies,
   abilities, permanent upgrades, cosmetics and the (entirely free) shop. */
(function (global) {
  'use strict';

  // ---------------------------------------------------------------- balance

  var BALANCE = {
    baseDotHealth: 6,
    baseDotValue: 1.7,
    maxDots: 320,
    maxBullets: 900,
    maxOrbs: 400,
    maxParticles: 260,
    maxLabels: 40,
    maxComboMultiplier: 6,
    comboStep: 0.012,
    offlineCapHours: 24,
    rebirthUnlockIndex: 9
  };

  // --------------------------------------------------------------- rarities

  var RARITIES = [
    { index: 0, name: 'Common',    value: 1,   health: 1,   radius: 10,   palette: 'slate' },
    { index: 1, name: 'Uncommon',  value: 2.6, health: 1.7, radius: 11.5, palette: 'green' },
    { index: 2, name: 'Rare',      value: 6.5, health: 2.8, radius: 13,   palette: 'cyan' },
    { index: 3, name: 'Epic',      value: 17,  health: 4.8, radius: 15,   palette: 'purple' },
    { index: 4, name: 'Legendary', value: 46,  health: 8.5, radius: 17,   palette: 'orange' },
    { index: 5, name: 'Cosmic',    value: 130, health: 16,  radius: 19.5, palette: 'pink' }
  ];

  /** Weights the spawn roll towards the top of the table as luck rises. */
  function rollRarity(luck) {
    var l = Math.max(0, luck);
    var cosmic = Math.min(0.05, l * 0.02);
    var legendary = Math.min(0.10, l * 0.07);
    var epic = Math.min(0.16, l * 0.18);
    var rare = Math.min(0.24, l * 0.45);
    var uncommon = Math.min(0.34, l * 1.3);

    var roll = Math.random();
    var floorValue = 0;

    floorValue += cosmic;
    if (roll < floorValue) return 5;
    floorValue += legendary;
    if (roll < floorValue) return 4;
    floorValue += epic;
    if (roll < floorValue) return 3;
    floorValue += rare;
    if (roll < floorValue) return 2;
    floorValue += uncommon;
    if (roll < floorValue) return 1;
    return 0;
  }

  /* Dot themes remap rarity colours; index matches the cosmetic's variant. */
  var DOT_THEMES = [
    ['slate', 'green', 'cyan', 'purple', 'orange', 'pink'],        // Classic
    ['cyan', 'mint', 'blue', 'violet', 'magenta', 'pink'],         // Neon Night
    ['slate', 'silver', 'white', 'silver', 'white', 'silver'],     // Monochrome
    ['pink', 'lime', 'amber', 'teal', 'violet', 'magenta'],        // Candy Shell
    ['ember', 'orange', 'amber', 'gold', 'crimson', 'red'],        // Molten
    ['teal', 'cyan', 'blue', 'indigo', 'mint', 'violet']           // Deep Sea
  ];

  var GOLDEN_RGB = [255, 214, 74];

  function dotRGB(rarityIndex, golden, themeVariant) {
    if (golden) return GOLDEN_RGB;
    var theme = DOT_THEMES[themeVariant] || DOT_THEMES[0];
    return global.Palette.rgb(theme[rarityIndex] || 'white');
  }

  // --------------------------------------------------------------- upgrades

  var CATEGORIES = [
    {
      id: 'defence', title: 'Defence', icon: '🎯', accent: 'red',
      blurb: 'Push fire rate and damage to bullet hell levels.'
    },
    {
      id: 'drone', title: 'Drone', icon: '🛸', accent: 'cyan',
      blurb: 'Speed, suction, agility and size — your drone vacuums up the earnings.'
    },
    {
      id: 'economy', title: 'Economy', icon: '💰', accent: 'gold',
      blurb: 'Stack capacity, value, spawn rate and luck.'
    }
  ];

  function up(id, category, name, blurb, icon, baseCost, growth, base, perLevel, maxLevel, style) {
    return {
      id: id, category: category, name: name, blurb: blurb, icon: icon,
      baseCost: baseCost, growth: growth, base: base, perLevel: perLevel,
      maxLevel: maxLevel, style: style
    };
  }

  var UPGRADES = [
    // Defence
    up('damage', 'defence', 'Damage',
       'Raw punch behind every round that leaves the barrel.', '⚡',
       15, 1.115, 5, 2.4, null, 'flat1'),
    up('fireRate', 'defence', 'Fire Rate',
       'Shots per second. Stack it until the barrel glows.', '🔥',
       25, 1.135, 1.4, 0.11, 400, 'rate2'),
    up('multishot', 'defence', 'Multishot',
       'Extra rounds per volley, fanned across the field.', '✳️',
       450, 1.62, 1, 1, 24, 'points'),
    up('critChance', 'defence', 'Crit Chance',
       'Odds that a round lands as a critical hit.', '💥',
       180, 1.27, 0.03, 0.007, 96, 'pct1'),
    up('critDamage', 'defence', 'Crit Damage',
       'How hard a critical hit lands when it does.', '🎯',
       220, 1.19, 2, 0.15, null, 'mult'),
    up('bulletSpeed', 'defence', 'Bullet Speed',
       'Rounds reach drifting targets sooner.', '🚀',
       60, 1.145, 420, 16, 120, 'points'),
    up('pierce', 'defence', 'Pierce',
       'Rounds punch through this many extra dots.', '➡️',
       1400, 1.78, 0, 1, 12, 'points'),
    up('explosive', 'defence', 'Explosive Rounds',
       'Kills detonate, splashing damage onto neighbours.', '💣',
       3200, 1.34, 0, 4.5, 60, 'points'),

    // Drone
    up('droneSpeed', 'drone', 'Drone Speed',
       'Top speed while chasing loose orbs.', '🏃',
       40, 1.125, 150, 11, 150, 'points'),
    up('droneSuction', 'drone', 'Suction',
       'Radius in which orbs get dragged towards the drone.', '🌀',
       55, 1.145, 46, 6, 150, 'points'),
    up('droneAgility', 'drone', 'Agility',
       'How sharply the drone can change heading.', '🔄',
       70, 1.155, 2.2, 0.32, 120, 'flat2'),
    up('droneSize', 'drone', 'Size',
       'A bigger hull sweeps up orbs on contact.', '⚪',
       90, 1.165, 10, 1.1, 90, 'flat1'),
    up('droneMagnet', 'drone', 'Magnet Power',
       'Force with which caught orbs are reeled in.', '🧲',
       320, 1.2, 90, 22, 120, 'points'),
    up('droneCount', 'drone', 'Drone Count',
       'Additional drones working the field with you.', '🛸',
       28000, 6.5, 1, 1, 5, 'points'),
    up('droneBonus', 'drone', 'Collector Bonus',
       'Extra cash on every orb the drone brings home.', '➕',
       500, 1.225, 0, 0.03, 200, 'pct0'),
    up('orbLifetime', 'drone', 'Orb Lifetime',
       'How long dropped orbs linger before fading out.', '⏳',
       160, 1.175, 6, 0.55, 80, 'seconds'),

    // Economy
    up('capacity', 'economy', 'Capacity',
       'Maximum number of dots drifting on the field.', '📦',
       30, 1.185, 12, 2, 114, 'points'),
    up('dotValue', 'economy', 'Dot Value',
       'Every popped dot is worth this much more.', '💵',
       20, 1.12, 1, 0.12, null, 'mult'),
    up('spawnRate', 'economy', 'Spawn Rate',
       'Fresh dots pushed into the field each second.', '♻️',
       35, 1.155, 1.1, 0.22, 200, 'rate2'),
    up('luck', 'economy', 'Luck',
       'Weights every spawn roll towards the rare tiers.', '🍀',
       140, 1.21, 0.02, 0.006, 130, 'pct1'),
    up('comboWindow', 'economy', 'Combo Window',
       'Seconds you have to keep a kill combo alive.', '⏱️',
       260, 1.215, 1.6, 0.12, 70, 'seconds'),
    up('idleIncome', 'economy', 'Idle Income',
       'Passive cash that keeps ticking, dots or no dots.', '♾️',
       6000, 1.46, 0, 0.9, null, 'rate1'),
    up('goldenDots', 'economy', 'Golden Dots',
       'Chance for a golden dot worth 25x the usual haul.', '⭐',
       9500, 1.43, 0, 0.004, 60, 'pct1'),
    up('offlineRate', 'economy', 'Offline Rate',
       'Share of your live income that accrues while away.', '🌙',
       4000, 1.4, 0.25, 0.05, 15, 'pct0')
  ];

  var UPGRADE_BY_ID = {};
  UPGRADES.forEach(function (def) { UPGRADE_BY_ID[def.id] = def; });

  /* Four upgrades (Damage, Crit Damage, Dot Value, Idle Income) have no cap, so
     "max everything" needs a defined stopping point for them. */
  var UNCAPPED_MAX_LEVEL = 250;

  function upgradeTopLevel(def) {
    return def.maxLevel === null ? UNCAPPED_MAX_LEVEL : def.maxLevel;
  }

  function upgradeValue(def, level) { return def.base + def.perLevel * level; }
  function upgradeMaxed(def, level) { return def.maxLevel !== null && level >= def.maxLevel; }
  function upgradeCost(def, level) { return def.baseCost * Math.pow(def.growth, level); }

  /** Geometric sum: what `count` levels from `level` would cost. */
  function upgradeCostRange(def, level, count) {
    if (count <= 0) return 0;
    var first = upgradeCost(def, level);
    if (def.growth === 1) return first * count;
    return first * (Math.pow(def.growth, count) - 1) / (def.growth - 1);
  }

  // --------------------------------------------------------------- galaxies

  var MODIFIERS = {
    calm: {
      title: 'Calm Space', icon: '🌙', detail: 'No modifiers. Just you and the void.'
    },
    dense: {
      title: 'Dense Field', icon: '⚫', detail: '+40% spawn rate, +15% dot health.',
      health: 1.15, spawn: 1.4
    },
    swift: {
      title: 'Solar Wind', icon: '💨', detail: 'Dots drift 70% faster, +25% value.',
      value: 1.25, drift: 1.7
    },
    armoured: {
      title: 'Armoured Shells', icon: '🛡️', detail: '+70% dot health, +60% dot value.',
      health: 1.7, value: 1.6
    },
    rich: {
      title: 'Rich Deposits', icon: '💰', detail: '+50% dot value.',
      value: 1.5
    },
    lucky: {
      title: 'Lucky Streak', icon: '🍀', detail: '+60% luck on every spawn roll.',
      luck: 0.6
    },
    volatile: {
      title: 'Volatile Matter', icon: '📈', detail: '-30% dot health, +60% spawn rate, -15% value.',
      health: 0.7, spawn: 1.6, value: 0.85
    },
    magnetic: {
      title: 'Magnetic Storm', icon: '🌀', detail: '+45% drone suction, +20% value.',
      suction: 1.45, value: 1.2
    },
    frenzied: {
      title: 'Overclocked', icon: '🔥', detail: '+25% fire rate, +10% dot health.',
      fireRate: 1.25, health: 1.1
    },
    gilded: {
      title: 'Gilded Belt', icon: '⭐', detail: '+6% golden dot chance.',
      golden: 0.06
    },
    crushing: {
      title: 'Crushing Gravity', icon: '⬇️', detail: '+130% dot health, +150% dot value.',
      health: 2.3, value: 2.5
    },
    nebula: {
      title: 'Nebula Drift', icon: '🌫️', detail: 'Dots wander unpredictably, +35% value.',
      value: 1.35, drift: 1.25, wander: 1
    }
  };

  function modifier(key) {
    var m = MODIFIERS[key] || MODIFIERS.calm;
    return {
      key: key,
      title: m.title,
      icon: m.icon,
      detail: m.detail,
      health: m.health || 1,
      value: m.value || 1,
      spawn: m.spawn || 1,
      drift: m.drift || 1,
      suction: m.suction || 1,
      fireRate: m.fireRate || 1,
      luck: m.luck || 0,
      golden: m.golden || 0,
      wander: m.wander || 0
    };
  }

  var MODIFIER_ORDER = [
    'calm', 'dense', 'rich', 'swift', 'lucky', 'armoured', 'magnetic', 'volatile',
    'gilded', 'frenzied', 'nebula', 'crushing'
  ];

  var GALAXY_NAMES = [
    'The Void', 'Ember Reach', 'Cobalt Drift', 'Halcyon Belt', 'Vermilion Rift',
    'Silent Expanse', 'Auric Cluster', 'Pale Meridian', 'Cinder Gate', 'Verdant Coil',
    'Obsidian Span', 'Lumen Hollow', 'Saffron Wake', 'Ashen Spiral', 'Tidal Crown',
    'Quartz Divide', 'Umbra Field', 'Solace Arc', 'Ferrite Chain', 'Glass Horizon',
    'Iron Requiem', 'Nova Threshold', 'Zephyr Bloom', 'Crimson Lattice', 'Mirror Deep',
    'Hollow Ascent', 'Starless March', 'Onyx Cascade', 'Radiant Fault', 'Sable Current',
    'Prism Verge', 'Echo Sanctum', 'Basalt Ring', 'Twilight Furrow', 'Aether Shoal',
    'Ivory Descent', 'Molten Chorus', 'Frost Meridian', 'Cerulean Maw', 'Ochre Passage',
    'Spectral Reef', "Titan's Ledger", 'Wandering Ash', 'Gilded Abyss', 'Storm Chalice',
    'Final Aurora', 'Null Cathedral', 'Eventide Crown', "Singularity's Edge", 'Origin'
  ];

  var GALAXIES = GALAXY_NAMES.map(function (name, index) {
    var mod = modifier(MODIFIER_ORDER[index % MODIFIER_ORDER.length]);
    return {
      index: index,
      number: index + 1,
      name: name,
      modifier: mod,
      healthMultiplier: Math.pow(1.4, index) * mod.health,
      valueMultiplier: Math.pow(1.8, index) * mod.value,
      travelCost: index === 0 ? 0 : 2500 * Math.pow(3, index),
      palette: global.Palette.galaxyRamp[index % global.Palette.galaxyRamp.length]
    };
  });

  function galaxyAt(index) {
    return GALAXIES[Math.min(Math.max(index, 0), GALAXIES.length - 1)];
  }

  // -------------------------------------------------------------- abilities

  var ABILITIES = [
    {
      id: 'frenzy', name: 'Frenzy', icon: '🔥', palette: 'orange',
      blurb: 'Unleashes rapid fire — a barrage of shots in the blink of an eye.',
      unlockCost: 2500, unlockGalaxy: 1,
      upgradeBaseCost: 3500, upgradeGrowth: 1.55, maxLevel: 40,
      baseDuration: 8, durationPerLevel: 0.4,
      baseCooldown: 90, cooldownPerLevel: 1.1, minCooldown: 25,
      basePotency: 5, potencyPerLevel: 0.45
    },
    {
      id: 'dotRain', name: 'Dot Rain', icon: '🌧️', palette: 'cyan',
      blurb: 'Showers the field with dots — clear them all for a windfall.',
      unlockCost: 40000, unlockGalaxy: 3,
      upgradeBaseCost: 55000, upgradeGrowth: 1.58, maxLevel: 40,
      baseDuration: 6, durationPerLevel: 0.3,
      baseCooldown: 150, cooldownPerLevel: 1.8, minCooldown: 45,
      basePotency: 40, potencyPerLevel: 6
    },
    {
      id: 'blackHole', name: 'Black Hole', icon: '🕳️', palette: 'purple',
      blurb: 'Drags every dot into the singularity and pays out the lot.',
      unlockCost: 750000, unlockGalaxy: 5,
      upgradeBaseCost: 900000, upgradeGrowth: 1.62, maxLevel: 40,
      baseDuration: 3.2, durationPerLevel: 0.1,
      baseCooldown: 240, cooldownPerLevel: 3.2, minCooldown: 70,
      basePotency: 2.5, potencyPerLevel: 0.35
    }
  ];

  var ABILITY_BY_ID = {};
  ABILITIES.forEach(function (def) { ABILITY_BY_ID[def.id] = def; });

  function abilityDuration(def, level) {
    return def.baseDuration + def.durationPerLevel * level;
  }

  function abilityCooldown(def, level, reduction) {
    var raw = def.baseCooldown - def.cooldownPerLevel * level;
    return Math.max(def.minCooldown, raw * Math.max(0.25, 1 - reduction));
  }

  function abilityPotency(def, level, power) {
    return (def.basePotency + def.potencyPerLevel * level) * power;
  }

  function abilityUpgradeCost(def, level) {
    return def.upgradeBaseCost * Math.pow(def.upgradeGrowth, level);
  }

  // ------------------------------------------------------- star (rebirth)

  function star(id, name, blurb, icon, baseCost, growth, perLevel, maxLevel, style) {
    return {
      id: id, name: name, blurb: blurb, icon: icon,
      baseCost: baseCost, growth: growth, perLevel: perLevel,
      maxLevel: maxLevel, style: style
    };
  }

  var STAR_UPGRADES = [
    star('cosmicDamage', 'Cosmic Damage',
         'Permanent bonus damage on every round you ever fire.', '⚡',
         2, 1.55, 0.12, 100, 'pct0'),
    star('cosmicValue', 'Cosmic Value',
         'Permanent bonus cash from every dot you pop.', '💰',
         2, 1.55, 0.12, 100, 'pct0'),
    star('cosmicFireRate', 'Cosmic Cadence',
         'Permanent bonus fire rate that survives every rebirth.', '🔥',
         4, 1.6, 0.05, 60, 'pct0'),
    star('cosmicLuck', 'Cosmic Luck',
         'Permanently weights spawn rolls towards rare tiers.', '🍀',
         5, 1.62, 0.06, 60, 'pct0'),
    star('startingCash', 'Head Start',
         'Cash handed to you the moment a new run begins.', '💵',
         3, 1.7, 1, 40, 'points'),
    star('abilityPower', 'Ability Power',
         'Frenzy, Dot Rain and Black Hole all hit harder.', '✨',
         6, 1.65, 0.08, 50, 'pct0'),
    star('abilityCooldown', 'Ability Recharge',
         'Shorter cooldowns between big moments.', '⏱️',
         8, 1.7, 0.03, 25, 'pct0'),
    star('stardustGain', 'Dust Affinity',
         'Every future rebirth yields more Star Dust.', '⭐',
         10, 1.8, 0.1, 50, 'pct0'),
    star('offlineBoost', 'Night Shift',
         'Your turret keeps a bigger share of its income while away.', '🌙',
         5, 1.6, 0.1, 40, 'pct0'),
    star('upgradeDiscount', 'Bulk Contracts',
         'Every cash upgrade in the game costs less.', '🏷️',
         12, 1.75, 0.02, 30, 'pct0'),
    star('startingGalaxy', 'Warp Memory',
         'Start each new run this many galaxies ahead.', '🧭',
         25, 2.2, 1, 20, 'points'),
    star('droneCore', 'Drone Core',
         'Extra drones that are already online at the start of a run.', '🛸',
         40, 3, 1, 4, 'points')
  ];

  var STAR_BY_ID = {};
  STAR_UPGRADES.forEach(function (def) { STAR_BY_ID[def.id] = def; });

  function starCost(def, level) { return Math.round(def.baseCost * Math.pow(def.growth, level)); }
  function starValue(def, level) { return def.perLevel * level; }

  /** Star Dust a rebirth would pay out right now. */
  function rebirthPayout(runEarnings, galaxyIndex, gainBonus) {
    if (galaxyIndex < BALANCE.rebirthUnlockIndex) return 0;
    var normalised = Math.max(0, runEarnings) / 1e9;
    if (normalised <= 0) return 0;
    var base = Math.pow(normalised, 0.42) * 6;
    var depth = 1 + (galaxyIndex - BALANCE.rebirthUnlockIndex + 1) * 0.18;
    return Math.floor(base * depth * (1 + gainBonus));
  }

  // -------------------------------------------------------------- cosmetics

  var SLOTS = [
    { id: 'turret', title: 'Turret', icon: '🔺', defaultKey: 'turret.standard' },
    { id: 'dots', title: 'Dot Theme', icon: '⚪', defaultKey: 'dots.classic' },
    { id: 'drone', title: 'Drone', icon: '🛸', defaultKey: 'drone.scout' },
    { id: 'background', title: 'Backdrop', icon: '✨', defaultKey: 'bg.void' },
    { id: 'trail', title: 'Bullet Trail', icon: '➖', defaultKey: 'trail.plain' }
  ];

  var SLOT_BY_ID = {};
  SLOTS.forEach(function (slot) { SLOT_BY_ID[slot.id] = slot; });

  function cos(id, slot, name, blurb, primary, secondary, variant) {
    return {
      id: id, slot: slot, name: name, blurb: blurb,
      primary: primary, secondary: secondary, variant: variant
    };
  }

  var COSMETICS = [
    // Turrets
    cos('turret.standard', 'turret', 'Standard Issue', 'The barrel you started with.', 'cyan', 'blue', 0),
    cos('turret.ember', 'turret', 'Ember Lance', 'Runs hot, always has.', 'ember', 'amber', 1),
    cos('turret.frost', 'turret', 'Frostbite', 'Cold-forged and razor thin.', 'mint', 'cyan', 2),
    cos('turret.void', 'turret', 'Void Caster', 'Bends the dark around the muzzle.', 'violet', 'void', 3),
    cos('turret.gilded', 'turret', 'Gilded Cannon', 'Solid gold. Recoil not included.', 'gold', 'amber', 4),
    cos('turret.bloom', 'turret', 'Bloom', 'Petals of plasma on every shot.', 'pink', 'magenta', 5),
    cos('turret.sentinel', 'turret', 'Sentinel', 'Heavy plating, heavier presence.', 'slate', 'silver', 6),
    cos('turret.prism', 'turret', 'Prism', 'Splits light into ordnance.', 'teal', 'indigo', 7),

    // Dot themes
    cos('dots.classic', 'dots', 'Classic', 'Rarity colours, exactly as intended.', 'white', 'slate', 0),
    cos('dots.neon', 'dots', 'Neon Night', 'Everything glows a little harder.', 'magenta', 'cyan', 1),
    cos('dots.mono', 'dots', 'Monochrome', 'For the purists.', 'silver', 'slate', 2),
    cos('dots.candy', 'dots', 'Candy Shell', 'Sweet, brittle, satisfying.', 'pink', 'lime', 3),
    cos('dots.molten', 'dots', 'Molten', 'Straight from the forge.', 'ember', 'gold', 4),
    cos('dots.deepsea', 'dots', 'Deep Sea', 'Bioluminescence in a vacuum.', 'teal', 'indigo', 5),

    // Drones
    cos('drone.scout', 'drone', 'Scout', 'Reliable little collector.', 'cyan', 'white', 0),
    cos('drone.wasp', 'drone', 'Wasp', 'Angry, fast, striped.', 'amber', 'slate', 1),
    cos('drone.orbital', 'drone', 'Orbital', 'Rings that never stop turning.', 'violet', 'indigo', 2),
    cos('drone.husk', 'drone', 'Husk', 'Salvaged from a dead galaxy.', 'slate', 'ember', 3),
    cos('drone.starling', 'drone', 'Starling', 'Leaves a trail of dust behind it.', 'gold', 'white', 4),

    // Backgrounds
    cos('bg.void', 'background', 'The Void', 'Plain, dark, endless.', 'void', 'slate', 0),
    cos('bg.nebula', 'background', 'Nebula', 'Violet clouds drifting past.', 'purple', 'indigo', 1),
    cos('bg.aurora', 'background', 'Aurora', 'Green light bleeding across the field.', 'green', 'teal', 2),
    cos('bg.ember', 'background', 'Ember Sky', 'The last warmth of a dying star.', 'ember', 'crimson', 3),
    cos('bg.grid', 'background', 'Grid', 'Clean lines for clean runs.', 'cyan', 'blue', 4),
    cos('bg.singularity', 'background', 'Singularity', 'Something enormous, just out of frame.', 'magenta', 'void', 5),

    // Trails
    cos('trail.plain', 'trail', 'Standard', 'A clean streak of light.', 'white', 'cyan', 0),
    cos('trail.plasma', 'trail', 'Plasma', 'Thick, hot, hard to miss.', 'ember', 'amber', 1),
    cos('trail.frost', 'trail', 'Frost', 'Leaves the air crystallised.', 'cyan', 'white', 2),
    cos('trail.void', 'trail', 'Void Streak', 'A tear in the backdrop.', 'violet', 'magenta', 3),
    cos('trail.gold', 'trail', 'Gold Rush', 'Every shot looks expensive.', 'gold', 'amber', 4)
  ];

  var COSMETIC_BY_ID = {};
  COSMETICS.forEach(function (item) { COSMETIC_BY_ID[item.id] = item; });

  function cosmeticsIn(slotId) {
    return COSMETICS.filter(function (item) { return item.slot === slotId; });
  }

  function cosmeticFor(slotId, key) {
    return COSMETIC_BY_ID[key] || COSMETIC_BY_ID[SLOT_BY_ID[slotId].defaultKey];
  }

  // ------------------------------------------------------------------ shop

  var SHOP_SECTIONS = [
    { id: 'featured', title: 'Featured', icon: '⭐' },
    { id: 'currency', title: 'Currency', icon: '💎' },
    { id: 'boosts', title: 'Boosts', icon: '⚡' },
    { id: 'cosmetics', title: 'Cosmetics', icon: '🎨' },
    { id: 'utilities', title: 'Utilities', icon: '⚙️' }
  ];

  /** Every item in this build costs nothing; `listPrice` is only ever shown
      struck through, so it is obvious what you are not paying. */
  function shop(id, section, name, blurb, icon, palette, listPrice, repeatable, badge, effects) {
    return {
      id: id, section: section, name: name, blurb: blurb, icon: icon,
      palette: palette, listPrice: listPrice, repeatable: repeatable,
      badge: badge, effects: effects
    };
  }

  var SHOP_ITEMS = [
    // Featured
    shop('boost.maxall', 'featured', 'Full Arsenal',
         'Every upgrade in Defence, Drone and Economy jumps straight to its highest level. ' +
         'The four uncapped ones go to level ' + UNCAPPED_MAX_LEVEL + '. Claim it again after a rebirth.',
         '🔝', 'crimson',
         '€49,99', true, 'MAX OUT',
         [{ t: 'maxUpgrades' }]),
    shop('pack.starter', 'featured', 'Starter Pack',
         'Everything a fresh turret needs to get rolling.', '📦', 'cyan',
         '€2,99', false, 'STARTER',
         [{ t: 'gems', v: 500 }, { t: 'flatCash', v: 25000 }, { t: 'cashMult', v: 1.5 }]),
    shop('pack.mega', 'featured', 'Mega Bundle',
         'The whole shop in one box, near enough.', '🎁', 'purple',
         '€24,99', false, 'BEST VALUE',
         [{ t: 'gems', v: 12000 }, { t: 'starDust', v: 50 }, { t: 'cashHours', v: 6 },
          { t: 'cashMult', v: 2 }, { t: 'damageMult', v: 2 }]),
    shop('pack.galaxy', 'featured', 'Galaxy Pack',
         'Jump-start the long haul across the void.', '🌌', 'indigo',
         '€9,99', false, null,
         [{ t: 'gems', v: 3500 }, { t: 'cashHours', v: 3 }, { t: 'abilities' }]),
    shop('pack.stardust', 'featured', 'Dust Cache',
         'A pouch of Star Dust straight into the vault.', '⭐', 'gold',
         '€14,99', true, null,
         [{ t: 'starDust', v: 40 }]),

    // Currency
    shop('gems.handful', 'currency', 'Handful of Gems', 'A modest pile.', '💎', 'cyan',
         '€0,99', true, null, [{ t: 'gems', v: 120 }]),
    shop('gems.pouch', 'currency', 'Pouch of Gems', 'Enough for a skin or two.', '👝', 'teal',
         '€4,99', true, null, [{ t: 'gems', v: 700 }]),
    shop('gems.chest', 'currency', 'Chest of Gems', "Now we're talking.", '🧰', 'violet',
         '€19,99', true, 'POPULAR', [{ t: 'gems', v: 3200 }]),
    shop('gems.vault', 'currency', 'Vault of Gems', 'Absurd quantities of the stuff.', '🏦', 'magenta',
         '€99,99', true, null, [{ t: 'gems', v: 20000 }]),
    shop('cash.small', 'currency', 'Cash Injection', 'One hour of production, instantly.', '💵', 'green',
         '€1,99', true, null, [{ t: 'cashHours', v: 1 }, { t: 'flatCash', v: 5000 }]),
    shop('cash.large', 'currency', 'Cash Windfall', 'Eight hours of production, instantly.', '💸', 'lime',
         '€9,99', true, null, [{ t: 'cashHours', v: 8 }, { t: 'flatCash', v: 50000 }]),

    // Boosts
    shop('boost.cash2x', 'boosts', 'Double Cash', 'Permanently doubles every payout.', '✖️', 'gold',
         '€6,99', false, null, [{ t: 'cashMult', v: 2 }]),
    shop('boost.damage2x', 'boosts', 'Double Damage', 'Permanently doubles turret damage.', '⚡', 'red',
         '€6,99', false, null, [{ t: 'damageMult', v: 2 }]),
    shop('boost.drops', 'boosts', 'Rich Orbs',
         'Every orb the drone collects is worth half again as much.', '🔶', 'amber',
         '€4,99', false, null, [{ t: 'dropMult', v: 1.5 }]),
    shop('boost.offline', 'boosts', 'Offline Overdrive',
         'Quadruples what you earn while the tab is closed.', '🌙', 'indigo',
         '€7,99', false, null, [{ t: 'offlineMult', v: 4 }]),
    shop('boost.abilities', 'boosts', 'Ability Unlock',
         'Frenzy, Dot Rain and Black Hole, right now.', '✨', 'orange',
         '€3,99', false, null, [{ t: 'abilities' }]),

    // Utilities
    shop('util.noads', 'utilities', 'Remove Ads',
         'There are no ads in this build. Claim it anyway.', '🚫', 'slate',
         '€3,99', false, null, [{ t: 'noAds' }]),
    shop('util.autocast', 'utilities', 'Auto Cast',
         'Abilities fire themselves the moment they come off cooldown.', '🪄', 'violet',
         '€5,99', false, null, [{ t: 'autoCast' }]),
    shop('util.vip', 'utilities', 'VIP Pass',
         'A permanent 25% cash bonus and a badge on the leaderboard.', '👑', 'gold',
         '€9,99 / maand', false, 'SUBSCRIPTION', [{ t: 'vip' }, { t: 'cashMult', v: 1.25 }])
  ];

  // Cosmetics become shop items automatically (defaults excluded — you own those).
  COSMETICS.forEach(function (item) {
    if (item.id === SLOT_BY_ID[item.slot].defaultKey) return;
    SHOP_ITEMS.push(shop('cosmetic.' + item.id, 'cosmetics', item.name, item.blurb,
                         SLOT_BY_ID[item.slot].icon, item.primary,
                         '€1,99', false, SLOT_BY_ID[item.slot].title.toUpperCase(),
                         [{ t: 'cosmetic', v: item.id }]));
  });

  var SHOP_BY_ID = {};
  SHOP_ITEMS.forEach(function (item) { SHOP_BY_ID[item.id] = item; });

  function shopItemsIn(sectionId) {
    return SHOP_ITEMS.filter(function (item) { return item.section === sectionId; });
  }

  function effectSummary(effect) {
    switch (effect.t) {
      case 'gems': return Fmt.count(effect.v) + ' gems';
      case 'starDust': return Fmt.count(effect.v) + ' Star Dust';
      case 'cashHours': return Fmt.duration(effect.v * 3600) + ' of production';
      case 'flatCash': return Fmt.cash(effect.v) + ' cash';
      case 'cashMult': return 'Permanent ' + Fmt.multiplier(effect.v) + ' cash';
      case 'damageMult': return 'Permanent ' + Fmt.multiplier(effect.v) + ' damage';
      case 'dropMult': return 'Permanent ' + Fmt.multiplier(effect.v) + ' orb drops';
      case 'offlineMult': return 'Offline earnings ' + Fmt.multiplier(effect.v);
      case 'noAds': return 'No ads, ever';
      case 'autoCast': return 'Abilities cast themselves';
      case 'vip': return 'VIP perks unlocked';
      case 'abilities': return 'All abilities unlocked';
      case 'maxUpgrades': return 'Every upgrade to max level';
      case 'cosmetic': {
        var c = COSMETIC_BY_ID[effect.v];
        return c ? c.name + ' ' + SLOT_BY_ID[c.slot].title.toLowerCase() : 'Cosmetic';
      }
      default: return '';
    }
  }

  function effectsSummary(item) {
    return item.effects.map(effectSummary).join(' · ');
  }

  // ---------------------------------------------------------------- exports

  global.Catalog = {
    BALANCE: BALANCE,
    RARITIES: RARITIES,
    rollRarity: rollRarity,
    dotRGB: dotRGB,
    GOLDEN_RGB: GOLDEN_RGB,

    CATEGORIES: CATEGORIES,
    UPGRADES: UPGRADES,
    upgrade: function (id) { return UPGRADE_BY_ID[id]; },
    upgradesIn: function (category) {
      return UPGRADES.filter(function (d) { return d.category === category; });
    },
    UNCAPPED_MAX_LEVEL: UNCAPPED_MAX_LEVEL,
    upgradeTopLevel: upgradeTopLevel,
    upgradeValue: upgradeValue,
    upgradeMaxed: upgradeMaxed,
    upgradeCost: upgradeCost,
    upgradeCostRange: upgradeCostRange,

    GALAXIES: GALAXIES,
    galaxyAt: galaxyAt,

    ABILITIES: ABILITIES,
    ability: function (id) { return ABILITY_BY_ID[id]; },
    abilityDuration: abilityDuration,
    abilityCooldown: abilityCooldown,
    abilityPotency: abilityPotency,
    abilityUpgradeCost: abilityUpgradeCost,

    STAR_UPGRADES: STAR_UPGRADES,
    starUpgrade: function (id) { return STAR_BY_ID[id]; },
    starCost: starCost,
    starValue: starValue,
    rebirthPayout: rebirthPayout,

    SLOTS: SLOTS,
    slot: function (id) { return SLOT_BY_ID[id]; },
    COSMETICS: COSMETICS,
    cosmetic: function (id) { return COSMETIC_BY_ID[id]; },
    cosmeticsIn: cosmeticsIn,
    cosmeticFor: cosmeticFor,

    SHOP_SECTIONS: SHOP_SECTIONS,
    SHOP_ITEMS: SHOP_ITEMS,
    shopItem: function (id) { return SHOP_BY_ID[id]; },
    shopItemsIn: shopItemsIn,
    effectsSummary: effectsSummary
  };
})(window);
