import Foundation

/// يحفظ الجدول والإعدادات في Application Support/classes.json على الجهاز.
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var items: [ClassItem] = []
    @Published private(set) var isExample = false
    @Published private(set) var settings = SchoolSettings()

    private struct Saved: Codable {
        var items: [ClassItem]
        var isExample: Bool
        var settings: SchoolSettings?
        var rev: Int?
        var userName: String?
    }

    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("classes.json")
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            items = saved.items
            isExample = saved.isExample
            settings = saved.settings ?? SchoolSettings()
            // الإصدار السابق كان يضع 5 دقائق بين الحصص افتراضيًا.
            if (saved.rev ?? 1) < 2 { settings.passing = 0 }
            // الأسماء المحفوظة بأرقام إنجليزية تُحوَّل إلى أرقام عربية.
            settings.subjects = settings.subjects.map(Fmt.ar)
            for i in settings.classes.indices { settings.classes[i].name = Fmt.ar(settings.classes[i].name) }
            for i in items.indices {
                items[i].subject = Fmt.ar(items[i].subject)
                items[i].room = Fmt.ar(items[i].room)
                items[i].className = items[i].className.map(Fmt.ar)
            }
        } else {
            items = ClassItem.examples
            isExample = true
        }
        reflow()
        save()
    }

    // MARK: - Backup

    /// نسخة احتياطية من الجدول والإعدادات واسم المستخدم.
    func backupData() -> Data? {
        let saved = Saved(items: items, isExample: isExample, settings: settings, rev: 2,
                          userName: UserDefaults.standard.string(forKey: "userName"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try? encoder.encode(saved)
    }

    /// يستبدل البيانات الحالية بمحتوى نسخة احتياطية. يرجع false إن كان الملف غير صالح.
    func restore(from data: Data) -> Bool {
        guard let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return false }
        items = saved.items
        isExample = saved.isExample
        settings = saved.settings ?? SchoolSettings()
        if let name = saved.userName { UserDefaults.standard.set(name, forKey: "userName") }
        reflow()
        save()
        return true
    }

    private func save() {
        let saved = Saved(items: items, isExample: isExample, settings: settings, rev: 2, userName: nil)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// يعيد حساب أوقات الحصص المرتبطة برقم حصة بعد تغيير الإعدادات.
    private func reflow() {
        let slots = settings.periods()
        for i in items.indices {
            guard let n = items[i].period else { continue }
            if n >= 1 && n <= slots.count {
                items[i].start = slots[n - 1].start
                items[i].end = slots[n - 1].end
            } else {
                items[i].period = nil
            }
        }
    }

    // MARK: - Queries

    func classes(on day: Int) -> [ClassItem] {
        items.filter { $0.weekday == day }.sorted { $0.start < $1.start }
    }

    /// أيام الدراسة، مع أي يوم آخر فيه حصص.
    var weekDays: [Int] {
        let days = Set(settings.schoolDays).union(items.map(\.weekday))
        return days.isEmpty ? [0, 1, 2, 3, 4] : days.sorted()
    }

    func isSchoolDay(_ day: Int) -> Bool {
        settings.schoolDays.contains(day)
    }

    var hourRange: (start: Int, end: Int) {
        var starts = items.map(\.start)
        var ends = items.map(\.end)
        if let first = settings.periods().first, let last = settings.periods().last {
            starts.append(first.start)
            ends.append(last.end)
        }
        guard let minStart = starts.min(), let maxEnd = ends.max() else {
            return (7 * 60, 14 * 60)
        }
        let s = minStart / 60 * 60
        var e = Int((Double(maxEnd) / 60).rounded(.up)) * 60
        if e - s < 4 * 60 { e = s + 4 * 60 }
        return (s, min(e, 24 * 60))
    }

    /// أول حصة فارغة في اليوم.
    func freePeriod(on day: Int) -> Int? {
        let taken = classes(on: day)
        for (i, slot) in settings.periods().enumerated() {
            let busy = taken.contains { $0.start < slot.end && slot.start < $0.end }
            if !busy { return i + 1 }
        }
        return nil
    }

    func suggestedStart(on day: Int) -> Int {
        if let last = classes(on: day).last { return min(last.end + settings.passing, 23 * 60) }
        return settings.dayStart
    }

    var nextColor: SubjectColor {
        SubjectColor.allCases[(isExample ? 0 : items.count) % SubjectColor.allCases.count]
    }

    func conflict(with item: ClassItem) -> ClassItem? {
        items.first { $0.id != item.id && $0.overlaps(item) }
    }

    // MARK: - Mutations

    func upsert(_ item: ClassItem) {
        if isExample {
            items = []
            isExample = false
        }
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = item
        } else {
            items.append(item)
        }
        save()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        isExample = false
        save()
    }

    func clearAll() {
        items = []
        isExample = false
        save()
    }

    func updateSettings(_ new: SchoolSettings) {
        settings = new
        // تحديث اسم الفصل ولونه في الحصص المرتبطة به.
        for i in items.indices {
            guard let cid = items[i].classID else { continue }
            if let c = settings.schoolClass(cid) {
                items[i].className = c.name
                items[i].color = c.color
            } else {
                items[i].classID = nil
            }
        }
        reflow()
        save()
    }

    /// الحصة الموجودة في رقم حصة معيّن من يوم معيّن.
    func item(day: Int, period: Int) -> ClassItem? {
        let slots = settings.periods()
        if let exact = items.first(where: { $0.weekday == day && $0.period == period }) { return exact }
        guard period >= 1 && period <= slots.count else { return nil }
        let slot = slots[period - 1]
        return items.first { $0.weekday == day && $0.start < slot.end && slot.start < $0.end }
    }

    /// يضع فصلًا (ومادة) في حصة من الجدول.
    func assign(day: Int, period: Int, subject: String, schoolClass: SchoolClass?) {
        let slots = settings.periods()
        guard period >= 1 && period <= slots.count else { return }
        var item = (isExample ? nil : item(day: day, period: period))
            ?? ClassItem(subject: "", weekday: day, start: 0, end: 0)
        item.subject = subject
        item.period = period
        item.start = slots[period - 1].start
        item.end = slots[period - 1].end
        item.classID = schoolClass?.id
        item.className = schoolClass?.name
        item.color = schoolClass?.color ?? nextColor
        upsert(item)
    }
}
