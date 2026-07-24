import SwiftUI

// MARK: - Offline earnings

struct OfflineReportView: View {
    let report: GameState.OfflineReport
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(PaletteColor.indigo.color)

            Text("Welcome back")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text("Your turret kept working for \(Fmt.duration(report.duration)).")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.dimText)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text(Fmt.cash(report.cashEarned))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(PaletteColor.gold.color)
                    .monoDigits()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(Fmt.cash(report.rate))/s while away")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.dimText)
                    .monoDigits()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.panelRaised))

            if report.capped {
                Text("Offline earnings cap out at \(Int(GameBalance.offlineCapHours)) hours.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(PaletteColor.amber.color)
                    .multilineTextAlignment(.center)
            }

            Button(action: dismiss) {
                Text("COLLECT")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PaletteColor.mint.color))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: 340)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.panel))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.hairline, lineWidth: 1))
        .padding(24)
    }
}

// MARK: - First run

struct TutorialView: View {
    let dismiss: () -> Void

    private let steps: [(String, String, String, PaletteColor)] = [
        ("target", "It shoots itself",
         "The turret picks the nearest dot and fires on its own. You never have to tap to shoot.", .red),
        ("sparkles", "The drone collects",
         "Popped dots drop orbs. Your drone vacuums them up — upgrade its suction so none fade away.", .cyan),
        ("wrench.and.screwdriver.fill", "Upgrade everything",
         "Defence, Drone and Economy. Damage, fire rate, capacity, value, spawn rate, luck.", .gold),
        ("globe.europe.africa.fill", "Travel onwards",
         "Save up to reach the next of 50 galaxies. Each one scales health and payouts, and adds a modifier.", .violet),
        ("gift.fill", "The shop is free",
         "Every pack, boost and cosmetic costs nothing. Claim whatever you want, whenever you want.", .mint)
    ]

    var body: some View {
        VStack(spacing: 14) {
            Text("Idle Dot Shooter")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: step.0)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(step.3.color)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(step.3.color.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.1)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(step.2)
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(.dimText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            Button(action: dismiss) {
                Text("START SHOOTING")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PaletteColor.cyan.color))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: 380)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.panel))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.hairline, lineWidth: 1))
        .padding(20)
    }
}

// MARK: - Dimmed backdrop

struct ModalBackdrop: View {
    var body: some View {
        Color.black.opacity(0.65)
            .ignoresSafeArea()
    }
}
