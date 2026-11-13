import Foundation

/// يحفظ الجدول في Application Support/classes.json على الجهاز.
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var items: [ClassItem] = []
    @Published private(set) var isExample = false

    private struct Saved: Codable {
        var items: [ClassItem]
        var isExample: Bool
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
        } else {
            items = ClassItem.examples
            isExample = true
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(Saved(items: items, isExample: isExample)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Queries

    func classes(on day: Int) -> [ClassItem] {
        items.filter { $0.weekday == day }.sorted { $0.start < $1.start }
    }

    /// الأحد إلى الخميس، مع أي يوم آخر فيه حصص.
    var weekDays: [Int] {
        Array(Set([0, 1, 2, 3, 4]).union(items.map(\.weekday))).sorted()
    }

    var hourRange: (start: Int, end: Int) {
        guard let minStart = items.map(\.start).min(), let maxEnd = items.map(\.end).max() else {
            return (7 * 60, 14 * 60)
        }
        let s = minStart / 60 * 60
        var e = Int((Double(maxEnd) / 60).rounded(.up)) * 60
        if e - s < 4 * 60 { e = s + 4 * 60 }
        return (s, min(e, 24 * 60))
    }

    func suggestedStart(on day: Int) -> Int {
        if let last = classes(on: day).last { return min(last.end + 5, 23 * 60) }
        return 7 * 60 + 30
    }

    var nextColor: SubjectColor {
        SubjectColor.allCases[(isExample ? 0 : items.count) % SubjectColor.allCases.count]
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

    func clearExamples() {
        items = []
        isExample = false
        save()
    }
}
