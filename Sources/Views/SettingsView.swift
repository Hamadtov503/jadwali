import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var s: SchoolSettings
    @State private var confirmClear = false
    @State private var newSubject = ""
    @State private var newClass = ""
    @State private var adding: AddKind?
    @FocusState private var focus: AddKind?

    enum AddKind: Hashable { case subject, klass }

    init(settings: SchoolSettings) {
        _s = State(initialValue: settings)
    }

    var body: some View {
        NavigationView {
            Form {
 Group {
                Section(header: SectionTitle("المواد الدراسية"), footer: plusButton(.subject)) {
                    ForEach(s.subjects, id: \.self) { name in
                        label(name, "book.fill", Theme.blue)
                    }
                    .onDelete { s.subjects.remove(atOffsets: $0) }
                    if adding == .subject {
                        HStack(spacing: 12) {
                            SettingIcon(name: "book.fill", color: Theme.green)
                            TextField("مادة جديدة", text: $newSubject.arabicDigits)
                                .focused($focus, equals: .subject)
                                .submitLabel(.done)
                                .onSubmit { addSubject(); adding = nil }
                            Button("إضافة") { addSubject(); adding = nil }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Theme.green)
                                .buttonStyle(.plain)
                                .disabled(trimmed(newSubject).isEmpty)
                        }
                    }
                }

                Section(header: SectionTitle("الفصول"), footer: plusButton(.klass)) {
                    ForEach($s.classes) { $c in
                        NavigationLink {
                            ClassDetailView(schoolClass: $c)
                        } label: {
                            label(c.name, "person.3.fill", c.color.main)
                        }
                    }
                    .onDelete { s.classes.remove(atOffsets: $0) }
                    if adding == .klass {
                        HStack(spacing: 12) {
                            SettingIcon(name: "person.3.fill", color: Theme.green)
                            TextField("فصل جديد", text: $newClass.arabicDigits)
                                .focused($focus, equals: .klass)
                                .submitLabel(.done)
                                .onSubmit { addClass(); adding = nil }
                            Button("إضافة") { addClass(); adding = nil }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Theme.green)
                                .buttonStyle(.plain)
                                .disabled(trimmed(newClass).isEmpty)
                        }
                    }
                }

                Section(header: SectionTitle("اليوم الدراسي")) {
                    DatePicker(selection: dayStartBinding, displayedComponents: .hourAndMinute) {
                        label("بداية الدوام", "sunrise.fill", Theme.orange)
                    }
                    Stepper(value: periodsBinding, in: 1...12) {
                        row("عدد الحصص", Fmt.n(s.periodsPerDay), "list.number", Theme.green)
                    }
                    Stepper(value: $s.periodLength, in: 20...120, step: 5) {
                        row("مدة الحصة", Fmt.duration(s.periodLength), "hourglass", Theme.blue)
                    }
                    Stepper(value: $s.passing, in: 0...30, step: 5) {
                        row("بين الحصص", s.passing == 0 ? "بدون" : Fmt.duration(s.passing),
                            "arrow.left.arrow.right", SubjectColor.teal.main)
                    }
                }

                if s.periodsPerDay > 1 {
                    Section(header: SectionTitle("الفسحة")) {
                        Toggle(isOn: $s.hasBreak) {
                            label("فسحة", "cup.and.saucer.fill", Theme.orange)
                        }
                        if s.hasBreak {
                            Stepper(value: $s.breakAfter, in: 1...(s.periodsPerDay - 1)) {
                                row("بعد الحصة", ordinal(s.breakAfter), "arrow.turn.down.left", SubjectColor.purple.main)
                            }
                            Stepper(value: $s.breakLength, in: 5...60, step: 5) {
                                row("مدة الفسحة", Fmt.duration(s.breakLength), "timer", SubjectColor.pink.main)
                            }
                        }
                    }
                }

                Section(header: SectionTitle("أيام الدراسة")) {
                    ForEach(0..<7, id: \.self) { d in
                        Toggle(isOn: dayBinding(d)) {
                            label(Weekdays.names[d], s.schoolDays.contains(d) ? "calendar" : "sun.max.fill",
                                  s.schoolDays.contains(d) ? Theme.green : SubjectColor.yellow.main)
                        }
                    }
                }

                Section(header: SectionTitle("توقيت الحصص")) {
                    let slots = s.periods()
                    ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                        row("الحصة \(Fmt.n(i + 1))", Fmt.range(slot.start, slot.end), "bell.fill", Theme.blue)
                        if let b = s.breakSlot(), i + 1 == s.breakAfter {
                            row("الفسحة", Fmt.range(b.start, b.end), "cup.and.saucer.fill", Theme.orange)
                        }
                    }
                    if slots.count < s.periodsPerDay {
                        Text("تتجاوز بعض الحصص منتصف الليل.")
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(role: .destructive) { confirmClear = true } label: {
                        HStack(spacing: 12) {
                            SettingIcon(name: "trash.fill", color: .red)
                            Text("حذف كل الحصص")
                        }
                    }
                }
            }
            .listRowBackground(Theme.surface)
            }
            .appFormBackground()
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

    private func plusButton(_ kind: AddKind) -> some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { adding = kind }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = kind }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.15)))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(kind == .subject ? "إضافة مادة" : "إضافة فصل")
            Spacer()
        }
    }

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

    private func label(_ title: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            SettingIcon(name: icon, color: color)
            Text(title)
        }
    }

    private func row(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            SettingIcon(name: icon, color: color)
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
        return n >= 1 && n <= names.count ? names[n - 1] : Fmt.n(n)
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
 Group {
            Section {
                HStack(spacing: 12) {
                    SettingIcon(name: "person.3.fill", color: schoolClass.color.main)
                    TextField("اسم الفصل", text: $schoolClass.name.arabicDigits)
                }
            }
            Section(header: SectionTitle("اللون")) {
                ColorGrid(selection: $schoolClass.color)
            }
        }
        .listRowBackground(Theme.surface)
        }
        .appFormBackground()
        .navigationTitle(schoolClass.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// أيقونة ملونة قبل كل خيار في الإعدادات.
struct SettingIcon: View {
    let name: String
    let color: Color

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
    }
}
