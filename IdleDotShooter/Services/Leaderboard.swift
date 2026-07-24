import Foundation

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var dotsDestroyed: Double
    var galaxyIndex: Int
    var rebirths: Int
    var isPlayer: Bool
    var isVIP: Bool
}

enum LeaderboardScope: String, CaseIterable, Identifiable {
    case global
    case friends

    var id: String { rawValue }
    var title: String { self == .global ? "Global" : "Friends" }
}

protocol LeaderboardService {
    /// Returns the ranked board with the player's own row merged in.
    func board(scope: LeaderboardScope, player: LeaderboardEntry) -> [LeaderboardEntry]
}

/// Offline stand-in for the online board.
///
/// The shipping game talks to a backend for "most dots destroyed". There is no
/// server behind this build, so rivals are generated once, persisted, and
/// advanced against wall-clock time. Everything below is local — swap in a
/// networked `LeaderboardService` and the rest of the app is unchanged.
final class LocalLeaderboardService: LeaderboardService {

    private struct Rival: Codable {
        var id: String
        var name: String
        var seedScore: Double
        var perHour: Double
        var galaxyIndex: Int
        var rebirths: Int
        var isVIP: Bool
        var friend: Bool
    }

    private struct Store: Codable {
        var createdAt: Date
        var rivals: [Rival]
    }

    private let defaultsKey = "idleDotShooter.leaderboard.v1"
    private var store: Store

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(Store.self, from: data) {
            store = decoded
        } else {
            store = Store(createdAt: Date(), rivals: LocalLeaderboardService.makeRivals())
            persist()
        }
    }

    func board(scope: LeaderboardScope, player: LeaderboardEntry) -> [LeaderboardEntry] {
        let hours = max(0, Date().timeIntervalSince(store.createdAt) / 3600)
        var entries: [LeaderboardEntry] = store.rivals
            .filter { scope == .global || $0.friend }
            .map { rival in
                LeaderboardEntry(id: rival.id,
                                 name: rival.name,
                                 dotsDestroyed: rival.seedScore + rival.perHour * hours,
                                 galaxyIndex: rival.galaxyIndex,
                                 rebirths: rival.rebirths,
                                 isPlayer: false,
                                 isVIP: rival.isVIP)
            }
        entries.append(player)
        entries.sort { $0.dotsDestroyed > $1.dotsDestroyed }
        return entries
    }

    func rank(of player: LeaderboardEntry, scope: LeaderboardScope) -> Int {
        let ranked = board(scope: scope, player: player)
        return (ranked.firstIndex { $0.isPlayer } ?? ranked.count) + 1
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(store) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func makeRivals() -> [Rival] {
        let handles = [
            "voidrunner", "pixelpop", "dot_dealer", "quasarQ", "nova_kat", "bitrot",
            "orbital_ed", "s0lstice", "greyhat", "mochi", "turret_tim", "lumen",
            "kilonova", "zzzap", "driftwood", "parsec", "hexline", "auralis",
            "cindershot", "boop", "vantablack", "gluon", "static_", "marrow",
            "sunder", "ferrite", "halcyon", "pulsewave", "onyx", "rhea",
            "tessellate", "vellum", "quark_", "moth", "sable", "helix",
            "eventide", "cobalt", "vermillion", "prism", "solace", "aster",
            "nimbus", "graviton", "echo9", "tundra", "opal", "kestrel",
            "fathom", "ember_", "reverie", "carbon", "lyra", "zenith",
            "meridian", "cascade", "harrow", "vireo", "spindle", "quiet"
        ]

        return handles.enumerated().map { index, name in
            // A long-tailed spread so the top of the board is genuinely far away
            // and the bottom is catchable within an evening.
            let strength = pow(Double(handles.count - index) / Double(handles.count), 3.2)
            let seed = 900 + strength * 4_200_000 * Double.random(in: 0.6...1.6)
            let perHour = 400 + strength * 90_000 * Double.random(in: 0.5...1.5)
            let galaxy = min(GalaxyCatalog.count - 1, Int(strength * 46) + Int.random(in: 0...3))
            return Rival(id: "rival.\(index)",
                         name: name,
                         seedScore: seed,
                         perHour: perHour,
                         galaxyIndex: galaxy,
                         rebirths: max(0, Int(strength * 22) + Int.random(in: -1...2)),
                         isVIP: Double.random(in: 0...1) < 0.22,
                         friend: index % 7 == 0)
        }
    }
}
