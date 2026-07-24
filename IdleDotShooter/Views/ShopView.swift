import SwiftUI

/// The storefront. Every item here is handed over for nothing — the euro price
/// each pack carries in the original is shown struck through so it is obvious
/// what you are not paying.
struct ShopView: View {
    @ObservedObject var state: GameState
    @State private var section: ShopSection = .featured

    var body: some View {
        ScreenScaffold(state: state, title: "Shop", icon: "cart.fill") {
            VStack(spacing: 14) {
                freeBanner
                sectionPicker

                if section == .cosmetics {
                    CosmeticsBoard(state: state)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(ShopCatalog.items(in: section)) { item in
                            ShopCard(item: item, state: state)
                        }
                    }
                }
            }
        }
    }

    private var freeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(PaletteColor.mint.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Everything is free")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("No purchases, no currency, no euros. Claim what you like, as often as you like.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.dimText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .panel()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PaletteColor.mint.color.opacity(0.45), lineWidth: 1)
        )
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopSection.allCases) { item in
                    Button {
                        section = item
                        Feedback.shared.select()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(item.title)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(section == item ? .black : .dimText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(section == item ? PaletteColor.cyan.color : Color.panel)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

// MARK: - Card

struct ShopCard: View {
    let item: ShopItem
    @ObservedObject var state: GameState

    var body: some View {
        let owned = state.isOwned(item)
        let accent = item.palette.color

        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(accent.opacity(0.14)))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    if let badge = item.badge {
                        Badge(text: badge, tint: accent)
                    }
                }

                Text(item.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.dimText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.effectSummary)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            VStack(spacing: 4) {
                Text(item.listPrice)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.dimText)
                    .strikethrough(true, color: PaletteColor.red.color)

                if owned {
                    Text("OWNED")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(PaletteColor.mint.color)
                        .frame(minWidth: 86)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(PaletteColor.mint.color.opacity(0.14)))
                } else {
                    BuyButton(title: ShopCatalog.freePriceLabel,
                              subtitle: item.repeatable ? "claim again" : "claim",
                              tint: PaletteColor.mint.color,
                              enabled: true) {
                        state.claim(item)
                    }
                }
            }
        }
        .panel()
    }
}

// MARK: - Cosmetics

struct CosmeticsBoard: View {
    @ObservedObject var state: GameState

    var body: some View {
        VStack(spacing: 16) {
            ForEach(CosmeticSlot.allCases) { slot in
                VStack(spacing: 10) {
                    SectionHeader(title: slot.title,
                                  subtitle: "Equipped: \(state.equipped(slot).name)",
                                  icon: slot.icon,
                                  accent: PaletteColor.cyan.color)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(CosmeticCatalog.items(in: slot)) { cosmetic in
                            CosmeticTile(cosmetic: cosmetic, state: state)
                        }
                    }
                }
            }
        }
    }
}

struct CosmeticTile: View {
    let cosmetic: Cosmetic
    @ObservedObject var state: GameState

    var body: some View {
        let owned = state.owns(cosmetic: cosmetic)
        let equipped = state.equipped(cosmetic.slot).id == cosmetic.id
        let shopItem = ShopCatalog.item("cosmetic.\(cosmetic.id)")

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(cosmetic.primary.color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(cosmetic.secondary.color, lineWidth: 2))
                Text(cosmetic.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(cosmetic.blurb)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.dimText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if equipped {
                tag(text: "EQUIPPED", color: PaletteColor.mint.color)
            } else if owned {
                Button {
                    state.equip(cosmetic)
                } label: {
                    tag(text: "EQUIP", color: PaletteColor.cyan.color)
                }
                .buttonStyle(.plain)
            } else if let shopItem {
                Button {
                    state.claim(shopItem)
                } label: {
                    VStack(spacing: 1) {
                        Text("FREE")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                        Text(shopItem.listPrice)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .strikethrough(true, color: PaletteColor.red.color)
                            .opacity(0.7)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(PaletteColor.mint.color))
                }
                .buttonStyle(.plain)
            }
        }
        .panel(padding: 12, corner: 16)
    }

    private func tag(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(color.opacity(0.16)))
    }
}
