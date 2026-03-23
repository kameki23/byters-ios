import SwiftUI
import PhotosUI

// MARK: - Japanese Text Helpers

private extension Character {
    var isKatakana: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x30A0...0x30FF).contains(scalar.value)
    }

    var isHiragana: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x3040...0x309F).contains(scalar.value)
    }
}

private extension String {
    /// ひらがなをカタカナに変換
    func toKatakana() -> String {
        var result = ""
        for scalar in unicodeScalars {
            if (0x3040...0x309F).contains(scalar.value),
               let katakana = Unicode.Scalar(scalar.value + 0x60) {
                result.unicodeScalars.append(katakana)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// カタカナ（＋スペース・長音）として有効か
    var isValidBankAccountName: Bool {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { char in
            char.isKatakana || char == "　" || char == " " || char == "ー"
        }
    }
}

// MARK: - MyPage Navigation Destinations

enum MyPageDestination: Hashable {
    case walletDetail, bankAccountList, withdrawal, transactionHistory, taxDocuments
    case upcomingWork, applicationHistory, workHistory, workCertificateList
    case favorites, favoriteEmployers, pendingReviews, myReviews, jobAlertSettings, savedSearches
    case workerScoreDetail, penaltyHistory, monthlySummaries, earningsGoal, qualifications, badges
    case profileEdit, identityVerification, timesheetAdjustment, changePassword
    case notificationList, notificationSettings, emailSettings, locationSettings, appearanceSettings, languageSettings, mutedEmployers
    case referralProgram
    case helpCenter, faq, contact, bugReport, feedbackHistory
    case termsOfService, privacyPolicy
}

struct MyPageView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MyPageViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountFinalConfirm = false
    @State private var isDeletingAccount = false

    private func deleteMyAccount() async {
        isDeletingAccount = true
        do {
            _ = try await APIClient.shared.deleteMyAccount()
            authManager.logout()
        } catch {
            viewModel.errorMessage = error.localizedDescription
            isDeletingAccount = false
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    // Error Display
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    // Profile Header with Edit Button
                    ProfileHeaderView(user: authManager.currentUser, onEditProfile: {
                        navigationPath.append(MyPageDestination.profileEdit)
                    })
                    .padding(.bottom, 16)

                    // Worker Rank Section
                    if let score = viewModel.workerScore {
                        MyPageWorkerRankCard(score: score)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    }

                    // Monthly Summary Section
                    if let summary = viewModel.monthlySummary {
                        MyPageMonthlySummaryCard(summary: summary)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    }

                    // Menu Sections
                    VStack(spacing: 12) {
                        // Wallet Section
                        MenuSection(title: "ウォレット") {
                            MenuNavRow(icon: "yensign.circle.fill", iconColor: .green, title: "残高", value: "¥\(viewModel.walletBalance.formatted())") {
                                navigationPath.append(MyPageDestination.walletDetail)
                            }
                            MenuNavRow(icon: "building.columns.fill", iconColor: .blue, title: "銀行口座") {
                                navigationPath.append(MyPageDestination.bankAccountList)
                            }
                            MenuNavRow(icon: "arrow.down.circle.fill", iconColor: .purple, title: "出金申請") {
                                navigationPath.append(MyPageDestination.withdrawal)
                            }
                            MenuNavRow(icon: "list.bullet.rectangle.fill", iconColor: .orange, title: "取引履歴") {
                                navigationPath.append(MyPageDestination.transactionHistory)
                            }
                            MenuNavRow(icon: "doc.text.fill", iconColor: .blue, title: "源泉徴収票") {
                                navigationPath.append(MyPageDestination.taxDocuments)
                            }
                        }

                        // Work Section
                        MenuSection(title: "お仕事") {
                            MenuNavRow(icon: "calendar.badge.clock", iconColor: .blue, title: "予定のお仕事") {
                                navigationPath.append(MyPageDestination.upcomingWork)
                            }
                            MenuNavRow(icon: "doc.text.fill", iconColor: .orange, title: "応募履歴") {
                                navigationPath.append(MyPageDestination.applicationHistory)
                            }
                            MenuNavRow(icon: "clock.fill", iconColor: .purple, title: "勤務履歴") {
                                navigationPath.append(MyPageDestination.workHistory)
                            }
                            MenuNavRow(icon: "doc.text.fill", iconColor: .teal, title: "就業証明書") {
                                navigationPath.append(MyPageDestination.workCertificateList)
                            }
                            MenuNavRow(icon: "heart.fill", iconColor: .red, title: "お気に入り求人") {
                                navigationPath.append(MyPageDestination.favorites)
                            }
                            MenuNavRow(icon: "building.2.fill", iconColor: .pink, title: "お気に入り事業者") {
                                navigationPath.append(MyPageDestination.favoriteEmployers)
                            }
                            MenuNavRow(icon: "star.fill", iconColor: .yellow, title: "レビューを書く", value: viewModel.pendingReviewCount > 0 ? "\(viewModel.pendingReviewCount)件" : nil) {
                                navigationPath.append(MyPageDestination.pendingReviews)
                            }
                            MenuNavRow(icon: "star.bubble.fill", iconColor: .blue, title: "レビュー履歴") {
                                navigationPath.append(MyPageDestination.myReviews)
                            }
                            MenuNavRow(icon: "bell.badge.fill", iconColor: .teal, title: "ジョブアラート") {
                                navigationPath.append(MyPageDestination.jobAlertSettings)
                            }
                            MenuNavRow(icon: "magnifyingglass.circle.fill", iconColor: .indigo, title: "保存した検索条件") {
                                navigationPath.append(MyPageDestination.savedSearches)
                            }
                        }

                        // Growth Section
                        MenuSection(title: "スキルアップ") {
                            MenuNavRow(icon: "chart.line.uptrend.xyaxis", iconColor: .purple, title: "ワーカーランク・信頼度", value: viewModel.workerScore?.rankDisplay) {
                                navigationPath.append(MyPageDestination.workerScoreDetail)
                            }
                            MenuNavRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "ペナルティ履歴", value: viewModel.penaltyCount > 0 ? "\(viewModel.penaltyCount)件" : nil) {
                                navigationPath.append(MyPageDestination.penaltyHistory)
                            }
                            MenuNavRow(icon: "chart.bar.fill", iconColor: .blue, title: "月次レポート") {
                                navigationPath.append(MyPageDestination.monthlySummaries)
                            }
                            MenuNavRow(icon: "target", iconColor: .green, title: "収入目標") {
                                navigationPath.append(MyPageDestination.earningsGoal)
                            }
                            MenuNavRow(icon: "checkmark.seal.fill", iconColor: .blue, title: "資格・免許") {
                                navigationPath.append(MyPageDestination.qualifications)
                            }
                            MenuNavRow(icon: "star.circle.fill", iconColor: .yellow, title: "バッジ") {
                                navigationPath.append(MyPageDestination.badges)
                            }
                        }

                        // Account Section
                        MenuSection(title: "アカウント") {
                            MenuNavRow(icon: "person.fill", iconColor: .blue, title: "プロフィール編集") {
                                navigationPath.append(MyPageDestination.profileEdit)
                            }
                            MenuNavRow(icon: "checkmark.shield.fill", iconColor: .green, title: "本人確認", value: authManager.currentUser?.identityStatusDisplay ?? "未提出", valueColor: identityStatusColor(authManager.currentUser?.identityVerificationStatus)) {
                                navigationPath.append(MyPageDestination.identityVerification)
                            }
                            MenuNavRow(icon: "clock.arrow.2.circlepath", iconColor: .purple, title: "勤務時間修正") {
                                navigationPath.append(MyPageDestination.timesheetAdjustment)
                            }
                            MenuNavRow(icon: "lock.fill", iconColor: .gray, title: "パスワード変更") {
                                navigationPath.append(MyPageDestination.changePassword)
                            }
                        }

                        // Settings Section
                        MenuSection(title: "設定") {
                            MenuNavRow(icon: "bell.badge.fill", iconColor: .orange, title: "通知一覧") {
                                navigationPath.append(MyPageDestination.notificationList)
                            }
                            MenuNavRow(icon: "bell.fill", iconColor: .red, title: "通知設定") {
                                navigationPath.append(MyPageDestination.notificationSettings)
                            }
                            MenuNavRow(icon: "envelope.fill", iconColor: .blue, title: "メール設定") {
                                navigationPath.append(MyPageDestination.emailSettings)
                            }
                            MenuNavRow(icon: "location.fill", iconColor: .green, title: "エリア設定") {
                                navigationPath.append(MyPageDestination.locationSettings)
                            }
                            MenuNavRow(icon: "moon.fill", iconColor: .indigo, title: "表示設定") {
                                navigationPath.append(MyPageDestination.appearanceSettings)
                            }
                            MenuNavRow(icon: "globe", iconColor: .teal, title: "言語設定") {
                                navigationPath.append(MyPageDestination.languageSettings)
                            }
                            MenuNavRow(icon: "nosign", iconColor: .red, title: "ブロックした事業者") {
                                navigationPath.append(MyPageDestination.mutedEmployers)
                            }
                        }

                        // Referral Section
                        MenuSection(title: "友達紹介") {
                            MenuNavRow(icon: "person.2.fill", iconColor: .orange, title: "友達を招待して特典GET") {
                                navigationPath.append(MyPageDestination.referralProgram)
                            }
                        }

                        // Support Section
                        MenuSection(title: "サポート") {
                            MenuNavRow(icon: "book.fill", iconColor: .blue, title: "ヘルプセンター") {
                                navigationPath.append(MyPageDestination.helpCenter)
                            }
                            MenuNavRow(icon: "questionmark.circle.fill", iconColor: .blue, title: "よくある質問") {
                                navigationPath.append(MyPageDestination.faq)
                            }
                            MenuNavRow(icon: "envelope.fill", iconColor: .gray, title: "お問い合わせ") {
                                navigationPath.append(MyPageDestination.contact)
                            }
                            MenuNavRow(icon: "ant.fill", iconColor: .red, title: "バグ報告・機能リクエスト") {
                                navigationPath.append(MyPageDestination.bugReport)
                            }
                            MenuNavRow(icon: "clock.arrow.circlepath", iconColor: .purple, title: "フィードバック履歴") {
                                navigationPath.append(MyPageDestination.feedbackHistory)
                            }
                        }

                        // Legal Section
                        MenuSection(title: "法的情報") {
                            MenuNavRow(icon: "doc.text.fill", iconColor: .gray, title: "利用規約") {
                                navigationPath.append(MyPageDestination.termsOfService)
                            }
                            MenuNavRow(icon: "hand.raised.fill", iconColor: .gray, title: "プライバシーポリシー") {
                                navigationPath.append(MyPageDestination.privacyPolicy)
                            }
                        }

                        // App Version
                        HStack {
                            Spacer()
                            VStack(spacing: 2) {
                                Text("Byters")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("バージョン \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)

                        // Logout
                        Button(action: { authManager.logout() }) {
                            HStack {
                                Spacer()
                                Text("ログアウト")
                                    .foregroundColor(.red)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Account Deletion
                        Button(action: { showDeleteAccountAlert = true }) {
                            HStack {
                                Spacer()
                                Text("アカウントを削除する")
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal)
                        .alert("アカウント削除", isPresented: $showDeleteAccountAlert) {
                            Button("キャンセル", role: .cancel) {}
                            Button("削除する", role: .destructive) {
                                showDeleteAccountFinalConfirm = true
                            }
                        } message: {
                            Text("アカウントを削除すると、すべてのデータが完全に削除され、元に戻すことはできません。本当に削除しますか？")
                        }
                        .alert("最終確認", isPresented: $showDeleteAccountFinalConfirm) {
                            Button("キャンセル", role: .cancel) {}
                            Button("完全に削除する", role: .destructive) {
                                Task {
                                    await deleteMyAccount()
                                }
                            }
                        } message: {
                            Text("この操作は取り消せません。アカウントに関連するすべてのデータ（応募履歴、ウォレット、チャット等）が削除されます。")
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MyPageDestination.self) { destination in
                destinationView(for: destination)
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("アカウントを削除中...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .allowsHitTesting(!isDeletingAccount)
    }

    @ViewBuilder
    private func destinationView(for destination: MyPageDestination) -> some View {
        switch destination {
        case .walletDetail: WalletDetailView()
        case .bankAccountList: BankAccountListView()
        case .withdrawal: WithdrawalView()
        case .transactionHistory: TransactionHistoryView()
        case .taxDocuments: TaxDocumentsView()
        case .upcomingWork: UpcomingWorkView()
        case .applicationHistory: ApplicationHistoryView()
        case .workHistory: WorkHistoryView()
        case .workCertificateList: WorkCertificateListView()
        case .favorites: FavoritesView()
        case .favoriteEmployers: FavoriteEmployersView()
        case .pendingReviews: PendingReviewsView()
        case .myReviews: MyReviewsView()
        case .jobAlertSettings: JobAlertSettingsView()
        case .savedSearches: SavedSearchesView()
        case .workerScoreDetail: WorkerScoreDetailView()
        case .penaltyHistory: PenaltyHistoryView()
        case .monthlySummaries: MonthlySummariesView()
        case .earningsGoal: EarningsGoalView()
        case .qualifications: QualificationsView()
        case .badges: BadgesView()
        case .profileEdit: ProfileEditView()
        case .identityVerification: IdentityVerificationView()
        case .timesheetAdjustment: TimesheetAdjustmentView()
        case .changePassword: ChangePasswordView()
        case .notificationList: NotificationListView()
        case .notificationSettings: JobSeekerNotificationSettingsView()
        case .emailSettings: EmailSettingsView()
        case .locationSettings: LocationSettingsView()
        case .appearanceSettings: AppearanceSettingsView()
        case .languageSettings: LanguageSettingsView()
        case .mutedEmployers: MutedEmployersView()
        case .referralProgram: ReferralProgramView()
        case .helpCenter: HelpCenterView()
        case .faq: FAQView()
        case .contact: ContactView()
        case .bugReport: BugReportView()
        case .feedbackHistory: FeedbackHistoryView()
        case .termsOfService: TermsOfServiceView()
        case .privacyPolicy: PrivacyPolicyView()
        }
    }

    private func identityStatusColor(_ status: String?) -> Color {
        switch status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User?
    var onEditProfile: (() -> Void)?

    private var profileCompletion: (percentage: Int, missing: [String]) {
        var filled = 0
        let total = 6
        var missing: [String] = []

        if let name = user?.name, !name.isEmpty { filled += 1 } else { missing.append("名前") }
        if let phone = user?.phone, !phone.isEmpty { filled += 1 } else { missing.append("電話番号") }
        if let bio = user?.bio, !bio.isEmpty { filled += 1 } else { missing.append("自己紹介") }
        if let pref = user?.prefecture, !pref.isEmpty { filled += 1 } else { missing.append("都道府県") }
        if user?.profileImageUrl != nil { filled += 1 } else { missing.append("プロフィール画像") }
        if user?.isIdentityVerified == true { filled += 1 } else { missing.append("本人確認") }

        return (percentage: Int(Double(filled) / Double(total) * 100), missing: missing)
    }

    var body: some View {
        VStack(spacing: 12) {
            if let imageUrl = user?.profileImageUrl, let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        )
                }
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    )
            }

            VStack(spacing: 4) {
                Text(user?.displayName ?? "ユーザー")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(user?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if user?.isIdentityVerified == true {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                    Text("本人確認済み")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }

            // Profile Completion
            let completion = profileCompletion
            if completion.percentage < 100 {
                VStack(spacing: 8) {
                    HStack {
                        Text("プロフィール完成度")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(completion.percentage)%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(completion.percentage >= 80 ? .green : .orange)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(completion.percentage >= 80 ? Color.green : Color.orange)
                                .frame(width: geometry.size.width * CGFloat(completion.percentage) / 100, height: 6)
                        }
                    }
                    .frame(height: 6)

                    if !completion.missing.isEmpty {
                        Text("未設定: \(completion.missing.prefix(3).joined(separator: "、"))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    // Profile edit button
                    Button(action: { onEditProfile?() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.circle.fill")
                            Text("プロフィールを完成させる")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
            } else {
                // Profile complete - show edit button
                Button(action: { onEditProfile?() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("プロフィール編集")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Menu Components

struct MenuSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct MenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var valueColor: Color? = nil
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)

            Text(title)
                .foregroundColor(.primary)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(valueColor ?? .gray)
                    .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

/// Button-based navigation row for reliable tap handling in ScrollView
struct MenuNavRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var valueColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 28)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                if let value = value {
                    Text(value)
                        .foregroundColor(valueColor ?? .gray)
                        .font(.subheadline)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@MainActor
class MyPageViewModel: ObservableObject {
    @Published var walletBalance: Int = 0
    @Published var pendingReviewCount: Int = 0
    @Published var workerScore: WorkerScore?
    @Published var monthlySummary: MonthlySummary?
    @Published var penaltyCount: Int = 0
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        async let walletTask: Void = loadWallet()
        async let reviewsTask: Void = loadPendingReviews()
        async let scoreTask: Void = loadWorkerScore()
        async let summaryTask: Void = loadMonthlySummary()
        async let penaltiesTask: Void = loadPenalties()

        _ = await (walletTask, reviewsTask, scoreTask, summaryTask, penaltiesTask)
    }

    private func loadWallet() async {
        do {
            let wallet = try await api.getWallet()
            walletBalance = wallet.balance
        } catch {
            // Non-critical
        }
    }

    private func loadPendingReviews() async {
        do {
            let pendingReviews = try await api.getPendingReviews()
            pendingReviewCount = pendingReviews.count
        } catch {
            // Non-critical
        }
    }

    private func loadWorkerScore() async {
        do {
            workerScore = try await api.getWorkerScore()
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

    private func loadPenalties() async {
        do {
            let penalties = try await api.getPenalties()
            penaltyCount = penalties.count
        } catch {
            // Non-critical
        }
    }
}

// MARK: - Wallet Detail View

// MARK: - Worker Rank Card (MyPage)

struct MyPageWorkerRankCard: View {
    let score: WorkerScore

    private var rankColor: Color {
        switch score.rank {
        case "diamond": return .purple
        case "gold": return .yellow
        case "silver": return .gray
        case "bronze": return .orange
        default: return .blue
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: score.rankIcon)
                    .font(.title2)
                    .foregroundColor(rankColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(score.rankDisplay)
                        .font(.headline)
                        .foregroundColor(rankColor)
                    Text("信頼度スコア: \(score.reliabilityScore)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(score.completedJobs)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("完了したお仕事")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("\(score.goodRatePercent)%")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Text("高評価率")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Divider().frame(height: 24)

                VStack(spacing: 2) {
                    Text("\(score.canceledJobs)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("キャンセル")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Divider().frame(height: 24)

                VStack(spacing: 2) {
                    Text("\(score.noShowCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(score.noShowCount > 0 ? .red : .primary)
                    Text("無断欠勤")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Divider().frame(height: 24)

                VStack(spacing: 2) {
                    Text("\(score.penalties)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(score.penalties > 0 ? .orange : .primary)
                    Text("ペナルティ")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            if let nextRank = score.nextRankJobs, nextRank > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("次のランクまで")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("あと\(nextRank)件")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor)
                    }
                    ProgressView(value: Double(score.completedJobs), total: Double(score.completedJobs + nextRank))
                        .tint(rankColor)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Monthly Summary Card (MyPage)

struct MyPageMonthlySummaryCard: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今月のサマリー")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("¥\(summary.totalEarnings.formatted())")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("収入")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text("\(summary.totalJobs)件")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("お仕事")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text(String(format: "%.1fh", summary.totalHours))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("勤務時間")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text("¥\(summary.averageHourlyRate.formatted())")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("平均時給")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Worker Score Detail View

struct WorkerScoreDetailView: View {
    @StateObject private var viewModel = WorkerScoreDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    SkeletonList(count: 3)
                } else if let score = viewModel.score {
                    MyPageWorkerRankCard(score: score)
                        .padding(.horizontal)

                    // Rank Explanation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ランク制度について")
                            .font(.headline)

                        RankExplanationRow(rank: "ダイヤモンド", icon: "diamond.fill", color: .purple, requirement: "50件以上完了 & 高評価90%以上")
                        RankExplanationRow(rank: "ゴールド", icon: "star.circle.fill", color: .yellow, requirement: "30件以上完了 & 高評価80%以上")
                        RankExplanationRow(rank: "シルバー", icon: "medal.fill", color: .gray, requirement: "15件以上完了 & 高評価70%以上")
                        RankExplanationRow(rank: "ブロンズ", icon: "shield.fill", color: .orange, requirement: "5件以上完了")
                        RankExplanationRow(rank: "ビギナー", icon: "person.fill", color: .blue, requirement: "開始時")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ランクアップのコツ")
                            .font(.headline)

                        TipRow(icon: "checkmark.circle.fill", color: .green, text: "お仕事を最後までやり遂げましょう")
                        TipRow(icon: "clock.fill", color: .blue, text: "遅刻・早退をしないようにしましょう")
                        TipRow(icon: "xmark.circle.fill", color: .red, text: "無断欠勤はペナルティの対象です")
                        TipRow(icon: "star.fill", color: .yellow, text: "良いレビューをもらうとスコアが上がります")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ワーカーランク")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }
}

struct RankExplanationRow: View {
    let rank: String
    let icon: String
    let color: Color
    let requirement: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(rank)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(requirement)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
}

struct TipRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

@MainActor
class WorkerScoreDetailViewModel: ObservableObject {
    @Published var score: WorkerScore?
    @Published var isLoading = true

    func loadData() async {
        isLoading = true
        do {
            score = try await APIClient.shared.getWorkerScore()
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

// MARK: - Penalty History View

struct PenaltyHistoryView: View {
    @StateObject private var viewModel = PenaltyHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    SkeletonList(count: 3)
                } else if viewModel.penalties.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("ペナルティなし")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("このまま良い勤務を続けましょう！")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(viewModel.penalties) { penalty in
                        PenaltyRow(penalty: penalty)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ペナルティ履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }
}

struct PenaltyRow: View {
    let penalty: Penalty

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: penalty.typeIcon)
                .foregroundColor(.orange)
                .frame(width: 32, height: 32)
                .background(Color.orange.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(penalty.typeDisplay)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let jobTitle = penalty.jobTitle {
                    Text(jobTitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if let reason = penalty.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let date = penalty.createdAt {
                    Text(date.prefix(10).replacingOccurrences(of: "-", with: "/"))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Text("-\(penalty.penaltyPoints)pt")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
class PenaltyHistoryViewModel: ObservableObject {
    @Published var penalties: [Penalty] = []
    @Published var isLoading = true

    func loadData() async {
        isLoading = true
        do {
            penalties = try await APIClient.shared.getPenalties()
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

// MARK: - Monthly Summaries View

struct MonthlySummariesView: View {
    @StateObject private var viewModel = MonthlySummariesViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    SkeletonList(count: 3)
                } else if viewModel.summaries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("まだ勤務データがありません")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(viewModel.summaries, id: \.month) { summary in
                        MonthlySummaryRow(summary: summary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("月次レポート")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }
}

struct MonthlySummaryRow: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.month)
                .font(.headline)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("¥\(summary.totalEarnings.formatted())")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("収入")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text("\(summary.totalJobs)件")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("お仕事")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text(String(format: "%.1fh", summary.totalHours))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("時間")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", summary.completionRate * 100))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(summary.completionRate >= 0.9 ? .green : .orange)
                    Text("完了率")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }

            if let topCategory = summary.topCategory {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("よく働いたカテゴリ: \(topCategory)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
class MonthlySummariesViewModel: ObservableObject {
    @Published var summaries: [MonthlySummary] = []
    @Published var isLoading = true

    func loadData() async {
        isLoading = true
        do {
            summaries = try await APIClient.shared.getMonthlySummaries()
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

// MARK: - Wallet Detail View

struct WalletDetailView: View {
    @StateObject private var viewModel = WalletDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Balance Card
                VStack(spacing: 8) {
                    Text("現在の残高")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    Text("¥\(viewModel.wallet?.balance.formatted() ?? "0")")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    if let available = viewModel.wallet?.availableBalance {
                        Text("出金可能額: ¥\(available.formatted())")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Earnings Summary
                if let stats = viewModel.earningsStats {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("収入サマリー")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 0) {
                            EarningsSummaryCard(title: "今月", amount: stats.thisMonthEarnings, color: .blue)
                            Divider().frame(height: 40)
                            EarningsSummaryCard(title: "先月", amount: stats.lastMonthEarnings, color: .gray)
                            Divider().frame(height: 40)
                            EarningsSummaryCard(title: "累計", amount: stats.totalEarnings, color: .green)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }

                // Quick Actions
                HStack(spacing: 16) {
                    NavigationLink(destination: WithdrawalView()) {
                        QuickActionCard(icon: "arrow.down.circle.fill", title: "出金", color: .green)
                    }

                    NavigationLink(destination: BankAccountListView()) {
                        QuickActionCard(icon: "building.columns.fill", title: "口座管理", color: .blue)
                    }

                    NavigationLink(destination: TransactionHistoryView()) {
                        QuickActionCard(icon: "list.bullet", title: "履歴", color: .orange)
                    }
                }
                .padding(.horizontal)

                // Recent Transactions
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近の取引")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.transactions.isEmpty {
                        Text("取引履歴はありません")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(viewModel.transactions.prefix(5)) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ウォレット")
        .task {
            await viewModel.loadData()
        }
    }
}

struct QuickActionCard: View {
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
    }
}

struct EarningsSummaryCard: View {
    let title: String
    let amount: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text("¥\(amount.formatted())")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

@MainActor
class WalletDetailViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var transactions: [Transaction] = []
    @Published var earningsStats: EarningsStats?
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        do {
            wallet = try await api.getWallet()
            transactions = try await api.getTransactions()
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            earningsStats = try await api.getEarningsStats()
        } catch {
            // Earnings stats are supplementary, don't show error
        }
    }
}

// MARK: - Transaction History

struct TransactionHistoryView: View {
    @StateObject private var viewModel = TransactionHistoryViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.isLoading {
                SkeletonList(count: 4)
            } else if viewModel.transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("取引履歴はありません")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("お仕事を完了すると報酬が記録されます")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.transactions) { transaction in
                    NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("取引履歴")
        .task {
            await viewModel.loadData()
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.typeDisplay)
                    .font(.headline)

                if let desc = transaction.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if let date = transaction.createdAt {
                    Text(date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Text("\(transaction.isPositive ? "+" : "-")¥\(abs(transaction.amount).formatted())")
                .font(.headline)
                .foregroundColor(transaction.isPositive ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Transaction Detail / Receipt

struct TransactionDetailView: View {
    let transaction: Transaction

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Receipt Header
                VStack(spacing: 8) {
                    Image(systemName: transaction.isPositive ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(transaction.isPositive ? .green : .red)

                    Text("\(transaction.isPositive ? "+" : "-")¥\(abs(transaction.amount).formatted())")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(transaction.typeDisplay)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)

                // Details Card
                VStack(spacing: 0) {
                    ReceiptRow(label: "種類", value: transaction.typeDisplay)
                    Divider()

                    if let desc = transaction.description {
                        ReceiptRow(label: "内容", value: desc)
                        Divider()
                    }

                    if let jobTitle = transaction.jobTitle {
                        ReceiptRow(label: "お仕事", value: jobTitle)
                        Divider()
                    }

                    ReceiptRow(label: "金額", value: "¥\(abs(transaction.amount).formatted())")
                    Divider()

                    if let status = transaction.status {
                        ReceiptRow(label: "ステータス", value: statusDisplay(status))
                        Divider()
                    }

                    if let date = transaction.createdAt {
                        ReceiptRow(label: "日時", value: formatReceiptDate(date))
                        Divider()
                    }

                    ReceiptRow(label: "取引ID", value: String(transaction.id.prefix(12)) + "...")
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)

                // Share as receipt
                ShareLink(
                    item: receiptText,
                    subject: Text("Byters 取引明細"),
                    message: Text("取引明細")
                ) {
                    Label("領収書を共有", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("取引明細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var receiptText: String {
        var lines = [
            "── Byters 取引明細 ──",
            "",
            "種類: \(transaction.typeDisplay)",
            "金額: ¥\(abs(transaction.amount).formatted())",
        ]
        if let desc = transaction.description { lines.append("内容: \(desc)") }
        if let jobTitle = transaction.jobTitle { lines.append("お仕事: \(jobTitle)") }
        if let status = transaction.status { lines.append("ステータス: \(statusDisplay(status))") }
        if let date = transaction.createdAt { lines.append("日時: \(formatReceiptDate(date))") }
        lines.append("取引ID: \(transaction.id)")
        lines.append("")
        lines.append("──────────────────")
        return lines.joined(separator: "\n")
    }

    private func statusDisplay(_ status: String) -> String {
        switch status {
        case "completed": return "完了"
        case "pending": return "処理中"
        case "failed": return "失敗"
        default: return status
        }
    }

    private func formatReceiptDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "yyyy年M月d日 HH:mm"
            return display.string(from: date)
        }
        return dateString
    }
}

private struct ReceiptRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

@MainActor
class TransactionHistoryViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            transactions = try await api.getTransactions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Bank Account List

struct BankAccountListView: View {
    @StateObject private var viewModel = BankAccountViewModel()
    @State private var showingAddSheet = false
    @State private var accountToDelete: BankAccount?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.isLoading {
                SkeletonList(count: 2)
            } else if viewModel.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("銀行口座が登録されていません")
                        .foregroundColor(.gray)

                    Button("口座を追加") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.accounts) { account in
                    BankAccountRow(account: account)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                accountToDelete = account
                                showDeleteConfirm = true
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("銀行口座")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("銀行口座を追加")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddBankAccountView(onSuccess: {
                Task { await viewModel.loadData() }
            })
        }
        .alert("口座を削除", isPresented: $showDeleteConfirm) {
            Button("削除する", role: .destructive) {
                if let account = accountToDelete {
                    Task { await viewModel.deleteAccountById(account.id) }
                }
            }
            Button("キャンセル", role: .cancel) {
                accountToDelete = nil
            }
        } message: {
            if let account = accountToDelete {
                Text("\(account.bankName) \(account.branchName)の口座を削除しますか？この操作は取り消せません。")
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct BankAccountRow: View {
    let account: BankAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(account.bankName)
                    .font(.headline)

                if account.isDefault == true {
                    Text("デフォルト")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }

            Text("\(account.branchName) \(account.accountTypeDisplay)")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("口座番号: \(account.accountNumber)")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("名義: \(account.accountHolderName)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class BankAccountViewModel: ObservableObject {
    @Published var accounts: [BankAccount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            accounts = try await api.getBankAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteAccountById(_ accountId: String) async {
        do {
            _ = try await api.deleteBankAccount(accountId: accountId)
            accounts.removeAll { $0.id == accountId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Add Bank Account

struct AddBankAccountView: View {
    @Environment(\.dismiss) var dismiss
    var onSuccess: () -> Void

    @State private var bankName = ""
    @State private var branchName = ""
    @State private var accountType = "ordinary"
    @State private var accountNumber = ""
    @State private var accountHolderName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showBankSelection = false

    var body: some View {
        NavigationStack {
            Form {
                Section("銀行情報") {
                    Button {
                        showBankSelection = true
                    } label: {
                        HStack {
                            Text("銀行名")
                                .foregroundColor(.primary)
                            Spacer()
                            if bankName.isEmpty {
                                Text("選択してください")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(bankName)
                                    .foregroundColor(.blue)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    TextField("支店名", text: $branchName)
                        .submitLabel(.done)
                }

                Section("口座情報") {
                    Picker("口座種別", selection: $accountType) {
                        Text("普通").tag("ordinary")
                        Text("当座").tag("checking")
                    }

                    TextField("口座番号（7桁）", text: $accountNumber)
                        .keyboardType(.numberPad)
                        .onChange(of: accountNumber) { _, newValue in
                            accountNumber = String(newValue.filter { $0.isNumber }.prefix(7))
                        }

                    TextField("口座名義（カタカナ）", text: $accountHolderName)
                        .textContentType(.name)
                        .submitLabel(.done)

                    if !accountHolderName.isEmpty {
                        if accountHolderName.toKatakana().isValidBankAccountName {
                            if accountHolderName != accountHolderName.toKatakana() {
                                Text("ひらがなは自動でカタカナに変換されます")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("口座名義はカタカナまたはひらがなで入力してください")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: addAccount) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("登録する")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("銀行口座を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showBankSelection) {
                BankSelectionView(selectedBankName: $bankName)
            }
        }
    }

    var isValid: Bool {
        !bankName.isEmpty &&
        !branchName.isEmpty &&
        accountNumber.count == 7 &&
        !accountHolderName.isEmpty &&
        accountHolderName.toKatakana().isValidBankAccountName
    }

    func addAccount() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let katakanaName = accountHolderName.toKatakana()
                _ = try await APIClient.shared.addBankAccount(
                    bankName: bankName,
                    branchName: branchName,
                    accountType: accountType,
                    accountNumber: accountNumber,
                    accountHolderName: katakanaName
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

// MARK: - Withdrawal View

struct WithdrawalView: View {
    @StateObject private var viewModel = WithdrawalViewModel()
    @State private var amount = ""
    @State private var selectedAccountId: String?
    @State private var showingConfirmation = false

    var body: some View {
        Form {
            Section("出金可能額") {
                HStack {
                    Text("残高")
                    Spacer()
                    Text("¥\(viewModel.wallet?.balance.formatted() ?? "0")")
                        .font(.headline)
                }
                if let wallet = viewModel.wallet,
                   let available = wallet.availableBalance,
                   available != wallet.balance {
                    HStack {
                        Text("出金可能額")
                        Spacer()
                        Text("¥\(available.formatted())")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                if viewModel.withdrawalFee > 0 {
                    HStack {
                        Text("出金手数料")
                        Spacer()
                        Text("¥\(viewModel.withdrawalFee.formatted())")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    Text("※ 出金額から手数料が差し引かれます")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Section("出金先口座") {
                if viewModel.accounts.isEmpty {
                    NavigationLink("銀行口座を登録する", destination: BankAccountListView())
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
                    TextField("1000", text: $amount)
                        .keyboardType(.numberPad)
                }

                Text("最低出金額: ¥1,000")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section("着金目安") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("翌営業日〜2営業日")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Stripe経由で登録済みの銀行口座へ振り込まれます。土日祝日を挟む場合は翌営業日以降の着金となります。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(action: { showingConfirmation = true }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("出金申請する")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit)
            }

            // Withdrawal History
            Section("出金履歴") {
                if viewModel.withdrawals.isEmpty {
                    Text("出金履歴はありません")
                        .foregroundColor(.gray)
                } else {
                    ForEach(viewModel.withdrawals) { withdrawal in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("¥\(withdrawal.amount.formatted())")
                                    .font(.headline)
                                Spacer()
                                Text(withdrawal.statusDisplay)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            if let date = withdrawal.requestedAt {
                                Text(date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("出金申請")
        .alert("出金の確認", isPresented: $showingConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("申請する") {
                guard let accountId = selectedAccountId, let amountInt = Int(amount) else { return }
                Task { await viewModel.requestWithdrawal(accountId: accountId, amount: amountInt) }
            }
        } message: {
            Text("¥\(amount)を出金申請しますか？\n登録済みの銀行口座へ翌営業日〜2営業日で着金します。")
        }
        .task {
            await viewModel.loadData()
        }
    }

    var canSubmit: Bool {
        guard let accountId = selectedAccountId, !accountId.isEmpty,
              let amountInt = Int(amount), amountInt >= 1000,
              let wallet = viewModel.wallet, amountInt <= wallet.availableAmount else {
            return false
        }
        return !viewModel.isLoading
    }
}

@MainActor
class WithdrawalViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var accounts: [BankAccount] = []
    @Published var withdrawals: [WithdrawalRequest] = []
    @Published var withdrawalFee: Int = 250
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        do {
            wallet = try await api.getWallet()
            accounts = try await api.getBankAccounts()
            withdrawals = try await api.getWithdrawalHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestWithdrawal(accountId: String, amount: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            // 出金前に最新の残高を再取得して検証
            let latestWallet = try await api.getWallet()
            wallet = latestWallet
            guard amount <= latestWallet.availableAmount else {
                errorMessage = "残高不足です。現在の出金可能額: ¥\(latestWallet.availableAmount.formatted())"
                isLoading = false
                return
            }

            let request = try await api.requestWithdrawal(bankAccountId: accountId, amount: amount)
            withdrawals.insert(request, at: 0)
            AnalyticsService.shared.track(AnalyticsService.eventWithdrawalRequested, properties: ["amount": String(amount)])
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Application History

struct ApplicationHistoryView: View {
    @StateObject private var viewModel = ApplicationHistoryViewModel()
    @State private var selectedFilter: ApplicationFilter = .all

    enum ApplicationFilter: String, CaseIterable {
        case all = "すべて"
        case pending = "審査中"
        case accepted = "承認済み"
        case completed = "完了"
        case rejected = "不採用"
    }

    var filteredApplications: [Application] {
        switch selectedFilter {
        case .all: return viewModel.applications
        case .pending: return viewModel.applications.filter { $0.status == "pending" }
        case .accepted: return viewModel.applications.filter { $0.status == "accepted" || $0.status == "checked_in" }
        case .completed: return viewModel.applications.filter { $0.status == "completed" }
        case .rejected: return viewModel.applications.filter { $0.status == "rejected" || $0.status == "canceled" }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ApplicationFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedFilter = filter }) {
                            Text(filter.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel("\(filter.rawValue)でフィルター")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            if viewModel.isLoading {
                SkeletonList(count: 4)
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("再試行") { Task { await viewModel.loadData() } }
                        .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else if filteredApplications.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "doc.text",
                    title: selectedFilter == .all ? "応募履歴はありません" : "\(selectedFilter.rawValue)の応募はありません",
                    message: selectedFilter == .all ? "求人に応募すると、ここに履歴が表示されます" : "フィルターを変更してみてください"
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApplications) { application in
                            ApplicationTimelineRow(application: application)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("応募履歴")
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
    }
}

struct ApplicationTimelineRow: View {
    let application: Application

    var statusColor: Color {
        switch application.status {
        case "pending": return .orange
        case "accepted", "checked_in": return .green
        case "rejected": return .red
        case "canceled": return .gray
        case "completed": return .blue
        default: return .gray
        }
    }

    var statusIcon: String {
        switch application.status {
        case "pending": return "clock.fill"
        case "accepted", "checked_in": return "checkmark.circle.fill"
        case "rejected": return "xmark.circle.fill"
        case "canceled": return "minus.circle.fill"
        case "completed": return "star.circle.fill"
        default: return "circle.fill"
        }
    }

    // Timeline step indicators
    private var timelineSteps: [(label: String, isActive: Bool, isCompleted: Bool)] {
        switch application.status {
        case "pending":
            return [("応募", true, true), ("審査中", true, false), ("結果", false, false)]
        case "accepted", "checked_in":
            return [("応募", true, true), ("承認", true, true), ("勤務", application.status == "checked_in", application.status == "checked_in")]
        case "completed":
            return [("応募", true, true), ("承認", true, true), ("完了", true, true)]
        case "rejected":
            return [("応募", true, true), ("不採用", true, true)]
        case "canceled":
            return [("応募", true, true), ("キャンセル", true, true)]
        default:
            return [("応募", true, true)]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with status badge
                HStack(alignment: .top) {
                    Image(systemName: statusIcon)
                        .font(.title3)
                        .foregroundColor(statusColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(application.jobTitle ?? "求人")
                            .font(.headline)
                            .lineLimit(2)

                        if let employer = application.employerName {
                            Text(employer)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text(application.statusDisplay)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .foregroundColor(statusColor)
                        .clipShape(Capsule())
                }

                // Timeline progress bar
                HStack(spacing: 0) {
                    ForEach(Array(timelineSteps.enumerated()), id: \.offset) { index, step in
                        if index > 0 {
                            Rectangle()
                                .fill(step.isCompleted ? statusColor : Color(.systemGray4))
                                .frame(height: 2)
                        }
                        VStack(spacing: 4) {
                            Circle()
                                .fill(step.isActive ? statusColor : Color(.systemGray4))
                                .frame(width: 10, height: 10)
                            Text(step.label)
                                .font(.system(size: 10))
                                .foregroundColor(step.isActive ? statusColor : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Footer info
                HStack {
                    if let date = application.createdAt {
                        Label(date, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let wage = application.hourlyWage {
                        Text("¥\(wage)/時間")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            .padding(.vertical, 6)
        }
    }
}

@MainActor
class ApplicationHistoryViewModel: ObservableObject {
    @Published var applications: [Application] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            applications = try await api.getMyApplications()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Work History

struct WorkHistoryView: View {
    @StateObject private var viewModel = WorkHistoryViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.isLoading {
                SkeletonList(count: 4)
            } else if viewModel.workHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("勤務履歴はありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.workHistory) { work in
                    WorkHistoryRow(work: work)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("勤務履歴")
        .task {
            await viewModel.loadData()
        }
    }
}

struct WorkHistoryRow: View {
    let work: WorkHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(work.jobTitle ?? "勤務")
                    .font(.headline)
                Spacer()
                Text(work.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(work.workDate)
                .font(.subheadline)

            if let checkIn = work.checkInTime, let checkOut = work.checkOutTime {
                Text("\(checkIn) 〜 \(checkOut)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if let earnings = work.earnings {
                Text("報酬: ¥\(earnings.formatted())")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class WorkHistoryViewModel: ObservableObject {
    @Published var workHistory: [WorkHistory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            workHistory = try await api.getWorkHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Profile Edit

struct ProfileEditView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var name = ""
    @State private var phone = ""
    @State private var bio = ""
    @State private var prefecture = ""
    @State private var city = ""
    @State private var isLoading = false
    @State private var showingSaved = false
    @State private var saveError: String?
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false

    var body: some View {
        Form {
            if let error = saveError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section("プロフィール画像") {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else if let imageUrl = authManager.currentUser?.profileImageUrl,
                                  let url = URL(string: imageUrl) {
                            CachedAsyncImage(url: url) {
                                defaultAvatar
                            }
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            defaultAvatar
                        }

                        Button(isUploadingImage ? "アップロード中..." : "画像を変更") {
                            showImageSourceSheet = true
                        }
                        .font(.caption)
                        .disabled(isUploadingImage)
                    }
                    Spacer()
                }
            }

            Section("基本情報") {
                TextField("名前", text: $name)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 50 { name = String(newValue.prefix(50)) }
                    }

                if let nameErr = ValidationHelper.nameError(name) {
                    Text(nameErr)
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                TextField("電話番号", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                if let phoneErr = ValidationHelper.phoneError(phone) {
                    Text(phoneErr)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section("自己紹介") {
                TextEditor(text: $bio)
                    .frame(height: 100)
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 500 { bio = String(newValue.prefix(500)) }
                    }
                Text("\(bio.count)/500")
                    .font(.caption2)
                    .foregroundColor(bio.count > 450 ? .orange : .gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Section("居住地") {
                Picker("都道府県", selection: $prefecture) {
                    Text("選択してください").tag("")
                    ForEach(Prefecture.all) { pref in
                        Text(pref.name).tag(pref.name)
                    }
                }
                TextField("市区町村", text: $city)
                    .submitLabel(.done)
            }

            Section {
                Button(action: {
                    Task { await saveProfile() }
                }) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isLoading || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!phone.isEmpty && !ValidationHelper.isValidPhone(phone)))
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("プロフィール編集")
        .alert("保存しました", isPresented: $showingSaved) {
            Button("OK") {}
        }
        .onAppear {
            if let user = authManager.currentUser {
                name = user.name ?? ""
                phone = user.phone ?? ""
                bio = user.bio ?? ""
                prefecture = user.prefecture ?? ""
                city = user.city ?? ""
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: imageSourceType)
        }
        .confirmationDialog("画像を選択", isPresented: $showImageSourceSheet) {
            Button("フォトライブラリから選択") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("カメラで撮影") {
                    imageSourceType = .camera
                    showImagePicker = true
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task { await uploadImage(image) }
            }
        }
    }

    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 80, height: 80)
            .foregroundColor(.gray.opacity(0.5))
    }

    private func uploadImage(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        let maxSize = 5 * 1024 * 1024 // 5MB
        if imageData.count > maxSize {
            saveError = "画像サイズが大きすぎます（最大5MB）。別の画像を選択してください。"
            return
        }
        isUploadingImage = true
        do {
            _ = try await APIClient.shared.uploadProfileImage(imageData: imageData)
            await authManager.checkAuthStatus()
        } catch {
            saveError = "画像のアップロードに失敗しました"
        }
        isUploadingImage = false
    }

    func saveProfile() async {
        isLoading = true
        saveError = nil
        do {
            let updated = try await APIClient.shared.updateProfile(
                name: name.isEmpty ? nil : name,
                phone: phone.isEmpty ? nil : phone,
                bio: bio.isEmpty ? nil : bio,
                prefecture: prefecture.isEmpty ? nil : prefecture,
                city: city.isEmpty ? nil : city
            )
            authManager.currentUser = updated
            authManager.cacheCurrentUser()
            showingSaved = true
            AnalyticsService.shared.track(AnalyticsService.eventProfileUpdated)
        } catch let apiError as APIError {
            saveError = apiError.localizedDescription
        } catch {
            saveError = "プロフィールの保存に失敗しました。通信状況を確認してもう一度お試しください。"
        }
        isLoading = false
    }
}

// MARK: - Identity Verification

struct IdentityVerificationView: View {
    @StateObject private var viewModel = IdentityVerificationViewModel()
    @State private var showingFrontImagePicker = false
    @State private var showingBackImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedBackImage: UIImage?
    @State private var documentType = "drivers_license"
    @State private var showResubmitForm = false
    @State private var showSubmitSuccess = false

    var body: some View {
        Form {
            // Error display
            if let error = viewModel.errorMessage {
                Section {
                    Label {
                        Text(error)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    .foregroundColor(.red)
                }
            }

            // Status badge section
            Section("現在のステータス") {
                HStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundColor(statusColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("本人確認")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(viewModel.verification?.statusDisplay ?? "未提出")
                            .font(.headline)
                            .foregroundColor(statusColor)
                    }

                    Spacer()

                    // Color-coded status badge
                    Text(statusBadgeText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor)
                        .clipShape(Capsule())
                }
                .padding(.vertical, 4)

                // Submitted date
                if let submittedAt = viewModel.verification?.submittedAt {
                    HStack {
                        Text("提出日")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(submittedAt.prefix(10))
                            .font(.subheadline)
                    }
                }

                // Document type
                if let docType = viewModel.verification?.documentType {
                    HStack {
                        Text("書類の種類")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(documentTypeDisplay(docType))
                            .font(.subheadline)
                    }
                }
            }

            // Pending status info
            if viewModel.verification?.status == "pending" {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("審査中です")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("書類の確認には通常1〜3営業日かかります。審査完了後、通知でお知らせします。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Approved status info
            if viewModel.verification?.status == "approved" {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本人確認が完了しています")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("お仕事への応募が可能です。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Rejection reason and re-submit section
            if viewModel.verification?.status == "rejected" {
                // Rejection reason card
                Section("却下理由") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                            Text("本人確認が却下されました")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }

                        Divider()

                        // Show the rejection reason prominently
                        VStack(alignment: .leading, spacing: 8) {
                            Text("理由")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            Text(viewModel.verification?.rejectionReason ?? "理由が提供されていません。サポートにお問い合わせください。")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("内容を確認の上、書類を再提出してください。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Re-submit button
                if !showResubmitForm {
                    Section {
                        Button(action: { showResubmitForm = true }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("書類を再提出する")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.blue)
                    }
                }
            }

            // Submission form: show for "none" status, or when re-submitting after rejection
            if viewModel.verification?.status == nil
                || viewModel.verification?.status == "none"
                || showResubmitForm {
                Section(showResubmitForm ? "再提出" : "書類を提出") {
                    Picker("書類の種類", selection: $documentType) {
                        Text("運転免許証").tag("drivers_license")
                        Text("マイナンバーカード").tag("my_number_card")
                        Text("パスポート").tag("passport")
                        Text("在留カード").tag("residence_card")
                    }
                }

                Section("表面") {
                    Button(action: { showingFrontImagePicker = true }) {
                        HStack {
                            Image(systemName: "camera")
                            Text(selectedImage == nil ? "表面を撮影する" : "表面を撮り直す")
                        }
                    }

                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Section("裏面（任意）") {
                    Button(action: { showingBackImagePicker = true }) {
                        HStack {
                            Image(systemName: "camera")
                            Text(selectedBackImage == nil ? "裏面を撮影する" : "裏面を撮り直す")
                        }
                    }

                    if let backImage = selectedBackImage {
                        HStack {
                            Image(uiImage: backImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button(action: { selectedBackImage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    Text("運転免許証・在留カードは裏面も提出すると審査がスムーズになります")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if selectedImage != nil {
                    Section {
                        Button(action: submitVerification) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text(showResubmitForm ? "再提出する" : "提出する")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }

                // Cancel re-submit
                if showResubmitForm {
                    Section {
                        Button(action: {
                            showResubmitForm = false
                            selectedImage = nil
                        }) {
                            Text("キャンセル")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("本人確認")
        .sheet(isPresented: $showingFrontImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showingBackImagePicker) {
            ImagePicker(image: $selectedBackImage)
        }
        .alert("提出完了", isPresented: $showSubmitSuccess) {
            Button("OK") {}
        } message: {
            Text("本人確認書類を提出しました。審査には通常1〜3営業日かかります。結果は通知でお知らせします。")
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Status Helpers

    private var statusColor: Color {
        switch viewModel.verification?.status {
        case "approved": return .green
        case "pending": return .orange
        case "rejected": return .red
        default: return .gray
        }
    }

    private var statusIcon: String {
        switch viewModel.verification?.status {
        case "approved": return "checkmark.shield.fill"
        case "pending": return "clock.badge.questionmark"
        case "rejected": return "xmark.shield.fill"
        default: return "shield.slash"
        }
    }

    private var statusBadgeText: String {
        switch viewModel.verification?.status {
        case "approved": return "確認済み"
        case "pending": return "審査中"
        case "rejected": return "却下"
        default: return "未提出"
        }
    }

    private func documentTypeDisplay(_ type: String) -> String {
        switch type {
        case "drivers_license": return "運転免許証"
        case "my_number_card": return "マイナンバーカード"
        case "passport": return "パスポート"
        case "residence_card": return "在留カード"
        default: return type
        }
    }

    private func submitVerification() {
        guard let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let maxSize = 10 * 1024 * 1024 // 10MB
        if imageData.count > maxSize {
            viewModel.errorMessage = "表面の画像サイズが大きすぎます（最大10MB）。別の画像を選択してください。"
            return
        }

        var backImageData: Data?
        if let backImage = selectedBackImage {
            guard let backData = backImage.jpegData(compressionQuality: 0.8) else { return }
            if backData.count > maxSize {
                viewModel.errorMessage = "裏面の画像サイズが大きすぎます（最大10MB）。別の画像を選択してください。"
                return
            }
            backImageData = backData
        }

        Task {
            await viewModel.submit(documentType: documentType, frontImage: imageData, backImage: backImageData)
            if viewModel.errorMessage == nil {
                showResubmitForm = false
                selectedImage = nil
                selectedBackImage = nil
                showSubmitSuccess = true
            }
        }
    }
}

@MainActor
class IdentityVerificationViewModel: ObservableObject {
    @Published var verification: IdentityVerification?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        do {
            verification = try await api.getIdentityVerificationStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit(documentType: String, frontImage: Data, backImage: Data? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await api.submitIdentityVerification(documentType: documentType, frontImageData: frontImage, backImageData: backImage)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - FAQ View

struct FAQView: View {
    let faqSections: [(String, [(String, String)])] = [
        ("お仕事について", [
            ("どんなお仕事がありますか？", "飲食店、イベントスタッフ、軽作業など様々な短期のお仕事があります。アプリの検索機能でエリアや職種を絞り込んで探せます。"),
            ("応募してからどれくらいで結果がわかりますか？", "事業者によって異なりますが、通常1〜3日以内に結果がチャットで通知されます。"),
            ("キャンセルはできますか？", "勤務日の前日までキャンセル可能です。当日キャンセルは評価に影響する場合があります。"),
            ("出勤・退勤はどうやって記録しますか？", "勤務先に設置されたQRコードをアプリで読み取ることで出退勤を記録できます。出勤時と退勤時にそれぞれQRコードをスキャンしてください。"),
        ]),
        ("報酬・出金について", [
            ("報酬はいつ受け取れますか？", "勤務完了後、事業者が承認すると即座にウォレットに反映されます。出金申請から翌営業日〜2営業日で登録済みの銀行口座に振り込まれます。"),
            ("出金手数料はかかりますか？", "出金時に所定の手数料がかかります。手数料はウォレットの出金申請画面でご確認いただけます。"),
            ("最低出金額はありますか？", "最低出金額は1,000円からとなっています。"),
        ]),
        ("アカウントについて", [
            ("本人確認は必須ですか？", "お仕事に応募するには本人確認が必要です。運転免許証、マイナンバーカード、パスポートのいずれかをご準備ください。"),
            ("退会するにはどうすればいいですか？", "マイページの「設定」>「アカウント削除」から退会手続きが可能です。未出金の報酬がある場合は先に出金をお願いします。"),
            ("パスワードを忘れました", "ログイン画面の「パスワードを忘れた方」からメールアドレスを入力してパスワードリセットが可能です。"),
        ]),
    ]

    var body: some View {
        List {
            ForEach(faqSections, id: \.0) { section in
                Section(header: Text(section.0)) {
                    ForEach(section.1, id: \.0) { faq in
                        DisclosureGroup(faq.0) {
                            Text(faq.1)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("よくある質問")
    }
}

// MARK: - Contact View

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var subject = ""
    @State private var message = ""
    @State private var category = "general"
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?

    private let categories = [
        ("general", "一般的なお問い合わせ"),
        ("account", "アカウントについて"),
        ("payment", "お支払いについて"),
        ("job", "求人について"),
        ("bug", "不具合の報告"),
        ("other", "その他")
    ]

    var body: some View {
        Form {
            Section("カテゴリ") {
                Picker("カテゴリを選択", selection: $category) {
                    ForEach(categories, id: \.0) { cat in
                        Text(cat.1).tag(cat.0)
                    }
                }
            }

            Section("お問い合わせ内容") {
                TextField("件名", text: $subject)
                    .submitLabel(.done)
                    .onChange(of: subject) { _, newValue in
                        if newValue.count > 100 { subject = String(newValue.prefix(100)) }
                    }
                TextEditor(text: $message)
                    .frame(height: 150)
                    .onChange(of: message) { _, newValue in
                        if newValue.count > 2000 { message = String(newValue.prefix(2000)) }
                    }
                Text("\(message.count)/2000")
                    .font(.caption2)
                    .foregroundColor(message.count > 1800 ? .orange : .gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section {
                Button(action: submitContact) {
                    if isSubmitting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("送信中...")
                        }
                    } else {
                        Text("送信")
                    }
                }
                .disabled(subject.isEmpty || message.isEmpty || isSubmitting)
                .frame(maxWidth: .infinity)
            }

            Section {
                if let mailURL = URL(string: "mailto:support@byters.jp") {
                    Link("メールでお問い合わせ", destination: mailURL)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("お問い合わせ")
        .alert("送信完了", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("お問い合わせを受け付けました。担当者より順次ご連絡いたします。")
        }
    }

    private func submitContact() {
        guard !subject.isEmpty, !message.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let userEmail = authManager.currentUser?.email ?? "unknown@byters.jp"

        Task {
            do {
                _ = try await APIClient.shared.submitContactForm(
                    category: category,
                    subject: subject,
                    message: message,
                    email: userEmail
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "送信に失敗しました。時間をおいて再度お試しください。"
                }
            }
        }
    }
}

// MARK: - Pending Reviews View

struct PendingReviewsView: View {
    @StateObject private var viewModel = PendingReviewsViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.isLoading {
                SkeletonList(count: 3)
            } else if viewModel.pendingReviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("レビュー待ちのお仕事はありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.pendingReviews) { pending in
                    NavigationLink(destination: SubmitReviewView(pendingReview: pending, onComplete: {
                        Task { await viewModel.loadData() }
                    })) {
                        PendingReviewRow(pending: pending)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("レビューを書く")
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct PendingReviewRow: View {
    let pending: PendingReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pending.jobTitle ?? "お仕事")
                .font(.headline)

            if let name = pending.revieweeName {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if let date = pending.workDate {
                Text("勤務日: \(date)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class PendingReviewsViewModel: ObservableObject {
    @Published var pendingReviews: [PendingReview] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            pendingReviews = try await api.getPendingReviews()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Submit Review View

struct SubmitReviewView: View {
    let pendingReview: PendingReview
    let onComplete: () -> Void

    @State private var ratingType: String? = nil // "good" or "bad"
    @State private var comment = ""
    @State private var selectedTags: Set<String> = []
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let goodTags = ["時間通り", "丁寧な対応", "また働きたい", "清潔な職場", "わかりやすい指示"]
    private let badTags = ["時間にルーズ", "対応が不親切", "説明不足", "環境が悪い"]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Text(pendingReview.jobTitle ?? "お仕事")
                        .font(.title3)
                        .fontWeight(.bold)

                    if let name = pendingReview.revieweeName {
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            Section("この事業者はどうでしたか？") {
                HStack(spacing: 24) {
                    Spacer()
                    Button(action: { ratingType = "good" }) {
                        VStack(spacing: 8) {
                            Image(systemName: ratingType == "good" ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 40))
                                .foregroundColor(ratingType == "good" ? .green : .gray)
                            Text("良い")
                                .font(.headline)
                                .foregroundColor(ratingType == "good" ? .green : .gray)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: { ratingType = "bad" }) {
                        VStack(spacing: 8) {
                            Image(systemName: ratingType == "bad" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.system(size: 40))
                                .foregroundColor(ratingType == "bad" ? .red : .gray)
                            Text("悪い")
                                .font(.headline)
                                .foregroundColor(ratingType == "bad" ? .red : .gray)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
                .padding(.vertical, 12)
            }

            if let type = ratingType {
                Section("タグを選択（任意）") {
                    let tags = type == "good" ? goodTags : badTags
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }) {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTags.contains(tag) ? (type == "good" ? Color.green.opacity(0.2) : Color.red.opacity(0.2)) : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedTags.contains(tag) ? (type == "good" ? .green : .red) : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }

            Section("コメント（任意）") {
                TextEditor(text: $comment)
                    .frame(height: 100)
            }

            if let error = errorMessage {
                Section {
                    Text(error).foregroundColor(.red)
                }
            }

            Section {
                Button(action: submitReview) {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("レビューを投稿")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || ratingType == nil)
            }
        }
        .navigationTitle("レビューを書く")
        .navigationBarTitleDisplayMode(.inline)
        .alert("レビューを投稿しました！", isPresented: $showSuccess) {
            Button("OK") {
                onComplete()
                dismiss()
            }
        }
    }

    private func submitReview() {
        guard let type = ratingType else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.submitReview(
                    jobId: pendingReview.jobId,
                    revieweeId: pendingReview.revieweeId,
                    rating: type == "good" ? 5 : 1,
                    comment: comment.isEmpty ? nil : comment
                )
                showSuccess = true
            } catch {
                errorMessage = "レビューの投稿に失敗しました"
            }
            isSubmitting = false
        }
    }
}

// MARK: - My Reviews View

struct MyReviewsView: View {
    @StateObject private var viewModel = MyReviewsViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if viewModel.isLoading {
                SkeletonList(count: 3)
            } else if viewModel.reviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.bubble")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("レビュー履歴はありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Average Rating Section
                Section {
                    VStack(spacing: 8) {
                        Text(String(format: "%.1f", viewModel.averageRating))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: myReviewsStarImageName(for: star, rating: viewModel.averageRating))
                                    .font(.title3)
                                    .foregroundColor(.orange)
                            }
                        }

                        Text("\(viewModel.reviews.count)件のレビュー")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Reviews List
                Section("受け取ったレビュー") {
                    ForEach(viewModel.reviews) { review in
                        MyReviewRow(review: review)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("レビュー履歴")
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
    }

    private func myReviewsStarImageName(for star: Int, rating: Double) -> String {
        let threshold = Double(star)
        if rating >= threshold {
            return "star.fill"
        } else if rating >= threshold - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

struct MyReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Reviewer avatar
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.reviewerName ?? "匿名ユーザー")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Star rating
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                if let date = review.createdAt {
                    Text(myReviewFormatDate(date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(5)
            }
        }
        .padding(.vertical, 6)
    }

    private func myReviewFormatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy/MM/dd"
            return displayFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy/MM/dd"
            return displayFormatter.string(from: date)
        }
        return dateString.prefix(10).replacingOccurrences(of: "-", with: "/")
    }
}

@MainActor
class MyReviewsViewModel: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(reviews.count)
    }

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            reviews = try await api.getMyReviews()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }

    var body: some View {
        Form {
            Section(header: Text("現在のパスワード")) {
                SecureField("現在のパスワード", text: $currentPassword)
            }

            Section(header: Text("新しいパスワード"), footer: Text("8文字以上で入力してください")) {
                SecureField("新しいパスワード", text: $newPassword)
                SecureField("新しいパスワード（確認）", text: $confirmPassword)
            }

            if newPassword != confirmPassword && !confirmPassword.isEmpty {
                Section {
                    Text("パスワードが一致しません")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section {
                Button(action: changePassword) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("パスワードを変更")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.medium)
                    }
                }
                .disabled(!isValid || isLoading)
            }
        }
        .navigationTitle("パスワード変更")
        .navigationBarTitleDisplayMode(.inline)
        .alert("パスワード変更完了", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("パスワードが正常に変更されました。")
        }
    }

    private func changePassword() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIClient.shared.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                showSuccess = true
            } catch {
                errorMessage = "パスワードの変更に失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

#Preview {
    MyPageView()
        .environmentObject(AuthManager.shared)
}
