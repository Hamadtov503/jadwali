import SwiftUI

enum ViewMode: String, CaseIterable, Identifiable {
    case day, week
    var id: String { rawValue }
    var title: String { self == .day ? "اليوم" : "الأسبوع" }
}

struct EditorTarget: Identifiable {
    let id = UUID()
    var item: ClassItem
    var isNew: Bool
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @AppStorage("viewMode") private var modeRaw: String = ViewMode.day.rawValue
    @State private var selectedDay = Weekdays.weekday(of: Date())
    @State private var editing: EditorTarget?

    private var mode: ViewMode { ViewMode(rawValue: modeRaw) ?? .day }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if store.isExample {
                    exampleBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                if mode == .day {
                    DayView(selectedDay: $selectedDay, onEdit: edit, onAdd: add)
                } else {
                    WeekView(onEdit: edit)
                }
            }

            addButton
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .sheet(item: $editing) { target in
            EditorView(target: target)
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Fmt.locale)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("جدولي الدراسي")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.fg)
                    HStack(spacing: 4) {
                        Circle().fill(Theme.green).frame(width: 8, height: 8)
                        Circle().fill(Theme.orange).frame(width: 8, height: 8)
                        Circle().fill(Theme.blue).frame(width: 8, height: 8)
                    }
                }
                Text(Fmt.today())
                    .font(.subheadline)
                    .foregroundColor(Theme.muted)
            }

            HStack(spacing: 2) {
                ForEach(ViewMode.allCases) { m in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { modeRaw = m.rawValue }
                    } label: {
                        Text(m.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(mode == m ? Theme.fg : Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(mode == m ? Theme.surface : Color.clear)
                                    .shadow(color: Color.black.opacity(mode == m ? 0.08 : 0), radius: 6, x: 0, y: 2)
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == m ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Capsule().fill(Theme.surface2))
        }
    }

    private var exampleBanner: some View {
        HStack {
            Text("جدول تجريبي")
                .font(.subheadline.weight(.medium))
                .foregroundColor(SubjectColor.orange.ink)
            Spacer()
            Button("مسح الأمثلة") { withAnimation { store.clearExamples() } }
                .font(.footnote.weight(.semibold))
                .foregroundColor(Theme.fg)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.surface))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SubjectColor.orange.soft))
    }

    private var addButton: some View {
        Button { add(mode == .day ? selectedDay : Weekdays.weekday(of: Date())) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("إضافة حصة")
                    .font(.system(.headline, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Capsule().fill(Theme.green))
            .shadow(color: Theme.green.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func edit(_ item: ClassItem) {
        editing = EditorTarget(item: item, isNew: false)
    }

    private func add(_ day: Int) {
        let start = store.suggestedStart(on: day)
        let item = ClassItem(subject: "", weekday: day, start: start,
                             end: min(start + 45, 23 * 60 + 59), color: store.nextColor)
        editing = EditorTarget(item: item, isNew: true)
    }
}
