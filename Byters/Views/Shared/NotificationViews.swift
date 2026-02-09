import SwiftUI

// MARK: - Notification List

struct NotificationListView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.gray)
                    Button("再読み込み") {
                        Task { await loadNotifications() }
                    }
                }
                .padding()
            } else if notificationManager.notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("通知はありません")
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                List {
                    ForEach(notificationManager.notifications) { notification in
                        NotificationRow(notification: notification) {
                            await notificationManager.markAsRead(notification.id)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadNotifications()
                }
            }
        }
        .navigationTitle("通知一覧")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !notificationManager.notifications.isEmpty {
                    Button("全て既読") {
                        Task { await notificationManager.markAllAsRead() }
                    }
                    .font(.caption)
                }
            }
        }
        .task {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        do {
            await notificationManager.loadUnreadCount()
            isLoading = false
        } catch {
            errorMessage = "通知の取得に失敗しました"
            isLoading = false
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () async -> Void

    var body: some View {
        Button {
            Task { await onTap() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                notificationIcon
                    .frame(width: 36, height: 36)
                    .background(iconBackgroundColor.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        if !notification.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)

                    if let createdAt = notification.createdAt {
                        Text(formatDate(createdAt))
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var notificationIcon: some View {
        Image(systemName: iconName)
            .foregroundColor(iconBackgroundColor)
    }

    private var iconName: String {
        switch notification.type.lowercased() {
        case "success", "application_accepted", "identity_approved":
            return "checkmark.circle.fill"
        case "warning":
            return "exclamationmark.triangle.fill"
        case "error", "application_rejected", "identity_rejected":
            return "xmark.circle.fill"
        case "application_received":
            return "person.badge.plus"
        case "application_submitted":
            return "paperplane.fill"
        case "application_cancelled":
            return "xmark.circle"
        case "payment_completed":
            return "yensign.circle.fill"
        case "withdrawal_requested":
            return "arrow.up.circle.fill"
        case "withdrawal_completed":
            return "checkmark.seal.fill"
        case "withdrawal_rejected":
            return "xmark.seal.fill"
        case "new_message":
            return "message.fill"
        case "checkin_confirmed":
            return "clock.badge.checkmark.fill"
        case "checkout_confirmed":
            return "flag.checkered"
        case "work_completed":
            return "star.fill"
        case "job_reminder":
            return "alarm.fill"
        case "job_cancelled":
            return "calendar.badge.minus"
        case "review_request":
            return "star.bubble.fill"
        case "new_job_posted":
            return "briefcase.fill"
        // Admin notification types
        case "admin_withdrawal_request":
            return "arrow.down.doc.fill"
        case "admin_identity_verification":
            return "person.text.rectangle.fill"
        default:
            return "bell.fill"
        }
    }

    private var iconBackgroundColor: Color {
        switch notification.type.lowercased() {
        case "success", "application_accepted", "identity_approved":
            return .green
        case "warning", "job_reminder":
            return .orange
        case "error", "withdrawal_rejected", "application_rejected", "job_cancelled", "application_cancelled", "identity_rejected":
            return .red
        case "application_received", "new_job_posted":
            return .blue
        case "application_submitted":
            return .cyan
        case "payment_completed", "withdrawal_completed":
            return .purple
        case "withdrawal_requested":
            return .indigo
        case "new_message":
            return .cyan
        case "checkin_confirmed", "checkout_confirmed":
            return .teal
        case "work_completed", "review_request":
            return .yellow
        // Admin notification types
        case "admin_withdrawal_request":
            return .orange
        case "admin_identity_verification":
            return .blue
        default:
            return .gray
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "M/d HH:mm"
            return displayFormatter.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "M/d HH:mm"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @State private var jobNotifications = true
    @State private var chatNotifications = true
    @State private var paymentNotifications = true

    var body: some View {
        Form {
            Section("通知設定") {
                Toggle("新着求人の通知", isOn: $jobNotifications)
                Toggle("チャットメッセージ", isOn: $chatNotifications)
                Toggle("決済・出金の通知", isOn: $paymentNotifications)
            }

            Section {
                Text("通知設定はデバイスの設定からも変更できます")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("通知設定")
    }
}
