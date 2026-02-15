import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    private var needsOnboarding: Bool {
        guard let user = authManager.currentUser else { return false }
        return (user.name == nil || user.name?.isEmpty == true)
            && !UserDefaults.standard.bool(forKey: "onboarding_completed")
    }

    var body: some View {
        Group {
            if authManager.isLoading {
                SplashView()
            } else if authManager.isAuthenticated {
                if authManager.currentUser?.emailVerified == false {
                    EmailVerificationView()
                        .environmentObject(authManager)
                } else if needsOnboarding {
                    OnboardingView()
                        .environmentObject(authManager)
                } else {
                    MainTabView()
                        .onAppear {
                            appState.selectedTab = .mypage
                        }
                        .sheet(isPresented: $appState.isShowingJobDetail) {
                            if let jobId = appState.selectedJobId {
                                NavigationStack {
                                    JobDetailView(jobId: jobId)
                                }
                            }
                        }
                }
            } else {
                AuthView()
            }
        }
        .offlineBanner()
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                appState.navigateToMyPage()
            }
        }
        .task {
            await checkAPIHealth()
        }
    }

    private func checkAPIHealth() async {
        do {
            let _ = try await APIClient.shared.getHealthStatus()
        } catch {
            // API is not reachable - NetworkMonitor will show offline banner
        }
    }
}

// MARK: - Email Verification View

struct EmailVerificationView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isResending = false
    @State private var resendSuccess = false
    @State private var errorMessage: String?
    @State private var isChecking = false

    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text("メール認証が必要です")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("登録したメールアドレスに認証リンクを送信しました。メールを確認してリンクをタップしてください。")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .padding(.horizontal)
                }

                if resendSuccess {
                    Text("認証メールを再送しました")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                VStack(spacing: 12) {
                    Button(action: checkVerification) {
                        HStack {
                            if isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            }
                            Text("認証を確認する")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isChecking)

                    Button(action: resendEmail) {
                        HStack {
                            if isResending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("認証メールを再送する")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isResending)

                    Button(action: { authManager.logout() }) {
                        Text("ログアウト")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private func resendEmail() {
        isResending = true
        errorMessage = nil
        resendSuccess = false
        Task {
            do {
                _ = try await APIClient.shared.resendVerificationEmail()
                resendSuccess = true
            } catch {
                errorMessage = "再送に失敗しました"
            }
            isResending = false
        }
    }

    private func checkVerification() {
        isChecking = true
        errorMessage = nil
        Task {
            await authManager.checkAuthStatus()
            if authManager.currentUser?.emailVerified == false {
                errorMessage = "まだ認証が完了していません"
            }
            isChecking = false
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var name = ""
    @State private var prefecture = ""
    @State private var isLoading = false
    @State private var currentStep = 0

    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i <= currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                Spacer()

                if currentStep == 0 {
                    // Welcome
                    VStack(spacing: 16) {
                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("ようこそ！")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Bytersを使い始めるために\nプロフィールを設定しましょう")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                } else if currentStep == 1 {
                    // Name
                    VStack(spacing: 16) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("お名前を教えてください")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        TextField("名前", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 40)
                    }
                } else {
                    // Prefecture
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("お住まいの地域")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        TextField("都道府県", text: $prefecture)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 40)
                    }
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: nextStep) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            }
                            Text(currentStep == 2 ? "始める" : "次へ")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || (currentStep == 1 && name.isEmpty))
                    .opacity((currentStep == 1 && name.isEmpty) ? 0.5 : 1.0)

                    if currentStep > 0 {
                        Button(action: skipOnboarding) {
                            Text("スキップ")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func nextStep() {
        if currentStep < 2 {
            withAnimation { currentStep += 1 }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        isLoading = true
        Task {
            do {
                _ = try await APIClient.shared.updateProfile(
                    name: name.isEmpty ? nil : name,
                    phone: nil,
                    bio: nil,
                    prefecture: prefecture.isEmpty ? nil : prefecture,
                    city: nil
                )
                await authManager.checkAuthStatus()
            } catch {
                // Profile save failed but proceed with onboarding to avoid blocking the user
            }
            UserDefaults.standard.set(true, forKey: "onboarding_completed")
            isLoading = false
        }
    }

    private func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        Task {
            await authManager.checkAuthStatus()
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
        .environmentObject(AuthManager.shared)
        .environmentObject(AppState())
}
