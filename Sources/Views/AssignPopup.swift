import SwiftUI

/// الحصة المراد تعبئتها من الجدول.
struct AssignTarget: Identifiable, Equatable {
    var id: String { "\(day)-\(period)" }
    let day: Int
    let period: Int
}

/// نافذة منبثقة لاختيار الفصل (والمادة إن كان للمعلم أكثر من مادة).
struct AssignPopup: View {
    @EnvironmentObject var store: Store
    let target: AssignTarget
    var onClose: () -> Void
    var onSettings: () -> Void
    var onDetails: (ClassItem) -> Void

    @State private var subject: String?

    private var existing: ClassItem? {
        store.isExample ? nil : store.item(day: target.day, period: target.period)
    }

    private var subjects: [String] { store.settings.subjects }
    private var classes: [SchoolClass] { store.settings.classes }

    private var chosenSubject: String? {
        if subjects.count <= 1 { return subjects.first ?? "" }
        return subject
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 16) {
                header

                if classes.isEmpty {
                    Button(action: onSettings) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("أضف الفصول من الإعدادات")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.green))
                    }
                    .buttonStyle(.plain)
                } else {
                    if subjects.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("المادة")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Theme.muted)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                ForEach(subjects, id: \.self) { name in
                                    Chip(title: name, selected: subject == name) { subject = name }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if subjects.count > 1 {
                            Text("الفصل")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Theme.muted)
                        }
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(classes) { c in
                                Chip(title: c.name, color: c.color,
                                     selected: existing?.classID == c.id && (chosenSubject ?? "") == (existing?.subject ?? "")) {
                                    pick(c)
                                }
                                .opacity(chosenSubject == nil ? 0.4 : 1)
                                .disabled(chosenSubject == nil)
                            }
                        }
                    }
                }

                if let e = existing {
                    HStack(spacing: 10) {
                        Button {
                            store.delete(e.id)
                            onClose()
                        } label: {
                            Label("إفراغ الحصة", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        Button { onDetails(e) } label: {
                            Label("التفاصيل", systemImage: "square.and.pencil")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(Theme.fg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
            )
            .padding(.horizontal, 22)
        }
        .onAppear {
            if let e = existing, subjects.contains(e.subject) { subject = e.subject }
        }
    }

    private var header: some View {
        let slots = store.settings.periods()
        let slot = target.period <= slots.count ? slots[target.period - 1] : (start: 0, end: 0)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Weekdays.names[target.day]) · الحصة \(target.period)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.fg)
                Text(Fmt.range(slot.start, slot.end))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(Theme.muted)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.surface2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("إغلاق")
        }
    }

    private func pick(_ c: SchoolClass) {
        guard let subj = chosenSubject else { return }
        store.assign(day: target.day, period: target.period, subject: subj, schoolClass: c)
        onClose()
    }
}
