import SwiftUI

// MARK: - Admin Dashboard

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // Overview Stats
                        VStack(alignment: .leading, spacing: 16) {
                            Text("概要")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                AdminStatCard(
                                    title: "総ユーザー",
                                    value: "\(viewModel.stats?.totalUsers ?? 0)",
                                    icon: "person.3.fill",
                                    color: .blue
                                )
                                AdminStatCard(
                                    title: "求人数",
                                    value: "\(viewModel.stats?.totalJobs ?? 0)",
                                    icon: "briefcase.fill",
                                    color: .green
                                )
                                AdminStatCard(
                                    title: "今月の売上",
                                    value: "¥\(formatNumber(viewModel.stats?.thisMonthRevenue ?? 0))",
                                    icon: "yensign.circle.fill",
                                    color: .orange
                                )
                                AdminStatCard(
                                    title: "出金申請",
                                    value: "\(viewModel.stats?.pendingWithdrawals ?? 0)",
                                    icon: "arrow.down.circle.fill",
                                    color: .purple
                                )
                            }
                            .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                AdminStatCard(
                                    title: "本人確認待ち",
                                    value: "\(viewModel.stats?.pendingIdentityVerifications ?? 0)",
                                    icon: "person.text.rectangle",
                                    color: .red
                                )
                                AdminStatCard(
                                    title: "今月の新規登録",
                                    value: "\(viewModel.stats?.thisMonthNewUsers ?? 0)",
                                    icon: "person.badge.plus",
                                    color: .teal
                                )
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                            .padding(.horizontal)

                        // Quick Actions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("クイックアクション")
                                .font(.headline)
                                .padding(.horizontal)

                            HStack(spacing: 12) {
                                QuickActionButton(
                                    icon: "arrow.down.circle",
                                    title: "出金処理",
                                    color: .orange
                                ) {
                                    viewModel.showWithdrawals = true
                                }

                                QuickActionButton(
                                    icon: "person.text.rectangle",
                                    title: "本人確認",
                                    color: .purple
                                ) {
                                    viewModel.showIdentityVerifications = true
                                }

                                QuickActionButton(
                                    icon: "doc.badge.clock",
                                    title: "求人審査",
                                    color: .blue
                                ) {
                                    viewModel.showPendingJobs = true
                                }
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                            .padding(.horizontal)

                        // Recent Activity
                        VStack(alignment: .leading, spacing: 16) {
                            Text("最近のアクティビティ")
                                .font(.headline)
                                .padding(.horizontal)

                            if viewModel.activities.isEmpty {
                                Text("アクティビティがありません")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.activities.prefix(5)) { activity in
                                        ActivityRow(activity: activity)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("管理画面")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $viewModel.showWithdrawals) {
                AdminWithdrawalsSheet()
            }
            .sheet(isPresented: $viewModel.showIdentityVerifications) {
                AdminIdentityVerificationsSheet()
            }
            .sheet(isPresented: $viewModel.showPendingJobs) {
                AdminPendingJobsSheet()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }
}

@MainActor
class AdminDashboardViewModel: ObservableObject {
    @Published var stats: AdminDashboardStats?
    @Published var activities: [AdminActivity] = []
    @Published var isLoading = true
    @Published var showWithdrawals = false
    @Published var showIdentityVerifications = false
    @Published var showPendingJobs = false

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStats() }
            group.addTask { await self.loadActivities() }
        }
        isLoading = false
    }

    func loadStats() async {
        do {
            stats = try await api.getAdminDashboardStats()
        } catch {
            print("Failed to load admin stats: \(error)")
        }
    }

    func loadActivities() async {
        do {
            activities = try await api.getAdminRecentActivity()
        } catch {
            print("Failed to load admin activities: \(error)")
        }
    }

    func refresh() async {
        await loadData()
    }
}

struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ActivityRow: View {
    let activity: AdminActivity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.iconName)
                .foregroundColor(colorFromString(activity.iconColor))
                .frame(width: 40, height: 40)
                .background(colorFromString(activity.iconColor).opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let detail = activity.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if let createdAt = activity.createdAt {
                Text(formatTimeAgo(createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "teal": return .teal
        default: return .gray
        }
    }

    private func formatTimeAgo(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "たった今"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))時間前"
        } else {
            return "\(Int(interval / 86400))日前"
        }
    }
}

// MARK: - Admin Users

struct AdminUsersView: View {
    @StateObject private var viewModel = AdminUsersViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search & Filter
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("ユーザー検索", text: $viewModel.searchText)
                            .onChange(of: viewModel.searchText) { _, _ in
                                viewModel.searchDebounced()
                            }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Picker("フィルター", selection: $viewModel.selectedFilter) {
                        Text("全て").tag("all")
                        Text("求職者").tag("job_seeker")
                        Text("事業者").tag("employer")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedFilter) { _, _ in
                        Task { await viewModel.loadUsers() }
                    }
                }
                .padding(.vertical)

                // User List
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.users.isEmpty {
                    Text("ユーザーが見つかりません")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.users) { user in
                        NavigationLink(destination: AdminUserDetailView(user: user)) {
                            AdminUserRow(user: user)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("ユーザー管理")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadUsers()
            }
        }
        .task {
            await viewModel.loadUsers()
        }
    }
}

@MainActor
class AdminUsersViewModel: ObservableObject {
    @Published var users: [AdminUser] = []
    @Published var isLoading = true
    @Published var searchText = ""
    @Published var selectedFilter = "all"

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?

    func loadUsers() async {
        isLoading = true
        do {
            users = try await api.getAdminUsers(
                search: searchText.isEmpty ? nil : searchText,
                userType: selectedFilter == "all" ? nil : selectedFilter
            )
        } catch {
            print("Failed to load users: \(error)")
        }
        isLoading = false
    }

