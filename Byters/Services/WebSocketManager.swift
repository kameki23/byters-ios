import Foundation
import Network

// MARK: - WebSocket Manager
// リアルタイムチャットメッセージング用WebSocket管理

@MainActor
class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var typingUsers: [String: Set<String>] = [:]  // roomId -> typing userIds
    @Published var onlineUsers: Set<String> = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var networkObserverTask: Task<Void, Never>?

    // 再接続用のエクスポネンシャルバックオフ
    private var reconnectAttempts = 0
    private let maxReconnectDelay: TimeInterval = 30
    private var isManuallyDisconnected = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    // MARK: - Connection

    func connect() {
        isManuallyDisconnected = false
        reconnectAttempts = 0
        observeNetworkChanges()
        establishConnection()
    }

    func disconnect() {
        isManuallyDisconnected = true
        tearDown()
        isConnected = false
        typingUsers.removeAll()
        onlineUsers.removeAll()
    }

    private func establishConnection() {
        // 既存の接続をクリーンアップ
        tearDown()

        guard let token = KeychainHelper.load(key: "auth_token") else {
            #if DEBUG
            print("[WebSocket] No auth token available")
            #endif
            return
        }

        // WebSocket URLを構築
        let wsBaseURL = StripeConfig.apiBaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsBaseURL)/ws") else {
            #if DEBUG
            print("[WebSocket] Invalid WebSocket URL")
            #endif
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        reconnectAttempts = 0

        #if DEBUG
        print("[WebSocket] Connected to \(url.absoluteString)")
        #endif

        startReceiving()
        startHeartbeat()
    }

    private func tearDown() {
        pingTask?.cancel()
        pingTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Receiving Messages

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                guard let webSocketTask = self.webSocketTask else { break }

                do {
                    let message = try await webSocketTask.receive()
                    self.handleMessage(message)
                } catch {
                    #if DEBUG
                    print("[WebSocket] Receive error: \(error.localizedDescription)")
                    #endif

                    if !Task.isCancelled {
                        await MainActor.run {
                            self.isConnected = false
                        }
                        self.scheduleReconnect()
                    }
                    break
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case .string(let text):
            guard let textData = text.data(using: .utf8) else { return }
            data = textData
        case .data(let binaryData):
            data = binaryData
        @unknown default:
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            #if DEBUG
            print("[WebSocket] Failed to parse message")
            #endif
            return
        }

        switch type {
        case "chat_message":
            handleChatMessage(json)
        case "typing_start":
            handleTypingStart(json)
        case "typing_stop":
            handleTypingStop(json)
        case "read_receipt":
            handleReadReceipt(json)
        case "presence":
            handlePresence(json)
        default:
            #if DEBUG
            print("[WebSocket] Unknown message type: \(type)")
            #endif
        }
    }

    // MARK: - Message Handlers

    private func handleChatMessage(_ json: [String: Any]) {
        #if DEBUG
        print("[WebSocket] Received chat message")
        #endif

        // チャットメッセージ受信を通知
        NotificationCenter.default.post(
            name: .chatMessageReceived,
            object: nil,
            userInfo: json
        )
    }

    private func handleTypingStart(_ json: [String: Any]) {
        guard let roomId = json["room_id"] as? String,
              let userId = json["user_id"] as? String else { return }

        var users = typingUsers[roomId] ?? []
        users.insert(userId)
        typingUsers[roomId] = users

        // タイピングインジケータの自動タイムアウト（5秒）
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if var current = typingUsers[roomId] {
                current.remove(userId)
                if current.isEmpty {
                    typingUsers.removeValue(forKey: roomId)
                } else {
                    typingUsers[roomId] = current
                }
            }
        }
    }

    private func handleTypingStop(_ json: [String: Any]) {
        guard let roomId = json["room_id"] as? String,
              let userId = json["user_id"] as? String else { return }

        if var users = typingUsers[roomId] {
            users.remove(userId)
            if users.isEmpty {
                typingUsers.removeValue(forKey: roomId)
            } else {
                typingUsers[roomId] = users
            }
        }
    }

    private func handleReadReceipt(_ json: [String: Any]) {
        #if DEBUG
        print("[WebSocket] Read receipt received")
        #endif
        // 既読通知をブロードキャスト
        NotificationCenter.default.post(
            name: .chatMessageReceived,
            object: nil,
            userInfo: json
        )
    }

    private func handlePresence(_ json: [String: Any]) {
        guard let userId = json["user_id"] as? String,
              let status = json["status"] as? String else { return }

        if status == "online" {
            onlineUsers.insert(userId)
        } else {
            onlineUsers.remove(userId)
        }

        #if DEBUG
        print("[WebSocket] Presence update: \(userId) is \(status)")
        #endif
    }

    // MARK: - Sending Messages

    func send(message: String, roomId: String) {
        let payload: [String: Any] = [
            "type": "chat_message",
            "room_id": roomId,
            "content": message
        ]
        sendJSON(payload)
    }

    func sendTypingStart(roomId: String) {
        let payload: [String: Any] = [
            "type": "typing_start",
            "room_id": roomId
        ]
        sendJSON(payload)
    }

    func sendTypingStop(roomId: String) {
        let payload: [String: Any] = [
            "type": "typing_stop",
            "room_id": roomId
        ]
        sendJSON(payload)
    }

    private func sendJSON(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            #if DEBUG
            print("[WebSocket] Failed to serialize message")
            #endif
            return
        }

        Task {
            do {
                try await webSocketTask?.send(.string(text))
            } catch {
                #if DEBUG
                print("[WebSocket] Send error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30秒
                guard !Task.isCancelled else { break }

                self?.webSocketTask?.sendPing(pongReceiveHandler: { [weak self] error in
                    if let error = error {
                        #if DEBUG
                        print("[WebSocket] Ping failed: \(error.localizedDescription)")
                        #endif
                        Task { @MainActor in
                            self?.isConnected = false
                        }
                        self?.scheduleReconnect()
                    } else {
                        #if DEBUG
                        print("[WebSocket] Ping sent")
                        #endif
                    }
                })
            }
        }
    }

    // MARK: - Reconnection (エクスポネンシャルバックオフ)

    private func scheduleReconnect() {
        guard !isManuallyDisconnected else { return }
        guard NetworkMonitor.shared.isConnected else {
            #if DEBUG
            print("[WebSocket] Offline, will reconnect when network returns")
            #endif
            return
        }

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self = self else { return }

            let delay = min(
                pow(2.0, Double(self.reconnectAttempts)),
                self.maxReconnectDelay
            )
            self.reconnectAttempts += 1

            #if DEBUG
            print("[WebSocket] Reconnecting in \(delay) seconds (attempt \(self.reconnectAttempts))")
            #endif

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled, !self.isManuallyDisconnected else { return }
            self.establishConnection()
        }
    }

    // MARK: - Network Monitoring

    /// ネットワーク状態の変化を監視して再接続を管理
    private func observeNetworkChanges() {
        networkObserverTask = Task { [weak self] in
            var wasConnected = NetworkMonitor.shared.isConnected

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self = self else { break }

                let isNetworkConnected = NetworkMonitor.shared.isConnected

                if !wasConnected && isNetworkConnected && !self.isManuallyDisconnected {
                    // ネットワーク復旧 → 再接続
                    #if DEBUG
                    print("[WebSocket] Network restored, reconnecting...")
                    #endif
                    self.reconnectAttempts = 0
                    self.establishConnection()
                } else if wasConnected && !isNetworkConnected {
                    // ネットワーク切断
                    #if DEBUG
                    print("[WebSocket] Network lost")
                    #endif
                    self.isConnected = false
                }

                wasConnected = isNetworkConnected
            }
        }
    }
}
