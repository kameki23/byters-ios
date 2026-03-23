import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var showReviewSheet = false
    @State private var showJobAlertSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    HomeSkeletonView()
                        .transition(.opacity)
                } else {
                LazyVStack(spacing: 0) {
                    // Error Banner (inline, non-blocking)
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                Task { await viewModel.loadData() }
                            }) {
                                Text("再試行")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.25))
                                    .clipShape(Capsule())
                            }
                            .accessibilityLabel("データの再読み込み")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Profile Completion Nudge
                    if let completion = viewModel.profileCompletion, completion.percentage < 100 {
                        ProfileCompletionBanner(completion: completion)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .accessibilityLabel("プロフィール完成度: \(completion.percentage)パーセント")
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    // Mandatory Review Prompt
                    if viewModel.pendingReviewCount > 0 {
                        MandatoryReviewPromptView(
                            pendingCount: viewModel.pendingReviewCount,
                            onReviewNow: { showReviewSheet = true }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .accessibilityElement(children: .contain)
                    }

                    // Banner Carousel
                    if !viewModel.banners.isEmpty {
                        BannerCarouselView(banners: viewModel.banners)
                            .padding(.top, 12)
                            .transition(.opacity)
                    }

                    // Worker Score Card
                    if let score = viewModel.workerScore {
                        WorkerScoreCard(score: score)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .accessibilityLabel("ワーカーランク: \(score.rankDisplay)、完了件数: \(score.completedJobs)件")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Quick Stats
                    HStack(spacing: 12) {
                        MiniStatCard(title: "応募中", value: "\(viewModel.pendingApplications)", icon: "clock.fill", color: .orange)
                            .accessibilityLabel("応募中の件数: \(viewModel.pendingApplications)件")
                        MiniStatCard(title: "予定", value: "\(viewModel.upcomingWork)", icon: "calendar", color: .blue)
                            .accessibilityLabel("予定のお仕事: \(viewModel.upcomingWork)件")
                        MiniStatCard(title: "残高", value: "¥\(viewModel.walletBalance.formatted())", icon: "yensign.circle.fill", color: .green)
                            .accessibilityLabel("ウォレット残高: \(viewModel.walletBalance)円")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Category Shortcuts
                    CategoryShortcutsView(categories: viewModel.categories)
                        .padding(.top, 20)

                    // Urgent Jobs Section
                    if !viewModel.urgentJobs.isEmpty {
                        JobSectionView(
                            title: "今すぐ働ける",
                            icon: "bolt.fill",
                            iconColor: .red,
                            badge: "急募 \(viewModel.urgentJobs.count)件",
                            jobs: viewModel.urgentJobs,
                            isLoading: false
                        )
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Today's Jobs Section
                    if !viewModel.todayJobs.isEmpty {
                        JobSectionView(
                            title: "今日働ける求人",
                            icon: "sun.max.fill",
                            iconColor: .orange,
                            badge: "\(viewModel.todayJobs.count)件",
                            jobs: viewModel.todayJobs,
                            isLoading: false
                        )
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Featured Jobs Section
                    JobSectionView(
                        title: "おすすめの求人",
                        icon: "sparkles",
                        iconColor: .yellow,
                        badge: nil,
                        jobs: viewModel.featuredJobs,
                        isLoading: false
                    )
                    .padding(.top, 20)

                    // High Wage Jobs
                    if !viewModel.highWageJobs.isEmpty {
                        JobSectionView(
                            title: "高時給の求人",
                            icon: "flame.fill",
                            iconColor: .red,
                            badge: nil,
                            jobs: viewModel.highWageJobs,
                            isLoading: false
                        )
                        .padding(.top, 20)
                    }

                    // Recent Applications
                    if !viewModel.recentApplications.isEmpty {
                        RecentApplicationsSection(applications: viewModel.recentApplications)
                            .padding(.top, 20)
                    }

                    // Monthly Summary
                    if let summary = viewModel.monthlySummary {
                        MonthlySummaryCard(summary: summary)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }

                    Spacer().frame(height: 32)
                }
                .animation(.easeOut(duration: 0.3), value: viewModel.errorMessage != nil)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: viewModel.isLoading)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showJobAlertSheet = true }) {
                        Image(systemName: "bell.badge.waveform.fill")
                            .foregroundColor(.teal)
                    }
                    .accessibilityLabel("ジョブアラート設定")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: NotificationListView()) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("通知一覧を表示")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showReviewSheet) {
                NavigationStack {
                    PendingReviewsView()
                }
            }
            .sheet(isPresented: $showJobAlertSheet) {
                JobAlertSettingsView()
            }
        }
        .task {
            AnalyticsService.shared.trackScreenView("home")
            await viewModel.loadData()
        }
    }
}

