import Foundation

enum SubjectColor: String, Codable, CaseIterable, Identifiable {
    case green, orange, blue
    var id: String { rawValue }
    var title: String {
        switch self {
        case .green: return "أخضر"
        case .orange: return "برتقالي"
        case .blue: return "أزرق"
        }
    }
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

    var duration: Int { end - start }
    var meta: String { [room, teacher].filter { !$0.isEmpty }.joined(separator: " · ") }
}

extension ClassItem {
    static let examples: [ClassItem] = {
        let rows: [(String, Int, Int, Int, String, String, SubjectColor)] = [
            ("رياضيات", 0, 450, 495, "قاعة 12", "أ. سالم", .blue),
            ("فيزياء", 0, 500, 545, "مختبر 2", "أ. خالد", .green),
            ("لغة عربية", 0, 570, 615, "قاعة 12", "أ. ناصر", .orange),
            ("لغة إنجليزية", 0, 620, 665, "قاعة 7", "أ. فهد", .blue),
            ("كيمياء", 1, 450, 495, "مختبر 1", "أ. عبدالله", .green),
            ("رياضيات", 1, 500, 545, "قاعة 12", "أ. سالم", .blue),
            ("حاسب آلي", 1, 570, 660, "معمل الحاسب", "أ. ماجد", .orange),
            ("أحياء", 2, 450, 495, "مختبر 3", "أ. يوسف", .green),
            ("لغة عربية", 2, 500, 545, "قاعة 12", "أ. ناصر", .orange),
            ("رياضيات", 2, 570, 615, "قاعة 12", "أ. سالم", .blue),
            ("فيزياء", 3, 450, 495, "مختبر 2", "أ. خالد", .green),
            ("لغة إنجليزية", 3, 500, 545, "قاعة 7", "أ. فهد", .blue),
            ("تربية بدنية", 3, 570, 615, "الصالة", "أ. سعد", .orange),
            ("كيمياء", 4, 450, 495, "مختبر 1", "أ. عبدالله", .green),
            ("لغة عربية", 4, 500, 545, "قاعة 12", "أ. ناصر", .orange),
            ("رياضيات", 4, 570, 615, "قاعة 12", "أ. سالم", .blue),
        ]
        return rows.map { ClassItem(subject: $0.0, weekday: $0.1, start: $0.2, end: $0.3, room: $0.4, teacher: $0.5, color: $0.6) }
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
