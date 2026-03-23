import Foundation
import SwiftUI

enum UserType: String, Codable {
    case jobSeeker = "job_seeker"
    case employer = "employer"
    case admin = "admin"
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var error: String?
    @Published var showSessionExpiredAlert: Bool = false
    @Published var isSocialLogin: Bool = false
    /// User type explicitly set during login/registration (persisted across sessions)
    @Published private(set) var activeUserType: UserType?

    private let api = APIClient.shared
    private var lastLoginTime: Date?
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    var userType: UserType? {
        // Priority 1: Explicitly set user type (from login/registration selection)
        if let active = activeUserType {
            return active
        }
        // Priority 2: Current user from backend
        if let typeString = currentUser?.userType {
            return UserType(rawValue: typeString)
        }
        // Priority 3: Cached user type (for offline scenarios)
        if let cached = UserDefaults.standard.string(forKey: "cached_user_type") {
            return UserType(rawValue: cached)
        }
        return nil
    }

    init() {
        isSocialLogin = UserDefaults.standard.bool(forKey: "is_social_login")
        // Restore active user type from persistence
        if let saved = UserDefaults.standard.string(forKey: "active_user_type") {
            activeUserType = UserType(rawValue: saved)
        }
        migrateTokenFromUserDefaults()

        // トークンがあればキャッシュからすぐにログイン状態にする
        if KeychainHelper.load(key: "auth_token") != nil {
            if let cachedUser = Self.loadCachedUser() {
                self.currentUser = cachedUser
                self.isAuthenticated = true
                self.isLoading = false
                // バックグラウンドで最新のユーザー情報を取得
                Task { @MainActor in
                    await self.refreshUserInBackground()
                }
            } else {
                // キャッシュがない場合はAPIから取得（初回のみ）
                Task { @MainActor in
                    async let auth: Void = self.checkAuthStatus()
                    async let timeout: Void = Self.splashTimeout(manager: self)
                    _ = await (auth, timeout)
                }
            }
        } else {
            // トークンなし → すぐにログイン画面を表示
            isLoading = false
        }
    }

