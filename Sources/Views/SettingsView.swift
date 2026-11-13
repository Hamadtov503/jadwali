import SwiftUI
import UniformTypeIdentifiers

/// ملف النسخة الاحتياطية (JSON).
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var s: SchoolSettings
    @State private var subjects: [SubjectRow]
    @State private var editingClass: ClassRef?
    @State private var exporting = false
    @State private var importing = false
    @State private var backupFile = BackupFile(data: Data())
    @State private var backupMessage: String?

    struct ClassRef: Identifiable { let id: UUID }
    struct SubjectRow: Identifiable { let id = UUID(); var name: String }
    @FocusState private var focused: UUID?

    init(settings: SchoolSettings) {
        var st = settings
        if st.classes.isEmpty { st.classes = [SchoolClass(name: "", color: st.nextClassColor)] }
        _s = State(initialValue: st)
        let rows = settings.subjects.map { SubjectRow(name: $0) }
        _subjects = State(initialValue: rows.isEmpty ? [SubjectRow(name: "")] : rows)
    }

    var body: some View {
        NavigationView {
            Form {
 Group {
                Section(header: SectionTitle("المواد الدراسية")) {
                    ForEach($subjects) { $row in
                        HStack(spacing: 12) {
                            SettingIcon(name: "book.fill", color: Theme.blue)
                            TextField("مادة جديدة", text: $row.name.arabicDigits)
                                .focused($focused, equals: row.id)
                                .submitLabel(.next)
                                .onSubmit { insertSubject(after: row.id) }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { deleteSubject(row.id) } label: {
                                Label("حذف", systemImage: "trash")
                            }
                        }
                    }
                }

                Section(header: SectionTitle("الفصول")) {
                    ForEach($s.classes) { $c in
                        HStack(spacing: 12) {
                            Button { editingClass = ClassRef(id: c.id) } label: {
                                SettingIcon(name: "person.3.fill", color: c.color.main)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("لون الفصل")
                            TextField("فصل جديد", text: $c.name.arabicDigits)
                                .focused($focused, equals: c.id)
                                .submitLabel(.next)
                                .onSubmit { insertClass(after: c.id) }
                            Button { editingClass = ClassRef(id: c.id) } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.muted)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { deleteClass(c.id) } label: {
                                Label("حذف", systemImage: "trash")
                            }
                        }
                    }
                }

                Section(header: SectionTitle("اليوم الدراسي")) {
                    DatePicker(selection: dayStartBinding, displayedComponents: .hourAndMinute) {
                        label("بداية الدوام", "sunrise.fill", Theme.orange)
                    }
                    .frame(height: 30)
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

                Section(header: SectionTitle("النسخ الاحتياطي")) {
                    Button {
                        guard let data = store.backupData() else { return }
                        backupFile = BackupFile(data: data)
                        exporting = true
                    } label: {
                        label("تصدير نسخة احتياطية", "square.and.arrow.up.fill", Theme.deepBrown)
                            .foregroundColor(Theme.fg)
                    }
                    .fileExporter(isPresented: $exporting, document: backupFile,
                                  contentType: .json, defaultFilename: "نسخة جدولي") { result in
                        if case .success = result { backupMessage = "تم تصدير النسخة الاحتياطية." }
                    }

                    Button { importing = true } label: {
                        label("استيراد نسخة احتياطية", "square.and.arrow.down.fill", Theme.green)
                            .foregroundColor(Theme.fg)
                    }
                    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                        guard case .success(let url) = result else { return }
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        if let data = try? Data(contentsOf: url), store.restore(from: data) {
                            s = store.settings
                            if s.classes.isEmpty { s.classes = [SchoolClass(name: "", color: s.nextClassColor)] }
                            let rows = s.subjects.map { SubjectRow(name: $0) }
                            subjects = rows.isEmpty ? [SubjectRow(name: "")] : rows
                            backupMessage = "تم استيراد النسخة الاحتياطية."
                        } else {
                            backupMessage = "الملف ليس نسخة احتياطية صالحة."
                        }
                    }
                }

                Section {
                    Text("جدولي — الإصدار \(Fmt.ar(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""))")
                        .font(.footnote)
                        .foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .listRowBackground(Theme.surface)
            }
            .appFormBackground()
            .sheet(item: $editingClass) { ref in
                ClassDetailView(schoolClass: classBinding(ref.id)) {
                    s.classes.removeAll { $0.id == ref.id }
                }
                    .accentColor(Theme.deepBrown)
            }
            .alert(backupMessage ?? "", isPresented: Binding(
                get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } }
            )) {
                Button("حسنًا", role: .cancel) {}
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        var names: [String] = []
                        for r in subjects {
                            let n = trimmed(r.name)
                            if !n.isEmpty && !names.contains(n) { names.append(n) }
                        }
                        s.subjects = names
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
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Helpers

    private func classBinding(_ id: UUID) -> Binding<SchoolClass> {
        Binding(
            get: { s.classes.first { $0.id == id } ?? SchoolClass(id: id, name: "", color: .blue) },
            set: { new in
                if let i = s.classes.firstIndex(where: { $0.id == id }) { s.classes[i] = new }
            }
        )
    }

    private func trimmed(_ t: String) -> String {
        t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Rows

    /// زر الإدخال في آخر سطر يفتح سطرًا جديدًا تحته.
    private func insertSubject(after id: UUID) {
        guard let i = subjects.firstIndex(where: { $0.id == id }),
              !trimmed(subjects[i].name).isEmpty else { focused = nil; return }
        let row = SubjectRow(name: "")
        withAnimation(.easeInOut(duration: 0.2)) { subjects.insert(row, at: i + 1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = row.id }
    }

    private func deleteSubject(_ id: UUID) {
        withAnimation {
            subjects.removeAll { $0.id == id }
            if subjects.isEmpty { subjects = [SubjectRow(name: "")] }
        }
    }

    private func insertClass(after id: UUID) {
        guard let i = s.classes.firstIndex(where: { $0.id == id }),
              !trimmed(s.classes[i].name).isEmpty else { focused = nil; return }
        let c = SchoolClass(name: "", color: s.nextClassColor)
        withAnimation(.easeInOut(duration: 0.2)) { s.classes.insert(c, at: i + 1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = c.id }
    }

    private func deleteClass(_ id: UUID) {
        withAnimation {
            s.classes.removeAll { $0.id == id }
            if s.classes.isEmpty { s.classes = [SchoolClass(name: "", color: s.nextClassColor)] }
        }
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
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                Group {
                    Section {
                        HStack(spacing: 12) {
                            SettingIcon(name: "person.3.fill", color: schoolClass.color.main)
                            TextField("اسم الفصل", text: $schoolClass.name.arabicDigits)
                                .focused($nameFocused)
                        }
                    }
                    Section(header: SectionTitle("اللون")) {
                        ColorGrid(selection: $schoolClass.color)
                    }
                    Section {
                        Button(role: .destructive) {
                            dismiss()
                            onDelete()
                        } label: {
                            HStack(spacing: 12) {
                                SettingIcon(name: "trash.fill", color: .red)
                                Text("حذف الفصل")
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .appFormBackground()
            .navigationTitle(schoolClass.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
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
