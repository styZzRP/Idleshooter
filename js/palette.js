/* A small, fixed palette so every screen, dot tier and cosmetic pulls from the
   same set of colours. */
(function (global) {
  'use strict';

  var PALETTE = {
    red:     [255, 69, 79],
    crimson: [217, 28, 89],
    orange:  [255, 135, 51],
    amber:   [255, 184, 51],
    gold:    [255, 214, 74],
    lime:    [184, 237, 74],
    green:   [84, 227, 120],
    mint:    [102, 245, 194],
    teal:    [51, 204, 194],
    cyan:    [61, 209, 255],
    blue:    [74, 140, 255],
    indigo:  [115, 107, 255],
    violet:  [161, 102, 255],
    purple:  [194, 89, 250],
    magenta: [242, 84, 217],
    pink:    [255, 115, 173],
    slate:   [158, 173, 199],
    silver:  [209, 219, 235],
    white:   [250, 252, 255],
    ember:   [252, 102, 31],
    void:    [92, 77, 158]
  };

  var GALAXY_RAMP = [
    'slate', 'ember', 'cyan', 'mint', 'crimson', 'silver', 'gold', 'violet',
    'orange', 'green', 'indigo', 'purple', 'amber', 'red', 'teal', 'blue',
    'pink', 'magenta'
  ];

  function rgb(name) {
    return PALETTE[name] || PALETTE.white;
  }

  /** 'cyan' -> '#3dd1ff'; with alpha -> 'rgba(61,209,255,0.4)'. */
  function color(name, alpha) {
    var c = rgb(name);
    if (alpha === undefined || alpha >= 1) {
      return '#' + c.map(function (v) {
        var h = v.toString(16);
        return h.length < 2 ? '0' + h : h;
      }).join('');
    }
    return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + alpha + ')';
  }

  function rgbaFrom(triple, alpha) {
    return 'rgba(' + triple[0] + ',' + triple[1] + ',' + triple[2] + ',' + alpha + ')';
  }

  global.Palette = {
    map: PALETTE,
    galaxyRamp: GALAXY_RAMP,
    rgb: rgb,
    color: color,
    rgbaFrom: rgbaFrom
  };
})(window);
