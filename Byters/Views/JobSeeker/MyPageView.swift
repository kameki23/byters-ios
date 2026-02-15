import SwiftUI
import PhotosUI

// MARK: - Character Extension for Katakana

private extension Character {
    var isKatakana: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x30A0...0x30FF).contains(scalar.value)
    }
}

struct MyPageView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MyPageViewModel()
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
        NavigationStack {
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

                    // Profile Header
                    ProfileHeaderView(user: authManager.currentUser)
                        .padding(.bottom, 16)

                    // Menu Sections
                    VStack(spacing: 12) {
                        // Wallet Section
                        MenuSection(title: "ウォレット") {
                            NavigationLink(destination: WalletDetailView()) {
                                MenuRow(
                                    icon: "yensign.circle.fill",
                                    iconColor: .green,
                                    title: "残高",
                                    value: "¥\(viewModel.walletBalance.formatted())"
                                )
                            }

                            NavigationLink(destination: BankAccountListView()) {
                                MenuRow(
                                    icon: "building.columns.fill",
                                    iconColor: .blue,
                                    title: "銀行口座",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: WithdrawalView()) {
                                MenuRow(
                                    icon: "arrow.down.circle.fill",
                                    iconColor: .purple,
                                    title: "出金申請",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: TransactionHistoryView()) {
                                MenuRow(
                                    icon: "list.bullet.rectangle.fill",
                                    iconColor: .orange,
                                    title: "取引履歴",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: TaxDocumentsView()) {
                                MenuRow(
                                    icon: "doc.text.fill",
                                    iconColor: .blue,
                                    title: "源泉徴収票",
                                    showChevron: true
                                )
                            }
                        }

                        // Work Section
                        MenuSection(title: "お仕事") {
                            NavigationLink(destination: UpcomingWorkView()) {
                                MenuRow(
                                    icon: "calendar.badge.clock",
                                    iconColor: .blue,
                                    title: "予定のお仕事",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: ApplicationHistoryView()) {
                                MenuRow(
                                    icon: "doc.text.fill",
                                    iconColor: .orange,
                                    title: "応募履歴",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: WorkHistoryView()) {
                                MenuRow(
                                    icon: "clock.fill",
                                    iconColor: .purple,
                                    title: "勤務履歴",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: FavoritesView()) {
                                MenuRow(
                                    icon: "heart.fill",
                                    iconColor: .red,
                                    title: "お気に入り",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: PendingReviewsView()) {
                                MenuRow(
                                    icon: "star.fill",
                                    iconColor: .yellow,
                                    title: "レビューを書く",
                                    value: viewModel.pendingReviewCount > 0 ? "\(viewModel.pendingReviewCount)件" : nil,
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: MyReviewsView()) {
                                MenuRow(
                                    icon: "star.bubble.fill",
                                    iconColor: .blue,
                                    title: "レビュー履歴",
                                    showChevron: true
                                )
                            }
                        }

                        // Growth Section
                        MenuSection(title: "スキルアップ") {
                            NavigationLink(destination: EarningsGoalView()) {
                                MenuRow(
                                    icon: "target",
                                    iconColor: .green,
                                    title: "収入目標",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: QualificationsView()) {
                                MenuRow(
                                    icon: "checkmark.seal.fill",
                                    iconColor: .blue,
                                    title: "資格・免許",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: BadgesView()) {
                                MenuRow(
                                    icon: "star.circle.fill",
                                    iconColor: .yellow,
                                    title: "バッジ",
                                    showChevron: true
                                )
                            }
                        }

                        // Account Section
                        MenuSection(title: "アカウント") {
                            NavigationLink(destination: ProfileEditView()) {
                                MenuRow(
                                    icon: "person.fill",
                                    iconColor: .blue,
                                    title: "プロフィール編集",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: IdentityVerificationView()) {
                                MenuRow(
                                    icon: "checkmark.shield.fill",
                                    iconColor: .green,
                                    title: "本人確認",
                                    value: authManager.currentUser?.identityStatusDisplay ?? "未提出"
                                )
                            }

                            NavigationLink(destination: TimesheetAdjustmentView()) {
                                MenuRow(
                                    icon: "clock.arrow.2.circlepath",
                                    iconColor: .purple,
                                    title: "勤務時間修正",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: ChangePasswordView()) {
                                MenuRow(
                                    icon: "lock.fill",
                                    iconColor: .gray,
                                    title: "パスワード変更",
                                    showChevron: true
                                )
                            }
                        }

                        // Settings Section
                        MenuSection(title: "設定") {
                            NavigationLink(destination: NotificationListView()) {
                                MenuRow(
                                    icon: "bell.badge.fill",
                                    iconColor: .orange,
                                    title: "通知一覧",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: JobSeekerNotificationSettingsView()) {
                                MenuRow(
                                    icon: "bell.fill",
                                    iconColor: .red,
                                    title: "通知設定",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: EmailSettingsView()) {
                                MenuRow(
                                    icon: "envelope.fill",
                                    iconColor: .blue,
                                    title: "メール設定",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: LocationSettingsView()) {
                                MenuRow(
                                    icon: "location.fill",
                                    iconColor: .green,
                                    title: "エリア設定",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: MutedEmployersView()) {
                                MenuRow(
                                    icon: "speaker.slash.fill",
                                    iconColor: .gray,
                                    title: "ミュート管理",
                                    showChevron: true
                                )
                            }
                        }

                        // Support Section
                        MenuSection(title: "サポート") {
                            NavigationLink(destination: FAQView()) {
                                MenuRow(
                                    icon: "questionmark.circle.fill",
                                    iconColor: .blue,
                                    title: "よくある質問",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: ContactView()) {
                                MenuRow(
                                    icon: "envelope.fill",
                                    iconColor: .gray,
                                    title: "お問い合わせ",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: BugReportView()) {
                                MenuRow(
                                    icon: "ant.fill",
                                    iconColor: .red,
                                    title: "バグ報告・機能リクエスト",
                                    showChevron: true
                                )
                            }
                        }

                        // Legal Section
                        MenuSection(title: "法的情報") {
                            NavigationLink(destination: TermsOfServiceView()) {
                                MenuRow(
                                    icon: "doc.text.fill",
                                    iconColor: .gray,
                                    title: "利用規約",
                                    showChevron: true
                                )
                            }

                            NavigationLink(destination: PrivacyPolicyView()) {
                                MenuRow(
                                    icon: "hand.raised.fill",
                                    iconColor: .gray,
                                    title: "プライバシーポリシー",
                                    showChevron: true
                                )
                            }
                        }

                        // App Version
                        HStack {
                            Spacer()
                            VStack(spacing: 2) {
                                Text("Byters")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
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
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User?

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
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        )
                }
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
                }
                .padding(.horizontal, 24)
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
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }

            if showChevron || value == nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

// MARK: - View Model

@MainActor
class MyPageViewModel: ObservableObject {
    @Published var walletBalance: Int = 0
    @Published var pendingReviewCount: Int = 0
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        do {
            let wallet = try await api.getWallet()
            walletBalance = wallet.balance
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let pendingReviews = try await api.getPendingReviews()
            pendingReviewCount = pendingReviews.count
        } catch {
            errorMessage = error.localizedDescription
        }
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
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.transactions.isEmpty {
                Text("取引履歴はありません")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.transactions) { transaction in
                    TransactionRow(transaction: transaction)
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
                ProgressView()
                    .frame(maxWidth: .infinity)
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
    @State private var bankCode = ""
    @State private var branchName = ""
    @State private var branchCode = ""
    @State private var accountType = "ordinary"
    @State private var accountNumber = ""
    @State private var accountHolderName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("銀行情報") {
                    TextField("銀行名", text: $bankName)
                    TextField("銀行コード（4桁）", text: $bankCode)
                        .keyboardType(.numberPad)
                        .onChange(of: bankCode) { _, newValue in
                            bankCode = String(newValue.filter { $0.isNumber }.prefix(4))
                        }
                    TextField("支店名", text: $branchName)
                    TextField("支店コード（3桁）", text: $branchCode)
                        .keyboardType(.numberPad)
                        .onChange(of: branchCode) { _, newValue in
                            branchCode = String(newValue.filter { $0.isNumber }.prefix(3))
                        }
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
                        .onChange(of: accountHolderName) { _, newValue in
                            // 全角スペースとカタカナのみ許可
                            accountHolderName = newValue.filter { char in
                                char.isKatakana || char == "　" || char == " " || char == "ー"
                            }
                        }

                    if !accountHolderName.isEmpty && !isValidKatakana(accountHolderName) {
                        Text("口座名義はカタカナで入力してください")
                            .font(.caption)
                            .foregroundColor(.orange)
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
            .navigationTitle("銀行口座を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    var isValid: Bool {
        !bankName.isEmpty &&
        bankCode.count == 4 &&
        !branchName.isEmpty &&
        branchCode.count == 3 &&
        accountNumber.count == 7 &&
        !accountHolderName.isEmpty &&
        isValidKatakana(accountHolderName)
    }

    private func isValidKatakana(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { $0.isKatakana || $0 == "　" || $0 == " " || $0 == "ー" }
    }

    func addAccount() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.addBankAccount(
                    bankName: bankName,
                    bankCode: bankCode,
                    branchName: branchName,
                    branchCode: branchCode,
                    accountType: accountType,
                    accountNumber: accountNumber,
                    accountHolderName: accountHolderName
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
            Text("¥\(amount)を出金申請しますか？\n処理には1〜3営業日かかります。")
        }
        .task {
            await viewModel.loadData()
        }
    }

    var canSubmit: Bool {
        guard let accountId = selectedAccountId, !accountId.isEmpty,
              let amountInt = Int(amount), amountInt >= 1000,
              let balance = viewModel.wallet?.balance, amountInt <= balance else {
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
            guard amount <= latestWallet.balance else {
                errorMessage = "残高不足です。現在の出金可能額: ¥\(latestWallet.balance)"
                isLoading = false
                return
            }

            let request = try await api.requestWithdrawal(bankAccountId: accountId, amount: amount)
            withdrawals.insert(request, at: 0)
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
                Spacer()
                ProgressView("読み込み中...")
                Spacer()
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
                ProgressView()
                    .frame(maxWidth: .infinity)
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
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } placeholder: {
                                defaultAvatar
                            }
                        } else {
                            defaultAvatar
                        }

                        Button(isUploadingImage ? "アップロード中..." : "画像を変更") {
                            showImagePicker = true
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
                TextField("電話番号", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

            Section("自己紹介") {
                TextEditor(text: $bio)
                    .frame(height: 100)
            }

            Section("居住地") {
                Picker("都道府県", selection: $prefecture) {
                    Text("選択してください").tag("")
                    ForEach(Prefecture.all) { pref in
                        Text(pref.name).tag(pref.name)
                    }
                }
                TextField("市区町村", text: $city)
            }

            Section {
                Button(action: saveProfile) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isLoading)
            }
        }
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
            ImagePicker(image: $selectedImage)
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
        isUploadingImage = true
        do {
            _ = try await APIClient.shared.uploadProfileImage(imageData: imageData)
            await authManager.checkAuthStatus()
        } catch {
            saveError = "画像のアップロードに失敗しました"
        }
        isUploadingImage = false
    }

    func saveProfile() {
        isLoading = true
        saveError = nil
        Task {
            do {
                let updated = try await APIClient.shared.updateProfile(
                    name: name.isEmpty ? nil : name,
                    phone: phone.isEmpty ? nil : phone,
                    bio: bio.isEmpty ? nil : bio,
                    prefecture: prefecture.isEmpty ? nil : prefecture,
                    city: city.isEmpty ? nil : city
                )
                authManager.currentUser = updated
                showingSaved = true
            } catch {
                saveError = "プロフィールの保存に失敗しました。もう一度お試しください。"
            }
            isLoading = false
        }
    }
}

// MARK: - Identity Verification

struct IdentityVerificationView: View {
    @StateObject private var viewModel = IdentityVerificationViewModel()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var documentType = "drivers_license"

    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("現在のステータス") {
                HStack {
                    Text("本人確認")
                    Spacer()
                    Text(viewModel.verification?.statusDisplay ?? "未提出")
                        .foregroundColor(statusColor)
                }
            }

            if viewModel.verification?.status != "approved" {
                Section("書類を提出") {
                    Picker("書類の種類", selection: $documentType) {
                        Text("運転免許証").tag("drivers_license")
                        Text("マイナンバーカード").tag("my_number")
                        Text("パスポート").tag("passport")
                        Text("在留カード").tag("residence_card")
                    }

                    Button(action: { showingImagePicker = true }) {
                        HStack {
                            Image(systemName: "camera")
                            Text(selectedImage == nil ? "書類を撮影する" : "書類を撮り直す")
                        }
                    }

                    if selectedImage != nil {
                        Image(uiImage: selectedImage!)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                    }
                }

                if selectedImage != nil {
                    Section {
                        Button(action: submitVerification) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("提出する")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }

            if viewModel.verification?.status == "rejected" {
                Section {
                    Text("却下理由: \(viewModel.verification?.rejectionReason ?? "不明")")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("本人確認")
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .task {
            await viewModel.loadData()
        }
    }

    var statusColor: Color {
        switch viewModel.verification?.status {
        case "approved": return .green
        case "pending": return .orange
        case "rejected": return .red
        default: return .gray
        }
    }

    func submitVerification() {
        guard let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        Task {
            await viewModel.submit(documentType: documentType, frontImage: imageData)
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

    func submit(documentType: String, frontImage: Data) async {
        isLoading = true
        do {
            _ = try await api.submitIdentityVerification(documentType: documentType, frontImageData: frontImage, backImageData: nil)
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
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
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
            ("出勤・退勤はどうやって記録しますか？", "勤務先に設置されたQRコードをアプリで読み取ることで出退勤を記録できます。"),
        ]),
        ("報酬・出金について", [
            ("報酬はいつ受け取れますか？", "勤務完了後、事業者が承認すると即座にウォレットに反映されます。出金申請から1〜3営業日で銀行口座に振り込まれます。"),
            ("出金手数料はかかりますか？", "出金手数料は無料です。"),
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
                TextEditor(text: $message)
                    .frame(height: 150)
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
                ProgressView()
                    .frame(maxWidth: .infinity)
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
                            Text("Good")
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
                            Text("Bad")
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
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
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
                ForEach(viewModel.reviews) { review in
                    MyReviewRow(review: review)
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
}

struct MyReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Spacer()

                if let date = review.createdAt {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
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
