import Foundation
import UIKit
import AuthenticationServices
import GoogleSignIn
import LineSDK

enum SocialAuthProvider: String {
    case google
    case line
    case apple
}

struct SocialAuthResult {
    let provider: SocialAuthProvider
    let idToken: String?
    let accessToken: String?
    let identityToken: String?
    let name: String?
    let email: String?
}

enum SocialAuthError: Error, LocalizedError {
    case cancelled
    case notConfigured(String)
    case noToken
    case sdkError(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .notConfigured(let provider):
            return "\(provider)の設定が見つかりません"
        case .noToken:
            return "認証トークンを取得できませんでした"
        case .sdkError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class SocialAuthService {
    static let shared = SocialAuthService()

    private init() {}

    // MARK: - Configuration

    static var isGoogleConfigured: Bool {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty, !clientID.hasPrefix("CONFIGURE"), !clientID.hasPrefix("$(") else {
            return false
        }
        return true
    }

    static var isLineConfigured: Bool {
        guard let channelID = Bundle.main.object(forInfoDictionaryKey: "LineChannelID") as? String,
              !channelID.isEmpty, !channelID.hasPrefix("CONFIGURE"), !channelID.hasPrefix("$(") else {
            return false
        }
        return true
    }

    func setupSDKs() {
        if SocialAuthService.isLineConfigured,
           let channelID = Bundle.main.object(forInfoDictionaryKey: "LineChannelID") as? String {
            LoginManager.shared.setup(channelID: channelID, universalLinkURL: nil)
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle(presentingVC: UIViewController) async throws -> SocialAuthResult {
        guard SocialAuthService.isGoogleConfigured,
              let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            throw SocialAuthError.notConfigured("Google")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw SocialAuthError.noToken
            }

            return SocialAuthResult(
                provider: .google,
                idToken: idToken,
                accessToken: nil,
                identityToken: nil,
                name: result.user.profile?.name,
                email: result.user.profile?.email
            )
        } catch let error as GIDSignInError where error.code == .canceled {
            throw SocialAuthError.cancelled
        } catch {
            throw SocialAuthError.sdkError(error)
        }
    }

    // MARK: - LINE Sign In

    func signInWithLINE(presentingVC: UIViewController) async throws -> SocialAuthResult {
        guard SocialAuthService.isLineConfigured else {
            throw SocialAuthError.notConfigured("LINE")
        }

        return try await withCheckedThrowingContinuation { continuation in
            LoginManager.shared.login(
                permissions: [.profile, .openID, .email],
                in: presentingVC
            ) { result in
                switch result {
                case .success(let loginResult):
                    guard let accessToken = loginResult.accessToken.value as String? else {
                        continuation.resume(throwing: SocialAuthError.noToken)
                        return
                    }

                    // Extract email from ID token JWT claims (LINE doesn't put email in UserProfile)
                    var userEmail: String?
                    if let idTokenRaw = loginResult.accessToken.IDTokenRaw {
                        userEmail = Self.extractEmailFromIDToken(idTokenRaw)
                    }

                    continuation.resume(returning: SocialAuthResult(
                        provider: .line,
                        idToken: loginResult.accessToken.IDTokenRaw,
                        accessToken: accessToken,
                        identityToken: nil,
                        name: loginResult.userProfile?.displayName,
                        email: userEmail
                    ))

                case .failure(let error):
                    if case .responseFailed(reason: .userCancelled) = error {
                        continuation.resume(throwing: SocialAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: SocialAuthError.sdkError(error))
                    }
                }
            }
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple() async throws -> SocialAuthResult {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate

            // Keep delegate alive until callback
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

            controller.performRequests()
        }
    }

    // MARK: - URL Handling

    func handleURL(_ url: URL) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }

        if LoginManager.shared.application(UIApplication.shared, open: url) {
            return true
        }

        return false
    }

    // MARK: - Helpers

    private static func extractEmailFromIDToken(_ idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        // Pad base64 to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String, !email.isEmpty else {
            return nil
        }
        return email
    }

    // MARK: - Sign Out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<SocialAuthResult, Error>?

    init(continuation: CheckedContinuation<SocialAuthResult, Error>) {
        self.continuation = continuation
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            continuation?.resume(throwing: SocialAuthError.noToken)
            continuation = nil
            return
        }

        let fullName: String? = {
            guard let nameComponents = credential.fullName else { return nil }
            let parts = [nameComponents.familyName, nameComponents.givenName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        continuation?.resume(returning: SocialAuthResult(
            provider: .apple,
            idToken: nil,
            accessToken: nil,
            identityToken: identityToken,
            name: fullName,
            email: credential.email
        ))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: SocialAuthError.cancelled)
        } else {
            continuation?.resume(throwing: SocialAuthError.sdkError(error))
        }
        continuation = nil
    }
}
