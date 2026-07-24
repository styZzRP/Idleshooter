/* Offline stand-in for the online board.
   The shipping game talks to a backend for "most dots destroyed". There is no
   server behind this build, so rivals are generated once, persisted, and
   advanced against wall-clock time. Swap this object for one that fetches and
   the rest of the app is unchanged. */
(function (global) {
  'use strict';

  var KEY = 'idleDotShooter.leaderboard.v1';

  var HANDLES = [
    'voidrunner', 'pixelpop', 'dot_dealer', 'quasarQ', 'nova_kat', 'bitrot',
    'orbital_ed', 's0lstice', 'greyhat', 'mochi', 'turret_tim', 'lumen',
    'kilonova', 'zzzap', 'driftwood', 'parsec', 'hexline', 'auralis',
    'cindershot', 'boop', 'vantablack', 'gluon', 'static_', 'marrow',
    'sunder', 'ferrite', 'halcyon', 'pulsewave', 'onyx', 'rhea',
    'tessellate', 'vellum', 'quark_', 'moth', 'sable', 'helix',
    'eventide', 'cobalt', 'vermillion', 'prism', 'solace', 'aster',
    'nimbus', 'graviton', 'echo9', 'tundra', 'opal', 'kestrel',
    'fathom', 'ember_', 'reverie', 'carbon', 'lyra', 'zenith',
    'meridian', 'cascade', 'harrow', 'vireo', 'spindle', 'quiet'
  ];

  function between(min, max) { return min + Math.random() * (max - min); }

  function makeRivals() {
    var total = HANDLES.length;
    return HANDLES.map(function (name, index) {
      // A long-tailed spread: the top of the board is genuinely far away, the
      // bottom is catchable within an evening.
      var strength = Math.pow((total - index) / total, 3.2);
      return {
        id: 'rival.' + index,
        name: name,
        seedScore: 900 + strength * 4200000 * between(0.6, 1.6),
        perHour: 400 + strength * 90000 * between(0.5, 1.5),
        galaxyIndex: Math.min(Catalog.GALAXIES.length - 1,
                              Math.floor(strength * 46) + Math.floor(between(0, 4))),
        rebirths: Math.max(0, Math.floor(strength * 22) + Math.floor(between(-1, 3))),
        isVIP: Math.random() < 0.22,
        friend: index % 7 === 0
      };
    });
  }

  function Leaderboard() {
    var stored = null;
    var raw = global.SaveStore.readRaw(KEY);
    if (raw) {
      try { stored = JSON.parse(raw); } catch (e) { stored = null; }
    }
    if (!stored || !Array.isArray(stored.rivals) || !stored.rivals.length) {
      stored = { createdAt: Date.now(), rivals: makeRivals() };
      global.SaveStore.writeRaw(KEY, JSON.stringify(stored));
    }
    this.store = stored;
  }

  Leaderboard.prototype.board = function (scope, player) {
    var hours = Math.max(0, (Date.now() - this.store.createdAt) / 3600000);
    var entries = this.store.rivals
      .filter(function (rival) { return scope === 'global' || rival.friend; })
      .map(function (rival) {
        return {
          id: rival.id,
          name: rival.name,
          dotsDestroyed: rival.seedScore + rival.perHour * hours,
          galaxyIndex: rival.galaxyIndex,
          rebirths: rival.rebirths,
          isPlayer: false,
          isVIP: rival.isVIP
        };
      });

    entries.push(player);
    entries.sort(function (a, b) { return b.dotsDestroyed - a.dotsDestroyed; });
    return entries;
  };

  global.Leaderboard = Leaderboard;
})(window);
