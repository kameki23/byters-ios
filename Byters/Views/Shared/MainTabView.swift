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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadSidebarView
            } else {
                iPhoneTabView
            }
        }
        .tint(.blue)
        .task {
            await notificationManager.loadUnreadCount()
            await notificationManager.loadChatUnreadCount()
        }
    }

    // MARK: - iPhone TabView

    private var iPhoneTabView: some View {
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
    }

    // MARK: - iPad Sidebar Navigation

    private var iPadSidebarView: some View {
        NavigationSplitView {
            List {
                sidebarButton(tab: .home, title: "ホーム", icon: "house.fill")
                sidebarButton(tab: .search, title: "検索", icon: "magnifyingglass")
                sidebarButton(tab: .work, title: "お仕事", icon: "briefcase.fill")
                sidebarButton(tab: .chat, title: "チャット", icon: "message.fill", badge: notificationManager.chatUnreadCount)
                sidebarButton(tab: .mypage, title: "マイページ", icon: "person.fill", badge: notificationManager.unreadCount)
            }
            .navigationTitle("Byters")
        } detail: {
            jobSeekerDetailView(for: appState.selectedTab)
        }
    }

    private func sidebarButton(tab: AppState.Tab, title: String, icon: String, badge: Int = 0) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
        }
        .listRowBackground(appState.selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    @ViewBuilder
    private func jobSeekerDetailView(for tab: AppState.Tab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .search:
            JobSearchView()
        case .work:
            WorkView()
        case .chat:
            ChatListView()
        case .mypage:
            MyPageView()
        }
    }
}

// MARK: - Employer Tab View

struct EmployerTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadSidebarView
            } else {
                iPhoneTabView
            }
        }
        .tint(.blue)
        .task {
            await notificationManager.loadUnreadCount()
            await notificationManager.loadChatUnreadCount()
        }
    }

    // MARK: - iPhone TabView

    private var iPhoneTabView: some View {
        TabView(selection: $appState.selectedTab) {
            EmployerDashboardView()
                .tabItem {
                    Label("ダッシュボード", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppState.Tab.home)
                .accessibilityLabel("ダッシュボードタブ")

            EmployerJobsView()
                .tabItem {
                    Label("求人管理", systemImage: "doc.text.fill")
                }
                .tag(AppState.Tab.search)
                .accessibilityLabel("求人管理タブ")

            EmployerApplicationsView()
                .tabItem {
                    Label("応募者", systemImage: "person.2.fill")
                }
                .tag(AppState.Tab.work)
                .accessibilityLabel("応募者管理タブ")

            ChatListView()
                .tabItem {
                    Label("メッセージ", systemImage: "message.fill")
                }
                .tag(AppState.Tab.chat)
                .badge(notificationManager.chatUnreadCount)
                .accessibilityLabel("メッセージタブ")

            EmployerSettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.mypage)
                .badge(notificationManager.unreadCount)
                .accessibilityLabel("設定タブ")
        }
    }

    // MARK: - iPad Sidebar Navigation

    private var iPadSidebarView: some View {
        NavigationSplitView {
            List {
                employerSidebarButton(tab: .home, title: "ダッシュボード", icon: "square.grid.2x2.fill")
                employerSidebarButton(tab: .search, title: "求人管理", icon: "doc.text.fill")
                employerSidebarButton(tab: .work, title: "応募者", icon: "person.2.fill")
                employerSidebarButton(tab: .chat, title: "メッセージ", icon: "message.fill", badge: notificationManager.chatUnreadCount)
                employerSidebarButton(tab: .mypage, title: "設定", icon: "gearshape.fill", badge: notificationManager.unreadCount)
            }
            .navigationTitle("Byters")
        } detail: {
            employerDetailView(for: appState.selectedTab)
        }
    }

    private func employerSidebarButton(tab: AppState.Tab, title: String, icon: String, badge: Int = 0) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
        }
        .listRowBackground(appState.selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    @ViewBuilder
    private func employerDetailView(for tab: AppState.Tab) -> some View {
        switch tab {
        case .home:
            EmployerDashboardView()
        case .search:
            EmployerJobsView()
        case .work:
            EmployerApplicationsView()
        case .chat:
            ChatListView()
        case .mypage:
            EmployerSettingsView()
        }
    }
}

// MARK: - Admin Tab View

