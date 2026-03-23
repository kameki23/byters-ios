import Foundation
import SwiftUI

/// バックエンドとの接続状態をバックグラウンドで監視するサービス
/// UIをブロックせず、連続失敗時のみバナーを表示する
@MainActor
class BackendConnectionMonitor: ObservableObject {
    static let shared = BackendConnectionMonitor()

    /// バックエンドへの接続が確認されているか
    @Published var isBackendReachable = true
    /// メンテナンス中かどうか
    @Published var isMaintenanceMode = false
    /// メンテナンス終了予定
    @Published var maintenanceEndTime: String?
    /// APIバージョンの不整合が検出されたか
    @Published var requiresAppUpdate = false

    private var healthCheckTask: Task<Void, Never>?
    private let healthCheckInterval: TimeInterval = 120 // 2分ごと（軽量化）
    private var consecutiveFailures = 0
    private let failureThreshold = 3 // 3回連続失敗でバナー表示

    private init() {}

    // MARK: - 監視開始/停止

    func startMonitoring() {
        stopMonitoring()
        healthCheckTask = Task(priority: .utility) { [weak self] in
            // 初回は5秒後（起動直後のUIを邪魔しない）
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.performHealthCheck()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.healthCheckInterval ?? 120) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.performHealthCheck()
            }
        }
    }

    func stopMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    // MARK: - ヘルスチェック（軽量・非ブロッキング）

    private func performHealthCheck() async {
        guard NetworkMonitor.shared.isConnected else {
            // ネットワーク切断はNetworkMonitor/OfflineBannerに任せる
            return
        }

        do {
            let health: HealthStatus = try await APIClient.shared.getHealthStatus()

            // 成功 → カウンターリセット
            consecutiveFailures = 0
            isBackendReachable = true

            if health.status == "maintenance" {
                isMaintenanceMode = true
                maintenanceEndTime = health.estimatedEndTime
            } else {
                isMaintenanceMode = false
                maintenanceEndTime = nil
            }

            // バージョンチェック
            if let serverVersion = health.version {
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                let serverMajor = serverVersion.split(separator: ".").first.flatMap { Int($0) } ?? 0
                let appMajor = appVersion.split(separator: ".").first.flatMap { Int($0) } ?? 0
                requiresAppUpdate = serverMajor > appMajor
            }

        } catch {
            consecutiveFailures += 1
            // 閾値を超えた場合のみ到達不能とマーク
            if consecutiveFailures >= failureThreshold {
                isBackendReachable = false
            }
            // それ以下の失敗は無視（一時的なネットワーク揺れ）
            #if DEBUG
            print("[BackendMonitor] Check failed (\(consecutiveFailures)/\(failureThreshold)): \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - 手動再接続

    func retryConnection() async {
        consecutiveFailures = 0
        isBackendReachable = true
        await performHealthCheck()

        if isBackendReachable && AuthManager.shared.isAuthenticated {
            if KeychainHelper.load(key: "auth_token") != nil {
                WebSocketManager.shared.connect()
            }
            if OfflineQueueManager.shared.pendingCount > 0 {
                await OfflineQueueManager.shared.processQueue()
            }
        }
    }
}
