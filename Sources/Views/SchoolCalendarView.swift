import SwiftUI

/// التقويم الدراسي: ما بقي من الفصل، والإجازة القادمة، وكل مواعيد العام.
struct SchoolCalendarView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Event: Identifiable {
        let id = UUID()
        let name: String
        let start: Date
        let end: Date
        let icon: String
        let color: Color
    }

    private var events: [Event] {
        var list: [Event] = []
        for (i, s) in SchoolCalendar.semesters.enumerated() {
            list.append(Event(name: "بداية \(s.name)", start: s.start, end: s.start,
                              icon: "book.fill", color: Theme.green))
            list.append(Event(name: i == SchoolCalendar.semesters.count - 1 ? "نهاية العام الدراسي" : "نهاية \(s.name)",
                              start: s.end, end: s.end, icon: "flag.checkered", color: Theme.deepBrown))
        }
        for h in SchoolCalendar.holidays {
            list.append(Event(name: h.name, start: h.start, end: h.end,
                              icon: "beach.umbrella.fill", color: Theme.orange))
        }
        return list.sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    nextHolidayCard
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                            if i > 0 {
                                Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 58)
                            }
                            eventRow(e)
                        }
                    }
                    .card()
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("التقويم الدراسي")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Cards

    @ViewBuilder
    private var summaryCard: some View {
        let today = Date()
        if let s = SchoolCalendar.currentOrNextSemester(today) {
            let total = SchoolCalendar.totalWeeks(in: s)
            let started = today >= s.start
            let done = started ? SchoolCalendar.weeksDone(in: s, by: today) : 0
            let left = max(total - done, 0)
            let days = SchoolCalendar.studyDaysLeft(from: today, to: s.end)
            let progress = total > 0 ? CGFloat(done) / CGFloat(total) : 0
            VStack(alignment: .leading, spacing: 12) {
                Text(s.name)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.muted)
                if let w = SchoolCalendar.week(on: today) {
                    Text("الأسبوع \(Fmt.n(w.number)) من \(Fmt.n(total))")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.fg)
                } else if let h = SchoolCalendar.holiday(on: today) {
                    Text(h.name)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.fg)
                } else if !started {
                    Text("يبدأ بعد \(Self.days(SchoolCalendar.daysBetween(today, s.start)))")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.fg)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surface2)
                        Capsule().fill(Theme.deepBrown)
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 8)
                HStack(spacing: 10) {
                    stat(Fmt.n(left), left == 1 ? "أسبوع باقٍ" : "أسابيع باقية")
                    stat(Fmt.n(days), days == 1 ? "يوم دراسي باقٍ" : "أيام دراسية باقية")
                    stat(Fmt.n(max(SchoolCalendar.daysBetween(today, s.end), 0)), "يومًا حتى نهاية الفصل")
                }
            }
            .padding(16)
            .card()
        } else {
            Text("انتهى العام الدراسي")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .card()
        }
    }

    @ViewBuilder
    private var nextHolidayCard: some View {
        let today = Weekdays.calendar.startOfDay(for: Date())
        if let current = SchoolCalendar.holidays.first(where: { $0.contains(today) }) {
            let back = Weekdays.calendar.date(byAdding: .day, value: 1, to: current.end) ?? current.end
            holidayCard(label: "أنت الآن في", name: current.name,
                        detail: "العودة للدراسة بعد \(Self.days(SchoolCalendar.daysBetween(today, back)))",
                        range: SchoolCalendar.rangeText(current))
        } else if let next = SchoolCalendar.holidays.first(where: { $0.start > today }) {
            holidayCard(label: "الإجازة القادمة", name: next.name,
                        detail: "بعد \(Self.days(SchoolCalendar.daysBetween(today, next.start))) · \(Self.days(SchoolCalendar.studyDaysLeft(from: today, to: Weekdays.calendar.date(byAdding: .day, value: -1, to: next.start) ?? next.start))) دراسة",
                        range: SchoolCalendar.rangeText(next))
        }
    }

    private func holidayCard(label: String, name: String, detail: String, range: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "beach.umbrella.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.orange))
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.muted)
                Text(name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.fg)
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(SubjectColor.orange.ink)
                Text(range)
                    .font(.caption)
                    .foregroundColor(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .card()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(Theme.fg)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface2.opacity(0.7)))
    }

    private func eventRow(_ e: Event) -> some View {
        let today = Weekdays.calendar.startOfDay(for: Date())
        let past = e.end < today
        let now = e.start <= today && today <= e.end
        let range = e.start == e.end
            ? SchoolCalendar.dayRange(e.start, e.start).components(separatedBy: " – ").last ?? ""
            : SchoolCalendar.dayRange(e.start, e.end)
        let status: String = {
            if now { return "الآن" }
            if past { return "انتهت" }
            return "بعد \(Self.days(SchoolCalendar.daysBetween(today, e.start)))"
        }()
        return HStack(spacing: 12) {
            Image(systemName: e.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(e.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.fg)
                Text(range)
                    .font(.caption)
                    .foregroundColor(Theme.muted)
            }
            Spacer(minLength: 4)
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundColor(now ? .white : (past ? Theme.muted : SubjectColor.orange.ink))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(now ? Theme.orange : (past ? Color.clear : SubjectColor.orange.soft)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .opacity(past ? 0.5 : 1)
    }

    /// «يوم» «يومين» «٣ أيام» «١٢ يومًا»
    static func days(_ n: Int) -> String {
        switch n {
        case ...0: return "اليوم"
        case 1: return "يوم"
        case 2: return "يومين"
        case 3...10: return "\(Fmt.n(n)) أيام"
        default: return "\(Fmt.n(n)) يومًا"
        }
    }
}
