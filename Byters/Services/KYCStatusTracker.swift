import Foundation
import SwiftUI
import UserNotifications

@MainActor
class KYCStatusTracker: ObservableObject {
    static let shared = KYCStatusTracker()

    @Published var verificationStatus: IdentityVerification?
    @Published var isPolling: Bool = false

    private let api = APIClient.shared
    private var pollingTask: Task<Void, Never>?
    private var previousStatus: String?

    private init() {}

    // MARK: - Public Methods

    func startTracking() {
        guard !isPolling else { return }
        isPolling = true

        pollingTask = Task { [weak self] in
            guard let self else { return }

            // Initial check
            self.performStatusCheck()

            // Poll every 30 seconds while status is pending
            while !Task.isCancelled && self.isPolling {
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)

                guard !Task.isCancelled else { break }
                self.performStatusCheck()

                // Stop polling if status is no longer pending
                let status = self.verificationStatus?.status ?? ""
                if status == "approved" || status == "rejected" {
                    self.isPolling = false
                    break
                }
            }
        }
    }

    func stopTracking() {
        isPolling = false
        pollingTask?.cancel()
        pollingTask = nil
    }

    func checkStatus() async {
        performStatusCheck()
    }

    // MARK: - Private Methods

    private func performStatusCheck() {
        Task {
            do {
                let verification = try await api.getIdentityVerificationStatus()
                let oldStatus = previousStatus
                let newStatus = verification.status

                verificationStatus = verification
                previousStatus = newStatus

                // Notify on status change
                if let oldStatus, oldStatus != newStatus {
                    await handleStatusChange(newStatus: newStatus, verification: verification)
                }
            } catch {
                #if DEBUG
                print("[KYC] ステータス取得エラー: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func handleStatusChange(newStatus: String, verification: IdentityVerification) async {
        switch newStatus {
        case "approved":
            await sendLocalNotification(
                title: "本人確認が完了しました",
                body: "本人確認が承認されました。すべての機能をご利用いただけます。"
            )
        case "rejected":
            let reason = verification.rejectionReason ?? "書類に不備がありました"
            await sendLocalNotification(
                title: "本人確認が却下されました",
                body: "理由: \(reason)\n再度書類を提出してください。"
            )
        default:
            break
        }
    }

    private func sendLocalNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = NotificationManager.isInQuietHours() ? nil : .default

        let request = UNNotificationRequest(
            identifier: "kyc_status_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("[KYC] ローカル通知を送信しました: \(title)")
            #endif
        } catch {
            #if DEBUG
            print("[KYC] 通知送信エラー: \(error.localizedDescription)")
            #endif
        }
    }
}
