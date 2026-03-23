import Foundation

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case networkError(Error)
    case offline
    case rateLimited
    case maintenance
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURLです"
        case .noData: return "データがありません"
        case .decodingError: return "データの読み込みに失敗しました。アプリを最新版にアップデートしてください。"
        case .serverError(let message): return message
        case .unauthorized: return "ログインの有効期限が切れました。再度ログインしてください。"
        case .networkError: return "通信エラーが発生しました。電波状況を確認して、もう一度お試しください。"
        case .offline: return "インターネットに接続されていません。Wi-Fiまたはモバイルデータ通信をオンにしてください。"
        case .rateLimited: return "リクエストが集中しています。1分ほどお待ちいただき、再度お試しください。"
        case .maintenance: return "ただいまメンテナンス中です。終了までしばらくお待ちください。"
        case .timeout: return "サーバーからの応答がありません。しばらくしてからもう一度お試しください。"
        }
    }

    /// ユーザーが取れるアクション
    var recoverySuggestion: String? {
        switch self {
        case .unauthorized: return "ログイン画面に戻ります"
        case .networkError, .offline: return "接続を確認してリトライしてください"
        case .rateLimited: return "しばらくお待ちください"
        case .timeout: return "リトライボタンを押してください"
        case .decodingError: return "App Storeで最新版を確認してください"
        default: return nil
        }
    }

    /// リトライ可能かどうか
    var isRetryable: Bool {
        switch self {
        case .networkError, .offline, .rateLimited, .timeout, .serverError:
            return true
        case .invalidURL, .noData, .decodingError, .unauthorized, .maintenance:
            return false
        }
    }
}

class APIClient {
    static let shared = APIClient()

    private let baseURL: String = StripeConfig.apiBaseURL
    private let maxRetries = 2
    private let session: URLSession

    /// Cached auth token to avoid repeated Keychain reads (IPC overhead)
    private var _cachedToken: String?
    private var _tokenCacheTime: Date?

    private var token: String? {
        // Re-read from Keychain at most every 5 minutes
        if let cached = _cachedToken, let cacheTime = _tokenCacheTime,
           Date().timeIntervalSince(cacheTime) < 300 {
            return cached
        }
        let loaded = KeychainHelper.load(key: "auth_token")
        _cachedToken = loaded
        _tokenCacheTime = Date()
        return loaded
    }

    /// Call this when the token changes (login/logout) to invalidate cache
    func invalidateTokenCache() {
        _cachedToken = nil
        _tokenCacheTime = nil
    }

    /// Reusable decoder to avoid repeated allocation
    private let snakeCaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 15
        config.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        config.requestCachePolicy = .useProtocolCachePolicy
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
        requiresAuth: Bool = true,
        idempotencyKey: String? = nil
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

