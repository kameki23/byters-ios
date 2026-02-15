import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURLです"
        case .noData: return "データがありません"
        case .decodingError: return "データの解析に失敗しました"
        case .serverError(let message): return message
        case .unauthorized: return "認証が必要です"
        case .networkError(let error): return error.localizedDescription
        }
    }
}

class APIClient {
    static let shared = APIClient()

    private let baseURL: String = StripeConfig.apiBaseURL
    private let maxRetries = 2
    private let session: URLSession

    private var token: String? {
        KeychainHelper.load(key: "auth_token")
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    private func notifyUnauthorized() {
        Task { @MainActor in
            AuthManager.shared.handleUnauthorized()
        }
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let isIdempotent = method == "GET" || method == "HEAD"
        var lastError: Error = APIError.noData

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
            }

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.noData
                }

                if httpResponse.statusCode == 401 {
                    notifyUnauthorized()
                    throw APIError.unauthorized
                }

                if httpResponse.statusCode >= 500 && isIdempotent && attempt < maxRetries {
                    lastError = APIError.serverError("サーバーエラー: \(httpResponse.statusCode)")
                    continue
                }

                if httpResponse.statusCode >= 400 {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        throw APIError.serverError(errorResponse.detail)
                    }
                    throw APIError.serverError("サーバーエラー: \(httpResponse.statusCode)")
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                return try decoder.decode(T.self, from: data)
            } catch let error as APIError {
                if case .unauthorized = error { throw error }
                lastError = error
                if !isIdempotent || attempt >= maxRetries { throw error }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = APIError.networkError(error)
                if !isIdempotent || attempt >= maxRetries {
                    throw APIError.networkError(error)
                }
            }
        }

        throw lastError
    }

    // Request that returns raw Data (for file uploads)
    func requestData(
        endpoint: String,
        method: String = "POST",
        formData: Data,
        contentType: String
    ) async throws -> SimpleResponse {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = formData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if httpResponse.statusCode == 401 {
            notifyUnauthorized()
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.detail)
            }
            throw APIError.serverError("アップロードに失敗しました: \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SimpleResponse.self, from: data)
    }

    // MARK: - Auth Endpoints

    func login(email: String, password: String) async throws -> LoginResponse {
        return try await request(
            endpoint: "/auth/login",
            method: "POST",
            body: ["email": email, "password": password],
            requiresAuth: false
        )
    }

    func adminLogin(email: String, password: String) async throws -> LoginResponse {
        return try await request(
            endpoint: "/admin/login",
            method: "POST",
            body: ["email": email, "password": password],
            requiresAuth: false
        )
    }

    func register(email: String, password: String, name: String, userType: String) async throws -> RegisterResponse {
        return try await request(
            endpoint: "/auth/register",
            method: "POST",
            body: [
                "email": email,
                "password": password,
                "name": name,
                "user_type": userType
            ],
            requiresAuth: false
        )
    }

    func getCurrentUser() async throws -> User {
        return try await request(endpoint: "/auth/me")
    }

    func updateProfile(name: String?, phone: String?, bio: String?, prefecture: String?, city: String?) async throws -> User {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let phone = phone { body["phone"] = phone }
        if let bio = bio { body["bio"] = bio }
        if let prefecture = prefecture { body["prefecture"] = prefecture }
        if let city = city { body["city"] = city }

        return try await request(
            endpoint: "/auth/profile",
            method: "PUT",
            body: body
        )
    }

    func uploadProfileImage(imageData: Data) async throws -> SimpleResponse {
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        return try await requestData(
            endpoint: "/auth/profile/image",
            formData: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    // MARK: - Jobs Endpoints

    func getJobs(search: String? = nil, prefecture: String? = nil, city: String? = nil, category: String? = nil) async throws -> [Job] {
        var queryParams: [String] = []
        if let search = search, !search.isEmpty {
            queryParams.append("keyword=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        if let prefecture = prefecture, !prefecture.isEmpty {
            queryParams.append("prefecture=\(prefecture.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        if let city = city, !city.isEmpty {
            queryParams.append("city=\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        if let category = category, !category.isEmpty {
            queryParams.append("category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }

        let endpoint = "/search/jobs-enhanced?" + queryParams.joined(separator: "&")
        return try await request(endpoint: endpoint, requiresAuth: false)
    }

    func getJobDetail(jobId: String) async throws -> Job {
        return try await request(endpoint: "/jobs/\(jobId)", requiresAuth: false)
    }

    func applyForJob(jobId: String, message: String?) async throws -> ApplicationResponse {
        var body: [String: Any] = [:]
        if let message = message {
            body["message"] = message
        }
        return try await request(
            endpoint: "/jobs/\(jobId)/apply",
            method: "POST",
            body: body
        )
    }

    func getCategories() async throws -> [JobCategory] {
        return try await request(endpoint: "/categories", requiresAuth: false)
    }

    // MARK: - Favorite Jobs

    func getFavoriteJobs() async throws -> [Job] {
        return try await request(endpoint: "/favorites/jobs")
    }

    func addFavoriteJob(jobId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/favorites/jobs/\(jobId)",
            method: "POST"
        )
    }

    func removeFavoriteJob(jobId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/favorites/jobs/\(jobId)",
            method: "DELETE"
        )
    }

    func getFavoriteEmployers() async throws -> [EmployerProfile] {
        return try await request(endpoint: "/favorites/employers")
    }

    func addFavoriteEmployer(employerId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/favorites/employers/\(employerId)",
            method: "POST"
        )
    }

    func removeFavoriteEmployer(employerId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/favorites/employers/\(employerId)",
            method: "DELETE"
        )
    }

    // MARK: - Wallet Endpoints

    func getWallet() async throws -> Wallet {
        return try await request(endpoint: "/wallet")
    }

    func getTransactions() async throws -> [Transaction] {
        let response: TransactionsResponse = try await request(endpoint: "/wallet/transactions")
        return response.data
    }

    // MARK: - Bank Account Endpoints

    func getBankAccounts() async throws -> [BankAccount] {
        let response: BankAccountsResponse = try await request(endpoint: "/wallet/bank-accounts")
        return response.data
    }

    func addBankAccount(
        bankName: String,
        bankCode: String,
        branchName: String,
        branchCode: String,
        accountType: String,
        accountNumber: String,
        accountHolderName: String
    ) async throws -> BankAccount {
        return try await request(
            endpoint: "/wallet/bank-accounts",
            method: "POST",
            body: [
                "bank_name": bankName,
                "bank_code": bankCode,
                "branch_name": branchName,
                "branch_code": branchCode,
                "account_type": accountType,
                "account_number": accountNumber,
                "account_holder_name": accountHolderName
            ]
        )
    }

    func deleteBankAccount(accountId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/wallet/bank-accounts/\(accountId)",
            method: "DELETE"
        )
    }

    // MARK: - Withdrawal Endpoints

    func requestWithdrawal(bankAccountId: String, amount: Int) async throws -> WithdrawalRequest {
        return try await request(
            endpoint: "/wallet/withdrawal-request",
            method: "POST",
            body: [
                "bank_account_id": bankAccountId,
                "amount": amount
            ]
        )
    }

    func getWithdrawalHistory() async throws -> [WithdrawalRequest] {
        return try await request(endpoint: "/wallet/withdrawal-requests")
    }

    // MARK: - Identity Verification Endpoints

    func getIdentityVerificationStatus() async throws -> IdentityVerification {
        return try await request(endpoint: "/identity/status")
    }

    func submitIdentityVerification(documentType: String, frontImageData: Data, backImageData: Data?) async throws -> SimpleResponse {
        // For simplicity, using base64 encoding
        let boundary = UUID().uuidString
        var body = Data()

        // Document type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"document_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(documentType)\r\n".data(using: .utf8)!)

        // Front image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"front_image\"; filename=\"front.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(frontImageData)
        body.append("\r\n".data(using: .utf8)!)

        // Back image (optional)
        if let backData = backImageData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"back_image\"; filename=\"back.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(backData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return try await requestData(
            endpoint: "/identity/submit",
            method: "POST",
            formData: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    // MARK: - Applications Endpoints

    func getMyApplications() async throws -> [Application] {
        return try await request(endpoint: "/matching-applications/my")
    }

    func cancelApplication(applicationId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/matching-applications/\(applicationId)/cancel",
            method: "POST"
        )
    }

    // MARK: - Work History Endpoints

    func getWorkHistory() async throws -> [WorkHistory] {
        return try await request(endpoint: "/mypage/work-history")
    }

    func checkIn(workHistoryId: String) async throws -> WorkHistory {
        return try await request(
            endpoint: "/attendance/\(workHistoryId)/check-in",
            method: "POST"
        )
    }

    func checkOut(workHistoryId: String) async throws -> WorkHistory {
        return try await request(
            endpoint: "/attendance/\(workHistoryId)/check-out",
            method: "POST"
        )
    }

    // QR Code Check-in with location
    func checkInWithQR(token: String, latitude: Double?, longitude: Double?, deviceTime: String) async throws -> CheckInResponse {
        var body: [String: Any] = [
            "token": token,
            "device_time": deviceTime
        ]
        if let lat = latitude { body["latitude"] = lat }
        if let lng = longitude { body["longitude"] = lng }

        return try await request(
            endpoint: "/attendance/qr-check-in",
            method: "POST",
            body: body
        )
    }

    // Check-out with location
    func checkOutWithLocation(applicationId: String, latitude: Double?, longitude: Double?, deviceTime: String) async throws -> CheckOutResponse {
        var body: [String: Any] = [
            "device_time": deviceTime
        ]
        if let lat = latitude { body["latitude"] = lat }
        if let lng = longitude { body["longitude"] = lng }

        return try await request(
            endpoint: "/attendance/\(applicationId)/check-out",
            method: "POST",
            body: body
        )
    }

    // MARK: - Chat Endpoints

    func getChatRooms() async throws -> [ChatRoom] {
        return try await request(endpoint: "/chat/rooms")
    }

    func getChatMessages(roomId: String) async throws -> [ChatMessage] {
        return try await request(endpoint: "/chat/rooms/\(roomId)/messages")
    }

    func sendMessage(roomId: String, content: String) async throws -> ChatMessage {
        return try await request(
            endpoint: "/chat/rooms/\(roomId)/messages",
            method: "POST",
            body: ["content": content]
        )
    }

    func sendMessageWithImage(roomId: String, content: String?, imageBase64: String) async throws -> ChatMessage {
        var body: [String: Any] = [
            "message_type": "image",
            "image": imageBase64
        ]
        if let content = content {
            body["content"] = content
        }
        return try await request(
            endpoint: "/chat/rooms/\(roomId)/messages",
            method: "POST",
            body: body
        )
    }

    func sendMessageWithFile(roomId: String, content: String?, fileBase64: String, fileName: String) async throws -> ChatMessage {
        var body: [String: Any] = [
            "message_type": "file",
            "file": fileBase64,
            "file_name": fileName
        ]
        if let content = content {
            body["content"] = content
        }
        return try await request(
            endpoint: "/chat/rooms/\(roomId)/messages",
            method: "POST",
            body: body
        )
    }

    // MARK: - Employer Endpoints

    func getEmployerStats() async throws -> EmployerStats {
        return try await request(endpoint: "/employer/stats")
    }

    func getEmployerProfile() async throws -> EmployerProfile {
        return try await request(endpoint: "/employer/profile")
    }

    func updateEmployerProfile(
        businessName: String?,
        description: String?,
        prefecture: String?,
        city: String?,
        address: String?,
        contactPhone: String?,
        contactEmail: String?
    ) async throws -> EmployerProfile {
        var body: [String: Any] = [:]
        if let businessName = businessName { body["business_name"] = businessName }
        if let description = description { body["description"] = description }
        if let prefecture = prefecture { body["prefecture"] = prefecture }
        if let city = city { body["city"] = city }
        if let address = address { body["address"] = address }
        if let contactPhone = contactPhone { body["contact_phone"] = contactPhone }
        if let contactEmail = contactEmail { body["contact_email"] = contactEmail }

        return try await request(
            endpoint: "/employer/profile",
            method: "PUT",
            body: body
        )
    }

    func getEmployerJobs() async throws -> [Job] {
        return try await request(endpoint: "/employer/jobs")
    }

    func createJob(
        title: String,
        description: String,
        prefecture: String,
        city: String,
        address: String?,
        hourlyWage: Int?,
        dailyWage: Int?,
        workDate: String?,
        startTime: String,
        endTime: String,
        requiredPeople: Int,
        categories: [String]?,
        requirements: String?,
        benefits: String?
    ) async throws -> Job {
        var body: [String: Any] = [
            "title": title,
            "description": description,
            "prefecture": prefecture,
            "city": city,
            "start_time": startTime,
            "end_time": endTime,
            "required_people": requiredPeople
        ]
        if let address = address { body["address"] = address }
        if let hourlyWage = hourlyWage { body["hourly_wage"] = hourlyWage }
        if let dailyWage = dailyWage { body["daily_wage"] = dailyWage }
        if let workDate = workDate { body["work_date"] = workDate }
        if let categories = categories { body["categories"] = categories }
        if let requirements = requirements { body["requirements"] = requirements }
        if let benefits = benefits { body["benefits"] = benefits }

        return try await request(
            endpoint: "/employer/jobs",
            method: "POST",
            body: body
        )
    }

    func createJobWithImages(
        title: String,
        description: String,
        prefecture: String,
        city: String,
        address: String?,
        hourlyWage: Int?,
        dailyWage: Int?,
        workDate: String?,
        startTime: String,
        endTime: String,
        requiredPeople: Int,
        categories: [String]?,
        requirements: String?,
        benefits: String?,
        images: [String],
        thumbnailIndex: Int
    ) async throws -> Job {
        var body: [String: Any] = [
            "title": title,
            "description": description,
            "prefecture": prefecture,
            "city": city,
            "start_time": startTime,
            "end_time": endTime,
            "required_people": requiredPeople
        ]
        if let address = address { body["address"] = address }
        if let hourlyWage = hourlyWage { body["hourly_wage"] = hourlyWage }
        if let dailyWage = dailyWage { body["daily_wage"] = dailyWage }
        if let workDate = workDate { body["work_date"] = workDate }
        if let categories = categories { body["categories"] = categories }
        if let requirements = requirements { body["requirements"] = requirements }
        if let benefits = benefits { body["benefits"] = benefits }

        // Add images as base64
        if !images.isEmpty {
            body["images"] = images
            body["thumbnail_index"] = thumbnailIndex
        }

        return try await request(
            endpoint: "/employer/jobs",
            method: "POST",
            body: body
        )
    }

    func updateJob(jobId: String, updates: [String: Any]) async throws -> Job {
        return try await request(
            endpoint: "/employer/jobs/\(jobId)",
            method: "PUT",
            body: updates
        )
    }

    func deleteJob(jobId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/jobs/\(jobId)",
            method: "DELETE"
        )
    }

    func publishJob(jobId: String) async throws -> Job {
        return try await request(
            endpoint: "/employer/jobs/\(jobId)/publish",
            method: "POST"
        )
    }

    func closeJob(jobId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/jobs/\(jobId)/close",
            method: "PUT"
        )
    }

    func repostJob(jobId: String, workDate: String?, hourlyRate: Int?, requiredPeople: Int?) async throws -> Job {
        var body: [String: Any] = [:]
        if let workDate = workDate { body["work_date"] = workDate }
        if let hourlyRate = hourlyRate { body["hourly_rate"] = hourlyRate }
        if let requiredPeople = requiredPeople { body["required_people"] = requiredPeople }
        return try await request(
            endpoint: "/employer/jobs/\(jobId)/repost",
            method: "POST",
            body: body
        )
    }

    func getEmployerApplications() async throws -> [Application] {
        return try await request(endpoint: "/employer/applications")
    }

    func approveApplication(applicationId: String) async throws -> Application {
        return try await request(
            endpoint: "/employer/applications/\(applicationId)/approve",
            method: "POST"
        )
    }

    func rejectApplication(applicationId: String, reason: String?) async throws -> Application {
        var body: [String: Any] = [:]
        if let reason = reason { body["reason"] = reason }
        return try await request(
            endpoint: "/employer/applications/\(applicationId)/reject",
            method: "POST",
            body: body
        )
    }

    // MARK: - Payment Endpoints (Stripe)

    func getPaymentMethods() async throws -> [PaymentMethod] {
        return try await request(endpoint: "/payment/methods")
    }

    func createSetupIntent() async throws -> PaymentIntent {
        return try await request(
            endpoint: "/payment/setup-intent",
            method: "POST"
        )
    }

    func attachPaymentMethod(paymentMethodId: String) async throws -> PaymentMethod {
        return try await request(
            endpoint: "/payment/methods",
            method: "POST",
            body: ["payment_method_id": paymentMethodId]
        )
    }

    func deletePaymentMethod(paymentMethodId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/payment/methods/\(paymentMethodId)",
            method: "DELETE"
        )
    }

    func setDefaultPaymentMethod(paymentMethodId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/payment/methods/\(paymentMethodId)/default",
            method: "POST"
        )
    }

    // Get payment quote for a job/worker
    func getPaymentQuote(jobId: String, workerId: String, hours: Double) async throws -> PaymentQuoteResponse {
        return try await request(
            endpoint: "/payment/quote",
            method: "POST",
            body: [
                "job_id": jobId,
                "worker_id": workerId,
                "hours": hours
            ]
        )
    }

    // Process payment charge
    func chargePayment(
        jobId: String,
        workerId: String,
        amount: Int,
        paymentMethodId: String,
        idempotencyKey: String
    ) async throws -> PaymentChargeResponse {
        return try await request(
            endpoint: "/payment/charge",
            method: "POST",
            body: [
                "job_id": jobId,
                "worker_id": workerId,
                "amount": amount,
                "payment_method_id": paymentMethodId,
                "idempotency_key": idempotencyKey
            ]
        )
    }

    // Auto-pay after checkout (called by backend, but can trigger manually)
    func processCheckoutPayment(applicationId: String) async throws -> PaymentChargeResponse {
        return try await request(
            endpoint: "/payment/checkout-payment/\(applicationId)",
            method: "POST"
        )
    }

    // MARK: - Notifications

    func getNotifications() async throws -> [AppNotification] {
        return try await request(endpoint: "/notifications")
    }

    func markNotificationRead(notificationId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/notifications/\(notificationId)/read",
            method: "POST"
        )
    }

    func markAllNotificationsRead() async throws -> SimpleResponse {
        return try await request(
            endpoint: "/notifications/read-all",
            method: "POST"
        )
    }

    // MARK: - Support / Contact

    func submitContactForm(category: String, subject: String, message: String, email: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/support/messages",
            method: "POST",
            body: [
                "category": category,
                "subject": subject,
                "message": message,
                "email": email
            ]
        )
    }

    // MARK: - Reviews

    func getMyReviews() async throws -> [Review] {
        return try await request(endpoint: "/reviews/my")
    }

    func submitReview(jobId: String, revieweeId: String, rating: Int, comment: String?) async throws -> Review {
        var body: [String: Any] = [
            "job_id": jobId,
            "reviewee_id": revieweeId,
            "rating": rating
        ]
        if let comment = comment { body["comment"] = comment }

        return try await request(
            endpoint: "/reviews",
            method: "POST",
            body: body
        )
    }

    // MARK: - QR Code Endpoints

    func getJobQRCode(jobId: String) async throws -> QRCodeResponse {
        return try await request(endpoint: "/employer/jobs/\(jobId)/qr-token")
    }

    func regenerateJobQRCode(jobId: String) async throws -> QRCodeResponse {
        return try await request(
            endpoint: "/employer/jobs/\(jobId)/qr-token",
            method: "POST"
        )
    }

    // MARK: - Review Endpoints (Extended)

    func getJobReviews(jobId: String) async throws -> [Review] {
        return try await request(endpoint: "/reviews/job/\(jobId)")
    }

    func getEmployerReviews(employerId: String) async throws -> [Review] {
        return try await request(endpoint: "/reviews/employer/\(employerId)")
    }

    func getWorkerReviews(workerId: String) async throws -> [Review] {
        return try await request(endpoint: "/reviews/worker/\(workerId)")
    }

    func getPendingReviews() async throws -> [PendingReview] {
        return try await request(endpoint: "/reviews/pending")
    }

    // MARK: - Eligibility Check

    func checkApplicationEligibility(jobId: String) async throws -> EligibilityResponse {
        return try await request(endpoint: "/jobs/\(jobId)/eligibility")
    }

    // MARK: - Admin Endpoints

    func getAdminDashboardStats() async throws -> AdminDashboardStats {
        return try await request(endpoint: "/admin/dashboard/stats")
    }

    func getAdminRecentActivity() async throws -> [AdminActivity] {
        return try await request(endpoint: "/admin/dashboard/activity")
    }

    func getAdminUsers(
        search: String? = nil,
        userType: String? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> [AdminUser] {
        var queryParams: [String] = ["page=\(page)", "limit=\(limit)"]
        if let search = search, !search.isEmpty {
            queryParams.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        if let userType = userType, userType != "all" {
            queryParams.append("user_type=\(userType)")
        }
        let endpoint = "/admin/users?" + queryParams.joined(separator: "&")
        return try await request(endpoint: endpoint)
    }

    func getAdminUserDetail(userId: String) async throws -> AdminUser {
        return try await request(endpoint: "/admin/users/\(userId)")
    }

    func banUser(userId: String, reason: String?) async throws -> SimpleResponse {
        var body: [String: Any] = [:]
        if let reason = reason { body["reason"] = reason }
        return try await request(
            endpoint: "/admin/users/\(userId)/ban",
            method: "POST",
            body: body
        )
    }

    func unbanUser(userId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/users/\(userId)/unban",
            method: "POST"
        )
    }

    func deleteUser(userId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/users/\(userId)",
            method: "DELETE"
        )
    }

    func getAdminJobs(
        search: String? = nil,
        status: String? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> [AdminJob] {
        var queryParams: [String] = ["page=\(page)", "limit=\(limit)"]
        if let search = search, !search.isEmpty {
            queryParams.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        if let status = status, status != "all" {
            queryParams.append("status=\(status)")
        }
        let endpoint = "/admin/jobs?" + queryParams.joined(separator: "&")
        return try await request(endpoint: endpoint)
    }

    func approveJob(jobId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/jobs/\(jobId)/approve",
            method: "POST"
        )
    }

    func suspendJob(jobId: String, reason: String?) async throws -> SimpleResponse {
        var body: [String: Any] = [:]
        if let reason = reason { body["reason"] = reason }
        return try await request(
            endpoint: "/admin/jobs/\(jobId)/suspend",
            method: "POST",
            body: body
        )
    }

    func flagJob(jobId: String, reason: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/jobs/\(jobId)/flag",
            method: "POST",
            body: ["reason": reason]
        )
    }

    func getAdminWithdrawals(status: String? = nil) async throws -> [AdminWithdrawalRequest] {
        var endpoint = "/admin/withdrawals"
        if let status = status, status != "all" {
            endpoint += "?status=\(status)"
        }
        return try await request(endpoint: endpoint)
    }

    func approveWithdrawal(withdrawalId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/withdrawals/\(withdrawalId)/approve",
            method: "POST"
        )
    }

    func rejectWithdrawal(withdrawalId: String, reason: String?) async throws -> SimpleResponse {
        var body: [String: Any] = [:]
        if let reason = reason { body["reason"] = reason }
        return try await request(
            endpoint: "/admin/withdrawals/\(withdrawalId)/reject",
            method: "POST",
            body: body
        )
    }

    func getAdminIdentityVerifications(status: String? = nil) async throws -> [AdminIdentityVerification] {
        var endpoint = "/admin/identity-verifications"
        if let status = status, status != "all" {
            endpoint += "?status=\(status)"
        }
        return try await request(endpoint: endpoint)
    }

    func approveIdentityVerification(verificationId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/identity-verifications/\(verificationId)/approve",
            method: "POST"
        )
    }

    func rejectIdentityVerification(verificationId: String, reason: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/identity-verifications/\(verificationId)/reject",
            method: "POST",
            body: ["reason": reason]
        )
    }

    func getAdminBanners() async throws -> [AdminBanner] {
        return try await request(endpoint: "/admin/banners")
    }

    func createBanner(
        title: String,
        imageUrl: String,
        linkUrl: String?,
        isActive: Bool,
        startDate: String?,
        endDate: String?
    ) async throws -> AdminBanner {
        var body: [String: Any] = [
            "title": title,
            "image_url": imageUrl,
            "is_active": isActive
        ]
        if let linkUrl = linkUrl { body["link_url"] = linkUrl }
        if let startDate = startDate { body["start_date"] = startDate }
        if let endDate = endDate { body["end_date"] = endDate }

        return try await request(
            endpoint: "/admin/banners",
            method: "POST",
            body: body
        )
    }

    func updateBanner(bannerId: String, updates: [String: Any]) async throws -> AdminBanner {
        return try await request(
            endpoint: "/admin/banners/\(bannerId)",
            method: "PUT",
            body: updates
        )
    }

    func deleteBanner(bannerId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/banners/\(bannerId)",
            method: "DELETE"
        )
    }

    func getAdminSystemSettings() async throws -> AdminSystemSettings {
        return try await request(endpoint: "/admin/system-settings")
    }

    func updateAdminSystemSettings(settings: [String: Any]) async throws -> AdminSystemSettings {
        return try await request(
            endpoint: "/admin/system-settings",
            method: "PUT",
            body: settings
        )
    }

    func updateAdminSystemSettings(key: String, value: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/settings/\(key)",
            method: "PUT",
            body: ["value": value]
        )
    }

    // MARK: - KYC Settings

    func getKycSettings() async throws -> KycSettings {
        return try await request(endpoint: "/admin/settings/kyc")
    }

    func updateKycSettings(approvalMode: String) async throws -> KycSettings {
        return try await request(
            endpoint: "/admin/settings/kyc",
            method: "PUT",
            body: ["approval_mode": approvalMode]
        )
    }

    // MARK: - Favorites

    func getFavorites() async throws -> [FavoriteJob] {
        return try await request(endpoint: "/favorites")
    }

    func isFavorite(jobId: String) async throws -> Bool {
        struct FavoriteStatus: Codable { let isFavorite: Bool }
        let result: FavoriteStatus = try await request(endpoint: "/favorites/\(jobId)/status")
        return result.isFavorite
    }

    // MARK: - Qualifications

    func getQualifications() async throws -> [Qualification] {
        return try await request(endpoint: "/qualifications")
    }

    func addQualification(type: String, name: String, expiryDate: String?, imageData: Data) async throws -> SimpleResponse {
        let base64Image = imageData.base64EncodedString()
        var body: [String: Any] = [
            "type": type,
            "name": name,
            "image": base64Image
        ]
        if let expiry = expiryDate {
            body["expiry_date"] = expiry
        }

        return try await request(
            endpoint: "/qualifications",
            method: "POST",
            body: body
        )
    }

    func deleteQualification(qualificationId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/qualifications/\(qualificationId)",
            method: "DELETE"
        )
    }

    // MARK: - Badges

    func getBadges() async throws -> [Badge] {
        return try await request(endpoint: "/badges")
    }

    // MARK: - Earnings Goal

    func getEarningsGoal() async throws -> EarningsGoalData {
        return try await request(endpoint: "/earnings/goal")
    }

    func setEarningsGoal(amount: Int, period: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/earnings/goal",
            method: "POST",
            body: [
                "goal_amount": amount,
                "period": period
            ]
        )
    }

    func getRecentEarnings() async throws -> [EarningRecord] {
        return try await request(endpoint: "/earnings/recent")
    }

    func getEarningsStats() async throws -> EarningsStats {
        return try await request(endpoint: "/earnings/stats")
    }

    // MARK: - Employer Finance

    func getEmployerFinanceStats() async throws -> EmployerFinanceStats {
        return try await request(endpoint: "/employer/finance/stats")
    }

    // MARK: - Employer Timesheets

    func getEmployerTimesheets() async throws -> [TimesheetData] {
        return try await request(endpoint: "/employer/timesheets")
    }

    func updateTimesheet(timesheetId: String, approved: Bool) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/timesheets/\(timesheetId)",
            method: "PUT",
            body: ["status": approved ? "approved" : "rejected"]
        )
    }
}

