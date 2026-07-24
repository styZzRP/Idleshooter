import SwiftUI

struct RebirthView: View {
    @ObservedObject var state: GameState
    @State private var confirming = false

    var body: some View {
        ScreenScaffold(state: state, title: "Rebirth", icon: "arrow.triangle.2.circlepath") {
            VStack(spacing: 14) {
                if state.rebirthUnlocked {
                    rebirthPanel
                    permanentUpgrades
                } else {
                    LockedNotice(icon: "lock.fill",
                                 title: "Rebirth locked",
                                 message: "Reach Galaxy \(GalaxyCatalog.rebirthUnlockIndex + 1) to unlock Rebirth. Reset your run, bank Star Dust, and spend it on upgrades that never go away.")
                    permanentUpgrades
                }
            }
        }
        .alert("Rebirth?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}
            Button("Rebirth", role: .destructive) { state.rebirth() }
        } message: {
            Text("Your cash, upgrade levels, ability levels and galaxy progress reset. You keep Star Dust, permanent upgrades, cosmetics and everything claimed in the shop.")
        }
    }

    private var rebirthPanel: some View {
        let payout = state.pendingStarDust
        return VStack(spacing: 12) {
            SectionHeader(title: "Reset the run",
                          subtitle: "Trade this run's progress for permanent power.",
                          icon: "sparkles",
                          accent: PaletteColor.violet.color)

            HStack(spacing: 10) {
                figure(title: "Star Dust now", value: Fmt.count(state.starDust), tint: .violet)
                figure(title: "On rebirth", value: "+\(Fmt.count(payout))", tint: .gold)
                figure(title: "Rebirths", value: Fmt.integer(state.stats.rebirths), tint: .mint)
            }

            Text("This run has earned \(Fmt.cash(state.stats.cashEarnedThisRun)). Star Dust scales with that total and with how far you pushed.")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(.dimText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if state.settings.confirmRebirth {
                    confirming = true
                } else {
                    state.rebirth()
                }
            } label: {
                Text(payout > 0 ? "REBIRTH FOR \(Fmt.count(payout)) STAR DUST" : "NOT ENOUGH PROGRESS YET")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(payout > 0 ? .black : .dimText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(payout > 0 ? PaletteColor.violet.color : Color.panelRaised))
            }
            .buttonStyle(.plain)
            .disabled(payout <= 0)
        }
        .panel()
    }

    private func figure(title: String, value: String, tint: PaletteColor) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(tint.color)
                .monoDigits()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.panelRaised))
    }

    private var permanentUpgrades: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Permanent upgrades",
                          subtitle: "Bought with Star Dust. These survive every reset.",
                          icon: "star.fill",
                          accent: PaletteColor.gold.color)

            ForEach(RebirthCatalog.all) { def in
                StarUpgradeRow(def: def, state: state)
            }
        }
    }
}

struct StarUpgradeRow: View {
    let def: StarUpgradeDef
    @ObservedObject var state: GameState

    var body: some View {
        let level = state.starLevel(def.id)
        let maxed = def.isMaxed(at: level)
        let price = def.cost(at: level)
        let accent = PaletteColor.violet.color

        HStack(spacing: 12) {
            Image(systemName: def.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(accent.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Lv \(level)/\(def.maxLevel)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.dimText)
                        .monoDigits()
                }
                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.dimText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(def.displayValue(at: level))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monoDigits()
                    if !maxed {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.dimText)
                        Text(def.displayValue(at: level + 1))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(accent)
                            .monoDigits()
                    }
                }
            }

            Spacer(minLength: 6)

            if maxed {
                Text("MAXED")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(PaletteColor.gold.color)
                    .frame(minWidth: 92)
            } else {
                BuyButton(title: "\(Fmt.count(price)) ✦",
                          subtitle: "star dust",
                          tint: accent,
                          enabled: state.starDust >= price) {
                    state.purchaseStarUpgrade(def.id)
                }
            }
        }
        .panel()
    }
}
