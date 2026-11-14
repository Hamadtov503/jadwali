import Foundation
import UserNotifications

/// يجدول إشعارات أسبوعية متكررة قبل بداية الحصة ونهايتها بخمس دقائق.
final class Notifier {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()
    private let lead = 5
    /// النظام لا يحتفظ بأكثر من 64 إشعارًا مجدولًا.
    private let limit = 60

    func requestPermission(_ done: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { done(granted) }
        }
    }

    private struct Event {
        let weekday: Int   // 0 = الأحد
        let minute: Int    // دقائق منذ منتصف الليل
        let title: String
        let body: String
    }

    func reschedule(items: [ClassItem], settings: SchoolSettings, isExample: Bool) {
        center.removeAllPendingNotificationRequests()
        guard !isExample, settings.notifyStart || settings.notifyEnd else { return }

        var events: [Event] = []
        let byDay = Dictionary(grouping: items, by: \.weekday)
        for (day, list) in byDay {
            let sorted = list.sorted { $0.start < $1.start }
            for (i, item) in sorted.enumerated() {
                let next = i + 1 < sorted.count ? sorted[i + 1] : nil
                // نهاية حصة تليها حصة مباشرة: إشعار واحد يجمع الاثنين.
                let backToBack = next.map { $0.start == item.end } ?? false

                if settings.notifyStart {
                    let prevEndsHere = i > 0 && sorted[i - 1].end == item.start
                    if !(prevEndsHere && settings.notifyEnd) {
                        events.append(Event(weekday: day, minute: item.start - lead,
                                            title: "تبدأ حصتك بعد \(Fmt.n(lead)) دقائق",
                                            body: describe(item)))
                    }
                }
                if settings.notifyEnd {
                    if backToBack, let n = next, settings.notifyStart {
                        events.append(Event(weekday: day, minute: item.end - lead,
                                            title: "تنتهي حصتك بعد \(Fmt.n(lead)) دقائق",
                                            body: "\(item.title)، وتليها \(describe(n))"))
                    } else {
                        events.append(Event(weekday: day, minute: item.end - lead,
                                            title: "تنتهي حصتك بعد \(Fmt.n(lead)) دقائق",
                                            body: item.title))
                    }
                }
            }
        }

        // الأقرب أولًا، حتى لا تضيع إشعارات الأيام القريبة إن تجاوزنا الحد.
        let now = Date()
        let cal = Weekdays.calendar
        let nowDay = Weekdays.weekday(of: now)
        let nowMin = Weekdays.minutes(of: now)
        func distance(_ e: Event) -> Int {
            var d = (e.weekday - nowDay) * 1440 + (e.minute - nowMin)
            if d <= 0 { d += 7 * 1440 }
            return d
        }
        let chosen = events.filter { $0.minute >= 0 }.sorted { distance($0) < distance($1) }.prefix(limit)

        for (i, e) in chosen.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = e.title
            content.body = e.body
            content.sound = .default
            var dc = DateComponents()
            dc.calendar = cal
            dc.weekday = e.weekday + 1
            dc.hour = e.minute / 60
            dc.minute = e.minute % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            center.add(UNNotificationRequest(identifier: "class-\(i)", content: content, trigger: trigger))
        }
    }

    private func describe(_ item: ClassItem) -> String {
        var parts = [item.title]
        if let p = item.period { parts.append("الحصة \(Fmt.n(p))") }
        if !item.room.isEmpty { parts.append(item.room) }
        return parts.joined(separator: " · ")
    }
}