    private static func splashTimeout(manager: AuthManager) async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        if manager.isLoading {
            manager.isLoading = false
        }
    }

    /// Set the active user type (from user selection during login/registration)
    func setActiveUserType(_ type: UserType) {
        activeUserType = type
        UserDefaults.standard.set(type.rawValue, forKey: "active_user_type")
    }

    func markAsSocialLogin() {
        isSocialLogin = true
        UserDefaults.standard.set(true, forKey: "is_social_login")
    }

    /// Migrate auth_token from UserDefaults to Keychain (one-time)
    private func migrateTokenFromUserDefaults() {
        if let oldToken = UserDefaults.standard.string(forKey: "auth_token") {
            KeychainHelper.save(key: "auth_token", value: oldToken)
            UserDefaults.standard.removeObject(forKey: "auth_token")
        }
    }

    func checkAuthStatus() async {
        guard KeychainHelper.load(key: "auth_token") != nil else {
            isLoading = false
            return
        }

        do {
            let user = try await api.getCurrentUser()
            self.currentUser = user
            self.isAuthenticated = true
            // Cache user for instant restore on next launch
            Self.cacheUser(user)
            UserDefaults.standard.set(user.userType, forKey: "cached_user_type")
            // If no active user type set yet, use backend's type
            if activeUserType == nil, let backendType = UserType(rawValue: user.userType) {
                setActiveUserType(backendType)
            }
            markLoginSuccess()
        } catch let apiError as APIError {
            if case .unauthorized = apiError {
                // Token is invalid (401), clear it
                logout()
            } else {
                // Network error etc. - keep login state, token is still valid
                self.isAuthenticated = true
            }
        } catch {
            // Network error - keep login state, token is still valid
            self.isAuthenticated = true
        }

        isLoading = false
    }

    /// バックグラウンドで最新のユーザー情報を取得（UIをブロックしない）
    private func refreshUserInBackground() async {
        do {
            let user = try await api.getCurrentUser()
            self.currentUser = user
            Self.cacheUser(user)
            UserDefaults.standard.set(user.userType, forKey: "cached_user_type")
            if activeUserType == nil, let backendType = UserType(rawValue: user.userType) {
                setActiveUserType(backendType)
            }
            markLoginSuccess()
        } catch let apiError as APIError {
            if case .unauthorized = apiError {
                logout()
            }
            // Other errors: keep cached user, don't logout
        } catch {
            // Network error: keep cached user
        }
    }

    // MARK: - User Cache

    private static let cachedUserKey = "cached_user_data"

    private static func cacheUser(_ user: User) {
        if let data = try? jsonEncoder.encode(user) {
            UserDefaults.standard.set(data, forKey: cachedUserKey)
        }
    }

    /// 外部からcurrentUserをキャッシュに保存する（AuthView等で使用）
    func cacheCurrentUser() {
        if let user = currentUser {
            Self.cacheUser(user)
        }
    }

    private static func loadCachedUser() -> User? {
        // Priority 1: UserDefaults cache (fastest)
        if let data = UserDefaults.standard.data(forKey: cachedUserKey),
           let user = try? jsonDecoder.decode(User.self, from: data) {
            return user
        }
        // Priority 2: Disk cache via CacheService (fallback)
        return CacheService.shared.load(User.self, forKey: "current_user", ttl: 60 * 60 * 24 * 7)
    }

    private static func clearCachedUser() {
        UserDefaults.standard.removeObject(forKey: cachedUserKey)
    }

    func login(email: String, password: String) async -> Bool {
        error = nil

        do {
            let response = try await api.login(email: email, password: password)
            KeychainHelper.save(key: "auth_token", value: response.accessToken)
            APIClient.shared.invalidateTokenCache()
            if let type = UserType(rawValue: response.user.userType) {
                setActiveUserType(type)
            }
            self.currentUser = response.user
            self.isAuthenticated = true
            Self.cacheUser(response.user)
            markLoginSuccess()
            return true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
            return false
        } catch {
            self.error = "ログインに失敗しました"
            return false
        }
    }

    func register(email: String, password: String, name: String, userType: UserType) async -> Bool {
        error = nil

        do {
            let response = try await api.register(
                email: email,
                password: password,
                name: name,
                userType: userType.rawValue
            )

            if let token = response.accessToken, let user = response.user {
                KeychainHelper.save(key: "auth_token", value: token)
                APIClient.shared.invalidateTokenCache()
                setActiveUserType(userType)
                self.currentUser = user
                self.isAuthenticated = true
                Self.cacheUser(user)
                markLoginSuccess()
                return true
            }

            // Registration successful but needs email verification
            return true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
            return false
        } catch {
            self.error = "登録に失敗しました"
            return false
        }
    }

    func logout() {
        AnalyticsService.shared.track(AnalyticsService.eventLogout)
        KeychainHelper.delete(key: "auth_token")
        APIClient.shared.invalidateTokenCache()
        KeychainHelper.delete(key: "is_admin")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "is_admin")
        UserDefaults.standard.removeObject(forKey: "is_social_login")
        UserDefaults.standard.removeObject(forKey: "cached_user_type")
        UserDefaults.standard.removeObject(forKey: "active_user_type")
        Self.clearCachedUser()
        CacheService.shared.clearAll()
        SocialAuthService.shared.signOut()
        currentUser = nil
        activeUserType = nil
        isAuthenticated = false
        isSocialLogin = false
    }

    /// Mark that a login just succeeded (grace period protection)
    func markLoginSuccess() {
        lastLoginTime = Date()
    }

    /// Called when API returns 401 - verify token before logging out
    func handleUnauthorized() {
        guard isAuthenticated else { return }
        // Don't auto-logout within 60 seconds of login
        if let loginTime = lastLoginTime, Date().timeIntervalSince(loginTime) < 60 {
            return
        }
        // Verify token is actually invalid before logging out
        Task {
            do {
                let user = try await api.getCurrentUser()
                // Token is still valid - update user data but don't logout
                self.currentUser = user
            } catch let apiError as APIError {
                if case .unauthorized = apiError {
                    // セッション切れをユーザーに通知してからログアウト
                    self.showSessionExpiredAlert = true
                    self.error = "セッションの有効期限が切れました。再度ログインしてください。"
                    logout()
                }
                // Other errors (network etc.) - don't logout
            } catch {
                // Network error - don't logout
            }
        }
    }

    /// セッション切れアラートを閉じる
    func dismissSessionExpiredAlert() {
        showSessionExpiredAlert = false
        error = nil
    }

    var isAdmin: Bool {
        return currentUser?.userType == "admin"
    }
}
