import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// الوضع بالعرض مسموح في صفحة الأسبوع فقط.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }

    /// يغيّر الاتجاهات المسموحة، ويعيد الشاشة إلى الطول إن لزم.
    static func setOrientation(_ mask: UIInterfaceOrientationMask) {
        orientationLock = mask
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            if mask == .portrait {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
            }
        } else {
            if mask == .portrait {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    /// إظهار الإشعار حتى والتطبيق مفتوح.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

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
        UNUserNotificationCenter.current().delegate = self
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

    init() {
        // لوحة المفاتيح في iOS 16 تُرسم داخل التطبيق نفسه وتأخذ الأرقام من إعدادات منطقته.
        // نثبّت منطقة التطبيق على السعودية بالأرقام العربية. يسري من التشغيل التالي.
        let d = UserDefaults.standard
        let wanted = "ar_SA@numbers=arab"
        if d.string(forKey: "AppleLocale") != wanted { d.set(wanted, forKey: "AppleLocale") }
        if d.stringArray(forKey: "AppleLanguages")?.first != "ar-SA" { d.set(["ar-SA"], forKey: "AppleLanguages") }
    }

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