    func searchDebounced() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await loadUsers()
            }
        }
    }
}

struct AdminUserRow: View {
    let user: AdminUser

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if user.isIdentityVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if user.isBanned == true {
                        Text("停止中")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(user.userTypeDisplay)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(user.userType == "job_seeker" ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                .foregroundColor(user.userType == "job_seeker" ? .blue : .green)
                .clipShape(Capsule())
        }
    }
}

struct AdminUserDetailView: View {
    let user: AdminUser
    @State private var showBanConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("名前", value: user.displayName)
                LabeledContent("メール", value: user.email)
                LabeledContent("タイプ", value: user.userTypeDisplay)
                LabeledContent("電話番号", value: user.phone ?? "未設定")
                if let createdAt = user.createdAt {
                    LabeledContent("登録日", value: formatDate(createdAt))
                }
            }

            Section("本人確認") {
                LabeledContent("ステータス") {
                    HStack {
                        if user.isIdentityVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                            Text("確認済み")
                        } else {
                            Text(user.identityVerificationStatus ?? "未提出")
                        }
                    }
                }
            }

            Section("統計") {
                if user.userType == "job_seeker" {
                    LabeledContent("応募件数", value: "\(user.totalApplications ?? 0)")
                } else if user.userType == "employer" {
                    LabeledContent("求人投稿数", value: "\(user.totalJobs ?? 0)")
                }
                LabeledContent("ウォレット残高", value: "¥\(user.walletBalance ?? 0)")
            }

            Section {
                if user.isBanned == true {
                    Button("利用停止を解除") {
                        Task { await unbanUser() }
                    }
                    .foregroundColor(.green)
                } else {
                    Button("利用停止にする") {
                        showBanConfirm = true
                    }
                    .foregroundColor(.orange)
                }

                Button("アカウントを削除") {
                    showDeleteConfirm = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("ユーザー詳細")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("このユーザーを利用停止にしますか？", isPresented: $showBanConfirm) {
            Button("利用停止にする", role: .destructive) {
                Task { await banUser() }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog("このアカウントを完全に削除しますか？この操作は取り消せません。", isPresented: $showDeleteConfirm) {
            Button("削除する", role: .destructive) {
                Task { await deleteUser() }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .overlay {
            if isProcessing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }

    private func banUser() async {
        isProcessing = true
        do {
            _ = try await APIClient.shared.banUser(userId: user.id, reason: nil)
            dismiss()
        } catch {
            print("Failed to ban user: \(error)")
        }
        isProcessing = false
    }

    private func unbanUser() async {
        isProcessing = true
        do {
            _ = try await APIClient.shared.unbanUser(userId: user.id)
            dismiss()
        } catch {
            print("Failed to unban user: \(error)")
        }
        isProcessing = false
    }

    private func deleteUser() async {
        isProcessing = true
        do {
            _ = try await APIClient.shared.deleteUser(userId: user.id)
            dismiss()
        } catch {
            print("Failed to delete user: \(error)")
        }
        isProcessing = false
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy年MM月dd日"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Admin Jobs

struct AdminJobsView: View {
    @StateObject private var viewModel = AdminJobsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("ステータス", selection: $viewModel.selectedStatus) {
                    Text("全て").tag("all")
                    Text("審査中").tag("pending")
                    Text("公開中").tag("active")
                    Text("停止中").tag("suspended")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: viewModel.selectedStatus) { _, _ in
                    Task { await viewModel.loadJobs() }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.jobs.isEmpty {
                    Text("求人がありません")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.jobs) { job in
                        AdminJobRow(job: job, onApprove: {
                            Task { await viewModel.approveJob(jobId: job.id) }
                        }, onSuspend: {
                            Task { await viewModel.suspendJob(jobId: job.id) }
                        })
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("求人管理")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadJobs()
            }
        }
        .task {
            await viewModel.loadJobs()
        }
    }
}

@MainActor
class AdminJobsViewModel: ObservableObject {
    @Published var jobs: [AdminJob] = []
    @Published var isLoading = true
    @Published var selectedStatus = "all"

    private let api = APIClient.shared

    func loadJobs() async {
        isLoading = true
        do {
            jobs = try await api.getAdminJobs(status: selectedStatus == "all" ? nil : selectedStatus)
        } catch {
            print("Failed to load jobs: \(error)")
        }
        isLoading = false
    }

    func approveJob(jobId: String) async {
        do {
            _ = try await api.approveJob(jobId: jobId)
            await loadJobs()
        } catch {
            print("Failed to approve job: \(error)")
        }
    }

    func suspendJob(jobId: String) async {
        do {
            _ = try await api.suspendJob(jobId: jobId, reason: nil)
            await loadJobs()
        } catch {
            print("Failed to suspend job: \(error)")
        }
    }
}

struct AdminJobRow: View {
    let job: AdminJob
    let onApprove: () -> Void
    let onSuspend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(job.employerName ?? "事業者名不明")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(job.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            if job.status == "pending" {
                HStack(spacing: 8) {
                    Button(action: onApprove) {
                        Text("承認")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: onSuspend) {
                        Text("却下")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            if job.isFlagged == true {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                    Text(job.flagReason ?? "問題あり")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch job.status {
        case "active": return .green
        case "pending": return .orange
        case "suspended": return .red
        case "closed": return .gray
        default: return .gray
        }
    }
}

// MARK: - Admin Settings

struct AdminSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AdminSettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("システム設定") {
                    NavigationLink(destination: AdminFeeSettingsView()) {
                        Label("手数料設定", systemImage: "percent")
                    }

                    NavigationLink(destination: AdminWithdrawalSettingsView()) {
                        Label("出金設定", systemImage: "banknote")
                    }

                    NavigationLink(destination: Text("通知設定")) {
                        Label("通知設定", systemImage: "bell.fill")
                    }
                }

                Section("分析・レポート") {
                    NavigationLink(destination: AdminAnalyticsView()) {
                        Label("アナリティクス", systemImage: "chart.bar.fill")
                    }

                    NavigationLink(destination: AdminDataExportView()) {
                        Label("データエクスポート", systemImage: "square.and.arrow.up")
                    }
                }

                Section("通知・マーケティング") {
                    NavigationLink(destination: AdminMassNotificationsView()) {
                        Label("一斉通知", systemImage: "bell.badge.fill")
                    }

                    NavigationLink(destination: AdminBannersView()) {
                        Label("バナー管理", systemImage: "photo.fill")
                    }

                    NavigationLink(destination: AdminAdsView()) {
                        Label("広告設定", systemImage: "megaphone.fill")
                    }
                }

                Section("審査管理") {
                    NavigationLink(destination: AdminIdentityVerificationsView()) {
                        Label("本人確認審査", systemImage: "person.text.rectangle")
                    }

                    NavigationLink(destination: AdminQualificationsView()) {
                        Label("資格審査", systemImage: "graduationcap.fill")
                    }

                    NavigationLink(destination: AdminWithdrawalsView()) {
                        Label("出金申請管理", systemImage: "arrow.down.circle")
                    }

                    NavigationLink(destination: AdminKycSettingsView()) {
                        Label("本人確認設定", systemImage: "shield.checkered")
                    }
                }

                Section {
                    Button(action: { authManager.logout() }) {
                        HStack {
                            Spacer()
                            Text("ログアウト")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

@MainActor
class AdminSettingsViewModel: ObservableObject {
    @Published var settings: AdminSystemSettings?

    private let api = APIClient.shared

    func loadSettings() async {
        do {
            settings = try await api.getAdminSystemSettings()
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
}

// MARK: - Admin Withdrawals Sheet

struct AdminWithdrawalsSheet: View {
    @StateObject private var viewModel = AdminWithdrawalsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AdminWithdrawalsContent(viewModel: viewModel)
                .navigationTitle("出金申請")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}

struct AdminWithdrawalsView: View {
    @StateObject private var viewModel = AdminWithdrawalsViewModel()

    var body: some View {
        AdminWithdrawalsContent(viewModel: viewModel)
            .navigationTitle("出金申請管理")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdminWithdrawalsContent: View {
    @ObservedObject var viewModel: AdminWithdrawalsViewModel

    var body: some View {
        VStack {
            Picker("ステータス", selection: $viewModel.selectedStatus) {
                Text("処理待ち").tag("pending")
                Text("完了").tag("completed")
                Text("全て").tag("all")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: viewModel.selectedStatus) { _, _ in
                Task { await viewModel.loadWithdrawals() }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.withdrawals.isEmpty {
                Text("出金申請がありません")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.withdrawals) { withdrawal in
                    AdminWithdrawalRow(
                        withdrawal: withdrawal,
                        onApprove: { Task { await viewModel.approve(id: withdrawal.id) } },
                        onReject: { Task { await viewModel.reject(id: withdrawal.id) } }
                    )
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.loadWithdrawals()
        }
    }
}

@MainActor
class AdminWithdrawalsViewModel: ObservableObject {
    @Published var withdrawals: [AdminWithdrawalRequest] = []
    @Published var isLoading = true
    @Published var selectedStatus = "pending"

    private let api = APIClient.shared

    func loadWithdrawals() async {
        isLoading = true
        do {
            withdrawals = try await api.getAdminWithdrawals(status: selectedStatus == "all" ? nil : selectedStatus)
        } catch {
            print("Failed to load withdrawals: \(error)")
        }
        isLoading = false
    }

    func approve(id: String) async {
        do {
            _ = try await api.approveWithdrawal(withdrawalId: id)
            await loadWithdrawals()
        } catch {
            print("Failed to approve: \(error)")
        }
    }

    func reject(id: String) async {
        do {
            _ = try await api.rejectWithdrawal(withdrawalId: id, reason: nil)
            await loadWithdrawals()
        } catch {
            print("Failed to reject: \(error)")
        }
    }
}

struct AdminWithdrawalRow: View {
    let withdrawal: AdminWithdrawalRequest
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(withdrawal.userName ?? withdrawal.userEmail ?? "不明")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("¥\(withdrawal.amount.formatted())")
                        .font(.headline)
                        .foregroundColor(.green)
                }

                Spacer()

                Text(withdrawal.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(withdrawal.status == "pending" ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundColor(withdrawal.status == "pending" ? .orange : .gray)
                    .clipShape(Capsule())
            }

            if let bank = withdrawal.bankAccountInfo {
                Text("\(bank.bankName) \(bank.branchName) \(bank.accountNumber)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if withdrawal.status == "pending" {
                HStack(spacing: 8) {
                    Button(action: onApprove) {
                        Text("承認")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: onReject) {
                        Text("却下")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Admin Identity Verifications

struct AdminIdentityVerificationsSheet: View {
    @StateObject private var viewModel = AdminIdentityVerificationsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AdminIdentityVerificationsContent(viewModel: viewModel)
                .navigationTitle("本人確認審査")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}

struct AdminIdentityVerificationsView: View {
    @StateObject private var viewModel = AdminIdentityVerificationsViewModel()

    var body: some View {
        AdminIdentityVerificationsContent(viewModel: viewModel)
            .navigationTitle("本人確認審査")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdminIdentityVerificationsContent: View {
    @ObservedObject var viewModel: AdminIdentityVerificationsViewModel

    var body: some View {
        VStack {
            Picker("ステータス", selection: $viewModel.selectedStatus) {
                Text("審査待ち").tag("pending")
                Text("完了").tag("approved")
                Text("全て").tag("all")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: viewModel.selectedStatus) { _, _ in
                Task { await viewModel.loadVerifications() }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.verifications.isEmpty {
                Text("審査待ちがありません")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.verifications) { verification in
                    AdminIdentityVerificationRow(
                        verification: verification,
                        onApprove: { Task { await viewModel.approve(id: verification.id) } },
                        onReject: { Task { await viewModel.reject(id: verification.id) } }
                    )
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.loadVerifications()
        }
    }
}

@MainActor
class AdminIdentityVerificationsViewModel: ObservableObject {
    @Published var verifications: [AdminIdentityVerification] = []
    @Published var isLoading = true
    @Published var selectedStatus = "pending"

    private let api = APIClient.shared

    func loadVerifications() async {
        isLoading = true
        do {
            verifications = try await api.getAdminIdentityVerifications(status: selectedStatus == "all" ? nil : selectedStatus)
        } catch {
            print("Failed to load verifications: \(error)")
        }
        isLoading = false
    }

    func approve(id: String) async {
        do {
            _ = try await api.approveIdentityVerification(verificationId: id)
            await loadVerifications()
        } catch {
            print("Failed to approve: \(error)")
        }
    }

    func reject(id: String) async {
        do {
            _ = try await api.rejectIdentityVerification(verificationId: id, reason: "書類不備")
            await loadVerifications()
        } catch {
            print("Failed to reject: \(error)")
        }
    }
}

struct AdminIdentityVerificationRow: View {
    let verification: AdminIdentityVerification
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verification.userName ?? verification.userEmail ?? "不明")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(verification.documentTypeDisplay)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(verification.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(verification.status == "pending" ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                    .foregroundColor(verification.status == "pending" ? .orange : .green)
                    .clipShape(Capsule())
            }

            // Image previews (if available)
            if let frontUrl = verification.frontImageUrl, let url = URL(string: frontUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if verification.status == "pending" {
                HStack(spacing: 8) {
                    Button(action: onApprove) {
                        Text("承認")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: onReject) {
                        Text("却下")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Admin Pending Jobs Sheet

struct AdminPendingJobsSheet: View {
    @StateObject private var viewModel = AdminJobsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.jobs.isEmpty {
                    Text("審査待ちの求人がありません")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.jobs) { job in
                        AdminJobRow(job: job, onApprove: {
                            Task { await viewModel.approveJob(jobId: job.id) }
                        }, onSuspend: {
                            Task { await viewModel.suspendJob(jobId: job.id) }
                        })
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("求人審査")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                viewModel.selectedStatus = "pending"
                await viewModel.loadJobs()
            }
        }
    }
}

// MARK: - Admin Banners View

struct AdminBannersView: View {
    @StateObject private var viewModel = AdminBannersViewModel()
    @State private var showAddBanner = false

    var body: some View {
        List {
            ForEach(viewModel.banners) { banner in
                AdminBannerRow(banner: banner) {
                    Task { await viewModel.deleteBanner(id: banner.id) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("バナー管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddBanner = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddBanner) {
            AddBannerSheet { await viewModel.loadBanners() }
        }
        .task {
            await viewModel.loadBanners()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

@MainActor
class AdminBannersViewModel: ObservableObject {
    @Published var banners: [AdminBanner] = []
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadBanners() async {
        isLoading = true
        do {
            banners = try await api.getAdminBanners()
        } catch {
            print("Failed to load banners: \(error)")
        }
        isLoading = false
    }

    func deleteBanner(id: String) async {
        do {
            _ = try await api.deleteBanner(bannerId: id)
            await loadBanners()
        } catch {
            print("Failed to delete banner: \(error)")
        }
    }
}

struct AdminBannerRow: View {
    let banner: AdminBanner
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let imageUrl = banner.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(banner.isActive ? "公開中" : "非公開")
                    .font(.caption)
                    .foregroundColor(banner.isActive ? .green : .gray)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

struct AddBannerSheet: View {
    @State private var title = ""
    @State private var imageUrl = ""
    @State private var linkUrl = ""
    @State private var isActive = true
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    let onComplete: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("タイトル", text: $title)
                TextField("画像URL", text: $imageUrl)
                TextField("リンクURL（任意）", text: $linkUrl)
                Toggle("公開", isOn: $isActive)
            }
            .navigationTitle("バナー追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await saveBanner() }
                    }
                    .disabled(title.isEmpty || imageUrl.isEmpty || isLoading)
                }
            }
        }
    }

    private func saveBanner() async {
        isLoading = true
        do {
            _ = try await APIClient.shared.createBanner(
                title: title,
                imageUrl: imageUrl,
                linkUrl: linkUrl.isEmpty ? nil : linkUrl,
                isActive: isActive,
                startDate: nil,
                endDate: nil
            )
            await onComplete()
            dismiss()
        } catch {
            print("Failed to create banner: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Settings Views

struct AdminFeeSettingsView: View {
    @State private var platformFee = "20"
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section("プラットフォーム手数料") {
                HStack {
                    TextField("手数料", text: $platformFee)
                        .keyboardType(.decimalPad)
                    Text("%")
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            Section {
                Button("保存") {
                    Task { await saveFeeSettings() }
                }
                .disabled(isSaving || platformFee.isEmpty)
            }
        }
        .navigationTitle("手数料設定")
        .task {
            await loadSettings()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    private func loadSettings() async {
        isLoading = true
        do {
            let settings = try await api.getAdminSystemSettings()
            platformFee = String(format: "%.1f", settings.platformFeePercent)
        } catch {
            errorMessage = "設定の読み込みに失敗しました"
        }
        isLoading = false
    }

    private func saveFeeSettings() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard let feeValue = Double(platformFee) else {
            errorMessage = "有効な数値を入力してください"
            isSaving = false
            return
        }

        do {
            _ = try await api.updateAdminSystemSettings(settings: [
                "platformFeePercent": feeValue
            ])
            successMessage = "保存しました"
        } catch {
            errorMessage = "保存に失敗しました"
        }
        isSaving = false
    }
}

struct AdminWithdrawalSettingsView: View {
    @State private var minAmount = "1000"
    @State private var maxAmount = "1000000"
    @State private var fee = "250"
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section("出金設定") {
                HStack {
                    Text("最低出金額")
                    Spacer()
                    TextField("金額", text: $minAmount)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("円")
                }

                HStack {
                    Text("最高出金額")
                    Spacer()
                    TextField("金額", text: $maxAmount)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("円")
                }

                HStack {
                    Text("出金手数料")
                    Spacer()
                    TextField("金額", text: $fee)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("円")
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            Section {
                Button("保存") {
                    Task { await saveWithdrawalSettings() }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("出金設定")
        .task {
            await loadSettings()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    private func loadSettings() async {
        isLoading = true
        do {
            let settings = try await api.getAdminSystemSettings()
            minAmount = String(settings.minWithdrawalAmount)
            maxAmount = String(settings.maxWithdrawalAmount)
            fee = String(settings.withdrawalFee)
        } catch {
            errorMessage = "設定の読み込みに失敗しました"
        }
        isLoading = false
    }

    private func saveWithdrawalSettings() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard let minValue = Int(minAmount),
              let maxValue = Int(maxAmount),
              let feeValue = Int(fee) else {
            errorMessage = "有効な数値を入力してください"
            isSaving = false
            return
        }

        do {
            _ = try await api.updateAdminSystemSettings(settings: [
                "minWithdrawalAmount": minValue,
                "maxWithdrawalAmount": maxValue,
                "withdrawalFee": feeValue
            ])
            successMessage = "保存しました"
        } catch {
            errorMessage = "保存に失敗しました"
        }
        isSaving = false
    }
}

// MARK: - KYC Settings View

struct AdminKycSettingsView: View {
    @State private var approvalMode = "manual"
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section("本人確認承認モード") {
                Picker("承認モード", selection: $approvalMode) {
                    Text("手動承認").tag("manual")
                    Text("自動承認").tag("auto")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section {
                if approvalMode == "auto" {
                    Text("本人確認書類が提出されると自動的に承認されます。")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("管理者が手動で本人確認を審査・承認します。")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            Section {
                Button("保存") {
                    Task { await saveKycSettings() }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("本人確認設定")
        .task {
            await loadSettings()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    private func loadSettings() async {
        isLoading = true
        do {
            let settings = try await api.getKycSettings()
            approvalMode = settings.approvalMode
        } catch {
            errorMessage = "設定の読み込みに失敗しました"
        }
        isLoading = false
    }

    private func saveKycSettings() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await api.updateKycSettings(approvalMode: approvalMode)
            successMessage = "保存しました"
        } catch {
            errorMessage = "保存に失敗しました"
        }
        isSaving = false
    }
}

// MARK: - Admin Qualifications View

struct AdminQualificationsView: View {
    @StateObject private var viewModel = AdminQualificationsViewModel()
    @State private var selectedQualification: AdminQualification?
    @State private var showDetailSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Filter
            Picker("ステータス", selection: $viewModel.selectedStatus) {
                Text("確認中").tag("pending")
                Text("承認済").tag("approved")
                Text("再提出要").tag("rejected")
                Text("全て").tag("all")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: viewModel.selectedStatus) { _, _ in
                Task { await viewModel.loadQualifications() }
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("ユーザー名、資格名で検索", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) { _, _ in
                        viewModel.filterQualifications()
                    }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // List
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredQualifications.isEmpty {
                Text("該当するデータがありません")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredQualifications) { qualification in
                    AdminQualificationRow(qualification: qualification)
                        .onTapGesture {
                            selectedQualification = qualification
                            showDetailSheet = true
                        }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("資格審査")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDetailSheet) {
            if let qualification = selectedQualification {
                AdminQualificationDetailSheet(
                    qualification: qualification,
                    onApprove: {
                        Task { await viewModel.approveQualification(id: qualification.id) }
                        showDetailSheet = false
                    },
                    onReject: { reason in
                        Task { await viewModel.rejectQualification(id: qualification.id, reason: reason) }
                        showDetailSheet = false
                    }
                )
            }
        }
        .task {
            await viewModel.loadQualifications()
        }
        .refreshable {
            await viewModel.loadQualifications()
        }
    }
}

@MainActor
class AdminQualificationsViewModel: ObservableObject {
    @Published var qualifications: [AdminQualification] = []
    @Published var filteredQualifications: [AdminQualification] = []
    @Published var isLoading = true
    @Published var selectedStatus = "pending"
    @Published var searchText = ""

    private let api = APIClient.shared

    func loadQualifications() async {
        isLoading = true
        do {
            qualifications = try await api.getAdminQualifications(status: selectedStatus == "all" ? nil : selectedStatus)
            filterQualifications()
        } catch {
            print("Failed to load qualifications: \(error)")
        }
        isLoading = false
    }

    func filterQualifications() {
        if searchText.isEmpty {
            filteredQualifications = qualifications
        } else {
            let term = searchText.lowercased()
            filteredQualifications = qualifications.filter {
                ($0.userName ?? "").lowercased().contains(term) ||
                ($0.userEmail ?? "").lowercased().contains(term) ||
                $0.qualificationName.lowercased().contains(term)
            }
        }
    }

    func approveQualification(id: String) async {
        do {
            _ = try await api.approveQualification(qualificationId: id)
            await loadQualifications()
        } catch {
            print("Failed to approve: \(error)")
        }
    }

    func rejectQualification(id: String, reason: String) async {
        do {
            _ = try await api.rejectQualification(qualificationId: id, reason: reason)
            await loadQualifications()
        } catch {
            print("Failed to reject: \(error)")
        }
    }
}

struct AdminQualificationRow: View {
    let qualification: AdminQualification

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(qualification.userName ?? "不明")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(qualification.qualificationName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(qualification.statusDisplay)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
        }
    }

    private var statusColor: Color {
        switch qualification.status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

struct AdminQualificationDetailSheet: View {
    let qualification: AdminQualification
    let onApprove: () -> Void
    let onReject: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rejectionReason = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "ユーザー", value: qualification.userName ?? "不明")
                        InfoRow(label: "メール", value: qualification.userEmail ?? "不明")
                        InfoRow(label: "資格名", value: qualification.qualificationName)
                        InfoRow(label: "取得日", value: qualification.obtainedDate ?? "-")
                        InfoRow(label: "提出日", value: formatDate(qualification.submittedAt))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Image Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("証明書画像")
                            .font(.headline)

                        if let imageUrl = qualification.qualificationImage, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            Text("画像なし")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Actions
                    if qualification.status == "pending" || qualification.status == "rejected" {
                        VStack(spacing: 12) {
                            Text("審査アクション")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("差戻し理由（却下時のみ）", text: $rejectionReason)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            HStack(spacing: 12) {
                                Button(action: onApprove) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("承認")
                                    }
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button(action: { onReject(rejectionReason) }) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("差戻し")
                                    }
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    } else if qualification.status == "approved" {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            Text("承認済みです")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("資格詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "-" }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy年MM月dd日"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Admin Ads View

struct AdminAdsView: View {
    @StateObject private var viewModel = AdminAdsViewModel()
    @State private var showAddBanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Price Settings
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "yensign.circle.fill")
                            .foregroundColor(.orange)
                        Text("価格設定")
                            .font(.headline)
                    }

                    VStack(spacing: 12) {
                        HStack {
                            Text("バナー広告（月額）")
                                .font(.subheadline)
                            Spacer()
                            TextField("", text: $viewModel.bannerPrice)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("円")
                                .foregroundColor(.gray)
                        }

                        HStack {
                            Text("おすすめ表示（日額）")
                                .font(.subheadline)
                            Spacer()
                            TextField("", text: $viewModel.promoPrice)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("円")
                                .foregroundColor(.gray)
                        }

                        Button(action: { Task { await viewModel.savePrices() } }) {
                            Text("価格を保存")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                // Active Carousel Slots
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("公開中カルーセル（\(viewModel.slots.count)/10）")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                    }

                    if viewModel.slots.isEmpty {
                        Text("候補リストからドラッグして追加してください")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(Array(viewModel.slots.enumerated()), id: \.element.id) { index, banner in
                            AdminBannerSlotRow(
                                banner: banner,
                                index: index,
                                isActive: true,
                                onMoveUp: index > 0 ? { viewModel.moveBanner(from: index, to: index - 1) } : nil,
                                onMoveDown: index < viewModel.slots.count - 1 ? { viewModel.moveBanner(from: index, to: index + 1) } : nil,
                                onRemove: { viewModel.removeFromSlots(at: index) }
                            )
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Add New Banner
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "photo.fill")
                            .foregroundColor(.blue)
                        Text("新規バナー追加")
                            .font(.headline)
                    }

                    Button(action: { showAddBanner = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("バナーを追加")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                // Candidates
                VStack(alignment: .leading, spacing: 16) {
                    Text("掲載候補リスト")
                        .font(.headline)

                    if viewModel.candidates.isEmpty {
                        Text("候補はありません")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(viewModel.candidates) { banner in
                            AdminBannerCandidateRow(
                                banner: banner,
                                onAddToSlots: {
                                    viewModel.addToSlots(banner)
                                },
                                onDelete: {
                                    Task { await viewModel.deleteBanner(id: banner.id) }
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("広告管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddBanner) {
            AddBannerFormSheet {
                Task { await viewModel.loadData() }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }
}

@MainActor
class AdminAdsViewModel: ObservableObject {
    @Published var slots: [AdminBannerSlot] = []
    @Published var candidates: [AdminBannerSlot] = []
    @Published var bannerPrice = "10000"
    @Published var promoPrice = "1000"
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            slots = try await api.getAdminBannerSlots()
            candidates = try await api.getAdminBannerCandidates()

            if let settings = try? await api.getAdminAdSettings() {
                bannerPrice = String(settings.bannerPriceMonthly ?? 10000)
                promoPrice = String(settings.promotionPriceDaily ?? 1000)
            }
        } catch {
            print("Failed to load ads data: \(error)")
        }
        isLoading = false
    }

    func savePrices() async {
        do {
            _ = try await api.updateAdSetting(key: "banner_price_monthly", value: bannerPrice, description: "Banner monthly price", category: "ads")
            _ = try await api.updateAdSetting(key: "promotion_price_daily", value: promoPrice, description: "Promo daily price", category: "ads")
        } catch {
            print("Failed to save prices: \(error)")
        }
    }

    func moveBanner(from: Int, to: Int) {
        var newSlots = slots
        let item = newSlots.remove(at: from)
        newSlots.insert(item, at: to)
        slots = newSlots
        Task { await saveOrder() }
    }

    func removeFromSlots(at index: Int) {
        let item = slots.remove(at: index)
        candidates.append(item)
        Task { await saveOrder() }
    }

    func addToSlots(_ banner: AdminBannerSlot) {
        guard slots.count < 10 else { return }
        candidates.removeAll { $0.id == banner.id }
        slots.append(banner)
        Task { await saveOrder() }
    }

    func saveOrder() async {
        do {
            _ = try await api.updateBannerOrder(orderedIds: slots.map { $0.id })
        } catch {
            print("Failed to save order: \(error)")
        }
    }

    func deleteBanner(id: String) async {
        do {
            _ = try await api.deleteBanner(bannerId: id)
            await loadData()
        } catch {
            print("Failed to delete banner: \(error)")
        }
    }
}

struct AdminBannerSlotRow: View {
    let banner: AdminBannerSlot
    let index: Int
    let isActive: Bool
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())

            if let imageUrl = banner.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.linkUrl)
                    .font(.caption)
                    .lineLimit(1)
                if let expires = banner.expiresAt {
                    Text("期限: \(formatDate(expires))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if let onMoveUp = onMoveUp {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                }
                if let onMoveDown = onMoveDown {
                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy/MM/dd"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct AdminBannerCandidateRow: View {
    let banner: AdminBannerSlot
    let onAddToSlots: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let imageUrl = banner.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .grayscale(1)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.linkUrl)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                if let expires = banner.expiresAt {
                    Text("期限: \(expires.prefix(10))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Button(action: onAddToSlots) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AddBannerFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var linkUrl = ""
    @State private var selectedImage: Data?
    @State private var showImagePicker = false
    @State private var isLoading = false

    let onComplete: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("バナー画像") {
                    Button(action: { showImagePicker = true }) {
                        if let imageData = selectedImage, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        } else {
                            HStack {
                                Image(systemName: "photo")
                                Text("画像を選択")
                            }
                        }
                    }
                }

                Section("リンクURL") {
                    TextField("https://...", text: $linkUrl)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("バナー追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task { await addBanner() }
                    }
                    .disabled(selectedImage == nil || linkUrl.isEmpty || isLoading)
                }
            }
        }
    }

    private func addBanner() async {
        guard let imageData = selectedImage else { return }
        isLoading = true

        do {
            let base64 = imageData.base64EncodedString()
            _ = try await APIClient.shared.createBannerWithImage(
                imageBase64: "data:image/jpeg;base64,\(base64)",
                linkUrl: linkUrl,
                description: "Admin Upload",
                months: 12
            )
            await onComplete()
            dismiss()
        } catch {
            print("Failed to add banner: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Admin Analytics View

struct AdminAnalyticsView: View {
    @StateObject private var viewModel = AdminAnalyticsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Period Picker
                Picker("期間", selection: $viewModel.selectedPeriod) {
                    Text("週間").tag("week")
                    Text("月間").tag("month")
                    Text("年間").tag("year")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: viewModel.selectedPeriod) { _, _ in
                    Task { await viewModel.loadData() }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Overview Stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("概要")
                            .font(.headline)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            AnalyticsStatCard(
                                title: "総ユーザー",
                                value: "\(viewModel.analytics?.totalUsers ?? 0)",
                                icon: "person.3.fill",
                                color: .blue
                            )
                            AnalyticsStatCard(
                                title: "総求人数",
                                value: "\(viewModel.analytics?.totalJobs ?? 0)",
                                icon: "briefcase.fill",
                                color: .green
                            )
                            AnalyticsStatCard(
                                title: "総応募数",
                                value: "\(viewModel.analytics?.totalApplications ?? 0)",
                                icon: "doc.text.fill",
                                color: .orange
                            )
                            AnalyticsStatCard(
                                title: "完了済み",
                                value: "\(viewModel.analytics?.completedJobs ?? 0)",
                                icon: "checkmark.circle.fill",
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)

                    // Revenue Stats
                    if let revenue = viewModel.revenueStats {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "yensign.circle.fill")
                                    .foregroundColor(.green)
                                Text("売上統計")
                                    .font(.headline)
                            }

                            VStack(spacing: 12) {
                                HStack {
                                    Text("総売上")
                                    Spacer()
                                    Text("¥\(revenue.totalRevenue.formatted())")
                                        .fontWeight(.bold)
                                }

                                HStack {
                                    Text("プラットフォーム手数料")
                                    Spacer()
                                    Text("¥\(revenue.platformFees.formatted())")
                                }

                                HStack {
                                    Text("出金済み")
                                    Spacer()
                                    Text("¥\(revenue.payoutTotal.formatted())")
                                }

                                HStack {
                                    Text("出金待ち")
                                    Spacer()
                                    Text("¥\(revenue.pendingPayouts.formatted())")
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }

                    // User Growth
                    if let growth = viewModel.userGrowth {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.blue)
                                Text("ユーザー成長")
                                    .font(.headline)
                            }

                            VStack(spacing: 12) {
                                HStack {
                                    Text("今期新規登録")
                                    Spacer()
                                    Text("+\(growth.newUsersThisPeriod)")
                                        .foregroundColor(.green)
                                        .fontWeight(.bold)
                                }

                                HStack {
                                    Text("求職者数")
                                    Spacer()
                                    Text("\(growth.jobSeekerCount)")
                                }

                                HStack {
                                    Text("事業者数")
                                    Spacer()
                                    Text("\(growth.employerCount)")
                                }
                            }
                            .font(.subheadline)

                            if !growth.dailySignups.isEmpty {
                                Divider()
                                Text("日別新規登録")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                ForEach(growth.dailySignups.prefix(7), id: \.date) { signup in
                                    HStack {
                                        Text(signup.date)
                                            .font(.caption)
                                        Spacer()
                                        Text("\(signup.count)人")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("アナリティクス")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }
}

struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
class AdminAnalyticsViewModel: ObservableObject {
    @Published var analytics: AdminAnalytics?
    @Published var revenueStats: AdminRevenueStats?
    @Published var userGrowth: AdminUserGrowth?
    @Published var selectedPeriod = "month"
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            async let analyticsTask = api.getAdminAnalytics(period: selectedPeriod)
            async let revenueTask = api.getAdminRevenueStats(period: selectedPeriod)
            async let growthTask = api.getAdminUserGrowth(period: selectedPeriod)

            analytics = try await analyticsTask
            revenueStats = try await revenueTask
            userGrowth = try await growthTask
        } catch {
            print("Failed to load analytics: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Admin Mass Notifications View

struct AdminMassNotificationsView: View {
    @StateObject private var viewModel = AdminMassNotificationsViewModel()
    @State private var showSendSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Send Button
            Button(action: { showSendSheet = true }) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                    Text("新規通知を送信")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()

            // History
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("送信履歴がありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.history) { record in
                    NotificationHistoryRow(record: record)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("一斉通知")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSendSheet) {
            SendMassNotificationSheet {
                Task { await viewModel.loadHistory() }
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .refreshable {
            await viewModel.loadHistory()
        }
    }
}

struct NotificationHistoryRow: View {
    let record: AdminNotificationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(formatDate(record.sentAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(record.message)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)

            HStack {
                if let targetType = record.targetUserType {
                    Text(targetTypeDisplay(targetType))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }

                Text("\(record.sentCount)件送信")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "MM/dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func targetTypeDisplay(_ type: String) -> String {
        switch type {
        case "job_seeker": return "求職者"
        case "employer": return "事業者"
        case "all": return "全員"
        default: return type
        }
    }
}

struct SendMassNotificationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var targetUserType = "all"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    let onComplete: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("通知内容")) {
                    TextField("タイトル", text: $title)
                    TextEditor(text: $message)
                        .frame(height: 100)
                }

                Section(header: Text("送信対象")) {
                    Picker("対象ユーザー", selection: $targetUserType) {
                        Text("全員").tag("all")
                        Text("求職者のみ").tag("job_seeker")
                        Text("事業者のみ").tag("employer")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if let success = successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("一斉通知送信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送信") {
                        Task { await sendNotification() }
                    }
                    .disabled(title.isEmpty || message.isEmpty || isLoading)
                }
            }
        }
    }

    private func sendNotification() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await APIClient.shared.sendMassNotification(
                title: title,
                message: message,
                targetUserType: targetUserType == "all" ? nil : targetUserType,
                targetUserIds: nil
            )
            successMessage = "\(result.sentCount)件の通知を送信しました"
            await onComplete()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = "送信に失敗しました: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

@MainActor
class AdminMassNotificationsViewModel: ObservableObject {
    @Published var history: [AdminNotificationRecord] = []
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadHistory() async {
        isLoading = true
        do {
            history = try await api.getAdminNotificationHistory()
        } catch {
            print("Failed to load notification history: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Admin Data Export View

struct AdminDataExportView: View {
    @State private var isExportingUsers = false
    @State private var isExportingJobs = false
    @State private var isExportingTransactions = false
    @State private var startDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
    @State private var endDate = Date()
    @State private var message: String?
    @State private var isError = false

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section(header: Text("ユーザーデータ")) {
                Button(action: { Task { await exportUsers() } }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.blue)
                        Text("ユーザーデータをエクスポート")
                        Spacer()
                        if isExportingUsers {
                            ProgressView()
                        }
                    }
                }
                .disabled(isExportingUsers)
            }

            Section(header: Text("求人データ")) {
                Button(action: { Task { await exportJobs() } }) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(.green)
                        Text("求人データをエクスポート")
                        Spacer()
                        if isExportingJobs {
                            ProgressView()
                        }
                    }
                }
                .disabled(isExportingJobs)
            }

            Section(header: Text("取引データ")) {
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                DatePicker("終了日", selection: $endDate, displayedComponents: .date)

                Button(action: { Task { await exportTransactions() } }) {
                    HStack {
                        Image(systemName: "yensign.circle.fill")
                            .foregroundColor(.orange)
                        Text("取引データをエクスポート")
                        Spacer()
                        if isExportingTransactions {
                            ProgressView()
                        }
                    }
                }
                .disabled(isExportingTransactions)
            }

            if let msg = message {
                Section {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(isError ? .red : .green)
                }
            }
        }
        .navigationTitle("データエクスポート")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportUsers() async {
        isExportingUsers = true
        message = nil

        do {
            let result = try await api.exportUsersData()
            message = "\(result.recordCount)件のユーザーデータをエクスポートしました"
            isError = false
        } catch {
            message = "エクスポートに失敗しました"
            isError = true
        }
        isExportingUsers = false
    }

    private func exportJobs() async {
        isExportingJobs = true
        message = nil

        do {
            let result = try await api.exportJobsData()
            message = "\(result.recordCount)件の求人データをエクスポートしました"
            isError = false
        } catch {
            message = "エクスポートに失敗しました"
            isError = true
        }
        isExportingJobs = false
    }

    private func exportTransactions() async {
        isExportingTransactions = true
        message = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        do {
            let result = try await api.exportTransactionsData(
                startDate: dateFormatter.string(from: startDate),
                endDate: dateFormatter.string(from: endDate)
            )
            message = "\(result.recordCount)件の取引データをエクスポートしました"
            isError = false
        } catch {
            message = "エクスポートに失敗しました"
            isError = true
        }
        isExportingTransactions = false
    }
}

#Preview {
    AdminDashboardView()
}
