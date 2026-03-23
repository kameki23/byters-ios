import SwiftUI

// MARK: - FollowedEmployer Model

struct FollowedEmployer: Codable, Identifiable {
    let id: String
    let employerId: String
    let employerName: String?
    let logoUrl: String?
    let averageRating: Double?
    let recentJobCount: Int?
    let followedAt: String?
}

// MARK: - Follow Button

struct FollowButton: View {
    let employerId: String
    @Binding var isFollowed: Bool
    var onToggle: ((Bool) -> Void)?

    @State private var isProcessing = false

    var body: some View {
        Button {
            guard !isProcessing else { return }
            toggleFollow()
        } label: {
            Image(systemName: isFollowed ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundColor(isFollowed ? .red : .gray)
                .scaleEffect(isProcessing ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isProcessing)
        }
        .disabled(isProcessing)
        .accessibilityLabel(isFollowed ? "フォロー解除" : "フォロー")
    }

    private func toggleFollow() {
        isProcessing = true
        let newState = !isFollowed

        Task {
            do {
                if newState {
                    _ = try await APIClient.shared.followEmployer(employerId: employerId)
                } else {
                    _ = try await APIClient.shared.unfollowEmployer(employerId: employerId)
                }
                await MainActor.run {
                    isFollowed = newState
                    onToggle?(newState)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                #if DEBUG
                print("[FollowButton] Error toggling follow: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

// MARK: - Followed Employers View

struct FollowedEmployersView: View {
    @StateObject private var viewModel = FollowedEmployersViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.employers.isEmpty {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.employers.isEmpty {
                emptyStateView
            } else {
                employerListView
            }
        }
        .navigationTitle("フォロー中の企業")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEmployers()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("お気に入りの企業をフォローすると\n新しい求人をすぐにチェックできます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Employer List

    private var employerListView: some View {
        List {
            ForEach(viewModel.employers) { employer in
                FollowedEmployerRow(
                    employer: employer,
                    onUnfollow: {
                        viewModel.removeEmployer(employer)
                    }
                )
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadEmployers()
        }
    }
}

// MARK: - Followed Employer Row

struct FollowedEmployerRow: View {
    let employer: FollowedEmployer
    var onUnfollow: (() -> Void)?

    @State private var isFollowed = true

    var body: some View {
        HStack(spacing: 12) {
            // Logo
            if let logoUrl = employer.logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "building.2")
                                .foregroundColor(.gray)
                        }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "building.2")
                            .foregroundColor(.gray)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(employer.employerName ?? "企業名不明")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let rating = employer.averageRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let jobCount = employer.recentJobCount, jobCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "briefcase")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("求人 \(jobCount)件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .overlay(alignment: .topTrailing) {
                            // Notification badge for new jobs
                            if jobCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Follow button
            FollowButton(
                employerId: employer.employerId,
                isFollowed: $isFollowed,
                onToggle: { followed in
                    if !followed {
                        onUnfollow?()
                    }
                }
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
class FollowedEmployersViewModel: ObservableObject {
    @Published var employers: [FollowedEmployer] = []
    @Published var isLoading = false

    func loadEmployers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            employers = try await APIClient.shared.getFollowedEmployers()
        } catch {
            #if DEBUG
            print("[FollowedEmployersViewModel] Failed to load employers: \(error.localizedDescription)")
            #endif
        }
    }

    func removeEmployer(_ employer: FollowedEmployer) {
        withAnimation {
            employers.removeAll { $0.id == employer.id }
        }
    }
}
