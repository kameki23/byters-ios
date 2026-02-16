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

    private let api = APIClient.shared

    var userType: UserType? {
        guard let typeString = currentUser?.userType else { return nil }
        return UserType(rawValue: typeString)
    }

    init() {
        migrateTokenFromUserDefaults()
        Task {
            await checkAuthStatus()
        }
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
        } catch {
            // Token is invalid, clear it
            logout()
        }

        isLoading = false
    }

    func login(email: String, password: String) async -> Bool {
        error = nil

        do {
            let response = try await api.login(email: email, password: password)
            KeychainHelper.save(key: "auth_token", value: response.accessToken)
            self.currentUser = response.user
            self.isAuthenticated = true
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
                self.currentUser = user
                self.isAuthenticated = true
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
        KeychainHelper.delete(key: "auth_token")
        KeychainHelper.delete(key: "is_admin")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "is_admin")
        SocialAuthService.shared.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    /// Called when API returns 401 - force logout and redirect to login
    func handleUnauthorized() {
        guard isAuthenticated else { return }
        logout()
    }

    var isAdmin: Bool {
        return currentUser?.userType == "admin"
    }
}
