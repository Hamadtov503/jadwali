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
    @State private var showProfile = false
    @AppStorage("userName") private var userName = ""

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
                            .environment(\.locale, Fmt.locale)
                .accentColor(Theme.orange)
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
                .environment(\.locale, Fmt.locale)
                .accentColor(Theme.orange)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                TimelineView(.periodic(from: Date(), by: 60)) { context in
                    Text(greeting(at: context.date))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.onBg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button { showProfile = true } label: {
                        AvatarView(name: userName, size: 42)
                            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("الملف الشخصي")
                        .sheet(isPresented: $showProfile) {
                            ProfileView()
                                .environment(\.locale, Fmt.locale)
                .accentColor(Theme.orange)
                        }
                    circleButton("gearshape", label: "الإعدادات") { showSettings = true }
                }
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

    private func greeting(at date: Date) -> String {
        let h = Weekdays.calendar.component(.hour, from: date)
        let base = (4..<12).contains(h) ? "صباح الخير" : "مساء الخير"
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "\(base) 👋" : "\(base) 👋 أ. \(name)"
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.fg)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.surface2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    private func assign(_ day: Int, _ period: Int) {
        withAnimation(.easeOut(duration: 0.18)) { assigning = AssignTarget(day: day, period: period) }
    }

    private func closePopup() {
        withAnimation(.easeOut(duration: 0.15)) { assigning = nil }
    }
}
