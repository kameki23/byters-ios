import SwiftUI

struct JobDetailView: View {
    let jobId: String

    @StateObject private var viewModel = JobDetailViewModel()
    @State private var showApplySheet = false
    @State private var showEligibilityError = false
    @State private var eligibilityMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if let job = viewModel.job {
                VStack(alignment: .leading, spacing: 24) {
                    // Job Image
                    if let imageUrl = job.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
                    }

                    // Header with Favorite Button
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(job.employerName ?? "企業名")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                Text(job.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            // Favorite Button
                            Button(action: {
                                Task {
                                    await viewModel.toggleFavorite()
                                }
                            }) {
                                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(viewModel.isFavorite ? .red : .gray)
                            }
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
                Button(action: {
                    shareJob()
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.job != nil {
                ApplyButton(
                    isApplied: viewModel.isApplied,
                    isEligible: viewModel.eligibility?.eligible ?? true,
                    isLoading: viewModel.isCheckingEligibility
                ) {
                    if !viewModel.isApplied {
                        if viewModel.eligibility?.eligible == false {
                            eligibilityMessage = viewModel.eligibility?.message ?? "応募条件を満たしていません"
                            showEligibilityError = true
                        } else {
                            showApplySheet = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showApplySheet) {
            ApplySheetView(jobId: jobId) { success in
                if success {
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
        .task {
            await viewModel.loadJob(jobId: jobId)
            await viewModel.loadReviews(jobId: jobId)
            await viewModel.checkEligibility(jobId: jobId)
        }
    }

    private func remainingSlots(_ job: Job) -> String {
        guard let required = job.requiredPeople else { return "未定" }
        let current = job.currentApplicants ?? 0
        return "\(required - current)名"
    }

    private func shareJob() {
        guard let job = viewModel.job else { return }
        let url = URL(string: "https://byters.jp/jobs/\(jobId)")!
        let activityVC = UIActivityViewController(
            activityItems: [job.title, url],
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

    private let api = APIClient.shared

    func loadJob(jobId: String) async {
        isLoading = true
        do {
            job = try await api.getJobDetail(jobId: jobId)
            // Check if already favorited (could be done via API)
        } catch {
            print("Failed to load job: \(error)")
        }
        isLoading = false
    }

    func loadReviews(jobId: String) async {
        do {
            reviews = try await api.getJobReviews(jobId: jobId)
        } catch {
            print("Failed to load reviews: \(error)")
        }
    }

    func checkEligibility(jobId: String) async {
        isCheckingEligibility = true
        do {
            eligibility = try await api.checkApplicationEligibility(jobId: jobId)
        } catch {
            // If eligibility check fails, assume eligible
            eligibility = EligibilityResponse(
                eligible: true,
                reasons: nil,
                identityVerified: nil,
                profileComplete: nil,
                message: nil
            )
        }
        isCheckingEligibility = false
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
            print("Failed to toggle favorite: \(error)")
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

#Preview {
    NavigationStack {
        JobDetailView(jobId: "test-id")
    }
}
