import SwiftUI
import PhotosUI

struct MyPageView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MyPageViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
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

                            NavigationLink(destination: NotificationSettingsView()) {
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
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User?

    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                )

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
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
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
            .background(Color.white)
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

    private let api = APIClient.shared

    func loadData() async {
        do {
            let wallet = try await api.getWallet()
            walletBalance = wallet.balance
        } catch {
            print("Failed to load wallet: \(error)")
        }

        do {
            let pendingReviews = try await api.getPendingReviews()
            pendingReviewCount = pendingReviews.count
        } catch {
            print("Failed to load pending reviews: \(error)")
        }
    }
}

// MARK: - Wallet Detail View

struct WalletDetailView: View {
    @StateObject private var viewModel = WalletDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
class WalletDetailViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var transactions: [Transaction] = []

    private let api = APIClient.shared

    func loadData() async {
        do {
            wallet = try await api.getWallet()
            transactions = try await api.getTransactions()
        } catch {
            print("Error loading wallet data: \(error)")
        }
    }
}

// MARK: - Transaction History

struct TransactionHistoryView: View {
    @StateObject private var viewModel = TransactionHistoryViewModel()

    var body: some View {
        List {
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            transactions = try await api.getTransactions()
        } catch {
            print("Error loading transactions: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Bank Account List

struct BankAccountListView: View {
    @StateObject private var viewModel = BankAccountViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        List {
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
                }
                .onDelete { indexSet in
                    Task {
                        await viewModel.deleteAccount(at: indexSet)
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
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddBankAccountView(onSuccess: {
                Task { await viewModel.loadData() }
            })
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            accounts = try await api.getBankAccounts()
        } catch {
            print("Error loading bank accounts: \(error)")
        }
        isLoading = false
    }

    func deleteAccount(at indexSet: IndexSet) async {
        for index in indexSet {
            let account = accounts[index]
            do {
                _ = try await api.deleteBankAccount(accountId: account.id)
                accounts.remove(at: index)
            } catch {
                print("Error deleting account: \(error)")
            }
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
        !accountHolderName.isEmpty
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
                Task { await viewModel.requestWithdrawal(accountId: selectedAccountId!, amount: Int(amount)!) }
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
            print("Error loading data: \(error)")
        }
    }

    func requestWithdrawal(accountId: String, amount: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            let request = try await api.requestWithdrawal(bankAccountId: accountId, amount: amount)
            withdrawals.insert(request, at: 0)
            await loadData() // Refresh wallet balance
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Application History

struct ApplicationHistoryView: View {
    @StateObject private var viewModel = ApplicationHistoryViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.applications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("応募履歴はありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.applications) { application in
                    ApplicationRow(application: application)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("応募履歴")
        .task {
            await viewModel.loadData()
        }
    }
}

struct ApplicationRow: View {
    let application: Application

    var statusColor: Color {
        switch application.status {
        case "pending": return .orange
        case "accepted": return .green
        case "rejected": return .red
        case "completed": return .blue
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(application.jobTitle ?? "求人")
                    .font(.headline)
                Spacer()
                Text(application.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            if let employer = application.employerName {
                Text(employer)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if let date = application.createdAt {
                Text("応募日: \(date)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class ApplicationHistoryViewModel: ObservableObject {
    @Published var applications: [Application] = []
    @Published var isLoading = false

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            applications = try await api.getMyApplications()
        } catch {
            print("Error loading applications: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Work History

struct WorkHistoryView: View {
    @StateObject private var viewModel = WorkHistoryViewModel()

    var body: some View {
        List {
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            workHistory = try await api.getWorkHistory()
        } catch {
            print("Error loading work history: \(error)")
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

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("名前", text: $name)
                TextField("電話番号", text: $phone)
                    .keyboardType(.phonePad)
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
    }

    func saveProfile() {
        isLoading = true
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
                print("Error saving profile: \(error)")
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

    private let api = APIClient.shared

    func loadData() async {
        do {
            verification = try await api.getIdentityVerificationStatus()
        } catch {
            print("Error loading verification status: \(error)")
        }
    }

    func submit(documentType: String, frontImage: Data) async {
        isLoading = true
        do {
            _ = try await api.submitIdentityVerification(documentType: documentType, frontImageData: frontImage, backImageData: nil)
            await loadData()
        } catch {
            print("Error submitting verification: \(error)")
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
    let faqs = [
        ("報酬はいつ受け取れますか？", "勤務完了後、事業者が承認すると即座にウォレットに反映されます。出金申請から1〜3営業日で銀行口座に振り込まれます。"),
        ("本人確認は必須ですか？", "お仕事に応募するには本人確認が必要です。運転免許証、マイナンバーカード、パスポートのいずれかをご準備ください。"),
        ("キャンセルはできますか？", "勤務日の前日までキャンセル可能です。当日キャンセルは評価に影響する場合があります。"),
        ("出金手数料はかかりますか？", "出金手数料は無料です。"),
    ]

    var body: some View {
        List {
            ForEach(faqs, id: \.0) { faq in
                DisclosureGroup(faq.0) {
                    Text(faq.1)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4)
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            pendingReviews = try await api.getPendingReviews()
        } catch {
            print("Error loading pending reviews: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Submit Review View

struct SubmitReviewView: View {
    let pendingReview: PendingReview
    let onComplete: () -> Void

    @State private var rating = 5
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

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

            Section("評価") {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button(action: { rating = star }) {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(.yellow)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Text(ratingDescription)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }

            Section("コメント（任意）") {
                TextEditor(text: $comment)
                    .frame(height: 120)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(action: submitReview) {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("レビューを投稿")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting)
            }
        }
        .navigationTitle("レビューを書く")
        .navigationBarTitleDisplayMode(.inline)
        .alert("レビューを投稿しました", isPresented: $showSuccess) {
            Button("OK") {
                onComplete()
                dismiss()
            }
        }
    }

    private var ratingDescription: String {
        switch rating {
        case 1: return "非常に悪い"
        case 2: return "悪い"
        case 3: return "普通"
        case 4: return "良い"
        case 5: return "非常に良い"
        default: return ""
        }
    }

    private func submitReview() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.submitReview(
                    jobId: pendingReview.jobId,
                    revieweeId: pendingReview.revieweeId,
                    rating: rating,
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            reviews = try await api.getMyReviews()
        } catch {
            print("Error loading reviews: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    MyPageView()
        .environmentObject(AuthManager())
}
