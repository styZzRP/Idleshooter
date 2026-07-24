/* Boots the game: wires state, engine, renderer and screens together, runs the
   animation loop, and owns tab switching, saving and the welcome-back modal. */
(function (global) {
  'use strict';

  var K = global.UIKit;
  var P = global.Palette;
  var el = K.el, add = K.add, onTap = K.onTap;

  var TABS = [
    { id: 'field', title: 'Field', icon: '🎯', tint: 'cyan' },
    { id: 'upgrades', title: 'Upgrades', icon: '🔧', tint: 'amber' },
    { id: 'shop', title: 'Shop', icon: '🛒', tint: 'mint' },
    { id: 'galaxy', title: 'Galaxy', icon: '🌍', tint: 'violet' },
    { id: 'rebirth', title: 'Rebirth', icon: '🔄', tint: 'purple' },
    { id: 'more', title: 'More', icon: '📊', tint: 'slate' }
  ];

  var SAVE_INTERVAL = 15;
  var SYNC_INTERVAL = 0.1;

  var state, engine, renderer, leaderboard;
  var screens = {};
  var tabButtons = {};
  var activeTab = 'field';
  var lastTime = 0;
  var syncAccumulator = 0;
  var saveAccumulator = 0;

  var UI = {
    syncNow: function () {
      syncAccumulator = 0;
      var screen = screens[activeTab];
      if (screen) screen.sync();
      updateTabBadges();
    }
  };
  global.UI = UI;

  // ------------------------------------------------------------- tab bar

  function buildTabBar() {
    var bar = document.getElementById('tabbar');
    K.clear(bar);

    TABS.forEach(function (tab) {
      var button = el('button', 'tab');
      button.style.setProperty('--tab-tint', P.color(tab.tint));

      var iconWrap = el('span', 'tab-icon', tab.icon);
      var dot = el('span', 'tab-dot hidden');
      add(button, iconWrap, el('span', 'tab-label', tab.title), dot);

      onTap(button, function () { setTab(tab.id); });
      tabButtons[tab.id] = { root: button, dot: dot };
      add(bar, button);
    });
  }

  function setTab(id) {
    activeTab = id;
    TABS.forEach(function (tab) {
      var section = document.getElementById('screen-' + tab.id);
      section.classList.toggle('hidden', tab.id !== id);
      tabButtons[tab.id].root.classList.toggle('active', tab.id === id);
    });
    global.Feedback.select();
    UI.syncNow();
  }

  function updateTabBadges() {
    var showDot = state.rebirthUnlocked() && state.pendingStarDust() > 0;
    tabButtons.rebirth.dot.classList.toggle('hidden', !showDot);
  }

  // -------------------------------------------------------------- modals

  function showOfflineReport(report) {
    K.showModal(function (modal, close) {
      add(modal,
          el('div', 'modal-icon', '🌙'),
          el('h2', null, 'Welcome back'),
          el('p', null, 'Your turret kept working for ' + Fmt.duration(report.duration) + '.'));

      var figure = el('div', 'figure');
      add(figure,
          el('div', 'figure-value mono', Fmt.cash(report.cashEarned)),
          el('div', 'figure-sub mono', Fmt.cash(report.rate) + '/s while away'));
      add(modal, figure);

      if (report.capped) {
        var capped = el('p', null,
          'Offline earnings cap out at ' + Catalog.BALANCE.offlineCapHours + ' hours.');
        capped.style.color = P.color('amber');
        add(modal, capped);
      }

      add(modal, K.bigButton('COLLECT', 'mint', close));
    });
  }

  var TUTORIAL_STEPS = [
    ['🎯', 'It shoots itself',
     'The turret picks the nearest dot and fires on its own. You never have to tap to shoot.', 'red'],
    ['🛸', 'The drone collects',
     'Popped dots drop orbs. Your drone vacuums them up — upgrade its suction so none fade away.', 'cyan'],
    ['🔧', 'Upgrade everything',
     'Defence, Drone and Economy. Damage, fire rate, capacity, value, spawn rate, luck.', 'gold'],
    ['🌍', 'Travel onwards',
     'Save up to reach the next of 50 galaxies. Each one scales health and payouts, and adds a modifier.', 'violet'],
    ['🎁', 'The shop is free',
     'Every pack, boost and cosmetic costs nothing. Claim whatever you want, whenever you want.', 'mint']
  ];

  function showTutorial() {
    K.showModal(function (modal, close) {
      add(modal, el('h2', null, 'Idle Dot Shooter'));

      var steps = el('div', 'steps');
      TUTORIAL_STEPS.forEach(function (step) {
        var row = el('div', 'step');
        row.style.setProperty('--step-tint', P.color(step[3]));
        var body = el('div');
        add(body, el('div', 'step-title', step[1]), el('div', 'step-body', step[2]));
        add(row, el('div', 'step-icon', step[0]), body);
        add(steps, row);
      });
      add(modal, steps);

      add(modal, K.bigButton('START SHOOTING', 'cyan', function () {
        state.tutorialSeen = true;
        state.persist();
        close();
      }));
    });
  }

  // ---------------------------------------------------------------- loop

  function frame(now) {
    global.requestAnimationFrame(frame);

    if (!lastTime) { lastTime = now; return; }
    var dt = (now - lastTime) / 1000;
    lastTime = now;
    if (!(dt > 0)) return;
    // A backgrounded tab can hand back an enormous delta; offline earnings
    // cover that window instead.
    if (dt > 1) dt = 1;

    engine.update(dt);

    if (activeTab === 'field') renderer.draw();

    syncAccumulator += dt;
    if (syncAccumulator >= SYNC_INTERVAL) {
      syncAccumulator = 0;
      var screen = screens[activeTab];
      if (screen) screen.sync();
      updateTabBadges();
    }

    saveAccumulator += dt;
    if (saveAccumulator >= SAVE_INTERVAL) {
      saveAccumulator = 0;
      state.persist();
    }
  }

  // --------------------------------------------------------------- start

  function start() {
    var save = global.SaveStore.load() || global.SaveStore.defaultSave();
    state = new global.GameState(save);
    engine = new global.GameEngine(state);
    leaderboard = new global.Leaderboard();

    state.stats.sessionsPlayed++;
    state.applyOfflineProgress();

    renderer = new global.Renderer(document.getElementById('field'), engine, state);

    screens.field = global.Screens.field(state, engine);
    screens.upgrades = global.Screens.upgrades(state);
    screens.shop = global.Screens.shop(state);
    screens.galaxy = global.Screens.galaxy(state);
    screens.rebirth = global.Screens.rebirth(state);
    screens.more = global.Screens.more(state, leaderboard);

    Object.keys(screens).forEach(function (key) { screens[key].build(); });

    buildTabBar();
    setTab('field');
    renderer.resize();

    if (state.pendingOfflineReport) {
      var report = state.pendingOfflineReport;
      state.pendingOfflineReport = null;
      showOfflineReport(report);
    } else if (!state.tutorialSeen) {
      showTutorial();
    }

    global.addEventListener('resize', function () { renderer.resize(); });
    global.addEventListener('orientationchange', function () {
      setTimeout(function () { renderer.resize(); }, 200);
    });

    document.addEventListener('visibilitychange', function () {
      if (document.hidden) {
        state.persist();
      } else {
        state.applyOfflineProgress();
        lastTime = 0;
        if (state.pendingOfflineReport) {
          var pending = state.pendingOfflineReport;
          state.pendingOfflineReport = null;
          showOfflineReport(pending);
        }
        UI.syncNow();
      }
    });

    global.addEventListener('pagehide', function () { state.persist(); });
    global.addEventListener('beforeunload', function () { state.persist(); });

    // Audio needs a gesture before it will make a sound.
    ['pointerdown', 'keydown'].forEach(function (type) {
      global.addEventListener(type, function once() {
        global.Feedback.unlock();
        global.removeEventListener(type, once);
      });
    });

    global.requestAnimationFrame(frame);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})(window);
