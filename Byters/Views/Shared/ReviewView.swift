import SwiftUI

// MARK: - Review Submit View

struct ReviewSubmitView: View {
    let pendingReview: PendingReview
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let api = APIClient.shared

    /// Tags depend on whether we are reviewing a worker or an employer.
    private var availableTags: [String] {
        let revieweeType = (pendingReview.revieweeType ?? "").lowercased()
        if revieweeType == "employer" {
            return ["指示が明確", "環境が良い", "対応が丁寧", "時給が適正", "また働きたい"]
        } else {
            return ["丁寧", "時間厳守", "スキルが高い", "コミュニケーション良好", "また一緒に働きたい"]
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if showSuccess {
                    successOverlay
                } else {
                    formContent
                }
            }
            .navigationTitle("レビューを書く")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showSuccess {
                        Button("キャンセル") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Job & Reviewee Info
                jobInfoCard

                // Star Rating
                starRatingSection

                // Quick Tags
                tagsSection

                // Comment
                commentSection

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Submit
                submitButton
            }
            .padding()
        }
    }

    // MARK: - Job Info Card

    private var jobInfoCard: some View {
        VStack(spacing: 8) {
            if let name = pendingReview.revieweeName {
                Text(name)
                    .font(.headline)
            }

            if let title = pendingReview.jobTitle {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let date = pendingReview.workDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(formatDate(date))
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Star Rating

    private var starRatingSection: some View {
        VStack(spacing: 12) {
            Text("評価")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            rating = star
                        }
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(star <= rating ? .yellow : Color(.systemGray4))
                            .scaleEffect(star <= rating ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }

            if rating > 0 {
                Text(ratingLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "不満"
        case 2: return "やや不満"
        case 3: return "普通"
        case 4: return "良い"
        case 5: return "とても良い"
        default: return ""
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("クイックタグ（任意）")
                .font(.caption)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(availableTags, id: \.self) { tag in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    } label: {
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTags.contains(tag) ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Comment

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("コメント（任意）")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $comment)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("レビューを送信")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(rating > 0 ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(rating == 0 || isSubmitting)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .scaleEffect(showSuccess ? 1.0 : 0.5)
                .opacity(showSuccess ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccess)

            Text("レビューを送信しました")
                .font(.title3)
                .fontWeight(.semibold)

            Text("ご協力ありがとうございます")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("閉じる") {
                onComplete?()
                dismiss()
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Actions

    private func submit() async {
        guard rating > 0 else { return }
        isSubmitting = true
        errorMessage = nil

        // Build full comment with tags
        var fullComment = ""
        if !selectedTags.isEmpty {
            fullComment += selectedTags.joined(separator: ", ")
        }
        if !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !fullComment.isEmpty { fullComment += "\n" }
            fullComment += comment.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        do {
            _ = try await api.submitReview(
                jobId: pendingReview.jobId,
                revieweeId: pendingReview.revieweeId,
                rating: rating,
                comment: fullComment.isEmpty ? nil : fullComment
            )
            AnalyticsService.shared.track("review_submitted", properties: [
                "rating": "\(rating)",
                "has_comment": "\(!fullComment.isEmpty)",
                "tag_count": "\(selectedTags.count)"
            ])
            withAnimation { showSuccess = true }
        } catch {
            errorMessage = "送信に失敗しました。もう一度お試しください。"
        }
        isSubmitting = false
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "M/d（E）"
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "M/d（E）"
            return display.string(from: date)
        }
        return dateString
    }
}

// MARK: - Flow Layout (Horizontal Wrapping)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), origins)
    }
}

// MARK: - Pending Reviews View

struct PendingReviewsCardView: View {
    @State private var pendingReviews: [PendingReview] = []
    @State private var isLoading = true
    @State private var selectedReview: PendingReview?

    private let api = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if pendingReviews.isEmpty {
                EmptyView()
            } else {
                pendingReviewsList
            }
        }
        .sheet(item: $selectedReview) { review in
            ReviewSubmitView(pendingReview: review) {
                // Remove from list after submission
                withAnimation {
                    pendingReviews.removeAll { $0.id == review.id }
                }
                selectedReview = nil
            }
        }
        .task {
            await loadPendingReviews()
        }
    }

    private var pendingReviewsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.bubble.fill")
                    .foregroundColor(.yellow)
                Text("レビュー待ち")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(pendingReviews.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pendingReviews) { review in
                        pendingReviewCard(review)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func pendingReviewCard(_ review: PendingReview) -> some View {
        Button {
            selectedReview = review
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(review.jobTitle ?? "お仕事")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let name = review.revieweeName {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let date = review.workDate {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Text("レビューを書く")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }
            .frame(width: 160, alignment: .leading)
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func loadPendingReviews() async {
        isLoading = true
        do {
            pendingReviews = try await api.getPendingReviews()
        } catch {
            // Silently fail — this is a supplementary view
        }
        isLoading = false
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "M/d"
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "M/d"
            return display.string(from: date)
        }
        return dateString
    }
}

// MARK: - Pending Reviews Banner

/// A compact banner that can be embedded in HomeView to prompt pending reviews.
struct PendingReviewsBanner: View {
    @State private var pendingCount = 0
    @State private var showPendingReviews = false

    private let api = APIClient.shared

    var body: some View {
        Group {
            if pendingCount > 0 {
                Button {
                    showPendingReviews = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "star.bubble.fill")
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("レビュー待ちがあります")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("\(pendingCount)件の未レビュー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPendingReviews) {
                    NavigationView {
                        PendingReviewsListSheet()
                            .navigationTitle("レビュー待ち")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("閉じる") { showPendingReviews = false }
                                }
                            }
                    }
                }
            }
        }
        .task {
            do {
                let reviews = try await api.getPendingReviews()
                pendingCount = reviews.count
            } catch {
                // ignore
            }
        }
    }
}

/// Full list sheet for pending reviews, opened from the banner.
private struct PendingReviewsListSheet: View {
    @State private var pendingReviews: [PendingReview] = []
    @State private var isLoading = true
    @State private var selectedReview: PendingReview?

    private let api = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if pendingReviews.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("未レビューはありません")
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                List {
                    ForEach(pendingReviews) { review in
                        Button {
                            selectedReview = review
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(review.jobTitle ?? "お仕事")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    if let name = review.revieweeName {
                                        Text(name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if let date = review.workDate {
                                        Text(formatDate(date))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedReview) { review in
            ReviewSubmitView(pendingReview: review) {
                withAnimation {
                    pendingReviews.removeAll { $0.id == review.id }
                }
                selectedReview = nil
            }
        }
        .task {
            isLoading = true
            do {
                pendingReviews = try await api.getPendingReviews()
            } catch {
                // handle silently
            }
            isLoading = false
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "M/d（E）"
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "M/d（E）"
            return display.string(from: date)
        }
        return dateString
    }
}

// MARK: - Review List View

struct ReviewListView: View {
    let userId: String
    let userName: String?

    @State private var reviews: [Review] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFilter: Int = 0 // 0 = all, 1-5 = rating

    private let api = APIClient.shared

    private var filteredReviews: [Review] {
        if selectedFilter == 0 {
            return reviews
        }
        return reviews.filter { $0.rating == selectedFilter }
    }

    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(reviews.count)
    }

    private var ratingDistribution: [Int: Int] {
        var distribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for review in reviews {
            distribution[review.rating, default: 0] += 1
        }
        return distribution
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.gray)
                    Button("再読み込み") {
                        Task { await loadReviews() }
                    }
                }
                .padding()
            } else if reviews.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("レビューはまだありません")
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Card
                        ratingSummaryCard

                        // Filter
                        ratingFilterBar

                        // Reviews
                        LazyVStack(spacing: 12) {
                            ForEach(filteredReviews) { review in
                                reviewRow(review)
                            }
                        }
                        .padding(.horizontal)

                        if filteredReviews.isEmpty {
                            Text("該当するレビューはありません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 20)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(userName != nil ? "\(userName!)のレビュー" : "レビュー一覧")
        .task {
            await loadReviews()
        }
    }

    // MARK: - Rating Summary Card

    private var ratingSummaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Average
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", averageRating))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    starsView(rating: averageRating)
                    Text("\(reviews.count)件のレビュー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 80)

                // Distribution
                VStack(alignment: .leading, spacing: 4) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        HStack(spacing: 6) {
                            Text("\(star)")
                                .font(.caption2)
                                .frame(width: 12, alignment: .trailing)
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.yellow)
                                        .frame(
                                            width: reviews.isEmpty ? 0 : geo.size.width * CGFloat(ratingDistribution[star, default: 0]) / CGFloat(reviews.count),
                                            height: 6
                                        )
                                }
                            }
                            .frame(height: 6)
                            Text("\(ratingDistribution[star, default: 0])")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Stars View

    private func starsView(rating: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starImageName(for: star, rating: rating))
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }

    private func starImageName(for position: Int, rating: Double) -> String {
        let diff = rating - Double(position - 1)
        if diff >= 1.0 {
            return "star.fill"
        } else if diff >= 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    // MARK: - Rating Filter

    private var ratingFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "すべて", value: 0)
                ForEach((1...5).reversed(), id: \.self) { star in
                    filterChip(label: "\(star)", value: star, showStar: true)
                }
            }
            .padding(.horizontal)
        }
    }

    private func filterChip(label: String, value: Int, showStar: Bool = false) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = value
            }
        } label: {
            HStack(spacing: 4) {
                if showStar {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(selectedFilter == value ? .white : .yellow)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedFilter == value ? Color.blue : Color(.systemGray6))
            .foregroundColor(selectedFilter == value ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Review Row

    private func reviewRow(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Reviewer name
                Text(review.reviewerName ?? "匿名")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                // Date
                if let date = review.createdAt {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            // Stars
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(star <= review.rating ? .yellow : Color(.systemGray4))
                }
            }

            // Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Actions

    private func loadReviews() async {
        isLoading = true
        errorMessage = nil
        do {
            reviews = try await api.getMyReviews()
        } catch {
            errorMessage = "レビューの読み込みに失敗しました"
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "yyyy/M/d"
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "yyyy/M/d"
            return display.string(from: date)
        }
        return dateString
    }
}