// MARK: - View Model

@MainActor
class HomeViewModel: ObservableObject {
    @Published var featuredJobs: [Job] = []
    @Published var todayJobs: [Job] = []
    @Published var urgentJobs: [Job] = []
    @Published var highWageJobs: [Job] = []
    @Published var recentApplications: [Application] = []
    @Published var walletBalance: Int = 0
    @Published var pendingApplications: Int = 0
    @Published var upcomingWork: Int = 0
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var workerScore: WorkerScore?
    @Published var profileCompletion: ProfileCompletion?
    @Published var banners: [HomeBanner] = []
    @Published var categories: [JobCategory] = []
    @Published var monthlySummary: MonthlySummary?
    @Published var pendingReviewCount: Int = 0

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        errorMessage = nil

        // Cache-First: キャッシュがあれば即座に表示（電波状況が悪くてもUIが見える）
        loadFromCache()

        // キャッシュで表示できればローディングを即解除
        if !featuredJobs.isEmpty {
            isLoading = false
        }

        // Phase 1: Critical data (visible immediately on screen)
        async let jobsTask: Void = loadJobs()
        async let applicationsTask: Void = loadApplications()
        async let walletTask: Void = loadWallet()
        async let scoreTask: Void = loadWorkerScore()

        _ = await (jobsTask, applicationsTask, walletTask, scoreTask)

        // Show the screen with critical data while loading the rest
        isLoading = false

        // Phase 2: Non-critical data (loaded in background after screen appears)
        async let profileTask: Void = loadProfileCompletion()
        async let bannersTask: Void = loadBanners()
        async let categoriesTask: Void = loadCategories()
        async let summaryTask: Void = loadMonthlySummary()
        async let reviewsTask: Void = loadPendingReviewCount()

