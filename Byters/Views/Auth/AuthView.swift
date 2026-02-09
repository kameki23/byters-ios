import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var selectedUserType: UserType = .jobSeeker
    @State private var isLoading = false
    @State private var showUserTypeSelection = true
    @State private var errorMessage: String?

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
                VStack(spacing: 30) {
                    // Logo - Secret admin access (tap 7 times)
                    VStack(spacing: 12) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)

                        Text("Byters")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)

                        Text("短期アルバイトマッチング")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 60)
                    .onTapGesture {
                        handleSecretTap()
                    }

                    Spacer(minLength: 20)

                    // Auth Card
                    VStack(spacing: 24) {
                        if showUserTypeSelection {
                            UserTypeSelectionView(
                                selectedType: $selectedUserType,
                                onContinue: {
                                    withAnimation {
                                        showUserTypeSelection = false
                                    }
                                }
                            )
                        } else {
                            SocialLoginView(
                                userType: selectedUserType,
                                isLoading: $isLoading,
                                errorMessage: $errorMessage,
                                onBack: {
                                    withAnimation {
                                        showUserTypeSelection = true
                                        errorMessage = nil
                                    }
                                }
                            )
                            .environmentObject(authManager)
                            .environmentObject(appState)
                        }
                    }
                    .padding(24)
                    .background(Color.white)
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

                    SecureField("パスワード", text: $password)
                        .textContentType(.password)
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
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        errorMessage = nil
                        dismiss()
                    }
                }
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
                    UserDefaults.standard.set(response.accessToken, forKey: "auth_token")
                    UserDefaults.standard.set(true, forKey: "is_admin")
                    authManager.currentUser = response.user
                    authManager.isAuthenticated = true
                    appState.onLoginSuccess()
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
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onBack: () -> Void

    @State private var webAuthSession: ASWebAuthenticationSession?

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .foregroundColor(.gray)
                    .font(.subheadline)
                }
                Spacer()
            }

            VStack(spacing: 8) {
                Text(userType == .jobSeeker ? "求職者として始める" : "事業者として始める")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("アカウントを作成またはログイン")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 12) {
                // LINE Login Button - Primary
                Button(action: { startOAuthFlow(provider: "line") }) {
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

                // Google Login Button
                Button(action: { startOAuthFlow(provider: "google") }) {
                    HStack(spacing: 12) {
                        // Google Logo
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
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Terms
            VStack(spacing: 4) {
                Text("続けることで")
                    .font(.caption2)
                    .foregroundColor(.gray)
                HStack(spacing: 4) {
                    Text("利用規約")
                        .underline()
                    Text("と")
                    Text("プライバシーポリシー")
                        .underline()
                }
                .font(.caption2)
                .foregroundColor(.blue)
                Text("に同意したものとみなされます")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 8)
        }
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
                    // Use ephemeral for fresh login each time
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
                    errorMessage = "認証の準備に失敗しました"
                }
            }
        }
    }

    private func getOAuthURL(provider: String) async throws -> URL {
        let baseURL = "https://byters.jp/api"
        let callbackURL = "byters://auth/callback"

        let urlString = "\(baseURL)/auth/\(provider)/url?front_url=\(callbackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&user_type=\(userType.rawValue)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let oauthResponse = try JSONDecoder().decode(OAuthURLResponse.self, from: data)

        guard let authURL = URL(string: oauthResponse.url) else {
            throw URLError(.badURL)
        }

        return authURL
    }

    private func handleOAuthCallback(callbackURL: URL?, error: Error?, provider: String) {
        if let error = error {
            DispatchQueue.main.async {
                isLoading = false
                if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    errorMessage = "認証がキャンセルされました"
                }
            }
            return
        }

        guard let callbackURL = callbackURL else {
            DispatchQueue.main.async {
                isLoading = false
                errorMessage = "認証に失敗しました"
            }
            return
        }

        // Parse callback URL
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)

        // Check for direct token (some OAuth flows return token directly)
        if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value {
            completeLoginWithToken(token)
            return
        }

        // Check for code to exchange
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            DispatchQueue.main.async {
                isLoading = false
                errorMessage = "認証コードを取得できませんでした"
            }
            return
        }

        // Exchange code for token
        Task {
            await exchangeCodeForToken(provider: provider, code: code)
        }
    }

    private func completeLoginWithToken(_ token: String) {
        Task {
            do {
                // Fetch user info with token
                let user = try await fetchUserWithToken(token)

                await MainActor.run {
                    UserDefaults.standard.set(token, forKey: "auth_token")
                    authManager.currentUser = user
                    authManager.isAuthenticated = true
                    appState.onLoginSuccess()  // Navigate to MyPage after login
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "ユーザー情報の取得に失敗しました"
                }
            }
        }
    }

    private func fetchUserWithToken(_ token: String) async throws -> User {
        let baseURL = "https://byters.jp/api"
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

    private func exchangeCodeForToken(provider: String, code: String) async {
        let baseURL = "https://byters.jp/api"
        guard let url = URL(string: "\(baseURL)/auth/\(provider)/callback") else {
            await MainActor.run {
                isLoading = false
                errorMessage = "URLエラー"
            }
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

                await MainActor.run {
                    UserDefaults.standard.set(loginResponse.accessToken, forKey: "auth_token")
                    authManager.currentUser = loginResponse.user
                    authManager.isAuthenticated = true
                    appState.onLoginSuccess()  // Navigate to MyPage after login
                    isLoading = false
                }
            } else {
                // Try to parse error
                if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = errorData.detail
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "ログインに失敗しました（\(httpResponse.statusCode)）"
                    }
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "認証処理中にエラーが発生しました"
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
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
