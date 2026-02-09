import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .mypage  // Default to MyPage for logged in users
    @Published var isShowingJobDetail: Bool = false
    @Published var selectedJobId: String?
    @Published var justLoggedIn: Bool = false  // Flag to trigger MyPage navigation after login

    enum Tab: Int, CaseIterable {
        case home = 0
        case search = 1
        case work = 2
        case chat = 3
        case mypage = 4

        var title: String {
            switch self {
            case .home: return "ホーム"
            case .search: return "検索"
            case .work: return "お仕事"
            case .chat: return "チャット"
            case .mypage: return "マイページ"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .work: return "briefcase.fill"
            case .chat: return "message.fill"
            case .mypage: return "person.fill"
            }
        }
    }

    func navigateToJobDetail(jobId: String) {
        selectedJobId = jobId
        isShowingJobDetail = true
    }

    func navigateToMyPage() {
        selectedTab = .mypage
        justLoggedIn = false
    }

    func onLoginSuccess() {
        justLoggedIn = true
        selectedTab = .mypage
    }
}
