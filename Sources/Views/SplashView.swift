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
    @State private var activeDot = 0
    private let dotTimer = Timer.publish(every: 0.24, on: .main, in: .common).autoconnect()

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
                .mask {
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { index in
                            Rectangle()
                                .opacity(reduceMotion || activeDot == index ? 1 : 0.25)
                                .frame(width: 12, height: 8)
                        }
                    }
                    .frame(width: 36, height: 8)
                }
                .offset(y: 142)
                .onReceive(dotTimer) { _ in
                    guard !reduceMotion else { return }
                    activeDot = (activeDot + 1) % 3
                }
        }
        .ignoresSafeArea()
    }
}
