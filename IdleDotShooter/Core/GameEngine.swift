import CoreGraphics
import Foundation

/// The simulation. Owns every entity on the field, advances them once per
/// frame, and reports earnings back to `GameState`.
///
/// It publishes at frame rate — only the canvas observes it.
final class GameEngine: ObservableObject {

    private unowned let state: GameState

    private(set) var dots: [DotEntity] = []
    private(set) var bullets: [BulletEntity] = []
    private(set) var orbs: [OrbEntity] = []
    private(set) var drones: [DroneEntity] = []
    private(set) var particles: [ParticleEntity] = []
    private(set) var labels: [FloatingLabel] = []
    private(set) var singularity: Singularity?

    private(set) var fieldSize: CGSize = .zero
    private(set) var turret = CGPoint(x: 0, y: 0)
    private(set) var turretAngle: Double = -.pi / 2
    private(set) var muzzleFlash: Double = 0
    private(set) var screenShake: Double = 0

    /// Height of the strip at the bottom reserved for the turret.
    private let turretMargin: Double = 96

    private var nextID = 1
    private var spawnAccumulator: Double = 0
    private var fireAccumulator: Double = 0
    private var rainRemaining: Double = 0
    private var rainRate: Double = 0
    private var rainAccumulator: Double = 0
    private var grid = SpatialGrid()

    private var incomeAccumulator: Double = 0
    private var incomeWindow: Double = 0
    private var knownResetToken = -1

    init(state: GameState) {
        self.state = state
        knownResetToken = state.fieldResetToken
    }

    // MARK: Layout

    var playHeight: Double {
        max(120, Double(fieldSize.height) - turretMargin)
    }

