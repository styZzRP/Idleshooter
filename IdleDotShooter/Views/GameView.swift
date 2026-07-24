import SwiftUI

struct GameView: View {
    @ObservedObject var state: GameState
    /// Deliberately not observed here — only `FieldCanvas` needs frame-rate
    /// updates, and observing the engine at this level would rebuild the HUD
    /// 60 times a second for nothing.
    let engine: GameEngine

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop(cosmetic: state.equipped(.background))

            FieldCanvas(engine: engine, state: state)

            VStack(spacing: 0) {
                HUDBar(state: state)
                ComboBanner(state: state)
                Spacer(minLength: 0)
                AbilityBar(state: state, engine: engine)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - HUD

struct HUDBar: View {
    @ObservedObject var state: GameState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                CurrencyPill(icon: "dollarsign.circle.fill",
                             value: Fmt.cash(state.cash),
                             tint: PaletteColor.gold.color,
                             caption: "\(Fmt.cash(state.recentIncomePerSecond))/s")

                CurrencyPill(icon: "diamond.fill",
                             value: Fmt.count(state.gems),
                             tint: PaletteColor.cyan.color)

                if state.starDust > 0 || state.stats.rebirths > 0 {
                    CurrencyPill(icon: "sparkles",
                                 value: Fmt.count(state.starDust),
                                 tint: PaletteColor.violet.color)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: state.galaxy.modifier.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(state.galaxy.palette.color)
                    Text("Galaxy \(state.galaxy.number) · \(state.galaxy.name)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(state.galaxy.modifier.title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.dimText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.panel.opacity(0.9)))
                .overlay(Capsule().stroke(state.galaxy.palette.color.opacity(0.4), lineWidth: 1))

                Spacer(minLength: 0)

                if state.isVIP {
                    Badge(text: "VIP", tint: PaletteColor.gold.color)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

// MARK: - Combo

struct ComboBanner: View {
    @ObservedObject var state: GameState

    var body: some View {
        Group {
            if state.combo > 1 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(PaletteColor.orange.color)
                        .font(.system(size: 12, weight: .bold))
                    Text("\(state.combo) combo")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monoDigits()
                    Text(Fmt.multiplier(state.comboMultiplier))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(PaletteColor.gold.color)
                        .monoDigits()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.panel.opacity(0.9)))
                .overlay(Capsule().stroke(PaletteColor.orange.color.opacity(0.5), lineWidth: 1))
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Abilities

struct AbilityBar: View {
    @ObservedObject var state: GameState
    let engine: GameEngine

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AbilityCatalog.all) { def in
                AbilityButton(def: def, state: state, engine: engine)
            }
        }
    }
}

struct AbilityButton: View {
    let def: AbilityDef
    @ObservedObject var state: GameState
    let engine: GameEngine

    private var ability: AbilityState { state.ability(def.id) }

    var body: some View {
        Button {
            if ability.unlocked {
                engine.cast(def.id)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: def.icon)
                    .font(.system(size: 18, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .monoDigits()
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.panel.opacity(0.92))
                    if ability.isActive {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(def.palette.color.opacity(0.28))
                    } else if ability.cooldownRemaining > 0 {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(def.palette.color.opacity(0.16))
                                .frame(height: geo.size.height * cooldownFraction)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: ability.isReady ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!ability.isReady)
        .opacity(ability.unlocked ? 1 : 0.45)
    }

    private var cooldownFraction: Double {
        let total = def.cooldown(level: ability.level, reduction: state.abilityCooldownReduction)
        guard total > 0 else { return 0 }
        return max(0, min(1, ability.cooldownRemaining / total))
    }

    private var label: String {
        if !ability.unlocked { return "LOCKED" }
        if ability.isActive { return Fmt.cooldown(ability.activeRemaining) }
        if ability.cooldownRemaining > 0 { return Fmt.cooldown(ability.cooldownRemaining) }
        return def.name.uppercased()
    }

    private var foreground: Color {
        if !ability.unlocked { return .dimText }
        return ability.isReady || ability.isActive ? def.palette.color : .dimText
    }

    private var borderColor: Color {
        ability.isReady || ability.isActive
            ? def.palette.color.opacity(0.85)
            : Color.hairline.opacity(0.7)
    }
}
