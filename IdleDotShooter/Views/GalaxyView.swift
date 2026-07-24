import SwiftUI

struct GalaxyView: View {
    @ObservedObject var state: GameState

    var body: some View {
        ScreenScaffold(state: state, title: "Galaxies", icon: "globe.europe.africa.fill") {
            VStack(spacing: 12) {
                summary

                LazyVStack(spacing: 10) {
                    ForEach(GalaxyCatalog.all) { galaxy in
                        GalaxyRow(galaxy: galaxy, state: state)
                    }
                }
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Travel",
                          subtitle: "Save up, jump ahead. Each galaxy scales health and payouts.",
                          icon: "paperplane.fill",
                          accent: PaletteColor.cyan.color)

            HStack(spacing: 10) {
                miniStat(title: "Current",
                         value: "\(state.galaxy.number)/\(GalaxyCatalog.count)",
                         tint: state.galaxy.palette.color)
                miniStat(title: "Furthest",
                         value: "\(state.stats.highestGalaxyIndex + 1)",
                         tint: PaletteColor.mint.color)
                miniStat(title: "Travels",
                         value: Fmt.count(state.stats.galaxyTravels),
                         tint: PaletteColor.violet.color)
            }

            ProgressBar(fraction: Double(state.unlockedGalaxyIndex + 1) / Double(GalaxyCatalog.count),
                        tint: PaletteColor.cyan.color)
        }
        .panel()
    }

    private func miniStat(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
                .monoDigits()
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.dimText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GalaxyRow: View {
    let galaxy: Galaxy
    @ObservedObject var state: GameState

    var body: some View {
        let isCurrent = galaxy.index == state.galaxyIndex
        let unlocked = galaxy.index <= state.unlockedGalaxyIndex
        let isNext = galaxy.index == state.unlockedGalaxyIndex + 1
        let cost = state.travelCost(to: galaxy.index)
        let accent = galaxy.palette.color

        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text("\(galaxy.number)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(unlocked || isNext ? accent : .dimText)
                    .monoDigits()
                Image(systemName: galaxy.modifier.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.dimText)
            }
            .frame(width: 40, height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(unlocked || isNext ? 0.14 : 0.05)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(galaxy.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(unlocked || isNext ? .white : .dimText)
                    if isCurrent { Badge(text: "HERE", tint: PaletteColor.mint.color) }
                }

                Text(galaxy.modifier.title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(accent)

                Text(galaxy.modifier.detail)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.dimText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    scaleTag(icon: "heart.fill",
                             text: Fmt.multiplier(galaxy.healthMultiplier),
                             tint: PaletteColor.red.color)
                    scaleTag(icon: "dollarsign.circle.fill",
                             text: Fmt.multiplier(galaxy.valueMultiplier),
                             tint: PaletteColor.gold.color)
                }
            }

            Spacer(minLength: 6)

            trailing(isCurrent: isCurrent, unlocked: unlocked, isNext: isNext, cost: cost, accent: accent)
        }
        .panel()
        .opacity(unlocked || isNext ? 1 : 0.55)
    }

    @ViewBuilder
    private func trailing(isCurrent: Bool, unlocked: Bool, isNext: Bool,
                          cost: Double, accent: Color) -> some View {
        if isCurrent {
            Text("CURRENT")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(PaletteColor.mint.color)
                .frame(minWidth: 92)
        } else if unlocked {
            BuyButton(title: "TRAVEL", subtitle: "free", tint: accent, enabled: true) {
                state.travel(to: galaxy.index)
            }
        } else if isNext {
            BuyButton(title: Fmt.cash(cost),
                      subtitle: "unlock",
                      tint: accent,
                      enabled: state.cash >= cost) {
                state.travel(to: galaxy.index)
            }
        } else {
            VStack(spacing: 2) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(Fmt.cash(cost))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monoDigits()
            }
            .foregroundColor(.dimText)
            .frame(minWidth: 92)
        }
    }

    private func scaleTag(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monoDigits()
        }
        .foregroundColor(tint)
    }
}