    func updateFieldSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let changed = abs(size.width - fieldSize.width) > 0.5 || abs(size.height - fieldSize.height) > 0.5
        fieldSize = size
        turret = CGPoint(x: size.width / 2, y: size.height - 54)
        if changed {
            clampEntities()
            if drones.isEmpty { syncDrones() }
        }
    }

    // MARK: Frame

    func update(dt rawDT: Double) {
        guard fieldSize.width > 1, fieldSize.height > 1 else { return }
        let dt = min(rawDT, 1.0 / 20.0)

        if state.fieldResetToken != knownResetToken {
            knownResetToken = state.fieldResetToken
            resetField()
        }

        state.stats.timeActive += dt
        state.tickCombo(dt)

        updateAbilities(dt)
        syncDrones()
        spawnDots(dt)
        updateDots(dt)
        updateTurret(dt)
        updateBullets(dt)
        updateOrbs(dt)
        updateDrones(dt)
        updateParticles(dt)
        updateLabels(dt)

        if state.derived.idleIncome > 0 {
            award(state.derived.idleIncome * dt)
        }

        muzzleFlash = max(0, muzzleFlash - dt * 6)
        screenShake = max(0, screenShake - dt * 4)

        compact()
        trackIncome(dt)
    }

    private func trackIncome(_ dt: Double) {
        incomeWindow += dt
        guard incomeWindow >= 1 else { return }
        let perSecond = incomeAccumulator / incomeWindow
        state.recentIncomePerSecond = state.recentIncomePerSecond > 0
            ? state.recentIncomePerSecond * 0.65 + perSecond * 0.35
            : perSecond
        incomeAccumulator = 0
        incomeWindow = 0
        state.setNeedsRefresh()
    }

    private func award(_ amount: Double) {
        guard amount > 0 else { return }
        state.award(cash: amount)
        incomeAccumulator += amount
    }

    // MARK: Field reset

    func resetField() {
        dots.removeAll(keepingCapacity: true)
        bullets.removeAll(keepingCapacity: true)
        orbs.removeAll(keepingCapacity: true)
        particles.removeAll(keepingCapacity: true)
        labels.removeAll(keepingCapacity: true)
        singularity = nil
        rainRemaining = 0
        spawnAccumulator = 0
        fireAccumulator = 0
        syncDrones()
        // Give the new galaxy a head start so the field is never empty on arrival.
        let prefill = max(3, state.derived.capacity / 2)
        for _ in 0..<prefill { spawnDot() }
    }

    private func clampEntities() {
        let maxY = playHeight
        for index in dots.indices {
            dots[index].x = min(max(dots[index].radius, dots[index].x), Double(fieldSize.width) - dots[index].radius)
            dots[index].y = min(max(dots[index].radius, dots[index].y), maxY - dots[index].radius)
        }
    }

    // MARK: Dots

    private func spawnDots(_ dt: Double) {
        let capacity = state.derived.capacity

        if rainRemaining > 0 {
            rainRemaining = max(0, rainRemaining - dt)
            rainAccumulator += dt * rainRate
            while rainAccumulator >= 1 && dots.count < GameBalance.maxDots {
                rainAccumulator -= 1
                spawnDot(fromRain: true)
            }
        }

        guard dots.count < capacity else { return }
        spawnAccumulator += dt * state.derived.spawnRate
        var budget = 0
        while spawnAccumulator >= 1 && dots.count < capacity && budget < 12 {
            spawnAccumulator -= 1
            spawnDot()
            budget += 1
        }
        if spawnAccumulator > 4 { spawnAccumulator = 4 }
    }

    @discardableResult
    private func spawnDot(fromRain: Bool = false) -> Int {
        guard dots.count < GameBalance.maxDots else { return -1 }
        let d = state.derived
        let rarity = Rarity.roll(luck: d.luck)
        let golden = Double.random(in: 0..<1) < d.goldenChance

        let radius = rarity.radius * (golden ? 1.15 : 1)
        let width = Double(fieldSize.width)
        let height = playHeight

        let health = GameBalance.baseDotHealth
            * d.dotHealthScale
            * rarity.healthMultiplier
            * (golden ? 3 : 1)

        let value = GameBalance.baseDotValue
            * d.dotValueScale
            * rarity.valueMultiplier
            * d.valueMultiplier
            * (golden ? 25 : 1)

        let speed = Double.random(in: 14...40) * d.driftScale
        let angle = Double.random(in: 0..<(2 * .pi))

        let dot = DotEntity(id: takeID(),
                            x: Double.random(in: radius...(max(radius + 1, width - radius))),
                            y: fromRain
                                ? Double.random(in: radius...max(radius + 1, height * 0.35))
                                : Double.random(in: radius...(max(radius + 1, height - radius))),
                            vx: cos(angle) * speed,
                            vy: sin(angle) * speed,
                            radius: radius,
                            health: health,
                            maxHealth: health,
                            rarity: rarity,
                            golden: golden,
                            value: value,
                            phase: Double.random(in: 0..<(2 * .pi)))
        dots.append(dot)
        return dot.id
    }

    private func updateDots(_ dt: Double) {
        let width = Double(fieldSize.width)
        let height = playHeight
        let wander = state.derived.wanderScale

        var singularityPull: (x: Double, y: Double, force: Double)?
        if let hole = singularity {
            singularityPull = (hole.x, hole.y, hole.pull)
        }

        for index in dots.indices {
            var dot = dots[index]
            guard !dot.dead else { continue }

            if wander > 0 {
                dot.vx += Double.random(in: -28...28) * wander * dt
                dot.vy += Double.random(in: -28...28) * wander * dt
                let speed = (dot.vx * dot.vx + dot.vy * dot.vy).squareRoot()
                let cap = 90.0
                if speed > cap {
                    dot.vx = dot.vx / speed * cap
                    dot.vy = dot.vy / speed * cap
                }
            }

            if let pull = singularityPull {
                let dx = pull.x - dot.x
                let dy = pull.y - dot.y
                let distance = max(6, (dx * dx + dy * dy).squareRoot())
                let force = pull.force / distance
                dot.vx += dx / distance * force * dt
                dot.vy += dy / distance * force * dt

                if distance < 26 {
                    dots[index] = dot
                    consumeBySingularity(index)
                    continue
                }
            }

            dot.x += dot.vx * dt
            dot.y += dot.vy * dt
            dot.phase += dt * 2

            if dot.x < dot.radius { dot.x = dot.radius; dot.vx = abs(dot.vx) }
            if dot.x > width - dot.radius { dot.x = width - dot.radius; dot.vx = -abs(dot.vx) }
            if dot.y < dot.radius { dot.y = dot.radius; dot.vy = abs(dot.vy) }
            if dot.y > height - dot.radius { dot.y = height - dot.radius; dot.vy = -abs(dot.vy) }

            dot.flash = max(0, dot.flash - dt * 7)
            dots[index] = dot
        }
    }

    // MARK: Turret

    private var effectiveFireRate: Double {
        var rate = state.derived.fireRate
        let frenzy = state.ability(.frenzy)
        if frenzy.isActive {
            let def = AbilityCatalog.def(.frenzy)
            rate *= def.potency(level: frenzy.level, power: state.abilityPower)
        }
        return max(0.1, rate)
    }

    private var effectiveMultishot: Int {
        var shots = state.derived.multishot
        if state.ability(.frenzy).isActive { shots += 3 }
        return min(48, max(1, shots))
    }

    private func updateTurret(_ dt: Double) {
        guard let targetIndex = nearestDotIndex(to: turret) else { return }

        let target = dots[targetIndex]
        let lead = leadPoint(for: target)
        let desired = atan2(lead.y - Double(turret.y), lead.x - Double(turret.x))
        turretAngle = turnToward(turretAngle, desired, rate: 14 * dt)

        fireAccumulator += dt * effectiveFireRate
        var volleys = 0
        while fireAccumulator >= 1 && volleys < 8 {
            fireAccumulator -= 1
            fireVolley(at: desired)
            volleys += 1
        }
        if fireAccumulator > 3 { fireAccumulator = 3 }
    }

    /// Aims slightly ahead of a drifting dot so fast targets still get hit.
    private func leadPoint(for dot: DotEntity) -> (x: Double, y: Double) {
        let speed = max(60, state.derived.bulletSpeed)
        let dx = dot.x - Double(turret.x)
        let dy = dot.y - Double(turret.y)
        let time = (dx * dx + dy * dy).squareRoot() / speed
        return (dot.x + dot.vx * time, dot.y + dot.vy * time)
    }

    private func fireVolley(at angle: Double) {
        guard bullets.count < GameBalance.maxBullets else { return }
        let d = state.derived
        let count = effectiveMultishot
        let spread = min(1.05, Double(count - 1) * 0.085)
        let start = angle - spread / 2
        let step = count > 1 ? spread / Double(count - 1) : 0

        for index in 0..<count {
            guard bullets.count < GameBalance.maxBullets else { break }
            let theta = start + step * Double(index)
            let crit = Double.random(in: 0..<1) < d.critChance
            let damage = d.damage * (crit ? d.critDamage : 1)

            bullets.append(BulletEntity(id: takeID(),
                                        x: Double(turret.x) + cos(theta) * 26,
                                        y: Double(turret.y) + sin(theta) * 26,
                                        vx: cos(theta) * d.bulletSpeed,
                                        vy: sin(theta) * d.bulletSpeed,
                                        damage: damage,
                                        isCrit: crit,
                                        pierceLeft: d.pierce,
                                        life: 3.0,
                                        radius: crit ? 4.2 : 3.2))
            state.stats.shotsFired += 1
        }

        muzzleFlash = 1
        if state.settings.haptics && count >= 8 {
            Feedback.shared.tap(.light, throttle: 0.14)
        }
    }

    private func turnToward(_ current: Double, _ target: Double, rate: Double) -> Double {
        var delta = target - current
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return current + delta * min(1, rate)
    }

    private func nearestDotIndex(to point: CGPoint) -> Int? {
        var best: Int?
        var bestDistance = Double.greatestFiniteMagnitude
        for index in dots.indices where !dots[index].dead {
            let dx = dots[index].x - Double(point.x)
            let dy = dots[index].y - Double(point.y)
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    // MARK: Bullets

    private func updateBullets(_ dt: Double) {
        guard !bullets.isEmpty else { return }
        grid.rebuild(width: Double(fieldSize.width), height: playHeight, dots: dots)

        let width = Double(fieldSize.width)
        let height = playHeight

        for index in bullets.indices {
            var bullet = bullets[index]
            guard !bullet.dead else { continue }

            bullet.x += bullet.vx * dt
            bullet.y += bullet.vy * dt
            bullet.life -= dt
            bullet.hitCooldown = max(0, bullet.hitCooldown - dt)

            if bullet.life <= 0 || bullet.x < -20 || bullet.x > width + 20 || bullet.y < -20 || bullet.y > height + 60 {
                bullet.dead = true
                bullets[index] = bullet
                continue
            }

            if bullet.hitCooldown <= 0 {
                var hitIndex = -1
                grid.forEachCandidate(x: bullet.x, y: bullet.y) { candidate in
                    guard candidate < self.dots.count else { return true }
                    let dot = self.dots[candidate]
                    guard !dot.dead, dot.id != bullet.lastHitID else { return true }
                    let dx = dot.x - bullet.x
                    let dy = dot.y - bullet.y
                    let reach = dot.radius + bullet.radius
                    if dx * dx + dy * dy <= reach * reach {
                        hitIndex = candidate
                        return false
                    }
                    return true
                }

                if hitIndex >= 0 {
                    bullet.lastHitID = dots[hitIndex].id
                    bullet.hitCooldown = 0.03
                    state.stats.bulletsHit += 1
                    if bullet.isCrit { state.stats.criticalHits += 1 }
                    state.stats.biggestSingleHit = max(state.stats.biggestSingleHit, bullet.damage)

                    if bullet.isCrit && state.settings.damageNumbers {
                        addLabel(text: Fmt.number(bullet.damage),
                                 x: dots[hitIndex].x,
                                 y: dots[hitIndex].y - dots[hitIndex].radius - 4,
                                 palette: .amber,
                                 emphasised: false)
                    }

                    applyDamage(to: hitIndex, amount: bullet.damage, allowSplash: true)

                    if bullet.pierceLeft > 0 {
                        bullet.pierceLeft -= 1
                    } else {
                        bullet.dead = true
                    }
                }
            }

            bullets[index] = bullet
        }
    }

    private func applyDamage(to index: Int, amount: Double, allowSplash: Bool) {
        guard index < dots.count, !dots[index].dead else { return }
        dots[index].health -= amount
        dots[index].flash = 1

        guard dots[index].health <= 0 else { return }
        kill(index, allowSplash: allowSplash)
    }

    private func kill(_ index: Int, allowSplash: Bool) {
        guard index < dots.count, !dots[index].dead else { return }
        var dot = dots[index]
        dot.dead = true
        dots[index] = dot

        let payout = dot.value * state.comboMultiplier
        state.registerKill(rarity: dot.rarity, golden: dot.golden)
        spawnOrb(from: dot, value: payout)
        spawnPopParticles(for: dot)

        if dot.golden || dot.rarity.rawValue >= Rarity.epic.rawValue {
            if state.settings.damageNumbers {
                addLabel(text: Fmt.cash(payout),
                         x: dot.x, y: dot.y,
                         palette: dot.golden ? .gold : dot.rarity.palette,
                         emphasised: true)
            }
            Feedback.shared.tap(.medium, throttle: 0.2)
        }

        if allowSplash && state.derived.explosiveRadius > 0 {
            splash(from: dot)
        }
    }

    private func splash(from dot: DotEntity) {
        let radius = state.derived.explosiveRadius
        let damage = state.derived.damage * 0.6
        let radiusSquared = radius * radius

        for index in dots.indices where !dots[index].dead {
            let dx = dots[index].x - dot.x
            let dy = dots[index].y - dot.y
            guard dx * dx + dy * dy <= radiusSquared else { continue }
            applyDamage(to: index, amount: damage, allowSplash: false)
        }

        if state.settings.particles {
            appendParticle(x: dot.x, y: dot.y, vx: 0, vy: 0,
                           life: 0.28, radius: radius, rgb: (1, 0.55, 0.2))
        }
    }

    private func consumeBySingularity(_ index: Int) {
        guard index < dots.count, !dots[index].dead else { return }
        guard let hole = singularity else { return }
        var dot = dots[index]
        dot.dead = true
        dots[index] = dot

        state.registerKill(rarity: dot.rarity, golden: dot.golden)
        award(dot.value * state.comboMultiplier * hole.payoutMultiplier)
        spawnPopParticles(for: dot)
    }

    // MARK: Orbs

    private func spawnOrb(from dot: DotEntity, value: Double) {
        guard orbs.count < GameBalance.maxOrbs else {
            // Field is saturated — bank it rather than dropping it on the floor.
            award(value * (1 + state.derived.droneBonus) * state.shopDropMultiplier)
            return
        }
        let life = state.derived.orbLifetime
        let angle = Double.random(in: 0..<(2 * .pi))
        let speed = Double.random(in: 10...45)
        orbs.append(OrbEntity(id: takeID(),
                              x: dot.x,
                              y: dot.y,
                              vx: cos(angle) * speed,
                              vy: sin(angle) * speed,
                              value: value,
                              life: life,
                              maxLife: life,
                              radius: dot.golden ? 7 : 5,
                              golden: dot.golden))
    }

    private func updateOrbs(_ dt: Double) {
        guard !orbs.isEmpty else { return }
        let width = Double(fieldSize.width)
        let height = playHeight
        let suction = state.derived.droneSuction
        let magnet = state.derived.droneMagnet

        for index in orbs.indices {
            var orb = orbs[index]
            guard !orb.dead else { continue }

            // Pull towards the closest drone that has it in range.
            var bestDistance = Double.greatestFiniteMagnitude
            var pullX = 0.0
            var pullY = 0.0
            for drone in drones {
                let dx = drone.x - orb.x
                let dy = drone.y - orb.y
                let distance = (dx * dx + dy * dy).squareRoot()
                if distance < bestDistance {
                    bestDistance = distance
                    pullX = dx
                    pullY = dy
                }
            }

            if bestDistance <= suction && bestDistance > 0.001 {
                let strength = magnet * (1 - bestDistance / max(1, suction)) + magnet * 0.35
                orb.vx += pullX / bestDistance * strength * dt
                orb.vy += pullY / bestDistance * strength * dt
            } else {
                orb.vx *= (1 - min(1, dt * 1.4))
                orb.vy *= (1 - min(1, dt * 1.4))
            }

            if let hole = singularity {
                let dx = hole.x - orb.x
                let dy = hole.y - orb.y
                let distance = max(6, (dx * dx + dy * dy).squareRoot())
                orb.vx += dx / distance * hole.pull * 0.6 * dt
                orb.vy += dy / distance * hole.pull * 0.6 * dt
            }

            orb.x += orb.vx * dt
            orb.y += orb.vy * dt
            orb.life -= dt

            orb.x = min(max(orb.radius, orb.x), max(orb.radius + 1, width - orb.radius))
            orb.y = min(max(orb.radius, orb.y), max(orb.radius + 1, height - orb.radius))

            if orb.life <= 0 {
                orb.dead = true
                // Fading orbs still bank a fraction — upgrade the drone to keep the rest.
                award(orb.value * 0.2)
                state.stats.orbsLost += 1
            }

            orbs[index] = orb
        }
    }

    private func collect(_ index: Int) {
        guard index < orbs.count, !orbs[index].dead else { return }
        var orb = orbs[index]
        orb.dead = true
        orbs[index] = orb

        let payout = orb.value * (1 + state.derived.droneBonus) * state.shopDropMultiplier
        award(payout)
        state.stats.orbsCollected += 1

        if state.settings.particles {
            appendParticle(x: orb.x, y: orb.y, vx: 0, vy: -30,
                           life: 0.3, radius: 6,
                           rgb: orb.golden ? DotPalette.goldenRGB : (0.4, 0.96, 0.76))
        }
    }

    // MARK: Drones

    private func syncDrones() {
        let wanted = max(1, state.derived.droneCount)
        guard fieldSize.width > 1 else { return }

        while drones.count > wanted { drones.removeLast() }
        while drones.count < wanted {
            let index = drones.count
            drones.append(DroneEntity(id: takeID(),
                                      x: Double(fieldSize.width) * 0.5 + Double(index) * 24,
                                      y: playHeight * 0.65,
                                      vx: 0,
                                      vy: 0,
                                      angle: -.pi / 2,
                                      idlePhase: Double(index) * 1.9))
        }
    }

    private func updateDrones(_ dt: Double) {
        let d = state.derived
        let width = Double(fieldSize.width)
        let height = playHeight
        let maxSpeed = d.droneSpeed
        let accel = maxSpeed * d.droneAgility
        let collectRadius = d.droneSize + 6

        for index in drones.indices {
            var drone = drones[index]

            var targetX = width / 2 + cos(drone.idlePhase) * width * 0.3
            var targetY = height / 2 + sin(drone.idlePhase * 0.7) * height * 0.3
            var hasTarget = false

            // Prefer the orb that is closest to this drone and not already the
            // target of a nearer one.
            var bestIndex = -1
            var bestDistance = Double.greatestFiniteMagnitude
            for orbIndex in orbs.indices where !orbs[orbIndex].dead {
                let orb = orbs[orbIndex]
                if isClaimedByCloserDrone(orbIndex: orbIndex, by: index) { continue }
                let dx = orb.x - drone.x
                let dy = orb.y - drone.y
                let distance = dx * dx + dy * dy
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = orbIndex
                }
            }

            if bestIndex >= 0 {
                targetX = orbs[bestIndex].x
                targetY = orbs[bestIndex].y
                drone.targetOrbID = orbs[bestIndex].id
                hasTarget = true
            } else {
                drone.targetOrbID = -1
                drone.idlePhase += dt * 0.6
            }

            let dx = targetX - drone.x
            let dy = targetY - drone.y
            let distance = max(0.001, (dx * dx + dy * dy).squareRoot())
            drone.vx += dx / distance * accel * dt
            drone.vy += dy / distance * accel * dt

            let speed = (drone.vx * drone.vx + drone.vy * drone.vy).squareRoot()
            if speed > maxSpeed {
                drone.vx = drone.vx / speed * maxSpeed
                drone.vy = drone.vy / speed * maxSpeed
            }

            drone.x += drone.vx * dt
            drone.y += drone.vy * dt
            drone.x = min(max(8, drone.x), max(9, width - 8))
            drone.y = min(max(8, drone.y), max(9, height - 8))

            if speed > 1 { drone.angle = atan2(drone.vy, drone.vx) }
            drones[index] = drone

            guard hasTarget else { continue }
            for orbIndex in orbs.indices where !orbs[orbIndex].dead {
                let orb = orbs[orbIndex]
                let ox = orb.x - drone.x
                let oy = orb.y - drone.y
                let reach = collectRadius + orb.radius
                if ox * ox + oy * oy <= reach * reach {
                    collect(orbIndex)
                }
            }
        }
    }

    private func isClaimedByCloserDrone(orbIndex: Int, by droneIndex: Int) -> Bool {
        let orb = orbs[orbIndex]
        let me = drones[droneIndex]
        let myDX = orb.x - me.x
        let myDY = orb.y - me.y
        let myDistance = myDX * myDX + myDY * myDY

        for (index, other) in drones.enumerated() where index < droneIndex {
            guard other.targetOrbID == orb.id else { continue }
            let dx = orb.x - other.x
            let dy = orb.y - other.y
            if dx * dx + dy * dy <= myDistance { return true }
        }
        return false
    }

    // MARK: Abilities

    private func updateAbilities(_ dt: Double) {
        var running = false

        for id in AbilityID.allCases {
            var ability = state.ability(id)
            guard ability.unlocked else { continue }

            if ability.activeRemaining > 0 {
                ability.activeRemaining = max(0, ability.activeRemaining - dt)
                running = true
            } else if ability.cooldownRemaining > 0 {
                ability.cooldownRemaining = max(0, ability.cooldownRemaining - dt)
                running = true
            }
            state.setAbility(id, ability)
        }

        if var hole = singularity {
            hole.remaining -= dt
            if hole.remaining <= 0 {
                singularity = nil
            } else {
                singularity = hole
            }
        }

        if state.autoCastUnlocked && state.autoCastEnabled {
            for id in AbilityID.allCases where state.ability(id).isReady {
                cast(id)
            }
        }

        if running { state.setNeedsRefresh() }
    }

    @discardableResult
    func cast(_ id: AbilityID) -> Bool {
        var ability = state.ability(id)
        guard ability.isReady else {
            Feedback.shared.play(.denied)
            return false
        }

        let def = AbilityCatalog.def(id)
        let duration = def.duration(level: ability.level)
        ability.activeRemaining = duration
        ability.cooldownRemaining = def.cooldown(level: ability.level,
                                                 reduction: state.abilityCooldownReduction)
        state.setAbility(id, ability)

        let potency = def.potency(level: ability.level, power: state.abilityPower)

        switch id {
        case .frenzy:
            state.stats.frenzyCasts += 1
            screenShake = 1
            addLabel(text: "FRENZY", x: Double(turret.x), y: playHeight * 0.5,
                     palette: .orange, emphasised: true)

        case .dotRain:
            state.stats.dotRainCasts += 1
            rainRemaining = duration
            rainRate = potency / max(0.5, duration)
            rainAccumulator = 0
            addLabel(text: "DOT RAIN", x: Double(fieldSize.width) / 2, y: playHeight * 0.35,
                     palette: .cyan, emphasised: true)

        case .blackHole:
            state.stats.blackHoleCasts += 1
            singularity = Singularity(x: Double(fieldSize.width) / 2,
                                      y: playHeight * 0.45,
                                      remaining: duration,
                                      duration: duration,
                                      pull: 900,
                                      payoutMultiplier: potency)
            screenShake = 1
            addLabel(text: "BLACK HOLE", x: Double(fieldSize.width) / 2, y: playHeight * 0.2,
                     palette: .purple, emphasised: true)
        }

        state.stats.abilitiesCast += 1
        state.publishNow()
        Feedback.shared.tap(.heavy)
        Feedback.shared.play(.ability)
        return true
    }

    // MARK: Particles and labels

    private func spawnPopParticles(for dot: DotEntity) {
        guard state.settings.particles else { return }
        let theme = state.equipped(.dots).variant
        let rgb = DotPalette.rgb(for: dot.rarity, golden: dot.golden, themeVariant: theme)
        let count = min(10, 4 + dot.rarity.rawValue * 2)

        for _ in 0..<count {
            guard particles.count < GameBalance.maxParticles else { return }
            let angle = Double.random(in: 0..<(2 * .pi))
            let speed = Double.random(in: 40...170)
            appendParticle(x: dot.x, y: dot.y,
                           vx: cos(angle) * speed,
                           vy: sin(angle) * speed,
                           life: Double.random(in: 0.25...0.55),
                           radius: Double.random(in: 1.5...3.4),
                           rgb: rgb)
        }
    }

    private func appendParticle(x: Double, y: Double, vx: Double, vy: Double,
                                life: Double, radius: Double,
                                rgb: (Double, Double, Double)) {
        guard particles.count < GameBalance.maxParticles else { return }
        particles.append(ParticleEntity(x: x, y: y, vx: vx, vy: vy,
                                        life: life, maxLife: life, radius: radius,
                                        red: rgb.0, green: rgb.1, blue: rgb.2))
    }

    private func updateParticles(_ dt: Double) {
        guard !particles.isEmpty else { return }
        for index in particles.indices {
            particles[index].x += particles[index].vx * dt
            particles[index].y += particles[index].vy * dt
            particles[index].vx *= (1 - min(1, dt * 2.6))
            particles[index].vy *= (1 - min(1, dt * 2.6))
            particles[index].life -= dt
        }
    }

    private func addLabel(text: String, x: Double, y: Double,
                          palette: PaletteColor, emphasised: Bool) {
        guard labels.count < GameBalance.maxFloatingLabels else { return }
        let life = emphasised ? 1.1 : 0.7
        labels.append(FloatingLabel(id: takeID(),
                                    x: x, y: y,
                                    vy: emphasised ? -46 : -34,
                                    text: text,
                                    life: life,
                                    maxLife: life,
                                    palette: palette,
                                    emphasised: emphasised))
    }

    private func updateLabels(_ dt: Double) {
        guard !labels.isEmpty else { return }
        for index in labels.indices {
            labels[index].y += labels[index].vy * dt
            labels[index].life -= dt
        }
    }

    // MARK: Housekeeping

    private func compact() {
        if dots.contains(where: { $0.dead }) { dots.removeAll { $0.dead } }
        if bullets.contains(where: { $0.dead }) { bullets.removeAll { $0.dead } }
        if orbs.contains(where: { $0.dead }) { orbs.removeAll { $0.dead } }
        if particles.contains(where: { $0.life <= 0 }) { particles.removeAll { $0.life <= 0 } }
        if labels.contains(where: { $0.life <= 0 }) { labels.removeAll { $0.life <= 0 } }
    }

    private func takeID() -> Int {
        nextID += 1
        return nextID
    }
}
