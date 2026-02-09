import SwiftUI

// MARK: - Favorites View

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("読み込み中...")
            } else if viewModel.favorites.isEmpty {
                EmptyFavoritesView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.favorites) { favorite in
                            NavigationLink(destination: JobDetailView(jobId: favorite.jobId)) {
                                FavoriteJobCard(favorite: favorite) {
                                    Task { await viewModel.removeFavorite(jobId: favorite.jobId) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("お気に入り")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadFavorites()
        }
        .refreshable {
            await viewModel.loadFavorites()
        }
    }
}

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("お気に入りがありません")
                .font(.headline)
                .foregroundColor(.gray)
            Text("気になる求人をお気に入りに追加しましょう")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding()
    }
}

struct FavoriteJobCard: View {
    let favorite: FavoriteJob
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(favorite.jobTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(favorite.employerName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            HStack(spacing: 16) {
                if let wage = favorite.hourlyWage {
                    Label("¥\(wage)/時", systemImage: "yensign.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if let location = favorite.location {
                    Label(location, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            if let addedAt = favorite.createdAt {
                Text("追加日: \(formatDate(addedAt))")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "M月d日"
            return displayFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "M月d日"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favorites: [FavoriteJob] = []
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadFavorites() async {
        isLoading = true
        do {
            favorites = try await api.getFavorites()
        } catch {
            print("Failed to load favorites: \(error)")
        }
        isLoading = false
    }

    func removeFavorite(jobId: String) async {
        do {
            _ = try await api.removeFavorite(jobId: jobId)
            favorites.removeAll { $0.jobId == jobId }
        } catch {
            print("Failed to remove favorite: \(error)")
        }
    }
}

// MARK: - Model

struct FavoriteJob: Codable, Identifiable {
    let id: String
    let jobId: String
    let jobTitle: String
    let employerName: String
    let hourlyWage: Int?
    let location: String?
    let createdAt: String?
}