        _ = await (profileTask, bannersTask, categoriesTask, summaryTask, reviewsTask)
    }

    /// キャッシュからデータを即座にロード（ネットワーク不要）
    private func loadFromCache() {
        if let cached = CacheService.shared.load([Job].self, forKey: "jobs_page1") {
            featuredJobs = cached
            let today = DateFormatter.yyyyMMdd.string(from: Date())
            todayJobs = cached.filter { $0.workDate == today && $0.status != "closed" && $0.status != "expired" }
            let tomorrow = DateFormatter.yyyyMMdd.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            urgentJobs = cached.filter { filterUrgentJob($0, today: today, tomorrow: tomorrow) }
            highWageJobs = cached.filter { ($0.hourlyWage ?? 0) >= 1500 }
                .sorted { ($0.hourlyWage ?? 0) > ($1.hourlyWage ?? 0) }
        }
        if let cached = CacheService.shared.load([Application].self, forKey: "my_applications") {
            recentApplications = cached
            pendingApplications = cached.filter { $0.status == "pending" }.count
            upcomingWork = cached.filter { $0.status == "accepted" }.count
        }
        if let cached = CacheService.shared.load(Wallet.self, forKey: "wallet") {
            walletBalance = cached.balance
        }
        if let cached = CacheService.shared.load(WorkerScore.self, forKey: "worker_score") {
            workerScore = cached
        }
        if let cached = CacheService.shared.load([JobCategory].self, forKey: "categories") {
            categories = cached
        }
    }

    private func filterUrgentJob(_ job: Job, today: String, tomorrow: String) -> Bool {
        let isActive = job.status != "closed" && job.status != "expired"
        let isSoon = job.workDate == today || job.workDate == tomorrow
        let hasSlots = (job.requiredPeople ?? 0) - (job.currentApplicants ?? 0) > 0
        return isActive && isSoon && hasSlots
    }

    func refresh() async {
        await loadData()
    }

    private func loadJobs() async {
        do {
            let allJobs = try await api.getJobs()
            featuredJobs = allJobs

            // Today's jobs
            let today = DateFormatter.yyyyMMdd.string(from: Date())
            todayJobs = allJobs.filter { $0.workDate == today && $0.status != "closed" && $0.status != "expired" }

            // Urgent jobs - today/tomorrow with available slots
            let tomorrow = DateFormatter.yyyyMMdd.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            urgentJobs = allJobs.filter { job in
                let isActive = job.status != "closed" && job.status != "expired"
                let isSoon = job.workDate == today || job.workDate == tomorrow
                let hasSlots = (job.requiredPeople ?? 0) - (job.currentApplicants ?? 0) > 0
                return isActive && isSoon && hasSlots
            }

            // High wage jobs (>= 1500 yen)
            highWageJobs = allJobs
                .filter { ($0.hourlyWage ?? 0) >= 1500 }
                .sorted { ($0.hourlyWage ?? 0) > ($1.hourlyWage ?? 0) }
        } catch {
            errorMessage = "求人の読み込みに失敗しました"
        }
    }

    private func loadApplications() async {
        do {
            let apps = try await api.getMyApplications()
            recentApplications = apps
            pendingApplications = apps.filter { $0.status == "pending" }.count
            upcomingWork = apps.filter { $0.status == "accepted" }.count
        } catch {
            // Non-critical
        }
    }

    private func loadWallet() async {
        do {
            let wallet = try await api.getWallet()
            walletBalance = wallet.balance
        } catch {
            // Non-critical
        }
    }

    private func loadWorkerScore() async {
        do {
            workerScore = try await api.getWorkerScore()
        } catch {
            // Non-critical - new users won't have a score yet
        }
    }

    private func loadProfileCompletion() async {
        do {
            profileCompletion = try await api.getProfileCompletion()
        } catch {
            // Non-critical
        }
    }

    private func loadBanners() async {
        do {
            banners = try await api.getHomeBanners()
        } catch {
            // Non-critical
        }
    }

    private func loadCategories() async {
        do {
            categories = try await api.getCategories()
        } catch {
            // Non-critical
        }
    }

    private func loadMonthlySummary() async {
        do {
            monthlySummary = try await api.getMonthlySummary()
        } catch {
            // Non-critical
        }
    }

    private func loadPendingReviewCount() async {
        do {
            let reviews = try await api.getPendingReviews()
            pendingReviewCount = reviews.count
        } catch {
            // Non-critical
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Profile Completion Banner

struct ProfileCompletionBanner: View {
    let completion: ProfileCompletion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text("プロフィールを完成させよう")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(completion.percentage)%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            ProgressView(value: Double(completion.percentage), total: 100)
                .tint(.orange)

            if !completion.missingFieldsDisplay.isEmpty {
                Text("未設定: \(completion.missingFieldsDisplay.prefix(3).joined(separator: "、"))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Banner Carousel

struct BannerCarouselView: View {
    let banners: [HomeBanner]
    @State private var currentIndex = 0

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                BannerItemView(banner: banner)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

struct BannerItemView: View {
    let banner: HomeBanner

    var body: some View {
        ZStack {
            if let imageUrl = banner.imageUrl, let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url) {
                    bannerPlaceholder
                }
                .scaledToFill()
            } else {
                bannerPlaceholder
            }

            VStack(alignment: .leading) {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text(banner.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bannerPlaceholder: some View {
        LinearGradient(
            colors: [.blue, .blue.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Worker Score Card

struct WorkerScoreCard: View {
    let score: WorkerScore

    // Compute grade from completed jobs (Timee-style)
    private var grade: (name: String, icon: String) {
        let jobs = score.completedJobs
        if jobs >= 100 { return ("MASTER", "crown.fill") }
        if jobs >= 50 { return ("ACE", "star.circle.fill") }
        if jobs >= 20 { return ("HOPE", "arrow.up.circle.fill") }
        return ("ROOKIE", "person.fill")
    }

    // EXP calculation (approx 60 EXP per hour worked)
    private var expPoints: Int {
        score.completedJobs * 480 // ~8 hours avg * 60 EXP
    }

    // Level calculation (progressive curve)
    private var level: Int {
        let exp = expPoints
        if exp <= 0 { return 1 }
        // Simple formula: level = sqrt(exp / 100)
        return max(1, Int(sqrt(Double(exp) / 100.0)) + 1)
    }

    private var nextLevelExp: Int {
        let nextLevel = level + 1
        return (nextLevel - 1) * (nextLevel - 1) * 100
    }

    var body: some View {
        VStack(spacing: 12) {
            // Grade & Level Header
            HStack(spacing: 16) {
                // Grade Icon
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(gradeColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: grade.icon)
                            .font(.title2)
                            .foregroundColor(gradeColor)
                    }
                    Text(grade.name)
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(gradeColor)
                }

                // Level & EXP
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Lv.\(level)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(score.rankDisplay)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(rankColor)
                            .clipShape(Capsule())
                    }

                    // EXP Progress
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("EXP \(expPoints)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("次のLvまで \(max(0, nextLevelExp - expPoints))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        ProgressView(value: Double(expPoints), total: Double(nextLevelExp))
                            .tint(gradeColor)
                    }
                }

                Spacer()
            }

            Divider()

            // Stats Row
            HStack(spacing: 0) {
                WorkerStatPill(icon: "briefcase.fill", color: .blue, label: "完了", value: "\(score.completedJobs)件")
                WorkerStatPill(icon: "hand.thumbsup.fill", color: .green, label: "Good率", value: "\(score.goodRatePercent)%")
                WorkerStatPill(icon: "shield.checkered", color: .purple, label: "信頼度", value: "\(score.reliabilityScore)")
            }

            // Next Rank Progress
            if let nextRank = score.nextRankJobs, nextRank > 0 {
                HStack(spacing: 4) {
                    Text("次のグレード(\(nextGradeName))まであと\(nextRank)件")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var gradeColor: Color {
        switch grade.name {
        case "MASTER": return .purple
        case "ACE": return .red
        case "HOPE": return .blue
        default: return .gray
        }
    }

    private var rankColor: Color {
        switch score.rank {
        case "diamond": return .purple
        case "gold": return .yellow
        case "silver": return .gray
        case "bronze": return .orange
        default: return .blue
        }
    }

    private var nextGradeName: String {
        let jobs = score.completedJobs
        if jobs < 20 { return "HOPE" }
        if jobs < 50 { return "ACE" }
        if jobs < 100 { return "MASTER" }
        return "MAX"
    }
}

struct WorkerStatPill: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Category Shortcuts

struct CategoryShortcutsView: View {
    let categories: [JobCategory]

    private let defaultCategories: [(name: String, icon: String, color: Color)] = [
        ("飲食", "fork.knife", .orange),
        ("軽作業", "shippingbox.fill", .blue),
        ("イベント", "party.popper.fill", .purple),
        ("オフィス", "desktopcomputer", .green),
        ("販売", "bag.fill", .pink),
        ("清掃", "sparkles", .teal),
        ("配送", "car.fill", .indigo),
        ("介護", "heart.fill", .red)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カテゴリから探す")
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(displayCategories.enumerated()), id: \.offset) { _, cat in
                        NavigationLink(destination: JobSearchView()) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(cat.color.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Image(systemName: cat.icon)
                                            .font(.title3)
                                            .foregroundColor(cat.color)
                                    )
                                Text(cat.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(cat.name)カテゴリの求人を検索")
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var displayCategories: [(name: String, icon: String, color: Color)] {
        if categories.isEmpty {
            return defaultCategories
        }
        return categories.prefix(8).enumerated().map { index, cat in
            let fallback = index < defaultCategories.count ? defaultCategories[index] : defaultCategories[0]
            return (
                name: cat.name,
                icon: cat.iconName ?? fallback.icon,
                color: fallback.color
            )
        }
    }
}

// MARK: - Job Section View

struct JobSectionView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let badge: String?
    let jobs: [Job]
    let isLoading: Bool
    var showAllAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)

                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(iconColor)
                        .clipShape(Capsule())
                }

                Spacer()

                if let showAllAction = showAllAction {
                    Button(action: showAllAction) {
                        HStack(spacing: 2) {
                            Text("すべて見る")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel("\(title)をすべて見る")
                }
            }
            .padding(.horizontal, 16)

            if isLoading {
                SkeletonList(count: 3)
            } else if jobs.isEmpty {
                EmptyStateView(
                    icon: "briefcase",
                    title: "求人がありません",
                    message: "新しい求人が登録されるまでお待ちください"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(jobs.prefix(10)) { job in
                            NavigationLink(destination: JobDetailView(jobId: job.id)) {
                                HomeJobCard(job: job)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Home Job Card (Enhanced)

struct HomeJobCard: View {
    let job: Job

    private var isExpired: Bool {
        job.status == "closed" || job.status == "expired" || job.isExpired == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image or placeholder
            ZStack(alignment: .topTrailing) {
                if let imageUrl = job.imageUrl, let url = URL(string: imageUrl) {
                    CachedAsyncImage(url: url) {
                        jobImagePlaceholder
                    }
                    .scaledToFill()
                } else {
                    jobImagePlaceholder
                }

                if isExpired {
                    Text("募集終了")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.8))
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            .frame(width: 220, height: 110)
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Date badge
                if let date = job.workDate {
                    Text(formatWorkDate(date))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(job.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                // Location
                HStack(spacing: 3) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                    Text(job.locationDisplay)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundColor(.gray)

                // Time
                if !job.timeDisplay.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(job.timeDisplay)
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                }

                // Perk tags
                let perks = job.perkTags
                if !perks.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(perks.prefix(2), id: \.rawValue) { perk in
                            Text(perk.rawValue)
                                .font(.system(size: 9))
                                .foregroundColor(perkColor(perk))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(perkColor(perk).opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Wage
                HStack {
                    Text(job.wageDisplay)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isExpired ? .gray : .blue)

                    Spacer()

                    if let required = job.requiredPeople, let current = job.currentApplicants {
                        let remaining = max(0, required - current)
                        if remaining > 0 && !isExpired {
                            Text("残\(remaining)名")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(10)
        }
        .frame(width: 220)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        .opacity(isExpired ? 0.7 : 1.0)
    }

    private var jobImagePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "briefcase.fill")
                    .font(.title2)
                    .foregroundColor(.blue.opacity(0.4))
            )
    }

    private func perkColor(_ perk: JobPerk) -> Color {
        switch perk {
        case .transportation: return .blue
        case .meal: return .orange
        case .beginner: return .purple
        }
    }

    private static let inputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return f
    }()

    private func formatWorkDate(_ dateString: String) -> String {
        guard let date = Self.inputDateFormatter.date(from: dateString) else { return dateString }
        if Calendar.current.isDateInToday(date) {
            return "今日"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "明日"
        } else {
            return Self.displayDateFormatter.string(from: date)
        }
    }
}

// MARK: - Recent Applications Section

struct RecentApplicationsSection: View {
    let applications: [Application]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text("最近の応募")
                    .font(.headline)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(applications.prefix(3)) { app in
                    NavigationLink(destination: JobDetailView(jobId: app.jobId)) {
                        HomeApplicationRow(application: app)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Monthly Summary Card

struct MonthlySummaryCard: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("今月のサマリー")
                    .font(.headline)
            }

            HStack(spacing: 0) {
                SummaryItem(title: "収入", value: "¥\(summary.totalEarnings.formatted())", color: .green)
                Divider().frame(height: 40)
                SummaryItem(title: "お仕事", value: "\(summary.totalJobs)件", color: .blue)
                Divider().frame(height: 40)
                SummaryItem(title: "時間", value: String(format: "%.1fh", summary.totalHours), color: .orange)
                Divider().frame(height: 40)
                SummaryItem(title: "完了率", value: String(format: "%.0f%%", summary.completionRate * 100), color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Existing Subviews (kept)

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct JobCard: View {
    let job: Job

    private var isExpired: Bool {
        job.status == "closed" || job.status == "expired" || job.isExpired == true
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text(job.employerName ?? "企業名")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(job.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    Text(job.locationDisplay)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text(job.wageDisplay)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isExpired ? .gray : .blue)
            }
            .frame(width: 200, height: 160)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .opacity(isExpired ? 0.7 : 1.0)

            if isExpired {
                Text("募集終了")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray)
                    .clipShape(Capsule())
                    .padding(8)
            }
        }
    }
}

struct HomeApplicationRow: View {
    let application: Application

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor(application.status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(application.jobTitle ?? "求人")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(application.employerName ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let date = application.workDate {
                        Text(date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            Text(application.statusDisplay)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor(application.status).opacity(0.1))
                .foregroundColor(statusColor(application.status))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "pending": return .orange
        case "accepted": return .green
        case "rejected": return .red
        case "completed": return .blue
        default: return .gray
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var retryAction: (() async -> Void)? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(.gray)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)

            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }

            if let retryAction = retryAction {
                Button(action: {
                    Task { await retryAction() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("再試行")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager.shared)
        .environmentObject(AppState())
}
