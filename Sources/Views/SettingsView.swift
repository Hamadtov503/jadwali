import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var s: SchoolSettings
    @State private var confirmClear = false

    init(settings: SchoolSettings) {
        _s = State(initialValue: settings)
    }

    var body: some View {
        NavigationView {
            Form {
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
                        row("الحصة \(i + 1)", "\(Fmt.time(slot.start)) – \(Fmt.time(slot.end))")
                        if let b = s.breakSlot(), i + 1 == s.breakAfter {
                            row("الفسحة", "\(Fmt.time(b.start)) – \(Fmt.time(b.end))")
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
