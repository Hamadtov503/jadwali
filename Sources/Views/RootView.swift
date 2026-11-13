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
    @State private var showSettings = false
    @State private var assigning: AssignTarget?

    private var mode: ViewMode { ViewMode(rawValue: modeRaw) ?? .day }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .sheet(isPresented: $showSettings) {
                        SettingsView(settings: store.settings)
                            .environmentObject(store)
                            .environment(\.layoutDirection, .rightToLeft)
                            .environment(\.locale, Fmt.locale)
                    }

                if store.isExample {
                    exampleBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                if mode == .day {
                    DayView(selectedDay: $selectedDay)
                } else {
                    WeekView(onTap: { assign($0, $1) })
                }
            }

            if let target = assigning {
                AssignPopup(target: target,
                            onClose: closePopup,
                            onSettings: { closePopup(); showSettings = true },
                            onDetails: { item in closePopup(); editing = EditorTarget(item: item, isNew: false) })
                    .transition(.opacity)
                    .zIndex(1)
            }
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
            HStack(alignment: .top) {
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
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.fg)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.surface2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("الإعدادات")
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
            Button("مسح الأمثلة") { withAnimation { store.clearAll() } }
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

    // MARK: - Actions

    private func assign(_ day: Int, _ period: Int) {
        withAnimation(.easeOut(duration: 0.18)) { assigning = AssignTarget(day: day, period: period) }
    }

    private func closePopup() {
        withAnimation(.easeOut(duration: 0.15)) { assigning = nil }
    }
}
