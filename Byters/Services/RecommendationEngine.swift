import Foundation
import Combine

// MARK: - Recommendation Engine

@MainActor
class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()

    @Published var recommendedJobs: [Job] = []
    @Published var isLoading: Bool = false

    private var lastLoadTime: Date?
    private var lastUserId: String?
    private let cacheTTL: TimeInterval = 60 * 30 // 30 minutes
    private let cacheKey = "recommended_jobs"

    private init() {}

    // MARK: - Public Methods

    func loadRecommendations(for userId: String) async {
        // Return cached results if still valid
        if let lastLoad = lastLoadTime,
           lastUserId == userId,
           Date().timeIntervalSince(lastLoad) < cacheTTL,
           !recommendedJobs.isEmpty {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Fetch user's work history
            let workHistory = try await APIClient.shared.getWorkHistory()

            // 2. Extract preferences from work history
            let preferences = extractPreferences(from: workHistory)

            // 3. Fetch available jobs
            let allJobs = try await APIClient.shared.getJobs(limit: 100)

            // 4. Score and sort by relevance
            let scored = allJobs.map { job -> (Job, Int) in
                let score = calculateScore(job: job, preferences: preferences)
                return (job, score)
            }

            let sorted = scored
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }

            recommendedJobs = sorted
            lastLoadTime = Date()
            lastUserId = userId

            // Cache results
            CacheService.shared.save(sorted, forKey: cacheKey)
        } catch {
            // Try loading from cache on failure
            if let cached = CacheService.shared.load([Job].self, forKey: cacheKey, ttl: cacheTTL) {
                recommendedJobs = cached
            }
            #if DEBUG
            print("[RecommendationEngine] Failed to load recommendations: \(error.localizedDescription)")
            #endif
        }
    }

    func refreshRecommendations() async {
        // Invalidate cache and reload
        lastLoadTime = nil
        if let userId = lastUserId {
            await loadRecommendations(for: userId)
        }
    }

    // MARK: - Preference Extraction

    private struct UserPreferences {
        var preferredCategories: Set<String>
        var preferredPrefectures: Set<String>
        var preferredCities: Set<String>
        var averageWage: Int
        var previousEmployerIds: Set<String>
    }

    private func extractPreferences(from history: [WorkHistory]) -> UserPreferences {
        let categories = Set<String>()
        let prefectures = Set<String>()
        let cities = Set<String>()
        var employerIds = Set<String>()
        var totalWage = 0
        var wageCount = 0

        for work in history {
            // WorkHistory doesn't have categories/prefecture directly,
            // but we track employer IDs and earnings for scoring
            employerIds.insert(work.jobId)

            if let earnings = work.earnings, earnings > 0 {
                totalWage += earnings
                wageCount += 1
            }
        }

        let averageWage = wageCount > 0 ? totalWage / wageCount : 0

        return UserPreferences(
            preferredCategories: categories,
            preferredPrefectures: prefectures,
            preferredCities: cities,
            averageWage: averageWage,
            previousEmployerIds: employerIds
        )
    }

    // MARK: - Scoring

    private func calculateScore(job: Job, preferences: UserPreferences) -> Int {
        var score = 0

        // Category match: 3 points
        if let jobCategories = job.categories {
            for category in jobCategories {
                if preferences.preferredCategories.contains(category) {
                    score += 3
                    break
                }
            }
        }

        // Location match - same prefecture: 2 points, same city: 3 points
        if let prefecture = job.prefecture, preferences.preferredPrefectures.contains(prefecture) {
            score += 2
        }
        if let city = job.city, preferences.preferredCities.contains(city) {
            score += 3
        }

        // Wage comparison: 1 point if hourly wage >= average past wage
        if preferences.averageWage > 0 {
            let jobWage = job.hourlyWage ?? job.dailyWage ?? 0
            if jobWage >= preferences.averageWage {
                score += 1
            }
        }

        // Previous employer: 2 points
        if let employerId = job.employerId, preferences.previousEmployerIds.contains(employerId) {
            score += 2
        }

        return score
    }
}