// MARK: - KYC Settings Model

struct KycSettings: Codable {
    let approvalMode: String
}

// MARK: - Earnings Stats Model

struct EarningsStats: Codable {
    let totalEarnings: Int
    let thisMonthEarnings: Int
    let lastMonthEarnings: Int
    let averagePerJob: Int
}

// MARK: - Employer Finance Models

struct EmployerFinanceStats: Codable {
    let thisMonthTotal: Int
    let thisMonthHires: Int
    let totalFees: Int
    let totalPayments: Int
    let monthlyBreakdown: [MonthlyBreakdown]
    let recentTransactions: [TransactionData]
}

struct MonthlyBreakdown: Codable {
    let month: String
    let amount: Int
}

struct TransactionData: Codable {
    let id: String
    let description: String
    let amount: Int
    let date: String
    let type: String
}

// MARK: - Timesheet Model

struct TimesheetData: Codable {
    let id: String
    let workerName: String
    let jobTitle: String
    let date: String
    let checkIn: String
    let checkOut: String
    let amount: Int
    let status: String
}

// Note: ErrorResponse is defined in AuthView.swift

// MARK: - Admin Qualifications

extension APIClient {
    func getAdminQualifications(status: String? = nil) async throws -> [AdminQualification] {
        var endpoint = "/admin/qualifications"
        if let status = status, status != "all" {
            endpoint += "?status=\(status)"
        }
        return try await request(endpoint: endpoint)
    }

