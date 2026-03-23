import Foundation

// MARK: - API Client Extensions

extension APIClient {

    // MARK: - Employer Follow

    func followEmployer(employerId: String) async throws -> GenericAPIResponse {
        return try await request(
            endpoint: "/employers/\(employerId)/follow",
            method: "POST"
        )
    }

    func unfollowEmployer(employerId: String) async throws -> GenericAPIResponse {
        return try await request(
            endpoint: "/employers/\(employerId)/follow",
            method: "DELETE"
        )
    }

    func getFollowedEmployers() async throws -> [FollowedEmployer] {
        return try await request(endpoint: "/employers/followed")
    }

    // MARK: - Recommendations

    func getRecommendedJobs() async throws -> [Job] {
        return try await request(endpoint: "/jobs/recommended")
    }

    // MARK: - Search Suggestions

    func getSearchSuggestions(query: String) async throws -> [String] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await request(
            endpoint: "/search/suggestions?q=\(encoded)",
            requiresAuth: false
        )
    }

    // MARK: - Tax Documents

    func getTaxDocuments(year: Int) async throws -> [TaxDocument] {
        return try await request(endpoint: "/tax-documents?year=\(year)")
    }

    // MARK: - Worker Availability

    func getWorkerAvailability(month: String) async throws -> [WorkerAvailability] {
        return try await request(endpoint: "/employer/workers/availability?month=\(month)")
    }

    func inviteWorkerForDate(workerId: String, date: String) async throws -> GenericAPIResponse {
        return try await request(
            endpoint: "/employer/workers/\(workerId)/invite",
            method: "POST",
            body: ["date": date]
        )
    }
}
