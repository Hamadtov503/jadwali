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
        PopupShell(onDismissed: onClose) { close in
            VStack(alignment: .leading, spacing: 16) {
                header(close)

                if classes.isEmpty {
                    Button { close { onSettings() } } label: {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("أضف الفصول من الإعدادات")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.deepBrown))
                    }
                    .buttonStyle(.plain)
                } else {
                    if subjects.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("المادة")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Theme.muted)
                            SimpleGrid(items: subjects, columns: 2) { name in
                                Chip(title: name, selected: subject == name) { subject = name }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if subjects.count > 1 {
                            Text("الفصل")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Theme.muted)
                        }
                        SimpleGrid(items: classes, columns: 3) { c in
                            Chip(title: c.name, color: c.color,
                                 selected: existing?.classID == c.id && (chosenSubject ?? "") == (existing?.subject ?? "")) {
                                pick(c, close)
                            }
                            .opacity(chosenSubject == nil ? 0.4 : 1)
                            .disabled(chosenSubject == nil)
                        }
                    }
                }

                if let e = existing {
                    HStack(spacing: 10) {
                        Button {
                            close { quietly { store.delete(e.id) } }
                        } label: {
                            Label("إفراغ الحصة", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        Button { close { onDetails(e) } } label: {
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

    private func header(_ close: @escaping PopupClose) -> some View {
        let slots = store.settings.periods()
        let slot = target.period <= slots.count ? slots[target.period - 1] : (start: 0, end: 0)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Weekdays.names[target.day]) · الحصة \(Fmt.n(target.period))")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.fg)
                Text(Fmt.range(slot.start, slot.end))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(Theme.muted)
            }
            Spacer()
            Button { close(nil) } label: {
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

    private func pick(_ c: SchoolClass, _ close: PopupClose) {
        guard let subj = chosenSubject else { return }
        let day = target.day, period = target.period
        close { quietly { store.assign(day: day, period: period, subject: subj, schoolClass: c) } }
    }

    /// تغيير الجدول بلا حركة، حتى لا يومض الجدول خلف النافذة وهي تُغلق.
    private func quietly(_ change: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, change)
    }
}

typealias PopupClose = (_ then: (() -> Void)?) -> Void

/// إطار النوافذ المنبثقة: الخلفية تعتم تدريجيًا، والبطاقة تظهر معتمة تمامًا بسرعة
/// مع تكبير خفيف مثل تنبيهات النظام، فلا يظهر الجدول من خلالها.
struct PopupShell<Card: View>: View {
    var onDismissed: () -> Void
    @ViewBuilder var card: (@escaping PopupClose) -> Card
    @State private var shown = false
    @State private var closing = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(shown ? 0.35 : 0)
                .animation(.easeOut(duration: 0.22), value: shown)
                .ignoresSafeArea()
                .onTapGesture { close(nil) }

            card(close)
                .opacity(shown ? 1 : 0)
                .animation(.easeOut(duration: 0.09), value: shown)
                .scaleEffect(shown ? 1 : 1.06)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: shown)
        }
        .onAppear { shown = true }
    }

    private func close(_ then: (() -> Void)?) {
        guard !closing else { return }
        closing = true
        shown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            then?()
            onDismissed()
        }
    }
}

/// نافذة تأكيد بتنسيق التطبيق: «نعم» يمين و«لا» يسار.
struct ConfirmPopup: View {
    let title: String
    var onYes: () -> Void
    var onDismissed: () -> Void

    var body: some View {
        PopupShell(onDismissed: onDismissed) { close in
            VStack(spacing: 18) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.red))
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.fg)
                HStack(spacing: 10) {
                    Button { close { onYes() } } label: {
                        Text("نعم")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface2))
                    }
                    .buttonStyle(.plain)
                    Button { close(nil) } label: {
                        Text("لا")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
            )
            .padding(.horizontal, 44)
        }
    }
}
