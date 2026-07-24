import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var state: GameState
    let service: LocalLeaderboardService

    @State private var scope: LeaderboardScope = .global
    @State private var editingName = false
    @State private var draftName = ""

    private var entries: [LeaderboardEntry] {
        service.board(scope: scope, player: state.leaderboardEntry)
    }

    var body: some View {
        ScreenScaffold(state: state, title: "Leaderboard", icon: "trophy.fill") {
            VStack(spacing: 12) {
                header
                scopePicker

                LazyVStack(spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(rank: index + 1, entry: entry)
                    }
                }

                Text("Rivals in this build are generated locally and advance over time — there is no server behind them.")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.dimText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .alert("Commander name", isPresented: $editingName) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                state.playerName = trimmed.isEmpty ? "Commander" : String(trimmed.prefix(18))
                state.publishNow()
                state.persist()
            }
        }
    }

    private var header: some View {
        let ranked = entries
        let rank = (ranked.firstIndex { $0.isPlayer } ?? 0) + 1

        return VStack(spacing: 10) {
            SectionHeader(title: "Most dots destroyed",
                          subtitle: "You are #\(rank) of \(ranked.count).",
                          icon: "trophy.fill",
                          accent: PaletteColor.gold.color)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.playerName)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(Fmt.count(state.stats.dotsDestroyed)) dots · Galaxy \(state.stats.highestGalaxyIndex + 1)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.dimText)
                        .monoDigits()
                }
                Spacer(minLength: 0)
                Button {
                    draftName = state.playerName
                    editingName = true
                } label: {
                    Text("Rename")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(PaletteColor.cyan.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(PaletteColor.cyan.color.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
        }
        .panel()
    }

    private var scopePicker: some View {
        HStack(spacing: 8) {
            ForEach(LeaderboardScope.allCases) { item in
                Button {
                    scope = item
                    Feedback.shared.select()
                } label: {
                    Text(item.title)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(scope == item ? .black : .dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(scope == item ? PaletteColor.gold.color : Color.panel)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(rankColor)
                .monoDigits()
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(entry.isPlayer ? PaletteColor.mint.color : .white)
                        .lineLimit(1)
                    if entry.isVIP { Badge(text: "VIP", tint: PaletteColor.gold.color) }
                    if entry.isPlayer { Badge(text: "YOU", tint: PaletteColor.mint.color) }
                }
                Text("Galaxy \(entry.galaxyIndex + 1) · \(entry.rebirths) rebirths")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.dimText)
                    .monoDigits()
            }

            Spacer(minLength: 6)

            Text(Fmt.count(entry.dotsDestroyed))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monoDigits()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(entry.isPlayer ? PaletteColor.mint.color.opacity(0.12) : Color.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(entry.isPlayer ? PaletteColor.mint.color.opacity(0.5) : Color.hairline.opacity(0.5),
                        lineWidth: 1)
        )
    }

    private var rankColor: Color {
        switch rank {
        case 1: return PaletteColor.gold.color
        case 2: return PaletteColor.silver.color
        case 3: return PaletteColor.orange.color
        default: return .dimText
        }
    }
}
