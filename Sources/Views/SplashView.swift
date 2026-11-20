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

/// مطابقة لشاشة البداية (Launch.storyboard) تمامًا: نفس المواضع محسوبة من منتصف الشاشة الكامل،
/// حتى لا يتحرك شيء عند الانتقال من شاشة النظام إلى التطبيق.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotsFloating = false

    var body: some View {
        ZStack {
            Theme.deepBrown
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
            Text("جدولي")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .fixedSize()
                .offset(y: 104)
            Image("SplashDots")
                .frame(width: 36, height: 8)
                .offset(y: 142 + (dotsFloating ? -4 : 0))
                .opacity(dotsFloating ? 0.7 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                        dotsFloating = true
                    }
                }
        }
        .ignoresSafeArea()
    }
}
