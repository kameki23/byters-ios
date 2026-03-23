import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var selectedUserType: UserType = .jobSeeker
    @State private var isLoading = false
    @State private var showUserTypeSelection = true
    @State private var errorMessage: String?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // Secret admin access
    @State private var logoTapCount = 0
    @State private var showAdminLogin = false
    @State private var lastTapTime = Date()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: verticalSizeClass == .compact ? 16 : 30) {
                    // Logo - Secret admin access (tap 7 times)
                    VStack(spacing: verticalSizeClass == .compact ? 6 : 12) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: verticalSizeClass == .compact ? 36 : 60))
                            .foregroundColor(.white)

                        Text("Byters")
                            .font(.system(size: verticalSizeClass == .compact ? 24 : 36, weight: .bold))
                            .foregroundColor(.white)

                        if verticalSizeClass != .compact {
                            Text("短期アルバイトマッチング")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, verticalSizeClass == .compact ? 20 : 60)
                    .onTapGesture {
                        handleSecretTap()
                    }

                    Spacer(minLength: verticalSizeClass == .compact ? 8 : 20)

                    // Auth Card - unified: type selection + social login
                    VStack(spacing: 24) {
                        SocialLoginView(
                            userType: selectedUserType,
                            selectedUserType: $selectedUserType,
                            isLoading: $isLoading,
                            errorMessage: $errorMessage
                        )
                        .environmentObject(authManager)
                        .environmentObject(appState)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }

            // Loading Overlay
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("認証中...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
        }
        .sheet(isPresented: $showAdminLogin) {
            SecretAdminLoginView(
                isLoading: $isLoading,
                errorMessage: $errorMessage
            )
            .environmentObject(authManager)
            .environmentObject(appState)
        }
    }

    private func handleSecretTap() {
        let now = Date()
        // Reset count if more than 2 seconds since last tap
        if now.timeIntervalSince(lastTapTime) > 2.0 {
            logoTapCount = 0
        }
        lastTapTime = now
        logoTapCount += 1

        if logoTapCount >= 7 {
            logoTapCount = 0
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            showAdminLogin = true
        }
    }
}

// MARK: - Secret Admin Login

struct SecretAdminLoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showPasswordReset = false
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)

                        Text("管理者ログイン")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("このページは管理者専用です")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }

                Section("認証情報") {
                    TextField("メールアドレス", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .submitLabel(.done)

                    if let emailErr = ValidationHelper.emailError(email) {
                        Text(emailErr)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    SecureField("パスワード", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)

                    if let passErr = ValidationHelper.passwordError(password) {
                        Text(passErr)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(action: performAdminLogin) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("ログイン")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(!ValidationHelper.isValidEmail(email) || !ValidationHelper.isValidPassword(password) || isLoading)
                }

                Section {
                    Button(action: { showPasswordReset = true }) {
                        Text("パスワードを忘れた場合")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        errorMessage = nil
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView()
            }
        }
    }

    private func performAdminLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await APIClient.shared.adminLogin(email: email, password: password)

                await MainActor.run {
                    KeychainHelper.save(key: "auth_token", value: response.accessToken)
                    APIClient.shared.invalidateTokenCache()
                    KeychainHelper.save(key: "is_admin", value: "true")
                    authManager.setActiveUserType(.admin)
                    authManager.currentUser = response.user
                    authManager.isAuthenticated = true
                    authManager.cacheCurrentUser()
                    authManager.markLoginSuccess()
                    appState.onLoginSuccess(userType: .admin)
                    isLoading = false
                    dismiss()
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = apiError.errorDescription
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "管理者認証に失敗しました"
                }
            }
        }
    }
}

// MARK: - User Type Selection

struct UserTypeSelectionView: View {
    @Binding var selectedType: UserType
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("アカウントタイプを選択")
                .font(.title2)
                .fontWeight(.bold)

            Text("ご利用目的に合わせてお選びください")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                UserTypeCard(
                    title: "働きたい",
                    subtitle: "求職者",
                    description: "履歴書不要で今すぐお仕事エントリー",
                    icon: "magnifyingglass",
                    color: .blue,
                    isSelected: selectedType == .jobSeeker
                ) {
                    selectedType = .jobSeeker
                }