    func getAdminQualificationDetail(qualificationId: String) async throws -> AdminQualification {
        return try await request(endpoint: "/admin/qualifications/\(qualificationId)")
    }

    func approveQualification(qualificationId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/qualifications/\(qualificationId)",
            method: "PUT",
            body: ["status": "approved"]
        )
    }

    func rejectQualification(qualificationId: String, reason: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/qualifications/\(qualificationId)",
            method: "PUT",
            body: ["status": "rejected", "rejection_reason": reason]
        )
    }
}

// MARK: - Admin Ads/Banners Management

extension APIClient {
    func getAdminBannerSlots() async throws -> [AdminBannerSlot] {
        return try await request(endpoint: "/admin/banners/slots")
    }

    func getAdminBannerCandidates() async throws -> [AdminBannerSlot] {
        return try await request(endpoint: "/admin/banners/candidates")
    }

    func updateBannerOrder(orderedIds: [String]) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/banners/order",
            method: "PUT",
            body: ["ordered_ids": orderedIds]
        )
    }

    func createBannerWithImage(imageBase64: String, linkUrl: String, description: String, months: Int) async throws -> AdminBannerSlot {
        return try await request(
            endpoint: "/admin/banners",
            method: "POST",
            body: [
                "image_base64": imageBase64,
                "link_url": linkUrl,
                "description": description,
                "months": months
            ]
        )
    }

    func getAdminAdSettings() async throws -> AdminAdSettings {
        return try await request(endpoint: "/admin/settings")
    }

    func updateAdSetting(key: String, value: String, description: String, category: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/settings/\(key)",
            method: "POST",
            body: [
                "value": value,
                "description": description,
                "category": category
            ]
        )
    }
}

