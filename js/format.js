/* Compact display of the very large numbers an idle economy produces. */
(function (global) {
  'use strict';

  var SUFFIXES = [
    '', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No',
    'Dc', 'UDc', 'DDc', 'TDc', 'QaDc', 'QiDc', 'SxDc', 'SpDc', 'OcDc', 'NoDc',
    'Vg', 'UVg', 'DVg', 'TVg', 'QaVg', 'QiVg', 'SxVg', 'SpVg', 'OcVg', 'NoVg', 'Tg'
  ];

  function trim(text) {
    if (text.indexOf('.') < 0) return text;
    return text.replace(/0+$/, '').replace(/\.$/, '');
  }

  function number(value) {
    if (!isFinite(value)) return '∞';
    var sign = value < 0 ? '-' : '';
    var v = Math.abs(value);

    if (v < 1) {
      if (v === 0) return '0';
      if (v < 0.01) return sign + '0';
      return sign + v.toFixed(2);
    }
    if (v < 1000) {
      if (v < 100) return sign + trim(v.toFixed(1));
      return sign + v.toFixed(0);
    }

    var tier = Math.floor(Math.log10(v) / 3);
    if (tier >= SUFFIXES.length) return sign + v.toExponential(2);

    var scaled = v / Math.pow(1000, tier);
    var text;
    if (scaled < 10) text = scaled.toFixed(2);
    else if (scaled < 100) text = scaled.toFixed(1);
    else text = scaled.toFixed(0);
    return sign + trim(text) + SUFFIXES[tier];
  }

  function cash(value) { return '$' + number(value); }

  function count(value) {
    if (Math.abs(value) < 1000) return Math.floor(value).toFixed(0);
    return number(value);
  }

  function multiplier(value) {
    return 'x' + (value < 100 ? value.toFixed(2) : number(value));
  }

  function percent(fraction, decimals) {
    return (fraction * 100).toFixed(decimals === undefined ? 1 : decimals) + '%';
  }

  function pad(value) { return value < 10 ? '0' + value : '' + value; }

  function duration(seconds) {
    if (!isFinite(seconds) || seconds <= 0) return '0s';
    var total = Math.floor(seconds);
    var days = Math.floor(total / 86400);
    var hours = Math.floor((total % 86400) / 3600);
    var minutes = Math.floor((total % 3600) / 60);
    var secs = total % 60;

    if (days > 0) return days + 'd ' + hours + 'h';
    if (hours > 0) return hours + 'h ' + pad(minutes) + 'm';
    if (minutes > 0) return minutes + 'm ' + pad(secs) + 's';
    if (seconds < 10) return seconds.toFixed(1) + 's';
    return secs + 's';
  }

  function cooldown(seconds) {
    var s = Math.max(0, seconds);
    if (s >= 60) return Math.floor(s / 60) + ':' + pad(Math.floor(s % 60));
    return s.toFixed(1);
  }

  /** Formats a stat value according to a catalog entry's display style. */
  function styled(style, value) {
    switch (style) {
      case 'flat1': return value.toFixed(1);
      case 'flat2': return value.toFixed(2);
      case 'rate2': return value.toFixed(2) + '/s';
      case 'rate1': return value.toFixed(1) + '/s';
      case 'pct0': return percent(value, 0);
      case 'pct1': return percent(value, 1);
      case 'mult': return multiplier(value);
      case 'seconds': return value.toFixed(1) + 's';
      case 'points':
      default: return Math.round(value).toString();
    }
  }

  global.Fmt = {
    number: number,
    cash: cash,
    count: count,
    multiplier: multiplier,
    percent: percent,
    duration: duration,
    cooldown: cooldown,
    styled: styled
  };
})(window);
