import Foundation
import UIKit
import Stripe
import StripePaymentSheet

// MARK: - Stripe Service

/// Stripe API configuration
struct StripeConfig {
    /// Returns whether Stripe is properly configured
    static var isConfigured: Bool {
        let key = publishableKey
        return !key.isEmpty && (key.hasPrefix("pk_test_") || key.hasPrefix("pk_live_"))
    }

    /// Stripe publishable key from Info.plist or environment
    static var publishableKey: String {
        // First try to get from Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "StripePublishableKey") as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }

        // Fallback to environment variable
        if let envKey = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"],
           !envKey.isEmpty {
            return envKey
        }

        // Return empty string if not configured - app should check isConfigured before using
        return ""
    }

    /// Backend API base URL
    static var apiBaseURL: String {
        if let url = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           !url.isEmpty, !url.hasPrefix("$(") {
            return url
        }
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !envURL.isEmpty {
            return envURL
        }
        return "https://byters.jp/api"
    }
}

/// Stripe Service for handling payment operations
@MainActor
class StripeService: NSObject, ObservableObject {
    static let shared = StripeService()

    private let authContext = StripeAuthenticationContext()

    @Published var isConfigured = false
    @Published var lastError: String?

    private override init() {
        super.init()
        configure()
    }

    /// Configure Stripe SDK with publishable key
    func configure() {
        guard StripeConfig.isConfigured else {
            isConfigured = false
            lastError = "Stripe公開鍵が設定されていません"
            #if DEBUG
            print("[StripeService] Warning: Stripe publishable key not configured")
            #endif
            return
        }

        StripeAPI.defaultPublishableKey = StripeConfig.publishableKey
        isConfigured = true
        #if DEBUG
        print("[StripeService] Configured successfully")
        #endif
    }

    // MARK: - Card Token Creation

    /// Create a payment method token from card details
    /// - Parameters:
    ///   - cardNumber: The card number (without spaces)
    ///   - expMonth: Expiration month (1-12)
    ///   - expYear: Expiration year (2-digit)
    ///   - cvc: Card verification code
    /// - Returns: Payment method ID if successful
    func createPaymentMethod(
        cardNumber: String,
        expMonth: UInt,
        expYear: UInt,
        cvc: String
    ) async throws -> String {
        guard isConfigured else {
            throw StripeError.notConfigured
        }

        let cardParams = STPCardParams()
        cardParams.number = cardNumber.replacingOccurrences(of: " ", with: "")
        cardParams.expMonth = expMonth
        cardParams.expYear = expYear + 2000  // Convert 2-digit to 4-digit
        cardParams.cvc = cvc

        // Validate card params
        guard STPCardValidator.validationState(forNumber: cardParams.number ?? "", validatingCardBrand: true) == .valid else {
            throw StripeError.invalidCard
        }

        let paymentMethodParams = STPPaymentMethodParams(
            card: STPPaymentMethodCardParams(cardSourceParams: cardParams),
            billingDetails: nil,
            metadata: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            STPAPIClient.shared.createPaymentMethod(with: paymentMethodParams) { paymentMethod, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let paymentMethod = paymentMethod {
                    continuation.resume(returning: paymentMethod.stripeId)
                } else {
                    continuation.resume(throwing: StripeError.unknownError)
                }
            }
        }
    }

    // MARK: - Setup Intent Confirmation

    /// Confirm a SetupIntent with the payment method
    /// - Parameters:
    ///   - clientSecret: The SetupIntent client secret from backend
    ///   - paymentMethodId: The payment method ID to attach
    /// - Returns: True if successful
    func confirmSetupIntent(clientSecret: String, paymentMethodId: String) async throws -> Bool {
        guard isConfigured else {
            throw StripeError.notConfigured
        }

        let setupIntentParams = STPSetupIntentConfirmParams(clientSecret: clientSecret)
        setupIntentParams.paymentMethodID = paymentMethodId

        return try await withCheckedThrowingContinuation { continuation in
            STPPaymentHandler.shared().confirmSetupIntent(setupIntentParams, with: self.authContext) { status, _, error in
                switch status {
                case .succeeded:
                    continuation.resume(returning: true)
                case .canceled:
                    continuation.resume(throwing: StripeError.cancelled)
                case .failed:
                    continuation.resume(throwing: error ?? StripeError.unknownError)
                @unknown default:
                    continuation.resume(throwing: StripeError.unknownError)
                }
            }
        }
    }

    // MARK: - Payment Intent (for charges)

    /// Confirm a PaymentIntent to charge the customer
    /// - Parameters:
    ///   - clientSecret: The PaymentIntent client secret from backend
    ///   - paymentMethodId: The payment method ID to use
    /// - Returns: True if successful
    func confirmPaymentIntent(clientSecret: String, paymentMethodId: String) async throws -> Bool {
        guard isConfigured else {
            throw StripeError.notConfigured
        }

        let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
        paymentIntentParams.paymentMethodId = paymentMethodId

        return try await withCheckedThrowingContinuation { continuation in
            STPPaymentHandler.shared().confirmPayment(paymentIntentParams, with: self.authContext) { status, _, error in
                switch status {
                case .succeeded:
                    continuation.resume(returning: true)
                case .canceled:
                    continuation.resume(throwing: StripeError.cancelled)
                case .failed:
                    continuation.resume(throwing: error ?? StripeError.unknownError)
                @unknown default:
                    continuation.resume(throwing: StripeError.unknownError)
                }
            }
        }
    }

    // MARK: - Payment Sheet

    /// Present a Payment Sheet for collecting payment
    /// - Parameters:
    ///   - paymentIntentClientSecret: The PaymentIntent client secret
    ///   - customerId: The Stripe customer ID
    ///   - customerEphemeralKeySecret: The ephemeral key secret for the customer
    /// - Returns: Payment result
    func presentPaymentSheet(
        paymentIntentClientSecret: String,
        customerId: String,
        customerEphemeralKeySecret: String
    ) async throws -> PaymentSheetResult {
        guard isConfigured else {
            throw StripeError.notConfigured
        }

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Byters"
        configuration.customer = .init(id: customerId, ephemeralKeySecret: customerEphemeralKeySecret)
        configuration.allowsDelayedPaymentMethods = false

        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: paymentIntentClientSecret,
            configuration: configuration
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw StripeError.notConfigured
        }

        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }

        return await withCheckedContinuation { continuation in
            paymentSheet.present(from: topVC) { result in
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Stripe Authentication Context Helper

class StripeAuthenticationContext: NSObject, STPAuthenticationContext {
    func authenticationPresentingViewController() -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return UIViewController()
        }

        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        return topVC
    }
}

// MARK: - Stripe Errors

enum StripeError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidCard
    case serverError
    case cancelled
    case unknownError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Stripe SDKが設定されていません"
        case .invalidURL:
            return "無効なURLです"
        case .invalidCard:
            return "カード情報が無効です"
        case .serverError:
            return "サーバーエラーが発生しました"
        case .cancelled:
            return "キャンセルされました"
        case .unknownError:
            return "不明なエラーが発生しました"
        }
    }
}
