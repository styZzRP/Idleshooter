import SwiftUI

struct UpgradesView: View {
    @ObservedObject var state: GameState
    @State private var category: UpgradeCategory = .defence

    var body: some View {
        ScreenScaffold(state: state, title: "Upgrades", icon: "wrench.and.screwdriver.fill") {
            VStack(spacing: 14) {
                categoryPicker

                HStack {
                    Text(category.blurb)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.dimText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    buyQuantityPicker
                }

                LazyVStack(spacing: 10) {
                    ForEach(UpgradeCatalog.upgrades(in: category)) { def in
                        UpgradeRow(def: def, state: state)
                    }
                }

                AbilitySection(state: state)
            }
        }
    }

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(UpgradeCategory.allCases) { item in
                Button {
                    category = item
                    Feedback.shared.select()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .bold))
                        Text(item.title)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(category == item ? .black : .dimText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(category == item ? item.accent.color : Color.panel)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var buyQuantityPicker: some View {
        HStack(spacing: 4) {
            ForEach(BuyQuantity.allCases) { quantity in
                Button {
                    state.settings.buyQuantity = quantity
                    state.publishNow()
                    Feedback.shared.select()
                } label: {
                    Text(quantity.label)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(state.settings.buyQuantity == quantity ? .black : .dimText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(state.settings.buyQuantity == quantity
                                      ? PaletteColor.mint.color
                                      : Color.panel)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Row

struct UpgradeRow: View {
    let def: UpgradeDef
    @ObservedObject var state: GameState

    var body: some View {
        let level = state.level(def.id)
        let maxed = def.isMaxed(at: level)
        let quote = state.quote(def.id, quantity: state.settings.buyQuantity)
        let affordable = !maxed && quote.levels > 0 && quote.price <= state.cash
        let accent = def.category.accent.color

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
                    Text("Lv \(level)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.dimText)
                        .monoDigits()
                    if let cap = def.maxLevel, level >= cap {
                        Badge(text: "MAX", tint: PaletteColor.gold.color)
                    }
                }

                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.dimText)
                    .lineLimit(2)
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
                        Text(def.displayValue(at: level + max(1, quote.levels)))
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
                BuyButton(title: Fmt.cash(quote.price),
                          subtitle: quote.levels > 1 ? "+\(quote.levels) levels" : "+1 level",
                          tint: accent,
                          enabled: affordable) {
                    state.purchase(def.id, quantity: state.settings.buyQuantity)
                }
            }
        }
        .panel()
    }
}

// MARK: - Abilities

struct AbilitySection: View {
    @ObservedObject var state: GameState

    var body: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Abilities",
                          subtitle: "Big moments, on a cooldown.",
                          icon: "sparkles",
                          accent: PaletteColor.violet.color)

            ForEach(AbilityCatalog.all) { def in
                AbilityRow(def: def, state: state)
            }
        }
        .padding(.top, 6)
    }
}

struct AbilityRow: View {
    let def: AbilityDef
    @ObservedObject var state: GameState

    var body: some View {
        let ability = state.ability(def.id)
        let available = state.abilityAvailableForPurchase(def.id)
        let accent = def.palette.color

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
                    if ability.unlocked {
                        Text("Lv \(ability.level)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.dimText)
                            .monoDigits()
                    }
                }
                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.dimText)
                    .fixedSize(horizontal: false, vertical: true)

                if ability.unlocked {
                    Text("\(Fmt.duration(def.duration(level: ability.level))) active · \(Fmt.duration(def.cooldown(level: ability.level, reduction: state.abilityCooldownReduction))) cooldown")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                        .monoDigits()
                } else if !available {
                    Text("Unlocks in Galaxy \(def.unlockGalaxy + 1)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.dimText)
                }
            }

            Spacer(minLength: 6)

            if !ability.unlocked {
                BuyButton(title: available ? Fmt.cash(def.unlockCost) : "LOCKED",
                          subtitle: available ? "unlock" : nil,
                          tint: accent,
                          enabled: available && state.cash >= def.unlockCost) {
                    state.unlockAbility(def.id)
                }
            } else if def.isMaxed(level: ability.level) {
                Text("MAXED")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(PaletteColor.gold.color)
                    .frame(minWidth: 92)
            } else {
                let price = def.upgradeCost(level: ability.level) * (1 - state.upgradeDiscount)
                BuyButton(title: Fmt.cash(price),
                          subtitle: "+1 level",
                          tint: accent,
                          enabled: state.cash >= price) {
                    state.upgradeAbility(def.id)
                }
            }
        }
        .panel()
    }
}
