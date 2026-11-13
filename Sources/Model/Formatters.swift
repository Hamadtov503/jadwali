import Foundation

enum Fmt {
    static let locale = Locale(identifier: "ar")

    /// 7:30 ص
    static func time(_ m: Int) -> String {
        short(m) + " " + (m / 60 < 12 ? "ص" : "م")
    }

    /// 7:30
    static func short(_ m: Int) -> String {
        let h = m / 60, mm = m % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):" + String(format: "%02d", mm)
    }

    static func duration(_ d: Int) -> String {
        if d < 60 { return "\(d) د" }
        let h = d / 60, m = d % 60
        if m > 0 { return "\(h) س \(m) د" }
        switch h {
        case 1: return "ساعة"
        case 2: return "ساعتان"
        default: return "\(h) ساعات"
        }
    }

    static func dayNumber(_ date: Date) -> String {
        String(Weekdays.calendar.component(.day, from: date))
    }

    private static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@calendar=gregorian;numbers=latn")
        f.calendar = Weekdays.calendar
        f.dateFormat = "EEEE، d MMMM"
        return f
    }()

    static func today(_ date: Date = Date()) -> String {
        longDate.string(from: date)
    }
}
