import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var showForceUpdate = false
    @State private var isMaintenanceMode = false
    @State private var maintenanceEndTime: String?

    private var needsOnboarding: Bool {
        guard let user = authManager.currentUser else { return false }
        return (user.name == nil || user.name?.isEmpty == true)
            && !UserDefaults.standard.bool(forKey: "onboarding_completed")
    }

    /// Social login users skip email verification (already verified by provider)
    private var needsEmailVerification: Bool {
        guard let user = authManager.currentUser else { return false }
        if authManager.isSocialLogin { return false }
        return user.emailVerified == false
    }

    var body: some View {
        Group {
            if isMaintenanceMode {
                MaintenanceView(estimatedEndTime: maintenanceEndTime) {
                    await checkMaintenanceStatus()
                }
            } else if authManager.isLoading {
                SplashView()
            } else if authManager.isAuthenticated {
                if needsEmailVerification {
                    EmailVerificationView()
                        .environmentObject(authManager)
                } else if needsOnboarding && !authManager.isSocialLogin {
                    OnboardingView()
                        .environmentObject(authManager)
                } else {
                    MainTabView()
                        .onAppear {
                            appState.navigateToDefaultPage(userType: authManager.userType)
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
        .preferredColorScheme(appState.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: authManager.isAuthenticated)
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                appState.navigateToDefaultPage(userType: authManager.userType)
            }
        }
        .task {
            // バックグラウンドで非同期チェック（UIをブロックしない）
            Task.detached(priority: .utility) {
                await self.checkAPIHealth()
            }
            Task.detached(priority: .utility) {
                await self.checkForceUpdate()
            }
        }
        .alert("アップデートが必要です", isPresented: $showForceUpdate) {
            Button("App Storeを開く") {
                if let url = URL(string: "https://apps.apple.com/app/byters/id6741090702") {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("新しいバージョンが公開されています。最新版にアップデートしてください。")
        }
        .alert("セッション切れ", isPresented: $authManager.showSessionExpiredAlert) {
            Button("OK") {
                authManager.dismissSessionExpiredAlert()
            }
        } message: {
            Text("セッションの有効期限が切れました。再度ログインしてください。")
        }
    }

    private func checkAPIHealth() async {
        do {
            let status = try await APIClient.shared.getHealthStatus()
            await MainActor.run {
                isMaintenanceMode = false
                maintenanceEndTime = status.estimatedEndTime
            }
        } catch let error as APIError {
            if case .maintenance = error {
                await MainActor.run { isMaintenanceMode = true }
            }
            // Other errors - NetworkMonitor will show offline banner
        } catch {
            // API is not reachable - NetworkMonitor will show offline banner
        }
    }

    private func checkMaintenanceStatus() async {
        await checkAPIHealth()
    }

    private func checkForceUpdate() async {
        do {
            let settings = try await APIClient.shared.getAppSettings()
            if let minVersion = settings.minimumAppVersion {
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
                if compareVersions(current: currentVersion, minimum: minVersion) {
                    await MainActor.run { showForceUpdate = true }
                }
            }
        } catch {
            // Settings not available - skip force update check
        }
    }

    /// Returns true if current version is less than minimum
    private func compareVersions(current: String, minimum: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let minimumParts = minimum.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(currentParts.count, minimumParts.count)

        for i in 0..<maxCount {
            let c = i < currentParts.count ? currentParts[i] : 0
            let m = i < minimumParts.count ? minimumParts[i] : 0
            if c < m { return true }
            if c > m { return false }
        }
        return false
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
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var currentStep = 0
    @State private var ageError: String?
    @State private var saveError: String?

    private let totalSteps = 5

    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                Spacer()

                if currentStep == 0 {
                    // Feature Highlights
                    VStack(spacing: 20) {
                        Text("Bytersでできること")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        VStack(spacing: 16) {
                            OnboardingFeatureCard(
                                icon: "magnifyingglass",
                                title: "求人を検索",
                                description: "あなたにぴったりの短期バイトを見つけよう"
                            )

                            OnboardingFeatureCard(
                                icon: "qrcode",
                                title: "QRで出退勤",
                                description: "QRコードをスキャンして出勤・退勤を記録"
                            )

                            OnboardingFeatureCard(
                                icon: "yensign.circle",
                                title: "報酬を受け取る",
                                description: "お仕事完了後にすぐ報酬をゲット"
                            )
                        }
                        .padding(.horizontal, 32)
                    }
                } else if currentStep == 1 {
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
                } else if currentStep == 2 {
                    // Birthday / Age verification
                    VStack(spacing: 16) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("生年月日を入力してください")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("本サービスは18歳以上の方がご利用いただけます")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        DatePicker("生年月日", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 32)

                        if let error = ageError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .fontWeight(.semibold)
                        }
                    }
                } else if currentStep == 3 {
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
                            .submitLabel(.done)
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
                            .submitLabel(.done)
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
                            Text(currentStep == totalSteps - 1 ? "始める" : "次へ")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || (currentStep == 3 && name.isEmpty))
                    .opacity((currentStep == 3 && name.isEmpty) ? 0.5 : 1.0)

                    if let error = saveError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if currentStep > 1 && currentStep != 2 {
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
        if currentStep == 2 {
            // Age verification
            if age < 18 {
                ageError = "18歳未満の方はご利用いただけません"
                return
            }
            ageError = nil
        }

        if currentStep < totalSteps - 1 {
            withAnimation { currentStep += 1 }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        isLoading = true
        saveError = nil
        Task {
            do {
                let updated = try await APIClient.shared.updateProfile(
                    name: name.isEmpty ? nil : name,
                    phone: nil,
                    bio: nil,
                    prefecture: prefecture.isEmpty ? nil : prefecture,
                    city: nil
                )
                authManager.currentUser = updated
                authManager.cacheCurrentUser()
                UserDefaults.standard.set(true, forKey: "onboarding_completed")
            } catch {
                saveError = "プロフィールの保存に失敗しました。もう一度お試しください。"
            }
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

// MARK: - Onboarding Feature Card

struct OnboardingFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
