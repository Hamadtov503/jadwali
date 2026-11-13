import SwiftUI

/// جدول الأسبوع على شكل مربعات: الأيام أعمدة، والحصص صفوف.
struct WeekView: View {
    @EnvironmentObject var store: Store
    var onTap: (Int, Int) -> Void
    @State private var confirmClear = false

    private let labelWidth: CGFloat = 70
    private let spacing: CGFloat = 6

    var body: some View {
        content
            .alert("إفراغ الجدول؟", isPresented: $confirmClear) {
                Button("نعم", role: .destructive) { withAnimation { store.clearAll() } }
                Button("لا", role: .cancel) {}
            }
    }

    private var content: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let today = Weekdays.weekday(of: context.date)
            let now = Weekdays.minutes(of: context.date)
            let days = store.weekDays
            let slots = store.settings.periods()

            GeometryReader { geo in
                let count = CGFloat(max(days.count, 1))
                let free = geo.size.width - 32 - 24 - labelWidth - spacing * count
                let side = min(max(free / count, 46), 90)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: spacing) {
                        headerRow(days: days, today: today, side: side)

                        ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                            HStack(spacing: spacing) {
                                periodLabel(i + 1, slot)
                                ForEach(days, id: \.self) { d in
                                    cell(day: d, period: i + 1, side: side,
                                         isNow: d == today && slot.start <= now && now < slot.end)
                                }
                            }
                            if let b = store.settings.breakSlot(), i + 1 == store.settings.breakAfter {
                                breakRow(b)
                            }
                        }
                    }
                    .background(alignment: .topLeading) {
                        if let idx = days.firstIndex(of: today) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.deepBrown.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.deepBrown, lineWidth: 2)
                                )
                                .frame(width: side + 8)
                                .frame(maxHeight: .infinity)
                                .padding(.vertical, -5)
                                .padding(.leading, labelWidth + spacing + CGFloat(idx) * (side + spacing) - 4)
                        }
                    }
                    .padding(12)
                    .card()
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)

                    if !store.items.isEmpty && !store.isExample {
                        Button { confirmClear = true } label: {
                            Label("إفراغ الجدول", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(Theme.onBg.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)
                    }

                    Color.clear.frame(height: 24)
                }
            }
        }
    }

    private func headerRow(days: [Int], today: Int, side: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: labelWidth, height: 1)
            ForEach(days, id: \.self) { d in
                let isToday = d == today
                VStack(spacing: 1) {
                    Text(Weekdays.names[d])
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(Fmt.dayNumber(Weekdays.date(of: d)))
                        .font(.caption2.monospacedDigit())
                        .opacity(0.8)
                }
                .foregroundColor(isToday ? .white : Theme.fg)
                .frame(width: side)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isToday ? Theme.deepBrown : Color.clear)
                )
            }
        }
    }

    private func periodLabel(_ n: Int, _ slot: SchoolSettings.Slot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("الحصة \(Fmt.n(n))")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.fg)
            Text(Fmt.range(slot.start, slot.end))
                .font(.caption2.monospacedDigit())
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: labelWidth, alignment: .leading)
    }

    private func breakRow(_ b: SchoolSettings.Slot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 12))
            Text("الفسحة")
                .font(.caption.weight(.semibold))
            Spacer()
            Text(Fmt.range(b.start, b.end))
                .font(.caption2.monospacedDigit())
        }
        .foregroundColor(SubjectColor.orange.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SubjectColor.orange.soft)
        )
    }

    @ViewBuilder
    private func cell(day: Int, period: Int, side: CGFloat, isNow: Bool) -> some View {
        let item = store.item(day: day, period: period)
        Button { onTap(day, period) } label: {
            ZStack {
                if let item = item {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.color.soft)
                    VStack(spacing: 2) {
                        Text(item.title)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundColor(item.color.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                        if item.className != nil && !item.subject.isEmpty && store.settings.subjects.count > 1 {
                            Text(item.subject)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(item.color.ink.opacity(0.8))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .padding(4)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
            }
            .frame(width: side, height: side)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isNow ? Theme.orange : Color.clear, lineWidth: 2.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Weekdays.names[day]) الحصة \(period)" + (item.map { " \($0.title)" } ?? ""))
    }
}