struct AdminTabView: View {
    @State private var selectedTab = 0
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadSidebarView
            } else {
                iPhoneTabView
            }
        }
        .tint(.blue)
        .task {
            await notificationManager.loadUnreadCount()
        }
    }

    // MARK: - iPhone TabView

    private var iPhoneTabView: some View {
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
    }

    // MARK: - iPad Sidebar Navigation

    private var iPadSidebarView: some View {
        NavigationSplitView {
            List {
                Section("メイン") {
                    adminSidebarButton(tag: 0, title: "ダッシュボード", icon: "chart.bar.fill")
                    adminSidebarButton(tag: 1, title: "ユーザー管理", icon: "person.3.fill")
                    adminSidebarButton(tag: 2, title: "求人管理", icon: "briefcase.fill")
                    adminSidebarButton(tag: 3, title: "通知", icon: "bell.fill", badge: notificationManager.unreadCount)
                }

                Section("審査管理") {
                    adminSidebarButton(tag: 10, title: "出金申請", icon: "arrow.down.circle")
                    adminSidebarButton(tag: 11, title: "本人確認審査", icon: "person.text.rectangle")
                    adminSidebarButton(tag: 12, title: "資格審査", icon: "graduationcap.fill")
                    adminSidebarButton(tag: 13, title: "通報・問い合わせ", icon: "exclamationmark.bubble")
                    adminSidebarButton(tag: 14, title: "紛争解決キュー", icon: "arrow.triangle.2.circlepath")
                }

                Section("収益管理") {
                    adminSidebarButton(tag: 20, title: "収益ウォレット", icon: "yensign.circle.fill")
                    adminSidebarButton(tag: 21, title: "銀行口座管理", icon: "building.columns.fill")
                    adminSidebarButton(tag: 22, title: "プラットフォーム出金", icon: "arrow.up.circle.fill")
                }

                Section("通知・マーケティング") {
                    adminSidebarButton(tag: 30, title: "一斉通知", icon: "bell.badge.fill")
                    adminSidebarButton(tag: 31, title: "バナー管理", icon: "photo.fill")
                    adminSidebarButton(tag: 32, title: "広告設定", icon: "megaphone.fill")
                    adminSidebarButton(tag: 33, title: "コンテンツ編集", icon: "doc.richtext")
                }

                Section("システム設定") {
                    adminSidebarButton(tag: 40, title: "手数料設定", icon: "percent")
                    adminSidebarButton(tag: 41, title: "出金設定", icon: "banknote")
                    adminSidebarButton(tag: 42, title: "通知設定", icon: "bell.fill")
                    adminSidebarButton(tag: 43, title: "カテゴリ管理", icon: "folder.fill")
                    adminSidebarButton(tag: 44, title: "オプション機能", icon: "switch.2")
                    adminSidebarButton(tag: 45, title: "本人確認設定", icon: "shield.checkered")
                }

                Section("分析・開発") {
                    adminSidebarButton(tag: 50, title: "アナリティクス", icon: "chart.bar.fill")
                    adminSidebarButton(tag: 51, title: "データエクスポート", icon: "square.and.arrow.up")
                    adminSidebarButton(tag: 52, title: "セキュリティ", icon: "lock.shield")
                    adminSidebarButton(tag: 53, title: "APIキー管理", icon: "key.fill")
                }

                Section {
                    adminSidebarButton(tag: 99, title: "設定・ログアウト", icon: "gearshape.fill")
                }
            }
            .navigationTitle("管理画面")
        } detail: {
            adminDetailView(for: selectedTab)
        }
    }

    private func adminSidebarButton(tag: Int, title: String, icon: String, badge: Int = 0) -> some View {
        Button {
            selectedTab = tag
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
        }
        .listRowBackground(selectedTab == tag ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    @ViewBuilder
    private func adminDetailView(for tab: Int) -> some View {
        switch tab {
        // メイン
        case 0:
            AdminDashboardView()
        case 1:
            AdminUsersView()
        case 2:
            AdminJobsView()
        case 3:
            NavigationStack { NotificationListView() }
        // 審査管理
        case 10:
            NavigationStack { AdminWithdrawalsView() }
        case 11:
            NavigationStack { AdminIdentityVerificationsView() }
        case 12:
            NavigationStack { AdminQualificationsView() }
        case 13:
            NavigationStack { AdminReportsView() }
        case 14:
            NavigationStack { AdminDisputesView() }
        // 収益管理
        case 20:
            NavigationStack { AdminRevenueWalletView() }
        case 21:
            NavigationStack { AdminPlatformBankAccountView() }
        case 22:
            NavigationStack { AdminPlatformWithdrawalView() }
        // 通知・マーケティング
        case 30:
            NavigationStack { AdminMassNotificationsView() }
        case 31:
            NavigationStack { AdminBannersView() }
        case 32:
            NavigationStack { AdminAdsView() }
        case 33:
            NavigationStack { AdminCMSContentView() }
        // システム設定
        case 40:
            NavigationStack { AdminFeeSettingsView() }
        case 41:
            NavigationStack { AdminWithdrawalSettingsView() }
        case 42:
            NavigationStack { AdminNotificationSettingsView() }
        case 43:
            NavigationStack { AdminCategoryManagementView() }
        case 44:
            NavigationStack { AdminOptionalFeaturesView() }
        case 45:
            NavigationStack { AdminKycSettingsView() }
        // 分析・開発
        case 50:
            NavigationStack { AdminAnalyticsView() }
        case 51:
            NavigationStack { AdminDataExportView() }
        case 52:
            NavigationStack { AdminSecurityView() }
        case 53:
            NavigationStack { AdminAPIKeysView() }
        // 設定
        case 99:
            AdminSettingsView()
        default:
            AdminDashboardView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(AppState())
}