// MARK: - User Settings

extension APIClient {
    func getNotificationSettings() async throws -> NotificationSettings {
        return try await request(endpoint: "/settings/notifications")
    }

    func updateNotificationSettings(settings: [String: Bool]) async throws -> NotificationSettings {
        return try await request(
            endpoint: "/settings/notifications",
            method: "PUT",
            body: settings
        )
    }

    func getEmailSettings() async throws -> EmailSettings {
        return try await request(endpoint: "/settings/email")
    }

    func updateEmailSettings(settings: [String: Bool]) async throws -> EmailSettings {
        return try await request(
            endpoint: "/settings/email",
            method: "PUT",
            body: settings
        )
    }

    func getLocationSettings() async throws -> LocationSettings {
        return try await request(endpoint: "/settings/location")
    }

    func updateLocationSettings(prefecture: String, city: String, radius: Int) async throws -> LocationSettings {
        return try await request(
            endpoint: "/settings/location",
            method: "PUT",
            body: [
                "prefecture": prefecture,
                "city": city,
                "search_radius_km": radius
            ]
        )
    }

    func getMutedEmployers() async throws -> [MutedEmployer] {
        return try await request(endpoint: "/settings/muted-employers")
    }

    func muteEmployer(employerId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/settings/muted-employers/\(employerId)",
            method: "POST"
        )
    }

    func unmuteEmployer(employerId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/settings/muted-employers/\(employerId)",
            method: "DELETE"
        )
    }
}

