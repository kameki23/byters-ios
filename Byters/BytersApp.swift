import SwiftUI
import UserNotifications
import GoogleSignIn

extension Notification.Name {
    static let chatMessageReceived = Notification.Name("chatMessageReceived")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Register rich notification categories with actions
        Task { @MainActor in
            NotificationManager.shared.registerNotificationCategories()
        }

        // Setup social auth SDKs (LINE)
        SocialAuthService.shared.setupSDKs()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            let maxRetries = 3
            var lastError: Error?
            for attempt in 0..<maxRetries {
                do {
                    _ = try await APIClient.shared.registerDeviceToken(token: token)
                    #if DEBUG
                    print("[Push] Device token registered successfully (attempt \(attempt + 1))")
                    #endif
                    return
                } catch {
                    lastError = error
                    #if DEBUG
                    print("[Push] Failed to register device token (attempt \(attempt + 1)/\(maxRetries)): \(error.localizedDescription)")
                    #endif
                    if attempt < maxRetries - 1 {
                        // Exponential backoff: 2s, 4s, 8s
                        let delay = UInt64(pow(2.0, Double(attempt + 1))) * 1_000_000_000
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
            }
            #if DEBUG
            if let lastError = lastError {
                print("[Push] Device token registration failed after \(maxRetries) attempts: \(lastError.localizedDescription)")
            }
            #endif
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] Remote notification registration failed: \(error.localizedDescription)")
        #endif
    }

    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        // Notify chat views to refresh when a chat-related push arrives
        if let type = userInfo["type"] as? String, type == "chat_message" {
            NotificationCenter.default.post(name: .chatMessageReceived, object: nil, userInfo: userInfo)
        }

        // If the push has an image_url and no existing attachment, enrich it with a local notification
        if let imageUrl = userInfo["image_url"] as? String,
           !imageUrl.isEmpty,
           notification.request.content.attachments.isEmpty {
            Task {
                await NotificationManager.shared.enrichPushNotificationWithImage(userInfo: userInfo)
            }
            // Suppress the original notification since we will re-present it with the image
            completionHandler([])
            return
        }

        completionHandler([.banner, .badge, .sound])
    }

    // Handle notification tap and action responses
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        Task { @MainActor in
            await NotificationManager.shared.loadUnreadCount()

            let appState = AppState.shared

            // Handle category-specific action responses
            switch actionIdentifier {
            case "reply_action":
                // Handle inline reply from chat_message category
                if let textResponse = response as? UNTextInputNotificationResponse {
                    let replyText = textResponse.userText
                    let roomId = userInfo["room_id"] as? String
                    #if DEBUG
                    print("[RichPush] Reply action: \"\(replyText)\" for room: \(roomId ?? "unknown")")
                    #endif
                    // Send the reply message via API
                    if let roomId = roomId, !replyText.isEmpty {
                        do {
                            _ = try await APIClient.shared.sendMessage(roomId: roomId, content: replyText)
                        } catch {
                            #if DEBUG
                            print("[RichPush] Failed to send reply: \(error.localizedDescription)")
                            #endif
                        }
                    }
                    // Navigate to the chat room
                    appState.handleDeepLink(.chat(roomId: roomId))
                }
                completionHandler()
                return

            case "open_action":
                // Open chat from chat_message category
                let roomId = userInfo["room_id"] as? String
                appState.handleDeepLink(.chat(roomId: roomId))
                completionHandler()
                return

            case "view_details_action":
                // View details from job_update category
                if let jobId = userInfo["job_id"] as? String {
                    appState.handleDeepLink(.job(jobId: jobId))
                }
                completionHandler()
                return

            case "confirm_action":
                // Confirm from application_update category
                if let jobId = userInfo["job_id"] as? String {
                    appState.handleDeepLink(.job(jobId: jobId))
                }
                completionHandler()
                return

            default:
                break
            }

            // Default tap handling (no specific action, user tapped the notification itself)
            if let type = userInfo["type"] as? String {
                switch type {
                case "chat_message":
                    let roomId = userInfo["room_id"] as? String
                    appState.handleDeepLink(.chat(roomId: roomId))
                case "job_update", "new_job":
                    if let jobId = userInfo["job_id"] as? String {
                        appState.handleDeepLink(.job(jobId: jobId))
                    }
                case "application_update":
                    if let jobId = userInfo["job_id"] as? String {
                        appState.handleDeepLink(.job(jobId: jobId))
                    }
                default:
                    appState.handleDeepLink(.notifications)
                }
            }
        }
        completionHandler()
    }
}

@main
struct BytersApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .onAppear {
                    requestNotificationPermission()
                    AnalyticsService.shared.startNewSession()
                    // ATT permission request (iOS 14.5+)
                    Task {
                        await TrackingTransparencyManager.shared.requestPermission()
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // バックエンド接続監視を開始
                BackendConnectionMonitor.shared.startMonitoring()
                if authManager.isAuthenticated {
                    Task {
                        await NotificationManager.shared.loadUnreadCount()
                        if authManager.currentUser == nil {
                            await authManager.checkAuthStatus()
                        }
                    }
                    // WebSocket接続を復帰（認証済みの場合のみ）
                    if KeychainHelper.load(key: "auth_token") != nil {
                        WebSocketManager.shared.connect()
                    }
                }
                AnalyticsService.shared.track("app_foreground")
            case .background:
                BackendConnectionMonitor.shared.stopMonitoring()
                AnalyticsService.shared.endSession()
            default:
                break
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Let social auth SDKs handle their URLs first
        if SocialAuthService.shared.handleURL(url) {
            return
        }

        // Custom URL scheme: byters://
        if url.scheme == "byters" {
            if url.host == "job", let jobId = url.pathComponents.dropFirst().first {
                appState.navigateToJobDetail(jobId: jobId)
            } else if url.host == "chat" {
                let roomId = url.pathComponents.dropFirst().first
                appState.handleDeepLink(.chat(roomId: roomId))
            } else if url.host == "notifications" {
                appState.handleDeepLink(.notifications)
            }
            return
        }

        // Universal Links: https://byters.jp/...
        guard let host = url.host,
              host == "byters.jp" || host == "www.byters.jp" else { return }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let first = pathComponents.first else { return }

        switch first {
        case "jobs":
            if let jobId = pathComponents.dropFirst().first {
                appState.handleDeepLink(.job(jobId: jobId))
            }
        case "chat":
            let roomId = pathComponents.dropFirst().first
            appState.handleDeepLink(.chat(roomId: roomId))
        case "notifications":
            appState.handleDeepLink(.notifications)
        case "mypage":
            appState.handleDeepLink(.mypage)
        default:
            break
        }
    }
}
