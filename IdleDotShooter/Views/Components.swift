import SwiftUI

// MARK: - Text helpers

extension Text {
    /// Tabular numerals so counters don't jitter as they tick.
    func monoDigits() -> Text {
        monospacedDigit()
    }
}

extension View {
    func panel(padding: CGFloat = 14, corner: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.hairline.opacity(0.6), lineWidth: 1)
            )
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var icon: String?
    var accent: Color = .white

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(accent.opacity(0.16)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.dimText)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Currency pill

struct CurrencyPill: View {
    let icon: String
    let value: String
    let tint: Color
    var caption: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monoDigits()
                if let caption {
                    Text(caption)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.dimText)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous).fill(Color.panelRaised)
        )
        .overlay(
            Capsule(style: .continuous).stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Buy button

struct BuyButton: View {
    let title: String
    let subtitle: String?
    let tint: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .monoDigits()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .opacity(0.75)
                }
            }
            .foregroundColor(enabled ? .black : Color.dimText)
            .frame(minWidth: 92)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(enabled ? tint : Color.panelRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(enabled ? Color.clear : Color.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.panelRaised)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundColor(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.16)))
    }
}

// MARK: - Empty / locked state

struct LockedNotice: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.dimText)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 22)
        .panel()
    }
}

// MARK: - Stat row

struct StatLine: View {
    let row: StatRow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: row.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(row.palette.color)
                .frame(width: 22)
            Text(row.label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.dimText)
            Spacer(minLength: 8)
            Text(row.value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monoDigits()
        }
        .padding(.vertical, 5)
    }
}
