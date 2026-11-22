import Foundation

/// التقويم الدراسي السعودي 1448هـ (2026–2027م) للتعليم العام.
/// التواريخ من التقويم المعلن، ومواعيد العيدين قد تتغير يومًا حسب رؤية الهلال.
enum SchoolCalendar {
    struct Span {
        let name: String
        let start: Date
        let end: Date   // آخر يوم داخل الفترة

        func contains(_ date: Date) -> Bool {
            let d = Weekdays.calendar.startOfDay(for: date)
            return d >= start && d <= end
        }
    }

    private static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Weekdays.calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    static let semesters: [Span] = [
        Span(name: "الفصل الدراسي الأول", start: day(2026, 8, 23), end: day(2027, 1, 7)),
        Span(name: "الفصل الدراسي الثاني", start: day(2027, 1, 17), end: day(2027, 6, 24)),
    ]

    static let holidays: [Span] = [
        Span(name: "إجازة اليوم الوطني", start: day(2026, 9, 23), end: day(2026, 9, 24)),
        Span(name: "إجازة الخريف", start: day(2026, 11, 20), end: day(2026, 11, 29)),
        Span(name: "إجازة منتصف العام", start: day(2027, 1, 8), end: day(2027, 1, 16)),
        Span(name: "إجازة يوم التأسيس", start: day(2027, 2, 21), end: day(2027, 2, 22)),
        Span(name: "إجازة عيد الفطر", start: day(2027, 2, 25), end: day(2027, 3, 13)),
        Span(name: "إجازة عيد الأضحى", start: day(2027, 5, 7), end: day(2027, 5, 22)),
    ]

    /// الإجازة التي يقع فيها التاريخ، ومنها إجازة نهاية العام بعد آخر فصل.
    static func holiday(on date: Date) -> Span? {
        if let h = holidays.first(where: { $0.contains(date) }) { return h }
        let d = Weekdays.calendar.startOfDay(for: date)
        if let last = semesters.last, d > last.end {
            return Span(name: "إجازة نهاية العام", start: Weekdays.calendar.date(byAdding: .day, value: 1, to: last.end) ?? d, end: d)
        }
        return nil
    }

    static func semester(on date: Date) -> Span? {
        semesters.first { $0.contains(date) }
    }

    /// يوم دراسة فعلي: داخل فصل وليس في إجازة.
    static func isStudyDay(_ date: Date) -> Bool {
        semester(on: date) != nil && holiday(on: date) == nil
    }

    /// رقم الأسبوع الدراسي داخل الفصل، دون عدّ الأسابيع التي كلها إجازة.
    static func week(on date: Date) -> (semester: String, number: Int)? {
        guard let s = semester(on: date) else { return nil }
        let cal = Weekdays.calendar
        func sunday(_ d: Date) -> Date {
            let start = cal.startOfDay(for: d)
            return cal.date(byAdding: .day, value: -Weekdays.weekday(of: start), to: start) ?? start
        }
        func hasStudy(_ weekStart: Date) -> Bool {
            (0..<5).contains { i in
                guard let d = cal.date(byAdding: .day, value: i, to: weekStart) else { return false }
                return s.contains(d) && holiday(on: d) == nil
            }
        }
        let target = sunday(date)
        guard hasStudy(target) else { return nil }
        var n = 0
        var w = sunday(s.start)
        while w <= target {
            if hasStudy(w) { n += 1 }
            guard let next = cal.date(byAdding: .day, value: 7, to: w) else { break }
            w = next
        }
        return (s.name, n)
    }

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@calendar=gregorian")
        f.calendar = Weekdays.calendar
        f.dateFormat = "d MMMM"
        return f
    }()

    /// عنوان الأسبوع الذي يقع فيه التاريخ: «الأسبوع ١٣» وتحته الفصل وتاريخ الأحد إلى الخميس.
    static func weekTitle(for ref: Date) -> (title: String, sub: String) {
        let sunday = Weekdays.date(of: 0, from: ref)
        let thursday = Weekdays.date(of: 4, from: ref)
        let range = dayRange(sunday, thursday)
        if let w = week(on: sunday) {
            return ("الأسبوع \(Fmt.n(w.number))", "\(w.semester) · \(range)")
        }
        if let h = holiday(on: sunday) ?? holiday(on: thursday) {
            return (h.name, range)
        }
        return ("خارج العام الدراسي", range)
    }

    /// يوم دراسة فعلي من الأحد إلى الخميس.
    static func isSchoolDay(_ date: Date) -> Bool {
        Weekdays.weekday(of: date) <= 4 && isStudyDay(date)
    }

    /// عدد أيام الدراسة من تاريخ إلى نهاية الفصل (يشمل اليوم نفسه).
    static func studyDaysLeft(from date: Date, to end: Date) -> Int {
        let cal = Weekdays.calendar
        var d = cal.startOfDay(for: date)
        var n = 0
        while d <= end {
            if isSchoolDay(d) { n += 1 }
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return n
    }

    /// عدد الأسابيع الدراسية في الفصل.
    static func totalWeeks(in s: Span) -> Int {
        week(on: lastStudyDay(in: s))?.number ?? 0
    }

    private static func lastStudyDay(in s: Span) -> Date {
        let cal = Weekdays.calendar
        var d = s.end
        while d > s.start, !isSchoolDay(d) {
            d = cal.date(byAdding: .day, value: -1, to: d) ?? s.start
        }
        return d
    }

    /// الفصل الحالي أو القادم.
    static func currentOrNextSemester(_ date: Date) -> Span? {
        let d = Weekdays.calendar.startOfDay(for: date)
        return semesters.first { d <= $0.end }
    }

    /// آخر أسبوع دراسي مرّ حتى هذا التاريخ (مفيد أثناء الإجازات).
    static func weeksDone(in s: Span, by date: Date) -> Int {
        let cal = Weekdays.calendar
        var d = min(cal.startOfDay(for: date), s.end)
        while d >= s.start {
            if isSchoolDay(d), let w = week(on: d) { return w.number }
            d = cal.date(byAdding: .day, value: -1, to: d) ?? s.start
            if d < s.start { break }
        }
        return 0
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Weekdays.calendar
        return cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }

    private static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@calendar=gregorian")
        f.calendar = Weekdays.calendar
        f.dateFormat = "d"
        return f
    }()

    /// «١٥ – ١٩ نوفمبر» أو «٢٩ نوفمبر – ٣ ديسمبر»
    static func dayRange(_ a: Date, _ b: Date) -> String {
        let sameMonth = Weekdays.calendar.component(.month, from: a) == Weekdays.calendar.component(.month, from: b)
        let first = sameMonth ? dayOnly.string(from: a) : shortDate.string(from: a)
        return Fmt.ar("\(first) – \(shortDate.string(from: b))")
    }

    /// «من ٢٠ نوفمبر إلى ٢٨ نوفمبر»
    static func rangeText(_ s: Span) -> String {
        Fmt.ar("من \(shortDate.string(from: s.start)) إلى \(shortDate.string(from: s.end))")
    }
}
