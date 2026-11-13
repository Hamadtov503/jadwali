import SwiftUI

struct EditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var item: ClassItem
    private let isNew: Bool
    @State private var errorText: String?
    @State private var confirmDelete = false
    @FocusState private var subjectFocused: Bool

    init(target: EditorTarget) {
        _item = State(initialValue: target.item)
        isNew = target.isNew
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("المادة", text: $item.subject)
                        .focused($subjectFocused)
                    Picker("اليوم", selection: $item.weekday) {
                        ForEach(0..<7, id: \.self) { d in
                            Text(Weekdays.names[d]).tag(d)
                        }
                    }
                }

                Section {
                    Picker("الوقت", selection: periodBinding) {
                        ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                            Text("الحصة \(i + 1) · \(Fmt.short(slot.start))–\(Fmt.short(slot.end))").tag(i + 1)
                        }
                        Text("وقت مخصص").tag(0)
                    }
                    if item.period == nil {
                        DatePicker("من", selection: startBinding, displayedComponents: .hourAndMinute)
                        DatePicker("إلى", selection: endBinding, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    TextField("القاعة", text: $item.room)
                    TextField("المعلم", text: $item.teacher)
                }

                Section(header: Text("اللون")) {
                    HStack(spacing: 10) {
                        ForEach(SubjectColor.allCases) { c in
                            let on = item.color == c
                            Button { item.color = c } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(c.main).frame(width: 14, height: 14)
                                    Text(c.title)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.fg)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(on ? c.soft : Color.clear))
                                .overlay(Capsule().stroke(on ? c.main : Theme.line, lineWidth: 2))
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let e = errorText {
                    Section {
                        Text(e).foregroundColor(.red)
                    }
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Text("حذف الحصة")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "حصة جديدة" : "تعديل الحصة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ", action: save)
                        .font(.body.weight(.semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .confirmationDialog("حذف الحصة؟", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("حذف", role: .destructive) {
                    store.delete(item.id)
                    dismiss()
                }
                Button("إلغاء", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if isNew {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { subjectFocused = true }
            }
        }
    }

    // MARK: - Time bindings

    private var slots: [SchoolSettings.Slot] { store.settings.periods() }

    private var periodBinding: Binding<Int> {
        Binding(
            get: { item.period ?? 0 },
            set: { n in
                let s = slots
                if n >= 1 && n <= s.count {
                    item.period = n
                    item.start = s[n - 1].start
                    item.end = s[n - 1].end
                } else {
                    item.period = nil
                }
                errorText = nil
            }
        )
    }

    private func date(_ m: Int) -> Date {
        Weekdays.calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { date(item.start) },
            set: { newValue in
                let length = max(item.duration, 5)
                item.start = Weekdays.minutes(of: newValue)
                item.end = min(item.start + length, 23 * 60 + 59)
                errorText = nil
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { date(item.end) },
            set: { newValue in
                item.end = Weekdays.minutes(of: newValue)
                errorText = nil
            }
        )
    }

    // MARK: - Save

    private func save() {
        item.subject = item.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        item.room = item.room.trimmingCharacters(in: .whitespacesAndNewlines)
        item.teacher = item.teacher.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.subject.isEmpty else {
            errorText = "اكتب اسم المادة."
            subjectFocused = true
            return
        }
        guard item.end > item.start else {
            errorText = "يجب أن يكون وقت النهاية بعد وقت البداية."
            return
        }
        if !store.isExample, let other = store.conflict(with: item) {
            errorText = "يتعارض هذا الوقت مع حصة \(other.subject) (\(Fmt.time(other.start)) – \(Fmt.time(other.end)))."
            return
        }
        store.upsert(item)
        dismiss()
    }
}
