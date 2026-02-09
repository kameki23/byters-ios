import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if authManager.isLoading {
                SplashView()
            } else if authManager.isAuthenticated {
                MainTabView()
                    .onAppear {
                        // Always navigate to MyPage when authenticated
                        appState.selectedTab = .mypage
                    }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                // When user becomes authenticated, go to MyPage
                appState.navigateToMyPage()
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.blue
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text("Byters")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
