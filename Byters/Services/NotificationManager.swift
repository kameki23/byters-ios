import SwiftUI
import UIKit
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var unreadCount: Int = 0
    @Published var chatUnreadCount: Int = 0
    @Published var notifications: [AppNotification] = []
    @Published var loadError: String?

    private let api = APIClient.shared

    private init() {}

    func loadUnreadCount() async {
        loadError = nil
        do {
            let allNotifications = try await api.getNotifications()
            unreadCount = allNotifications.filter { !$0.isRead }.count
            notifications = allNotifications
        } catch {
            loadError = "通知の読み込みに失敗しました"
        }
    }

    func loadChatUnreadCount() async {
        // Retry up to 2 times on failure
        for attempt in 0..<3 {
            do {
                let rooms = try await api.getChatRooms()
                chatUnreadCount = rooms.compactMap(\.unreadCount).reduce(0, +)
                return
            } catch {
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                }
            }
        }
    }

    func markAsRead(_ id: String) async {
        do {
            _ = try await api.markNotificationRead(notificationId: id)
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                let old = notifications[index]
                if !old.isRead {
                    notifications[index] = AppNotification(
                        id: old.id,
                        userId: old.userId,
                        type: old.type,
                        title: old.title,
                        message: old.message,
                        isRead: true,
                        data: old.data,
                        createdAt: old.createdAt,
                        imageUrl: old.imageUrl
                    )
                    unreadCount = max(0, unreadCount - 1)
                }
            }
        } catch {
            loadError = "通知の更新に失敗しました"
        }
    }

    func markAllAsRead() async {
        do {
            _ = try await api.markAllNotificationsRead()
            notifications = notifications.map { n in
                AppNotification(
                    id: n.id,
                    userId: n.userId,
                    type: n.type,
                    title: n.title,
                    message: n.message,
                    isRead: true,
                    data: n.data,
                    createdAt: n.createdAt,
                    imageUrl: n.imageUrl
                )
            }
            unreadCount = 0
        } catch {
            loadError = "通知の更新に失敗しました"
        }
    }

    // MARK: - Quiet Hours

    /// Check if the current time falls within quiet hours.
    nonisolated static func isInQuietHours() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "quiet_hours_enabled") else { return false }

        let start = defaults.double(forKey: "quiet_hours_start") // seconds from midnight
        let end = defaults.double(forKey: "quiet_hours_end")
        let now = Date().timeIntervalSince(Calendar.current.startOfDay(for: Date()))

        if start < end {
            // e.g. 08:00 - 18:00
            return now >= start && now < end
        } else {
            // e.g. 22:00 - 07:00 (overnight)
            return now >= start || now < end
        }
    }

    // MARK: - Rich Notification Support

    /// Register notification categories with actions for rich push notifications.
    func registerNotificationCategories() {
        // Chat message category: reply with text input + open action
        let replyAction = UNTextInputNotificationAction(
            identifier: "reply_action",
            title: "返信",
            options: [],
            textInputButtonTitle: "送信",
            textInputPlaceholder: "メッセージを入力..."
        )
        let openChatAction = UNNotificationAction(
            identifier: "open_action",
            title: "開く",
            options: [.foreground]
        )
        let chatCategory = UNNotificationCategory(
            identifier: "chat_message",
            actions: [replyAction, openChatAction],
            intentIdentifiers: [],
            options: []
        )

        // Job update category: view details action
        let viewDetailsAction = UNNotificationAction(
            identifier: "view_details_action",
            title: "詳細を見る",
            options: [.foreground]
        )
        let jobUpdateCategory = UNNotificationCategory(
            identifier: "job_update",
            actions: [viewDetailsAction],
            intentIdentifiers: [],
            options: []
        )

        // Application update category: confirm action
        let confirmAction = UNNotificationAction(
            identifier: "confirm_action",
            title: "確認する",
            options: [.foreground]
        )
        let applicationUpdateCategory = UNNotificationCategory(
            identifier: "application_update",
            actions: [confirmAction],
            intentIdentifiers: [],
            options: []
        )

        // Payment category
        let viewPaymentAction = UNNotificationAction(
            identifier: "view_payment_action",
            title: "支払いを確認",
            options: [.foreground]
        )
        let paymentCategory = UNNotificationCategory(
            identifier: "payment",
            actions: [viewPaymentAction],
            intentIdentifiers: [],
            options: []
        )

        // Work reminder category
        let checkInAction = UNNotificationAction(
            identifier: "check_in_action",
            title: "チェックイン",
            options: [.foreground]
        )
        let workReminderCategory = UNNotificationCategory(
            identifier: "work_reminder",
            actions: [checkInAction],
            intentIdentifiers: [],
            options: []
        )

        // Review category
        let writeReviewAction = UNNotificationAction(
            identifier: "write_review_action",
            title: "レビューを書く",
            options: [.foreground]
        )
        let reviewCategory = UNNotificationCategory(
            identifier: "review_request",
            actions: [writeReviewAction],
            intentIdentifiers: [],
            options: []
        )

        // KYC status category
        let viewKYCAction = UNNotificationAction(
            identifier: "view_kyc_action",
            title: "確認する",
            options: [.foreground]
        )
        let kycCategory = UNNotificationCategory(
            identifier: "kyc_update",
            actions: [viewKYCAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            chatCategory,
            jobUpdateCategory,
            applicationUpdateCategory,
            paymentCategory,
            workReminderCategory,
            reviewCategory,
            kycCategory
        ])
    }

    /// Download an image from a URL and save it to a temporary file suitable for UNNotificationAttachment.
    nonisolated func downloadImageForAttachment(from urlString: String) async -> UNNotificationAttachment? {
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("[RichPush] Invalid image URL: \(urlString)")
            #endif
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  !data.isEmpty else {
                #if DEBUG
                print("[RichPush] Failed to download image: invalid response")
                #endif
                return nil
            }

            // Determine file extension from MIME type
            let fileExtension: String
            let mimeType = httpResponse.mimeType ?? ""
            switch mimeType {
            case "image/png":
                fileExtension = "png"
            case "image/gif":
                fileExtension = "gif"
            case "image/jpeg", "image/jpg":
                fileExtension = "jpg"
            default:
                fileExtension = "jpg"
            }

            // Save to temp directory with unique filename
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + "." + fileExtension
            let fileURL = tempDir.appendingPathComponent(fileName)
            try data.write(to: fileURL)

            // Cache the image in memory as well
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    ImageCache.shared.setImage(uiImage, for: urlString)
                }
            }

            let attachment = try UNNotificationAttachment(
                identifier: UUID().uuidString,
                url: fileURL,
                options: nil
            )
            return attachment
        } catch {
            #if DEBUG
            print("[RichPush] Error creating attachment: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Create and schedule a local notification with an image attachment.
    /// Used to re-present a push notification with rich content (image).
    nonisolated func scheduleRichLocalNotification(
        title: String,
        body: String,
        userInfo: [AnyHashable: Any],
        categoryIdentifier: String,
        imageUrl: String?
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        content.categoryIdentifier = categoryIdentifier
        content.sound = NotificationManager.isInQuietHours() ? nil : .default

        // Group notifications by type using threadIdentifier
        let threadId: String
        switch categoryIdentifier {
        case "chat_message":
            let roomId = userInfo["room_id"] as? String ?? "general"
            threadId = "chat-\(roomId)"
        case "job_update", "new_job":
            threadId = "jobs"
        case "application_update":
            threadId = "applications"
        case "payment":
            threadId = "payments"
        case "work_reminder":
            threadId = "work"
        case "review_request":
            threadId = "reviews"
        case "kyc_update":
            threadId = "kyc"
        default:
            threadId = "general"
        }
        content.threadIdentifier = threadId

        // Download and attach image if available
        if let imageUrl = imageUrl {
            if let attachment = await downloadImageForAttachment(from: imageUrl) {
                content.attachments = [attachment]
            }
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("[RichPush] Rich local notification scheduled successfully")
            #endif
        } catch {
            #if DEBUG
            print("[RichPush] Failed to schedule rich notification: \(error.localizedDescription)")
            #endif
        }
    }

    /// Process incoming push notification userInfo and enrich it with image attachment if needed.
    /// Returns true if enrichment was performed (a new local notification was scheduled).
    nonisolated func enrichPushNotificationWithImage(userInfo: [AnyHashable: Any]) async -> Bool {
        guard let imageUrl = userInfo["image_url"] as? String,
              !imageUrl.isEmpty else {
            return false
        }

        let title = userInfo["title"] as? String
            ?? (userInfo["aps"] as? [String: Any])?["alert"].flatMap { alert -> String? in
                if let alertDict = alert as? [String: Any] {
                    return alertDict["title"] as? String
                }
                return alert as? String
            }
            ?? ""

        let body = userInfo["body"] as? String
            ?? (userInfo["aps"] as? [String: Any])?["alert"].flatMap { alert -> String? in
                if let alertDict = alert as? [String: Any] {
                    return alertDict["body"] as? String
                }
                return nil
            }
            ?? ""

        let categoryIdentifier = userInfo["type"] as? String ?? "default"

        await scheduleRichLocalNotification(
            title: title,
            body: body,
            userInfo: userInfo,
            categoryIdentifier: categoryIdentifier,
            imageUrl: imageUrl
        )

        return true
    }
}
