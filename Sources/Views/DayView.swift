import SwiftUI

struct DayView: View {
    @EnvironmentObject var store: Store
    @Binding var selectedDay: Int

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { context in
            let today = Weekdays.weekday(of: context.date)
            let now = Weekdays.minutes(of: context.date)
            let items = store.classes(on: selectedDay)
            let isToday = selectedDay == today

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DayStrip(selectedDay: $selectedDay, today: today)
                    if items.isEmpty && !store.isSchoolDay(selectedDay) {
                        VStack(spacing: 12) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(UIColor(hex: 0xFFC56B)))
                            Text("إجازة نهاية الأسبوع")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .card(Theme.deepGreen)
                    } else {
                    SummaryCard(items: items, isToday: isToday, now: now, day: selectedDay)

                    if items.isEmpty {
                        Text(isToday ? "لا توجد حصص اليوم" : "لا توجد حصص يوم \(Weekdays.names[selectedDay])")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .card()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(items) { item in
                                ClassRow(item: item,
                                         state: rowState(start: item.start, end: item.end, isToday: isToday, now: now),
                                         now: now)
                            }
                        }
                    }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func rowState(start: Int, end: Int, isToday: Bool, now: Int) -> ClassRow.RowState {
        guard isToday else { return .upcoming }
        if now >= end { return .past }
        if now >= start { return .now }
        return .upcoming
    }
}

// MARK: - Day strip

struct DayStrip: View {
    @EnvironmentObject var store: Store
    @Binding var selectedDay: Int
    let today: Int

    private var days: [Int] {
        Array(Set(store.weekDays).union([today, selectedDay])).sorted()
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { d in
                let selected = d == selectedDay
                let colors = store.classes(on: d).prefix(4).map(\.color)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedDay = d }
                } label: {
                    VStack(spacing: 3) {
                        Text(Weekdays.names[d])
                            .font(.caption.weight(d == today ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundColor(selected ? Color.white.opacity(0.85) : (d == today ? SubjectColor.orange.ink : Theme.muted))
                        Text(Fmt.dayNumber(Weekdays.date(of: d)))
                            .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                            .foregroundColor(selected ? .white : Theme.fg)
                        HStack(spacing: 3) {
                            ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                                Circle()
                                    .fill(selected ? Color.white.opacity(0.9) : c.main)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? Theme.blue : Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? Theme.blue : Theme.line, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Summary

struct SummaryCard: View {
    let items: [ClassItem]
    let isToday: Bool
    let now: Int
    let day: Int

    private var lines: (label: String, title: String, detail: String) {
        guard let first = items.first, let last = items.last else {
            return (isToday ? "اليوم" : Weekdays.names[day], "لا توجد حصص", "")
        }
        guard isToday else {
            return (Weekdays.names[day], "الحصة الأولى: \(first.title)",
                    "من \(Fmt.time(first.start)) إلى \(Fmt.time(last.end))")
        }
        let current = items.first { $0.start <= now && now < $0.end }
        let next = items.first { $0.start > now }
        if let c = current {
            var detail = "تنتهي بعد \(Fmt.duration(c.end - now))"
            if let n = next { detail += " · تليها \(n.title)" }
            return ("الحصة الحالية", c.title, detail)
        }
        if let n = next {
            var detail = "تبدأ بعد \(Fmt.duration(n.start - now)) · \(Fmt.time(n.start))"
            if !n.room.isEmpty { detail += " · \(n.room)" }
            return ("الحصة التالية", n.title, detail)
        }
        return ("اليوم", "انتهت حصص اليوم", "انتهت آخر حصة الساعة \(Fmt.time(last.end))")
    }

    var body: some View {
        let l = lines
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l.label)
                    .font(.caption)
                    .foregroundColor(Theme.muted)
                Text(l.title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(Theme.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !l.detail.isEmpty {
                    Text(l.detail)
                        .font(.subheadline)
                        .foregroundColor(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Theme.line).frame(width: 1, height: 44)

            VStack(spacing: 2) {
                Text(Fmt.n(items.count))
                    .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundColor(Theme.fg)
                Text(items.count == 1 ? "حصة" : "حصص")
                    .font(.caption)
                    .foregroundColor(Theme.muted)
            }
            .frame(width: 64)
        }
        .padding(16)
        .card()
    }
}

// MARK: - Rows

/// شكل موحّد لكل صف: رقم الحصة، ثم المحتوى، ثم الوقت.
struct RowLayout<Badge: View, Content: View>: View {
    let start: Int
    let end: Int
    var timeColor: Color = Theme.muted
    var height: CGFloat = 64
    @ViewBuilder var badge: Badge
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            badge
                .frame(width: 36, height: 36)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.range(start, end))
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundColor(timeColor)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: height)
    }
}

struct NowTag: View {
    var body: some View {
        Text("الآن")
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.orange))
    }
}

struct ClassRow: View {
    enum RowState { case past, now, upcoming }

    let item: ClassItem
    let state: RowState
    let now: Int

    var body: some View {
        Group {
            VStack(spacing: 0) {
                RowLayout(start: item.start, end: item.end, timeColor: state == .now ? item.color.ink : Theme.muted) {
                    Group {
                        if let p = item.period {
                            Text(Fmt.n(p))
                                .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
                        } else {
                            Image(systemName: "clock")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(state == .now ? .white : item.color.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(state == .now ? item.color.main : item.color.soft)
                    )
                } content: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(Theme.fg)
                                .lineLimit(1)
                            if state == .now { NowTag() }
                        }
                        if !item.meta.isEmpty {
                            Text(item.meta)
                                .font(.caption)
                                .foregroundColor(Theme.muted)
                                .lineLimit(1)
                        }
                    }
                }
                if state == .now {
                    let progress = CGFloat(now - item.start) / CGFloat(max(item.duration, 1))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surface2)
                            Capsule().fill(item.color.main)
                                .frame(width: geo.size.width * min(max(progress, 0), 1))
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
            .background(state == .now ? item.color.soft : Theme.surface)
            .overlay(alignment: .leading) {
                Rectangle().fill(item.color.main).frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Color.black.opacity(state == .past ? 0 : 0.05), radius: 10, x: 0, y: 4)
        }
        .opacity(state == .past ? 0.55 : 1)
    }
}
