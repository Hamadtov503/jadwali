import SwiftUI
import PhotosUI
import UIKit

/// صورة الملف الشخصي، محفوظة في Application Support/avatar.jpg.
final class Avatar: ObservableObject {
    static let shared = Avatar()
    @Published private(set) var image: UIImage?
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("avatar.jpg")
        if let data = try? Data(contentsOf: url) { image = UIImage(data: data) }
    }

    func set(_ new: UIImage) {
        let side: CGFloat = 600
        let scale = min(1, side / max(new.size.width, new.size.height))
        let size = CGSize(width: new.size.width * scale, height: new.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in new.draw(in: CGRect(origin: .zero, size: size)) }
        image = resized
        if let data = resized.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func remove() {
        image = nil
        try? FileManager.default.removeItem(at: url)
    }
}

/// اختيار صورة من الصور (يعمل على iOS 15).
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self.parent.onPick(image) }
            }
        }
    }
}

/// الصورة الدائرية للمستخدم.
struct AvatarView: View {
    @ObservedObject var avatar = Avatar.shared
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Theme.green)
            if let img = avatar.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if let first = name.trimmingCharacters(in: .whitespaces).first {
                Text(String(first))
                    .font(.system(size: size * 0.43, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName = ""
    @State private var name = ""
    @State private var showPicker = false
    @ObservedObject private var avatar = Avatar.shared

    var body: some View {
        NavigationView {
            Form {
 Group {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button { showPicker = true } label: {
                                AvatarView(name: name, size: 104)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Circle().fill(Theme.orange))
                                            .overlay(Circle().stroke(Theme.bg, lineWidth: 3))
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("اختيار صورة")
                            if avatar.image != nil {
                                Button("حذف الصورة") { avatar.remove() }
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .buttonStyle(.plain)
                            }
                        }
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
            .listRowBackground(Theme.surface)
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
        .sheet(isPresented: $showPicker) {
            PhotoPicker(isPresented: $showPicker) { avatar.set($0) }
                .ignoresSafeArea()
        }
    }
}
