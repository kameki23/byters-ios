import Foundation
import Combine

// MARK: - Search History Manager

@MainActor
class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()

    private let userDefaultsKey = "search_history"
    private let maxHistoryCount = 20

    @Published var recentSearches: [String] = []
    @Published var popularSearches: [String] = [
        "軽作業", "飲食", "イベント", "倉庫", "オフィス",
        "清掃", "配送", "コンビニ", "引越し", "販売"
    ]

    private init() {
        loadHistory()
        Task { await fetchPopularSearches() }
    }

    // MARK: - Public Methods

    func addSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove duplicate if exists, then insert at top
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)

        // Keep within limit
        if recentSearches.count > maxHistoryCount {
            recentSearches = Array(recentSearches.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    func removeSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        saveHistory()
    }

    func clearHistory() {
        recentSearches.removeAll()
        saveHistory()
    }

    func getSuggestions(for prefix: String) -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Return recent searches first, then popular, deduplicated
            var result: [String] = []
            var seen = Set<String>()
            for item in recentSearches + popularSearches {
                if seen.insert(item).inserted {
                    result.append(item)
                }
            }
            return result
        }

        let lowercased = trimmed.lowercased()
        var result: [String] = []
        var seen = Set<String>()

        // Recent searches matching prefix first
        for item in recentSearches where item.lowercased().contains(lowercased) {
            if seen.insert(item).inserted {
                result.append(item)
            }
        }

        // Then popular searches matching prefix
        for item in popularSearches where item.lowercased().contains(lowercased) {
            if seen.insert(item).inserted {
                result.append(item)
            }
        }

        return result
    }

    // MARK: - Private Methods

    private func loadHistory() {
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            recentSearches = saved
        }
    }

    private func saveHistory() {
        UserDefaults.standard.set(recentSearches, forKey: userDefaultsKey)
    }

    private func fetchPopularSearches() async {
        do {
            let suggestions = try await APIClient.shared.getSearchSuggestions(query: "")
            if !suggestions.isEmpty {
                popularSearches = suggestions
            }
        } catch {
            // Keep default popular searches on failure
            #if DEBUG
            print("[SearchHistoryManager] Failed to fetch popular searches: \(error.localizedDescription)")
            #endif
        }
    }
}