// MARK: - Timesheet Adjustments

extension APIClient {
    func requestTimesheetAdjustment(
        applicationId: String,
        requestedCheckIn: String?,
        requestedCheckOut: String?,
        reason: String
    ) async throws -> SimpleResponse {
        var body: [String: Any] = ["reason": reason]
        if let checkIn = requestedCheckIn { body["requested_check_in"] = checkIn }
        if let checkOut = requestedCheckOut { body["requested_check_out"] = checkOut }

        return try await request(
            endpoint: "/timesheet/\(applicationId)/adjustment-request",
            method: "POST",
            body: body
        )
    }

    func getMyTimesheetAdjustments() async throws -> [TimesheetAdjustment] {
        return try await request(endpoint: "/timesheet/adjustment-requests")
    }
}

// MARK: - Admin Models

struct AdminQualification: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String?
    let userEmail: String?
    let qualificationName: String
    let qualificationType: String?
    let obtainedDate: String?
    let qualificationImage: String?
    let status: String
    let rejectionReason: String?
    let submittedAt: String?
    let reviewedAt: String?

    var statusDisplay: String {
        switch status {
        case "pending": return "確認中"
        case "approved": return "承認済"
        case "rejected": return "再提出要"
        default: return status
        }
    }
}

struct AdminBannerSlot: Codable, Identifiable {
    let id: String
    let imageUrl: String?
    let linkUrl: String
    let description: String?
    let expiresAt: String?
    let orderIndex: Int?
    let isActive: Bool?
}

