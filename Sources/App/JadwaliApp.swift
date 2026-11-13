import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.backgroundColor = Theme.uiBackground
        bar.titleTextAttributes = [.foregroundColor: Theme.uiOnBg]
        bar.largeTitleTextAttributes = [.foregroundColor: Theme.uiOnBg]
        UINavigationBar.appearance().tintColor = UIColor(hex: 0x4A3326)
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        UITableView.appearance().backgroundColor = Theme.uiBackground
        UICollectionView.appearance().backgroundColor = Theme.uiBackground
        clearLaunchSnapshotCache()
        _ = Store.shared
        return true
    }

    /// iOS يحتفظ بصورة لشاشة البداية القديمة (البيضاء) ولا يحدّثها عند التثبيت عبر TrollStore.
    /// حذف ذاكرتها يجبره على رسم شاشة البداية الحالية في المرة القادمة.
    private func clearLaunchSnapshotCache() {
        let key = "launchCacheClearedForBuild"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        guard UserDefaults.standard.string(forKey: key) != build else { return }
        let fm = FileManager.default
        if let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
            try? fm.removeItem(at: lib.appendingPathComponent("SplashBoard"))
            if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                try? fm.removeItem(at: caches.appendingPathComponent("Snapshots"))
            }
        }
        UserDefaults.standard.set(build, forKey: key)
    }
}

@main
struct JadwaliApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            LaunchContainer()
                .environmentObject(store)
                .environment(\.locale, Fmt.locale)
                .accentColor(Theme.deepBrown)
                .preferredColorScheme(.light)
        }
    }
}
