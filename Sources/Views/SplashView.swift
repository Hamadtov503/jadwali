import SwiftUI

/// يعرض الشاشة الافتتاحية ثم ينتقل إلى التطبيق.
struct LaunchContainer: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootView()
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
            }
        }
    }
}

/// مطابقة لشاشة البداية (Launch.storyboard) تمامًا، حتى يظهر الشعار مع الخلفية دون انتقال.
struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.deepBrown.ignoresSafeArea()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
        }
    }
}