struct AdminAdSettings: Codable {
    let bannerPriceMonthly: Int?
    let promotionPriceDaily: Int?
}

// MARK: - User Settings Models

struct NotificationSettings: Codable {
    var jobMatches: Bool
    var applicationUpdates: Bool
    var chatMessages: Bool
    var reminders: Bool
    var marketing: Bool
}

struct EmailSettings: Codable {
    var weeklyDigest: Bool
    var applicationAlerts: Bool
    var paymentReceipts: Bool
    var promotions: Bool
}

struct LocationSettings: Codable {
    var prefecture: String
    var city: String
    var searchRadiusKm: Int
}

struct MutedEmployer: Codable, Identifiable {
    let id: String
    let employerId: String
    let employerName: String
    let mutedAt: String
}

struct TimesheetAdjustment: Codable, Identifiable {
    let id: String
    let applicationId: String
    let jobTitle: String
    let originalCheckIn: String
    let originalCheckOut: String
    let requestedCheckIn: String?
    let requestedCheckOut: String?
    let reason: String
    let status: String
    let requestedAt: String
    let reviewedAt: String?
}

// MARK: - Admin Mass Notifications

extension APIClient {
    func sendMassNotification(
        title: String,
        message: String,
        targetUserType: String?,
        targetUserIds: [String]?
    ) async throws -> MassNotificationResponse {
        var body: [String: Any] = [
            "title": title,
            "message": message
        ]
        if let userType = targetUserType {
            body["target_user_type"] = userType
        }
        if let userIds = targetUserIds {
            body["target_user_ids"] = userIds
        }

        return try await request(
            endpoint: "/admin/notifications/send",
            method: "POST",
            body: body
        )
    }

    func getAdminNotificationHistory() async throws -> [AdminNotificationRecord] {
        return try await request(endpoint: "/admin/notifications/history")
    }
}

// MARK: - Admin Data Export

extension APIClient {
    func exportUsersData(format: String = "csv") async throws -> DataExportResponse {
        return try await request(
            endpoint: "/admin/export/users?format=\(format)"
        )
    }

    func exportJobsData(format: String = "csv") async throws -> DataExportResponse {
        return try await request(
            endpoint: "/admin/export/jobs?format=\(format)"
        )
    }

    func exportTransactionsData(
        startDate: String?,
        endDate: String?,
        format: String = "csv"
    ) async throws -> DataExportResponse {
        var endpoint = "/admin/export/transactions?format=\(format)"
        if let start = startDate {
            endpoint += "&start_date=\(start)"
        }
        if let end = endDate {
            endpoint += "&end_date=\(end)"
        }
        return try await request(endpoint: endpoint)
    }
}

// MARK: - Admin Analytics

extension APIClient {
    func getAdminAnalytics(period: String = "month") async throws -> AdminAnalytics {
        return try await request(endpoint: "/admin/analytics?period=\(period)")
    }

    func getAdminRevenueStats(period: String = "month") async throws -> AdminRevenueStats {
        return try await request(endpoint: "/admin/analytics/revenue?period=\(period)")
    }

    func getAdminUserGrowth(period: String = "month") async throws -> AdminUserGrowth {
        return try await request(endpoint: "/admin/analytics/user-growth?period=\(period)")
    }
}

// MARK: - Admin Wallet

extension APIClient {
    func getAdminWallet() async throws -> Wallet {
        return try await request(endpoint: "/admin/wallet")
    }

    func getAdminTransactions() async throws -> [Transaction] {
        let response: TransactionsResponse = try await request(endpoint: "/admin/wallet/transactions")
        return response.data
    }

    func getAdminBankAccounts() async throws -> [BankAccount] {
        let response: BankAccountsResponse = try await request(endpoint: "/admin/wallet/bank-accounts")
        return response.data
    }

