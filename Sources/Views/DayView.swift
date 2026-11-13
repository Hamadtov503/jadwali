import SwiftUI

struct DayView: View {
    @EnvironmentObject var store: Store
    @Binding var selectedDay: Int
    var onEdit: (ClassItem) -> Void
    var onAdd: (Int) -> Void

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { context in
            let today = Weekdays.weekday(of: context.date)
            let now = Weekdays.minutes(of: context.date)
            let items = store.classes(on: selectedDay)
            let isToday = selectedDay == today

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DayStrip(selectedDay: $selectedDay, today: today)
                    SummaryCard(items: items, isToday: isToday, now: now, day: selectedDay)

                    if items.isEmpty {
                        emptyState(isToday: isToday)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    let gap = item.start - items[index - 1].end
                                    if gap >= 5 { GapRow(minutes: gap) }
                                }
                                ClassRow(item: item,
                                         state: rowState(item, isToday: isToday, now: now),
                                         now: now,
                                         onTap: { onEdit(item) })
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
    }

    private func rowState(_ item: ClassItem, isToday: Bool, now: Int) -> ClassRow.RowState {
        guard isToday else { return .upcoming }
        if now >= item.end { return .past }
        if now >= item.start { return .now }
        return .upcoming
    }

    private func emptyState(isToday: Bool) -> some View {
        VStack(spacing: 12) {
            Text(isToday ? "لا توجد حصص اليوم" : "لا توجد حصص يوم \(Weekdays.names[selectedDay])")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(Theme.fg)
            Button("إضافة حصة") { onAdd(selectedDay) }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.blue))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .card()
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
            return (Weekdays.names[day], "الحصة الأولى: \(first.subject)",
                    "من \(Fmt.time(first.start)) إلى \(Fmt.time(last.end))")
        }
        let current = items.first { $0.start <= now && now < $0.end }
        let next = items.first { $0.start > now }
        if let c = current {
            var detail = "تنتهي بعد \(Fmt.duration(c.end - now))"
            if let n = next { detail += " · تليها \(n.subject)" }
            return ("الحصة الحالية", c.subject, detail)
        }
        if let n = next {
            var detail = "تبدأ بعد \(Fmt.duration(n.start - now)) · \(Fmt.time(n.start))"
            if !n.room.isEmpty { detail += " · \(n.room)" }
            return ("الحصة التالية", n.subject, detail)
        }
        return ("اليوم", "انتهت حصص اليوم", "انتهت آخر حصة الساعة \(Fmt.time(last.end))")
    }

    var body: some View {
        let l = lines
        let total = items.reduce(0) { $0 + $1.duration }
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l.label)
                    .font(.caption)
                    .foregroundColor(Theme.muted)
                Text(l.title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(Theme.fg)
                if !l.detail.isEmpty {
                    Text(l.detail)
                        .font(.subheadline)
                        .foregroundColor(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .card()

            HStack(spacing: 10) {
                stat(value: "\(items.count)", label: "حصص")
                stat(value: total > 0 ? Fmt.duration(total) : "—", label: "إجمالي الوقت")
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundColor(Theme.fg)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .card()
    }
}

// MARK: - Rows

struct GapRow: View {
    let minutes: Int
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.line)
                .frame(width: 18, height: 2)
            Text("استراحة \(Fmt.duration(minutes))")
                .font(.caption)
                .foregroundColor(Theme.muted)
        }
        .padding(.leading, 64)
    }
}

struct ClassRow: View {
    enum RowState { case past, now, upcoming }

    let item: ClassItem
    let state: RowState
    let now: Int
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.short(item.start))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(Theme.fg)
                Text(Fmt.short(item.end))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.muted)
            }
            .frame(width: 52, alignment: .leading)
            .padding(.top, 14)

            Button(action: onTap) { card }
                .buttonStyle(.plain)
        }
        .opacity(state == .past ? 0.55 : 1)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.subject)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.fg)
                Spacer(minLength: 4)
                if state == .now {
                    Text("الآن")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.orange))
                } else {
                    Text(Fmt.duration(item.duration))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(item.color.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(item.color.soft))
                }
            }
            if !item.meta.isEmpty {
                Text(item.meta)
                    .font(.footnote)
                    .foregroundColor(Theme.muted)
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
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 14)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(state == .now ? item.color.soft : Theme.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(item.color.main).frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: Color.black.opacity(state == .past ? 0 : 0.05), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}
