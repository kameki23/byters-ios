import SwiftUI

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
        do {
            let rooms = try await api.getChatRooms()
            chatUnreadCount = rooms.compactMap(\.unreadCount).reduce(0, +)
        } catch {
            // Chat unread count is non-critical
        }
    }

    func markAsRead(_ id: String) async {
        do {
            _ = try await api.markNotificationRead(notificationId: id)
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                let old = notifications[index]
                notifications[index] = AppNotification(
                    id: old.id,
                    userId: old.userId,
                    type: old.type,
                    title: old.title,
                    message: old.message,
                    isRead: true,
                    data: old.data,
                    createdAt: old.createdAt
                )
            }
            unreadCount = max(0, unreadCount - 1)
        } catch {
            _ = error
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
                    createdAt: n.createdAt
                )
            }
            unreadCount = 0
        } catch {
            _ = error
        }
    }
}
