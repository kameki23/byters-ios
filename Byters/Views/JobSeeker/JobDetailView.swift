import SwiftUI
import MapKit

struct JobDetailView: View {
    let jobId: String

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = JobDetailViewModel()
    @State private var showApplySheet = false
    @State private var showApplyConfirmation = false
    @State private var showEligibilityError = false
    @State private var showProfileIncompleteAlert = false
    @State private var eligibilityMessage = ""
    @State private var showReportSheet = false
    @State private var showScheduleConflict = false
    @State private var scheduleConflicts: [ScheduleConflict] = []
    @State private var showPendingReviewBlock = false
    @State private var pendingReviewCount = 0
    @State private var showReviewSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("求人情報を読み込み中...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else if let errorMessage = viewModel.errorMessage, viewModel.job == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button(action: {
                        Task { await viewModel.loadJob(jobId: jobId) }
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
                }
                .padding(.top, 100)
            } else if let job = viewModel.job {
                VStack(alignment: .leading, spacing: 24) {
                    // Job Image(s)
                    JobImageCarousel(job: job)

                    // Header with Favorite Button
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let employerId = job.employerId {
                                    NavigationLink(destination: EmployerPublicProfileView(employerId: employerId)) {
                                        HStack(spacing: 4) {
                                            Text(job.employerName ?? "企業名")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                } else {
                                    Text(job.employerName ?? "企業名")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }

                                Text(job.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            // Favorite Button
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                Task {
                                    await viewModel.toggleFavorite()
                                }
                            }) {
                                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(viewModel.isFavorite ? .red : .gray)
                                    .scaleEffect(viewModel.isFavorite ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3), value: viewModel.isFavorite)
                            }
                            .accessibilityLabel(viewModel.isFavorite ? "お気に入りから削除" : "お気に入りに追加")
                        }

                        // Tags
                        if let categories = job.categories, !categories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { category in
                                        Text(category)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        // Perk Tags
                        let perks = job.perkTags
                        if !perks.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(perks, id: \.rawValue) { perk in
                                    HStack(spacing: 4) {
                                        Image(systemName: perk.icon)
                                            .font(.caption2)
                                        Text(perk.rawValue)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(detailPerkColor(perk).opacity(0.1))
                                    .foregroundColor(detailPerkColor(perk))
                                    .clipShape(Capsule())
                                }
                            }
                        }

                        // Employer Rating
                        if let goodRate = job.employerGoodRate ?? job.goodRate, goodRate > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.caption)
                                    .foregroundColor(goodRate >= 80 ? .green : goodRate >= 50 ? .orange : .red)
                                Text("事業者評価 \(goodRate)%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let count = job.reviewCount, count > 0 {
                                    Text("(\(count)件)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Key Info Cards
                    HStack(spacing: 12) {
                        InfoCard(title: "給与", value: job.wageDisplay, icon: "yensign.circle.fill", color: .green)
                        InfoCard(title: "勤務日", value: job.workDate ?? "未定", icon: "calendar", color: .blue)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        InfoCard(title: "時間", value: job.timeDisplay.isEmpty ? "未定" : job.timeDisplay, icon: "clock.fill", color: .orange)
                        InfoCard(title: "残り枠", value: remainingSlots(job), icon: "person.2.fill", color: .purple)
                    }
                    .padding(.horizontal)

                    // Location
                    VStack(alignment: .leading, spacing: 12) {
                        Text("勤務地")
                            .font(.headline)

                        HStack(alignment: .top) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)

                            Text(job.locationDisplay)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        // Embedded Map
                        if let lat = job.latitude, let lng = job.longitude {
                            JobLocationMapView(latitude: lat, longitude: lng, title: job.title)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("仕事内容")
                            .font(.headline)

                        Text(job.description ?? "詳細情報なし")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Requirements
                    if let requirements = job.requirements, !requirements.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("応募条件")
                                .font(.headline)

                            Text(requirements)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // Benefits
                    if let benefits = job.benefits, !benefits.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("待遇・福利厚生")
                                .font(.headline)

                            Text(benefits)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // Payment Type Notice (manual only)
                    if job.resolvedPaymentType == .manual {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .foregroundColor(.orange)
                                Text("実績精算")
                                    .font(.headline)
                            }
                            Text("この求人は実績精算方式です。チェックアウト後、事業者が実績を確認してから交通費・残業代を含めた精算が行われます。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Cancellation Policy
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.orange)
                            Text("キャンセルポリシー")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            PolicyInfoRow(time: "72時間前まで", penalty: "ペナルティなし", color: .green)
                            PolicyInfoRow(time: "24〜72時間前", penalty: "注意", color: .yellow)
                            PolicyInfoRow(time: "6〜24時間前", penalty: "軽度ペナルティ", color: .orange)
                            PolicyInfoRow(time: "6時間以内", penalty: "重度ペナルティ", color: .red)
                        }

                        Text("無断キャンセルは信頼度に大きく影響します")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("キャンセルポリシー。72時間前まではペナルティなし、24時間前までは注意、6時間以内は重度ペナルティ")

                    Divider()
                        .padding(.horizontal)

                    // Reviews Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("レビュー")
                                .font(.headline)

                            if !viewModel.reviews.isEmpty {
                                Text("(\(viewModel.reviews.count)件)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }

                        if viewModel.reviews.isEmpty {
                            Text("まだレビューがありません")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.reviews.prefix(3)) { review in
                                    ReviewCard(review: review)
                                }

                                if viewModel.reviews.count > 3 {
                                    NavigationLink(destination: AllReviewsView(reviews: viewModel.reviews)) {
                                        Text("すべてのレビューを見る")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Eligibility Status
                    if let eligibility = viewModel.eligibility {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: eligibility.eligible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(eligibility.eligible ? .green : .orange)

                                Text(eligibility.eligible ? "応募可能" : "応募条件を満たしていません")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            if let reasons = eligibility.reasons, !reasons.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(reasons, id: \.self) { reason in
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "info.circle")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            Text(reason)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(viewModel.eligibility?.eligible == true ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Spacer for button
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.vertical)
            } else {
                Text("求人が見つかりません")
                    .foregroundColor(.gray)
                    .padding(.top, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { showReportSheet = true }) {
                        Image(systemName: "flag")
                            .foregroundColor(.orange)
                    }
                    Button(action: { shareJob() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                targetType: "job",
                targetId: jobId,
                targetTitle: viewModel.job?.title
            )
        }
        .overlay(alignment: .bottom) {
            if viewModel.job != nil {
                ApplyButton(
                    isApplied: viewModel.isApplied,
                    isEligible: viewModel.eligibility?.eligible ?? true,
                    isLoading: viewModel.isCheckingEligibility
                ) {
                    if !viewModel.isApplied {
                        // 未レビューチェック
                        if pendingReviewCount > 0 {
                            showPendingReviewBlock = true
                            return
                        }
                        if viewModel.eligibility?.eligible == false {
                            eligibilityMessage = viewModel.eligibility?.message ?? "応募条件を満たしていません"
                            showEligibilityError = true
                        } else if let user = authManager.currentUser,
                                  (user.name == nil || user.name?.isEmpty == true) {
                            showProfileIncompleteAlert = true
                        } else {
                            // スケジュール重複チェック
                            Task {
                                let conflicts = await viewModel.checkScheduleConflicts()
                                if !conflicts.isEmpty {
                                    scheduleConflicts = conflicts
                                    showScheduleConflict = true
                                } else {
                                    showApplyConfirmation = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "この求人に応募しますか？",
            isPresented: $showApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button("応募に進む") {
                showApplySheet = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let job = viewModel.job {
                Text(applyConfirmationMessage(job: job))
            }
        }
        .sheet(isPresented: $showApplySheet) {
            ApplySheetView(jobId: jobId) { success in
                if success {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    viewModel.isApplied = true
                }
                showApplySheet = false
            }
        }
        .alert("応募できません", isPresented: $showEligibilityError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(eligibilityMessage)
        }
        .alert("プロフィールを完成させてください", isPresented: $showProfileIncompleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("求人に応募するには、マイページからお名前を登録してください。")
        }
        .alert("レビューを先に完了してください", isPresented: $showPendingReviewBlock) {
            Button("レビューを書く") {
                showReviewSheet = true
            }
            Button("あとで", role: .cancel) {}
        } message: {
            Text("\(pendingReviewCount)件の未レビューがあります。レビューを完了すると応募できるようになります。")
        }
        .sheet(isPresented: $showReviewSheet) {
            NavigationStack {
                PendingReviewsView()
            }
        }
        .sheet(isPresented: $showScheduleConflict) {
            ScheduleConflictView(
                conflicts: scheduleConflicts,
                onProceed: {
                    showScheduleConflict = false
                    showApplyConfirmation = true
                },
                onCancel: {
                    showScheduleConflict = false
                }
            )
        }
        .task {
            await viewModel.loadJob(jobId: jobId)
            await viewModel.loadReviews(jobId: jobId)
            await viewModel.checkEligibility(jobId: jobId)
            // 未レビュー数をチェック
            await checkPendingReviews()
        }
    }

    private func detailPerkColor(_ perk: JobPerk) -> Color {
        switch perk {
        case .transportation: return .blue
        case .meal: return .orange
        case .beginner: return .purple
        }
    }

    private func remainingSlots(_ job: Job) -> String {
        guard let required = job.requiredPeople else { return "未定" }
        let current = job.currentApplicants ?? 0
        return "\(required - current)名"
    }

    private func applyConfirmationMessage(job: Job) -> String {
        var lines: [String] = []
        lines.append("【\(job.title)】")
        lines.append("給与: \(job.wageDisplay)")
        if let date = job.workDate {
            let timeInfo = job.timeDisplay.isEmpty ? "" : " \(job.timeDisplay)"
            lines.append("勤務日: \(date)\(timeInfo)")
        }
        return lines.joined(separator: "\n")
    }

    private func checkPendingReviews() async {
        do {
            let reviews = try await APIClient.shared.getPendingReviews()
            pendingReviewCount = reviews.count
        } catch {
            pendingReviewCount = 0
        }
    }

    private func shareJob() {
        guard let job = viewModel.job else { return }
        let shareText = "\(job.title) - Bytersで短期バイトを見つけよう！"
        let webBaseURL = StripeConfig.apiBaseURL.replacingOccurrences(of: "/api", with: "")
        let url = URL(string: "\(webBaseURL)/jobs/\(jobId)")!
        let activityVC = UIActivityViewController(
            activityItems: [shareText, url],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - View Model

@MainActor
class JobDetailViewModel: ObservableObject {
    @Published var job: Job?
    @Published var isLoading = true
    @Published var isApplied = false
    @Published var isFavorite = false
    @Published var reviews: [Review] = []
    @Published var eligibility: EligibilityResponse?
    @Published var isCheckingEligibility = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadJob(jobId: String) async {
        isLoading = true
        do {
            job = try await api.getJobDetail(jobId: jobId)
        } catch {
            errorMessage = "求人情報の読み込みに失敗しました"
        }
        // Load favorite status
        do {
            isFavorite = try await api.isFavorite(jobId: jobId)
        } catch {
            // Non-critical - default to not favorited
        }
        isLoading = false
    }

    func loadReviews(jobId: String) async {
        do {
            reviews = try await api.getJobReviews(jobId: jobId)
        } catch {
            _ = error
        }
    }

    func checkEligibility(jobId: String) async {
        isCheckingEligibility = true
        do {
            eligibility = try await api.checkApplicationEligibility(jobId: jobId)
        } catch {
            errorMessage = "応募資格の確認に失敗しました"
            eligibility = nil
        }
        isCheckingEligibility = false
    }

    func checkScheduleConflicts() async -> [ScheduleConflict] {
        guard let job = job else { return [] }
        do {
            let apps = try await api.getMyApplications()
            let accepted = apps.filter { $0.status == "accepted" || $0.status == "checked_in" }

            var conflicts: [ScheduleConflict] = []

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for existing in accepted {
                // 同日チェック
                if let existingDate = existing.workDate, let newDate = job.workDate, existingDate == newDate {
                    // 時間重複チェック
                    if let existStart = existing.startTime.flatMap({ formatter.date(from: $0) }),
                       let existEnd = existing.endTime.flatMap({ formatter.date(from: $0) }),
                       let newStart = job.startTime.flatMap({ formatter.date(from: $0) }),
                       let newEnd = job.endTime.flatMap({ formatter.date(from: $0) }) {

                        // 重複: 新しいジョブの開始 < 既存の終了 && 新しいジョブの終了 > 既存の開始
                        if newStart < existEnd && newEnd > existStart {
                            conflicts.append(ScheduleConflict(existingJob: existing, conflictType: .overlap))
                            continue
                        }

                        // 1時間以内チェック
                        let gapBefore = newStart.timeIntervalSince(existEnd)
                        let gapAfter = existStart.timeIntervalSince(newEnd)
                        if (gapBefore >= 0 && gapBefore < 3600) || (gapAfter >= 0 && gapAfter < 3600) {
                            conflicts.append(ScheduleConflict(existingJob: existing, conflictType: .tooClose))
                            continue
                        }
                    }

                    // 時間情報なしでも同日警告
                    conflicts.append(ScheduleConflict(existingJob: existing, conflictType: .sameDay))
                }
            }

            return conflicts
        } catch {
            return []
        }
    }

    func toggleFavorite() async {
        guard let jobId = job?.id else { return }
        do {
            if isFavorite {
                _ = try await api.removeFavoriteJob(jobId: jobId)
            } else {
                _ = try await api.addFavoriteJob(jobId: jobId)
            }
            isFavorite.toggle()
        } catch {
            _ = error
        }
    }
}

// MARK: - Subviews

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ApplyButton: View {
    let isApplied: Bool
    let isEligible: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(buttonText)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(buttonColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isApplied || isLoading)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var buttonText: String {
        if isApplied {
            return "応募済み"
        } else if !isEligible {
            return "条件を満たしていません"
        } else {
            return "この求人に応募する"
        }
    }

    private var buttonColor: Color {
        if isApplied {
            return .gray
        } else if !isEligible {
            return .orange
        } else {
            return .blue
        }
    }
}

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Rating stars
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Spacer()

                if let createdAt = review.createdAt {
                    Text(formatDate(createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let reviewerName = review.reviewerName {
                Text("- \(reviewerName)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

struct AllReviewsView: View {
    let reviews: [Review]

    var body: some View {
        List(reviews) { review in
            ReviewCard(review: review)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .navigationTitle("レビュー一覧")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ApplySheetView: View {
    let jobId: String
    let onComplete: (Bool) -> Void

    @State private var message = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("応募メッセージ（任意）")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $message)
                    .frame(height: 150)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Button(action: apply) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("応募する")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
            }
            .padding()
            .navigationTitle("応募確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onComplete(false)
                    }
                }
            }
        }
    }

    private func apply() {
        isLoading = true
        error = nil

        Task {
            do {
                _ = try await APIClient.shared.applyForJob(
                    jobId: jobId,
                    message: message.isEmpty ? nil : message
                )
                onComplete(true)
            } catch let apiError as APIError {
                error = apiError.errorDescription
            } catch {
                self.error = "応募に失敗しました"
            }
            isLoading = false
        }
    }
}

// MARK: - Policy Info Row

struct PolicyInfoRow: View {
    let time: String
    let penalty: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(time)
                .font(.caption)
                .frame(width: 100, alignment: .leading)

            Text(penalty)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color == .green ? .green : (color == .red ? .red : .primary))
        }
    }
}

// MARK: - Job Location Map View

struct JobLocationMapView: View {
    let latitude: Double
    let longitude: Double
    let title: String

    var body: some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker(title, coordinate: coordinate)
                .tint(.red)
        }
        .mapStyle(.standard)
        .allowsHitTesting(true)
    }
}

#Preview {
    NavigationStack {
        JobDetailView(jobId: "test-id")
    }
}
