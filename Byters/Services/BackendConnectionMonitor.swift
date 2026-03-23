import Foundation
import SwiftUI

/// バックエンドとの接続状態を常時監視し、フロントエンドとバックエンドの連携を保証するサービス
@MainActor
class BackendConnectionMonitor: ObservableObject {
    static let shared = BackendConnectionMonitor()

    /// バックエンドへの接続が確認されているか
    @Published var isBackendReachable = true
    /// バックエンドのステータス（正常/メンテナンス等）
    @Published var backendStatus: BackendStatus = .connected
    /// 最後に接続確認した時刻
    @Published var lastHealthCheckAt: Date?
    /// APIバージョンの不整合が検出されたか
    @Published var requiresAppUpdate = false

    private var healthCheckTask: Task<Void, Never>?
    private let healthCheckInterval: TimeInterval = 60 // 60秒ごとにチェック
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    enum BackendStatus: Equatable {
        case connected
        case disconnected
        case maintenance(estimatedEnd: String?)
        case degraded
    }

    private init() {}

    // MARK: - 監視開始/停止

    /// アプリ起動時またはフォアグラウンド復帰時に呼ぶ
    func startMonitoring() {
        stopMonitoring()
        healthCheckTask = Task { [weak self] in
            guard let self else { return }

            // 初回チェック
            await self.performHealthCheck()

            // 定期チェック
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.healthCheckInterval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self.performHealthCheck()
            }
        }
    }

    /// バックグラウンド移行時に停止
    func stopMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    // MARK: - ヘルスチェック

    /// バックエンドのヘルスチェックを実行
    func performHealthCheck() async {
        // ネットワーク自体が切れている場合はスキップ
        guard NetworkMonitor.shared.isConnected else {
            isBackendReachable = false
            backendStatus = .disconnected
            return
        }

        do {
            let health: HealthStatus = try await APIClient.shared.getHealthStatus()
            lastHealthCheckAt = Date()

            if health.status == "maintenance" {
                isBackendReachable = false
                backendStatus = .maintenance(estimatedEnd: health.estimatedEndTime)
            } else if health.status == "degraded" {
                isBackendReachable = true
                backendStatus = .degraded
            } else {
                isBackendReachable = true
                backendStatus = .connected
            }

            // APIバージョン互換性チェック
            if let serverVersion = health.version {
                checkVersionCompatibility(serverVersion: serverVersion)
            }

            #if DEBUG
            print("[BackendMonitor] Health OK: status=\(health.status), version=\(health.version ?? "unknown")")
            #endif

        } catch let error as APIError {
            lastHealthCheckAt = Date()

            switch error {
            case .maintenance:
                isBackendReachable = false
                backendStatus = .maintenance(estimatedEnd: nil)
            case .offline:
                isBackendReachable = false
                backendStatus = .disconnected
            default:
                // サーバーエラーやタイムアウトでも到達不能とする
                isBackendReachable = false
                backendStatus = .disconnected
            }

            #if DEBUG
            print("[BackendMonitor] Health check failed: \(error.localizedDescription)")
            #endif

        } catch {
            isBackendReachable = false
            backendStatus = .disconnected

            #if DEBUG
            print("[BackendMonitor] Health check error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - バージョン互換性

    private func checkVersionCompatibility(serverVersion: String) {
        // サーバーがサポートする最小クライアントバージョンを確認
        // フォーマット例: "1.0" → メジャー.マイナー
        let serverComponents = serverVersion.split(separator: ".").compactMap { Int($0) }
        let appComponents = appVersion.split(separator: ".").compactMap { Int($0) }

        guard serverComponents.count >= 1, appComponents.count >= 1 else { return }

        // メジャーバージョンが異なる場合はアップデート必須
        if serverComponents[0] > appComponents[0] {
            requiresAppUpdate = true
        }
    }

    // MARK: - 再接続

    /// 手動で再接続を試みる
    func retryConnection() async {
        await performHealthCheck()

        // 接続復旧時にWebSocketも再接続
        if isBackendReachable && AuthManager.shared.isAuthenticated {
            if KeychainHelper.load(key: "auth_token") != nil {
                WebSocketManager.shared.connect()
            }
            // オフラインキューの処理
            if OfflineQueueManager.shared.pendingCount > 0 {
                await OfflineQueueManager.shared.processQueue()
            }
        }
    }
}

// MARK: - バックエンド接続バナー

struct BackendStatusBannerModifier: ViewModifier {
    @StateObject private var monitor = BackendConnectionMonitor.shared

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            switch monitor.backendStatus {
            case .maintenance(let estimatedEnd):
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("メンテナンス中です")
                            .font(.caption)
                            .fontWeight(.semibold)
                        if let end = estimatedEnd {
                            Text("終了予定: \(end)")
                                .font(.caption2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.yellow)
                .foregroundColor(.black)

            case .disconnected:
                if NetworkMonitor.shared.isConnected {
                    // ネットワークはあるがバックエンドに到達不能
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("サーバーに接続中...")
                            .font(.caption)
                        Spacer()
                        Button("再試行") {
                            Task { await monitor.retryConnection() }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.9))
                    .foregroundColor(.white)
                }

            case .degraded:
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("一部のサービスが不安定です")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.8))
                .foregroundColor(.white)

            case .connected:
                EmptyView()
            }

            if monitor.requiresAppUpdate {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.caption)
                    Text("新しいバージョンが利用可能です。アップデートしてください。")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
            }

            content
        }
        .animation(.easeInOut(duration: 0.3), value: monitor.backendStatus)
    }
}

extension View {
    func backendStatusBanner() -> some View {
        modifier(BackendStatusBannerModifier())
    }
}
