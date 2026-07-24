/* Small DOM helpers and the reusable widgets every screen is built from. */
(function (global) {
  'use strict';

  var P = global.Palette;

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }

  function add(parent) {
    for (var i = 1; i < arguments.length; i++) {
      if (arguments[i]) parent.appendChild(arguments[i]);
    }
    return parent;
  }

  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
    return node;
  }

  function onTap(node, handler) {
    node.addEventListener('click', function (event) {
      event.preventDefault();
      global.Feedback.unlock();
      handler(event);
    });
    return node;
  }

  // ------------------------------------------------------------- widgets

  /** Wallet pill: icon + value, optionally with a caption underneath. */
  function pill(icon, palette, withCaption) {
    var root = el('div', 'pill');
    root.style.setProperty('--pill-tint', P.color(palette));

    var iconEl = el('span', 'pill-icon', icon);
    var body = el('span');
    var value = el('span', 'pill-value mono', '0');
    add(body, value);

    var caption = null;
    if (withCaption) {
      caption = el('span', 'pill-caption mono', '');
      add(body, caption);
    }

    add(root, iconEl, body);
    return { root: root, value: value, caption: caption };
  }

  function sectionHead(title, subtitle, icon, palette) {
    var root = el('div', 'section-head');
    if (palette) root.style.setProperty('--head-tint', P.color(palette));
    if (icon) add(root, el('div', 'head-icon', icon));

    var text = el('div');
    add(text, el('div', 'head-title', title));
    if (subtitle) add(text, el('div', 'head-sub', subtitle));
    add(root, text);
    return root;
  }

  function badge(text, palette) {
    var node = el('span', 'badge', text);
    node.style.setProperty('--badge-tint', P.color(palette));
    return node;
  }

  /** Two-line action button: big title with a small subtitle. */
  function buyButton(palette, handler) {
    var root = el('button', 'buy');
    root.style.setProperty('--buy-tint', P.color(palette));
    var title = el('span', 'buy-title mono', '');
    var sub = el('span', 'buy-sub', '');
    add(root, title, sub);
    onTap(root, handler);
    return { root: root, title: title, sub: sub };
  }

  function tag(text, palette) {
    var node = el('div', 'tag', text);
    node.style.setProperty('--tag-tint', P.color(palette));
    return node;
  }

  function bar(palette) {
    var root = el('div', 'bar');
    root.style.setProperty('--bar-tint', P.color(palette));
    var fill = el('i');
    add(root, fill);
    return { root: root, fill: fill };
  }

  function statLine(label, icon, palette) {
    var root = el('div', 'stat-line');
    root.style.setProperty('--stat-tint', P.color(palette));
    var value = el('span', 'stat-value mono', '');
    add(root, el('span', 'stat-icon', icon), el('span', 'stat-label', label), value);
    return { root: root, value: value };
  }

  function tile(label, palette) {
    var root = el('div', 'tile');
    root.style.setProperty('--tile-tint', P.color(palette));
    var value = el('div', 'tile-value mono', '');
    add(root, value, el('div', 'tile-label', label));
    return { root: root, value: value };
  }

  function mini(label, palette) {
    var root = el('div', 'mini');
    root.style.setProperty('--mini-tint', P.color(palette));
    var value = el('div', 'mini-value mono', '');
    add(root, value, el('div', 'mini-label', label));
    return { root: root, value: value };
  }

  /** Horizontal segmented control. `items` need `id` and `title` (+ optional icon). */
  function segmented(items, current, palette, onSelect, scroll) {
    var root = el('div', 'segmented' + (scroll ? ' scroll' : ''));
    var buttons = {};

    items.forEach(function (item) {
      var button = el('button', 'seg');
      button.style.setProperty('--seg-tint', P.color(palette));
      if (item.icon) add(button, el('span', 'seg-icon', item.icon));
      add(button, el('span', 'seg-label', item.title));
      if (item.id === current) button.classList.add('active');
      onTap(button, function () {
        Object.keys(buttons).forEach(function (key) {
          buttons[key].classList.toggle('active', key === item.id);
        });
        global.Feedback.select();
        onSelect(item.id);
      });
      buttons[item.id] = button;
      add(root, button);
    });

    return { root: root, buttons: buttons };
  }

  function toggleSwitch(isOn, handler) {
    var root = el('button', 'switch' + (isOn ? ' on' : ''));
    add(root, el('i'));
    onTap(root, function () {
      var next = !root.classList.contains('on');
      root.classList.toggle('on', next);
      handler(next);
    });
    return root;
  }

  function settingRow(label, icon, control) {
    var root = el('div', 'setting');
    add(root, el('span', 'set-icon', icon), el('span', 'set-label', label), control);
    return root;
  }

  function actionButton(label, icon, palette, handler) {
    var root = el('button', 'action-button');
    root.style.setProperty('--act-tint', P.color(palette));
    add(root, el('span', null, icon), el('span', null, label));
    onTap(root, handler);
    return root;
  }

  function bigButton(label, palette, handler) {
    var root = el('button', 'big-button', label);
    root.style.setProperty('--big-tint', P.color(palette));
    onTap(root, handler);
    return root;
  }

  function lockedNotice(icon, title, message) {
    var root = el('div', 'panel locked-notice');
    add(root,
        el('div', 'ln-icon', icon),
        el('div', 'ln-title', title),
        el('div', 'ln-message', message));
    return root;
  }

  /** Standard screen chrome: title, wallet strip, scrolling body. */
  function scaffold(host, title, icon) {
    clear(host);

    var header = el('div', 'screen-header');
    var titleRow = el('div', 'screen-title');
    add(titleRow, el('span', 'title-icon', icon), el('span', null, title));

    var wallet = el('div', 'wallet');
    var cash = pill('💰', 'gold', true);
    var gems = pill('💎', 'cyan', false);
    var dust = pill('✨', 'violet', false);
    add(wallet, cash.root, gems.root, dust.root);

    add(header, titleRow, wallet);

    var body = el('div', 'screen-body');
    add(host, header, body);

    return {
      body: body,
      syncWallet: function (state) {
        cash.value.textContent = Fmt.cash(state.cash);
        cash.caption.textContent = Fmt.cash(state.recentIncomePerSecond) + '/s';
        gems.value.textContent = Fmt.count(state.gems);
        dust.value.textContent = Fmt.count(state.starDust);
      }
    };
  }

  // -------------------------------------------------------------- modals

  var modalLayer = null;

  function layer() {
    if (!modalLayer) modalLayer = document.getElementById('modal-layer');
    return modalLayer;
  }

  function closeModal() {
    var host = layer();
    clear(host);
    host.classList.add('hidden');
  }

  function showModal(build) {
    var host = layer();
    clear(host);
    var modal = el('div', 'modal');
    build(modal, closeModal);
    add(host, modal);
    host.classList.remove('hidden');
  }

  /** Confirmation dialog with a destructive-looking confirm button. */
  function confirmModal(title, message, confirmLabel, onConfirm) {
    showModal(function (modal, close) {
      add(modal, el('h2', null, title), el('p', null, message));
      var actions = el('div', 'modal-actions');
      var cancel = el('button', 'ghost-button', 'Cancel');
      onTap(cancel, close);
      var confirm = el('button', 'danger-button', confirmLabel);
      onTap(confirm, function () { close(); onConfirm(); });
      add(actions, cancel, confirm);
      add(modal, actions);
    });
  }

  function promptModal(title, initial, onSave) {
    showModal(function (modal, close) {
      add(modal, el('h2', null, title));
      var input = el('input');
      input.type = 'text';
      input.value = initial;
      input.maxLength = 18;
      add(modal, input);

      var actions = el('div', 'modal-actions');
      var cancel = el('button', 'ghost-button', 'Cancel');
      onTap(cancel, close);
      var save = el('button', 'big-button', 'Save');
      save.style.setProperty('--big-tint', P.color('cyan'));
      onTap(save, function () { close(); onSave(input.value); });
      add(actions, cancel, save);
      add(modal, actions);

      setTimeout(function () { input.focus(); input.select(); }, 60);
    });
  }

  global.UIKit = {
    el: el,
    add: add,
    clear: clear,
    onTap: onTap,
    pill: pill,
    sectionHead: sectionHead,
    badge: badge,
    buyButton: buyButton,
    tag: tag,
    bar: bar,
    statLine: statLine,
    tile: tile,
    mini: mini,
    segmented: segmented,
    toggleSwitch: toggleSwitch,
    settingRow: settingRow,
    actionButton: actionButton,
    bigButton: bigButton,
    lockedNotice: lockedNotice,
    scaffold: scaffold,
    showModal: showModal,
    closeModal: closeModal,
    confirmModal: confirmModal,
    promptModal: promptModal
  };
})(window);
