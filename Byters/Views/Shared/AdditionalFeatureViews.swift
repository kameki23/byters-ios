import SwiftUI
import AVKit

// MARK: - API Response Helpers

private struct GenericResponse: Codable {
    let success: Bool?
    let message: String?
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @State private var searchText = ""
    @State private var selectedCategory: String?

    private var filteredArticles: [HelpArticle] {
        var articles = HelpArticle.articles
        if let cat = selectedCategory {
            articles = articles.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            articles = articles.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        return articles
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("ヘルプを検索...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                if selectedCategory == nil && searchText.isEmpty {
                    // Category Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(HelpArticle.categories, id: \.name) { cat in
                            Button(action: {
                                withAnimation { selectedCategory = cat.name }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: cat.icon)
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text(cat.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // Category header with back button
                    if let cat = selectedCategory {
                        HStack {
                            Button(action: {
                                withAnimation { selectedCategory = nil }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("カテゴリ一覧")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                            Spacer()
                            Text(cat)
                                .font(.headline)
                        }
                        .padding(.horizontal)
                    }

                    // Articles List
                    VStack(spacing: 8) {
                        ForEach(filteredArticles) { article in
                            NavigationLink(destination: HelpArticleDetailView(article: article)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(article.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text(article.content.prefix(60) + "...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if filteredArticles.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("該当する記事が見つかりませんでした")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal)
                }

                // Contact Support
                VStack(spacing: 12) {
                    Divider()
                    Text("お探しの情報が見つかりませんか？")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    NavigationLink(destination: ContactView()) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("お問い合わせ")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ヘルプセンター")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpArticleDetailView: View {
    let article: HelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())

                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Divider()

                Text(article.content)
                    .font(.body)
                    .lineSpacing(6)
            }
            .padding()
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Report View

struct ReportContentView: View {
    let targetType: String
    let targetId: String
    let targetTitle: String?

    @Environment(\.dismiss) var dismiss
    @State private var selectedReason = ""
    @State private var detail = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let reasons: [String]

    init(targetType: String, targetId: String, targetTitle: String? = nil) {
        self.targetType = targetType
        self.targetId = targetId
        self.targetTitle = targetTitle

        switch targetType {
        case "job":
            self.reasons = [
                "詐欺的な求人内容",
                "違法な労働条件",
                "ハラスメント・差別的な内容",
                "個人情報の不正収集",
                "実在しない求人",
                "賃金が最低賃金未満",
                "その他"
            ]
        case "message":
            self.reasons = [
                "ハラスメント",
                "スパム・迷惑メッセージ",
                "詐欺的な内容",
                "個人情報の要求",
                "脅迫・暴力的な内容",
                "その他"
            ]
        default:
            self.reasons = [
                "不適切な行為",
                "詐欺",
                "ハラスメント",
                "なりすまし",
                "その他"
            ]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let title = targetTitle {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("「\(title)」を通報")
                                .font(.subheadline)
                        }
                    }
                }

                Section("通報理由") {
                    ForEach(reasons, id: \.self) { reason in
                        Button(action: { selectedReason = reason }) {
                            HStack {
                                Text(reason)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section("詳細（任意）") {
                    TextEditor(text: $detail)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if detail.isEmpty {
                                    Text("具体的な状況を記入してください")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: submitReport) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("通報する")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(selectedReason.isEmpty || isSubmitting)
                }

                Section {
                    Text("通報内容は24時間体制で確認し、適切に対応いたします。虚偽の通報はアカウント制限の対象となります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("通報を送信しました", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("ご報告ありがとうございます。内容を確認の上、適切に対応いたします。")
            }
        }
    }

    private func submitReport() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.request(
                    endpoint: "/reports",
                    method: "POST",
                    body: [
                        "targetType": targetType,
                        "targetId": targetId,
                        "reason": selectedReason,
                        "detail": detail
                    ]
                ) as GenericResponse
                showSuccess = true
            } catch {
                errorMessage = "通報の送信に失敗しました。しばらくしてからお試しください。"
            }
            isSubmitting = false
        }
    }
}

// MARK: - Time Modification Request View

struct TimeModificationRequestView: View {
    let applicationId: String
    let jobTitle: String?
    let originalStartTime: String?
    let originalEndTime: String?

    @Environment(\.dismiss) var dismiss
    @State private var requestType = "late_arrival"
    @State private var newStartTime = ""
    @State private var newEndTime = ""
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let requestTypes = [
        ("late_arrival", "遅刻（実際の出勤時刻が遅かった）"),
        ("early_departure", "早退（予定より早く退勤した）"),
        ("overtime", "残業（予定より長く勤務した）"),
        ("missed_checkin", "出勤打刻忘れ"),
        ("missed_checkout", "退勤打刻忘れ"),
        ("employer_shortened", "事業者都合による時間短縮"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let title = jobTitle {
                    Section {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundColor(.orange)
                            Text(title)
                                .font(.subheadline)
                        }
                    }
                }

                Section("修正種別") {
                    ForEach(requestTypes, id: \.0) { (value, label) in
                        Button(action: { requestType = value }) {
                            HStack {
                                Text(label)
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                Spacer()
                                if requestType == value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section("修正後の時刻") {
                    if let orig = originalStartTime {
                        HStack {
                            Text("元の出勤時刻")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(orig)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("修正後の出勤時刻")
                        Spacer()
                        TextField("09:00", text: $newStartTime)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    if let orig = originalEndTime {
                        HStack {
                            Text("元の退勤時刻")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(orig)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("修正後の退勤時刻")
                        Spacer()
                        TextField("18:00", text: $newEndTime)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section(header: Text("理由"), footer: Text("10文字以上で理由を入力してください")) {
                    TextEditor(text: $reason)
                        .frame(height: 100)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: submitRequest) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("修正をリクエスト")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(reason.count < 10 || isSubmitting)
                }

                Section {
                    Text("修正リクエストは事業者の承認後に反映されます。通常、当日〜翌日中に回答があります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("勤務時間の修正")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("修正リクエストを送信しました", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("事業者の承認をお待ちください。")
            }
        }
    }

    private func submitRequest() {
        guard reason.count >= 10 else {
            errorMessage = "理由は10文字以上で入力してください"
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.request(
                    endpoint: "/time-modifications",
                    method: "POST",
                    body: [
                        "applicationId": applicationId,
                        "requestType": requestType,
                        "requestedStartTime": newStartTime.isEmpty ? nil : newStartTime,
                        "requestedEndTime": newEndTime.isEmpty ? nil : newEndTime,
                        "reason": reason
                    ].compactMapValues { $0 }
                ) as GenericResponse
                showSuccess = true
            } catch {
                errorMessage = "リクエストの送信に失敗しました"
            }
            isSubmitting = false
        }
    }
}

// MARK: - Cancellation Policy View

struct CancellationPolicyView: View {
    let hoursRemaining: Int?
    let onConfirmCancel: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var confirmCancel = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Warning Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("キャンセルポリシー")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)

                    // Policy Rules
                    VStack(alignment: .leading, spacing: 12) {
                        Text("キャンセルのペナルティ")
                            .font(.headline)

                        ForEach(CancellationPolicy.rules, id: \.hours) { rule in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(rule.points == 0 ? Color.green : (rule.points <= 1 ? Color.yellow : Color.red))
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.label)
                                        .font(.subheadline)
                                    if rule.points > 0 {
                                        Text("ペナルティ \(rule.points)ポイント加算")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }

                                Spacer()

                                if let hours = hoursRemaining {
                                    let isCurrentBracket = CancellationPolicy.penalty(hoursRemaining: hours) == rule.points
                                    if isCurrentBracket {
                                        Text("現在")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Restriction Levels
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ペナルティポイントによる制限")
                            .font(.headline)

                        ForEach(CancellationPolicy.restrictions, id: \.label) { restriction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(restriction.range.lowerBound)〜\(restriction.range.upperBound)pt")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(restriction.range.lowerBound == 0 ? Color.green : Color.orange)
                                    .clipShape(Capsule())
                                    .frame(width: 70)

                                Text(restriction.label)
                                    .font(.subheadline)
                            }
                        }
                    }

                    // No-show warning
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("無断欠勤について")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Text("無断欠勤（連絡なしのキャンセル）は、アカウントの無期限停止の対象となります。やむを得ない場合は必ず事前に連絡してください。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Penalty Reduction
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ペナルティの減少方法")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("お仕事完了後にレビューを投稿すると、ペナルティが1ポイント減少します。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Cancel Button
                    if hoursRemaining != nil {
                        let penalty = CancellationPolicy.penalty(hoursRemaining: hoursRemaining!)
                        Button(action: { confirmCancel = true }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text(penalty > 0 ? "ペナルティ\(penalty)ptを承知の上でキャンセル" : "キャンセルする")
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
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("キャンセルポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("キャンセルの確認", isPresented: $confirmCancel) {
                Button("キャンセルする", role: .destructive) {
                    onConfirmCancel()
                    dismiss()
                }
                Button("戻る", role: .cancel) {}
            } message: {
                if let hours = hoursRemaining {
                    let penalty = CancellationPolicy.penalty(hoursRemaining: hours)
                    if penalty > 0 {
                        Text("キャンセルするとペナルティ\(penalty)ポイントが加算されます。本当にキャンセルしますか？")
                    } else {
                        Text("この応募をキャンセルしますか？")
                    }
                } else {
                    Text("この応募をキャンセルしますか？")
                }
            }
        }
    }
}

// MARK: - Referral Program View

struct ReferralProgramView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange.opacity(0.6))

                VStack(spacing: 12) {
                    Text("友達紹介プログラム")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("現在検討中のため、保留とさせていただいております。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("サービス開始の準備が整い次第、\nお知らせいたします。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("友達紹介")
        .navigationBarTitleDisplayMode(.inline)
    }

}

// Share Sheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Worker Management Views (Employer)

struct WorkerManagementView: View {
    @State private var selectedTab = 0
    @StateObject private var viewModel = WorkerManagementViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("お気に入り").tag(0)
                Text("ブロック").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                favoritesList
            } else {
                blockedList
            }
        }
        .navigationTitle("ワーカー管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.favorites.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("お気に入りワーカーがいません")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("応募管理画面でワーカーをお気に入りに追加できます")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(viewModel.favorites) { worker in
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(worker.workerName ?? "ワーカー")
                            .font(.headline)
                        HStack(spacing: 8) {
                            if let rate = worker.goodRate {
                                HStack(spacing: 2) {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.caption2)
                                    Text("\(rate)%")
                                        .font(.caption)
                                }
                                .foregroundColor(.green)
                            }
                            if let jobs = worker.completedJobs {
                                HStack(spacing: 2) {
                                    Image(systemName: "briefcase.fill")
                                        .font(.caption2)
                                    Text("\(jobs)回")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                }
                .swipeActions(edge: .trailing) {
                    Button("削除", role: .destructive) {
                        Task { await viewModel.removeFavorite(worker) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var blockedList: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.blocked.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "nosign")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("ブロックしたワーカーはいません")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(viewModel.blocked) { worker in
                HStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.red)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(worker.workerName ?? "ワーカー")
                            .font(.headline)
                        if let reason = worker.reason {
                            Text("理由: \(reason)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button("解除") {
                        Task { await viewModel.unblock(worker) }
                    }
                    .tint(.green)
                }
            }
        }
    }
}

@MainActor
class WorkerManagementViewModel: ObservableObject {
    @Published var favorites: [FavoriteWorker] = []
    @Published var blocked: [BlockedWorker] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            favorites = try await api.request(endpoint: "/employer/favorite-workers")
        } catch {
            favorites = []
        }
        do {
            blocked = try await api.request(endpoint: "/employer/blocked-workers")
        } catch {
            blocked = []
        }
        isLoading = false
    }

    func removeFavorite(_ worker: FavoriteWorker) async {
        do {
            _ = try await api.request(
                endpoint: "/employer/favorite-workers/\(worker.workerId)",
                method: "DELETE"
            ) as GenericResponse
            favorites.removeAll { $0.id == worker.id }
        } catch {
            errorMessage = "削除に失敗しました"
        }
    }

    func unblock(_ worker: BlockedWorker) async {
        do {
            _ = try await api.request(
                endpoint: "/employer/blocked-workers/\(worker.workerId)",
                method: "DELETE"
            ) as GenericResponse
            blocked.removeAll { $0.id == worker.id }
        } catch {
            errorMessage = "解除に失敗しました"
        }
    }
}

// MARK: - Block Worker Sheet

struct BlockWorkerSheet: View {
    let workerId: String
    let workerName: String?
    let onComplete: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let reasons = [
        "無断欠勤",
        "業務態度が悪い",
        "遅刻が多い",
        "指示に従わない",
        "コミュニケーションの問題",
        "その他",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "nosign")
                            .foregroundColor(.red)
                        Text("\(workerName ?? "このワーカー")をブロック")
                            .font(.subheadline)
                    }
                }

                Section("ブロック理由") {
                    ForEach(reasons, id: \.self) { r in
                        Button(action: { reason = r }) {
                            HStack {
                                Text(r)
                                    .foregroundColor(.primary)
                                Spacer()
                                if reason == r {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section {
                    Text("ブロックすると、このワーカーはあなたの求人を閲覧・応募できなくなります。ワーカーにはブロックの通知は送信されません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }

                Section {
                    Button(action: blockWorker) {
                        if isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("ブロックする")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(reason.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("ワーカーをブロック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func blockWorker() {
        isSubmitting = true
        Task {
            do {
                _ = try await APIClient.shared.request(
                    endpoint: "/employer/blocked-workers",
                    method: "POST",
                    body: [
                        "workerId": workerId,
                        "reason": reason
                    ]
                ) as GenericResponse
                onComplete()
                dismiss()
            } catch {
                errorMessage = "ブロックに失敗しました"
            }
            isSubmitting = false
        }
    }
}

// MARK: - Employer Time Modification Review View

struct EmployerTimeModificationReviewView: View {
    @StateObject private var viewModel = TimeModificationReviewViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.requests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("時間修正リクエストはありません")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.requests) { req in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(req.workerName ?? "ワーカー")
                                    .font(.headline)
                                Text(req.jobTitle ?? "求人")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(req.requestTypeDisplay)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        if let start = req.requestedStartTime {
                            Text("修正後出勤: \(start)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let end = req.requestedEndTime {
                            Text("修正後退勤: \(end)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("理由: \(req.reason)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if req.status == "pending" {
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task { await viewModel.approve(req) }
                                }) {
                                    Text("承認")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color.green)
                                        .clipShape(Capsule())
                                }

                                Button(action: {
                                    Task { await viewModel.reject(req) }
                                }) {
                                    Text("却下")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                        } else {
                            Text(req.statusDisplay)
                                .font(.caption)
                                .foregroundColor(req.status == "approved" ? .green : .red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("時間修正リクエスト")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }
}

@MainActor
class TimeModificationReviewViewModel: ObservableObject {
    @Published var requests: [TimeModificationRequest] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            requests = try await api.request(endpoint: "/employer/time-modifications")
        } catch {
            requests = []
        }
        isLoading = false
    }

    func approve(_ req: TimeModificationRequest) async {
        do {
            _ = try await api.request(
                endpoint: "/time-modifications/\(req.id)/approve",
                method: "POST"
            ) as GenericResponse
            await loadData()
        } catch {
            errorMessage = "承認に失敗しました"
        }
    }

    func reject(_ req: TimeModificationRequest) async {
        do {
            _ = try await api.request(
                endpoint: "/time-modifications/\(req.id)/reject",
                method: "POST"
            ) as GenericResponse
            await loadData()
        } catch {
            errorMessage = "却下に失敗しました"
        }
    }
}

// MARK: - Withholding Tax Confirmation View (源泉徴収確認)

struct WithholdingTaxView: View {
    let calculation: WithholdingTaxCalculation
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                Text("源泉徴収のお知らせ")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("本日の報酬が9,800円を超えるため、\n源泉徴収税が適用されます。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Breakdown
            VStack(spacing: 16) {
                TaxRow(label: "総報酬額", value: "¥\(calculation.grossEarnings.formatted())", isHighlighted: false)

                Divider()

                TaxRow(label: "課税対象額", value: "¥\((calculation.grossEarnings - 9800).formatted())", isHighlighted: false)

                TaxRow(label: "源泉徴収税（3.102%）", value: "-¥\(calculation.taxAmount.formatted())", isHighlighted: false, isDeduction: true)

                Divider()

                TaxRow(label: "お受取額", value: "¥\(calculation.netEarnings.formatted())", isHighlighted: true)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Label("日額9,800円以下の場合は非課税です", systemImage: "info.circle")
                Label("源泉徴収票はマイページからダウンロードできます", systemImage: "arrow.down.doc")
                Label("確定申告で還付される場合があります", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button(action: onConfirm) {
                Text("確認しました")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("源泉徴収を確認。お受取額¥\(calculation.netEarnings.formatted())")
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}

struct TaxRow: View {
    let label: String
    let value: String
    let isHighlighted: Bool
    var isDeduction: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isHighlighted ? .headline : .subheadline)
                .foregroundColor(isHighlighted ? .primary : .secondary)

            Spacer()

            Text(value)
                .font(isHighlighted ? .title3 : .subheadline)
                .fontWeight(isHighlighted ? .bold : .regular)
                .foregroundColor(isDeduction ? .red : (isHighlighted ? .blue : .primary))
        }
    }
}

// MARK: - Schedule Conflict Warning View

struct ScheduleConflictView: View {
    let conflicts: [ScheduleConflict]
    let onProceed: () -> Void
    let onCancel: () -> Void

    var hasBlockingConflict: Bool {
        conflicts.contains { $0.conflictType.severity == .blocking }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: hasBlockingConflict ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(hasBlockingConflict ? .red : .orange)

                Text(hasBlockingConflict ? "スケジュール重複" : "スケジュールの確認")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(hasBlockingConflict ? "既存の勤務と時間が重複しているため、\nこの求人に応募できません。" : "スケジュールに注意が必要です。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Conflict list
            VStack(spacing: 12) {
                ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                    HStack(spacing: 12) {
                        Image(systemName: conflict.conflictType.severity == .blocking ? "xmark.circle.fill" :
                                conflict.conflictType.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .foregroundColor(conflict.conflictType.severity == .blocking ? .red :
                                conflict.conflictType.severity == .warning ? .orange : .blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(conflict.existingJob.jobTitle ?? "既存の勤務")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let date = conflict.existingJob.workDate {
                                Text(date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Text(conflict.conflictType.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if !hasBlockingConflict {
                    Button(action: onProceed) {
                        Text("確認して応募する")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button(action: onCancel) {
                    Text(hasBlockingConflict ? "戻る" : "キャンセル")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }
}

// MARK: - Mandatory Review Prompt View

struct MandatoryReviewPromptView: View {
    let pendingCount: Int
    let onReviewNow: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "star.bubble.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("レビューをお願いします")
                        .font(.headline)

                    Text("\(pendingCount)件の未レビューがあります。\nレビューを完了すると次の応募ができます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Button(action: onReviewNow) {
                Text("レビューを書く")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("レビューを書く。\(pendingCount)件の未レビューがあります")
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("レビュー催促。\(pendingCount)件の未レビューがあります")
    }
}

// MARK: - Job Alert Settings View

struct JobAlertSettingsView: View {
    @StateObject private var viewModel = JobAlertViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("キーワード") {
                    TextField("例: カフェ、キッチン", text: $viewModel.keyword)
                }

                Section("時給") {
                    HStack {
                        Text("¥")
                        TextField("下限", value: $viewModel.minWage, format: .number)
                            .keyboardType(.numberPad)
                        Text("〜")
                        TextField("上限", value: $viewModel.maxWage, format: .number)
                            .keyboardType(.numberPad)
                    }
                }

                Section("時間帯") {
                    ForEach(JobAlert.timeRanges, id: \.id) { range in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedTimeRanges.contains(range.id) },
                            set: { isOn in
                                if isOn { viewModel.selectedTimeRanges.insert(range.id) }
                                else { viewModel.selectedTimeRanges.remove(range.id) }
                            }
                        )) {
                            HStack {
                                Text(range.label)
                                Text(range.hours)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section("曜日") {
                    let days = ["日", "月", "火", "水", "木", "金", "土"]
                    HStack {
                        ForEach(0..<7, id: \.self) { i in
                            Button(action: {
                                if viewModel.selectedDays.contains(i) {
                                    viewModel.selectedDays.remove(i)
                                } else {
                                    viewModel.selectedDays.insert(i)
                                }
                            }) {
                                Text(days[i])
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(width: 36, height: 36)
                                    .background(viewModel.selectedDays.contains(i) ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(viewModel.selectedDays.contains(i) ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("通知") {
                    Toggle("アラートを有効にする", isOn: $viewModel.isEnabled)
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("保存する")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .navigationTitle("ジョブアラート設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
}

@MainActor
class JobAlertViewModel: ObservableObject {
    @Published var keyword = ""
    @Published var minWage: Int?
    @Published var maxWage: Int?
    @Published var selectedTimeRanges: Set<String> = []
    @Published var selectedDays: Set<Int> = []
    @Published var isEnabled = true
    @Published var isSaving = false

    func save() async {
        isSaving = true
        let settings = JobAlertSettings(
            enabled: isEnabled,
            keywords: keyword.isEmpty ? [] : [keyword],
            minHourlyWage: minWage,
            preferredAreas: [],
            preferredCategories: []
        )
        do {
            _ = try await APIClient.shared.saveJobAlerts(settings)
        } catch {
            #if DEBUG
            print("Job alert save error: \(error)")
            #endif
        }
        isSaving = false
    }

    func loadData() async {
        do {
            let settings = try await APIClient.shared.getJobAlerts()
            isEnabled = settings.enabled
            keyword = settings.keywords.first ?? ""
            minWage = settings.minHourlyWage
        } catch {
            #if DEBUG
            print("Job alert load error: \(error)")
            #endif
        }
    }
}

// MARK: - Saved Search View

struct SavedSearchesView: View {
    @StateObject private var viewModel = SavedSearchViewModel()

    var body: some View {
        List {
            if viewModel.searches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("保存した検索条件はありません")
                        .foregroundColor(.gray)
                    Text("求人検索画面で検索条件を保存できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.searches) { search in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(search.name)
                                .font(.headline)
                            Spacer()
                            if let count = search.resultCount {
                                Text("\(count)件")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 8) {
                            if let keyword = search.keyword, !keyword.isEmpty {
                                Label(keyword, systemImage: "magnifyingglass")
                            }
                            if let area = search.filters.area {
                                Label(area, systemImage: "mappin")
                            }
                            if let minWage = search.filters.minWage {
                                Label("¥\(minWage)〜", systemImage: "yensign.circle")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    viewModel.deleteSearch(at: indexSet)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("保存した検索条件")
        .task {
            await viewModel.loadData()
        }
    }
}

@MainActor
class SavedSearchViewModel: ObservableObject {
    @Published var searches: [SavedSearch] = []
    @Published var isLoading = false

    func loadData() async {
        isLoading = true
        do {
            searches = try await APIClient.shared.getSavedSearches()
        } catch {
            #if DEBUG
            print("Saved searches load error: \(error)")
            #endif
        }
        isLoading = false
    }

    func deleteSearch(at offsets: IndexSet) {
        let idsToDelete = offsets.compactMap { searches[$0].id }
        searches.remove(atOffsets: offsets)
        Task {
            for id in idsToDelete {
                do {
                    _ = try await APIClient.shared.deleteSavedSearch(searchId: id)
                } catch {
                    #if DEBUG
                    print("[SavedSearch] Delete failed: \(error.localizedDescription)")
                    #endif
                    await loadData()
                    break
                }
            }
        }
    }
}

// MARK: - Employer Bulk Message View

struct BulkMessageView: View {
    let jobId: String?
    @StateObject private var viewModel = BulkMessageViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Recipients
                VStack(alignment: .leading, spacing: 8) {
                    Text("送信先")
                        .font(.headline)

                    if viewModel.isLoadingWorkers {
                        ProgressView()
                    } else {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.blue)
                            Text("\(viewModel.selectedWorkers.count)名のワーカー")
                                .font(.subheadline)
                            Spacer()
                            Button("全選択") {
                                viewModel.selectAll()
                            }
                            .font(.caption)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.workers, id: \.self) { worker in
                                    let isSelected = viewModel.selectedWorkers.contains(worker)
                                    Button(action: {
                                        if isSelected {
                                            viewModel.selectedWorkers.remove(worker)
                                        } else {
                                            viewModel.selectedWorkers.insert(worker)
                                        }
                                    }) {
                                        Text(worker)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(isSelected ? Color.blue : Color(.systemGray5))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Quick templates
                VStack(alignment: .leading, spacing: 8) {
                    Text("テンプレート")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.templates, id: \.self) { template in
                                Button(action: { viewModel.message = template }) {
                                    Text(template.prefix(20) + "...")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // Message
                VStack(alignment: .leading, spacing: 4) {
                    Text("メッセージ")
                        .font(.headline)

                    TextEditor(text: $viewModel.message)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("\(viewModel.message.count)/500")
                        .font(.caption)
                        .foregroundColor(viewModel.message.count > 500 ? .red : .gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Spacer()

                // Send button
                Button(action: {
                    Task {
                        await viewModel.send()
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("\(viewModel.selectedWorkers.count)名に送信")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canSend ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.canSend)
            }
            .padding()
            .navigationTitle("一括メッセージ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await viewModel.loadWorkers(jobId: jobId)
            }
        }
    }
}

@MainActor
class BulkMessageViewModel: ObservableObject {
    @Published var workers: [String] = []
    @Published var selectedWorkers: Set<String> = []
    @Published var message = ""
    @Published var isLoadingWorkers = true
    @Published var isSending = false

    let templates = [
        "お疲れ様です。明日のお仕事の確認です。集合場所と持ち物をご確認ください。",
        "本日はお仕事ありがとうございました。またのご応募をお待ちしております。",
        "急募のお知らせです。明日の勤務に空きが出ました。ご応募お待ちしております。",
        "シフト変更のお知らせです。詳細はメッセージをご確認ください。",
    ]

    var canSend: Bool {
        !selectedWorkers.isEmpty && !message.isEmpty && message.count <= 500
    }

    @Published var errorMessage: String?
    @Published var sendSuccess = false

    func loadWorkers(jobId: String?) async {
        isLoadingWorkers = true
        do {
            let jobWorkers = try await APIClient.shared.getJobWorkers(jobId: jobId)
            workers = jobWorkers.map { $0.name }
            selectedWorkers = Set(workers)
        } catch {
            workers = []
        }
        isLoadingWorkers = false
    }

    func selectAll() {
        selectedWorkers = Set(workers)
    }

    func send() async {
        isSending = true
        errorMessage = nil
        do {
            let workerIds = Array(selectedWorkers)
            _ = try await APIClient.shared.sendBulkMessage(workerIds: workerIds, message: message, jobId: nil)
            sendSuccess = true
        } catch {
            errorMessage = "メッセージの送信に失敗しました"
        }
        isSending = false
    }
}

// MARK: - CSV Export View

struct CSVExportView: View {
    @StateObject private var viewModel = CSVExportViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("エクスポート種類") {
                    ForEach(ExportRequest.ExportType.allCases, id: \.rawValue) { type in
                        Button(action: { viewModel.selectedType = type }) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)

                                Text(type.displayName)
                                    .foregroundColor(.primary)

                                Spacer()

                                if viewModel.selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section("期間") {
                    DatePicker("開始日", selection: $viewModel.dateFrom, displayedComponents: .date)
                    DatePicker("終了日", selection: $viewModel.dateTo, displayedComponents: .date)

                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach(["今月", "先月", "3ヶ月"], id: \.self) { preset in
                            Button(preset) {
                                viewModel.applyPreset(preset)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        }
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.export()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("CSVをエクスポート")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isExporting)
                }

                if viewModel.exportSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("エクスポートが完了しました")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("データエクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

@MainActor
class CSVExportViewModel: ObservableObject {
    @Published var selectedType: ExportRequest.ExportType = .attendance
    @Published var dateFrom = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var dateTo = Date()
    @Published var isExporting = false
    @Published var exportSuccess = false

    func applyPreset(_ preset: String) {
        let calendar = Calendar.current
        dateTo = Date()

        switch preset {
        case "今月":
            dateFrom = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        case "先月":
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            dateFrom = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth)) ?? Date()
            dateTo = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()) ?? Date()
        case "3ヶ月":
            dateFrom = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        default:
            break
        }
    }

    func export() async {
        isExporting = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateRange = "\(formatter.string(from: dateFrom))~\(formatter.string(from: dateTo))"
        do {
            _ = try await APIClient.shared.requestCSVExport(type: selectedType.rawValue, dateRange: dateRange)
            exportSuccess = true
        } catch {
            #if DEBUG
            print("CSV export error: \(error)")
            #endif
        }
        isExporting = false
    }
}

// MARK: - Photo Check-in View

struct PhotoCheckInView: View {
    let onPhotoTaken: (Data) -> Void
    let onSkip: () -> Void
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                Text("チェックイン写真")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("到着確認のため、\n職場での写真を撮影してください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue, lineWidth: 2)
                    )

                HStack(spacing: 16) {
                    Button("撮り直す") {
                        capturedImage = nil
                        showCamera = true
                    }
                    .foregroundColor(.orange)

                    Button(action: {
                        if let data = image.jpegData(compressionQuality: 0.7) {
                            onPhotoTaken(data)
                        }
                    }) {
                        Text("この写真で確認")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                Button(action: { showCamera = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title)
                        Text("撮影する")
                            .fontWeight(.medium)
                    }
                    .frame(width: 200, height: 200)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            Spacer()

            Button(action: onSkip) {
                Text("スキップ")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .accessibilityLabel("写真撮影をスキップしてチェックインを続行")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                capturedImage = image
                showCamera = false
            }
        }
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Work Certificate (就業証明書)

struct WorkCertificateListView: View {
    @StateObject private var viewModel = WorkCertificateViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                SkeletonList(count: 4)
            } else if viewModel.certificates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("就業証明書はありません")
                        .foregroundColor(.gray)
                    Text("勤務完了後に就業証明書が発行されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.certificates) { cert in
                    WorkCertificateRow(
                        certificate: cert,
                        onDownload: { viewModel.downloadPDF(certificateId: cert.id) }
                    )
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("就業証明書")
        .task {
            await viewModel.loadCertificates()
        }
        .overlay {
            if viewModel.isDownloading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("PDFをダウンロード中...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let pdfURL = viewModel.downloadedPDFURL {
                ShareSheet(items: [pdfURL])
            }
        }
        .alert("ダウンロード完了", isPresented: $viewModel.showDownloadSuccess) {
            Button("共有する") { viewModel.showShareSheet = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text("就業証明書のPDFをダウンロードしました")
        }
    }
}

struct WorkCertificateRow: View {
    let certificate: WorkCertificate
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(certificate.jobTitle)
                        .font(.headline)
                    Text(certificate.employerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 16) {
                Label(certificate.workDate, systemImage: "calendar")
                    .font(.caption)

                if let hours = certificate.totalHours {
                    Label(String(format: "%.1f時間", hours), systemImage: "clock")
                        .font(.caption)
                }

                if let earnings = certificate.earnings {
                    Label("¥\(earnings.formatted())", systemImage: "yensign.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .foregroundColor(.secondary)

            if let certNum = certificate.certificateNumber {
                Text("証明書番号: \(certNum)")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class WorkCertificateViewModel: ObservableObject {
    @Published var certificates: [WorkCertificate] = []
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var errorMessage: String?
    @Published var showShareSheet = false
    @Published var showDownloadSuccess = false
    @Published var downloadedPDFURL: URL?

    private let api = APIClient.shared

    func loadCertificates() async {
        isLoading = true
        errorMessage = nil
        do {
            certificates = try await api.getWorkCertificates()
        } catch {
            errorMessage = "証明書の取得に失敗しました"
        }
        isLoading = false
    }

    func downloadPDF(certificateId: String) {
        isDownloading = true
        errorMessage = nil

        Task {
            do {
                let data = try await api.downloadWorkCertificatePDF(certificateId: certificateId)

                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "work_certificate_\(certificateId).pdf"
                let fileURL = tempDir.appendingPathComponent(fileName)
                try data.write(to: fileURL)

                downloadedPDFURL = fileURL
                isDownloading = false
                showDownloadSuccess = true
            } catch {
                isDownloading = false
                errorMessage = "PDFのダウンロードに失敗しました"
            }
        }
    }
}

// MARK: - Job Image Carousel

struct JobImageCarousel: View {
    let job: Job
    @State private var selectedIndex = 0

    private var allImageUrls: [URL] {
        var urls: [URL] = []
        if let imageUrls = job.imageUrls {
            urls = imageUrls.compactMap { URL(string: $0) }
        }
        if urls.isEmpty, let imageUrl = job.imageUrl, let url = URL(string: imageUrl) {
            urls = [url]
        }
        return urls
    }

    private var hasVideo: Bool {
        if let videoUrl = job.videoUrl {
            return !videoUrl.isEmpty
        }
        return false
    }

    var body: some View {
        let urls = allImageUrls
        let totalItems = urls.count + (hasVideo ? 1 : 0)

        if totalItems > 0 {
            if totalItems == 1 && !hasVideo {
                CachedAsyncImage(url: urls[0]) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                .scaledToFill()
                .frame(height: 200)
                .clipped()
            } else if totalItems == 1 && hasVideo {
                JobVideoPlayerView(videoUrl: job.videoUrl!)
                    .frame(height: 220)
            } else {
                TabView(selection: $selectedIndex) {
                    // Video slide (first if exists)
                    if hasVideo {
                        JobVideoPlayerView(videoUrl: job.videoUrl!)
                            .tag(-1)
                    }

                    // Image slides
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        CachedAsyncImage(url: url) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
                        .scaledToFill()
                        .clipped()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 220)
            }
        }
    }
}

// MARK: - Job Video Player View

struct JobVideoPlayerView: View {
    let videoUrl: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .overlay(
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("動画を読み込み中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }

            // Play button overlay (shown when not playing)
            if !isPlaying {
                Button(action: {
                    if player == nil, let url = URL(string: videoUrl) {
                        player = AVPlayer(url: url)
                    }
                    player?.play()
                    isPlaying = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 60, height: 60)
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }

            // Video badge
            VStack {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                        Text("動画")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(8)
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            if let url = URL(string: videoUrl) {
                player = AVPlayer(url: url)
            }
        }
    }
}

// MARK: - Employer Public Profile View

struct EmployerPublicProfileView: View {
    let employerId: String
    @StateObject private var viewModel = EmployerPublicProfileViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let profile = viewModel.profile {
                VStack(spacing: 20) {
                    // Cover & Logo
                    ZStack(alignment: .bottomLeading) {
                        if let coverUrl = profile.coverImageUrl, let url = URL(string: coverUrl) {
                            CachedAsyncImage(url: url) {
                                Rectangle()
                                    .fill(Color.blue.opacity(0.1))
                            }
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(LinearGradient(colors: [.blue, .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 160)
                        }

                        HStack(spacing: 12) {
                            if let logoUrl = profile.logoUrl, let url = URL(string: logoUrl) {
                                CachedAsyncImage(url: url) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                }
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "building.2.fill")
                                            .foregroundColor(.blue)
                                    )
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            }

                            VStack(alignment: .leading) {
                                Text(profile.displayName ?? "事業者")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                if let pref = profile.prefecture {
                                    let loc = [pref, profile.city].compactMap({ $0 }).joined(separator: " ")
                                    if !loc.isEmpty {
                                        Text(loc)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                        }
                        .padding()
                    }

                    // Stats
                    HStack(spacing: 0) {
                        EmployerStatItem(value: "\(profile.totalJobs ?? 0)", label: "求人数")
                        Divider().frame(height: 40)
                        EmployerStatItem(value: "\(profile.totalHires ?? 0)", label: "採用実績")
                        Divider().frame(height: 40)
                        EmployerStatItem(
                            value: profile.averageRating.map { String(format: "%.1f", $0) } ?? "-",
                            label: "評価"
                        )
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4)
                    .padding(.horizontal)

                    // Description
                    if let desc = profile.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("企業紹介")
                                .font(.headline)
                            Text(desc)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // Jobs by this employer
                    if !viewModel.jobs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("募集中の求人")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(viewModel.jobs) { job in
                                NavigationLink(destination: JobDetailView(jobId: job.id)) {
                                    EmployerPublicJobRow(job: job)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(error)
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)
            }
        }
        .navigationTitle("事業者プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(employerId: employerId)
        }
    }
}

struct EmployerStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmployerPublicJobRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            if let imageUrl = job.imageUrl, let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(job.wageDisplay)
                    .font(.caption)
                    .foregroundColor(.green)
                Text(job.locationDisplay)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

@MainActor
class EmployerPublicProfileViewModel: ObservableObject {
    @Published var profile: EmployerProfile?
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadProfile(employerId: String) async {
        isLoading = true
        do {
            profile = try await api.getPublicEmployerProfile(employerId: employerId)
            if let allJobs: [Job] = try? await api.getJobs() {
                jobs = allJobs.filter { $0.employerId == employerId }.prefix(10).map { $0 }
            }
        } catch {
            errorMessage = "プロフィールの取得に失敗しました"
        }
        isLoading = false
    }
}
