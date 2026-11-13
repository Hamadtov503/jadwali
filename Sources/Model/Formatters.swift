import Foundation

enum Fmt {
    static let locale = Locale(identifier: "ar")

    /// يحوّل الأرقام إلى أرقام عربية (٠١٢٣٤٥٦٧٨٩).
    static func ar(_ s: String) -> String {
        String(s.map { c -> Character in
            if let d = c.wholeNumberValue, c.isASCII {
                return Character(UnicodeScalar(0x0660 + d)!)
            }
            return c
        })
    }

    static func n(_ v: Int) -> String { ar(String(v)) }

    /// ٧:٣٠ ص
    static func time(_ m: Int) -> String {
        short(m) + " " + (m / 60 < 12 ? "ص" : "م")
    }

    /// ٧:٣٠
    static func short(_ m: Int) -> String {
        let h = m / 60, mm = m % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return ar("\(h12):" + String(format: "%02d", mm))
    }

    /// ٧:٠٠ - ٧:٤٥ (البداية على اليمين دائمًا)
    static func range(_ a: Int, _ b: Int) -> String {
        "\u{2067}\(short(a)) - \(short(b))\u{2069}"
    }

    static func duration(_ d: Int) -> String {
        if d < 60 { return "\(n(d)) د" }
        let h = d / 60, m = d % 60
        if m > 0 { return "\(n(h)) س \(n(m)) د" }
        switch h {
        case 1: return "ساعة"
        case 2: return "ساعتان"
        default: return "\(n(h)) ساعات"
        }
    }

    static func dayNumber(_ date: Date) -> String {
        n(Weekdays.calendar.component(.day, from: date))
    }

    private static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@calendar=gregorian;numbers=latn")
        f.calendar = Weekdays.calendar
        f.dateFormat = "EEEE، d MMMM"
        return f
    }()

    static func today(_ date: Date = Date()) -> String {
        ar(longDate.string(from: date))
    }
}
