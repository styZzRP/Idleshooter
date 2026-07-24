/* The simulation. Owns every entity on the field, advances them once per frame,
   and reports earnings back to GameState. Works in CSS pixels; the renderer
   handles device pixel ratio. */
(function (global) {
  'use strict';

  var C = global.Catalog;
  var B = C.BALANCE;
  /* Height reserved at the bottom for the turret and the ability bar that
     floats over it, so dots never drift behind the buttons. */
  var TURRET_MARGIN = 132;
  var TURRET_OFFSET = 98;

  // -------------------------------------------------------- spatial grid

  function SpatialGrid() {
    this.cellSize = 80;
    this.columns = 1;
    this.rows = 1;
    this.buckets = [[]];
  }

  SpatialGrid.prototype.rebuild = function (width, height, dots) {
    var cols = Math.max(1, Math.ceil(width / this.cellSize));
    var rows = Math.max(1, Math.ceil(height / this.cellSize));

    if (cols !== this.columns || rows !== this.rows || this.buckets.length !== cols * rows) {
      this.columns = cols;
      this.rows = rows;
      this.buckets = new Array(cols * rows);
      for (var i = 0; i < this.buckets.length; i++) this.buckets[i] = [];
    } else {
      for (var j = 0; j < this.buckets.length; j++) this.buckets[j].length = 0;
    }

    for (var k = 0; k < dots.length; k++) {
      var dot = dots[k];
      if (dot.dead) continue;
      var cx = Math.min(cols - 1, Math.max(0, (dot.x / this.cellSize) | 0));
      var cy = Math.min(rows - 1, Math.max(0, (dot.y / this.cellSize) | 0));
      this.buckets[cy * cols + cx].push(k);
    }
  };

  /** Returns the index of the first dot within reach, or -1. */
  SpatialGrid.prototype.findHit = function (dots, x, y, radius, skipID) {
    var cx = Math.min(this.columns - 1, Math.max(0, (x / this.cellSize) | 0));
    var cy = Math.min(this.rows - 1, Math.max(0, (y / this.cellSize) | 0));
    var minX = Math.max(0, cx - 1), maxX = Math.min(this.columns - 1, cx + 1);
    var minY = Math.max(0, cy - 1), maxY = Math.min(this.rows - 1, cy + 1);

    for (var row = minY; row <= maxY; row++) {
      for (var col = minX; col <= maxX; col++) {
        var bucket = this.buckets[row * this.columns + col];
        for (var i = 0; i < bucket.length; i++) {
          var index = bucket[i];
          var dot = dots[index];
          if (!dot || dot.dead || dot.id === skipID) continue;
          var dx = dot.x - x;
          var dy = dot.y - y;
          var reach = dot.radius + radius;
          if (dx * dx + dy * dy <= reach * reach) return index;
        }
      }
    }
    return -1;
  };

  // --------------------------------------------------------------- engine

  function GameEngine(state) {
    this.state = state;

    this.dots = [];
    this.bullets = [];
    this.orbs = [];
    this.drones = [];
    this.particles = [];
    this.labels = [];
    this.singularity = null;

    this.width = 0;
    this.height = 0;
    this.turretX = 0;
    this.turretY = 0;
    this.turretAngle = -Math.PI / 2;
    this.muzzleFlash = 0;
    this.screenShake = 0;

    this.nextID = 1;
    this.spawnAccumulator = 0;
    this.fireAccumulator = 0;
    this.rainRemaining = 0;
    this.rainRate = 0;
    this.rainAccumulator = 0;
    this.grid = new SpatialGrid();

    this.incomeAccumulator = 0;
    this.incomeWindow = 0;
    this.knownResetToken = state.fieldResetToken;
    this.primed = false;
  }

  GameEngine.prototype.takeID = function () { return ++this.nextID; };

  Object.defineProperty(GameEngine.prototype, 'playHeight', {
    get: function () { return Math.max(120, this.height - TURRET_MARGIN); }
  });

  GameEngine.prototype.resize = function (width, height) {
    if (!(width > 0) || !(height > 0)) return;
    var changed = Math.abs(width - this.width) > 0.5 || Math.abs(height - this.height) > 0.5;
    this.width = width;
    this.height = height;
    this.turretX = width / 2;
    this.turretY = height - TURRET_OFFSET;
    if (changed) {
      this.clampEntities();
      if (!this.drones.length) this.syncDrones();
    }
  };

  GameEngine.prototype.clampEntities = function () {
    var maxY = this.playHeight;
    for (var i = 0; i < this.dots.length; i++) {
      var dot = this.dots[i];
      dot.x = Math.min(Math.max(dot.radius, dot.x), this.width - dot.radius);
      dot.y = Math.min(Math.max(dot.radius, dot.y), maxY - dot.radius);
    }
  };

  // ---------------------------------------------------------------- frame

  GameEngine.prototype.update = function (rawDT) {
    if (!(this.width > 1) || !(this.height > 1)) return;
    var dt = Math.min(rawDT, 1 / 20);
    var state = this.state;

    if (state.fieldResetToken !== this.knownResetToken || !this.primed) {
      this.knownResetToken = state.fieldResetToken;
      this.resetField();
    }

    state.stats.timeActive += dt;
    state.tickCombo(dt);

    this.updateAbilities(dt);
    this.syncDrones();
    this.spawnDots(dt);
    this.updateDots(dt);
    this.updateTurret(dt);
    this.updateBullets(dt);
    this.updateOrbs(dt);
    this.updateDrones(dt);
    this.updateParticles(dt);
    this.updateLabels(dt);

    if (state.derived.idleIncome > 0) this.award(state.derived.idleIncome * dt);

    this.muzzleFlash = Math.max(0, this.muzzleFlash - dt * 6);
    this.screenShake = Math.max(0, this.screenShake - dt * 4);

    this.compact();
    this.trackIncome(dt);
  };

  GameEngine.prototype.trackIncome = function (dt) {
    this.incomeWindow += dt;
    if (this.incomeWindow < 1) return;
    var perSecond = this.incomeAccumulator / this.incomeWindow;
    var state = this.state;
    state.recentIncomePerSecond = state.recentIncomePerSecond > 0
      ? state.recentIncomePerSecond * 0.65 + perSecond * 0.35
      : perSecond;
    this.incomeAccumulator = 0;
    this.incomeWindow = 0;
  };

  GameEngine.prototype.award = function (amount) {
    if (!(amount > 0)) return;
    this.state.awardCash(amount);
    this.incomeAccumulator += amount;
  };

  GameEngine.prototype.resetField = function () {
    this.dots.length = 0;
    this.bullets.length = 0;
    this.orbs.length = 0;
    this.particles.length = 0;
    this.labels.length = 0;
    this.singularity = null;
    this.rainRemaining = 0;
    this.spawnAccumulator = 0;
    this.fireAccumulator = 0;
    this.syncDrones();

    // Give the new galaxy a head start so the field is never empty on arrival.
    var prefill = Math.max(3, Math.floor(this.state.derived.capacity / 2));
    for (var i = 0; i < prefill; i++) this.spawnDot(false);
    this.primed = true;
  };

  // ----------------------------------------------------------------- dots

  GameEngine.prototype.spawnDots = function (dt) {
    var capacity = this.state.derived.capacity;

    if (this.rainRemaining > 0) {
      this.rainRemaining = Math.max(0, this.rainRemaining - dt);
      this.rainAccumulator += dt * this.rainRate;
      while (this.rainAccumulator >= 1 && this.dots.length < B.maxDots) {
        this.rainAccumulator -= 1;
        this.spawnDot(true);
      }
    }

    if (this.dots.length >= capacity) return;
    this.spawnAccumulator += dt * this.state.derived.spawnRate;
    var budget = 0;
    while (this.spawnAccumulator >= 1 && this.dots.length < capacity && budget < 12) {
      this.spawnAccumulator -= 1;
      this.spawnDot(false);
      budget++;
    }
    if (this.spawnAccumulator > 4) this.spawnAccumulator = 4;
  };

  GameEngine.prototype.spawnDot = function (fromRain) {
    if (this.dots.length >= B.maxDots) return;
    var d = this.state.derived;
    var rarityIndex = C.rollRarity(d.luck);
    var rarity = C.RARITIES[rarityIndex];
    var golden = Math.random() < d.goldenChance;

    var radius = rarity.radius * (golden ? 1.15 : 1);
    var width = this.width;
    var height = this.playHeight;

    var health = B.baseDotHealth * d.dotHealthScale * rarity.health * (golden ? 3 : 1);
    var value = B.baseDotValue * d.dotValueScale * rarity.value * d.valueMultiplier * (golden ? 25 : 1);

    var speed = (14 + Math.random() * 26) * d.driftScale;
    var angle = Math.random() * Math.PI * 2;

    var maxX = Math.max(radius + 1, width - radius);
    var maxY = fromRain
      ? Math.max(radius + 1, height * 0.35)
      : Math.max(radius + 1, height - radius);

    this.dots.push({
      id: this.takeID(),
      x: radius + Math.random() * (maxX - radius),
      y: radius + Math.random() * (maxY - radius),
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      radius: radius,
      health: health,
      maxHealth: health,
      rarity: rarityIndex,
      golden: golden,
      value: value,
      flash: 0,
      phase: Math.random() * Math.PI * 2,
      dead: false
    });
  };

  GameEngine.prototype.updateDots = function (dt) {
    var width = this.width;
    var height = this.playHeight;
    var wander = this.state.derived.wanderScale;
    var hole = this.singularity;

    for (var i = 0; i < this.dots.length; i++) {
      var dot = this.dots[i];
      if (dot.dead) continue;

      if (wander > 0) {
        dot.vx += (Math.random() * 56 - 28) * wander * dt;
        dot.vy += (Math.random() * 56 - 28) * wander * dt;
        var speed = Math.sqrt(dot.vx * dot.vx + dot.vy * dot.vy);
        if (speed > 90) {
          dot.vx = dot.vx / speed * 90;
          dot.vy = dot.vy / speed * 90;
        }
      }

      if (hole) {
        var hx = hole.x - dot.x;
        var hy = hole.y - dot.y;
        var distance = Math.max(6, Math.sqrt(hx * hx + hy * hy));
        var force = hole.pull / distance;
        dot.vx += hx / distance * force * dt;
        dot.vy += hy / distance * force * dt;

        if (distance < 26) {
          this.consumeBySingularity(i);
          continue;
        }
      }

      dot.x += dot.vx * dt;
      dot.y += dot.vy * dt;
      dot.phase += dt * 2;

      if (dot.x < dot.radius) { dot.x = dot.radius; dot.vx = Math.abs(dot.vx); }
      if (dot.x > width - dot.radius) { dot.x = width - dot.radius; dot.vx = -Math.abs(dot.vx); }
      if (dot.y < dot.radius) { dot.y = dot.radius; dot.vy = Math.abs(dot.vy); }
      if (dot.y > height - dot.radius) { dot.y = height - dot.radius; dot.vy = -Math.abs(dot.vy); }

      dot.flash = Math.max(0, dot.flash - dt * 7);
    }
  };

  // --------------------------------------------------------------- turret

  GameEngine.prototype.effectiveFireRate = function () {
    var rate = this.state.derived.fireRate;
    var frenzy = this.state.ability('frenzy');
    if (frenzy.activeRemaining > 0) {
      rate *= C.abilityPotency(C.ability('frenzy'), frenzy.level, this.state.abilityPower());
    }
    return Math.max(0.1, rate);
  };

  GameEngine.prototype.effectiveMultishot = function () {
    var shots = this.state.derived.multishot;
    if (this.state.ability('frenzy').activeRemaining > 0) shots += 3;
    return Math.min(48, Math.max(1, shots));
  };

  GameEngine.prototype.updateTurret = function (dt) {
    var targetIndex = this.nearestDotIndex(this.turretX, this.turretY);
    if (targetIndex < 0) return;

    var target = this.dots[targetIndex];
    var speed = Math.max(60, this.state.derived.bulletSpeed);
    var dx = target.x - this.turretX;
    var dy = target.y - this.turretY;
    var time = Math.sqrt(dx * dx + dy * dy) / speed;
    var desired = Math.atan2(target.y + target.vy * time - this.turretY,
                             target.x + target.vx * time - this.turretX);

    this.turretAngle = this.turnToward(this.turretAngle, desired, 14 * dt);

    this.fireAccumulator += dt * this.effectiveFireRate();
    var volleys = 0;
    while (this.fireAccumulator >= 1 && volleys < 8) {
      this.fireAccumulator -= 1;
      this.fireVolley(desired);
      volleys++;
    }
    if (this.fireAccumulator > 3) this.fireAccumulator = 3;
  };

  GameEngine.prototype.turnToward = function (current, target, rate) {
    var delta = target - current;
    while (delta > Math.PI) delta -= Math.PI * 2;
    while (delta < -Math.PI) delta += Math.PI * 2;
    return current + delta * Math.min(1, rate);
  };

  GameEngine.prototype.nearestDotIndex = function (x, y) {
    var best = -1;
    var bestDistance = Infinity;
    for (var i = 0; i < this.dots.length; i++) {
      var dot = this.dots[i];
      if (dot.dead) continue;
      var dx = dot.x - x;
      var dy = dot.y - y;
      var distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  };

  GameEngine.prototype.fireVolley = function (angle) {
    if (this.bullets.length >= B.maxBullets) return;
    var d = this.state.derived;
    var count = this.effectiveMultishot();
    var spread = Math.min(1.05, (count - 1) * 0.085);
    var start = angle - spread / 2;
    var step = count > 1 ? spread / (count - 1) : 0;

    for (var i = 0; i < count; i++) {
      if (this.bullets.length >= B.maxBullets) break;
      var theta = start + step * i;
      var crit = Math.random() < d.critChance;

      this.bullets.push({
        id: this.takeID(),
        x: this.turretX + Math.cos(theta) * 26,
        y: this.turretY + Math.sin(theta) * 26,
        vx: Math.cos(theta) * d.bulletSpeed,
        vy: Math.sin(theta) * d.bulletSpeed,
        damage: d.damage * (crit ? d.critDamage : 1),
        isCrit: crit,
        pierceLeft: d.pierce,
        life: 3,
        radius: crit ? 4.2 : 3.2,
        lastHitID: -1,
        hitCooldown: 0,
        dead: false
      });
      this.state.stats.shotsFired++;
    }

    this.muzzleFlash = 1;
    if (count >= 8) global.Feedback.tap('light', 0.14);
  };

  // -------------------------------------------------------------- bullets

  GameEngine.prototype.updateBullets = function (dt) {
    if (!this.bullets.length) return;
    this.grid.rebuild(this.width, this.playHeight, this.dots);

    var width = this.width;
    var height = this.playHeight;
    var stats = this.state.stats;
    var damageNumbers = this.state.settings.damageNumbers;

    for (var i = 0; i < this.bullets.length; i++) {
      var bullet = this.bullets[i];
      if (bullet.dead) continue;

      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
      bullet.life -= dt;
      bullet.hitCooldown = Math.max(0, bullet.hitCooldown - dt);

      if (bullet.life <= 0 || bullet.x < -20 || bullet.x > width + 20 ||
          bullet.y < -20 || bullet.y > height + 60) {
        bullet.dead = true;
        continue;
      }

      if (bullet.hitCooldown > 0) continue;

      var hitIndex = this.grid.findHit(this.dots, bullet.x, bullet.y, bullet.radius, bullet.lastHitID);
      if (hitIndex < 0) continue;

      var dot = this.dots[hitIndex];
      bullet.lastHitID = dot.id;
      bullet.hitCooldown = 0.03;
      stats.bulletsHit++;
      if (bullet.isCrit) stats.criticalHits++;
      if (bullet.damage > stats.biggestSingleHit) stats.biggestSingleHit = bullet.damage;

      if (bullet.isCrit && damageNumbers) {
        this.addLabel(Fmt.number(bullet.damage), dot.x, dot.y - dot.radius - 4, 'amber', false);
      }

      this.applyDamage(hitIndex, bullet.damage, true);

      if (bullet.pierceLeft > 0) bullet.pierceLeft--;
      else bullet.dead = true;
    }
  };

  GameEngine.prototype.applyDamage = function (index, amount, allowSplash) {
    var dot = this.dots[index];
    if (!dot || dot.dead) return;
    dot.health -= amount;
    dot.flash = 1;
    if (dot.health <= 0) this.kill(index, allowSplash);
  };

  GameEngine.prototype.kill = function (index, allowSplash) {
    var dot = this.dots[index];
    if (!dot || dot.dead) return;
    dot.dead = true;

    var payout = dot.value * this.state.comboMultiplier();
    this.state.registerKill(dot.rarity, dot.golden);
    this.spawnOrb(dot, payout);
    this.spawnPopParticles(dot);

    if (dot.golden || dot.rarity >= 3) {
      if (this.state.settings.damageNumbers) {
        this.addLabel(Fmt.cash(payout), dot.x, dot.y,
                      dot.golden ? 'gold' : C.RARITIES[dot.rarity].palette, true);
      }
      global.Feedback.tap('medium', 0.2);
      global.Feedback.play('pop', 0.18);
    }

    if (allowSplash && this.state.derived.explosiveRadius > 0) this.splash(dot);
  };

  GameEngine.prototype.splash = function (source) {
    var radius = this.state.derived.explosiveRadius;
    var damage = this.state.derived.damage * 0.6;
    var radiusSquared = radius * radius;

    for (var i = 0; i < this.dots.length; i++) {
      var dot = this.dots[i];
      if (dot.dead) continue;
      var dx = dot.x - source.x;
      var dy = dot.y - source.y;
      if (dx * dx + dy * dy > radiusSquared) continue;
      this.applyDamage(i, damage, false);
    }

    if (this.state.settings.particles) {
      this.addParticle(source.x, source.y, 0, 0, 0.28, radius, [255, 140, 51]);
    }
  };

  GameEngine.prototype.consumeBySingularity = function (index) {
    var dot = this.dots[index];
    if (!dot || dot.dead || !this.singularity) return;
    dot.dead = true;

    this.state.registerKill(dot.rarity, dot.golden);
    this.award(dot.value * this.state.comboMultiplier() * this.singularity.payoutMultiplier);
    this.spawnPopParticles(dot);
  };

  // ----------------------------------------------------------------- orbs

  GameEngine.prototype.spawnOrb = function (dot, value) {
    if (this.orbs.length >= B.maxOrbs) {
      // Field is saturated — bank it rather than dropping it on the floor.
      this.award(value * (1 + this.state.derived.droneBonus) * this.state.shopDropMultiplier);
      return;
    }
    var life = this.state.derived.orbLifetime;
    var angle = Math.random() * Math.PI * 2;
    var speed = 10 + Math.random() * 35;

    this.orbs.push({
      id: this.takeID(),
      x: dot.x,
      y: dot.y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      value: value,
      life: life,
      maxLife: life,
      radius: dot.golden ? 7 : 5,
      golden: dot.golden,
      dead: false
    });
  };

  GameEngine.prototype.updateOrbs = function (dt) {
    if (!this.orbs.length) return;
    var width = this.width;
    var height = this.playHeight;
    var suction = this.state.derived.droneSuction;
    var magnet = this.state.derived.droneMagnet;
    var drag = 1 - Math.min(1, dt * 1.4);

    for (var i = 0; i < this.orbs.length; i++) {
      var orb = this.orbs[i];
      if (orb.dead) continue;

      var bestDistance = Infinity;
      var pullX = 0;
      var pullY = 0;
      for (var j = 0; j < this.drones.length; j++) {
        var drone = this.drones[j];
        var dx = drone.x - orb.x;
        var dy = drone.y - orb.y;
        var distance = Math.sqrt(dx * dx + dy * dy);
        if (distance < bestDistance) {
          bestDistance = distance;
          pullX = dx;
          pullY = dy;
        }
      }

      if (bestDistance <= suction && bestDistance > 0.001) {
        var strength = magnet * (1 - bestDistance / Math.max(1, suction)) + magnet * 0.35;
        orb.vx += pullX / bestDistance * strength * dt;
        orb.vy += pullY / bestDistance * strength * dt;
      } else {
        orb.vx *= drag;
        orb.vy *= drag;
      }

      if (this.singularity) {
        var hx = this.singularity.x - orb.x;
        var hy = this.singularity.y - orb.y;
        var hd = Math.max(6, Math.sqrt(hx * hx + hy * hy));
        orb.vx += hx / hd * this.singularity.pull * 0.6 * dt;
        orb.vy += hy / hd * this.singularity.pull * 0.6 * dt;
      }

      orb.x += orb.vx * dt;
      orb.y += orb.vy * dt;
      orb.life -= dt;

      orb.x = Math.min(Math.max(orb.radius, orb.x), Math.max(orb.radius + 1, width - orb.radius));
      orb.y = Math.min(Math.max(orb.radius, orb.y), Math.max(orb.radius + 1, height - orb.radius));

      if (orb.life <= 0) {
        orb.dead = true;
        // Fading orbs still bank a fraction — upgrade the drone to keep the rest.
        this.award(orb.value * 0.2);
        this.state.stats.orbsLost++;
      }
    }
  };

  GameEngine.prototype.collect = function (index) {
    var orb = this.orbs[index];
    if (!orb || orb.dead) return;
    orb.dead = true;

    this.award(orb.value * (1 + this.state.derived.droneBonus) * this.state.shopDropMultiplier);
    this.state.stats.orbsCollected++;

    if (this.state.settings.particles) {
      this.addParticle(orb.x, orb.y, 0, -30, 0.3, 6,
                       orb.golden ? C.GOLDEN_RGB : global.Palette.rgb('mint'));
    }
  };

  // --------------------------------------------------------------- drones

  GameEngine.prototype.syncDrones = function () {
    var wanted = Math.max(1, this.state.derived.droneCount);
    if (!(this.width > 1)) return;

    while (this.drones.length > wanted) this.drones.pop();
    while (this.drones.length < wanted) {
      var index = this.drones.length;
      this.drones.push({
        id: this.takeID(),
        x: this.width * 0.5 + index * 24,
        y: this.playHeight * 0.65,
        vx: 0,
        vy: 0,
        angle: -Math.PI / 2,
        targetOrbID: -1,
        idlePhase: index * 1.9
      });
    }
  };

  GameEngine.prototype.updateDrones = function (dt) {
    var d = this.state.derived;
    var width = this.width;
    var height = this.playHeight;
    var maxSpeed = d.droneSpeed;
    var accel = maxSpeed * d.droneAgility;
    var collectRadius = d.droneSize + 6;

    for (var i = 0; i < this.drones.length; i++) {
      var drone = this.drones[i];

      var targetX = width / 2 + Math.cos(drone.idlePhase) * width * 0.3;
      var targetY = height / 2 + Math.sin(drone.idlePhase * 0.7) * height * 0.3;
      var hasTarget = false;

      var bestIndex = -1;
      var bestDistance = Infinity;
      for (var j = 0; j < this.orbs.length; j++) {
        var orb = this.orbs[j];
        if (orb.dead) continue;
        if (this.claimedByCloserDrone(orb, i)) continue;
        var ox = orb.x - drone.x;
        var oy = orb.y - drone.y;
        var distance = ox * ox + oy * oy;
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = j;
        }
      }

      if (bestIndex >= 0) {
        targetX = this.orbs[bestIndex].x;
        targetY = this.orbs[bestIndex].y;
        drone.targetOrbID = this.orbs[bestIndex].id;
        hasTarget = true;
      } else {
        drone.targetOrbID = -1;
        drone.idlePhase += dt * 0.6;
      }

      var dx = targetX - drone.x;
      var dy = targetY - drone.y;
      var distanceToTarget = Math.max(0.001, Math.sqrt(dx * dx + dy * dy));
      drone.vx += dx / distanceToTarget * accel * dt;
      drone.vy += dy / distanceToTarget * accel * dt;

      var speed = Math.sqrt(drone.vx * drone.vx + drone.vy * drone.vy);
      if (speed > maxSpeed) {
        drone.vx = drone.vx / speed * maxSpeed;
        drone.vy = drone.vy / speed * maxSpeed;
      }

      drone.x = Math.min(Math.max(8, drone.x + drone.vx * dt), Math.max(9, width - 8));
      drone.y = Math.min(Math.max(8, drone.y + drone.vy * dt), Math.max(9, height - 8));
      if (speed > 1) drone.angle = Math.atan2(drone.vy, drone.vx);

      if (!hasTarget) continue;
      for (var k = 0; k < this.orbs.length; k++) {
        var candidate = this.orbs[k];
        if (candidate.dead) continue;
        var cx = candidate.x - drone.x;
        var cy = candidate.y - drone.y;
        var reach = collectRadius + candidate.radius;
        if (cx * cx + cy * cy <= reach * reach) this.collect(k);
      }
    }
  };

  GameEngine.prototype.claimedByCloserDrone = function (orb, droneIndex) {
    var me = this.drones[droneIndex];
    var myDX = orb.x - me.x;
    var myDY = orb.y - me.y;
    var myDistance = myDX * myDX + myDY * myDY;

    for (var i = 0; i < droneIndex; i++) {
      var other = this.drones[i];
      if (other.targetOrbID !== orb.id) continue;
      var dx = orb.x - other.x;
      var dy = orb.y - other.y;
      if (dx * dx + dy * dy <= myDistance) return true;
    }
    return false;
  };

  // ------------------------------------------------------------ abilities

  GameEngine.prototype.updateAbilities = function (dt) {
    var state = this.state;

    for (var i = 0; i < C.ABILITIES.length; i++) {
      var ability = state.ability(C.ABILITIES[i].id);
      if (!ability.unlocked) continue;
      if (ability.activeRemaining > 0) {
        ability.activeRemaining = Math.max(0, ability.activeRemaining - dt);
      } else if (ability.cooldownRemaining > 0) {
        ability.cooldownRemaining = Math.max(0, ability.cooldownRemaining - dt);
      }
    }

    if (this.singularity) {
      this.singularity.remaining -= dt;
      if (this.singularity.remaining <= 0) this.singularity = null;
    }

    if (state.autoCastUnlocked && state.autoCastEnabled) {
      for (var j = 0; j < C.ABILITIES.length; j++) {
        var id = C.ABILITIES[j].id;
        if (state.abilityReady(id)) this.cast(id);
      }
    }
  };

  GameEngine.prototype.cast = function (id) {
    var state = this.state;
    if (!state.abilityReady(id)) {
      global.Feedback.play('denied');
      return false;
    }

    var def = C.ability(id);
    var ability = state.ability(id);
    var duration = C.abilityDuration(def, ability.level);

    ability.activeRemaining = duration;
    ability.cooldownRemaining = C.abilityCooldown(def, ability.level, state.abilityCooldownReduction());

    var potency = C.abilityPotency(def, ability.level, state.abilityPower());

    if (id === 'frenzy') {
      state.stats.frenzyCasts++;
      this.screenShake = 1;
      this.addLabel('FRENZY', this.turretX, this.playHeight * 0.5, 'orange', true);
    } else if (id === 'dotRain') {
      state.stats.dotRainCasts++;
      this.rainRemaining = duration;
      this.rainRate = potency / Math.max(0.5, duration);
      this.rainAccumulator = 0;
      this.addLabel('DOT RAIN', this.width / 2, this.playHeight * 0.35, 'cyan', true);
    } else if (id === 'blackHole') {
      state.stats.blackHoleCasts++;
      this.singularity = {
        x: this.width / 2,
        y: this.playHeight * 0.45,
        remaining: duration,
        duration: duration,
        pull: 900,
        payoutMultiplier: potency
      };
      this.screenShake = 1;
      this.addLabel('BLACK HOLE', this.width / 2, this.playHeight * 0.2, 'purple', true);
    }

    state.stats.abilitiesCast++;
    state.touch();
    global.Feedback.tap('heavy');
    global.Feedback.play('ability');
    return true;
  };

  // ------------------------------------------------- particles and labels

  GameEngine.prototype.spawnPopParticles = function (dot) {
    if (!this.state.settings.particles) return;
    var theme = this.state.equipped('dots').variant;
    var rgb = C.dotRGB(dot.rarity, dot.golden, theme);
    var count = Math.min(10, 4 + dot.rarity * 2);

    for (var i = 0; i < count; i++) {
      if (this.particles.length >= B.maxParticles) return;
      var angle = Math.random() * Math.PI * 2;
      var speed = 40 + Math.random() * 130;
      this.addParticle(dot.x, dot.y,
                       Math.cos(angle) * speed, Math.sin(angle) * speed,
                       0.25 + Math.random() * 0.3,
                       1.5 + Math.random() * 1.9,
                       rgb);
    }
  };

  GameEngine.prototype.addParticle = function (x, y, vx, vy, life, radius, rgb) {
    if (this.particles.length >= B.maxParticles) return;
    this.particles.push({
      x: x, y: y, vx: vx, vy: vy,
      life: life, maxLife: life, radius: radius,
      r: rgb[0], g: rgb[1], b: rgb[2]
    });
  };

  GameEngine.prototype.updateParticles = function (dt) {
    if (!this.particles.length) return;
    var drag = 1 - Math.min(1, dt * 2.6);
    for (var i = 0; i < this.particles.length; i++) {
      var p = this.particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= drag;
      p.vy *= drag;
      p.life -= dt;
    }
  };

  GameEngine.prototype.addLabel = function (text, x, y, palette, emphasised) {
    if (this.labels.length >= B.maxLabels) return;
    var life = emphasised ? 1.1 : 0.7;
    this.labels.push({
      x: x, y: y,
      vy: emphasised ? -46 : -34,
      text: text,
      life: life,
      maxLife: life,
      palette: palette,
      emphasised: emphasised
    });
  };

  GameEngine.prototype.updateLabels = function (dt) {
    for (var i = 0; i < this.labels.length; i++) {
      this.labels[i].y += this.labels[i].vy * dt;
      this.labels[i].life -= dt;
    }
  };

  // ---------------------------------------------------------- housekeeping

  function alive(entity) { return !entity.dead; }
  function living(entity) { return entity.life > 0; }

  GameEngine.prototype.compact = function () {
    if (this.dots.some(function (d) { return d.dead; })) this.dots = this.dots.filter(alive);
    if (this.bullets.some(function (b) { return b.dead; })) this.bullets = this.bullets.filter(alive);
    if (this.orbs.some(function (o) { return o.dead; })) this.orbs = this.orbs.filter(alive);
    if (this.particles.some(function (p) { return p.life <= 0; })) this.particles = this.particles.filter(living);
    if (this.labels.some(function (l) { return l.life <= 0; })) this.labels = this.labels.filter(living);
  };

  global.GameEngine = GameEngine;
})(window);
