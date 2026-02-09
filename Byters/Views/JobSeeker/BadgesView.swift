import SwiftUI

// MARK: - Badges View

struct BadgesView: View {
    @StateObject private var viewModel = BadgesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("読み込み中...")
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Stats Header
                        BadgeStatsHeader(
                            earnedCount: viewModel.earnedBadges.count,
                            totalCount: viewModel.allBadges.count
                        )

                        // Earned Badges
                        if !viewModel.earnedBadges.isEmpty {
                            BadgeSection(title: "獲得済みバッジ", badges: viewModel.earnedBadges, isEarned: true)
                        }

                        // Unearned Badges
                        if !viewModel.unearnedBadges.isEmpty {
                            BadgeSection(title: "未獲得バッジ", badges: viewModel.unearnedBadges, isEarned: false)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("バッジ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadBadges()
        }
        .refreshable {
            await viewModel.loadBadges()
        }
    }
}

struct BadgeStatsHeader: View {
    let earnedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.title)
                Text("\(earnedCount)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("/ \(totalCount)")
                    .font(.title2)
                    .foregroundColor(.gray)
            }

            Text("バッジを獲得しました")
                .font(.subheadline)
                .foregroundColor(.gray)

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow)
                        .frame(width: geometry.size.width * CGFloat(earnedCount) / CGFloat(max(totalCount, 1)), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct BadgeSection: View {
    let title: String
    let badges: [Badge]
    let isEarned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(badges) { badge in
                    BadgeCard(badge: badge, isEarned: isEarned)
                }
            }
        }
    }
}

struct BadgeCard: View {
    let badge: Badge
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isEarned ? badgeColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: badgeIcon)
                    .font(.title)
                    .foregroundColor(isEarned ? badgeColor : .gray.opacity(0.5))
            }

            Text(badge.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(isEarned ? .primary : .gray)

            if isEarned, let earnedAt = badge.earnedAt {
                Text(formatDate(earnedAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var badgeIcon: String {
        switch badge.type {
        case "first_job": return "star.fill"
        case "five_jobs": return "5.circle.fill"
        case "ten_jobs": return "10.circle.fill"
        case "perfect_attendance": return "checkmark.circle.fill"
        case "high_rating": return "hand.thumbsup.fill"
        case "verified": return "checkmark.seal.fill"
        case "early_bird": return "sunrise.fill"
        case "night_owl": return "moon.stars.fill"
        case "reliable": return "clock.badge.checkmark.fill"
        case "communicator": return "bubble.left.and.bubble.right.fill"
        default: return "star.circle.fill"
        }
    }

    private var badgeColor: Color {
        switch badge.type {
        case "first_job": return .yellow
        case "five_jobs": return .orange
        case "ten_jobs": return .red
        case "perfect_attendance": return .green
        case "high_rating": return .blue
        case "verified": return .purple
        case "early_bird": return .orange
        case "night_owl": return .indigo
        case "reliable": return .teal
        case "communicator": return .cyan
        default: return .gray
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "M/d"
            return displayFormatter.string(from: date)
        }
        return ""
    }
}

// MARK: - ViewModel

@MainActor
class BadgesViewModel: ObservableObject {
    @Published var allBadges: [Badge] = []
    @Published var earnedBadges: [Badge] = []
    @Published var unearnedBadges: [Badge] = []
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadBadges() async {
        isLoading = true
        do {
            let result = try await api.getBadges()
            allBadges = result
            earnedBadges = result.filter { $0.earnedAt != nil }
            unearnedBadges = result.filter { $0.earnedAt == nil }
        } catch {
            print("Failed to load badges: \(error)")
            // Fallback with default badges
            allBadges = Badge.defaultBadges
            unearnedBadges = allBadges
        }
        isLoading = false
    }
}

// MARK: - Model

struct Badge: Codable, Identifiable {
    let id: String
    let type: String
    let name: String
    let description: String?
    let earnedAt: String?

    static let defaultBadges: [Badge] = [
        Badge(id: "1", type: "first_job", name: "初仕事", description: "初めてのお仕事を完了", earnedAt: nil),
        Badge(id: "2", type: "five_jobs", name: "5回達成", description: "5回のお仕事を完了", earnedAt: nil),
        Badge(id: "3", type: "ten_jobs", name: "10回達成", description: "10回のお仕事を完了", earnedAt: nil),
        Badge(id: "4", type: "perfect_attendance", name: "皆勤賞", description: "1ヶ月間無遅刻無欠勤", earnedAt: nil),
        Badge(id: "5", type: "high_rating", name: "高評価", description: "平均評価4.5以上", earnedAt: nil),
        Badge(id: "6", type: "verified", name: "本人確認済み", description: "本人確認を完了", earnedAt: nil),
        Badge(id: "7", type: "early_bird", name: "早起き", description: "朝のシフトを10回完了", earnedAt: nil),
        Badge(id: "8", type: "night_owl", name: "夜型", description: "夜のシフトを10回完了", earnedAt: nil),
        Badge(id: "9", type: "reliable", name: "信頼の証", description: "連続10回定時チェックイン", earnedAt: nil),
    ]
}
