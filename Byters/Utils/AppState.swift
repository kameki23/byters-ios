import Foundation
import SwiftUI

enum DeepLinkTarget: Equatable {
    case job(jobId: String)
    case chat(roomId: String?)
    case notifications
    case mypage
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var selectedTab: Tab = .home  // Default to Home for logged in users
    @Published var isShowingJobDetail: Bool = false
    @Published var selectedJobId: String?
    @Published var justLoggedIn: Bool = false  // Flag to trigger navigation after login
    @Published var pendingDeepLink: DeepLinkTarget?

    /// 0 = system, 1 = light, 2 = dark
    /// Using a separate backing store to avoid publishing changes for every didSet
    private var _appearanceMode: Int

    var appearanceMode: Int {
        get { _appearanceMode }
        set {
            guard _appearanceMode != newValue else { return }
            _appearanceMode = newValue
            UserDefaults.standard.set(newValue, forKey: "appearance_mode")
            objectWillChange.send()
        }
    }

    var colorScheme: ColorScheme? {
        switch _appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    init() {
        self._appearanceMode = UserDefaults.standard.integer(forKey: "appearance_mode")
    }

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

    /// Navigate to the default page based on user type
    /// Job seekers → Home (トップページ), Employers → Home (ダッシュボード)
    func navigateToDefaultPage(userType: UserType?) {
        switch userType {
        case .jobSeeker:
            selectedTab = .home
        case .employer:
            selectedTab = .home  // Employer uses its own tab view, this won't conflict
        default:
            selectedTab = .home
        }
        justLoggedIn = false
    }

    func handleDeepLink(_ target: DeepLinkTarget) {
        switch target {
        case .job(let jobId):
            navigateToJobDetail(jobId: jobId)
        case .chat:
            selectedTab = .chat
        case .notifications:
            selectedTab = .mypage
        case .mypage:
            selectedTab = .mypage
        }
        pendingDeepLink = nil
    }

    func onLoginSuccess(userType: UserType? = nil) {
        justLoggedIn = true
        switch userType {
        case .jobSeeker:
            selectedTab = .home
        case .employer:
            selectedTab = .home
        default:
            selectedTab = .home
        }
    }
}
