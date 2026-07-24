import SwiftUI

/// Draws every live entity. Re-renders once per engine frame; nothing else in
/// the app observes the engine, so the HUD is not dragged along at 60 Hz.
struct FieldCanvas: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject var state: GameState

    var body: some View {
        GeometryReader { geo in
            Canvas(rendersAsynchronously: false) { context, size in
                draw(context: &context, size: size)
            }
            .onAppear { engine.updateFieldSize(geo.size) }
            .onChange(of: geo.size) { newSize in engine.updateFieldSize(newSize) }
        }
    }

    // MARK: Drawing

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let shake = engine.screenShake
        if shake > 0.01 && !state.settings.reducedMotion {
            let amount = CGFloat(shake * 5)
            context.translateBy(x: CGFloat.random(in: -amount...amount),
                                y: CGFloat.random(in: -amount...amount))
        }

        drawSingularity(&context)
        drawOrbs(&context)
        drawDots(&context)
        drawBullets(&context)
        drawDrones(&context)
        drawParticles(&context)
        drawTurret(&context, size: size)
        drawLabels(&context)
    }

    // MARK: Dots

    private func drawDots(_ context: inout GraphicsContext) {
        let themeVariant = state.equipped(.dots).variant

        for dot in engine.dots where !dot.dead {
            let rgb = DotPalette.rgb(for: dot.rarity, golden: dot.golden, themeVariant: themeVariant)
            let base = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
            let pulse = state.settings.reducedMotion ? 0 : sin(dot.phase) * 0.06
            let radius = dot.radius * (1 + pulse)
            let rect = CGRect(x: dot.x - radius, y: dot.y - radius,
                              width: radius * 2, height: radius * 2)

            if dot.golden || dot.rarity.rawValue >= Rarity.legendary.rawValue {
                let glowRect = rect.insetBy(dx: -radius * 0.9, dy: -radius * 0.9)
                context.fill(Path(ellipseIn: glowRect),
                             with: .radialGradient(Gradient(colors: [base.opacity(0.35), .clear]),
                                                   center: CGPoint(x: dot.x, y: dot.y),
                                                   startRadius: radius * 0.4,
                                                   endRadius: radius * 1.9))
            }

            context.fill(Path(ellipseIn: rect), with: .color(base.opacity(0.92)))

            // Inner highlight gives the dots a bit of volume.
            let inner = CGRect(x: dot.x - radius * 0.42 - radius * 0.16,
                               y: dot.y - radius * 0.42 - radius * 0.16,
                               width: radius * 0.84, height: radius * 0.84)
            context.fill(Path(ellipseIn: inner), with: .color(.white.opacity(0.22)))

            if dot.flash > 0.01 {
                context.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(min(0.75, dot.flash * 0.75))))
            }

            // Health ring, only once the dot has taken a hit.
            let fraction = dot.healthFraction
            if fraction < 0.999 {
                let ringRect = rect.insetBy(dx: -3.5, dy: -3.5)
                var ring = Path()
                ring.addArc(center: CGPoint(x: dot.x, y: dot.y),
                            radius: ringRect.width / 2,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * fraction),
                            clockwise: false)
                context.stroke(ring, with: .color(.white.opacity(0.8)), lineWidth: 2)
            }
        }
    }

    // MARK: Bullets

    private func drawBullets(_ context: inout GraphicsContext) {
        guard !engine.bullets.isEmpty else { return }
        let trail = state.equipped(.trail)
        let core = trail.primary.color
        let tail = trail.secondary.color
        let length: Double = trail.variant == 1 ? 22 : (trail.variant == 3 ? 26 : 16)
        let width: Double = trail.variant == 1 ? 4.4 : 2.6

        var trailPath = Path()
        for bullet in engine.bullets where !bullet.dead {
            let speed = max(1, (bullet.vx * bullet.vx + bullet.vy * bullet.vy).squareRoot())
            let backX = bullet.x - bullet.vx / speed * length
            let backY = bullet.y - bullet.vy / speed * length
            trailPath.move(to: CGPoint(x: backX, y: backY))
            trailPath.addLine(to: CGPoint(x: bullet.x, y: bullet.y))
        }
        context.stroke(trailPath, with: .color(tail.opacity(0.5)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round))

        for bullet in engine.bullets where !bullet.dead {
            let radius = bullet.radius
            let rect = CGRect(x: bullet.x - radius, y: bullet.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect),
                         with: .color(bullet.isCrit ? PaletteColor.amber.color : core))
        }
    }

    // MARK: Orbs

    private func drawOrbs(_ context: inout GraphicsContext) {
        for orb in engine.orbs where !orb.dead {
            let fade = min(1, orb.life / max(0.01, orb.maxLife * 0.35))
            let color = orb.golden ? PaletteColor.gold.color : PaletteColor.mint.color
            let radius = orb.radius
            let rect = CGRect(x: orb.x - radius, y: orb.y - radius,
                              width: radius * 2, height: radius * 2)

            context.fill(Path(ellipseIn: rect.insetBy(dx: -radius, dy: -radius)),
                         with: .radialGradient(Gradient(colors: [color.opacity(0.4 * fade), .clear]),
                                               center: CGPoint(x: orb.x, y: orb.y),
                                               startRadius: 0,
                                               endRadius: radius * 2.4))
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(fade)))
        }
    }

    // MARK: Drones

    private func drawDrones(_ context: inout GraphicsContext) {
        let cosmetic = state.equipped(.drone)
        let body = cosmetic.primary.color
        let accent = cosmetic.secondary.color
        let size = state.derived.droneSize
        let suction = state.derived.droneSuction

        for drone in engine.drones {
            // Suction field
            let fieldRect = CGRect(x: drone.x - suction, y: drone.y - suction,
                                   width: suction * 2, height: suction * 2)
            context.stroke(Path(ellipseIn: fieldRect),
                           with: .color(body.opacity(0.12)),
                           lineWidth: 1)

            var hull = context
            hull.translateBy(x: drone.x, y: drone.y)
            hull.rotate(by: .radians(drone.angle))

            let rect = CGRect(x: -size, y: -size * 0.7, width: size * 2, height: size * 1.4)

            switch cosmetic.variant {
            case 2: // Orbital — concentric rings
                hull.stroke(Path(ellipseIn: CGRect(x: -size, y: -size, width: size * 2, height: size * 2)),
                            with: .color(accent.opacity(0.7)), lineWidth: 2)
                hull.fill(Path(ellipseIn: CGRect(x: -size * 0.5, y: -size * 0.5,
                                                 width: size, height: size)),
                          with: .color(body))
            case 4: // Starling — diamond
                var diamond = Path()
                diamond.move(to: CGPoint(x: size, y: 0))
                diamond.addLine(to: CGPoint(x: 0, y: size * 0.8))
                diamond.addLine(to: CGPoint(x: -size, y: 0))
                diamond.addLine(to: CGPoint(x: 0, y: -size * 0.8))
                diamond.closeSubpath()
                hull.fill(diamond, with: .color(body))
                hull.stroke(diamond, with: .color(accent.opacity(0.9)), lineWidth: 1.5)
            default:
                hull.fill(Path(roundedRect: rect, cornerRadius: size * 0.5), with: .color(body))
                hull.fill(Path(ellipseIn: CGRect(x: size * 0.1, y: -size * 0.25,
                                                 width: size * 0.5, height: size * 0.5)),
                          with: .color(accent))
            }
        }
    }

    // MARK: Particles

    private func drawParticles(_ context: inout GraphicsContext) {
        for particle in engine.particles where particle.life > 0 {
            let alpha = max(0, particle.life / max(0.01, particle.maxLife))
            let radius = particle.radius * (0.4 + alpha * 0.6)
            let rect = CGRect(x: particle.x - radius, y: particle.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect),
                         with: .color(Color(red: particle.red,
                                            green: particle.green,
                                            blue: particle.blue).opacity(alpha)))
        }
    }

    // MARK: Singularity

    private func drawSingularity(_ context: inout GraphicsContext) {
        guard let hole = engine.singularity else { return }
        let radius = 30 + sin(hole.progress * .pi) * 46
        let center = CGPoint(x: hole.x, y: hole.y)

        context.fill(Path(ellipseIn: CGRect(x: hole.x - radius * 2.6, y: hole.y - radius * 2.6,
                                            width: radius * 5.2, height: radius * 5.2)),
                     with: .radialGradient(Gradient(colors: [PaletteColor.purple.color.opacity(0.45),
                                                             PaletteColor.violet.color.opacity(0.12),
                                                             .clear]),
                                           center: center,
                                           startRadius: radius * 0.5,
                                           endRadius: radius * 2.6))

        context.fill(Path(ellipseIn: CGRect(x: hole.x - radius, y: hole.y - radius,
                                            width: radius * 2, height: radius * 2)),
                     with: .color(.black.opacity(0.92)))

        context.stroke(Path(ellipseIn: CGRect(x: hole.x - radius * 1.15, y: hole.y - radius * 1.15,
                                              width: radius * 2.3, height: radius * 2.3)),
                       with: .color(PaletteColor.magenta.color.opacity(0.8)),
                       lineWidth: 2.5)
    }

    // MARK: Turret

    private func drawTurret(_ context: inout GraphicsContext, size: CGSize) {
        let cosmetic = state.equipped(.turret)
        let body = cosmetic.primary.color
        let accent = cosmetic.secondary.color
        let origin = engine.turret

        // Base plate
        let baseRadius: Double = 24
        context.fill(Path(ellipseIn: CGRect(x: Double(origin.x) - baseRadius,
                                            y: Double(origin.y) - baseRadius,
                                            width: baseRadius * 2, height: baseRadius * 2)),
                     with: .radialGradient(Gradient(colors: [body.opacity(0.30), .clear]),
                                           center: origin,
                                           startRadius: 2,
                                           endRadius: baseRadius))

        var turret = context
        turret.translateBy(x: Double(origin.x), y: Double(origin.y))
        turret.rotate(by: .radians(engine.turretAngle))

        let barrelLength: Double = cosmetic.variant == 2 ? 34 : 28
        let barrelWidth: Double = cosmetic.variant == 6 ? 13 : 9

        switch cosmetic.variant {
        case 3, 5: // Void Caster / Bloom — split prongs
            for offset in [-barrelWidth * 0.55, barrelWidth * 0.55] {
                turret.fill(Path(roundedRect: CGRect(x: 4, y: offset - 2.4,
                                                     width: barrelLength, height: 4.8),
                                 cornerRadius: 2.4),
                            with: .color(body))
            }
        case 7: // Prism — tapered
            var wedge = Path()
            wedge.move(to: CGPoint(x: 6, y: -barrelWidth / 2))
            wedge.addLine(to: CGPoint(x: barrelLength, y: -2))
            wedge.addLine(to: CGPoint(x: barrelLength, y: 2))
            wedge.addLine(to: CGPoint(x: 6, y: barrelWidth / 2))
            wedge.closeSubpath()
            turret.fill(wedge, with: .color(body))
        default:
            turret.fill(Path(roundedRect: CGRect(x: 4, y: -barrelWidth / 2,
                                                 width: barrelLength, height: barrelWidth),
                             cornerRadius: barrelWidth / 2),
                        with: .color(body))
        }

        if engine.muzzleFlash > 0.02 {
            let flash = engine.muzzleFlash
            turret.fill(Path(ellipseIn: CGRect(x: barrelLength - 2, y: -6 * flash,
                                               width: 12 * flash, height: 12 * flash)),
                        with: .color(accent.opacity(0.85 * flash)))
        }

        // Hub
        context.fill(Path(ellipseIn: CGRect(x: Double(origin.x) - 13, y: Double(origin.y) - 13,
                                            width: 26, height: 26)),
                     with: .color(Color.panelRaised))
        context.stroke(Path(ellipseIn: CGRect(x: Double(origin.x) - 13, y: Double(origin.y) - 13,
                                              width: 26, height: 26)),
                       with: .color(body.opacity(0.9)), lineWidth: 2)
        context.fill(Path(ellipseIn: CGRect(x: Double(origin.x) - 4.5, y: Double(origin.y) - 4.5,
                                            width: 9, height: 9)),
                     with: .color(accent))

        // Ground line the dots never cross.
        var floor = Path()
        floor.move(to: CGPoint(x: 0, y: engine.playHeight))
        floor.addLine(to: CGPoint(x: size.width, y: engine.playHeight))
        context.stroke(floor, with: .color(Color.hairline.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
    }

    // MARK: Floating labels

    private func drawLabels(_ context: inout GraphicsContext) {
        for label in engine.labels where label.life > 0 {
            let alpha = min(1, label.life / max(0.01, label.maxLife * 0.6))
            let text = Text(label.text)
                .font(.system(size: label.emphasised ? 17 : 12,
                              weight: .heavy,
                              design: .rounded))
                .foregroundColor(label.palette.color.opacity(alpha))
            context.draw(text, at: CGPoint(x: label.x, y: label.y), anchor: .center)
        }
    }
}