    func addAdminBankAccount(
        bankName: String,
        bankCode: String,
        branchName: String,
        branchCode: String,
        accountType: String,
        accountNumber: String,
        accountHolderName: String
    ) async throws -> BankAccount {
        return try await request(
            endpoint: "/admin/wallet/bank-accounts",
            method: "POST",
            body: [
                "bank_name": bankName,
                "bank_code": bankCode,
                "branch_name": branchName,
                "branch_code": branchCode,
                "account_type": accountType,
                "account_number": accountNumber,
                "account_holder_name": accountHolderName
            ]
        )
    }

    func deleteAdminBankAccount(accountId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/wallet/bank-accounts/\(accountId)",
            method: "DELETE"
        )
    }

    func requestAdminWithdrawal(bankAccountId: String, amount: Int) async throws -> WithdrawalRequest {
        return try await request(
            endpoint: "/admin/wallet/withdrawal-request",
            method: "POST",
            body: [
                "bank_account_id": bankAccountId,
                "amount": amount
            ]
        )
    }

    func getAdminWithdrawalHistory() async throws -> [WithdrawalRequest] {
        return try await request(endpoint: "/admin/wallet/withdrawal-requests")
    }
}

// MARK: - Admin Category Management

extension APIClient {
    func getAdminCategories() async throws -> [AdminCategory] {
        return try await request(endpoint: "/admin/categories")
    }

    func createAdminCategory(name: String, label: String, description: String, icon: String, displayOrder: Int) async throws -> SimpleResponse {
        return try await request(endpoint: "/admin/categories", method: "POST", body: [
            "name": name, "label": label, "description": description, "icon": icon, "display_order": displayOrder
        ] as [String: Any])
    }

    func updateAdminCategory(categoryId: String, name: String, label: String, description: String, icon: String, displayOrder: Int) async throws -> SimpleResponse {
        return try await request(endpoint: "/admin/categories/\(categoryId)", method: "PUT", body: [
            "name": name, "label": label, "description": description, "icon": icon, "display_order": displayOrder
        ] as [String: Any])
    }

    func deleteAdminCategory(categoryId: String) async throws -> SimpleResponse {
        return try await request(endpoint: "/admin/categories/\(categoryId)", method: "DELETE")
    }
}

// MARK: - Admin Reports Management

extension APIClient {
    func getAdminReports(status: String? = nil) async throws -> [AdminReport] {
        var endpoint = "/admin/reports"
        if let s = status { endpoint += "?status=\(s)" }
        return try await request(endpoint: endpoint)
    }

    func updateAdminReport(reportId: String, status: String, adminNote: String?) async throws -> SimpleResponse {
        var body: [String: Any] = ["status": status]
        if let note = adminNote { body["admin_note"] = note }
        return try await request(endpoint: "/admin/reports/\(reportId)", method: "PUT", body: body)
    }

    func getAdminReportStats() async throws -> AdminReportStats {
        return try await request(endpoint: "/admin/reports/stats")
    }
}

// MARK: - Admin CMS Content

extension APIClient {
    func getAdminContent(key: String) async throws -> AdminContent {
        return try await request(endpoint: "/admin/content/\(key)")
    }

    func updateAdminContent(key: String, title: String, content: String) async throws -> SimpleResponse {
        return try await request(endpoint: "/admin/content/\(key)", method: "PUT", body: [
            "title": title, "content": content, "content_type": "page"
        ])
    }
}

// MARK: - Admin API Keys

extension APIClient {
    func getAdminAPIKeys() async throws -> [AdminAPIKey] {
        return try await request(endpoint: "/admin/api-keys")
    }

    func getAdminGlobalAPIKeys() async throws -> AdminGlobalAPIKeys {
        return try await request(endpoint: "/admin/api-keys/global")
    }

    func updateAdminGlobalAPIKeys(keys: [String: String]) async throws -> SimpleResponse {
        return try await request(endpoint: "/admin/api-keys/global", method: "PUT", body: keys)
    }

    func createAdminAPIKey(name: String, description: String, permissions: [String]) async throws -> SimpleResponse {
        return try await request(endpoint: "/admin/api-keys", method: "POST", body: [
            "name": name, "description": description, "permissions": permissions
        ] as [String: Any])
    }

    func deleteAdminAPIKey(keyId: String) async throws -> SimpleResponse {
        return try await request(endpoint: "/admin/api-keys/\(keyId)", method: "DELETE")
    }
}

// MARK: - Admin Access Logs

extension APIClient {
    func getAdminAccessLogs() async throws -> [AdminAccessLog] {
        return try await request(endpoint: "/admin/access-logs")
    }
}

// MARK: - Admin Models (Additional)

struct AdminCategory: Codable, Identifiable {
    let id: String
    let name: String?
    let label: String?
    let description: String?
    let icon: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, label, description, icon
        case displayOrder = "display_order"
        case isActive = "is_active"
    }
}

struct AdminReport: Codable, Identifiable {
    let id: String
    let reporterId: String?
    let reportedUserId: String?
    let reportedJobId: String?
    let type: String?
    let reason: String?
    let description: String?
    let status: String?
    let adminNote: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case reportedJobId = "reported_job_id"
        case type, reason, description, status
        case adminNote = "admin_note"
        case createdAt = "created_at"
    }

    var statusDisplay: String {
        switch status {
        case "pending": return "対応待ち"
        case "in_progress": return "対応中"
        case "resolved": return "解決済み"
        case "rejected": return "却下"
        default: return status ?? "不明"
        }
    }

    var statusColor: String {
        switch status {
        case "pending": return "orange"
        case "in_progress": return "blue"
        case "resolved": return "green"
        case "rejected": return "gray"
        default: return "gray"
        }
    }
}

struct AdminReportStats: Codable {
    let pending: Int
    let inProgress: Int?
    let resolved: Int
    let rejected: Int?
    let total: Int

    enum CodingKeys: String, CodingKey {
        case pending, resolved, rejected, total
        case inProgress = "in_progress"
    }
}

struct AdminContent: Codable {
    let key: String?
    let title: String?
    let content: String?
    let contentType: String?

    enum CodingKeys: String, CodingKey {
        case key, title, content
        case contentType = "content_type"
    }
}

struct AdminAPIKey: Codable, Identifiable {
    let id: String
    let name: String?
    let description: String?
    let permissions: [String]?
    let key: String?
    let isActive: Bool?
    let usageCount: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, permissions, key
        case isActive = "is_active"
        case usageCount = "usage_count"
        case createdAt = "created_at"
    }
}

struct AdminGlobalAPIKeys: Codable {
    let googleMapsApiKey: String?
    let stripePk: String?
    let env: String?

