import SwiftUI

struct WeekView: View {
    @EnvironmentObject var store: Store
    var onEdit: (ClassItem) -> Void

    private let hourHeight: CGFloat = 64
    private let axisWidth: CGFloat = 58
    private let headerHeight: CGFloat = 52

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let today = Weekdays.weekday(of: context.date)
            let now = Weekdays.minutes(of: context.date)
            let days = store.weekDays
            let range = store.hourRange

            GeometryReader { geo in
                let available = geo.size.width - 32 - axisWidth
                let colWidth = max(96, available / CGFloat(max(days.count, 1)))

                ScrollView(.vertical, showsIndicators: false) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            headerRow(days: days, today: today, colWidth: colWidth)
                            Rectangle().fill(Theme.line).frame(height: 1)
                            HStack(alignment: .top, spacing: 0) {
                                axis(range: range)
                                ForEach(days, id: \.self) { d in
                                    column(day: d, range: range, colWidth: colWidth,
                                           isToday: d == today, now: now)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func y(_ m: Int, _ range: (start: Int, end: Int)) -> CGFloat {
        CGFloat(m - range.start) / 60 * hourHeight
    }

    private func totalHeight(_ range: (start: Int, end: Int)) -> CGFloat {
        CGFloat(range.end - range.start) / 60 * hourHeight
    }

    private func headerRow(days: [Int], today: Int, colWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: axisWidth, height: headerHeight)
            ForEach(days, id: \.self) { d in
                VStack(spacing: 1) {
                    Text(Weekdays.names[d])
                        .font(.subheadline.weight(.semibold))
                    Text(Fmt.dayNumber(Weekdays.date(of: d)))
                        .font(.caption.monospacedDigit())
                        .opacity(0.8)
                }
                .foregroundColor(d == today ? SubjectColor.orange.ink : Theme.fg)
                .frame(width: colWidth, height: headerHeight)
            }
        }
    }

    private func axis(range: (start: Int, end: Int)) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: range.start + 60, to: range.end, by: 60)), id: \.self) { m in
                Text(Fmt.time(m))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .fixedSize()
                    .offset(y: y(m, range) - 7)
            }
        }
        .padding(.leading, 8)
        .frame(width: axisWidth, height: totalHeight(range), alignment: .topLeading)
    }

    private func column(day: Int, range: (start: Int, end: Int), colWidth: CGFloat,
                        isToday: Bool, now: Int) -> some View {
        let height = totalHeight(range)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: range.start + 30, to: range.end, by: 30)), id: \.self) { m in
                Rectangle()
                    .fill(Theme.line.opacity(m % 60 == 0 ? 1 : 0.5))
                    .frame(width: colWidth, height: 1)
                    .offset(y: y(m, range))
            }

            ForEach(store.classes(on: day)) { item in
                let h = max(22, CGFloat(item.duration) / 60 * hourHeight - 3)
                Button { onEdit(item) } label: {
                    block(item, height: h)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .frame(width: colWidth, height: h)
                .offset(y: y(item.start, range) + 1)
            }

            if isToday && now >= range.start && now <= range.end {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.orange).frame(width: colWidth, height: 2)
                    Circle().fill(Theme.orange).frame(width: 10, height: 10)
                }
                .frame(width: colWidth, height: 10, alignment: .leading)
                .offset(y: y(now, range) - 5)
                .allowsHitTesting(false)
            }
        }
        .frame(width: colWidth, height: height, alignment: .topLeading)
        .background(isToday ? SubjectColor.orange.soft.opacity(0.45) : Color.clear)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.line).frame(width: 1)
        }
    }

    private func block(_ item: ClassItem, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.subject)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.fg)
                .lineLimit(height < 46 ? 1 : 2)
            Text(Fmt.range(item.start, item.end))
                .font(.caption2.monospacedDigit())
                .foregroundColor(item.color.ink)
            if height >= 60 && !item.room.isEmpty {
                Text(item.room)
                    .font(.caption2)
                    .foregroundColor(item.color.ink)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(item.color.soft)
        .overlay(alignment: .leading) {
            Rectangle().fill(item.color.main).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
