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

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.deepGreen.ignoresSafeArea()
            VStack(spacing: 18) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1 : 0.85)
                Text("جدولي")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle().fill(Theme.green).frame(width: 8, height: 8)
                    Circle().fill(Theme.orange).frame(width: 8, height: 8)
                    Circle().fill(Theme.blue).frame(width: 8, height: 8)
                }
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
        }
    }
}
