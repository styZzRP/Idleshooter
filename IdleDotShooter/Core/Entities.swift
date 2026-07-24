import CoreGraphics
import Foundation

struct DotEntity {
    var id: Int
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var radius: Double
    var health: Double
    var maxHealth: Double
    var rarity: Rarity
    var golden: Bool
    var value: Double
    /// Counts down after a hit, drives the white flash on the dot.
    var flash: Double = 0
    /// Free-running phase so every dot pulses slightly out of step.
    var phase: Double
    var dead = false

    var healthFraction: Double {
        maxHealth > 0 ? max(0, min(1, health / maxHealth)) : 0
    }
}

struct BulletEntity {
    var id: Int
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var damage: Double
    var isCrit: Bool
    var pierceLeft: Int
    var life: Double
    var radius: Double
    var lastHitID: Int = -1
    /// Brief blackout after a hit so one round can't chew the same dot twice.
    var hitCooldown: Double = 0
    var dead = false
}

struct OrbEntity {
    var id: Int
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var value: Double
    var life: Double
    var maxLife: Double
    var radius: Double
    var golden: Bool
    var dead = false
}

struct DroneEntity {
    var id: Int
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var angle: Double
    var targetOrbID: Int = -1
    /// Offset so multiple drones idle in different spots.
    var idlePhase: Double
}

struct ParticleEntity {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double
    var maxLife: Double
    var radius: Double
    var red: Double
    var green: Double
    var blue: Double
}

struct FloatingLabel {
    var id: Int
    var x: Double
    var y: Double
    var vy: Double
    var text: String
    var life: Double
    var maxLife: Double
    var palette: PaletteColor
    var emphasised: Bool
}

/// Active black hole, if any.
struct Singularity {
    var x: Double
    var y: Double
    var remaining: Double
    var duration: Double
    var pull: Double
    var payoutMultiplier: Double

    var progress: Double {
        duration > 0 ? 1 - max(0, remaining / duration) : 1
    }
}

/// Uniform grid over the play field so bullet/dot tests only look at nearby
/// dots instead of the whole field.
struct SpatialGrid {
    private(set) var cellSize: Double = 80
    private(set) var columns = 1
    private(set) var rows = 1
    private var buckets: [[Int]] = [[]]

    mutating func rebuild(width: Double, height: Double, dots: [DotEntity]) {
        let cols = max(1, Int(ceil(width / cellSize)))
        let rws = max(1, Int(ceil(height / cellSize)))

        if cols != columns || rws != rows || buckets.count != cols * rws {
            columns = cols
            rows = rws
            buckets = Array(repeating: [], count: cols * rws)
        } else {
            for index in buckets.indices { buckets[index].removeAll(keepingCapacity: true) }
        }

        for (index, dot) in dots.enumerated() where !dot.dead {
            let cx = min(columns - 1, max(0, Int(dot.x / cellSize)))
            let cy = min(rows - 1, max(0, Int(dot.y / cellSize)))
            buckets[cy * columns + cx].append(index)
        }
    }

    /// Visits every dot index in the 3x3 block of cells around the point.
    /// `body` returns `false` to stop the walk early.
    func forEachCandidate(x: Double, y: Double, _ body: (Int) -> Bool) {
        let cx = min(columns - 1, max(0, Int(x / cellSize)))
        let cy = min(rows - 1, max(0, Int(y / cellSize)))

        let minX = max(0, cx - 1), maxX = min(columns - 1, cx + 1)
        let minY = max(0, cy - 1), maxY = min(rows - 1, cy + 1)

        var row = minY
        while row <= maxY {
            var col = minX
            while col <= maxX {
                for index in buckets[row * columns + col] {
                    if !body(index) { return }
                }
                col += 1
            }
            row += 1
        }
    }
}
