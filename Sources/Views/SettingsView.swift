import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var s: SchoolSettings
    @State private var confirmClear = false
    @State private var newSubject = ""
    @State private var newClass = ""

    init(settings: SchoolSettings) {
        _s = State(initialValue: settings)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("المواد الدراسية")) {
                    ForEach(s.subjects, id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { s.subjects.remove(atOffsets: $0) }
                    HStack {
                        TextField("مادة جديدة", text: $newSubject)
                            .onSubmit(addSubject)
                        Button(action: addSubject) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.green)
                        }
                        .buttonStyle(.plain)
                        .disabled(trimmed(newSubject).isEmpty)
                    }
                }

                Section(header: Text("الفصول")) {
                    ForEach($s.classes) { $c in
                        NavigationLink {
                            ClassDetailView(schoolClass: $c)
                        } label: {
                            HStack(spacing: 10) {
                                Circle().fill(c.color.main).frame(width: 14, height: 14)
                                Text(c.name)
                            }
                        }
                    }
                    .onDelete { s.classes.remove(atOffsets: $0) }
                    HStack {
                        TextField("فصل جديد", text: $newClass)
                            .onSubmit(addClass)
                        Button(action: addClass) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.green)
                        }
                        .buttonStyle(.plain)
                        .disabled(trimmed(newClass).isEmpty)
                    }
                }

                Section(header: Text("اليوم الدراسي")) {
                    DatePicker("بداية الدوام", selection: dayStartBinding, displayedComponents: .hourAndMinute)
                    Stepper(value: periodsBinding, in: 1...12) {
                        row("عدد الحصص", "\(s.periodsPerDay)")
                    }
                    Stepper(value: $s.periodLength, in: 20...120, step: 5) {
                        row("مدة الحصة", Fmt.duration(s.periodLength))
                    }
                    Stepper(value: $s.passing, in: 0...30, step: 5) {
                        row("بين الحصص", s.passing == 0 ? "بدون" : Fmt.duration(s.passing))
                    }
                }

                if s.periodsPerDay > 1 {
                    Section(header: Text("الفسحة")) {
                        Toggle("فسحة", isOn: $s.hasBreak)
                        if s.hasBreak {
                            Picker("بعد الحصة", selection: $s.breakAfter) {
                                ForEach(1..<s.periodsPerDay, id: \.self) { n in
                                    Text(ordinal(n)).tag(n)
                                }
                            }
                            Stepper(value: $s.breakLength, in: 5...60, step: 5) {
                                row("مدة الفسحة", Fmt.duration(s.breakLength))
                            }
                        }
                    }
                }

                Section(header: Text("أيام الدراسة")) {
                    ForEach(0..<7, id: \.self) { d in
                        Toggle(Weekdays.names[d], isOn: dayBinding(d))
                    }
                }

                Section(header: Text("توقيت الحصص")) {
                    let slots = s.periods()
                    ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                        row("الحصة \(i + 1)", Fmt.range(slot.start, slot.end))
                        if let b = s.breakSlot(), i + 1 == s.breakAfter {
                            row("الفسحة", Fmt.range(b.start, b.end))
                                .foregroundColor(SubjectColor.orange.ink)
                        }
                    }
                    if slots.count < s.periodsPerDay {
                        Text("تتجاوز بعض الحصص منتصف الليل.")
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(role: .destructive) { confirmClear = true } label: {
                        Text("حذف كل الحصص")
                    }
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        addSubject()
                        addClass()
                        for i in s.classes.indices { s.classes[i].name = trimmed(s.classes[i].name) }
                        s.classes.removeAll { $0.name.isEmpty }
                        store.updateSettings(s)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .confirmationDialog("حذف كل الحصص؟", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("حذف", role: .destructive) { store.clearAll() }
                Button("إلغاء", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Helpers

    private func trimmed(_ t: String) -> String {
        t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addSubject() {
        let name = trimmed(newSubject)
        guard !name.isEmpty else { return }
        if !s.subjects.contains(name) { s.subjects.append(name) }
        newSubject = ""
    }

    private func addClass() {
        let name = trimmed(newClass)
        guard !name.isEmpty else { return }
        if !s.classes.contains(where: { $0.name == name }) {
            s.classes.append(SchoolClass(name: name, color: s.nextClassColor))
        }
        newClass = ""
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(Theme.muted)
        }
    }

    private func ordinal(_ n: Int) -> String {
        let names = ["الأولى", "الثانية", "الثالثة", "الرابعة", "الخامسة", "السادسة",
                     "السابعة", "الثامنة", "التاسعة", "العاشرة", "الحادية عشرة", "الثانية عشرة"]
        return n >= 1 && n <= names.count ? names[n - 1] : "\(n)"
    }

    private var dayStartBinding: Binding<Date> {
        Binding(
            get: {
                Weekdays.calendar.date(bySettingHour: s.dayStart / 60, minute: s.dayStart % 60,
                                       second: 0, of: Date()) ?? Date()
            },
            set: { s.dayStart = Weekdays.minutes(of: $0) }
        )
    }

    private var periodsBinding: Binding<Int> {
        Binding(
            get: { s.periodsPerDay },
            set: { n in
                s.periodsPerDay = n
                if s.breakAfter >= n { s.breakAfter = max(1, n - 1) }
            }
        )
    }

    private func dayBinding(_ d: Int) -> Binding<Bool> {
        Binding(
            get: { s.schoolDays.contains(d) },
            set: { on in
                if on {
                    if !s.schoolDays.contains(d) { s.schoolDays.append(d) }
                } else {
                    s.schoolDays.removeAll { $0 == d }
                }
                s.schoolDays.sort()
            }
        )
    }
}

struct ClassDetailView: View {
    @Binding var schoolClass: SchoolClass

    var body: some View {
        Form {
            Section {
                TextField("اسم الفصل", text: $schoolClass.name)
            }
            Section(header: Text("اللون")) {
                ColorGrid(selection: $schoolClass.color)
            }
        }
        .navigationTitle(schoolClass.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
