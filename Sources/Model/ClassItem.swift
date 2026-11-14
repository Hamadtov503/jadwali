import Foundation

enum SubjectColor: String, Codable, CaseIterable, Identifiable {
    case green, orange, blue, purple, pink, teal, red, yellow
    case indigo, brown, mint, lime, navy, maroon, sky, gray
    var id: String { rawValue }
    var title: String {
        switch self {
        case .green: return "أخضر"
        case .orange: return "برتقالي"
        case .blue: return "أزرق"
        case .purple: return "بنفسجي"
        case .pink: return "وردي"
        case .teal: return "فيروزي"
        case .red: return "أحمر"
        case .yellow: return "ذهبي"
        case .indigo: return "نيلي"
        case .brown: return "بني"
        case .mint: return "نعناعي"
        case .lime: return "ليموني"
        case .navy: return "كحلي"
        case .maroon: return "عنابي"
        case .sky: return "سماوي"
        case .gray: return "رمادي"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SubjectColor(rawValue: raw) ?? .blue
    }
}

/// فصل يدرّسه المعلم، وله لون.
struct SchoolClass: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var color: SubjectColor
}

/// حصة أسبوعية متكررة.
struct ClassItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var subject: String
    /// 0 = الأحد … 6 = السبت
    var weekday: Int
    /// دقائق منذ منتصف الليل
    var start: Int
    var end: Int
    var room: String = ""
    var teacher: String = ""
    var color: SubjectColor = .blue
    /// رقم الحصة (يبدأ من 1). nil = وقت مخصص.
    var period: Int? = nil
    /// الفصل المرتبط بالحصة.
    var classID: UUID? = nil
    var className: String? = nil

    var duration: Int { end - start }
    /// العنوان الرئيسي: اسم الفصل إن وُجد، وإلا المادة.
    var title: String {
        if let c = className, !c.isEmpty { return c }
        return subject
    }
    /// السطر الثاني: المادة (إن كان العنوان فصلًا) ثم القاعة والمعلم.
    var meta: String {
        let hasClass = !(className ?? "").isEmpty
        return [hasClass ? subject : "", room, teacher].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func overlaps(_ other: ClassItem) -> Bool {
        weekday == other.weekday && start < other.end && other.start < end
    }
}

/// إعدادات اليوم الدراسي.
struct SchoolSettings: Codable, Equatable {
    var dayStart = 7 * 60
    var periodsPerDay = 7
    var periodLength = 45
    var passing = 0
    var hasBreak = true
    var breakAfter = 3
    var breakLength = 25
    var schoolDays: [Int] = [0, 1, 2, 3, 4]
    var subjects: [String] = []
    var classes: [SchoolClass] = []
    /// عدد الحصص في يوم معيّن إن كان أقل من العدد العام (المفتاح: رقم اليوم).
    var dayPeriods: [String: Int] = [:]
    var notifyStart = false
    var notifyEnd = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case dayStart, periodsPerDay, periodLength, passing, hasBreak, breakAfter, breakLength
        case schoolDays, subjects, classes, dayPeriods, notifyStart, notifyEnd
    }

    /// يقرأ الإعدادات القديمة التي لا تحوي الحقول الجديدة.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SchoolSettings()
        dayStart = try c.decodeIfPresent(Int.self, forKey: .dayStart) ?? d.dayStart
        periodsPerDay = try c.decodeIfPresent(Int.self, forKey: .periodsPerDay) ?? d.periodsPerDay
        periodLength = try c.decodeIfPresent(Int.self, forKey: .periodLength) ?? d.periodLength
        passing = try c.decodeIfPresent(Int.self, forKey: .passing) ?? d.passing
        hasBreak = try c.decodeIfPresent(Bool.self, forKey: .hasBreak) ?? d.hasBreak
        breakAfter = try c.decodeIfPresent(Int.self, forKey: .breakAfter) ?? d.breakAfter
        breakLength = try c.decodeIfPresent(Int.self, forKey: .breakLength) ?? d.breakLength
        schoolDays = try c.decodeIfPresent([Int].self, forKey: .schoolDays) ?? d.schoolDays
        subjects = try c.decodeIfPresent([String].self, forKey: .subjects) ?? []
        classes = try c.decodeIfPresent([SchoolClass].self, forKey: .classes) ?? []
        dayPeriods = try c.decodeIfPresent([String: Int].self, forKey: .dayPeriods) ?? [:]
        notifyStart = try c.decodeIfPresent(Bool.self, forKey: .notifyStart) ?? false
        notifyEnd = try c.decodeIfPresent(Bool.self, forKey: .notifyEnd) ?? false
    }

    /// عدد حصص يوم معيّن.
    func periodCount(on day: Int) -> Int {
        min(dayPeriods[String(day)] ?? periodsPerDay, periodsPerDay)
    }

    func schoolClass(_ id: UUID?) -> SchoolClass? {
        guard let id = id else { return nil }
        return classes.first { $0.id == id }
    }

    /// أول لون لم يُستخدم لفصل بعد.
    var nextClassColor: SubjectColor {
        let used = Set(classes.map(\.color))
        return SubjectColor.allCases.first { !used.contains($0) }
            ?? SubjectColor.allCases[classes.count % SubjectColor.allCases.count]
    }

    typealias Slot = (start: Int, end: Int)

    func periods() -> [Slot] {
        var out: [Slot] = []
        var t = dayStart
        let count = max(periodsPerDay, 1)
        for i in 1...count {
            let end = t + periodLength
            if end > 24 * 60 { break }
            out.append((start: t, end: end))
            t = end
            if i < count {
                t += (hasBreak && i == breakAfter) ? breakLength : passing
            }
        }
        return out
    }

    /// موعد الفسحة إن وُجدت.
    func breakSlot() -> Slot? {
        let p = periods()
        guard hasBreak, breakAfter >= 1, breakAfter < p.count else { return nil }
        return (start: p[breakAfter - 1].end, end: p[breakAfter].start)
    }
}

