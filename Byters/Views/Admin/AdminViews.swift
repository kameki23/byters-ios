import SwiftUI
import PhotosUI

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
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
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
    @Published var errorMessage: String?

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
            errorMessage = error.localizedDescription
        }
    }

    func loadActivities() async {
        do {
            activities = try await api.getAdminRecentActivity()
        } catch {
            errorMessage = error.localizedDescription
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
        .background(Color(.systemBackground))
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
                        NavigationLink(destination: AdminUserDetailView(user: user, onUpdate: {
                            Task { await viewModel.loadUsers() }
                        })) {
                            AdminUserRow(user: user)
                        }
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(currentUser: user) }
                        }
                    }
                    .listStyle(.plain)

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
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
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

@MainActor
class AdminUsersViewModel: ObservableObject {
    @Published var users: [AdminUser] = []
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var searchText = ""
    @Published var selectedFilter = "all"
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?
    private var currentPage = 1
    private var hasMorePages = true

    func loadUsers() async {
        isLoading = true
        currentPage = 1
        hasMorePages = true
        do {
            let result = try await api.getAdminUsers(
                search: searchText.isEmpty ? nil : searchText,
                userType: selectedFilter == "all" ? nil : selectedFilter,
                page: 1
            )
            users = result
            hasMorePages = result.count >= 20
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMoreIfNeeded(currentUser: AdminUser) async {
        guard let lastUser = users.last,
              lastUser.id == currentUser.id,
              hasMorePages,
              !isLoadingMore else { return }

        isLoadingMore = true
        currentPage += 1
        do {
            let result = try await api.getAdminUsers(
                search: searchText.isEmpty ? nil : searchText,
                userType: selectedFilter == "all" ? nil : selectedFilter,
                page: currentPage
            )
            users.append(contentsOf: result)
            hasMorePages = result.count >= 20
        } catch {
            errorMessage = error.localizedDescription
            currentPage -= 1
        }
        isLoadingMore = false
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
    var onUpdate: (() -> Void)?
    @State private var showBanConfirm = false
    @State private var showBanReasonSheet = false
    @State private var showDeleteConfirm = false
    @State private var banReason = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
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

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section {
                if user.isBanned == true {
                    Button("利用停止を解除") {
                        Task { await unbanUser() }
                    }
                    .foregroundColor(.green)
                } else {
                    Button("利用停止にする") {
                        showBanReasonSheet = true
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
        .sheet(isPresented: $showBanReasonSheet) {
            NavigationStack {
                Form {
                    Section("利用停止の理由") {
                        TextEditor(text: $banReason)
                            .frame(height: 100)
                    }
                }
                .navigationTitle("利用停止")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { showBanReasonSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("停止する") {
                            showBanReasonSheet = false
                            Task { await banUser() }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .presentationDetents([.medium])
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
        errorMessage = nil
        do {
            _ = try await APIClient.shared.banUser(userId: user.id, reason: banReason.isEmpty ? nil : banReason)
            onUpdate?()
            dismiss()
        } catch {
            errorMessage = "利用停止に失敗しました"
        }
        isProcessing = false
    }

    private func unbanUser() async {
        isProcessing = true
        do {
            _ = try await APIClient.shared.unbanUser(userId: user.id)
            onUpdate?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    private func deleteUser() async {
        isProcessing = true
        do {
            _ = try await APIClient.shared.deleteUser(userId: user.id)
            onUpdate?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
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
    @State private var showSuspendSheet = false
    @State private var suspendReason = ""
    @State private var suspendTargetJobId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("求人検索", text: $viewModel.searchText)
                            .onChange(of: viewModel.searchText) { _, _ in
                                viewModel.searchDebounced()
                            }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Picker("ステータス", selection: $viewModel.selectedStatus) {
                        Text("全て").tag("all")
                        Text("審査中").tag("pending")
                        Text("公開中").tag("active")
                        Text("停止中").tag("suspended")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedStatus) { _, _ in
                        Task { await viewModel.loadJobs() }
                    }
                }
                .padding(.vertical)

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
                            suspendTargetJobId = job.id
                            suspendReason = ""
                            showSuspendSheet = true
                        })
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(currentJob: job) }
                        }
                    }
                    .listStyle(.plain)

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .navigationTitle("求人管理")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadJobs()
            }
            .sheet(isPresented: $showSuspendSheet) {
                NavigationStack {
                    Form {
                        Section("停止理由") {
                            TextEditor(text: $suspendReason)
                                .frame(height: 100)
                        }
                    }
                    .navigationTitle("求人を停止")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showSuspendSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("停止する") {
                                if let jobId = suspendTargetJobId {
                                    showSuspendSheet = false
                                    Task { await viewModel.suspendJob(jobId: jobId, reason: suspendReason) }
                                }
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .task {
            await viewModel.loadJobs()
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

@MainActor
class AdminJobsViewModel: ObservableObject {
    @Published var jobs: [AdminJob] = []
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var selectedStatus = "all"
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private var currentPage = 1
    private var hasMorePages = true
    private var searchTask: Task<Void, Never>?

    func loadJobs() async {
        isLoading = true
        currentPage = 1
        hasMorePages = true
        do {
            jobs = try await api.getAdminJobs(
                search: searchText.isEmpty ? nil : searchText,
                status: selectedStatus == "all" ? nil : selectedStatus,
                page: 1
            )
            hasMorePages = jobs.count >= 20
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMoreIfNeeded(currentJob: AdminJob) async {
        guard let lastJob = jobs.last,
              lastJob.id == currentJob.id,
              hasMorePages,
              !isLoadingMore else { return }

        isLoadingMore = true
        currentPage += 1
        do {
            let result = try await api.getAdminJobs(
                search: searchText.isEmpty ? nil : searchText,
                status: selectedStatus == "all" ? nil : selectedStatus,
                page: currentPage
            )
            jobs.append(contentsOf: result)
            hasMorePages = result.count >= 20
        } catch {
            errorMessage = error.localizedDescription
            currentPage -= 1
        }
        isLoadingMore = false
    }

    func searchDebounced() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await loadJobs()
            }
        }
    }

    func approveJob(jobId: String) async {
        do {
            _ = try await api.approveJob(jobId: jobId)
            await loadJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func suspendJob(jobId: String, reason: String) async {
        do {
            _ = try await api.suspendJob(jobId: jobId, reason: reason.isEmpty ? nil : reason)
            await loadJobs()
        } catch {
            errorMessage = error.localizedDescription
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

    var body: some View {
        NavigationStack {
            List {
                Section("収益管理") {
                    NavigationLink(destination: AdminRevenueWalletView()) {
                        Label("収益ウォレット", systemImage: "yensign.circle.fill")
                    }

                    NavigationLink(destination: AdminPlatformBankAccountView()) {
                        Label("銀行口座管理", systemImage: "building.columns.fill")
                    }

                    NavigationLink(destination: AdminPlatformWithdrawalView()) {
                        Label("出金申請", systemImage: "arrow.up.circle.fill")
                    }
                }

                Section("システム設定") {
                    NavigationLink(destination: AdminFeeSettingsView()) {
                        Label("手数料設定", systemImage: "percent")
                    }

                    NavigationLink(destination: AdminWithdrawalSettingsView()) {
                        Label("出金設定", systemImage: "banknote")
                    }

                    NavigationLink(destination: AdminNotificationSettingsView()) {
                        Label("通知設定", systemImage: "bell.fill")
                    }

                    NavigationLink(destination: AdminCategoryManagementView()) {
                        Label("カテゴリ管理", systemImage: "folder.fill")
                    }

                    NavigationLink(destination: AdminOptionalFeaturesView()) {
                        Label("オプション機能", systemImage: "switch.2")
                    }
                }

                Section("分析・レポート") {
                    NavigationLink(destination: AdminAnalyticsView()) {
                        Label("アナリティクス", systemImage: "chart.bar.fill")
                    }

                    NavigationLink(destination: AdminDataExportView()) {
                        Label("データエクスポート", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink(destination: AdminSecurityView()) {
                        Label("セキュリティ", systemImage: "lock.shield")
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

                    NavigationLink(destination: AdminCMSContentView()) {
                        Label("コンテンツ編集", systemImage: "doc.richtext")
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

                    NavigationLink(destination: AdminReportsView()) {
                        Label("通報・問い合わせ", systemImage: "exclamationmark.bubble")
                    }

                    NavigationLink(destination: AdminKycSettingsView()) {
                        Label("本人確認設定", systemImage: "shield.checkered")
                    }
                }

                Section("開発者") {
                    NavigationLink(destination: AdminAPIKeysView()) {
                        Label("APIキー管理", systemImage: "key.fill")
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
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @State private var rejectTargetId: String?

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
                        onReject: {
                            rejectTargetId = withdrawal.id
                            rejectReason = ""
                            showRejectSheet = true
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.loadWithdrawals()
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationStack {
                Form {
                    Section("却下理由") {
                        TextEditor(text: $rejectReason)
                            .frame(height: 100)
                    }
                }
                .navigationTitle("出金申請を却下")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { showRejectSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("却下する") {
                            if let id = rejectTargetId {
                                showRejectSheet = false
                                Task { await viewModel.reject(id: id, reason: rejectReason) }
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

@MainActor
class AdminWithdrawalsViewModel: ObservableObject {
    @Published var withdrawals: [AdminWithdrawalRequest] = []
    @Published var isLoading = true
    @Published var selectedStatus = "pending"
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadWithdrawals() async {
        isLoading = true
        do {
            withdrawals = try await api.getAdminWithdrawals(status: selectedStatus == "all" ? nil : selectedStatus)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func approve(id: String) async {
        do {
            _ = try await api.approveWithdrawal(withdrawalId: id)
            await loadWithdrawals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(id: String, reason: String) async {
        do {
            _ = try await api.rejectWithdrawal(withdrawalId: id, reason: reason.isEmpty ? nil : reason)
            await loadWithdrawals()
        } catch {
            errorMessage = error.localizedDescription
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
    @State private var showRejectSheet = false
    @State private var selectedRejectReason = ""
    @State private var customRejectReason = ""
    @State private var rejectTargetId: String?

    private var finalRejectReason: String {
        selectedRejectReason == "other" ? customRejectReason : selectedRejectReason
    }

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
                        onReject: {
                            rejectTargetId = verification.id
                            selectedRejectReason = ""
                            customRejectReason = ""
                            showRejectSheet = true
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.loadVerifications()
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationStack {
                Form {
                    Section("却下理由") {
                        Picker("理由を選択", selection: $selectedRejectReason) {
                            Text("選択してください").tag("")
                            Text("書類不備").tag("書類不備")
                            Text("画像が不鮮明").tag("画像が不鮮明")
                            Text("有効期限切れ").tag("有効期限切れ")
                            Text("本人との一致が確認できない").tag("本人との一致が確認できない")
                            Text("その他").tag("other")
                        }

                        if selectedRejectReason == "other" {
                            TextField("理由を入力", text: $customRejectReason)
                        }
                    }
                }
                .navigationTitle("本人確認を却下")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { showRejectSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("却下する") {
                            if let id = rejectTargetId {
                                showRejectSheet = false
                                Task { await viewModel.reject(id: id, reason: finalRejectReason) }
                            }
                        }
                        .disabled(finalRejectReason.isEmpty)
                        .foregroundColor(.red)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

@MainActor
class AdminIdentityVerificationsViewModel: ObservableObject {
    @Published var verifications: [AdminIdentityVerification] = []
    @Published var isLoading = true
    @Published var selectedStatus = "pending"
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadVerifications() async {
        isLoading = true
        do {
            verifications = try await api.getAdminIdentityVerifications(status: selectedStatus == "all" ? nil : selectedStatus)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func approve(id: String) async {
        do {
            _ = try await api.approveIdentityVerification(verificationId: id)
            await loadVerifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(id: String, reason: String) async {
        do {
            _ = try await api.rejectIdentityVerification(verificationId: id, reason: reason.isEmpty ? "書類不備" : reason)
            await loadVerifications()
        } catch {
            errorMessage = error.localizedDescription
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
            HStack(spacing: 8) {
                if let frontUrl = verification.frontImageUrl, let url = URL(string: frontUrl) {
                    VStack {
                        Text("表面")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                if let backUrl = verification.backImageUrl, let url = URL(string: backUrl) {
                    VStack {
                        Text("裏面")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
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
    @State private var showSuspendSheet = false
    @State private var suspendReason = ""
    @State private var suspendTargetJobId: String?

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
                            suspendTargetJobId = job.id
                            suspendReason = ""
                            showSuspendSheet = true
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
            .sheet(isPresented: $showSuspendSheet) {
                NavigationStack {
                    Form {
                        Section("停止理由") {
                            TextEditor(text: $suspendReason)
                                .frame(height: 100)
                        }
                    }
                    .navigationTitle("求人を停止")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showSuspendSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("停止する") {
                                if let jobId = suspendTargetJobId {
                                    showSuspendSheet = false
                                    Task { await viewModel.suspendJob(jobId: jobId, reason: suspendReason) }
                                }
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .presentationDetents([.medium])
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
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

@MainActor
class AdminBannersViewModel: ObservableObject {
    @Published var banners: [AdminBanner] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadBanners() async {
        isLoading = true
        do {
            banners = try await api.getAdminBanners()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteBanner(id: String) async {
        do {
            _ = try await api.deleteBanner(bannerId: id)
            await loadBanners()
        } catch {
            errorMessage = error.localizedDescription
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
    @State private var useSchedule = false
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    let onComplete: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("バナー情報") {
                    TextField("タイトル", text: $title)
                    TextField("画像URL", text: $imageUrl)
                    TextField("リンクURL（任意）", text: $linkUrl)
                    Toggle("公開", isOn: $isActive)
                }

                Section("公開期間") {
                    Toggle("公開期間を設定", isOn: $useSchedule)

                    if useSchedule {
                        DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
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
        errorMessage = nil

        let formatter = ISO8601DateFormatter()
        let startDateStr = useSchedule ? formatter.string(from: startDate) : nil
        let endDateStr = useSchedule ? formatter.string(from: endDate) : nil

        do {
            _ = try await APIClient.shared.createBanner(
                title: title,
                imageUrl: imageUrl,
                linkUrl: linkUrl.isEmpty ? nil : linkUrl,
                isActive: isActive,
                startDate: startDateStr,
                endDate: endDateStr
            )
            await onComplete()
            dismiss()
        } catch {
            errorMessage = "バナーの作成に失敗しました"
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

// MARK: - Admin Notification Settings View

struct AdminNotificationSettingsView: View {
    @State private var enablePushNotifications = true
    @State private var enableEmailNotifications = true
    @State private var notifyNewRegistration = true
    @State private var notifyWithdrawalRequest = true
    @State private var notifyIdentitySubmission = true
    @State private var notifyNewJobPost = false
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("プッシュ通知") {
                Toggle("プッシュ通知を有効化", isOn: $enablePushNotifications)
            }

            Section("メール通知") {
                Toggle("メール通知を有効化", isOn: $enableEmailNotifications)
            }

            Section("管理者通知トリガー") {
                Toggle("新規ユーザー登録", isOn: $notifyNewRegistration)
                Toggle("出金申請", isOn: $notifyWithdrawalRequest)
                Toggle("本人確認提出", isOn: $notifyIdentitySubmission)
                Toggle("新規求人投稿", isOn: $notifyNewJobPost)
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
                    Task { await saveSettings() }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
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
            let settings = try await APIClient.shared.getAdminSystemSettings()
            enablePushNotifications = settings.enablePushNotifications ?? true
            enableEmailNotifications = settings.enableEmailNotifications ?? true
            notifyNewRegistration = settings.notifyNewRegistration ?? true
            notifyWithdrawalRequest = settings.notifyWithdrawalRequest ?? true
            notifyIdentitySubmission = settings.notifyIdentitySubmission ?? true
            notifyNewJobPost = settings.notifyNewJobPost ?? false
        } catch {
            errorMessage = "設定の読み込みに失敗しました"
        }
        isLoading = false
    }

    private func saveSettings() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIClient.shared.updateAdminSystemSettings(settings: [
                "enablePushNotifications": enablePushNotifications,
                "enableEmailNotifications": enableEmailNotifications,
                "notifyNewRegistration": notifyNewRegistration,
                "notifyWithdrawalRequest": notifyWithdrawalRequest,
                "notifyIdentitySubmission": notifyIdentitySubmission,
                "notifyNewJobPost": notifyNewJobPost
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
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadQualifications() async {
        isLoading = true
        do {
            qualifications = try await api.getAdminQualifications(status: selectedStatus == "all" ? nil : selectedStatus)
            filterQualifications()
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    func rejectQualification(id: String, reason: String) async {
        do {
            _ = try await api.rejectQualification(qualificationId: id, reason: reason)
            await loadQualifications()
        } catch {
            errorMessage = error.localizedDescription
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
                .background(Color(.systemBackground))
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
                .background(Color(.systemBackground))
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
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
    @Published var errorMessage: String?

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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func savePrices() async {
        do {
            _ = try await api.updateAdSetting(key: "banner_price_monthly", value: bannerPrice, description: "Banner monthly price", category: "ads")
            _ = try await api.updateAdSetting(key: "promotion_price_daily", value: promoPrice, description: "Promo daily price", category: "ads")
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    func deleteBanner(id: String) async {
        do {
            _ = try await api.deleteBanner(bannerId: id)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
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
        .background(Color(.systemBackground))
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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onComplete: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("バナー画像") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let imageData = selectedImage, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
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

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
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
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImage = data
                    }
                }
            }
        }
    }

    private func addBanner() async {
        guard let imageData = selectedImage else { return }
        isLoading = true
        errorMessage = nil

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
            errorMessage = "バナーの追加に失敗しました"
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
                    .background(Color(.systemBackground))
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
                        .background(Color(.systemBackground))
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
                        .background(Color(.systemBackground))
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
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
    @Published var errorMessage: String?

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
            errorMessage = error.localizedDescription
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
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadHistory() async {
        isLoading = true
        do {
            history = try await api.getAdminNotificationHistory()
        } catch {
            errorMessage = error.localizedDescription
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
            openDownloadUrl(result.downloadUrl)
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
            openDownloadUrl(result.downloadUrl)
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
            openDownloadUrl(result.downloadUrl)
        } catch {
            message = "エクスポートに失敗しました"
            isError = true
        }
        isExportingTransactions = false
    }

    private func openDownloadUrl(_ urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Admin Revenue Wallet View

struct AdminRevenueWalletView: View {
    @StateObject private var viewModel = AdminRevenueWalletViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Balance Card
                VStack(spacing: 16) {
                    Text("収益残高")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    Text("¥\(viewModel.wallet?.balance.formatted() ?? "0")")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    if let available = viewModel.wallet?.availableBalance {
                        HStack {
                            Text("出金可能額")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("¥\(available.formatted())")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                // Quick Actions
                HStack(spacing: 12) {
                    NavigationLink(destination: AdminPlatformWithdrawalView()) {
                        AdminWalletActionCard(
                            icon: "arrow.up.circle.fill",
                            title: "出金申請",
                            color: .orange
                        )
                    }

                    NavigationLink(destination: AdminPlatformBankAccountView()) {
                        AdminWalletActionCard(
                            icon: "building.columns.fill",
                            title: "銀行口座",
                            color: .blue
                        )
                    }

                    NavigationLink(destination: AdminTransactionHistoryView(transactions: viewModel.transactions)) {
                        AdminWalletActionCard(
                            icon: "list.bullet.rectangle",
                            title: "取引履歴",
                            color: .green
                        )
                    }
                }
                .padding(.horizontal)

                // Recent Transactions
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近の取引")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.transactions.isEmpty {
                        Text("取引履歴がありません")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.transactions.prefix(5)) { transaction in
                                AdminTransactionRow(transaction: transaction)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("収益ウォレット")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

@MainActor
class AdminRevenueWalletViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var transactions: [Transaction] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            wallet = try await api.getAdminWallet()
            transactions = try await api.getAdminTransactions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct AdminWalletActionCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct AdminTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.isPositive ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(transaction.isPositive ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.typeDisplay)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let desc = transaction.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.isPositive ? "+" : "-")¥\(abs(transaction.amount).formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.isPositive ? .green : .primary)

                if let date = transaction.createdAt {
                    Text(formatTransactionDate(date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatTransactionDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "MM/dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct AdminTransactionHistoryView: View {
    let transactions: [Transaction]

    var body: some View {
        Group {
            if transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("取引履歴がありません")
                        .foregroundColor(.gray)
                }
            } else {
                List(transactions) { transaction in
                    AdminTransactionRow(transaction: transaction)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("取引履歴")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Admin Platform Bank Account View

struct AdminPlatformBankAccountView: View {
    @StateObject private var viewModel = AdminPlatformBankAccountViewModel()
    @State private var showAddSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.accounts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("銀行口座が登録されていません")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("出金するには銀行口座を登録してください")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.8))
                    Button("口座を追加") {
                        showAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List {
                    ForEach(viewModel.accounts) { account in
                        AdminPlatformBankAccountRow(account: account)
                    }
                    .onDelete { indexSet in
                        Task { await viewModel.deleteAccount(at: indexSet) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("銀行口座管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAdminBankAccountSheet {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

@MainActor
class AdminPlatformBankAccountViewModel: ObservableObject {
    @Published var accounts: [BankAccount] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            accounts = try await api.getAdminBankAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteAccount(at indexSet: IndexSet) async {
        for index in indexSet {
            let account = accounts[index]
            do {
                _ = try await api.deleteAdminBankAccount(accountId: account.id)
                accounts.remove(at: index)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct AdminPlatformBankAccountRow: View {
    let account: BankAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(account.bankName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if account.isDefault == true {
                    Text("デフォルト")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            Text("\(account.branchName) \(account.accountTypeDisplay)")
                .font(.caption)
                .foregroundColor(.gray)
            HStack {
                Text("口座番号: \(account.accountNumber)")
                    .font(.caption)
                Spacer()
                Text(account.accountHolderName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddAdminBankAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bankName = ""
    @State private var bankCode = ""
    @State private var branchName = ""
    @State private var branchCode = ""
    @State private var accountType = "ordinary"
    @State private var accountNumber = ""
    @State private var accountHolderName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSuccess: () async -> Void

    private var isValid: Bool {
        !bankName.isEmpty &&
        bankCode.count == 4 &&
        !branchName.isEmpty &&
        branchCode.count == 3 &&
        accountNumber.count == 7 &&
        !accountHolderName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("銀行情報") {
                    TextField("銀行名", text: $bankName)
                    TextField("銀行コード（4桁）", text: $bankCode)
                        .keyboardType(.numberPad)
                }

                Section("支店情報") {
                    TextField("支店名", text: $branchName)
                    TextField("支店コード（3桁）", text: $branchCode)
                        .keyboardType(.numberPad)
                }

                Section("口座情報") {
                    Picker("口座種別", selection: $accountType) {
                        Text("普通").tag("ordinary")
                        Text("当座").tag("checking")
                    }
                    TextField("口座番号（7桁）", text: $accountNumber)
                        .keyboardType(.numberPad)
                    TextField("口座名義（カタカナ）", text: $accountHolderName)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("銀行口座を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await addAccount() }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
        }
    }

    private func addAccount() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.addAdminBankAccount(
                bankName: bankName,
                bankCode: bankCode,
                branchName: branchName,
                branchCode: branchCode,
                accountType: accountType,
                accountNumber: accountNumber,
                accountHolderName: accountHolderName
            )
            await onSuccess()
            dismiss()
        } catch {
            errorMessage = "銀行口座の登録に失敗しました"
        }
        isLoading = false
    }
}

// MARK: - Admin Platform Withdrawal View

struct AdminPlatformWithdrawalView: View {
    @StateObject private var viewModel = AdminPlatformWithdrawalViewModel()
    @State private var selectedAccountId: String?
    @State private var amount = ""
    @State private var showConfirmation = false

    private var canSubmit: Bool {
        guard let accountId = selectedAccountId, !accountId.isEmpty,
              let amountInt = Int(amount), amountInt >= 1000,
              let balance = viewModel.wallet?.balance, amountInt <= balance else {
            return false
        }
        return !viewModel.isSubmitting
    }

    var body: some View {
        Form {
            Section("出金可能額") {
                HStack {
                    Text("残高")
                    Spacer()
                    Text("¥\(viewModel.wallet?.balance.formatted() ?? "0")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                if let available = viewModel.wallet?.availableBalance {
                    HStack {
                        Text("出金可能額")
                        Spacer()
                        Text("¥\(available.formatted())")
                            .foregroundColor(.blue)
                    }
                }
            }

            Section("出金先口座") {
                if viewModel.accounts.isEmpty {
                    NavigationLink("銀行口座を登録する", destination: AdminPlatformBankAccountView())
                        .foregroundColor(.blue)
                } else {
                    Picker("口座を選択", selection: $selectedAccountId) {
                        Text("選択してください").tag(nil as String?)
                        ForEach(viewModel.accounts) { account in
                            Text(account.displayText).tag(account.id as String?)
                        }
                    }
                }
            }

            Section("出金額") {
                HStack {
                    Text("¥")
                    TextField("金額を入力", text: $amount)
                        .keyboardType(.numberPad)
                }
                Text("最低出金額: ¥1,000")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section {
                Button("出金を申請する") {
                    showConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .listRowBackground(canSubmit ? Color.blue : Color.gray)
                .disabled(!canSubmit)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let success = viewModel.successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            // Withdrawal History
            if !viewModel.withdrawals.isEmpty {
                Section("出金履歴") {
                    ForEach(viewModel.withdrawals) { withdrawal in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("¥\(withdrawal.amount.formatted())")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let date = withdrawal.requestedAt {
                                    Text(formatWithdrawalDate(date))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Text(withdrawal.statusDisplay)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(withdrawalStatusColor(withdrawal.status).opacity(0.1))
                                .foregroundColor(withdrawalStatusColor(withdrawal.status))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .navigationTitle("出金申請")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("出金確認", isPresented: $showConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("申請する") {
                guard let accountId = selectedAccountId,
                      let amountInt = Int(amount) else { return }
                Task {
                    await viewModel.requestWithdrawal(accountId: accountId, amount: amountInt)
                    amount = ""
                    selectedAccountId = nil
                }
            }
        } message: {
            Text("¥\(amount)を出金申請しますか？\n処理には1〜3営業日かかります。")
        }
    }

    private func formatWithdrawalDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy/MM/dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func withdrawalStatusColor(_ status: String) -> Color {
        switch status {
        case "pending": return .orange
        case "processing": return .blue
        case "completed": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

@MainActor
class AdminPlatformWithdrawalViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var accounts: [BankAccount] = []
    @Published var withdrawals: [WithdrawalRequest] = []
    @Published var isLoading = true
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            wallet = try await api.getAdminWallet()
            accounts = try await api.getAdminBankAccounts()
            withdrawals = try await api.getAdminWithdrawalHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func requestWithdrawal(accountId: String, amount: Int) async {
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        do {
            let request = try await api.requestAdminWithdrawal(bankAccountId: accountId, amount: amount)
            withdrawals.insert(request, at: 0)
            successMessage = "¥\(amount.formatted())の出金を申請しました"
            await loadData()
        } catch {
            errorMessage = "出金申請に失敗しました"
        }
        isSubmitting = false
    }
}

// MARK: - Category Management

struct AdminCategoryManagementView: View {
    @StateObject private var viewModel = AdminCategoryManagementViewModel()
    @State private var showAddSheet = false

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.categories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("カテゴリがありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.categories) { category in
                    HStack(spacing: 12) {
                        Text(category.icon ?? "📁")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.label ?? category.name ?? "")
                                .font(.headline)
                            if let desc = category.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("#\(category.displayOrder ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteCategory(category.id) }
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("カテゴリ管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCategorySheet(onSuccess: { Task { await viewModel.loadData() } })
        }
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
    }
}

struct AddCategorySheet: View {
    @Environment(\.dismiss) var dismiss
    var onSuccess: () -> Void

    @State private var name = ""
    @State private var label = ""
    @State private var description = ""
    @State private var icon = "📁"
    @State private var displayOrder = "1"
    @State private var isLoading = false
    @State private var errorMessage: String?

    let iconOptions = ["🍔", "🏪", "🎪", "📦", "🛵", "💻", "🧹", "📋", "👵", "🏗️", "🎓", "🏥"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("カテゴリ名（英語）", text: $name)
                    TextField("表示名（日本語）", text: $label)
                    TextField("説明", text: $description)
                    TextField("表示順", text: $displayOrder)
                        .keyboardType(.numberPad)
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { emoji in
                            Button(action: { icon = emoji }) {
                                Text(emoji)
                                    .font(.title)
                                    .padding(8)
                                    .background(icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button(action: save) {
                        if isLoading { ProgressView().frame(maxWidth: .infinity) }
                        else { Text("追加").frame(maxWidth: .infinity) }
                    }
                    .disabled(isLoading || name.isEmpty || label.isEmpty)
                }
            }
            .navigationTitle("カテゴリ追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    func save() {
        isLoading = true
        Task {
            do {
                _ = try await APIClient.shared.createAdminCategory(
                    name: name, label: label, description: description,
                    icon: icon, displayOrder: Int(displayOrder) ?? 1
                )
                onSuccess()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

@MainActor
class AdminCategoryManagementViewModel: ObservableObject {
    @Published var categories: [AdminCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            categories = try await APIClient.shared.getAdminCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteCategory(_ id: String) async {
        do {
            _ = try await APIClient.shared.deleteAdminCategory(categoryId: id)
            categories.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - CMS Content Editing

struct AdminCMSContentView: View {
    @StateObject private var viewModel = AdminCMSContentViewModel()

    let contentKeys = [
        ("terms_of_service", "利用規約", "doc.text"),
        ("privacy_policy", "プライバシーポリシー", "hand.raised"),
        ("faq", "よくある質問", "questionmark.circle"),
        ("about", "Bytersについて", "info.circle"),
        ("guide_job_seeker", "求職者ガイド", "person.fill"),
        ("guide_employer", "雇用者ガイド", "building.2"),
    ]

    var body: some View {
        List {
            ForEach(contentKeys, id: \.0) { key, title, icon in
                NavigationLink(destination: AdminCMSEditorView(contentKey: key, title: title)) {
                    Label(title, systemImage: icon)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("コンテンツ編集")
    }
}

struct AdminCMSEditorView: View {
    let contentKey: String
    let title: String

    @State private var contentTitle = ""
    @State private var contentBody = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSavedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("読み込み中...")
                Spacer()
            } else {
                Form {
                    Section("タイトル") {
                        TextField("タイトル", text: $contentTitle)
                    }

                    Section("本文") {
                        TextEditor(text: $contentBody)
                            .frame(minHeight: 300)
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: save) {
                    if isSaving { ProgressView() }
                    else { Text("保存") }
                }
                .disabled(isSaving)
            }
        }
        .alert("保存しました", isPresented: $showSavedAlert) {
            Button("OK") {}
        }
        .task { await loadContent() }
    }

    func loadContent() async {
        isLoading = true
        do {
            let content = try await APIClient.shared.getAdminContent(key: contentKey)
            contentTitle = content.title ?? title
            contentBody = content.content ?? ""
        } catch {
            contentTitle = title
            contentBody = ""
        }
        isLoading = false
    }

    func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIClient.shared.updateAdminContent(
                    key: contentKey, title: contentTitle, content: contentBody
                )
                showSavedAlert = true
            } catch {
                errorMessage = "保存に失敗しました"
            }
            isSaving = false
        }
    }
}

@MainActor
class AdminCMSContentViewModel: ObservableObject {}

// MARK: - Reports / Inquiries

struct AdminReportsView: View {
    @StateObject private var viewModel = AdminReportsViewModel()
    @State private var selectedFilter = "all"
    @State private var selectedReport: AdminReport?

    let filters = [("all", "すべて"), ("pending", "対応待ち"), ("in_progress", "対応中"), ("resolved", "解決済み")]

    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.0) { key, label in
                        Button(action: {
                            selectedFilter = key
                            Task { await viewModel.loadData(status: key == "all" ? nil : key) }
                        }) {
                            Text(label)
                                .font(.subheadline)
                                .fontWeight(selectedFilter == key ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedFilter == key ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedFilter == key ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            // Stats banner
            if let stats = viewModel.stats {
                HStack(spacing: 16) {
                    StatPill(label: "待ち", count: stats.pending, color: .orange)
                    StatPill(label: "対応中", count: stats.inProgress ?? 0, color: .blue)
                    StatPill(label: "解決", count: stats.resolved, color: .green)
                    StatPill(label: "合計", count: stats.total, color: .secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Reports list
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.reports.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("通報はありません")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(viewModel.reports) { report in
                    Button(action: { selectedReport = report }) {
                        AdminReportRow(report: report)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("通報・問い合わせ")
        .refreshable { await viewModel.loadData(status: selectedFilter == "all" ? nil : selectedFilter) }
        .task {
            await viewModel.loadStats()
            await viewModel.loadData()
        }
        .sheet(item: $selectedReport) { report in
            AdminReportDetailSheet(report: report, onUpdate: {
                Task { await viewModel.loadData(status: selectedFilter == "all" ? nil : selectedFilter) }
            })
        }
    }
}

struct StatPill: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AdminReportRow: View {
    let report: AdminReport

    var statusColor: Color {
        switch report.status {
        case "pending": return .orange
        case "in_progress": return .blue
        case "resolved": return .green
        case "rejected": return .gray
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.type ?? "通報")
                    .font(.headline)
                Spacer()
                Text(report.statusDisplay)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }
            if let reason = report.reason {
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if let date = report.createdAt {
                Text(date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AdminReportDetailSheet: View {
    let report: AdminReport
    var onUpdate: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedStatus = ""
    @State private var adminNote = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("通報情報") {
                    LabeledContent("種別", value: report.type ?? "不明")
                    LabeledContent("ステータス", value: report.statusDisplay)
                    if let reason = report.reason {
                        LabeledContent("理由", value: reason)
                    }
                    if let desc = report.description {
                        Text(desc)
                            .font(.subheadline)
                    }
                }

                Section("対応") {
                    Picker("ステータス変更", selection: $selectedStatus) {
                        Text("対応待ち").tag("pending")
                        Text("対応中").tag("in_progress")
                        Text("解決済み").tag("resolved")
                        Text("却下").tag("rejected")
                    }

                    TextField("管理者メモ", text: $adminNote, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button(action: submit) {
                        if isSubmitting { ProgressView().frame(maxWidth: .infinity) }
                        else { Text("更新").frame(maxWidth: .infinity) }
                    }
                    .disabled(isSubmitting || selectedStatus.isEmpty)
                }
            }
            .navigationTitle("通報詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { selectedStatus = report.status ?? "pending" }
        }
    }

    func submit() {
        isSubmitting = true
        Task {
            do {
                _ = try await APIClient.shared.updateAdminReport(
                    reportId: report.id, status: selectedStatus,
                    adminNote: adminNote.isEmpty ? nil : adminNote
                )
                onUpdate()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

@MainActor
class AdminReportsViewModel: ObservableObject {
    @Published var reports: [AdminReport] = []
    @Published var stats: AdminReportStats?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadData(status: String? = nil) async {
        isLoading = true
        do {
            reports = try await APIClient.shared.getAdminReports(status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadStats() async {
        do {
            stats = try await APIClient.shared.getAdminReportStats()
        } catch {
            // Stats are non-critical
        }
    }
}

// MARK: - API Key Management

struct AdminAPIKeysView: View {
    @StateObject private var viewModel = AdminAPIKeysViewModel()
    @State private var showGlobalKeys = false

    var body: some View {
        List {
            Section("グローバルAPIキー") {
                Button(action: { showGlobalKeys = true }) {
                    Label("外部APIキー設定", systemImage: "key.fill")
                }
            }

            Section("アプリケーションAPIキー") {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if viewModel.apiKeys.isEmpty {
                    Text("APIキーがありません")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(viewModel.apiKeys) { key in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(key.name ?? "不明")
                                    .font(.headline)
                                Spacer()
                                Circle()
                                    .fill(key.isActive == true ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                            }
                            if let desc = key.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let usage = key.usageCount {
                                Text("使用回数: \(usage)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteKey(key.id) }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(.red).font(.caption) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("APIキー管理")
        .sheet(isPresented: $showGlobalKeys) {
            AdminGlobalAPIKeysSheet()
        }
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
    }
}

struct AdminGlobalAPIKeysSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var googleMapsKey = ""
    @State private var stripePk = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section { ProgressView("読み込み中...") }
                } else {
                    Section("Google Maps") {
                        SecureField("Google Maps API Key", text: $googleMapsKey)
                            .textContentType(.none)
                    }

                    Section("Stripe") {
                        SecureField("Stripe Publishable Key", text: $stripePk)
                            .textContentType(.none)
                    }

                    if let error = errorMessage {
                        Section { Text(error).foregroundColor(.red) }
                    }

                    Section {
                        Button(action: save) {
                            if isSaving { ProgressView().frame(maxWidth: .infinity) }
                            else { Text("保存").frame(maxWidth: .infinity) }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle("外部APIキー設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("保存しました", isPresented: $showSavedAlert) {
                Button("OK") {}
            }
            .task { await loadKeys() }
        }
    }

    func loadKeys() async {
        isLoading = true
        do {
            let keys = try await APIClient.shared.getAdminGlobalAPIKeys()
            googleMapsKey = keys.googleMapsApiKey ?? ""
            stripePk = keys.stripePk ?? ""
        } catch {}
        isLoading = false
    }

    func save() {
        isSaving = true
        Task {
            do {
                _ = try await APIClient.shared.updateAdminGlobalAPIKeys(keys: [
                    "google_maps_api_key": googleMapsKey,
                    "stripe_publishable_key": stripePk
                ])
                showSavedAlert = true
            } catch {
                errorMessage = "保存に失敗しました"
            }
            isSaving = false
        }
    }
}

@MainActor
class AdminAPIKeysViewModel: ObservableObject {
    @Published var apiKeys: [AdminAPIKey] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadData() async {
        isLoading = true
        do {
            apiKeys = try await APIClient.shared.getAdminAPIKeys()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteKey(_ id: String) async {
        do {
            _ = try await APIClient.shared.deleteAdminAPIKey(keyId: id)
            apiKeys.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Security / Access Logs

struct AdminSecurityView: View {
    @StateObject private var viewModel = AdminSecurityViewModel()

    var body: some View {
        List {
            Section("アクセスログ") {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if viewModel.logs.isEmpty {
                    Text("アクセスログがありません")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(viewModel.logs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.blue)
                                Text(log.adminName ?? log.adminId ?? "不明")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if let status = log.status {
                                    Text(status)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(status == "success" ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                                        .foregroundColor(status == "success" ? .green : .red)
                                        .clipShape(Capsule())
                                }
                            }
                            if let action = log.action {
                                Text(action)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                if let ip = log.ipAddress {
                                    Label(ip, systemImage: "network")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let ts = log.timestamp {
                                    Text(ts)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(.red).font(.caption) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("セキュリティ")
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
    }
}

@MainActor
class AdminSecurityViewModel: ObservableObject {
    @Published var logs: [AdminAccessLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadData() async {
        isLoading = true
        do {
            logs = try await APIClient.shared.getAdminAccessLogs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Optional Features

struct AdminOptionalFeaturesView: View {
    @StateObject private var viewModel = AdminOptionalFeaturesViewModel()

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section { ProgressView("読み込み中...") }
            } else {
                Section(header: Text("本人確認"), footer: Text("自動承認を有効にすると、書類提出後に自動的に承認されます")) {
                    Picker("承認モード", selection: $viewModel.kycMode) {
                        Text("手動承認").tag("manual")
                        Text("自動承認").tag("auto")
                    }
                }

                Section(header: Text("出金"), footer: Text("自動処理を有効にすると、出金申請が自動的に処理されます")) {
                    Toggle("自動処理", isOn: $viewModel.autoProcessWithdrawals)
                }

                Section(header: Text("求人"), footer: Text("自動承認を有効にすると、新規求人投稿が即座に公開されます")) {
                    Toggle("求人の自動承認", isOn: $viewModel.autoApproveJobs)
                }

                Section(header: Text("チャット"), footer: Text("画像送信を無効にするとテキストのみに制限されます")) {
                    Toggle("画像送信を許可", isOn: $viewModel.chatImageEnabled)
                }

                Section(header: Text("通知"), footer: Text("メール通知を有効にするとユーザーにメールも送信されます")) {
                    Toggle("メール通知", isOn: $viewModel.emailNotificationsEnabled)
                    Toggle("プッシュ通知", isOn: $viewModel.pushNotificationsEnabled)
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundColor(.red).font(.caption) }
                }

                if let message = viewModel.savedMessage {
                    Section { Text(message).foregroundColor(.green).font(.caption) }
                }

                Section {
                    Button(action: { Task { await viewModel.save() } }) {
                        if viewModel.isSaving { ProgressView().frame(maxWidth: .infinity) }
                        else {
                            Text("設定を保存")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .navigationTitle("オプション機能")
        .task { await viewModel.loadData() }
    }
}

@MainActor
class AdminOptionalFeaturesViewModel: ObservableObject {
    @Published var kycMode = "manual"
    @Published var autoProcessWithdrawals = false
    @Published var autoApproveJobs = false
    @Published var chatImageEnabled = true
    @Published var emailNotificationsEnabled = true
    @Published var pushNotificationsEnabled = true
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var savedMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            _ = try await api.getAdminSystemSettings()
            if let kycSettings = try? await api.getKycSettings() {
                kycMode = kycSettings.approvalMode
            }
        } catch {}
        isLoading = false
    }

    func save() async {
        isSaving = true
        savedMessage = nil
        errorMessage = nil
        do {
            _ = try await api.updateKycSettings(approvalMode: kycMode)

            _ = try await api.updateAdminSystemSettings(key: "auto_process_withdrawals", value: "\(autoProcessWithdrawals)")
            _ = try await api.updateAdminSystemSettings(key: "auto_approve_jobs", value: "\(autoApproveJobs)")
            _ = try await api.updateAdminSystemSettings(key: "chat_image_enabled", value: "\(chatImageEnabled)")
            _ = try await api.updateAdminSystemSettings(key: "email_notifications_enabled", value: "\(emailNotificationsEnabled)")
            _ = try await api.updateAdminSystemSettings(key: "push_notifications_enabled", value: "\(pushNotificationsEnabled)")

            savedMessage = "設定を保存しました"
        } catch {
            errorMessage = "保存に失敗しました"
        }
        isSaving = false
    }
}

#Preview {
    AdminDashboardView()
}
