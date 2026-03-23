import Foundation

@MainActor
final class SkillMatchingService: ObservableObject {
    static let shared = SkillMatchingService()

    @Published var matchedJobs: [MatchedJob] = []
    @Published var isLoading = false

    struct MatchedJob: Identifiable {
        let id: String
        let job: Job
        let matchScore: Int
        let matchReasons: [String]
    }

    private init() {}

    func findMatches(
        userBadges: [Badge],
        workHistory: [WorkHistory],
        preferences: UserJobPreferences?
    ) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let jobs = try await APIClient.shared.getJobs()

            // Extract user's experience data
            let workedEmployers = Set(workHistory.map(\.employerName).compactMap { $0 })
            let badgeNames = Set(userBadges.map(\.name))

            var matched: [MatchedJob] = []

            for job in jobs {
                var score = 0
                var reasons: [String] = []

                // Badge match: user has required badges
                if let required = job.requiredBadges {
                    let requiredSet = Set(required)
                    let overlap = requiredSet.intersection(badgeNames)
                    if overlap.count == requiredSet.count {
                        score += 5
                        reasons.append("必要な資格をすべて保有")
                    } else if !overlap.isEmpty {
                        score += 2
                        reasons.append("一部の資格を保有")
                    }
                } else {
                    // No badges required - accessible to all
                    score += 1
                }

                // Employer match: worked for this employer before
                if let employer = job.employerName, workedEmployers.contains(employer) {
                    score += 3
                    reasons.append("勤務経験のある企業")
                }

                // Beginner friendly
                if job.beginnerWelcome {
                    score += 1
                    reasons.append("未経験歓迎")
                }

                // Wage match: above user's average
                if let wage = job.hourlyWage, let avgWage = averageWage(from: workHistory) {
                    if wage >= avgWage {
                        score += 2
                        reasons.append("平均時給以上")
                    }
                }

                if score >= 2 {
                    matched.append(MatchedJob(id: job.id, job: job, matchScore: score, matchReasons: reasons))
                }
            }

            matchedJobs = matched.sorted { $0.matchScore > $1.matchScore }
        } catch {
            #if DEBUG
            print("[SkillMatch] Failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func averageWage(from history: [WorkHistory]) -> Int? {
        let earnings = history.compactMap(\.earnings)
        guard !earnings.isEmpty else { return nil }
        return earnings.reduce(0, +) / earnings.count
    }
}

struct UserJobPreferences: Codable {
    var preferredCategories: [String]
    var preferredPrefecture: String?
    var preferredCity: String?
    var minWage: Int?
    var maxDistance: Double?
}
