import SwiftUI

/// Static starfield + gradient behind the play field. Driven by the equipped
/// backdrop cosmetic, drawn once rather than per frame.
struct Backdrop: View {
    let cosmetic: Cosmetic

    private static let stars: [Star] = (0..<90).map { _ in
        Star(x: Double.random(in: 0...1),
             y: Double.random(in: 0...1),
             radius: Double.random(in: 0.6...1.9),
             opacity: Double.random(in: 0.15...0.7))
    }

    private struct Star: Hashable {
        let x: Double
        let y: Double
        let radius: Double
        let opacity: Double
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors,
                           startPoint: .top,
                           endPoint: .bottom)

            if cosmetic.variant == 4 {
                GridOverlay(tint: cosmetic.primary.color.opacity(0.16))
            } else {
                Canvas { context, size in
                    for star in Backdrop.stars {
                        let rect = CGRect(x: star.x * size.width - star.radius,
                                          y: star.y * size.height - star.radius,
                                          width: star.radius * 2,
                                          height: star.radius * 2)
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(.white.opacity(star.opacity)))
                    }
                }
                .allowsHitTesting(false)
            }

            RadialGradient(colors: [cosmetic.primary.color.opacity(0.24), .clear],
                           center: .init(x: 0.5, y: 0.18),
                           startRadius: 8,
                           endRadius: 420)
                .blendMode(.plusLighter)

            RadialGradient(colors: [cosmetic.secondary.color.opacity(0.18), .clear],
                           center: .init(x: 0.15, y: 0.8),
                           startRadius: 8,
                           endRadius: 360)
                .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        [
            Color.fieldBackground,
            cosmetic.secondary.color.opacity(0.16),
            Color.fieldBackground
        ]
    }
}

private struct GridOverlay: View {
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 42
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(tint), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
