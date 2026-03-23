import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else {
                    self?.connectionType = nil
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

struct OfflineBannerModifier: ViewModifier {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showReconnected = false
    @State private var pendingCount = 0

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text(pendingCount > 0
                         ? "オフラインです（\(pendingCount)件の操作を保留中）"
                         : "オフラインです。ネットワーク接続を確認してください。")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange)
                .foregroundColor(.white)
            } else if showReconnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.caption)
                    Text("接続が復旧しました")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green)
                .foregroundColor(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            content
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.3), value: showReconnected)
        .onChange(of: networkMonitor.isConnected) { wasConnected, isNowConnected in
            if !wasConnected && isNowConnected {
                showReconnected = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showReconnected = false
                }
                // オフラインキューの処理を再開（保留中のリクエストがある場合のみ）
                if OfflineQueueManager.shared.pendingCount > 0 {
                    Task {
                        await OfflineQueueManager.shared.processQueue()
                    }
                }
            }
        }
    }
}

extension View {
    func offlineBanner() -> some View {
        modifier(OfflineBannerModifier())
    }
}
