import SwiftUI

/// Shared chrome for every non-game screen: title, wallet strip, scrolling body.
struct ScreenScaffold<Content: View>: View {
    @ObservedObject var state: GameState
    let title: String
    let icon: String
    private let content: () -> Content

    init(state: GameState,
         title: String,
         icon: String,
         @ViewBuilder content: @escaping () -> Content) {
        self.state = state
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        ZStack {
            Color.fieldBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    content()
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PaletteColor.cyan.color)
                Text(title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                CurrencyPill(icon: "dollarsign.circle.fill",
                             value: Fmt.cash(state.cash),
                             tint: PaletteColor.gold.color,
                             caption: "\(Fmt.cash(state.recentIncomePerSecond))/s")
                CurrencyPill(icon: "diamond.fill",
                             value: Fmt.count(state.gems),
                             tint: PaletteColor.cyan.color)
                CurrencyPill(icon: "sparkles",
                             value: Fmt.count(state.starDust),
                             tint: PaletteColor.violet.color)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Color.fieldBackground)
    }
}