extension ClassItem {
    static let examples: [ClassItem] = {
        let rows: [(String, Int, Int, String, String, SubjectColor)] = [
            ("رياضيات", 0, 1, "قاعة 12", "أ. سالم", .blue),
            ("فيزياء", 0, 2, "مختبر 2", "أ. خالد", .green),
            ("لغة عربية", 0, 3, "قاعة 12", "أ. ناصر", .orange),
            ("لغة إنجليزية", 0, 4, "قاعة 7", "أ. فهد", .blue),
            ("كيمياء", 1, 1, "مختبر 1", "أ. عبدالله", .green),
            ("رياضيات", 1, 2, "قاعة 12", "أ. سالم", .blue),
            ("حاسب آلي", 1, 4, "معمل الحاسب", "أ. ماجد", .orange),
            ("أحياء", 2, 1, "مختبر 3", "أ. يوسف", .green),
            ("لغة عربية", 2, 2, "قاعة 12", "أ. ناصر", .orange),
            ("رياضيات", 2, 4, "قاعة 12", "أ. سالم", .blue),
            ("فيزياء", 3, 1, "مختبر 2", "أ. خالد", .green),
            ("لغة إنجليزية", 3, 2, "قاعة 7", "أ. فهد", .blue),
            ("تربية بدنية", 3, 3, "الصالة", "أ. سعد", .orange),
            ("كيمياء", 4, 1, "مختبر 1", "أ. عبدالله", .green),
            ("لغة عربية", 4, 2, "قاعة 12", "أ. ناصر", .orange),
            ("رياضيات", 4, 4, "قاعة 12", "أ. سالم", .blue),
        ]
        return rows.map {
            ClassItem(subject: $0.0, weekday: $0.1, start: 0, end: 0,
                      room: $0.3, teacher: $0.4, color: $0.5, period: $0.2)
        }
    }()
}

enum Weekdays {
    static let names = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    static let calendar = Calendar(identifier: .gregorian)

    static func weekday(of date: Date) -> Int {
        calendar.component(.weekday, from: date) - 1
    }

    static func minutes(of date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// تاريخ اليوم المطلوب داخل الأسبوع الحالي (يبدأ الأسبوع بالأحد).
    static func date(of day: Int, from ref: Date = Date()) -> Date {
        let today = calendar.startOfDay(for: ref)
        let offset = day - weekday(of: today)
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }
}
