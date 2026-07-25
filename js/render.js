/* Canvas renderer. Draws the backdrop (cached to an offscreen canvas) plus
   every live entity, once per animation frame. */
(function (global) {
  'use strict';

  var C = global.Catalog;
  var P = global.Palette;

  var STARS = [];
  for (var i = 0; i < 90; i++) {
    STARS.push({
      x: Math.random(),
      y: Math.random(),
      radius: 0.6 + Math.random() * 1.3,
      alpha: 0.15 + Math.random() * 0.55
    });
  }

  function Renderer(canvas, engine, state) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.engine = engine;
    this.state = state;
    this.dpr = 1;
    this.width = 0;
    this.height = 0;

    this.backdrop = document.createElement('canvas');
    this.backdropKey = '';
  }

  /** Matches the canvas backing store to its CSS size and the device DPR. */
  Renderer.prototype.resize = function () {
    var rect = this.canvas.getBoundingClientRect();
    var width = Math.max(1, Math.round(rect.width));
    var height = Math.max(1, Math.round(rect.height));
    var dpr = Math.min(global.devicePixelRatio || 1, 2.5);

    if (width === this.width && height === this.height && dpr === this.dpr) return;

    this.width = width;
    this.height = height;
    this.dpr = dpr;
    this.canvas.width = Math.round(width * dpr);
    this.canvas.height = Math.round(height * dpr);
    this.engine.resize(width, height);
    this.backdropKey = '';
  };

  // ------------------------------------------------------------- backdrop

  Renderer.prototype.ensureBackdrop = function () {
    var cosmetic = this.state.equipped('background');
    var key = cosmetic.id + ':' + this.width + 'x' + this.height + ':' + this.dpr;
    if (key === this.backdropKey) return;
    this.backdropKey = key;

    var w = Math.round(this.width * this.dpr);
    var h = Math.round(this.height * this.dpr);
    this.backdrop.width = w;
    this.backdrop.height = h;

    var ctx = this.backdrop.getContext('2d');
    ctx.clearRect(0, 0, w, h);

    var gradient = ctx.createLinearGradient(0, 0, 0, h);
    gradient.addColorStop(0, '#0b0c14');
    gradient.addColorStop(0.5, P.color(cosmetic.secondary, 0.16));
    gradient.addColorStop(1, '#0b0c14');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, w, h);

    if (cosmetic.variant === 4) {
      // Grid backdrop
      ctx.strokeStyle = P.color(cosmetic.primary, 0.16);
      ctx.lineWidth = 1;
      var spacing = 42 * this.dpr;
      ctx.beginPath();
      for (var x = 0; x <= w; x += spacing) {
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
      }
      for (var y = 0; y <= h; y += spacing) {
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
      }
      ctx.stroke();
    } else {
      for (var i = 0; i < STARS.length; i++) {
        var star = STARS[i];
        ctx.fillStyle = 'rgba(255,255,255,' + star.alpha + ')';
        ctx.beginPath();
        ctx.arc(star.x * w, star.y * h, star.radius * this.dpr, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Two soft glows tinted by the cosmetic.
    this.glow(ctx, w * 0.5, h * 0.18, Math.max(w, h) * 0.7, cosmetic.primary, 0.24);
    this.glow(ctx, w * 0.15, h * 0.8, Math.max(w, h) * 0.6, cosmetic.secondary, 0.18);
  };

  Renderer.prototype.glow = function (ctx, x, y, radius, palette, alpha) {
    var gradient = ctx.createRadialGradient(x, y, 4, x, y, radius);
    gradient.addColorStop(0, P.color(palette, alpha));
    gradient.addColorStop(1, P.color(palette, 0));
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
  };

  // ----------------------------------------------------------------- draw

  Renderer.prototype.draw = function () {
    this.resize();
    this.ensureBackdrop();

    var ctx = this.ctx;
    var engine = this.engine;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.drawImage(this.backdrop, 0, 0);

    ctx.scale(this.dpr, this.dpr);

    var shake = engine.screenShake;
    if (shake > 0.01 && !this.state.settings.reducedMotion) {
      var amount = shake * 5;
      ctx.translate((Math.random() * 2 - 1) * amount, (Math.random() * 2 - 1) * amount);
    }

    this.drawSingularity(ctx);
    this.drawOrbs(ctx);
    this.drawDots(ctx);
    this.drawBullets(ctx);
    this.drawDrones(ctx);
    this.drawParticles(ctx);
    this.drawTurret(ctx);
    this.drawLabels(ctx);
  };

  Renderer.prototype.drawDots = function (ctx) {
    var theme = this.state.equipped('dots').variant;
    var reduced = this.state.settings.reducedMotion;
    var dots = this.engine.dots;

    for (var i = 0; i < dots.length; i++) {
      var dot = dots[i];
      if (dot.dead) continue;

      var rgb = C.dotRGB(dot.rarity, dot.golden, theme);
      var base = 'rgb(' + rgb[0] + ',' + rgb[1] + ',' + rgb[2] + ')';
      var radius = dot.radius * (reduced ? 1 : 1 + Math.sin(dot.phase) * 0.06);

      if (dot.golden || dot.rarity >= 4) {
        var glow = ctx.createRadialGradient(dot.x, dot.y, radius * 0.4, dot.x, dot.y, radius * 1.9);
        glow.addColorStop(0, P.rgbaFrom(rgb, 0.35));
        glow.addColorStop(1, P.rgbaFrom(rgb, 0));
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(dot.x, dot.y, radius * 1.9, 0, Math.PI * 2);
        ctx.fill();
      }

      ctx.fillStyle = base;
      ctx.globalAlpha = 0.92;
      ctx.beginPath();
      ctx.arc(dot.x, dot.y, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;

      // Inner highlight gives the dots a bit of volume.
      ctx.fillStyle = 'rgba(255,255,255,0.22)';
      ctx.beginPath();
      ctx.arc(dot.x - radius * 0.24, dot.y - radius * 0.24, radius * 0.42, 0, Math.PI * 2);
      ctx.fill();

      if (dot.flash > 0.01) {
        ctx.fillStyle = 'rgba(255,255,255,' + Math.min(0.75, dot.flash * 0.75) + ')';
        ctx.beginPath();
        ctx.arc(dot.x, dot.y, radius, 0, Math.PI * 2);
        ctx.fill();
      }

      // Health ring, only once the dot has taken a hit.
      var fraction = dot.maxHealth > 0 ? Math.max(0, dot.health / dot.maxHealth) : 0;
      if (fraction < 0.999) {
        ctx.strokeStyle = 'rgba(255,255,255,0.8)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(dot.x, dot.y, radius + 3.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * fraction);
        ctx.stroke();
      }
    }
  };

  Renderer.prototype.drawBullets = function (ctx) {
    var bullets = this.engine.bullets;
    if (!bullets.length) return;

    var trail = this.state.equipped('trail');
    var length = trail.variant === 1 ? 22 : (trail.variant === 3 ? 26 : 16);
    var width = trail.variant === 1 ? 3.6 : 2.4;

    ctx.strokeStyle = P.color(trail.secondary, 0.4);
    ctx.lineWidth = width;
    ctx.lineCap = 'round';
    ctx.beginPath();
    for (var i = 0; i < bullets.length; i++) {
      var bullet = bullets[i];
      if (bullet.dead) continue;
      var speed = Math.max(1, Math.sqrt(bullet.vx * bullet.vx + bullet.vy * bullet.vy));
      ctx.moveTo(bullet.x - bullet.vx / speed * length, bullet.y - bullet.vy / speed * length);
      ctx.lineTo(bullet.x, bullet.y);
    }
    ctx.stroke();

    var core = P.color(trail.primary);
    var critColor = P.color('amber');
    for (var j = 0; j < bullets.length; j++) {
      var b = bullets[j];
      if (b.dead) continue;
      ctx.fillStyle = b.isCrit ? critColor : core;
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius, 0, Math.PI * 2);
      ctx.fill();
    }
  };

  Renderer.prototype.drawOrbs = function (ctx) {
    var orbs = this.engine.orbs;
    for (var i = 0; i < orbs.length; i++) {
      var orb = orbs[i];
      if (orb.dead) continue;

      var fade = Math.min(1, orb.life / Math.max(0.01, orb.maxLife * 0.35));
      var rgb = orb.golden ? C.GOLDEN_RGB : P.rgb('mint');

      var glow = ctx.createRadialGradient(orb.x, orb.y, 0, orb.x, orb.y, orb.radius * 2.4);
      glow.addColorStop(0, P.rgbaFrom(rgb, 0.4 * fade));
      glow.addColorStop(1, P.rgbaFrom(rgb, 0));
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(orb.x, orb.y, orb.radius * 2.4, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = P.rgbaFrom(rgb, fade);
      ctx.beginPath();
      ctx.arc(orb.x, orb.y, orb.radius, 0, Math.PI * 2);
      ctx.fill();
    }
  };

  Renderer.prototype.drawDrones = function (ctx) {
    var cosmetic = this.state.equipped('drone');
    var body = P.color(cosmetic.primary);
    var accent = P.color(cosmetic.secondary);
    var collect = this.state.derived.droneSize + 6;
    var suction = this.state.derived.droneSuction;
    // The hull is drawn well under the real collect radius: at high Size levels
    // a 1:1 hull would swallow the screen. The inner ring shows the true reach.
    var size = Math.min(17, this.state.derived.droneSize * 0.55);

    for (var i = 0; i < this.engine.drones.length; i++) {
      var drone = this.engine.drones[i];

      ctx.strokeStyle = P.color(cosmetic.primary, 0.07);
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(drone.x, drone.y, suction, 0, Math.PI * 2);
      ctx.stroke();

      ctx.strokeStyle = P.color(cosmetic.primary, 0.22);
      ctx.beginPath();
      ctx.arc(drone.x, drone.y, collect, 0, Math.PI * 2);
      ctx.stroke();

      ctx.save();
      ctx.translate(drone.x, drone.y);
      ctx.rotate(drone.angle);

      if (cosmetic.variant === 2) {
        ctx.strokeStyle = P.color(cosmetic.secondary, 0.7);
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(0, 0, size, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fillStyle = body;
        ctx.beginPath();
        ctx.arc(0, 0, size * 0.5, 0, Math.PI * 2);
        ctx.fill();
      } else if (cosmetic.variant === 4) {
        ctx.beginPath();
        ctx.moveTo(size, 0);
        ctx.lineTo(0, size * 0.8);
        ctx.lineTo(-size, 0);
        ctx.lineTo(0, -size * 0.8);
        ctx.closePath();
        ctx.fillStyle = body;
        ctx.fill();
        ctx.strokeStyle = P.color(cosmetic.secondary, 0.9);
        ctx.lineWidth = 1.5;
        ctx.stroke();
      } else {
        ctx.fillStyle = body;
        roundRect(ctx, -size, -size * 0.7, size * 2, size * 1.4, size * 0.5);
        ctx.fill();
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.arc(size * 0.35, 0, size * 0.25, 0, Math.PI * 2);
        ctx.fill();
      }

      ctx.restore();
    }
  };

  Renderer.prototype.drawParticles = function (ctx) {
    var particles = this.engine.particles;
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      if (p.life <= 0) continue;
      var alpha = Math.max(0, p.life / Math.max(0.01, p.maxLife));

      if (p.ring) {
        // Expanding shockwave.
        ctx.strokeStyle = 'rgba(' + p.r + ',' + p.g + ',' + p.b + ',' + alpha * 0.55 + ')';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius * (1.05 - alpha * 0.55), 0, Math.PI * 2);
        ctx.stroke();
        continue;
      }

      var radius = p.radius * (0.4 + alpha * 0.6);
      ctx.fillStyle = 'rgba(' + p.r + ',' + p.g + ',' + p.b + ',' + alpha + ')';
      ctx.beginPath();
      ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
      ctx.fill();
    }
  };

  Renderer.prototype.drawSingularity = function (ctx) {
    var hole = this.engine.singularity;
    if (!hole) return;

    var progress = hole.duration > 0 ? 1 - Math.max(0, hole.remaining / hole.duration) : 1;
    var radius = 30 + Math.sin(progress * Math.PI) * 46;

    var glow = ctx.createRadialGradient(hole.x, hole.y, radius * 0.5, hole.x, hole.y, radius * 2.6);
    glow.addColorStop(0, P.color('purple', 0.45));
    glow.addColorStop(0.6, P.color('violet', 0.12));
    glow.addColorStop(1, P.color('violet', 0));
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(hole.x, hole.y, radius * 2.6, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(0,0,0,0.92)';
    ctx.beginPath();
    ctx.arc(hole.x, hole.y, radius, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = P.color('magenta', 0.8);
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(hole.x, hole.y, radius * 1.15, 0, Math.PI * 2);
    ctx.stroke();
  };

  Renderer.prototype.drawTurret = function (ctx) {
    var engine = this.engine;
    var cosmetic = this.state.equipped('turret');
    var body = P.color(cosmetic.primary);
    var accent = P.color(cosmetic.secondary);
    var x = engine.turretX;
    var y = engine.turretY;

    // Base glow
    var glow = ctx.createRadialGradient(x, y, 2, x, y, 24);
    glow.addColorStop(0, P.color(cosmetic.primary, 0.3));
    glow.addColorStop(1, P.color(cosmetic.primary, 0));
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(x, y, 24, 0, Math.PI * 2);
    ctx.fill();

    var barrelLength = cosmetic.variant === 2 ? 34 : 28;
    var barrelWidth = cosmetic.variant === 6 ? 13 : 9;

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(engine.turretAngle);

    ctx.fillStyle = body;
    if (cosmetic.variant === 3 || cosmetic.variant === 5) {
      roundRect(ctx, 4, -barrelWidth * 0.55 - 2.4, barrelLength, 4.8, 2.4);
      ctx.fill();
      roundRect(ctx, 4, barrelWidth * 0.55 - 2.4, barrelLength, 4.8, 2.4);
      ctx.fill();
    } else if (cosmetic.variant === 7) {
      ctx.beginPath();
      ctx.moveTo(6, -barrelWidth / 2);
      ctx.lineTo(barrelLength, -2);
      ctx.lineTo(barrelLength, 2);
      ctx.lineTo(6, barrelWidth / 2);
      ctx.closePath();
      ctx.fill();
    } else {
      roundRect(ctx, 4, -barrelWidth / 2, barrelLength, barrelWidth, barrelWidth / 2);
      ctx.fill();
    }

    if (engine.muzzleFlash > 0.02) {
      var flash = engine.muzzleFlash;
      ctx.fillStyle = P.color(cosmetic.secondary, 0.85 * flash);
      ctx.beginPath();
      ctx.arc(barrelLength + 4 * flash, 0, 6 * flash, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();

    // Hub
    ctx.fillStyle = '#202434';
    ctx.beginPath();
    ctx.arc(x, y, 13, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = P.color(cosmetic.primary, 0.9);
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.fillStyle = accent;
    ctx.beginPath();
    ctx.arc(x, y, 4.5, 0, Math.PI * 2);
    ctx.fill();

    // Ground line the dots never cross.
    ctx.strokeStyle = 'rgba(56,61,82,0.55)';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 6]);
    ctx.beginPath();
    ctx.moveTo(0, engine.playHeight);
    ctx.lineTo(this.width, engine.playHeight);
    ctx.stroke();
    ctx.setLineDash([]);
  };

  Renderer.prototype.drawLabels = function (ctx) {
    var labels = this.engine.labels;
    if (!labels.length) return;

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    for (var i = 0; i < labels.length; i++) {
      var label = labels[i];
      if (label.life <= 0) continue;
      var alpha = Math.min(1, label.life / Math.max(0.01, label.maxLife * 0.6));
      ctx.font = '900 ' + (label.emphasised ? 17 : 12) + 'px ' +
                 'ui-rounded, -apple-system, "Segoe UI", system-ui, sans-serif';
      ctx.fillStyle = P.color(label.palette, alpha);
      ctx.fillText(label.text, label.x, label.y);
    }
  };

  function roundRect(ctx, x, y, width, height, radius) {
    var r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.arcTo(x + width, y, x + width, y + r, r);
    ctx.lineTo(x + width, y + height - r);
    ctx.arcTo(x + width, y + height, x + width - r, y + height, r);
    ctx.lineTo(x + r, y + height);
    ctx.arcTo(x, y + height, x, y + height - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
  }

  global.Renderer = Renderer;
})(window);
