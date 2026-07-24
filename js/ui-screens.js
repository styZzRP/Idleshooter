/* Every screen. Each one builds its DOM once and then only updates the parts
   that change, so a 10 Hz refresh never touches layout it doesn't need to. */
(function (global) {
  'use strict';

  var K = global.UIKit;
  var C = global.Catalog;
  var P = global.Palette;
  var el = K.el, add = K.add, clear = K.clear, onTap = K.onTap;

  var QUANTITIES = [
    { id: 1, title: 'x1' },
    { id: 10, title: 'x10' },
    { id: 25, title: 'x25' },
    { id: 0, title: 'MAX' }
  ];

  // ================================================================= FIELD

  function FieldScreen(state, engine) {
    var walletHost = document.getElementById('hud-wallet');
    var galaxyHost = document.getElementById('hud-galaxy');
    var flagsHost = document.getElementById('hud-flags');
    var comboHost = document.getElementById('hud-combo');
    var abilityHost = document.getElementById('ability-bar');

    var cash, gems, dust, dustPill;
    var galaxyIcon, galaxyText, galaxyMod;
    var comboCount, comboMult;
    var abilities = [];
    var vipBadge;

    function build() {
      clear(walletHost);
      cash = K.pill('💰', 'gold', true);
      gems = K.pill('💎', 'cyan', false);
      dust = K.pill('✨', 'violet', false);
      dustPill = dust.root;
      add(walletHost, cash.root, gems.root, dustPill);

      clear(galaxyHost);
      galaxyIcon = el('span', 'chip-icon', '🌙');
      galaxyText = el('span', 'chip-name', '');
      galaxyMod = el('span', 'chip-mod', '');
      add(galaxyHost, galaxyIcon, galaxyText, galaxyMod);

      clear(flagsHost);
      vipBadge = K.badge('VIP', 'gold');
      add(flagsHost, vipBadge);

      clear(comboHost);
      comboCount = el('span', null, '');
      comboMult = el('span', 'combo-mult mono', '');
      add(comboHost, el('span', null, '🔥'), comboCount, comboMult);

      clear(abilityHost);
      abilities = C.ABILITIES.map(function (def) {
        var button = el('button', 'ability locked');
        button.style.setProperty('--ab-tint', P.color(def.palette));
        var fill = el('div', 'ability-fill');
        var icon = el('span', 'ability-icon', def.icon);
        var label = el('span', 'ability-label', def.name.toUpperCase());
        add(button, fill, icon, label);
        onTap(button, function () {
          if (state.ability(def.id).unlocked) engine.cast(def.id);
        });
        add(abilityHost, button);
        return { def: def, root: button, fill: fill, label: label };
      });
    }

    function sync() {
      cash.value.textContent = Fmt.cash(state.cash);
      cash.caption.textContent = Fmt.cash(state.recentIncomePerSecond) + '/s';
      gems.value.textContent = Fmt.count(state.gems);
      dust.value.textContent = Fmt.count(state.starDust);
      dustPill.classList.toggle('hidden', state.starDust <= 0 && state.stats.rebirths === 0);

      var galaxy = state.galaxy();
      galaxyHost.style.setProperty('--chip-tint', P.color(galaxy.palette, 0.4));
      galaxyIcon.textContent = galaxy.modifier.icon;
      galaxyText.textContent = 'Galaxy ' + galaxy.number + ' · ' + galaxy.name;
      galaxyMod.textContent = galaxy.modifier.title;

      vipBadge.classList.toggle('hidden', !state.isVIP);

      if (state.combo > 1) {
        comboHost.classList.remove('hidden');
        comboCount.textContent = state.combo + ' combo';
        comboMult.textContent = Fmt.multiplier(state.comboMultiplier());
      } else {
        comboHost.classList.add('hidden');
      }

      abilities.forEach(function (entry) {
        var ability = state.ability(entry.def.id);
        var ready = state.abilityReady(entry.def.id);
        var active = ability.activeRemaining > 0;

        entry.root.classList.toggle('locked', !ability.unlocked);
        entry.root.classList.toggle('ready', ready);
        entry.root.classList.toggle('active', active);
        entry.root.disabled = !ready;

        if (!ability.unlocked) {
          entry.label.textContent = 'LOCKED';
        } else if (active) {
          entry.label.textContent = Fmt.cooldown(ability.activeRemaining);
        } else if (ability.cooldownRemaining > 0) {
          entry.label.textContent = Fmt.cooldown(ability.cooldownRemaining);
          var total = C.abilityCooldown(entry.def, ability.level, state.abilityCooldownReduction());
          var fraction = total > 0 ? Math.max(0, Math.min(1, ability.cooldownRemaining / total)) : 0;
          entry.fill.style.height = (fraction * 100) + '%';
        } else {
          entry.label.textContent = entry.def.name.toUpperCase();
          entry.fill.style.height = '0%';
        }
        if (active) entry.fill.style.height = '100%';
      });
    }

    return { build: build, sync: sync };
  }

  // ============================================================== UPGRADES

  function UpgradesScreen(state) {
    var host = document.getElementById('screen-upgrades');
    var chrome, rowsHost, noteEl, quantityHost;
    var category = 'defence';
    var rows = [];
    var abilityRows = [];
    var quantityButtons = {};

    function build() {
      chrome = K.scaffold(host, 'Upgrades', '🔧');

      var categories = C.CATEGORIES.map(function (cat) {
        return { id: cat.id, title: cat.title, icon: cat.icon };
      });
      var picker = K.segmented(categories, category, 'cyan', function (id) {
        category = id;
        buildRows();
        sync();
      });
      // Each category button carries its own accent.
      C.CATEGORIES.forEach(function (cat) {
        picker.buttons[cat.id].style.setProperty('--seg-tint', P.color(cat.accent));
      });

      var pickerRow = el('div', 'picker-row');
      noteEl = el('div', 'picker-note', '');
      quantityHost = el('div', 'quantity');
      QUANTITIES.forEach(function (quantity) {
        var button = el('button', 'qty', quantity.title);
        onTap(button, function () {
          state.settings.buyQuantity = quantity.id;
          state.touch();
          state.persist();
          sync();
        });
        quantityButtons[quantity.id] = button;
        add(quantityHost, button);
      });
      add(pickerRow, noteEl, quantityHost);

      rowsHost = el('div', 'stack');

      var abilitySection = el('div', 'stack');
      add(abilitySection, K.sectionHead('Abilities', 'Big moments, on a cooldown.', '✨', 'violet'));
      abilityRows = C.ABILITIES.map(function (def) {
        var row = buildAbilityRow(def);
        add(abilitySection, row.root);
        return row;
      });

      add(chrome.body, picker.root, pickerRow, rowsHost, abilitySection);
      buildRows();
    }

    function buildRows() {
      clear(rowsHost);
      rows = C.upgradesIn(category).map(function (def) {
        var row = buildRow(def);
        add(rowsHost, row.root);
        return row;
      });
      var cat = C.CATEGORIES.filter(function (c) { return c.id === category; })[0];
      noteEl.textContent = cat ? cat.blurb : '';
    }

    function buildRow(def) {
      var accent = C.CATEGORIES.filter(function (c) { return c.id === def.category; })[0].accent;

      var root = el('div', 'row');
      root.style.setProperty('--row-tint', P.color(accent));

      var main = el('div', 'row-main');
      var titleRow = el('div', 'row-title');
      var levelEl = el('span', 'row-level mono', 'Lv 0');
      var maxBadge = K.badge('MAX', 'gold');
      maxBadge.classList.add('hidden');
      add(titleRow, el('span', 'row-name', def.name), levelEl, maxBadge);

      var values = el('div', 'row-values mono');
      var currentEl = el('span', 'current', '');
      var arrow = el('span', 'arrow', '→');
      var nextEl = el('span', 'next', '');
      add(values, currentEl, arrow, nextEl);

      add(main, titleRow, el('div', 'row-blurb', def.blurb), values);

      var side = el('div', 'row-side');
      var buy = K.buyButton(accent, function () {
        if (state.purchase(def.id, state.settings.buyQuantity)) global.UI.syncNow();
      });
      var maxedTag = K.tag('MAXED', 'gold');
      maxedTag.classList.add('hidden');
      add(side, buy.root, maxedTag);

      add(root, el('div', 'row-icon', def.icon), main, side);

      return {
        def: def, root: root, levelEl: levelEl, maxBadge: maxBadge,
        currentEl: currentEl, arrow: arrow, nextEl: nextEl,
        buy: buy, maxedTag: maxedTag
      };
    }

    function buildAbilityRow(def) {
      var root = el('div', 'row');
      root.style.setProperty('--row-tint', P.color(def.palette));

      var main = el('div', 'row-main');
      var titleRow = el('div', 'row-title');
      var levelEl = el('span', 'row-level mono', '');
      add(titleRow, el('span', 'row-name', def.name), levelEl);

      var detail = el('div', 'row-values', '');
      add(main, titleRow, el('div', 'row-blurb', def.blurb), detail);

      var side = el('div', 'row-side');
      var buy = K.buyButton(def.palette, function () {
        var ability = state.ability(def.id);
        var done = ability.unlocked ? state.upgradeAbility(def.id) : state.unlockAbility(def.id);
        if (done) global.UI.syncNow();
      });
      var maxedTag = K.tag('MAXED', 'gold');
      maxedTag.classList.add('hidden');
      add(side, buy.root, maxedTag);

      add(root, el('div', 'row-icon', def.icon), main, side);
      return { def: def, root: root, levelEl: levelEl, detail: detail, buy: buy, maxedTag: maxedTag };
    }

    function sync() {
      chrome.syncWallet(state);

      Object.keys(quantityButtons).forEach(function (key) {
        quantityButtons[key].classList.toggle('active', Number(key) === state.settings.buyQuantity);
      });

      rows.forEach(function (row) {
        var def = row.def;
        var level = state.level(def.id);
        var maxed = C.upgradeMaxed(def, level);
        var quote = state.quote(def.id, state.settings.buyQuantity);

        row.levelEl.textContent = 'Lv ' + level;
        row.maxBadge.classList.toggle('hidden', !maxed);
        row.currentEl.textContent = Fmt.styled(def.style, C.upgradeValue(def, level));

        if (maxed) {
          row.arrow.classList.add('hidden');
          row.nextEl.classList.add('hidden');
          row.buy.root.classList.add('hidden');
          row.maxedTag.classList.remove('hidden');
        } else {
          row.arrow.classList.remove('hidden');
          row.nextEl.classList.remove('hidden');
          row.buy.root.classList.remove('hidden');
          row.maxedTag.classList.add('hidden');
          row.nextEl.textContent = Fmt.styled(def.style,
            C.upgradeValue(def, level + Math.max(1, quote.levels)));
          row.buy.title.textContent = Fmt.cash(quote.price);
          row.buy.sub.textContent = quote.levels > 1 ? '+' + quote.levels + ' levels' : '+1 level';
          row.buy.root.disabled = quote.levels <= 0 || quote.price > state.cash;
        }
      });

      abilityRows.forEach(function (row) {
        var def = row.def;
        var ability = state.ability(def.id);
        var available = state.abilityAvailable(def.id);

        row.levelEl.textContent = ability.unlocked ? 'Lv ' + ability.level : '';
        row.maxedTag.classList.add('hidden');
        row.buy.root.classList.remove('hidden');

        if (!ability.unlocked) {
          row.detail.textContent = available
            ? 'Not unlocked yet.'
            : 'Unlocks in Galaxy ' + (def.unlockGalaxy + 1);
          row.buy.title.textContent = available ? Fmt.cash(def.unlockCost) : 'LOCKED';
          row.buy.sub.textContent = available ? 'unlock' : '';
          row.buy.root.disabled = !available || state.cash < def.unlockCost;
        } else {
          var duration = C.abilityDuration(def, ability.level);
          var cooldown = C.abilityCooldown(def, ability.level, state.abilityCooldownReduction());
          row.detail.textContent = Fmt.duration(duration) + ' active · ' +
                                   Fmt.duration(cooldown) + ' cooldown';

          if (ability.level >= def.maxLevel) {
            row.buy.root.classList.add('hidden');
            row.maxedTag.classList.remove('hidden');
          } else {
            var price = C.abilityUpgradeCost(def, ability.level) * (1 - state.upgradeDiscount());
            row.buy.title.textContent = Fmt.cash(price);
            row.buy.sub.textContent = '+1 level';
            row.buy.root.disabled = state.cash < price;
          }
        }
      });
    }

    return { build: build, sync: sync };
  }

  // ================================================================== SHOP

  function ShopScreen(state) {
    var host = document.getElementById('screen-shop');
    var chrome, listHost;
    var section = 'featured';
    var cards = [];
    var cosmeticTiles = [];

    function build() {
      chrome = K.scaffold(host, 'Shop', '🛒');

      var banner = el('div', 'panel free-banner');
      add(banner, K.sectionHead(
        'Everything is free',
        'No purchases, no currency, no euros. Claim what you like, as often as you like.',
        '🎁', 'mint'));

      var picker = K.segmented(C.SHOP_SECTIONS, section, 'cyan', function (id) {
        section = id;
        buildList();
        sync();
      }, true);

      listHost = el('div', 'stack');
      add(chrome.body, banner, picker.root, listHost);
      buildList();
    }

    function buildList() {
      clear(listHost);
      cards = [];
      cosmeticTiles = [];

      if (section === 'cosmetics') {
        C.SLOTS.forEach(function (slot) {
          var group = el('div', 'stack');
          var head = K.sectionHead(slot.title, 'Equipped: ' + state.equipped(slot.id).name,
                                   slot.icon, 'cyan');
          var grid = el('div', 'cosmetic-grid');

          C.cosmeticsIn(slot.id).forEach(function (cosmetic) {
            var card = buildCosmetic(cosmetic);
            add(grid, card.root);
            cosmeticTiles.push(card);
          });

          add(group, head, grid);
          add(listHost, group);
          cosmeticTiles.push({ slot: slot, slotHeader: head.querySelector('.head-sub') });
        });
        return;
      }

      C.shopItemsIn(section).forEach(function (item) {
        var card = buildCard(item);
        add(listHost, card.root);
        cards.push(card);
      });
    }

    function buildCard(item) {
      var root = el('div', 'row');
      root.style.setProperty('--row-tint', P.color(item.palette));

      var main = el('div', 'row-main');
      var titleRow = el('div', 'row-title');
      add(titleRow, el('span', 'row-name', item.name));
      if (item.badge) add(titleRow, K.badge(item.badge, item.palette));

      add(main, titleRow,
          el('div', 'row-blurb', item.blurb),
          el('div', 'effects', C.effectsSummary(item)));

      var side = el('div', 'row-side');
      add(side, el('div', 'price-strike', item.listPrice));
      var buy = K.buyButton('mint', function () {
        if (state.claim(item)) global.UI.syncNow();
      });
      var ownedTag = K.tag('OWNED', 'mint');
      ownedTag.classList.add('hidden');
      add(side, buy.root, ownedTag);

      add(root, el('div', 'row-icon', item.icon), main, side);
      return { item: item, root: root, buy: buy, ownedTag: ownedTag };
    }

    function buildCosmetic(cosmetic) {
      var root = el('div', 'cosmetic');
      var head = el('div', 'cos-head');
      var swatch = el('div', 'swatch');
      swatch.style.setProperty('--swatch-1', P.color(cosmetic.primary));
      swatch.style.setProperty('--swatch-2', P.color(cosmetic.secondary));
      add(head, swatch, el('span', null, cosmetic.name));

      var action = el('div', 'cos-action');
      add(root, head, el('div', 'cos-blurb', cosmetic.blurb), action);

      return { cosmetic: cosmetic, root: root, action: action };
    }

    function syncCosmetic(entry) {
      var cosmetic = entry.cosmetic;
      var owned = state.ownsCosmetic(cosmetic);
      var equipped = state.equipped(cosmetic.slot).id === cosmetic.id;
      var shopItem = C.shopItem('cosmetic.' + cosmetic.id);
      var wanted = equipped ? 'equipped' : (owned ? 'equip' : 'claim');
      if (entry.mode === wanted) return;
      entry.mode = wanted;

      clear(entry.action);
      if (equipped) {
        add(entry.action, K.tag('EQUIPPED', 'mint'));
      } else if (owned) {
        var equipButton = K.tag('EQUIP', 'cyan');
        equipButton.style.cursor = 'pointer';
        onTap(equipButton, function () {
          state.equip(cosmetic);
          global.UI.syncNow();
        });
        add(entry.action, equipButton);
      } else if (shopItem) {
        var buy = K.buyButton('mint', function () {
          if (state.claim(shopItem)) global.UI.syncNow();
        });
        buy.root.style.width = '100%';
        buy.title.textContent = 'FREE';
        buy.sub.textContent = shopItem.listPrice;
        buy.sub.style.textDecoration = 'line-through';
        add(entry.action, buy.root);
      }
    }

    function sync() {
      chrome.syncWallet(state);

      cards.forEach(function (card) {
        var owned = state.isOwned(card.item);
        card.buy.root.classList.toggle('hidden', owned);
        card.ownedTag.classList.toggle('hidden', !owned);
        if (!owned) {
          card.buy.title.textContent = 'FREE';
          card.buy.sub.textContent = card.item.repeatable ? 'claim again' : 'claim';
        }
      });

      cosmeticTiles.forEach(function (entry) {
        if (entry.slot) {
          if (entry.slotHeader) {
            entry.slotHeader.textContent = 'Equipped: ' + state.equipped(entry.slot.id).name;
          }
        } else {
          syncCosmetic(entry);
        }
      });
    }

    return { build: build, sync: sync };
  }

  // ================================================================ GALAXY

  function GalaxyScreen(state) {
    var host = document.getElementById('screen-galaxy');
    var chrome, rows = [], current, furthest, travels, progress;

    function build() {
      chrome = K.scaffold(host, 'Galaxies', '🌍');

      var summary = el('div', 'panel stack');
      add(summary, K.sectionHead('Travel',
        'Save up, jump ahead. Each galaxy scales health and payouts.', '🚀', 'cyan'));

      var minis = el('div', 'mini-stats');
      current = K.mini('Current', 'cyan');
      furthest = K.mini('Furthest', 'mint');
      travels = K.mini('Travels', 'violet');
      add(minis, current.root, furthest.root, travels.root);

      progress = K.bar('cyan');
      add(summary, minis, progress.root);

      var list = el('div', 'stack');
      rows = C.GALAXIES.map(function (galaxy) {
        var row = buildRow(galaxy);
        add(list, row.root);
        return row;
      });

      add(chrome.body, summary, list);
    }

    function buildRow(galaxy) {
      var root = el('div', 'row');
      root.style.setProperty('--row-tint', P.color(galaxy.palette));

      var index = el('div', 'galaxy-index');
      add(index, el('div', 'gi-number mono', String(galaxy.number)),
                 el('div', 'gi-icon', galaxy.modifier.icon));

      var main = el('div', 'row-main');
      var titleRow = el('div', 'row-title');
      var hereBadge = K.badge('HERE', 'mint');
      hereBadge.classList.add('hidden');
      add(titleRow, el('span', 'row-name', galaxy.name), hereBadge);

      var tags = el('div', 'scale-tags');
      var health = el('span', 'mono', '');
      health.style.color = P.color('red');
      var value = el('span', 'mono', '');
      value.style.color = P.color('gold');
      health.textContent = '❤ ' + Fmt.multiplier(galaxy.healthMultiplier);
      value.textContent = '💰 ' + Fmt.multiplier(galaxy.valueMultiplier);
      add(tags, health, value);

      var modTitle = el('div', 'row-values', galaxy.modifier.title);
      modTitle.style.color = P.color(galaxy.palette);

      add(main, titleRow, modTitle, el('div', 'row-blurb', galaxy.modifier.detail), tags);

      var side = el('div', 'row-side');
      var buy = K.buyButton(galaxy.palette, function () {
        if (state.travel(galaxy.index)) global.UI.syncNow();
      });
      var stateTag = K.tag('CURRENT', 'mint');
      stateTag.classList.add('hidden');
      add(side, buy.root, stateTag);

      add(root, index, main, side);
      return { galaxy: galaxy, root: root, hereBadge: hereBadge, buy: buy, stateTag: stateTag };
    }

    function sync() {
      chrome.syncWallet(state);

      current.value.textContent = state.galaxy().number + '/' + C.GALAXIES.length;
      furthest.value.textContent = String(state.stats.highestGalaxyIndex + 1);
      travels.value.textContent = Fmt.count(state.stats.galaxyTravels);
      progress.fill.style.width =
        ((state.unlockedGalaxyIndex + 1) / C.GALAXIES.length * 100) + '%';

      rows.forEach(function (row) {
        var index = row.galaxy.index;
        var isCurrent = index === state.galaxyIndex;
        var unlocked = index <= state.unlockedGalaxyIndex;
        var isNext = index === state.unlockedGalaxyIndex + 1;
        var cost = state.travelCost(index);

        row.root.classList.toggle('dimmed', !unlocked && !isNext);
        row.hereBadge.classList.toggle('hidden', !isCurrent);

        if (isCurrent) {
          row.buy.root.classList.add('hidden');
          row.stateTag.classList.remove('hidden');
          row.stateTag.textContent = 'CURRENT';
        } else if (unlocked) {
          row.buy.root.classList.remove('hidden');
          row.stateTag.classList.add('hidden');
          row.buy.title.textContent = 'TRAVEL';
          row.buy.sub.textContent = 'free';
          row.buy.root.disabled = false;
        } else if (isNext) {
          row.buy.root.classList.remove('hidden');
          row.stateTag.classList.add('hidden');
          row.buy.title.textContent = Fmt.cash(cost);
          row.buy.sub.textContent = 'unlock';
          row.buy.root.disabled = state.cash < cost;
        } else {
          row.buy.root.classList.add('hidden');
          row.stateTag.classList.remove('hidden');
          row.stateTag.textContent = '🔒 ' + Fmt.cash(cost);
        }
      });
    }

    return { build: build, sync: sync };
  }

  // =============================================================== REBIRTH

  function RebirthScreen(state) {
    var host = document.getElementById('screen-rebirth');
    var chrome, panel, locked, dustNow, dustNext, rebirthCount, runNote, rebirthButton;
    var starRows = [];

    function build() {
      chrome = K.scaffold(host, 'Rebirth', '🔄');

      locked = K.lockedNotice('🔒', 'Rebirth locked',
        'Reach Galaxy ' + (C.BALANCE.rebirthUnlockIndex + 1) +
        ' to unlock Rebirth. Reset your run, bank Star Dust, and spend it on upgrades that never go away.');

      panel = el('div', 'panel stack');
      add(panel, K.sectionHead('Reset the run',
        'Trade this run\'s progress for permanent power.', '✨', 'violet'));

      var figures = el('div', 'mini-stats');
      dustNow = K.mini('Star Dust now', 'violet');
      dustNext = K.mini('On rebirth', 'gold');
      rebirthCount = K.mini('Rebirths', 'mint');
      [dustNow, dustNext, rebirthCount].forEach(function (figure) {
        figure.root.classList.add('tile');
      });
      add(figures, dustNow.root, dustNext.root, rebirthCount.root);

      runNote = el('div', 'row-blurb', '');
      rebirthButton = K.bigButton('REBIRTH', 'violet', function () {
        if (state.settings.confirmRebirth) {
          K.confirmModal('Rebirth?',
            'Your cash, upgrade levels, ability levels and galaxy progress reset. You keep Star Dust, ' +
            'permanent upgrades, cosmetics and everything claimed in the shop.',
            'Rebirth',
            function () { state.rebirth(); global.UI.syncNow(); });
        } else {
          state.rebirth();
          global.UI.syncNow();
        }
      });

      add(panel, figures, runNote, rebirthButton);

      var permanent = el('div', 'stack');
      add(permanent, K.sectionHead('Permanent upgrades',
        'Bought with Star Dust. These survive every reset.', '⭐', 'gold'));

      starRows = C.STAR_UPGRADES.map(function (def) {
        var row = buildStarRow(def);
        add(permanent, row.root);
        return row;
      });

      add(chrome.body, locked, panel, permanent);
    }

    function buildStarRow(def) {
      var root = el('div', 'row');
      root.style.setProperty('--row-tint', P.color('violet'));

      var main = el('div', 'row-main');
      var titleRow = el('div', 'row-title');
      var levelEl = el('span', 'row-level mono', '');
      add(titleRow, el('span', 'row-name', def.name), levelEl);

      var values = el('div', 'row-values mono');
      var currentEl = el('span', 'current', '');
      var arrow = el('span', 'arrow', '→');
      var nextEl = el('span', 'next', '');
      add(values, currentEl, arrow, nextEl);

      add(main, titleRow, el('div', 'row-blurb', def.blurb), values);

      var side = el('div', 'row-side');
      var buy = K.buyButton('violet', function () {
        if (state.purchaseStarUpgrade(def.id)) global.UI.syncNow();
      });
      var maxedTag = K.tag('MAXED', 'gold');
      maxedTag.classList.add('hidden');
      add(side, buy.root, maxedTag);

      add(root, el('div', 'row-icon', def.icon), main, side);
      return {
        def: def, root: root, levelEl: levelEl, currentEl: currentEl,
        arrow: arrow, nextEl: nextEl, buy: buy, maxedTag: maxedTag
      };
    }

    function sync() {
      chrome.syncWallet(state);

      var unlocked = state.rebirthUnlocked();
      locked.classList.toggle('hidden', unlocked);
      panel.classList.toggle('hidden', !unlocked);

      var payout = state.pendingStarDust();
      dustNow.value.textContent = Fmt.count(state.starDust);
      dustNext.value.textContent = '+' + Fmt.count(payout);
      rebirthCount.value.textContent = String(state.stats.rebirths);
      runNote.textContent = 'This run has earned ' + Fmt.cash(state.stats.cashEarnedThisRun) +
        '. Star Dust scales with that total and with how far you pushed.';

      rebirthButton.textContent = payout > 0
        ? 'REBIRTH FOR ' + Fmt.count(payout) + ' STAR DUST'
        : 'NOT ENOUGH PROGRESS YET';
      rebirthButton.disabled = payout <= 0;

      starRows.forEach(function (row) {
        var def = row.def;
        var level = state.starLevel(def.id);
        var maxed = level >= def.maxLevel;
        var price = C.starCost(def, level);

        row.levelEl.textContent = 'Lv ' + level + '/' + def.maxLevel;
        row.currentEl.textContent = Fmt.styled(def.style, C.starValue(def, level));

        if (maxed) {
          row.arrow.classList.add('hidden');
          row.nextEl.classList.add('hidden');
          row.buy.root.classList.add('hidden');
          row.maxedTag.classList.remove('hidden');
        } else {
          row.arrow.classList.remove('hidden');
          row.nextEl.classList.remove('hidden');
          row.buy.root.classList.remove('hidden');
          row.maxedTag.classList.add('hidden');
          row.nextEl.textContent = Fmt.styled(def.style, C.starValue(def, level + 1));
          row.buy.title.textContent = Fmt.count(price) + ' ✦';
          row.buy.sub.textContent = 'star dust';
          row.buy.root.disabled = state.starDust < price;
        }
      });
    }

    return { build: build, sync: sync };
  }

  // ================================================================== MORE

  function MoreScreen(state, leaderboard) {
    var host = document.getElementById('screen-more');
    var page = 'stats';
    var pageHost, chromeless;
    var stats = null, ranks = null, settings = null;

    var PAGES = [
      { id: 'stats', title: 'Command', icon: '📊' },
      { id: 'ranks', title: 'Ranks', icon: '🏆' },
      { id: 'settings', title: 'Settings', icon: '⚙️' }
    ];

    function build() {
      clear(host);

      var header = el('div', 'screen-header');
      var picker = K.segmented(PAGES, page, 'cyan', function (id) {
        page = id;
        showPage();
      });
      add(header, picker.root);

      pageHost = el('div', 'screen-body');
      add(host, header, pageHost);

      stats = CommandPage(state);
      ranks = RanksPage(state, leaderboard);
      settings = SettingsPage(state);

      showPage();
    }

    function showPage() {
      clear(pageHost);
      chromeless = page === 'stats' ? stats : (page === 'ranks' ? ranks : settings);
      chromeless.build(pageHost);
      chromeless.sync();
    }

    function sync() {
      if (chromeless) chromeless.sync();
    }

    return { build: build, sync: sync };
  }

  // ------------------------------------------------------- command centre

  function CommandPage(state) {
    var tiles = {}, lines = [], rarityBars = [];

    var TILES = [
      ['dps', 'DPS', 'red'],
      ['income', 'Cash/sec', 'gold'],
      ['fireRate', 'Fire rate', 'orange'],
      ['multishot', 'Multishot', 'amber'],
      ['crit', 'Crit', 'crimson'],
      ['critDamage', 'Crit dmg', 'red'],
      ['capacity', 'Capacity', 'cyan'],
      ['spawn', 'Spawn', 'teal'],
      ['luck', 'Luck', 'green'],
      ['drones', 'Drones', 'cyan'],
      ['suction', 'Suction', 'mint'],
      ['combo', 'Combo', 'violet']
    ];

    var SECTIONS = [
      ['Combat', [
        ['Dots destroyed', '🎯', 'red', function (s) { return Fmt.count(s.stats.dotsDestroyed); }],
        ['Shots fired', '⚡', 'orange', function (s) { return Fmt.count(s.stats.shotsFired); }],
        ['Hits landed', '💥', 'amber', function (s) { return Fmt.count(s.stats.bulletsHit); }],
        ['Accuracy', '✅', 'mint', function (s) {
          return Fmt.percent(s.stats.shotsFired > 0 ? Math.min(1, s.stats.bulletsHit / s.stats.shotsFired) : 0);
        }],
        ['Critical hits', '🔥', 'crimson', function (s) { return Fmt.count(s.stats.criticalHits); }],
        ['Biggest hit', '🔨', 'red', function (s) { return Fmt.number(s.stats.biggestSingleHit); }],
        ['Golden dots', '⭐', 'gold', function (s) { return Fmt.count(s.stats.goldenDotsPopped); }],
        ['Best combo', '🔥', 'orange', function (s) { return Fmt.count(s.stats.bestCombo); }]
      ]],
      ['Economy', [
        ['Cash earned (lifetime)', '💰', 'gold', function (s) { return Fmt.cash(s.stats.cashEarnedLifetime); }],
        ['Cash earned (this run)', '🔄', 'amber', function (s) { return Fmt.cash(s.stats.cashEarnedThisRun); }],
        ['Cash spent', '🛒', 'lime', function (s) { return Fmt.cash(s.stats.cashSpent); }],
        ['Biggest payout', '✨', 'gold', function (s) { return Fmt.cash(s.stats.biggestSinglePayout); }],
        ['Average per dot', '➗', 'green', function (s) {
          return Fmt.cash(s.stats.dotsDestroyed > 0 ? s.stats.cashEarnedLifetime / s.stats.dotsDestroyed : 0);
        }],
        ['Upgrades purchased', '🔧', 'cyan', function (s) { return Fmt.count(s.stats.upgradesPurchased); }]
      ]],
      ['Drone', [
        ['Orbs collected', '🟢', 'mint', function (s) { return Fmt.count(s.stats.orbsCollected); }],
        ['Orbs lost', '❌', 'slate', function (s) { return Fmt.count(s.stats.orbsLost); }],
        ['Collection rate', '🌀', 'teal', function (s) {
          var total = s.stats.orbsCollected + s.stats.orbsLost;
          return Fmt.percent(total > 0 ? s.stats.orbsCollected / total : 1);
        }]
      ]],
      ['Abilities', [
        ['Abilities cast', '✨', 'violet', function (s) { return Fmt.count(s.stats.abilitiesCast); }],
        ['Frenzy', '🔥', 'orange', function (s) { return Fmt.count(s.stats.frenzyCasts); }],
        ['Dot Rain', '🌧️', 'cyan', function (s) { return Fmt.count(s.stats.dotRainCasts); }],
        ['Black Hole', '🕳️', 'purple', function (s) { return Fmt.count(s.stats.blackHoleCasts); }]
      ]],
      ['Journey', [
        ['Galaxy travels', '🚀', 'cyan', function (s) { return Fmt.count(s.stats.galaxyTravels); }],
        ['Furthest galaxy', '🚩', 'mint', function (s) {
          return (s.stats.highestGalaxyIndex + 1) + ' · ' + C.galaxyAt(s.stats.highestGalaxyIndex).name;
        }],
        ['Rebirths', '🔄', 'violet', function (s) { return Fmt.count(s.stats.rebirths); }],
        ['Star Dust earned', '⭐', 'gold', function (s) { return Fmt.count(s.stats.starDustEarnedLifetime); }],
        ['Time active', '⏱️', 'silver', function (s) { return Fmt.duration(s.stats.timeActive); }],
        ['Time offline', '🌙', 'indigo', function (s) { return Fmt.duration(s.stats.timeOffline); }],
        ['Sessions', '📱', 'slate', function (s) { return Fmt.count(s.stats.sessionsPlayed); }],
        ['First played', '📅', 'slate', function (s) {
          return new Date(s.stats.firstPlayed).toLocaleDateString();
        }]
      ]]
    ];

    function build(hostEl) {
      tiles = {};
      lines = [];
      rarityBars = [];

      var live = el('div', 'panel stack');
      add(live, K.sectionHead('Live Output',
        'Everything your current build is doing right now.', '📈', 'mint'));
      var grid = el('div', 'tile-grid');
      TILES.forEach(function (spec) {
        var t = K.tile(spec[1], spec[2]);
        tiles[spec[0]] = t;
        add(grid, t.root);
      });
      add(live, grid);
      add(hostEl, live);

      SECTIONS.forEach(function (section) {
        var panel = el('div', 'panel');
        add(panel, K.sectionHead(section[0], '', '', null));
        section[1].forEach(function (spec) {
          var line = K.statLine(spec[0], spec[1], spec[2]);
          line.get = spec[3];
          add(panel, line.root);
          lines.push(line);
        });
        add(hostEl, panel);
      });

      var rarity = el('div', 'panel stack');
      add(rarity, K.sectionHead('Dots by rarity', 'Everything you have ever popped.', '⚪', 'pink'));
      C.RARITIES.forEach(function (r) {
        var block = el('div', 'stack-tight');
        var head = el('div', 'row-values');
        var name = el('span', null, r.name);
        name.style.color = P.color(r.palette);
        var count = el('span', 'mono', '0');
        count.style.marginLeft = 'auto';
        add(head, name, count);
        var progress = K.bar(r.palette);
        progress.root.style.height = '5px';
        add(block, head, progress.root);
        add(rarity, block);
        rarityBars.push({ rarity: r, count: count, bar: progress });
      });
      add(hostEl, rarity);
    }

    function sync() {
      var d = state.derived;
      tiles.dps.value.textContent = Fmt.number(d.dps);
      tiles.income.value.textContent = Fmt.cash(state.recentIncomePerSecond);
      tiles.fireRate.value.textContent = d.fireRate.toFixed(2) + '/s';
      tiles.multishot.value.textContent = String(d.multishot);
      tiles.crit.value.textContent = Fmt.percent(d.critChance);
      tiles.critDamage.value.textContent = Fmt.multiplier(d.critDamage);
      tiles.capacity.value.textContent = String(d.capacity);
      tiles.spawn.value.textContent = d.spawnRate.toFixed(2) + '/s';
      tiles.luck.value.textContent = Fmt.percent(d.luck);
      tiles.drones.value.textContent = String(d.droneCount);
      tiles.suction.value.textContent = d.droneSuction.toFixed(0);
      tiles.combo.value.textContent = Fmt.multiplier(state.comboMultiplier());

      lines.forEach(function (line) { line.value.textContent = line.get(state); });

      var total = 0;
      state.stats.rarityKills.forEach(function (value) { total += value; });
      total = Math.max(1, total);

      rarityBars.forEach(function (entry) {
        var kills = state.stats.rarityKills[entry.rarity.index] || 0;
        entry.count.textContent = Fmt.count(kills);
        entry.bar.fill.style.width = (kills / total * 100) + '%';
      });
    }

    return { build: build, sync: sync };
  }

  // ----------------------------------------------------------- leaderboard

  function RanksPage(state, leaderboard) {
    var scope = 'global';
    var listHost, headerSub, nameEl, statsEl;
    var lastBuilt = 0;

    function build(hostEl) {
      var panel = el('div', 'panel stack');
      var head = K.sectionHead('Most dots destroyed', '', '🏆', 'gold');
      headerSub = el('div', 'head-sub', '');
      head.querySelector('.head-title').parentNode.appendChild(headerSub);
      add(panel, head);

      var identity = el('div', 'row-title');
      var identityMain = el('div', 'row-main');
      nameEl = el('div', 'row-name', state.playerName);
      statsEl = el('div', 'row-blurb mono', '');
      add(identityMain, nameEl, statsEl);

      var rename = K.tag('Rename', 'cyan');
      rename.style.cursor = 'pointer';
      rename.style.minWidth = '86px';
      onTap(rename, function () {
        K.promptModal('Commander name', state.playerName, function (value) {
          var trimmed = (value || '').trim();
          state.playerName = trimmed ? trimmed.slice(0, 18) : 'Commander';
          state.persist();
          lastBuilt = 0;
          global.UI.syncNow();
        });
      });

      identity.style.width = '100%';
      add(identity, identityMain, rename);
      add(panel, identity);

      var picker = K.segmented(
        [{ id: 'global', title: 'Global' }, { id: 'friends', title: 'Friends' }],
        scope, 'gold',
        function (id) { scope = id; lastBuilt = 0; sync(); }
      );

      listHost = el('div', 'stack-tight');

      add(hostEl, panel, picker.root, listHost);
      add(hostEl, el('div', 'note',
        'Rivals in this build are generated locally and advance over time — there is no server behind them.'));
    }

    function sync() {
      var now = performance.now();
      var entries = leaderboard.board(scope, state.leaderboardEntry());
      var rank = 1;
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].isPlayer) { rank = i + 1; break; }
      }

      headerSub.textContent = 'You are #' + rank + ' of ' + entries.length + '.';
      nameEl.textContent = state.playerName;
      statsEl.textContent = Fmt.count(state.stats.dotsDestroyed) + ' dots · Galaxy ' +
                            (state.stats.highestGalaxyIndex + 1);

      // The order barely moves; rebuilding once a second is plenty.
      if (now - lastBuilt < 1000) return;
      lastBuilt = now;

      clear(listHost);
      entries.forEach(function (entry, index) {
        add(listHost, buildRow(index + 1, entry));
      });
    }

    function buildRow(rank, entry) {
      var root = el('div', 'lb-row' + (entry.isPlayer ? ' me' : ''));
      var rankEl = el('div', 'lb-rank mono', String(rank));
      if (rank === 1) rankEl.style.color = P.color('gold');
      else if (rank === 2) rankEl.style.color = P.color('silver');
      else if (rank === 3) rankEl.style.color = P.color('orange');

      var main = el('div', 'lb-main');
      var name = el('div', 'lb-name');
      var nameText = el('span', null, entry.name);
      if (entry.isPlayer) nameText.style.color = P.color('mint');
      add(name, nameText);
      if (entry.isVIP) add(name, K.badge('VIP', 'gold'));
      if (entry.isPlayer) add(name, K.badge('YOU', 'mint'));

      add(main, name, el('div', 'lb-sub mono',
        'Galaxy ' + (entry.galaxyIndex + 1) + ' · ' + entry.rebirths + ' rebirths'));

      add(root, rankEl, main, el('div', 'lb-score mono', Fmt.count(entry.dotsDestroyed)));
      return root;
    }

    return { build: build, sync: sync };
  }

  // --------------------------------------------------------------- settings

  function SettingsPage(state) {
    var switches = {};
    var autoCastRow, autoCastSwitch, autoCastNote, storageNote;

    function toggle(key, label, icon) {
      var control = K.toggleSwitch(state.settings[key], function (value) {
        state.settings[key] = value;
        state.applySettings();
        state.persist();
        state.touch();
      });
      switches[key] = control;
      return K.settingRow(label, icon, control);
    }

    function build(hostEl) {
      switches = {};

      var feel = el('div', 'panel');
      add(feel, K.sectionHead('Feel', '', '📳', 'cyan'),
          toggle('haptics', 'Vibration', '📳'),
          toggle('sound', 'Sound', '🔊'),
          toggle('particles', 'Particles', '✨'),
          toggle('damageNumbers', 'Damage numbers', '🔢'),
          toggle('reducedMotion', 'Reduced motion', '🧘'));

      var gameplay = el('div', 'panel');
      add(gameplay, K.sectionHead('Gameplay', '', '🎮', 'violet'),
          toggle('confirmRebirth', 'Confirm before rebirth', '⚠️'));

      autoCastSwitch = K.toggleSwitch(state.autoCastEnabled, function (value) {
        state.autoCastEnabled = value;
        state.persist();
        state.touch();
      });
      autoCastNote = el('span', 'set-note', 'Free in the shop');
      autoCastRow = el('div', 'setting');
      add(autoCastRow, el('span', 'set-icon', '🪄'),
                       el('span', 'set-label', 'Auto-cast abilities'),
                       autoCastNote, autoCastSwitch);
      add(gameplay, autoCastRow);

      var data = el('div', 'panel stack');
      add(data, K.sectionHead('Data', '', '💾', 'amber'),
          K.actionButton('Save now', '💾', 'mint', function () {
            state.persist();
            global.Feedback.success();
          }),
          K.actionButton('Erase all progress', '🗑️', 'red', function () {
            K.confirmModal('Wipe all progress?',
              'This deletes your save: cash, upgrades, galaxies, Star Dust, cosmetics and stats. ' +
              'It cannot be undone.',
              'Erase everything',
              function () { state.resetEverything(); global.UI.syncNow(); });
          }));

      storageNote = el('div', 'note', '');
      add(data, storageNote);

      var about = el('div', 'panel stack');
      add(about, K.sectionHead('About', '', 'ℹ️', 'slate'),
          el('div', 'row-blurb',
             'Idle Dot Shooter — an independent, offline rebuild that runs entirely in your browser. ' +
             'The turret fires itself, the drone collects, and every item in the shop costs nothing at all.'));

      add(hostEl, feel, gameplay, data, about);
    }

    function sync() {
      Object.keys(switches).forEach(function (key) {
        switches[key].classList.toggle('on', !!state.settings[key]);
      });
      autoCastSwitch.classList.toggle('hidden', !state.autoCastUnlocked);
      autoCastSwitch.classList.toggle('on', state.autoCastEnabled);
      autoCastNote.classList.toggle('hidden', state.autoCastUnlocked);

      storageNote.textContent = global.SaveStore.storageAvailable
        ? 'Progress is saved to this browser automatically.'
        : 'Storage is blocked here, so progress will not survive a reload. ' +
          'Serving the folder over http:// fixes it.';
    }

    return { build: build, sync: sync };
  }

  global.Screens = {
    field: FieldScreen,
    upgrades: UpgradesScreen,
    shop: ShopScreen,
    galaxy: GalaxyScreen,
    rebirth: RebirthScreen,
    more: MoreScreen
  };
})(window);
