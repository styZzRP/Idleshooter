import SwiftUI

/// Command Centre, Leaderboard and Settings share one tab.
struct MoreView: View {
    @ObservedObject var state: GameState
    let leaderboard: LocalLeaderboardService

    enum Page: String, CaseIterable, Identifiable {
        case stats
        case ranks
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stats:    return "Command"
            case .ranks:    return "Ranks"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .stats:    return "chart.bar.doc.horizontal.fill"
            case .ranks:    return "trophy.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    @State private var page: Page = .stats

    var body: some View {
        ZStack {
            Color.fieldBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                picker
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                switch page {
                case .stats:    CommandCentreView(state: state)
                case .ranks:    LeaderboardView(state: state, service: leaderboard)
                case .settings: SettingsView(state: state)
                }
            }
        }
    }

    private var picker: some View {
        HStack(spacing: 8) {
            ForEach(Page.allCases) { item in
                Button {
                    page = item
                    Feedback.shared.select()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(item.title)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(page == item ? .black : .dimText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(page == item ? PaletteColor.cyan.color : Color.panel)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
