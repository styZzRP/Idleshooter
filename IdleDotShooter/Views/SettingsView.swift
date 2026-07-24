import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: GameState
    @State private var confirmingReset = false

    var body: some View {
        ScreenScaffold(state: state, title: "Settings", icon: "gearshape.fill") {
            VStack(spacing: 14) {
                feel
                gameplay
                data
                about
            }
        }
        .alert("Wipe all progress?", isPresented: $confirmingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Erase everything", role: .destructive) {
                state.resetEverything()
            }
        } message: {
            Text("This deletes your save: cash, upgrades, galaxies, Star Dust, cosmetics and stats. It cannot be undone.")
        }
    }

    private var feel: some View {
        VStack(spacing: 4) {
            SectionHeader(title: "Feel", icon: "hand.tap.fill", accent: PaletteColor.cyan.color)
                .padding(.bottom, 4)

            toggle("Haptics", "iphone.radiowaves.left.and.right", binding(\.haptics))
            toggle("Sound", "speaker.wave.2.fill", binding(\.sound))
            toggle("Particles", "sparkles", binding(\.particles))
            toggle("Damage numbers", "textformat.123", binding(\.damageNumbers))
            toggle("Reduced motion", "figure.stand", binding(\.reducedMotion))
        }
        .panel()
    }

    private var gameplay: some View {
        VStack(spacing: 4) {
            SectionHeader(title: "Gameplay", icon: "gamecontroller.fill", accent: PaletteColor.violet.color)
                .padding(.bottom, 4)

            toggle("Confirm before rebirth", "exclamationmark.triangle.fill", binding(\.confirmRebirth))

            if state.autoCastUnlocked {
                Toggle(isOn: Binding(
                    get: { state.autoCastEnabled },
                    set: { state.autoCastEnabled = $0; state.publishNow(); state.persist() }
                )) {
                    settingLabel("Auto-cast abilities", "wand.and.stars")
                }
                .tint(PaletteColor.mint.color)
            } else {
                HStack {
                    settingLabel("Auto-cast abilities", "wand.and.stars")
                    Spacer()
                    Text("Free in the shop")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.dimText)
                }
                .padding(.vertical, 6)
            }

            HStack {
                settingLabel("Default buy amount", "number.square.fill")
                Spacer()
                Picker("", selection: Binding(
                    get: { state.settings.buyQuantity },
                    set: { state.settings.buyQuantity = $0; state.publishNow(); state.persist() }
                )) {
                    ForEach(BuyQuantity.allCases) { quantity in
                        Text(quantity.label).tag(quantity)
                    }
                }
                .pickerStyle(.menu)
                .tint(PaletteColor.cyan.color)
            }
            .padding(.vertical, 2)
        }
        .panel()
    }

    private var data: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Data", icon: "externaldrive.fill", accent: PaletteColor.amber.color)

            Button {
                state.persist()
                Feedback.shared.success()
            } label: {
                actionLabel("Save now", "square.and.arrow.down.fill", PaletteColor.mint.color)
            }
            .buttonStyle(.plain)

            Button {
                confirmingReset = true
            } label: {
                actionLabel("Erase all progress", "trash.fill", PaletteColor.red.color)
            }
            .buttonStyle(.plain)
        }
        .panel()
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "About", icon: "info.circle.fill", accent: PaletteColor.slate.color)

            Text("Idle Dot Shooter — an independent, offline rebuild. The turret fires itself, the drone collects, and every item in the shop costs nothing at all.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.dimText)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Version")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.dimText)
                Spacer()
                Text(appVersion)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monoDigits()
            }
        }
        .panel()
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: Helpers

    private func binding(_ keyPath: WritableKeyPath<GameSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { state.settings[keyPath: keyPath] },
            set: { newValue in
                state.settings[keyPath: keyPath] = newValue
                state.publishNow()
                state.persist()
            }
        )
    }

    private func toggle(_ title: String, _ icon: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            settingLabel(title, icon)
        }
        .tint(PaletteColor.mint.color)
    }

    private func settingLabel(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(PaletteColor.cyan.color)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func actionLabel(_ title: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
            Spacer()
        }
        .foregroundColor(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(0.12)))
    }
}
