import Foundation
import UserNotifications

/// يجدول إشعارات قبل بداية الحصة ونهايتها بـ٥ دقائق، لأيام الدراسة الفعلية فقط.
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

        // إشعارات بتاريخ محدد للأيام القادمة، تتخطى الإجازات الرسمية وما بعد نهاية العام.
        // تُعاد جدولتها عند كل فتح للتطبيق أو حفظ.
        let cal = Weekdays.calendar
        let now = Date()
        let today = cal.startOfDay(for: now)
        var count = 0
        outer: for offset in 0..<21 {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            guard SchoolCalendar.isStudyDay(date) else { continue }
            let wd = Weekdays.weekday(of: date)
            for e in events.filter({ $0.weekday == wd && $0.minute >= 0 }).sorted(by: { $0.minute < $1.minute }) {
                guard let fire = cal.date(byAdding: .minute, value: e.minute, to: date), fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = e.title
                content.body = e.body
                content.sound = .default
                let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                center.add(UNNotificationRequest(identifier: "class-\(count)", content: content, trigger: trigger))
                count += 1
                if count >= limit { break outer }
            }
        }
    }

    private func describe(_ item: ClassItem) -> String {
        var parts = [item.title]
        if let p = item.period { parts.append("الحصة \(Fmt.n(p))") }
        if !item.room.isEmpty { parts.append(item.room) }
        return parts.joined(separator: " · ")
    }
}