        if let idempotencyKey = idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        // べき等キー付きPOSTもリトライ安全とみなす
        let isSafeToRetry = method == "GET" || method == "HEAD" || idempotencyKey != nil
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
                    // Only force-logout for token validation endpoint (/auth/me)
                    // Other 401s may be from broken/mismatched backend, not invalid tokens
                    if endpoint == "/auth/me" {
                        notifyUnauthorized()
                    }
                    throw APIError.unauthorized
                }

                if httpResponse.statusCode == 429 {
                    if attempt < maxRetries {
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        let delay = UInt64(Double(retryAfter ?? "") ?? 3.0)
                        try await Task.sleep(nanoseconds: delay * 1_000_000_000)
                        continue
                    }
                    throw APIError.rateLimited
                }

                if httpResponse.statusCode == 503 {
                    throw APIError.maintenance
                }

                if httpResponse.statusCode >= 500 && isSafeToRetry && attempt < maxRetries {
                    lastError = APIError.serverError("サーバーエラー: \(httpResponse.statusCode)")
                    continue
                }

                if httpResponse.statusCode == 409 {
                    // 競合エラー（重複応募など）を専用メッセージで返す
                    if let errorResponse = try? snakeCaseDecoder.decode(ErrorResponse.self, from: data) {
                        throw APIError.serverError(errorResponse.detail)
                    }
                    throw APIError.serverError("この操作は既に処理されています")
                }

                if httpResponse.statusCode >= 400 {
                    if let errorResponse = try? snakeCaseDecoder.decode(ErrorResponse.self, from: data) {
                        throw APIError.serverError(errorResponse.detail)
                    }
                    throw APIError.serverError("サーバーエラー: \(httpResponse.statusCode)")
                }

                do {
                    return try snakeCaseDecoder.decode(T.self, from: data)
                } catch {
                    #if DEBUG
                    let preview = String(data: data.prefix(500), encoding: .utf8) ?? "(binary)"
                    print("[API] Decoding \(T.self) failed: \(error)\nResponse: \(preview)")
                    #endif
                    throw APIError.decodingError
                }
            } catch let error as APIError {
                if case .unauthorized = error { throw error }
                if case .maintenance = error { throw error }
                lastError = error
                if !isSafeToRetry || attempt >= maxRetries { throw error }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Check if truly offline at time of failure
                let isOffline = await !NetworkMonitor.shared.isConnected
                let apiError: APIError = isOffline ? .offline : .networkError(error)
                lastError = apiError
                if !isSafeToRetry || attempt >= maxRetries {
                    throw apiError
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
            // Don't force-logout from file upload 401s
            throw APIError.unauthorized
        }

        if httpResponse.statusCode == 503 {
            throw APIError.maintenance
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? snakeCaseDecoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.detail)
            }
            throw APIError.serverError("アップロードに失敗しました: \(httpResponse.statusCode)")
        }

        return try snakeCaseDecoder.decode(SimpleResponse.self, from: data)
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
        let cacheKey = "current_user"
        do {
            let user: User = try await request(endpoint: "/auth/me")
            CacheService.shared.save(user, forKey: cacheKey)
            return user
        } catch {
            if let cached = CacheService.shared.load(User.self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    // MARK: - Social Auth (Native SDK)

    func socialLoginGoogle(idToken: String, userType: String) async throws -> LoginResponse {
        return try await request(
            endpoint: "/auth/social/google",
            method: "POST",
            body: [
                "id_token": idToken,
                "user_type": userType
            ],
            requiresAuth: false
        )
    }

    func socialLoginLine(accessToken: String, idToken: String?, userType: String) async throws -> LoginResponse {
        var body: [String: Any] = [
            "access_token": accessToken,
            "user_type": userType
        ]
        if let idToken = idToken { body["id_token"] = idToken }

        return try await request(
            endpoint: "/auth/social/line",
            method: "POST",
            body: body,
            requiresAuth: false
        )
    }

    func socialLoginApple(identityToken: String, userType: String, name: String?, email: String?) async throws -> LoginResponse {
        var body: [String: Any] = [
            "identity_token": identityToken,
            "user_type": userType
        ]
        if let name = name { body["name"] = name }
        if let email = email { body["email"] = email }

        return try await request(
            endpoint: "/auth/social/apple",
            method: "POST",
            body: body,
            requiresAuth: false
        )
    }

    // MARK: - Phone (SMS) Authentication

    func sendPhoneOTP(phoneNumber: String) async throws -> GenericAPIResponse {
        return try await request(
            endpoint: "/auth/phone/send-otp",
            method: "POST",
            body: ["phone_number": phoneNumber],
            requiresAuth: false
        )
    }

    func verifyPhoneOTP(phoneNumber: String, code: String, userType: String) async throws -> LoginResponse {
        return try await request(
            endpoint: "/auth/phone/verify",
            method: "POST",
            body: [
                "phone_number": phoneNumber,
                "code": code,
                "user_type": userType
            ],
            requiresAuth: false
        )
    }

    func updateProfile(name: String?, phone: String?, bio: String?, prefecture: String?, city: String?, birthDate: String? = nil, gender: String? = nil) async throws -> User {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let phone = phone { body["phone"] = phone }
        if let bio = bio { body["bio"] = bio }
        if let prefecture = prefecture { body["prefecture"] = prefecture }
        if let city = city { body["city"] = city }
        if let birthDate = birthDate { body["birth_date"] = birthDate }
        if let gender = gender { body["gender"] = gender }

        let user: User = try await request(
            endpoint: "/auth/profile",
            method: "PUT",
            body: body
        )
        // Cache updated user locally for persistence
        CacheService.shared.save(user, forKey: "current_user")
        return user
    }

    func uploadProfileImage(imageData: Data) async throws -> SimpleResponse {
        let base64Image = "data:image/jpeg;base64," + imageData.base64EncodedString()
        return try await request(
            endpoint: "/auth/profile/image",
            method: "POST",
            body: ["image": base64Image]
        )
    }

    func uploadEmployerLogo(imageData: Data) async throws -> SimpleResponse {
        let base64Image = "data:image/jpeg;base64," + imageData.base64EncodedString()
        // Use employer profile PUT with logo_url field (no dedicated image endpoint)
        let _: EmployerProfile = try await request(
            endpoint: "/employer/profile",
            method: "PUT",
            body: ["logo_url": base64Image]
        )
        return SimpleResponse(ok: true, message: "ロゴを更新しました")
    }

    // MARK: - Jobs Endpoints

    func getJobs(search: String? = nil, prefecture: String? = nil, city: String? = nil, category: String? = nil, page: Int = 1, limit: Int = 20) async throws -> [Job] {
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
        queryParams.append("page=\(page)")
        queryParams.append("limit=\(limit)")

        let endpoint = "/search/jobs-enhanced?" + queryParams.joined(separator: "&")

        // For the default first page with no filters, use cache
        let isDefaultQuery = search == nil && prefecture == nil && city == nil && category == nil && page == 1
        let cacheKey = "jobs_page\(page)"

        do {
            let jobs: [Job] = try await request(endpoint: endpoint, requiresAuth: false)
            if isDefaultQuery {
                CacheService.shared.save(jobs, forKey: cacheKey)
            }
            return jobs
        } catch {
            // Fallback to cache when offline
            if isDefaultQuery, let cached = CacheService.shared.load([Job].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func getJobDetail(jobId: String) async throws -> Job {
        return try await request(endpoint: "/jobs/\(jobId)", requiresAuth: false)
    }

    func applyForJob(jobId: String, message: String?) async throws -> ApplicationResponse {
        var body: [String: Any] = [:]
        if let message = message {
            body["message"] = message
        }

        let endpoint = "/jobs/\(jobId)/apply"
        let idempotencyKey = "apply-\(jobId)-\(token ?? "anon")"

        do {
            let result: ApplicationResponse = try await request(
                endpoint: endpoint,
                method: "POST",
                body: body,
                idempotencyKey: idempotencyKey
            )
            CacheService.shared.remove(forKey: "my_applications")
            return result
        } catch let error as APIError {
            // オフライン時はキューに保存して後で再送
            if case .offline = error {
                if let bodyData = try? JSONSerialization.data(withJSONObject: body) {
                    await OfflineQueueManager.shared.enqueue(
                        endpoint: endpoint,
                        method: "POST",
                        body: bodyData
                    )
                }
            }
            throw error
        }
    }

    func getCategories() async throws -> [JobCategory] {
        do {
            let categories: [JobCategory] = try await request(endpoint: "/categories", requiresAuth: false)
            CacheService.shared.save(categories, forKey: "categories")
            return categories
        } catch {
            if let cached = CacheService.shared.load([JobCategory].self, forKey: "categories", ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    // MARK: - Favorite Jobs

    func getFavoriteJobs() async throws -> [Job] {
        let cacheKey = "favorite_jobs"
        do {
            let jobs: [Job] = try await request(endpoint: "/favorites/jobs")
            CacheService.shared.save(jobs, forKey: cacheKey)
            return jobs
        } catch {
            if let cached = CacheService.shared.load([Job].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func addFavoriteJob(jobId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/favorites/jobs/\(jobId)",
            method: "POST"
        )
        CacheService.shared.remove(forKey: "favorite_jobs")
        return result
    }

    func removeFavoriteJob(jobId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/favorites/jobs/\(jobId)",
            method: "DELETE"
        )
        CacheService.shared.remove(forKey: "favorite_jobs")
        return result
    }

    func getFavoriteEmployers() async throws -> [EmployerProfile] {
        let cacheKey = "favorite_employers"
        do {
            let employers: [EmployerProfile] = try await request(endpoint: "/favorites/employers")
            CacheService.shared.save(employers, forKey: cacheKey)
            return employers
        } catch {
            if let cached = CacheService.shared.load([EmployerProfile].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func addFavoriteEmployer(employerId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/favorites/employers/\(employerId)",
            method: "POST"
        )
        CacheService.shared.remove(forKey: "favorite_employers")
        return result
    }

    func removeFavoriteEmployer(employerId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/favorites/employers/\(employerId)",
            method: "DELETE"
        )
        CacheService.shared.remove(forKey: "favorite_employers")
        return result
    }

    // MARK: - Wallet Endpoints

    func getWallet() async throws -> Wallet {
        let cacheKey = "wallet"
        do {
            let wallet: Wallet = try await request(endpoint: "/wallet")
            CacheService.shared.save(wallet, forKey: cacheKey)
            return wallet
        } catch {
            if let cached = CacheService.shared.load(Wallet.self, forKey: cacheKey, ttl: 60 * 60) {
                return cached
            }
            throw error
        }
    }

    func getTransactions() async throws -> [Transaction] {
        let cacheKey = "transactions"
        do {
            let response: TransactionsResponse = try await request(endpoint: "/wallet/transactions")
            CacheService.shared.save(response.data, forKey: cacheKey)
            return response.data
        } catch {
            if let cached = CacheService.shared.load([Transaction].self, forKey: cacheKey, ttl: 60 * 60) {
                return cached
            }
            throw error
        }
    }

    // MARK: - Bank Account Endpoints

    func getBankAccounts() async throws -> [BankAccount] {
        let cacheKey = "bank_accounts"
        do {
            let response: BankAccountsResponse = try await request(endpoint: "/wallet/bank-accounts")
            CacheService.shared.save(response.data, forKey: cacheKey)
            return response.data
        } catch {
            if let cached = CacheService.shared.load([BankAccount].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func addBankAccount(
        bankName: String,
        branchName: String,
        accountType: String,
        accountNumber: String,
        accountHolderName: String
    ) async throws -> BankAccount {
        let account: BankAccount = try await request(
            endpoint: "/wallet/bank-accounts",
            method: "POST",
            body: [
                "bank_name": bankName,
                "branch_name": branchName,
                "account_type": accountType,
                "account_number": accountNumber,
                "account_holder_name": accountHolderName
            ]
        )
        CacheService.shared.remove(forKey: "bank_accounts")
        return account
    }

    func deleteBankAccount(accountId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/wallet/bank-accounts/\(accountId)",
            method: "DELETE"
        )
        CacheService.shared.remove(forKey: "bank_accounts")
        return result
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
        var body: [String: Any] = [
            "document_type": documentType,
            "front_image": "data:image/jpeg;base64," + frontImageData.base64EncodedString()
        ]
        if let backData = backImageData {
            body["back_image"] = "data:image/jpeg;base64," + backData.base64EncodedString()
        }

        return try await request(
            endpoint: "/identity/submit",
            method: "POST",
            body: body
        )
    }

    // MARK: - Applications Endpoints

    func getMyApplications() async throws -> [Application] {
        let cacheKey = "my_applications"
        do {
            let apps: [Application] = try await request(endpoint: "/matching-applications/my")
            CacheService.shared.save(apps, forKey: cacheKey)
            return apps
        } catch {
            if let cached = CacheService.shared.load([Application].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func cancelApplication(applicationId: String) async throws -> SimpleResponse {
        let endpoint = "/matching-applications/\(applicationId)/cancel"
        let idempotencyKey = "cancel-\(applicationId)"

        do {
            let result: SimpleResponse = try await request(
                endpoint: endpoint,
                method: "POST",
                idempotencyKey: idempotencyKey
            )
            CacheService.shared.remove(forKey: "my_applications")
            return result
        } catch let error as APIError {
            if case .offline = error {
                await OfflineQueueManager.shared.enqueue(
                    endpoint: endpoint,
                    method: "POST"
                )
            }
            throw error
        }
    }

    // MARK: - Work History Endpoints

    func getWorkHistory() async throws -> [WorkHistory] {
        let cacheKey = "work_history"
        do {
            let history: [WorkHistory] = try await request(endpoint: "/mypage/work-history")
            CacheService.shared.save(history, forKey: cacheKey)
            return history
        } catch {
            if let cached = CacheService.shared.load([WorkHistory].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func getWorkCertificates() async throws -> [WorkCertificate] {
        let response: WorkCertificateListResponse = try await request(endpoint: "/mypage/work-certificates")
        return response.certificates
    }

    func downloadWorkCertificatePDF(certificateId: String) async throws -> Data {
        let baseURL = StripeConfig.apiBaseURL
        guard let url = URL(string: "\(baseURL)/mypage/work-certificates/\(certificateId)/pdf") else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        if let token = KeychainHelper.load(key: "auth_token") {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError("PDFのダウンロードに失敗しました")
        }
        return data
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

    // QR Code Check-in with location (idempotency key for duplicate prevention)
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
            body: body,
            idempotencyKey: "checkin-\(token)-\(deviceTime)"
        )
    }

    // QR Code Check-out with location
    func checkOutWithQR(token: String, latitude: Double?, longitude: Double?, deviceTime: String, breakMinutes: Int? = nil) async throws -> CheckOutResponse {
        var body: [String: Any] = [
            "token": token,
            "device_time": deviceTime
        ]
        if let lat = latitude { body["latitude"] = lat }
        if let lng = longitude { body["longitude"] = lng }
        if let breakMin = breakMinutes { body["break_minutes"] = breakMin }

        return try await request(
            endpoint: "/attendance/qr-check-out",
            method: "POST",
            body: body,
            idempotencyKey: "checkout-qr-\(token)-\(deviceTime)"
        )
    }

    // Check-out with location (idempotency key for duplicate prevention)
    func checkOutWithLocation(applicationId: String, latitude: Double?, longitude: Double?, deviceTime: String, breakMinutes: Int? = nil) async throws -> CheckOutResponse {
        var body: [String: Any] = [
            "device_time": deviceTime
        ]
        if let lat = latitude { body["latitude"] = lat }
        if let lng = longitude { body["longitude"] = lng }
        if let breakMin = breakMinutes { body["break_minutes"] = breakMin }

        return try await request(
            endpoint: "/attendance/\(applicationId)/check-out",
            method: "POST",
            body: body,
            idempotencyKey: "checkout-\(applicationId)-\(deviceTime)"
        )
    }

    // MARK: - Break Tracking

    func startBreak(applicationId: String) async throws -> GenericAPIResponse {
        return try await request(
            endpoint: "/attendance/\(applicationId)/break/start",
            method: "POST"
        )
    }

    func endBreak(applicationId: String) async throws -> GenericAPIResponse {
        return try await request(
            endpoint: "/attendance/\(applicationId)/break/end",
            method: "POST"
        )
    }

    // MARK: - Instant Payment (Checkout → Charge → Wallet)

    func requestInstantPayment(applicationId: String) async throws -> InstantPaymentResponse {
        return try await request(
            endpoint: "/payments/instant/\(applicationId)",
            method: "POST"
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
            endpoint: "/chat/rooms/\(roomId)/send",
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
            endpoint: "/chat/rooms/\(roomId)/send",
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
            endpoint: "/chat/rooms/\(roomId)/send",
            method: "POST",
            body: body
        )
    }

    // MARK: - Employer Endpoints

    func getEmployerStats() async throws -> EmployerStats {
        let cacheKey = "employer_stats"
        do {
            let stats: EmployerStats = try await request(endpoint: "/employer/stats")
            CacheService.shared.save(stats, forKey: cacheKey)
            return stats
        } catch {
            if let cached = CacheService.shared.load(EmployerStats.self, forKey: cacheKey, ttl: 60 * 60) {
                return cached
            }
            throw error
        }
    }

    func getEmployerProfile() async throws -> EmployerProfile {
        let cacheKey = "employer_profile"
        do {
            let profile: EmployerProfile = try await request(endpoint: "/employer/profile")
            CacheService.shared.save(profile, forKey: cacheKey)
            return profile
        } catch {
            if let cached = CacheService.shared.load(EmployerProfile.self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func getPublicEmployerProfile(employerId: String) async throws -> EmployerProfile {
        return try await request(endpoint: "/employers/\(employerId)/profile")
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
        if let businessName = businessName { body["company_name"] = businessName }
        if let description = description { body["description"] = description }
        if let prefecture = prefecture { body["prefecture"] = prefecture }
        if let city = city { body["city"] = city }
        if let address = address { body["address"] = address }
        if let contactPhone = contactPhone { body["phone"] = contactPhone }
        if let contactEmail = contactEmail { body["email"] = contactEmail }

        let profile: EmployerProfile = try await request(
            endpoint: "/employer/profile",
            method: "PUT",
            body: body
        )
        CacheService.shared.save(profile, forKey: "employer_profile")
        return profile
    }

    func getEmployerJobs() async throws -> [Job] {
        let cacheKey = "employer_jobs"
        do {
            let jobs: [Job] = try await request(endpoint: "/employer/jobs")
            CacheService.shared.save(jobs, forKey: cacheKey)
            return jobs
        } catch {
            if let cached = CacheService.shared.load([Job].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func invalidateEmployerJobsCache() {
        CacheService.shared.remove(forKey: "employer_jobs")
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
        workDateEnd: String? = nil,
        startTime: String,
        endTime: String,
        requiredPeople: Int,
        categories: [String]?,
        requirements: String?,
        benefits: String?,
        paymentType: String? = nil
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
        if let workDateEnd = workDateEnd { body["work_date_end"] = workDateEnd }
        if let categories = categories { body["categories"] = categories }
        if let requirements = requirements { body["requirements"] = requirements }
        if let benefits = benefits { body["benefits"] = benefits }
        if let paymentType = paymentType { body["payment_type"] = paymentType }

        let job: Job = try await request(
            endpoint: "/employer/jobs",
            method: "POST",
            body: body
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return job
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
        workDateEnd: String? = nil,
        startTime: String,
        endTime: String,
        requiredPeople: Int,
        categories: [String]?,
        requirements: String?,
        benefits: String?,
        images: [String],
        thumbnailIndex: Int,
        paymentType: String? = nil,
        videoBase64: String? = nil
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
        if let workDateEnd = workDateEnd { body["work_date_end"] = workDateEnd }
        if let categories = categories { body["categories"] = categories }
        if let requirements = requirements { body["requirements"] = requirements }
        if let benefits = benefits { body["benefits"] = benefits }
        if let paymentType = paymentType { body["payment_type"] = paymentType }

        // Add images as base64
        if !images.isEmpty {
            body["images"] = images
            body["thumbnail_index"] = thumbnailIndex
        }

        // Add video as base64
        if let videoBase64 = videoBase64 {
            body["video"] = videoBase64
        }

        let job: Job = try await request(
            endpoint: "/employer/jobs",
            method: "POST",
            body: body
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return job
    }

    func updateJob(jobId: String, updates: [String: Any]) async throws -> Job {
        let job: Job = try await request(
            endpoint: "/employer/jobs/\(jobId)",
            method: "PUT",
            body: updates
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return job
    }

    func deleteJob(jobId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/employer/jobs/\(jobId)",
            method: "DELETE"
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return result
    }

    func publishJob(jobId: String) async throws -> Job {
        let job: Job = try await request(
            endpoint: "/employer/jobs/\(jobId)/publish",
            method: "POST"
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return job
    }

    func closeJob(jobId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/employer/jobs/\(jobId)/close",
            method: "PUT"
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return result
    }

    func cancelShift(jobId: String, reason: String, notifyWorkers: Bool) async throws -> SimpleResponse {
        let body: [String: Any] = [
            "reason": reason,
            "notify_workers": notifyWorkers
        ]
        let result: SimpleResponse = try await request(
            endpoint: "/employer/jobs/\(jobId)/cancel",
            method: "POST",
            body: body
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return result
    }

    func repostJob(jobId: String, workDate: String?, hourlyRate: Int?, requiredPeople: Int?) async throws -> Job {
        var body: [String: Any] = [:]
        if let workDate = workDate { body["work_date"] = workDate }
        if let hourlyRate = hourlyRate { body["hourly_rate"] = hourlyRate }
        if let requiredPeople = requiredPeople { body["required_people"] = requiredPeople }
        let job: Job = try await request(
            endpoint: "/employer/jobs/\(jobId)/repost",
            method: "POST",
            body: body
        )
        invalidateEmployerJobsCache()
        CacheService.shared.remove(forKey: "jobs_page1")
        return job
    }

    func getEmployerApplications() async throws -> [Application] {
        let cacheKey = "employer_applications"
        do {
            let apps: [Application] = try await request(endpoint: "/employer/applications")
            CacheService.shared.save(apps, forKey: cacheKey)
            return apps
        } catch {
            if let cached = CacheService.shared.load([Application].self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func approveApplication(applicationId: String) async throws -> Application {
        let result: Application = try await request(
            endpoint: "/employer/applications/\(applicationId)/approve",
            method: "POST",
            idempotencyKey: "approve-\(applicationId)"
        )
        CacheService.shared.remove(forKey: "employer_applications")
        return result
    }

    func rejectApplication(applicationId: String, reason: String?) async throws -> Application {
        var body: [String: Any] = [:]
        if let reason = reason { body["reason"] = reason }
        let result: Application = try await request(
            endpoint: "/employer/applications/\(applicationId)/reject",
            method: "POST",
            body: body,
            idempotencyKey: "reject-\(applicationId)"
        )
        CacheService.shared.remove(forKey: "employer_applications")
        return result
    }

    func reportNoShow(applicationId: String) async throws -> SimpleResponse {
        let result: SimpleResponse = try await request(
            endpoint: "/employer/applications/\(applicationId)/no-show",
            method: "POST",
            idempotencyKey: "noshow-\(applicationId)"
        )
        CacheService.shared.remove(forKey: "employer_applications")
        return result
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
            endpoint: "/payment/methods/add",
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

    // Manual payment for manual settlement jobs
    func submitManualPayment(
        timesheetId: String,
        basePay: Int,
        transportationFee: Int,
        overtimeMinutes: Int,
        overtimePay: Int,
        totalAmount: Int,
        paymentMethodId: String,
        idempotencyKey: String
    ) async throws -> ManualPaymentResponse {
        return try await request(
            endpoint: "/payment/manual",
            method: "POST",
            body: [
                "timesheet_id": timesheetId,
                "base_pay": basePay,
                "transportation_fee": transportationFee,
                "overtime_minutes": overtimeMinutes,
                "overtime_pay": overtimePay,
                "total_amount": totalAmount,
                "payment_method_id": paymentMethodId,
                "idempotency_key": idempotencyKey
            ]
        )
    }

    // MARK: - Platform Fee

    func getPlatformFeePercent() async throws -> PlatformFeeResponse {
        return try await request(endpoint: "/settings/platform-fee")
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

struct TimesheetData: Codable, Identifiable {
    let id: String
    let workerId: String?
    let jobId: String?
    let workerName: String
    let jobTitle: String
    let date: String
    let checkIn: String
    let checkOut: String
    let amount: Int
    let status: String
    let paymentType: String?
    let hourlyWage: Int?
    let scheduledHours: Double?
    let transportationFee: Int?
    let overtimeMinutes: Int?
    let overtimePay: Int?
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
        branchName: String,
        accountType: String,
        accountNumber: String,
        accountHolderName: String
    ) async throws -> BankAccount {
        return try await request(
            endpoint: "/admin/wallet/bank-accounts",
            method: "POST",
            body: [
                "bank_name": bankName,
                "branch_name": branchName,
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

    // MARK: - Admin Disputes

    func getAdminDisputes(status: String? = nil) async throws -> [Dispute] {
        var endpoint = "/admin/disputes"
        if let s = status { endpoint += "?status=\(s)" }
        return try await request(endpoint: endpoint)
    }

    func updateAdminDispute(disputeId: String, status: String, resolution: String?, adminNote: String?, resolvedAmount: Int?) async throws -> SimpleResponse {
        var body: [String: Any] = ["status": status]
        if let resolution = resolution { body["resolution"] = resolution }
        if let note = adminNote { body["admin_note"] = note }
        if let amount = resolvedAmount { body["resolved_amount"] = amount }
        return try await request(endpoint: "/admin/disputes/\(disputeId)", method: "PUT", body: body)
    }

    func escalateDispute(disputeId: String, note: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/admin/disputes/\(disputeId)/escalate",
            method: "POST",
            body: ["note": note]
        )
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

    func getAppSettings() async throws -> AppSettings {
        return try await request(endpoint: "/settings", requiresAuth: false)
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

struct AppSettings: Codable {
    let minimumAppVersion: String?
    let maintenanceMode: Bool?

    enum CodingKeys: String, CodingKey {
        case minimumAppVersion = "minimum_app_version"
        case maintenanceMode = "maintenance_mode"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimumAppVersion = try container.decodeIfPresent(String.self, forKey: .minimumAppVersion)
        maintenanceMode = try container.decodeIfPresent(Bool.self, forKey: .maintenanceMode)
    }
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
    let estimatedEndTime: String?
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

// MARK: - Worker Score & Penalties

extension APIClient {
    func getWorkerScore() async throws -> WorkerScore {
        let cacheKey = "worker_score"
        do {
            let score: WorkerScore = try await request(endpoint: "/worker/score")
            CacheService.shared.save(score, forKey: cacheKey)
            return score
        } catch {
            if let cached = CacheService.shared.load(WorkerScore.self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func getPenalties() async throws -> [Penalty] {
        return try await request(endpoint: "/worker/penalties")
    }

    func getProfileCompletion() async throws -> ProfileCompletion {
        return try await request(endpoint: "/worker/profile-completion")
    }

    func getMonthlySummary(month: String? = nil) async throws -> MonthlySummary {
        var endpoint = "/worker/monthly-summary"
        if let month = month { endpoint += "?month=\(month)" }
        let cacheKey = "monthly_summary_\(month ?? "current")"
        do {
            let summary: MonthlySummary = try await request(endpoint: endpoint)
            CacheService.shared.save(summary, forKey: cacheKey)
            return summary
        } catch {
            if let cached = CacheService.shared.load(MonthlySummary.self, forKey: cacheKey, ttl: 60 * 60 * 24) {
                return cached
            }
            throw error
        }
    }

    func getMonthlySummaries() async throws -> [MonthlySummary] {
        return try await request(endpoint: "/worker/monthly-summaries")
    }
}

// MARK: - Banners

extension APIClient {
    func getHomeBanners() async throws -> [HomeBanner] {
        return try await request(endpoint: "/banners", requiresAuth: false)
    }
}

// MARK: - Job Templates

extension APIClient {
    func getJobTemplates() async throws -> [JobTemplate] {
        return try await request(endpoint: "/employer/job-templates")
    }

    func saveJobTemplate(name: String, jobData: [String: Any]) async throws -> JobTemplate {
        var body = jobData
        body["name"] = name
        return try await request(
            endpoint: "/employer/job-templates",
            method: "POST",
            body: body
        )
    }

    func deleteJobTemplate(templateId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/job-templates/\(templateId)",
            method: "DELETE"
        )
    }

    func createJobFromTemplate(templateId: String, workDate: String, requiredPeople: Int?) async throws -> Job {
        var body: [String: Any] = ["work_date": workDate]
        if let people = requiredPeople { body["required_people"] = people }
        return try await request(
            endpoint: "/employer/job-templates/\(templateId)/create-job",
            method: "POST",
            body: body
        )
    }
}

// MARK: - Employer Timesheets (Bulk)

extension APIClient {
    func bulkApproveTimesheets(timesheetIds: [String]) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/timesheets/bulk-approve",
            method: "POST",
            body: ["timesheet_ids": timesheetIds]
        )
    }

    func getEmployerTimesheetsByJob(jobId: String) async throws -> [TimesheetData] {
        return try await request(endpoint: "/employer/jobs/\(jobId)/timesheets")
    }
}

// MARK: - Worker Re-invite

extension APIClient {
    func reinviteWorker(workerId: String, jobId: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/reinvite",
            method: "POST",
            body: ["worker_id": workerId, "job_id": jobId]
        )
    }

    func getReliableWorkers() async throws -> [ReliableWorker] {
        return try await request(endpoint: "/employer/reliable-workers")
    }
}

struct ReliableWorker: Codable, Identifiable {
    let id: String
    let name: String
    let completedJobs: Int
    let goodRate: Int
    let lastWorkedAt: String?
    let categories: [String]?
}

// MARK: - Bulk Message

extension APIClient {
    func sendBulkMessage(workerIds: [String], message: String, jobId: String?) async throws -> SimpleResponse {
        var body: [String: Any] = [
            "worker_ids": workerIds,
            "message": message
        ]
        if let jobId = jobId { body["job_id"] = jobId }
        return try await request(endpoint: "/employer/bulk-message", method: "POST", body: body)
    }

    func getJobWorkers(jobId: String?) async throws -> [JobWorker] {
        let endpoint = jobId.map { "/employer/jobs/\($0)/workers" } ?? "/employer/workers"
        return try await request(endpoint: endpoint)
    }
}

struct JobWorker: Codable, Identifiable {
    let id: String
    let name: String
    let profileImageUrl: String?
}

// MARK: - CSV Export

extension APIClient {
    func requestCSVExport(type: String, dateRange: String) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/employer/export/csv",
            method: "POST",
            body: ["type": type, "date_range": dateRange]
        )
    }
}

// MARK: - Saved Searches

extension APIClient {
    func getSavedSearches() async throws -> [SavedSearch] {
        return try await request(endpoint: "/saved-searches")
    }

    func deleteSavedSearch(searchId: String) async throws -> SimpleResponse {
        return try await request(endpoint: "/saved-searches/\(searchId)", method: "DELETE")
    }
}

// MARK: - Job Alerts

extension APIClient {
    func getJobAlerts() async throws -> JobAlertSettings {
        return try await request(endpoint: "/job-alerts")
    }

    func saveJobAlerts(_ settings: JobAlertSettings) async throws -> SimpleResponse {
        return try await request(
            endpoint: "/job-alerts",
            method: "PUT",
            body: [
                "enabled": settings.enabled,
                "keywords": settings.keywords,
                "min_hourly_wage": settings.minHourlyWage as Any,
                "preferred_areas": settings.preferredAreas,
                "preferred_categories": settings.preferredCategories
            ]
        )
    }
}

struct JobAlertSettings: Codable {
    var enabled: Bool
    var keywords: [String]
    var minHourlyWage: Int?
    var preferredAreas: [String]
    var preferredCategories: [String]
}