                UserTypeCard(
                    title: "募集したい",
                    subtitle: "事業者",
                    description: "最短3分で求人掲載・スタッフ採用",
                    icon: "building.2.fill",
                    color: .green,
                    isSelected: selectedType == .employer
                ) {
                    selectedType = .employer
                }
            }

            Button(action: onContinue) {
                Text("次へ")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
    }
}

struct UserTypeCard: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("(\(subtitle))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? color : .gray.opacity(0.3))
                    .font(.title2)
            }
            .padding()
            .background(isSelected ? color.opacity(0.05) : Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Social Login View

struct SocialLoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    let userType: UserType
    @Binding var selectedUserType: UserType
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    @State private var webAuthSession: ASWebAuthenticationSession?
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var agreedToTerms = false
    @State private var errorDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Bytersを始める")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("アカウントタイプを選んでログイン")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // User Type Selector (inline toggle)
            HStack(spacing: 0) {
                Button(action: { withAnimation { selectedUserType = .jobSeeker } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                        Text("働きたい")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedUserType == .jobSeeker ? Color.blue : Color.clear)
                    .foregroundColor(selectedUserType == .jobSeeker ? .white : .gray)
                }

                Button(action: { withAnimation { selectedUserType = .employer } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.title3)
                        Text("募集したい")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedUserType == .employer ? Color.green : Color.clear)
                    .foregroundColor(selectedUserType == .employer ? .white : .gray)
                }
            }
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 12) {
                // LINE Login Button - Primary
                Button(action: {
                    startNativeAuth(provider: .line)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LINEで続ける")
                                .fontWeight(.semibold)
                            Text("ワンタップで簡単登録")
                                .font(.caption)
                                .opacity(0.9)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color(red: 0, green: 0.72, blue: 0))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("LINEでログイン")
                .accessibilityHint("LINEアカウントでログインします")

                // Google Login Button
                Button(action: {
                    startNativeAuth(provider: .google)
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                            Text("G")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.red)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Googleで続ける")
                                .fontWeight(.semibold)
                            Text("Googleアカウントでログイン")
                                .font(.caption)
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color(.systemBackground))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .accessibilityLabel("Googleでログイン")
                .accessibilityHint("Googleアカウントでログインします")

                // Apple Sign In Button
                Button(action: {
                    startNativeAuth(provider: .apple)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Appleで続ける")
                                .fontWeight(.semibold)
                            Text("Apple IDでログイン")
                                .font(.caption)
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Appleでログイン")
                .accessibilityHint("Apple IDでログインします")

            }
            .disabled(!agreedToTerms || isLoading)
            .opacity(agreedToTerms ? 1.0 : 0.5)

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button(action: { errorMessage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }

            // Terms Agreement
            VStack(spacing: 8) {
                Button(action: { agreedToTerms.toggle() }) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                            .foregroundColor(agreedToTerms ? .blue : .gray)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Button(action: { showTerms = true }) {
                                    Text("利用規約")
                                        .underline()
                                        .foregroundColor(.blue)
                                }
                                Text("と")
                                    .foregroundColor(.gray)
                                Button(action: { showPrivacy = true }) {
                                    Text("プライバシーポリシー")
                                        .underline()
                                        .foregroundColor(.blue)
                                }
                            }
                            .font(.caption)
                            Text("に同意します")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(.plain)

                if !agreedToTerms {
                    Text("まず利用規約にチェックを入れてソーシャルボタンを押してください")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.top, 8)
            .sheet(isPresented: $showTerms) {
                NavigationStack {
                    TermsOfServiceView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") { showTerms = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showPrivacy) {
                NavigationStack {
                    PrivacyPolicyView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") { showPrivacy = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - 共通ログイン完了処理

    private func completeLogin(with loginResponse: LoginResponse, provider: SocialAuthProvider) {
        KeychainHelper.save(key: "auth_token", value: loginResponse.accessToken)
        APIClient.shared.invalidateTokenCache()
        authManager.markAsSocialLogin()
        authManager.setActiveUserType(selectedUserType)
        UserDefaults.standard.set(selectedUserType.rawValue, forKey: "cached_user_type")
        authManager.currentUser = loginResponse.user
        authManager.isAuthenticated = true
        authManager.cacheCurrentUser()
        authManager.markLoginSuccess()
        AnalyticsService.shared.track(AnalyticsService.eventLoginSuccess, properties: ["provider": provider.rawValue])
        appState.onLoginSuccess(userType: selectedUserType)
        isLoading = false
    }

    /// エラーメッセージを表示し、5秒後に自動消去する
    private func showError(_ message: String) {
        errorMessage = message
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                withAnimation { errorMessage = nil }
            }
        }
    }

    // MARK: - Native SDK Auth

    private func startNativeAuth(provider: SocialAuthProvider) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result: SocialAuthResult

                switch provider {
                case .google:
                    guard let vc = getPresentingViewController() else {
                        isLoading = false
                        showError("画面の取得に失敗しました")
                        return
                    }
                    result = try await SocialAuthService.shared.signInWithGoogle(presentingVC: vc)

                case .line:
                    guard let vc = getPresentingViewController() else {
                        isLoading = false
                        showError("画面の取得に失敗しました")
                        return
                    }
                    result = try await SocialAuthService.shared.signInWithLINE(presentingVC: vc)

                case .apple:
                    result = try await SocialAuthService.shared.signInWithApple()
                }

                // Send token to backend
                let loginResponse: LoginResponse
                switch result.provider {
                case .google:
                    guard let idToken = result.idToken else { throw SocialAuthError.noToken }
                    loginResponse = try await APIClient.shared.socialLoginGoogle(
                        idToken: idToken,
                        userType: userType.rawValue
                    )
                case .line:
                    guard let accessToken = result.accessToken else { throw SocialAuthError.noToken }
                    loginResponse = try await APIClient.shared.socialLoginLine(
                        accessToken: accessToken,
                        idToken: result.idToken,
                        userType: userType.rawValue
                    )
                case .apple:
                    guard let identityToken = result.identityToken else { throw SocialAuthError.noToken }
                    loginResponse = try await APIClient.shared.socialLoginApple(
                        identityToken: identityToken,
                        userType: userType.rawValue,
                        name: result.name,
                        email: result.email
                    )
                }

                completeLogin(with: loginResponse, provider: provider)

            } catch let error as SocialAuthError {
                switch error {
                case .cancelled:
                    isLoading = false
                    break // User cancelled - no error message
                case .notConfigured where provider == .line:
                    fallbackToWebAuth(provider: provider)
                case .sdkError where provider == .line:
                    fallbackToWebAuth(provider: provider)
                default:
                    isLoading = false
                    if let desc = error.errorDescription {
                        showError(desc)
                    }
                }
            } catch let error as APIError {
                isLoading = false
                AnalyticsService.shared.track(AnalyticsService.eventLoginFailed, properties: ["provider": provider.rawValue, "error": error.localizedDescription])
                switch error {
                case .networkError:
                    showError("サーバーに接続できません。ネットワークを確認してください。")
                case .serverError(let message):
                    showError("サーバーエラー: \(message)")
                case .unauthorized:
                    showError("認証に失敗しました。もう一度お試しください。")
                default:
                    showError("ログインに失敗しました: \(error.errorDescription ?? "不明なエラー")")
                }
            } catch {
                isLoading = false
                showError("認証に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    private func getPresentingViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else {
            return nil
        }
        var vc = rootVC
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }

    // MARK: - Web OAuth Fallback

    private func fallbackToWebAuth(provider: SocialAuthProvider) {
        startOAuthFlow(provider: provider.rawValue)
    }

    private func startOAuthFlow(provider: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let authURL = try await getOAuthURL(provider: provider)

                await MainActor.run {
                    let session = ASWebAuthenticationSession(
                        url: authURL,
                        callbackURLScheme: "byters"
                    ) { callbackURL, error in
                        handleOAuthCallback(callbackURL: callbackURL, error: error, provider: provider)
                    }

                    session.presentationContextProvider = WebAuthContextProvider.shared
                    session.prefersEphemeralWebBrowserSession = false

                    self.webAuthSession = session

                    if !session.start() {
                        isLoading = false
                        errorMessage = "認証を開始できませんでした"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "認証の準備に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }

    private func getOAuthURL(provider: String) async throws -> URL {
        let baseURL = StripeConfig.apiBaseURL

        let urlString = "\(baseURL)/auth/mobile/\(provider)/url?user_type=\(userType.rawValue)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "OAuthError",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "サーバーエラー(\(httpResponse.statusCode)): \(body)"]
            )
        }

        let oauthResponse = try JSONDecoder().decode(OAuthURLResponse.self, from: data)

        guard let authURL = URL(string: oauthResponse.url) else {
            throw URLError(.badURL)
        }

        return authURL
    }

    private func handleOAuthCallback(callbackURL: URL?, error: Error?, provider: String) {
        Task { @MainActor in
            if let error = error {
                isLoading = false
                let nsError = error as NSError
                if nsError.code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    showError("認証エラー: \(error.localizedDescription)")
                }
                return
            }

            guard let callbackURL = callbackURL else {
                isLoading = false
                showError("認証に失敗しました")
                return
            }

            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)

            if let errorParam = components?.queryItems?.first(where: { $0.name == "error" })?.value {
                let message = components?.queryItems?.first(where: { $0.name == "message" })?.value ?? errorParam
                isLoading = false
                showError("認証エラー: \(message)")
                return
            }

            if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value {
                completeLoginWithToken(token)
                return
            }

            if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value {
                await exchangeCodeForToken(provider: provider, code: code)
                return
            }

            isLoading = false
            showError("認証コードを取得できませんでした")
        }
    }

    private func completeLoginWithToken(_ token: String) {
        Task { @MainActor in
            do {
                let user = try await fetchUserWithToken(token)
                let response = LoginResponse(accessToken: token, user: user)
                completeLogin(with: response, provider: .google)
            } catch {
                isLoading = false
                showError("ユーザー情報の取得に失敗しました")
            }
        }
    }

    private func fetchUserWithToken(_ token: String) async throws -> User {
        let baseURL = StripeConfig.apiBaseURL
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(User.self, from: data)
    }

    @MainActor
    private func exchangeCodeForToken(provider: String, code: String) async {
        let baseURL = StripeConfig.apiBaseURL
        guard let url = URL(string: "\(baseURL)/auth/mobile/\(provider)/callback") else {
            isLoading = false
            showError("URLエラー")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "code": code,
            "user_type": userType.rawValue
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                let socialProvider = SocialAuthProvider(rawValue: provider) ?? .google
                completeLogin(with: loginResponse, provider: socialProvider)
            } else {
                isLoading = false
                if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    showError(errorData.detail)
                } else {
                    showError("ログインに失敗しました（\(httpResponse.statusCode)）")
                }
            }
        } catch {
            isLoading = false
            showError("認証処理中にエラーが発生しました")
        }
    }
}

// MARK: - Password Reset

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("パスワードリセット")
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("登録メールアドレスにパスワードリセットのリンクを送信します")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("メールアドレス") {
                    TextField("example@email.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .submitLabel(.done)

                    if let emailErr = ValidationHelper.emailError(email) {
                        Text(emailErr)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if let success = successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(action: sendResetEmail) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("リセットメールを送信")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(!ValidationHelper.isValidEmail(email) || isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func sendResetEmail() {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.requestPasswordReset(email: email)
                await MainActor.run {
                    isLoading = false
                    successMessage = "リセットメールを送信しました。メールをご確認ください。"
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "送信に失敗しました。メールアドレスをご確認ください。"
                }
            }
        }
    }
}

// MARK: - Web Auth Context Provider

class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Response Models

struct OAuthURLResponse: Codable {
    let url: String
}

struct ErrorResponse: Codable {
    let detail: String
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
        .environmentObject(AppState())
}

