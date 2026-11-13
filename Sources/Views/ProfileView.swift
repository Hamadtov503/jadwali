import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName = ""
    @State private var name = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(Theme.deepGreen)
                            if let first = name.trimmingCharacters(in: .whitespaces).first {
                                Text(String(first))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 92, height: 92)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: 12) {
                        SettingIcon(name: "person.fill", color: Theme.green)
                        TextField("الاسم", text: $name)
                            .submitLabel(.done)
                    }
                }
            }
            .appFormBackground()
            .navigationTitle("الملف الشخصي")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
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
        .onAppear { name = userName }
    }
}
