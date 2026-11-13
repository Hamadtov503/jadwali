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
 Group {
                Section(header: SectionTitle("المادة")) {
                    if !store.settings.subjects.isEmpty {
                        LazyVGrid(columns: grid(2), spacing: 8) {
                            ForEach(store.settings.subjects, id: \.self) { name in
                                Chip(title: name, selected: item.subject == name) { item.subject = name }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    TextField("المادة", text: $item.subject.arabicDigits)
                        .focused($subjectFocused)
                }

                if !store.settings.classes.isEmpty {
                    Section(header: SectionTitle("الفصل")) {
                        LazyVGrid(columns: grid(3), spacing: 8) {
                            ForEach(store.settings.classes) { c in
                                Chip(title: c.name, color: c.color, selected: item.classID == c.id) {
                                    if item.classID == c.id {
                                        item.classID = nil
                                        item.className = nil
                                    } else {
                                        item.classID = c.id
                                        item.className = c.name
                                        item.color = c.color
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section(header: SectionTitle("اليوم")) {
                    LazyVGrid(columns: grid(4), spacing: 8) {
                        ForEach(dayChoices, id: \.self) { d in
                            Chip(title: Weekdays.names[d], selected: item.weekday == d) {
                                item.weekday = d
                                errorText = nil
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section(header: SectionTitle("الحصة")) {
                    LazyVGrid(columns: grid(2), spacing: 8) {
                        ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                            Chip(title: "\(Fmt.n(i + 1)) · \(Fmt.range(slot.start, slot.end))",
                                 selected: item.period == i + 1) { setPeriod(i + 1) }
                        }
                        Chip(title: "وقت مخصص", selected: item.period == nil) { setPeriod(0) }
                    }
                    .padding(.vertical, 6)
                    if item.period == nil {
                        DatePicker("من", selection: startBinding, displayedComponents: .hourAndMinute)
                        DatePicker("إلى", selection: endBinding, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    TextField("القاعة", text: $item.room.arabicDigits)
                }

                if item.classID == nil {
                    Section(header: SectionTitle("اللون")) {
                        ColorGrid(selection: $item.color)
                    }
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
            .listRowBackground(Theme.surface)
            }
            .appFormBackground()
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
            if isNew && store.settings.subjects.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { subjectFocused = true }
            }
        }
    }

    // MARK: - Helpers

    private func grid(_ n: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: n)
    }

    private var dayChoices: [Int] {
        Array(Set(store.weekDays).union([item.weekday])).sorted()
    }

    // MARK: - Time bindings

    private var slots: [SchoolSettings.Slot] { store.settings.periods() }

    private func setPeriod(_ n: Int) {
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
        guard !item.subject.isEmpty || item.classID != nil else {
            errorText = "اكتب اسم المادة."
            subjectFocused = true
            return
        }
        guard item.end > item.start else {
            errorText = "يجب أن يكون وقت النهاية بعد وقت البداية."
            return
        }
        if !store.isExample, let other = store.conflict(with: item) {
            errorText = "يتعارض هذا الوقت مع حصة \(other.title) (\(Fmt.range(other.start, other.end)))."
            return
        }
        store.upsert(item)
        dismiss()
    }
}
