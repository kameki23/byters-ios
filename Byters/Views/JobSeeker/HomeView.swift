import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("こんにちは、")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text(authManager.currentUser?.displayName ?? "ゲスト")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Quick Stats
                    HStack(spacing: 16) {
                        StatCard(title: "応募中", value: "\(viewModel.pendingApplications)", icon: "clock.fill", color: .orange)
                        StatCard(title: "予定", value: "\(viewModel.upcomingWork)", icon: "calendar", color: .blue)
                        StatCard(title: "残高", value: "¥\(viewModel.walletBalance.formatted())", icon: "yensign.circle.fill", color: .green)
                    }
                    .padding(.horizontal)

                    // Featured Jobs Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("おすすめの求人")
                                .font(.headline)

                            Spacer()

                            NavigationLink(destination: JobSearchView()) {
                                Text("すべて見る")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if viewModel.featuredJobs.isEmpty {
                            EmptyStateView(
                                icon: "briefcase",
                                title: "求人がありません",
                                message: "新しい求人が登録されるまでお待ちください"
                            )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.featuredJobs) { job in
                                        NavigationLink(destination: JobDetailView(jobId: job.id)) {
                                            JobCard(job: job)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Recent Applications
                    VStack(alignment: .leading, spacing: 16) {
                        Text("最近の応募")
                            .font(.headline)
                            .padding(.horizontal)

                        if viewModel.recentApplications.isEmpty {
                            Text("まだ応募がありません")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.recentApplications.prefix(3)) { app in
                                    HomeApplicationRow(application: app)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - View Model

@MainActor
class HomeViewModel: ObservableObject {
    @Published var featuredJobs: [Job] = []
    @Published var recentApplications: [Application] = []
    @Published var walletBalance: Int = 0
    @Published var pendingApplications: Int = 0
    @Published var upcomingWork: Int = 0
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true

        async let jobsTask = loadJobs()
        async let applicationsTask = loadApplications()
        async let walletTask = loadWallet()

        await jobsTask
        await applicationsTask
        await walletTask

        isLoading = false
    }

    func refresh() async {
        await loadData()
    }

    private func loadJobs() async {
        do {
            featuredJobs = try await api.getJobs()
        } catch {
            print("Failed to load jobs: \(error)")
        }
    }

    private func loadApplications() async {
        do {
            let apps = try await api.getMyApplications()
            recentApplications = apps
            pendingApplications = apps.filter { $0.status == "pending" }.count
            upcomingWork = apps.filter { $0.status == "accepted" }.count
        } catch {
            print("Failed to load applications: \(error)")
        }
    }

    private func loadWallet() async {
        do {
            let wallet = try await api.getWallet()
            walletBalance = wallet.balance
        } catch {
            print("Failed to load wallet: \(error)")
        }
    }
}

// MARK: - Subviews

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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct JobCard: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Employer name
            Text(job.employerName ?? "企業名")
                .font(.caption)
                .foregroundColor(.gray)

            // Title
            Text(job.title)
                .font(.headline)
                .lineLimit(2)

            // Location
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                Text(job.locationDisplay)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Wage
            Text(job.wageDisplay)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .frame(width: 200, height: 160)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct HomeApplicationRow: View {
    let application: Application

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(application.jobTitle ?? "求人")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(application.employerName ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(application.statusDisplay)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor(application.status).opacity(0.1))
                .foregroundColor(statusColor(application.status))
                .clipShape(Capsule())
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "pending": return .orange
        case "accepted": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

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
        }
        .padding(40)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
