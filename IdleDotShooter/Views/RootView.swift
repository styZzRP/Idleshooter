import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case field
    case upgrades
    case shop
    case galaxy
    case rebirth
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .field:    return "Field"
        case .upgrades: return "Upgrades"
        case .shop:     return "Shop"
        case .galaxy:   return "Galaxy"
        case .rebirth:  return "Rebirth"
        case .more:     return "More"
        }
    }

    var icon: String {
        switch self {
        case .field:    return "scope"
        case .upgrades: return "wrench.and.screwdriver.fill"
        case .shop:     return "cart.fill"
        case .galaxy:   return "globe.europe.africa.fill"
        case .rebirth:  return "arrow.triangle.2.circlepath"
        case .more:     return "square.grid.2x2.fill"
        }
    }

    var tint: PaletteColor {
        switch self {
        case .field:    return .cyan
        case .upgrades: return .amber
        case .shop:     return .mint
        case .galaxy:   return .violet
        case .rebirth:  return .purple
        case .more:     return .slate
        }
    }
}

struct RootView: View {
    @ObservedObject var state: GameState
    let engine: GameEngine
    let leaderboard: LocalLeaderboardService

    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: Tab = .field
    @State private var offlineReport: GameState.OfflineReport?
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            Color.fieldBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }

            if let report = offlineReport {
                ModalBackdrop()
                OfflineReportView(report: report) {
                    offlineReport = nil
                }
                .transition(.scale.combined(with: .opacity))
            } else if showTutorial {
                ModalBackdrop()
                TutorialView {
                    showTutorial = false
                    state.tutorialSeen = true
                    state.persist()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            GameContainer.shared.start()
            collectOfflineReport()
            showTutorial = !state.tutorialSeen
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                GameContainer.shared.enterForeground()
                collectOfflineReport()
            case .background, .inactive:
                GameContainer.shared.enterBackground()
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .field:
            GameView(state: state, engine: engine)
        case .upgrades:
            UpgradesView(state: state)
        case .shop:
            ShopView(state: state)
        case .galaxy:
            GalaxyView(state: state)
        case .rebirth:
            RebirthView(state: state)
        case .more:
            MoreView(state: state, leaderboard: leaderboard)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                    Feedback.shared.select()
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            Image(systemName: item.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(tab == item ? item.tint.color : .dimText)
                            if item == .rebirth && state.rebirthUnlocked && state.pendingStarDust > 0 {
                                Circle()
                                    .fill(PaletteColor.gold.color)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 11, y: -9)
                            }
                        }
                        Text(item.title)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundColor(tab == item ? item.tint.color : .dimText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .background(
            Color.panel
                .overlay(Rectangle()
                    .fill(Color.hairline.opacity(0.6))
                    .frame(height: 1),
                         alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func collectOfflineReport() {
        if let report = state.pendingOfflineReport {
            state.pendingOfflineReport = nil
            offlineReport = report
        }
    }
}
