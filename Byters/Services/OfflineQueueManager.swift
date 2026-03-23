import Foundation
import Network

// MARK: - Offline Queue Manager
// オフライン時のAPIリクエストをキューに保存し、接続復旧時に再送

@MainActor
class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()

    @Published var pendingCount: Int = 0

    private var queue: [QueuedRequest] = []
    private let maxQueueSize = 100
    private let maxRetries = 3
    private var isProcessing = false
    private var networkObserverTask: Task<Void, Never>?

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// キューの永続化ファイルパス
    private var queueFileURL: URL {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return documentsDir.appendingPathComponent("offline_queue.json")
    }

    private init() {
        loadQueueFromDisk()
        // ネットワーク監視はenqueue時に遅延開始（起動時のシングルトン連鎖を防ぐ）
    }

    // MARK: - Public API

    /// オフラインキューにリクエストを追加
    func enqueue(endpoint: String, method: String, body: Data? = nil, idempotencyKey: String? = nil) {
        // 初回enqueue時にネットワーク監視を開始
        if networkObserverTask == nil {
            observeNetworkChanges()
        }
        guard queue.count < maxQueueSize else {
            #if DEBUG
            print("[OfflineQueue] Queue is full (\(maxQueueSize)), dropping request: \(method) \(endpoint)")
            #endif
            return
        }

        let request = QueuedRequest(
            id: UUID(),
            endpoint: endpoint,
            method: method,
            body: body,
            idempotencyKey: idempotencyKey,
            createdAt: Date(),
            retryCount: 0
        )

        queue.append(request)
        pendingCount = queue.count
        saveQueueToDisk()

        #if DEBUG
        print("[OfflineQueue] Enqueued: \(method) \(endpoint) (pending: \(pendingCount))")
        #endif

        // オンラインなら即時処理を試みる
        if NetworkMonitor.shared.isConnected {
            Task { await processQueue() }
        }
    }

    /// キュー内のリクエストを順番に再送
    func processQueue() async {
        guard !isProcessing else { return }
        guard !queue.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else {
            #if DEBUG
            print("[OfflineQueue] Offline, skipping queue processing")
            #endif
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        #if DEBUG
        print("[OfflineQueue] Processing queue (\(queue.count) requests)")
        #endif

        // キューのコピーを作成して順番に処理
        var remainingRequests: [QueuedRequest] = []

        for var request in queue {
            guard NetworkMonitor.shared.isConnected else {
                // 処理中にオフラインになった場合、残りを保持
                remainingRequests.append(request)
                continue
            }

            do {
                try await replayRequest(request)
                #if DEBUG
                print("[OfflineQueue] Successfully replayed: \(request.method) \(request.endpoint)")
                #endif
            } catch {
                request.retryCount += 1

                if request.retryCount < maxRetries {
                    // エクスポネンシャルバックオフ
                    let delay = UInt64(pow(2.0, Double(request.retryCount))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    remainingRequests.append(request)

                    #if DEBUG
                    print("[OfflineQueue] Retry \(request.retryCount)/\(maxRetries) for: \(request.method) \(request.endpoint)")
                    #endif
                } else {
                    #if DEBUG
                    print("[OfflineQueue] Dropped after \(maxRetries) retries: \(request.method) \(request.endpoint)")
                    #endif
                }
            }
        }

        queue = remainingRequests
        pendingCount = queue.count
        saveQueueToDisk()
    }

    /// キューを全てクリア
    func clearQueue() {
        queue.removeAll()
        pendingCount = 0
        saveQueueToDisk()

        #if DEBUG
        print("[OfflineQueue] Queue cleared")
        #endif
    }

    // MARK: - Request Replay

    private func replayRequest(_ request: QueuedRequest) async throws {
        // APIClientの汎用リクエストメソッドを使用して再送
        let bodyDict: [String: Any]?

        if let body = request.body {
            bodyDict = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        } else {
            bodyDict = nil
        }

        // 24時間以上前のリクエストは期限切れとして破棄
        if Date().timeIntervalSince(request.createdAt) > 86400 {
            #if DEBUG
            print("[OfflineQueue] Expired request dropped: \(request.method) \(request.endpoint)")
            #endif
            return
        }

        let _: SimpleResponse = try await APIClient.shared.request(
            endpoint: request.endpoint,
            method: request.method,
            body: bodyDict,
            idempotencyKey: request.idempotencyKey
        )
    }

    // MARK: - Persistence (ディスク永続化)

    private func saveQueueToDisk() {
        Task.detached(priority: .utility) { [queue, encoder, queueFileURL] in
            do {
                let data = try encoder.encode(queue)
                try data.write(to: queueFileURL, options: .atomic)
            } catch {
                #if DEBUG
                print("[OfflineQueue] Failed to save queue: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func loadQueueFromDisk() {
        do {
            let data = try Data(contentsOf: queueFileURL)
            queue = try decoder.decode([QueuedRequest].self, from: data)
            pendingCount = queue.count

            #if DEBUG
            print("[OfflineQueue] Loaded \(queue.count) requests from disk")
            #endif
        } catch {
            // ファイルが存在しない場合は正常（初回起動時）
            queue = []
            pendingCount = 0
        }
    }

    // MARK: - Network Monitoring

    /// ネットワーク復旧時にキューを自動処理
    private func observeNetworkChanges() {
        networkObserverTask = Task { [weak self] in
            var wasConnected = NetworkMonitor.shared.isConnected

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self = self else { break }

                let isNowConnected = NetworkMonitor.shared.isConnected

                if !wasConnected && isNowConnected && !self.queue.isEmpty {
                    #if DEBUG
                    print("[OfflineQueue] Network restored, processing queue...")
                    #endif
                    await self.processQueue()
                }

                wasConnected = isNowConnected
            }
        }
    }
}

// MARK: - Queued Request Model

struct QueuedRequest: Codable, Identifiable {
    let id: UUID
    let endpoint: String
    let method: String
    let body: Data?
    let idempotencyKey: String?
    let createdAt: Date
    var retryCount: Int
}

