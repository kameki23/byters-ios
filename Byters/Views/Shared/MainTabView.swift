import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            // Check isAdmin flag first (for secret admin login)
            if authManager.isAdmin {
                AdminTabView()
            } else {
                switch authManager.userType {
                case .jobSeeker:
                    JobSeekerTabView()
                case .employer:
                    EmployerTabView()
                case .admin:
                    AdminTabView()
                case .none:
                    JobSeekerTabView() // Default
                }
            }
        }
    }
}

// MARK: - Job Seeker Tab View

struct JobSeekerTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(AppState.Tab.home)
                .accessibilityLabel("ホームタブ")

            JobSearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }
                .tag(AppState.Tab.search)
                .accessibilityLabel("求人検索タブ")

            WorkView()
                .tabItem {
                    Label("お仕事", systemImage: "briefcase.fill")
                }
                .tag(AppState.Tab.work)
                .accessibilityLabel("お仕事タブ")

            ChatListView()
                .tabItem {
                    Label("チャット", systemImage: "message.fill")
                }
                .tag(AppState.Tab.chat)
                .badge(notificationManager.chatUnreadCount)
                .accessibilityLabel("チャットタブ")

            MyPageView()
                .tabItem {
                    Label("マイページ", systemImage: "person.fill")
                }
                .tag(AppState.Tab.mypage)
                .badge(notificationManager.unreadCount)
                .accessibilityLabel("マイページタブ")
        }
        .tint(.blue)
        .task {
            await notificationManager.loadUnreadCount()
            await notificationManager.loadChatUnreadCount()
        }
    }
}

// MARK: - Employer Tab View

struct EmployerTabView: View {
    @State private var selectedTab = 0
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            EmployerDashboardView()
                .tabItem {
                    Label("ダッシュボード", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            EmployerJobsView()
                .tabItem {
                    Label("求人管理", systemImage: "doc.text.fill")
                }
                .tag(1)

            EmployerApplicationsView()
                .tabItem {
                    Label("応募者", systemImage: "person.2.fill")
                }
                .tag(2)

            ChatListView()
                .tabItem {
                    Label("メッセージ", systemImage: "message.fill")
                }
                .tag(3)
                .badge(notificationManager.chatUnreadCount)

            EmployerSettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(4)
                .badge(notificationManager.unreadCount)
        }
        .tint(.blue)
        .task {
            await notificationManager.loadUnreadCount()
            await notificationManager.loadChatUnreadCount()
        }
    }
}

// MARK: - Admin Tab View

struct AdminTabView: View {
    @State private var selectedTab = 0
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDashboardView()
                .tabItem {
                    Label("ダッシュボード", systemImage: "chart.bar.fill")
                }
                .tag(0)

            AdminUsersView()
                .tabItem {
                    Label("ユーザー", systemImage: "person.3.fill")
                }
                .tag(1)

            AdminJobsView()
                .tabItem {
                    Label("求人", systemImage: "briefcase.fill")
                }
                .tag(2)

            NavigationStack {
                NotificationListView()
            }
            .tabItem {
                Label("通知", systemImage: "bell.fill")
            }
            .tag(3)
            .badge(notificationManager.unreadCount)

            AdminSettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.blue)
        .task {
            await notificationManager.loadUnreadCount()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(AppState())
}
