import AppTrackingTransparency
import SwiftUI

@MainActor
final class TrackingTransparencyManager: ObservableObject {
    static let shared = TrackingTransparencyManager()

    @Published var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published var hasRequestedPermission: Bool = false

    private init() {
        hasRequestedPermission = UserDefaults.standard.bool(forKey: "att_requested")
        // trackingAuthorizationStatusは安全にアクセス可能
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus
    }

    /// Request tracking permission. Should be called after app launch delay.
    func requestPermission() async {
        guard !hasRequestedPermission else { return }

        // アプリが完全にアクティブになるまで待機（Apple審査ガイドライン準拠）
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // アプリがフォアグラウンドであることを確認
        guard UIApplication.shared.applicationState == .active else { return }

        let status = await ATTrackingManager.requestTrackingAuthorization()
        trackingStatus = status
        hasRequestedPermission = true
        UserDefaults.standard.set(true, forKey: "att_requested")

        switch status {
        case .authorized:
            AnalyticsService.shared.track("att_authorized")
        case .denied:
            AnalyticsService.shared.track("att_denied")
        default:
            break
        }

        #if DEBUG
        print("[ATT] Tracking authorization status: \(status.rawValue)")
        #endif
    }

    var isTrackingAllowed: Bool {
        trackingStatus == .authorized
    }
}
