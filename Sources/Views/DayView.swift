import SwiftUI

struct DayView: View {
    @EnvironmentObject var store: Store
    @Binding var selectedDay: Int
    var onEdit: (ClassItem) -> Void
    var onAdd: (Int, Int?) -> Void

    /// عنصر في الجدول: حصة مسجّلة، أو حصة فارغة، أو الفسحة.
    enum Entry: Identifiable {
        case lesson(ClassItem)
        case free(period: Int, start: Int, end: Int)
        case rest(start: Int, end: Int)

        var id: String {
            switch self {
            case .lesson(let c): return c.id.uuidString
            case .free(let p, _, _): return "free-\(p)"
            case .rest: return "rest"
            }
        }
        var start: Int {
            switch self {
            case .lesson(let c): return c.start
            case .free(_, let s, _), .rest(let s, _): return s
            }
        }
        var end: Int {
            switch self {
            case .lesson(let c): return c.end
            case .free(_, _, let e), .rest(_, let e): return e
            }
        }
    }

    private func entries(for items: [ClassItem]) -> [Entry] {
        var out = items.map { Entry.lesson($0) }
        if store.isSchoolDay(selectedDay) {
            for (i, slot) in store.settings.periods().enumerated() {
                let busy = items.contains { $0.start < slot.end && slot.start < $0.end }
                if !busy { out.append(.free(period: i + 1, start: slot.start, end: slot.end)) }
            }
            if let b = store.settings.breakSlot(),
               !items.contains(where: { $0.start < b.end && b.start < $0.end }) {
                out.append(.rest(start: b.start, end: b.end))
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
                        VStack(spacing: 8) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 {
                                    let gap = entry.start - list[index - 1].end
                                    if gap >= 10 { GapRow(minutes: gap) }
                                }
                                let state = rowState(start: entry.start, end: entry.end, isToday: isToday, now: now)
                                switch entry {
                                case .lesson(let item):
                                    ClassRow(item: item, state: state, now: now, onTap: { onEdit(item) })
                                case .free(let period, let start, let end):
                                    FreePeriodRow(period: period, start: start, end: end,
                                                  isPast: state == .past,
                                                  onTap: { onAdd(selectedDay, period) })
                                case .rest(let start, let end):
                                    BreakRow(start: start, end: end, state: state)
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
        let total = items.reduce(0) { $0 + $1.duration }
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
                Text("\(items.count)")
                    .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundColor(Theme.fg)
                Text(items.count == 1 ? "حصة" : "حصص")
                    .font(.caption)
                    .foregroundColor(Theme.muted)
                if total > 0 {
                    Text(Fmt.duration(total))
                        .font(.caption2)
                        .foregroundColor(Theme.muted)
                }
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

struct GapRow: View {
    let minutes: Int
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Text(Fmt.duration(minutes))
                .font(.caption2)
                .foregroundColor(Theme.muted)
                .fixedSize()
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .padding(.horizontal, 24)
    }
}

struct BreakRow: View {
    let start: Int
    let end: Int
    let state: ClassRow.RowState

    var body: some View {
        RowLayout(start: start, end: end, timeColor: SubjectColor.orange.ink, height: 50) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 15))
                .foregroundColor(SubjectColor.orange.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface.opacity(0.7)))
                .padding(.vertical, 2)
        } content: {
            HStack(spacing: 8) {
                Text("الفسحة")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(SubjectColor.orange.ink)
                if state == .now { NowTag() }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(SubjectColor.orange.soft)
        )
        .opacity(state == .past ? 0.55 : 1)
    }
}

struct FreePeriodRow: View {
    let period: Int
    let start: Int
    let end: Int
    let isPast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RowLayout(start: start, end: end) {
                Text("\(period)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    )
            } content: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("حصة فارغة")
                        .font(.subheadline)
                }
                .foregroundColor(Theme.muted)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("إضافة حصة في الحصة \(period)")
        .opacity(isPast ? 0.5 : 1)
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                RowLayout(start: item.start, end: item.end, timeColor: state == .now ? item.color.ink : Theme.muted) {
                    Group {
                        if let p = item.period {
                            Text("\(p)")
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
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(state == .past ? 0.55 : 1)
    }
}
