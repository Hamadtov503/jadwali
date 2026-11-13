import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UIView.appearance().semanticContentAttribute = .forceRightToLeft
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.backgroundColor = Theme.uiBackground
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
            RootView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Fmt.locale)
                .accentColor(Theme.blue)
        }
    }
}
