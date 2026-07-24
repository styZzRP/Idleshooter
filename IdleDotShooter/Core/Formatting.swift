import Foundation

/// Compact display of the very large numbers an idle economy produces.
enum Fmt {

    private static let suffixes = [
        "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
        "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc",
        "Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg"
    ]

    /// 1234 -> "1.23K", 1_500_000 -> "1.50M"
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        let sign = value < 0 ? "-" : ""
        let v = abs(value)

        if v < 1 {
            if v == 0 { return "0" }
            if v < 0.01 { return sign + "0" }
            return sign + String(format: "%.2f", v)
        }
        if v < 1000 {
            if v < 100 { return sign + trimmed(String(format: "%.1f", v)) }
            return sign + String(format: "%.0f", v)
        }

        let tier = Int(floor(log10(v) / 3.0))
        guard tier < suffixes.count else {
            return sign + String(format: "%.2e", v)
        }
        let scaled = v / pow(1000.0, Double(tier))
        let text: String
        if scaled < 10 {
            text = String(format: "%.2f", scaled)
        } else if scaled < 100 {
            text = String(format: "%.1f", scaled)
        } else {
            text = String(format: "%.0f", scaled)
        }
        return sign + trimmed(text) + suffixes[tier]
    }

    static func cash(_ value: Double) -> String { "$" + number(value) }

    /// Whole numbers that never need a decimal (counters, levels).
    static func count(_ value: Double) -> String {
        if abs(value) < 1000 { return String(format: "%.0f", value) }
        return number(value)
    }

    static func integer(_ value: Int) -> String { count(Double(value)) }

    /// 1.0 -> "x1.00"
    static func multiplier(_ value: Double) -> String {
        "x" + (value < 100 ? String(format: "%.2f", value) : number(value))
    }

    /// 0.153 -> "15.3%"
    static func percent(_ fraction: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", fraction * 100)
    }

    /// Seconds -> "1h 04m", "3m 12s", "9.4s"
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0s" }
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(String(format: "%02d", minutes))m" }
        if minutes > 0 { return "\(minutes)m \(String(format: "%02d", secs))s" }
        if seconds < 10 { return String(format: "%.1fs", seconds) }
        return "\(secs)s"
    }

    /// Short cooldown display used on the ability buttons: "12.4" / "1:05"
    static func cooldown(_ seconds: Double) -> String {
        if seconds >= 60 {
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            return "\(m):" + String(format: "%02d", s)
        }
        return String(format: "%.1f", max(0, seconds))
    }

    private static func trimmed(_ text: String) -> String {
        guard text.contains(".") else { return text }
        var out = text
        while out.hasSuffix("0") { out.removeLast() }
        if out.hasSuffix(".") { out.removeLast() }
        return out
    }
}
