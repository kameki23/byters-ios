import Foundation
import SwiftUI

enum UserType: String, Codable {
    case jobSeeker = "job_seeker"
    case employer = "employer"
    case admin = "admin"
}

@MainActor
class AuthManager: ObservableObject {
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
        Task {
            await checkAuthStatus()
        }
    }

    func checkAuthStatus() async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else {
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
            UserDefaults.standard.set(response.accessToken, forKey: "auth_token")
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
                UserDefaults.standard.set(token, forKey: "auth_token")
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
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "is_admin")
        currentUser = nil
        isAuthenticated = false
    }

    var isAdmin: Bool {
        return currentUser?.userType == "admin" || UserDefaults.standard.bool(forKey: "is_admin")
    }
}
