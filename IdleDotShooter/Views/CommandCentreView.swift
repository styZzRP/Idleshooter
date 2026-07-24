import SwiftUI

struct CommandCentreView: View {
    @ObservedObject var state: GameState

    var body: some View {
        ScreenScaffold(state: state, title: "Command Centre", icon: "chart.bar.doc.horizontal.fill") {
            VStack(spacing: 14) {
                liveBoard

                ForEach(sections) { section in
                    VStack(spacing: 0) {
                        SectionHeader(title: section.title, icon: nil)
                            .padding(.bottom, 6)
                        ForEach(section.rows) { row in
                            StatLine(row: row)
                            if row.id != section.rows.last?.id {
                                Divider().background(Color.hairline.opacity(0.4))
                            }
                        }
                    }
                    .panel()
                }

                rarityBreakdown
            }
        }
    }

    // MARK: Live numbers

    private var liveBoard: some View {
        let d = state.derived
        return VStack(spacing: 10) {
            SectionHeader(title: "Live Output",
                          subtitle: "Everything your current build is doing right now.",
                          icon: "waveform.path.ecg",
                          accent: PaletteColor.mint.color)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                tile("DPS", Fmt.number(d.dps), .red)
                tile("Cash/sec", Fmt.cash(state.recentIncomePerSecond), .gold)
                tile("Fire rate", String(format: "%.2f/s", d.fireRate), .orange)
                tile("Multishot", "\(d.multishot)", .amber)
                tile("Crit", Fmt.percent(d.critChance), .crimson)
                tile("Crit dmg", Fmt.multiplier(d.critDamage), .red)
                tile("Capacity", "\(d.capacity)", .cyan)
                tile("Spawn", String(format: "%.2f/s", d.spawnRate), .teal)
                tile("Luck", Fmt.percent(d.luck), .green)
                tile("Drones", "\(d.droneCount)", .cyan)
                tile("Suction", String(format: "%.0f", d.droneSuction), .mint)
                tile("Combo", Fmt.multiplier(state.comboMultiplier), .violet)
            }
        }
        .panel()
    }

    private func tile(_ title: String, _ value: String, _ palette: PaletteColor) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(palette.color)
                .monoDigits()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.panelRaised))
    }

    // MARK: Rarity

    private var rarityBreakdown: some View {
        let total = max(1, Rarity.allCases.reduce(0.0) { $0 + state.stats.kills(of: $1) })
        return VStack(spacing: 10) {
            SectionHeader(title: "Dots by rarity",
                          subtitle: "Everything you have ever popped.",
                          icon: "circle.grid.3x3.fill",
                          accent: PaletteColor.pink.color)

            ForEach(Rarity.allCases) { rarity in
                let kills = state.stats.kills(of: rarity)
                VStack(spacing: 4) {
                    HStack {
                        Text(rarity.name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(rarity.palette.color)
                        Spacer()
                        Text(Fmt.count(kills))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monoDigits()
                    }
                    ProgressBar(fraction: kills / total, tint: rarity.palette.color, height: 5)
                }
            }
        }
        .panel()
    }

    // MARK: Rows

    private var sections: [StatSection] {
        let stats = state.stats
        return [
            StatSection(title: "Combat", rows: [
                StatRow(label: "Dots destroyed", value: Fmt.count(stats.dotsDestroyed),
                        icon: "scope", palette: .red),
                StatRow(label: "Shots fired", value: Fmt.count(stats.shotsFired),
                        icon: "bolt.fill", palette: .orange),
                StatRow(label: "Hits landed", value: Fmt.count(stats.bulletsHit),
                        icon: "target", palette: .amber),
                StatRow(label: "Accuracy", value: Fmt.percent(stats.accuracy),
                        icon: "checkmark.seal.fill", palette: .mint),
                StatRow(label: "Critical hits", value: Fmt.count(stats.criticalHits),
                        icon: "burst.fill", palette: .crimson),
                StatRow(label: "Biggest hit", value: Fmt.number(stats.biggestSingleHit),
                        icon: "hammer.fill", palette: .red),
                StatRow(label: "Golden dots", value: Fmt.count(stats.goldenDotsPopped),
                        icon: "star.circle.fill", palette: .gold),
                StatRow(label: "Best combo", value: Fmt.integer(stats.bestCombo),
                        icon: "flame.fill", palette: .orange)
            ]),

            StatSection(title: "Economy", rows: [
                StatRow(label: "Cash earned (lifetime)", value: Fmt.cash(stats.cashEarnedLifetime),
                        icon: "dollarsign.circle.fill", palette: .gold),
                StatRow(label: "Cash earned (this run)", value: Fmt.cash(stats.cashEarnedThisRun),
                        icon: "arrow.clockwise.circle.fill", palette: .amber),
                StatRow(label: "Cash spent", value: Fmt.cash(stats.cashSpent),
                        icon: "cart.fill", palette: .lime),
                StatRow(label: "Biggest payout", value: Fmt.cash(stats.biggestSinglePayout),
                        icon: "sparkles", palette: .gold),
                StatRow(label: "Average per dot", value: Fmt.cash(stats.averagePayout),
                        icon: "divide.circle.fill", palette: .green),
                StatRow(label: "Upgrades purchased", value: Fmt.count(stats.upgradesPurchased),
                        icon: "wrench.and.screwdriver.fill", palette: .cyan)
            ]),

            StatSection(title: "Drone", rows: [
                StatRow(label: "Orbs collected", value: Fmt.count(stats.orbsCollected),
                        icon: "circle.circle.fill", palette: .mint),
                StatRow(label: "Orbs lost", value: Fmt.count(stats.orbsLost),
                        icon: "xmark.circle.fill", palette: .slate),
                StatRow(label: "Collection rate", value: Fmt.percent(stats.collectionRate),
                        icon: "tornado", palette: .teal)
            ]),

            StatSection(title: "Abilities", rows: [
                StatRow(label: "Abilities cast", value: Fmt.count(stats.abilitiesCast),
                        icon: "sparkles", palette: .violet),
                StatRow(label: "Frenzy", value: Fmt.count(stats.frenzyCasts),
                        icon: "flame.fill", palette: .orange),
                StatRow(label: "Dot Rain", value: Fmt.count(stats.dotRainCasts),
                        icon: "cloud.rain.fill", palette: .cyan),
                StatRow(label: "Black Hole", value: Fmt.count(stats.blackHoleCasts),
                        icon: "circle.circle.fill", palette: .purple)
            ]),

            StatSection(title: "Journey", rows: [
                StatRow(label: "Galaxy travels", value: Fmt.count(stats.galaxyTravels),
                        icon: "paperplane.fill", palette: .cyan),
                StatRow(label: "Furthest galaxy",
                        value: "\(stats.highestGalaxyIndex + 1) · \(GalaxyCatalog.galaxy(at: stats.highestGalaxyIndex).name)",
                        icon: "flag.fill", palette: .mint),
                StatRow(label: "Rebirths", value: Fmt.integer(stats.rebirths),
                        icon: "arrow.triangle.2.circlepath", palette: .violet),
                StatRow(label: "Star Dust earned", value: Fmt.count(stats.starDustEarnedLifetime),
                        icon: "star.fill", palette: .gold),
                StatRow(label: "Time active", value: Fmt.duration(stats.timeActive),
                        icon: "clock.fill", palette: .silver),
                StatRow(label: "Time offline", value: Fmt.duration(stats.timeOffline),
                        icon: "moon.zzz.fill", palette: .indigo),
                StatRow(label: "Sessions", value: Fmt.integer(stats.sessionsPlayed),
                        icon: "iphone", palette: .slate),
                StatRow(label: "First played", value: dateText(stats.firstPlayed),
                        icon: "calendar", palette: .slate)
            ])
        ]
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
