import SwiftUI

struct DayView: View {
    @EnvironmentObject var store: Store
    @Binding var selectedDay: Int
    var onEdit: (ClassItem) -> Void
    var onAdd: (Int, Int?) -> Void

    /// عنصر في الخط الزمني: حصة مسجّلة أو حصة فارغة من إعدادات اليوم الدراسي.
    enum Entry: Identifiable {
        case lesson(ClassItem)
        case free(period: Int, start: Int, end: Int)

        var id: String {
            switch self {
            case .lesson(let c): return c.id.uuidString
            case .free(let p, _, _): return "free-\(p)"
            }
        }
        var start: Int {
            switch self {
            case .lesson(let c): return c.start
            case .free(_, let s, _): return s
            }
        }
        var end: Int {
            switch self {
            case .lesson(let c): return c.end
            case .free(_, _, let e): return e
            }
        }
    }

    private func entries(for items: [ClassItem]) -> [Entry] {
        var out = items.map { Entry.lesson($0) }
        if store.isSchoolDay(selectedDay) && !store.isExample {
            for (i, slot) in store.settings.periods().enumerated() {
                let busy = items.contains { $0.start < slot.end && slot.start < $0.end }
                if !busy { out.append(.free(period: i + 1, start: slot.start, end: slot.end)) }
            }
        }
        return out.sorted { $0.start < $1.start }
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { context in
            let today = Weekdays.weekday(of: context.date)
            let now = Weekdays.minutes(of: context.date)
            let items = store.classes(on: selectedDay)
            let list = entries(for: items)
            let isToday = selectedDay == today

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DayStrip(selectedDay: $selectedDay, today: today)
                    SummaryCard(items: items, isToday: isToday, now: now, day: selectedDay)

                    if list.isEmpty {
                        emptyState(isToday: isToday)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 {
                                    let gap = entry.start - list[index - 1].end
                                    if gap >= 10 { GapRow(minutes: gap) }
                                }
                                switch entry {
                                case .lesson(let item):
                                    ClassRow(item: item,
                                             state: rowState(start: item.start, end: item.end, isToday: isToday, now: now),
                                             now: now,
                                             onTap: { onEdit(item) })
                                case .free(let period, let start, let end):
                                    FreePeriodRow(period: period, start: start, end: end,
                                                  isPast: rowState(start: start, end: end, isToday: isToday, now: now) == .past,
                                                  onTap: { onAdd(selectedDay, period) })
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
    }

    private func rowState(start: Int, end: Int, isToday: Bool, now: Int) -> ClassRow.RowState {
        guard isToday else { return .upcoming }
        if now >= end { return .past }
        if now >= start { return .now }
        return .upcoming
    }

    private func emptyState(isToday: Bool) -> some View {
        VStack(spacing: 12) {
            Text(isToday ? "لا توجد حصص اليوم" : "لا توجد حصص يوم \(Weekdays.names[selectedDay])")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(Theme.fg)
            Button("إضافة حصة") { onAdd(selectedDay, nil) }
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

struct FreePeriodRow: View {
    let period: Int
    let start: Int
    let end: Int
    let isPast: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.short(start))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(Theme.muted)
                Text(Fmt.short(end))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.muted)
            }
            .frame(width: 52, alignment: .leading)

            Button(action: onTap) {
                HStack {
                    Text("الحصة \(period)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.muted)
                    Spacer()
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("إضافة حصة في الحصة \(period)")
        }
        .opacity(isPast ? 0.5 : 1)
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
            let metaLine = ([item.period.map { "الحصة \($0)" }].compactMap { $0 } + (item.meta.isEmpty ? [] : [item.meta]))
                .joined(separator: " · ")
            if !metaLine.isEmpty {
                Text(metaLine)
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