    enum CodingKeys: String, CodingKey {
        case googleMapsApiKey = "google_maps_api_key"
        case stripePk = "stripe_publishable_key"
        case env
    }
}

struct AdminAccessLog: Codable, Identifiable {
    var id: String { "\(timestamp ?? "")-\(action ?? "")" }
    let adminId: String?
    let adminName: String?
    let action: String?
    let timestamp: String?
    let ipAddress: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case adminId = "admin_id"
        case adminName = "admin_name"
        case action, timestamp
        case ipAddress = "ip_address"
        case status
    }
}

// MARK: - Employer Plan Management

extension APIClient {
    func getEmployerPlan() async throws -> EmployerPlanInfo {
        return try await request(endpoint: "/employer/plan")
    }

    func upgradeEmployerPlan(planId: String, paymentMethodId: String?) async throws -> EmployerPlanInfo {
        var body: [String: Any] = ["plan_id": planId]
        if let pmId = paymentMethodId {
            body["payment_method_id"] = pmId
        }
        return try await request(
            endpoint: "/employer/plan/upgrade",
            method: "POST",
            body: body
        )
    }

    func cancelEmployerPlan() async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/plan/cancel",
            method: "POST"
        )
    }
}

// MARK: - Health Check

extension APIClient {
    func getHealthStatus() async throws -> HealthStatus {
        return try await request(endpoint: "/health", requiresAuth: false)
    }
}

// MARK: - Additional Models

struct MassNotificationResponse: Codable {
    let ok: Bool
    let sentCount: Int
    let message: String?
}

struct AdminNotificationRecord: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let targetUserType: String?
    let sentCount: Int
    let sentAt: String
    let sentBy: String?
}

struct DataExportResponse: Codable {
    let ok: Bool
    let downloadUrl: String?
    let recordCount: Int
    let format: String
}

struct AdminAnalytics: Codable {
    let totalUsers: Int
    let totalJobs: Int
    let totalApplications: Int
    let totalRevenue: Int
    let activeUsers: Int
    let completedJobs: Int
    let averageRating: Double?
    let period: String
}

struct AdminRevenueStats: Codable {
    let totalRevenue: Int
    let platformFees: Int
    let payoutTotal: Int
    let pendingPayouts: Int
    let dailyBreakdown: [DailyRevenue]
}

struct DailyRevenue: Codable {
    let date: String
    let amount: Int
    let fees: Int
}

struct AdminUserGrowth: Codable {
    let totalUsers: Int
    let newUsersThisPeriod: Int
    let jobSeekerCount: Int
    let employerCount: Int
    let dailySignups: [DailySignup]
}

struct DailySignup: Codable {
    let date: String
    let count: Int
    let jobSeekers: Int
    let employers: Int
}

struct EmployerPlanInfo: Codable {
    let planId: String
    let planName: String
    let isActive: Bool
    let expiresAt: String?
    let features: [String]
    let monthlyPrice: Int?
    let maxJobPostings: Int?
    let maxApplicationsPerJob: Int?
}

struct HealthStatus: Codable {
    let status: String
    let version: String?
    let database: String?
    let timestamp: String?
}

// MARK: - Tax Documents

extension APIClient {
    func getTaxDocuments() async throws -> [TaxDocument] {
        return try await request(endpoint: "/tax-documents")
    }

    func downloadTaxDocument(documentId: String) async throws -> DataExportResponse {
        return try await request(endpoint: "/tax-documents/\(documentId)/download")
    }
}

struct TaxDocument: Codable, Identifiable {
    let id: String
    let year: Int
    let totalEarnings: Int
    let totalWithholding: Int
    let documentUrl: String?
    let issuedAt: String
}

// MARK: - Upcoming Work

extension APIClient {
    func getUpcomingWork() async throws -> [UpcomingWorkItem] {
        return try await request(endpoint: "/work/upcoming")
    }

    func checkIn(applicationId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/work/\(applicationId)/check-in",
            method: "POST"
        )
    }

    func checkOut(applicationId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/work/\(applicationId)/check-out",
            method: "POST"
        )
    }
}

struct UpcomingWorkItem: Codable, Identifiable {
    let id: String
    let applicationId: String
    let jobId: String
    let jobTitle: String
    let employerName: String
    let workDate: String
    let startTime: String
    let endTime: String
    let location: String
    let status: String
    let checkInTime: String?
    let checkOutTime: String?
}

// MARK: - Bug Report / Feedback

extension APIClient {
    func submitBugReport(
        category: String,
        title: String,
        description: String,
        deviceInfo: String
    ) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/feedback",
            method: "POST",
            body: [
                "category": category,
                "title": title,
                "description": description,
                "device_info": deviceInfo
            ]
        )
    }

    func getFeedbackHistory() async throws -> [FeedbackItem] {
        return try await request(endpoint: "/feedback")
    }
}

struct FeedbackItem: Codable, Identifiable {
    let id: String
    let category: String
    let title: String
    let description: String
    let status: String
    let createdAt: String
    let response: String?
}

// MARK: - Account Deletion

extension APIClient {
    func deleteMyAccount() async throws -> SimpleResponse {
        return try await request(
            endpoint: "/auth/me",
            method: "DELETE"
        )
    }
}

// MARK: - Device Token Registration

extension APIClient {
    func registerDeviceToken(token: String, platform: String = "ios") async throws -> SimpleResponse {
        return try await request(
            endpoint: "/auth/device-token",
            method: "POST",
            body: ["token": token, "platform": platform]
        )
    }
}

// MARK: - Password Reset / Change

extension APIClient {
    func requestPasswordReset(email: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/auth/password-reset",
            method: "POST",
            body: ["email": email],
            requiresAuth: false
        )
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/auth/change-password",
            method: "POST",
            body: [
                "current_password": currentPassword,
                "new_password": newPassword
            ]
        )
    }
}

// MARK: - Email Verification

extension APIClient {
    func resendVerificationEmail() async throws -> SimpleResponse {
        return try await request(
            endpoint: "/auth/resend-verification",
            method: "POST"
        )
    }
}

// MARK: - Distance Search

extension APIClient {
    func searchJobsByDistance(
        latitude: Double,
        longitude: Double,
        radiusKm: Int = 10,
        category: String? = nil
    ) async throws -> [Job] {
        var endpoint = "/jobs/search/nearby?lat=\(latitude)&lng=\(longitude)&radius=\(radiusKm)"
        if let cat = category {
            endpoint += "&category=\(cat.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        return try await request(endpoint: endpoint)
    }
}
