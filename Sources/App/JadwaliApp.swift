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
        _ = Store.shared
        return true
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
