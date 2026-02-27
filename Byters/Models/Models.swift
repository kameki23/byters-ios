import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let userType: String
    let phone: String?
    let profileImageUrl: String?
    let isIdentityVerified: Bool?
    let identityVerificationStatus: String?
    let emailVerified: Bool?
    let createdAt: String?
    let bio: String?
    let birthDate: String?
    let gender: String?
    let prefecture: String?
    let city: String?

    var displayName: String {
        name ?? email
    }

    var identityStatusDisplay: String {
        switch identityVerificationStatus {
        case "pending": return "審査中"
        case "approved": return "確認済み"
        case "rejected": return "却下"
        default: return "未提出"
        }
    }
}

// MARK: - Generic API Response

struct GenericAPIResponse: Codable {
    let ok: Bool?
    let message: String?
}

// MARK: - Auth Responses

struct LoginResponse: Codable {
    let accessToken: String
    let user: User
}

struct RegisterResponse: Codable {
    let ok: Bool?
    let message: String?
    let accessToken: String?
    let user: User?
}

// MARK: - Job

struct Job: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let employerId: String?
    let employerName: String?
    let location: String?
    let prefecture: String?
    let city: String?
    let address: String?
    let hourlyWage: Int?
    let dailyWage: Int?
    let workDate: String?
    let workDateEnd: String?
    let startTime: String?
    let endTime: String?
    let requiredPeople: Int?
    let currentApplicants: Int?
    let status: String?
    let categories: [String]?
    let requirements: String?
    let benefits: String?
    let imageUrl: String?
    let imageUrls: [String]?
    let latitude: Double?
    let longitude: Double?
    let createdAt: String?
    let isExpired: Bool?
    let hourlyRate: Int?
    let workTime: String?
    let repostedFrom: String?
    let goodRate: Int?
    let reviewCount: Int?
    let employerGoodRate: Int?
    let paymentType: String?

    var resolvedPaymentType: PaymentType {
        PaymentType(rawValue: paymentType ?? "") ?? .auto
    }

    var wageDisplay: String {
        if let hourly = hourlyWage {
            return "¥\(hourly.formatted())/時"
        }
        if let daily = dailyWage {
            return "¥\(daily.formatted())/日"
        }
        return "要相談"
    }

    var locationDisplay: String {
        [prefecture, city, address]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var timeDisplay: String {
        guard let start = startTime, let end = endTime else { return "" }
        return "\(start) 〜 \(end)"
    }

    var statusDisplay: String {
        switch status {
        case "active", "recruiting": return "募集中"
        case "draft": return "下書き"
        case "closed": return "募集終了"
        case "expired": return "期限切れ"
        case "pending": return "審査中"
        default: return status ?? ""
        }
    }
}

// MARK: - Payment Type

enum PaymentType: String, Codable, CaseIterable {
    case auto = "auto"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .auto: return "自動支払い"
        case .manual: return "実績精算払い"
        }
    }

    var description: String {
        switch self {
        case .auto: return "チェックアウト時に予定時給×予定時間で自動決済"
        case .manual: return "実働確認後に交通費・残業代を含めて精算"
        }
    }
}

struct JobCreateRequest: Codable {
    let title: String
    let description: String
    let prefecture: String
    let city: String
    let address: String?
    let hourlyWage: Int?
    let dailyWage: Int?
    let workDate: String?
    let startTime: String
    let endTime: String
    let requiredPeople: Int
    let categories: [String]?
    let requirements: String?
    let benefits: String?
    let paymentType: String?
}

// MARK: - Application

struct Application: Codable, Identifiable {
    let id: String
    let jobId: String
    let applicantId: String
    let employerId: String?
    let status: String
    let jobTitle: String?
    let employerName: String?
    let applicantName: String?
    let applicantPhone: String?
    let applicantEmail: String?
    let message: String?
    let workDate: String?
    let hourlyWage: Int?
    let startTime: String?
    let endTime: String?
    let checkInTime: String?
    let checkOutTime: String?
    let createdAt: String?
    let updatedAt: String?
    let goodRate: Int?
    let reviewCount: Int?
    let completedJobs: Int?
    let isVerified: Bool?
    let bio: String?
    let iconUrl: String?
    let paymentType: String?

    var statusDisplay: String {
        switch status {
        case "pending": return "審査中"
        case "accepted": return "承認済み"
        case "rejected": return "不採用"
        case "canceled": return "キャンセル"
        case "completed": return "完了"
        case "confirmed": return "確定"
        case "working": return "勤務中"
        case "paid": return "支払済"
        default: return status
        }
    }

    var statusColor: String {
        switch status {
        case "pending": return "orange"
        case "accepted": return "green"
        case "rejected": return "red"
        case "canceled": return "gray"
        case "completed": return "blue"
        default: return "gray"
        }
    }
}

struct ApplicationResponse: Codable {
    let ok: Bool
    let applicationId: String
    let chatRoomId: String?
    let message: String?
}

// MARK: - Wallet

struct Wallet: Codable {
    let balance: Int
    let pendingBalance: Int?
    let availableBalance: Int?
    let stripeBalance: StripeBalance?

    struct StripeBalance: Codable {
        let available: Int?
        let pending: Int?
    }

    var availableAmount: Int {
        availableBalance ?? balance
    }
}

struct Transaction: Codable, Identifiable {
    let id: String
    let type: String
    let amount: Int
    let description: String?
    let status: String?
    let createdAt: String?
    let jobTitle: String?

    var typeDisplay: String {
        switch type {
        case "earning": return "報酬"
        case "withdrawal": return "出金"
        case "bonus": return "ボーナス"
        case "stripe_connect_received": return "Stripe入金"
        case "refund": return "返金"
        default: return type
        }
    }

    var isPositive: Bool {
        type == "earning" || type == "bonus" || type == "refund" || type == "stripe_connect_received"
    }
}

// MARK: - Bank Account

struct BankAccount: Codable, Identifiable {
    let id: String
    let bankName: String
    let bankCode: String?
    let branchName: String
    let branchCode: String?
    let accountType: String
    let accountNumber: String
    let accountHolderName: String
    let isDefault: Bool?
    let createdAt: String?

    var accountTypeDisplay: String {
        accountType == "ordinary" ? "普通" : "当座"
    }

    var displayText: String {
        "\(bankName) \(branchName) \(accountTypeDisplay) \(accountNumber)"
    }
}

struct BankAccountCreateRequest: Codable {
    let bankName: String
    let bankCode: String
    let branchName: String
    let branchCode: String
    let accountType: String
    let accountNumber: String
    let accountHolderName: String
}

// MARK: - Withdrawal

struct WithdrawalRequest: Codable, Identifiable {
    let id: String
    let userId: String
    let bankAccountId: String
    let amount: Int
    let status: String
    let requestedAt: String?
    let processedAt: String?
    let bankAccountInfo: BankAccount?

    var statusDisplay: String {
        switch status {
        case "pending": return "処理待ち"
        case "processing": return "処理中"
        case "completed": return "完了"
        case "rejected": return "却下"
        case "canceled": return "キャンセル"
        default: return status
        }
    }
}

struct WithdrawalCreateRequest: Codable {
    let bankAccountId: String
    let amount: Int
}

// MARK: - Identity Verification

struct IdentityVerification: Codable {
    let status: String
    let documentType: String?
    let submittedAt: String?
    let verifiedAt: String?
    let rejectionReason: String?

    var statusDisplay: String {
        switch status {
        case "none": return "未提出"
        case "pending": return "審査中"
        case "approved": return "確認済み"
        case "rejected": return "却下"
        default: return status
        }
    }
}

// MARK: - Chat

struct ChatRoom: Codable, Identifiable {
    let id: String
    let jobId: String?
    let applicationId: String?
    let employerId: String
    let workerId: String
    let employerName: String?
    let workerName: String?
    let jobTitle: String?
    let lastMessage: String?
    let lastMessageAt: String?
    let unreadCount: Int?
    let createdAt: String?

    func otherPartyName(myUserId: String) -> String {
        if myUserId == employerId {
            return workerName ?? "求職者"
        } else {
            return employerName ?? "事業者"
        }
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let roomId: String
    let senderId: String
    let content: String
    let createdAt: String?
    let isRead: Bool?
    let messageType: String?  // "text", "image", "file"
    let imageUrl: String?
    let fileUrl: String?
    let fileName: String?
    let fileSize: Int?
}

// MARK: - Employer Profile

struct EmployerProfile: Codable, Identifiable {
    let id: String
    let employerId: String
    let companyName: String?
    let description: String?
    let prefecture: String?
    let city: String?
    let address: String?
    let categories: [String]?
    let phone: String?
    let email: String?
    let logoUrl: String?
    let coverImageUrl: String?
    let createdAt: String?
    let totalJobs: Int?
    let totalHires: Int?
    let averageRating: Double?

    var businessName: String? { companyName }
    var contactPhone: String? { phone }
    var contactEmail: String? { email }
}

// MARK: - Employer Stats

struct EmployerStats: Codable {
    let activeJobs: Int
    let totalApplicants: Int
    let thisMonthHires: Int
    let averageRating: Double
    let pendingApplications: Int
    let totalEarnings: Int?
}

// MARK: - Work History / Attendance

struct WorkHistory: Codable, Identifiable {
    let id: String
    let jobId: String
    let workerId: String
    let jobTitle: String?
    let employerName: String?
    let workDate: String
    let checkInTime: String?
    let checkOutTime: String?
    let status: String
    let earnings: Int?
    let createdAt: String?

    var statusDisplay: String {
        switch status {
        case "scheduled": return "予定"
        case "checked_in": return "勤務中"
        case "completed": return "完了"
        case "canceled": return "キャンセル"
        case "no_show": return "欠勤"
        default: return status
        }
    }
}

// MARK: - Payment / Stripe

struct PaymentMethod: Codable, Identifiable {
    let id: String
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    let isDefault: Bool?

    var displayText: String {
        "\(brand.uppercased()) •••• \(last4)"
    }

    var expiryDisplay: String {
        "\(expMonth)/\(expYear)"
    }
}

struct PaymentIntent: Codable {
    let clientSecret: String
    let amount: Int
    let status: String
}

// MARK: - Review

struct Review: Codable, Identifiable {
    let id: String
    let reviewerId: String
    let revieweeId: String
    let jobId: String
    let rating: Int
    let comment: String?
    let reviewerName: String?
    let createdAt: String?
}

// MARK: - Notification

struct AppNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let message: String
    let isRead: Bool
    let data: [String: String]?
    let createdAt: String?
    let imageUrl: String?
}

// MARK: - Category

struct JobCategory: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String?
    let iconName: String?
    let jobCount: Int?
}

// MARK: - Prefecture

struct Prefecture: Identifiable {
    let id: String
    let name: String

    static let all: [Prefecture] = [
        Prefecture(id: "hokkaido", name: "北海道"),
        Prefecture(id: "aomori", name: "青森県"),
        Prefecture(id: "iwate", name: "岩手県"),
        Prefecture(id: "miyagi", name: "宮城県"),
        Prefecture(id: "akita", name: "秋田県"),
        Prefecture(id: "yamagata", name: "山形県"),
        Prefecture(id: "fukushima", name: "福島県"),
        Prefecture(id: "ibaraki", name: "茨城県"),
        Prefecture(id: "tochigi", name: "栃木県"),
        Prefecture(id: "gunma", name: "群馬県"),
        Prefecture(id: "saitama", name: "埼玉県"),
        Prefecture(id: "chiba", name: "千葉県"),
        Prefecture(id: "tokyo", name: "東京都"),
        Prefecture(id: "kanagawa", name: "神奈川県"),
        Prefecture(id: "niigata", name: "新潟県"),
        Prefecture(id: "toyama", name: "富山県"),
        Prefecture(id: "ishikawa", name: "石川県"),
        Prefecture(id: "fukui", name: "福井県"),
        Prefecture(id: "yamanashi", name: "山梨県"),
        Prefecture(id: "nagano", name: "長野県"),
        Prefecture(id: "gifu", name: "岐阜県"),
        Prefecture(id: "shizuoka", name: "静岡県"),
        Prefecture(id: "aichi", name: "愛知県"),
        Prefecture(id: "mie", name: "三重県"),
        Prefecture(id: "shiga", name: "滋賀県"),
        Prefecture(id: "kyoto", name: "京都府"),
        Prefecture(id: "osaka", name: "大阪府"),
        Prefecture(id: "hyogo", name: "兵庫県"),
        Prefecture(id: "nara", name: "奈良県"),
        Prefecture(id: "wakayama", name: "和歌山県"),
        Prefecture(id: "tottori", name: "鳥取県"),
        Prefecture(id: "shimane", name: "島根県"),
        Prefecture(id: "okayama", name: "岡山県"),
        Prefecture(id: "hiroshima", name: "広島県"),
        Prefecture(id: "yamaguchi", name: "山口県"),
        Prefecture(id: "tokushima", name: "徳島県"),
        Prefecture(id: "kagawa", name: "香川県"),
        Prefecture(id: "ehime", name: "愛媛県"),
        Prefecture(id: "kochi", name: "高知県"),
        Prefecture(id: "fukuoka", name: "福岡県"),
        Prefecture(id: "saga", name: "佐賀県"),
        Prefecture(id: "nagasaki", name: "長崎県"),
        Prefecture(id: "kumamoto", name: "熊本県"),
        Prefecture(id: "oita", name: "大分県"),
        Prefecture(id: "miyazaki", name: "宮崎県"),
        Prefecture(id: "kagoshima", name: "鹿児島県"),
        Prefecture(id: "okinawa", name: "沖縄県")
    ]
}

// MARK: - API Response Wrappers

struct ListResponse<T: Codable>: Codable {
    let data: [T]
    let total: Int?
    let page: Int?
    let limit: Int?
}

struct SimpleResponse: Codable {
    let ok: Bool
    let message: String?
}

struct BankAccountsResponse: Codable {
    let data: [BankAccount]
}

struct TransactionsResponse: Codable {
    let data: [Transaction]
}

// MARK: - Check-in/Check-out Responses

struct CheckInResponse: Codable {
    let ok: Bool
    let applicationId: String?
    let jobId: String?
    let jobTitle: String?
    let checkInTime: String?
    let message: String?
}

struct CheckOutResponse: Codable {
    let ok: Bool
    let applicationId: String?
    let checkOutTime: String?
    let workedHours: Double?
    let earnings: Int?
    let paid: Bool?
    let paymentId: String?
    let message: String?
    let paymentType: String?
}

// MARK: - Payment Processing

struct PaymentQuoteResponse: Codable {
    let amount: Int
    let fee: Int
    let total: Int
    let currency: String?
}

struct PaymentChargeResponse: Codable {
    let ok: Bool
    let paymentId: String?
    let status: String?
    let message: String?
}

struct InstantPaymentResponse: Codable {
    let ok: Bool
    let paymentId: String?
    let paymentIntentId: String?
    let amount: Int?
    let fee: Int?
    let netAmount: Int?
    let walletBalance: Int?
    let status: String?
    let message: String?
    let requiresAction: Bool?
    let clientSecret: String?
}

struct ManualPaymentResponse: Codable {
    let ok: Bool
    let paymentId: String?
    let status: String?
    let message: String?
}

// MARK: - QR Code Response

struct QRCodeResponse: Codable {
    let token: String
    let expiresAt: String?
    let jobId: String?
}

// MARK: - Pending Review

struct PendingReview: Codable, Identifiable {
    let id: String
    let jobId: String
    let jobTitle: String?
    let revieweeId: String
    let revieweeName: String?
    let revieweeType: String?
    let workDate: String?
}

// MARK: - Eligibility Response

struct EligibilityResponse: Codable {
    let eligible: Bool
    let reasons: [String]?
    let identityVerified: Bool?
    let profileComplete: Bool?
    let message: String?
}

// MARK: - Admin Models

struct AdminDashboardStats: Codable {
    let totalUsers: Int
    let totalJobs: Int
    let totalApplications: Int
    let totalRevenue: Int
    let pendingWithdrawals: Int
    let pendingIdentityVerifications: Int
    let activeJobSeekers: Int
    let activeEmployers: Int
    let thisMonthNewUsers: Int
    let thisMonthNewJobs: Int
    let thisMonthRevenue: Int
}

struct AdminUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let userType: String
    let phone: String?
    let isIdentityVerified: Bool?
    let identityVerificationStatus: String?
    let createdAt: String?
    let lastLoginAt: String?
    let isActive: Bool?
    let isBanned: Bool?
    let totalApplications: Int?
    let totalJobs: Int?
    let walletBalance: Int?

    var displayName: String {
        name ?? email
    }

    var userTypeDisplay: String {
        switch userType {
        case "job_seeker": return "求職者"
        case "employer": return "事業者"
        case "admin": return "管理者"
        default: return userType
        }
    }
}

struct AdminJob: Codable, Identifiable {
    let id: String
    let title: String
    let employerId: String
    let employerName: String?
    let status: String?
    let workDate: String?
    let hourlyWage: Int?
    let requiredPeople: Int?
    let currentApplicants: Int?
    let createdAt: String?
    let isFlagged: Bool?
    let flagReason: String?

    var statusDisplay: String {
        switch status {
        case "active": return "公開中"
        case "draft": return "下書き"
        case "closed": return "終了"
        case "pending": return "審査中"
        case "suspended": return "停止中"
        default: return status ?? ""
        }
    }
}

struct AdminWithdrawalRequest: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String?
    let userEmail: String?
    let amount: Int
    let status: String
    let bankAccountInfo: BankAccount?
    let requestedAt: String?
    let processedAt: String?

    var statusDisplay: String {
        switch status {
        case "pending": return "処理待ち"
        case "processing": return "処理中"
        case "completed": return "完了"
        case "rejected": return "却下"
        default: return status
        }
    }
}

struct AdminIdentityVerification: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String?
    let userEmail: String?
    let documentType: String?
    let status: String
    let submittedAt: String?
    let frontImageUrl: String?
    let backImageUrl: String?

    var statusDisplay: String {
        switch status {
        case "pending": return "審査待ち"
        case "approved": return "承認済み"
        case "rejected": return "却下"
        default: return status
        }
    }

    var documentTypeDisplay: String {
        switch documentType {
        case "drivers_license": return "運転免許証"
        case "my_number_card": return "マイナンバーカード"
        case "passport": return "パスポート"
        case "residence_card": return "在留カード"
        default: return documentType ?? "不明"
        }
    }
}

struct AdminActivity: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let detail: String?
    let userId: String?
    let createdAt: String?

    var iconName: String {
        switch type {
        case "user_registered": return "person.badge.plus"
        case "job_posted": return "doc.fill.badge.plus"
        case "withdrawal_requested": return "arrow.down.circle.fill"
        case "identity_submitted": return "person.text.rectangle"
        case "application_submitted": return "paperplane.fill"
        default: return "bell.fill"
        }
    }

    var iconColor: String {
        switch type {
        case "user_registered": return "blue"
        case "job_posted": return "green"
        case "withdrawal_requested": return "orange"
        case "identity_submitted": return "purple"
        case "application_submitted": return "teal"
        default: return "gray"
        }
    }
}

struct AdminBanner: Codable, Identifiable {
    let id: String
    let title: String
    let imageUrl: String?
    let linkUrl: String?
    let isActive: Bool
    let startDate: String?
    let endDate: String?
    let position: Int?
    let createdAt: String?
}

struct AdminSystemSettings: Codable {
    let platformFeePercent: Double
    let minWithdrawalAmount: Int
    let maxWithdrawalAmount: Int
    let withdrawalFee: Int
    let requireIdentityVerification: Bool
    let autoApproveJobs: Bool
    let maintenanceMode: Bool
    let enablePushNotifications: Bool?
    let enableEmailNotifications: Bool?
    let notifyNewRegistration: Bool?
    let notifyWithdrawalRequest: Bool?
    let notifyIdentitySubmission: Bool?
    let notifyNewJobPost: Bool?
}

// MARK: - Worker Score / Rank

struct WorkerScore: Codable {
    let totalJobs: Int
    let completedJobs: Int
    let canceledJobs: Int
    let noShowCount: Int
    let averageRating: Double
    let goodRatePercent: Int
    let rank: String
    let nextRankJobs: Int?
    let penalties: Int
    let reliabilityScore: Int

    var rankDisplay: String {
        switch rank {
        case "diamond": return "ダイヤモンド"
        case "gold": return "ゴールド"
        case "silver": return "シルバー"
        case "bronze": return "ブロンズ"
        case "beginner": return "ビギナー"
        default: return rank
        }
    }

    var rankColor: String {
        switch rank {
        case "diamond": return "purple"
        case "gold": return "yellow"
        case "silver": return "gray"
        case "bronze": return "orange"
        default: return "blue"
        }
    }

    var rankIcon: String {
        switch rank {
        case "diamond": return "diamond.fill"
        case "gold": return "star.circle.fill"
        case "silver": return "medal.fill"
        case "bronze": return "shield.fill"
        default: return "person.fill"
        }
    }
}

// MARK: - Penalty

struct Penalty: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String
    let reason: String?
    let jobId: String?
    let jobTitle: String?
    let penaltyPoints: Int
    let createdAt: String?
    let expiresAt: String?

    var typeDisplay: String {
        switch type {
        case "no_show": return "無断欠勤"
        case "late_cancel": return "直前キャンセル"
        case "early_leave": return "早退"
        case "late_arrival": return "遅刻"
        case "violation": return "規約違反"
        default: return type
        }
    }

    var typeIcon: String {
        switch type {
        case "no_show": return "xmark.circle.fill"
        case "late_cancel": return "clock.badge.xmark"
        case "early_leave": return "arrow.right.circle.fill"
        case "late_arrival": return "clock.fill"
        case "violation": return "exclamationmark.triangle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Monthly Summary

struct MonthlySummary: Codable {
    let month: String
    let totalEarnings: Int
    let totalJobs: Int
    let totalHours: Double
    let averageHourlyRate: Int
    let topCategory: String?
    let completionRate: Double
}

// MARK: - Profile Completion

struct ProfileCompletion: Codable {
    let percentage: Int
    let missingFields: [String]

    var missingFieldsDisplay: [String] {
        missingFields.map { field in
            switch field {
            case "name": return "名前"
            case "phone": return "電話番号"
            case "bio": return "自己紹介"
            case "profile_image": return "プロフィール写真"
            case "prefecture": return "都道府県"
            case "city": return "市区町村"
            case "birth_date": return "生年月日"
            case "gender": return "性別"
            case "identity_verification": return "本人確認"
            case "bank_account": return "銀行口座"
            default: return field
            }
        }
    }
}

// MARK: - Banner

struct HomeBanner: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let imageUrl: String?
    let linkUrl: String?
    let backgroundColor: String?
    let isActive: Bool?
}

// MARK: - Job Template

struct JobTemplate: Codable, Identifiable {
    let id: String
    let employerId: String
    let name: String
    let title: String
    let description: String?
    let prefecture: String?
    let city: String?
    let address: String?
    let hourlyWage: Int?
    let dailyWage: Int?
    let startTime: String?
    let endTime: String?
    let requiredPeople: Int?
    let categories: [String]?
    let requirements: String?
    let benefits: String?
    let createdAt: String?
}

// MARK: - Timesheet

struct Timesheet: Codable, Identifiable {
    let id: String
    let applicationId: String
    let jobId: String
    let workerId: String
    let workerName: String?
    let jobTitle: String?
    let workDate: String
    let scheduledStart: String?
    let scheduledEnd: String?
    let actualStart: String?
    let actualEnd: String?
    let breakMinutes: Int?
    let totalHours: Double?
    let hourlyRate: Int?
    let totalPay: Int?
    let status: String
    let approvedAt: String?
    let note: String?

    var statusDisplay: String {
        switch status {
        case "pending": return "承認待ち"
        case "approved": return "承認済み"
        case "rejected": return "却下"
        case "adjusted": return "修正済み"
        default: return status
        }
    }
}

// MARK: - Extended Job Fields

extension Job {
    var transportationAllowance: Bool { benefits?.contains("交通費") == true }
    var mealProvided: Bool { benefits?.contains("まかない") == true || benefits?.contains("食事") == true }
    var beginnerWelcome: Bool { requirements?.contains("未経験") == true || requirements?.contains("初心者") == true }

    var perkTags: [JobPerk] {
        var tags: [JobPerk] = []
        if transportationAllowance { tags.append(.transportation) }
        if mealProvided { tags.append(.meal) }
        if beginnerWelcome { tags.append(.beginner) }
        return tags
    }
}

enum JobPerk: String, CaseIterable {
    case transportation = "交通費支給"
    case meal = "まかない"
    case beginner = "未経験OK"

    var icon: String {
        switch self {
        case .transportation: return "tram.fill"
        case .meal: return "fork.knife"
        case .beginner: return "face.smiling.fill"
        }
    }

    var color: String {
        switch self {
        case .transportation: return "blue"
        case .meal: return "orange"
        case .beginner: return "purple"
        }
    }
}

// MARK: - Job Industry Templates

enum JobIndustry: String, CaseIterable, Identifiable {
    case restaurant = "飲食"
    case lightWork = "軽作業"
    case event = "イベント"
    case office = "オフィス"
    case retail = "販売"
    case cleaning = "清掃"
    case delivery = "配送"
    case nursing = "介護"
    case warehouse = "倉庫"
    case factory = "工場"
    case hotel = "ホテル・宿泊"
    case other = "その他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .lightWork: return "shippingbox.fill"
        case .event: return "party.popper.fill"
        case .office: return "desktopcomputer"
        case .retail: return "bag.fill"
        case .cleaning: return "sparkles"
        case .delivery: return "car.fill"
        case .nursing: return "heart.fill"
        case .warehouse: return "building.2.fill"
        case .factory: return "gearshape.2.fill"
        case .hotel: return "bed.double.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum JobRole: String, CaseIterable, Identifiable {
    case hallStaff = "ホールスタッフ"
    case kitchenStaff = "キッチンスタッフ"
    case dishwasher = "洗い場"
    case barStaff = "バーテンダー"
    case cafeStaff = "カフェスタッフ"
    case sorting = "仕分け"
    case picking = "ピッキング"
    case packing = "梱包"
    case inspection = "検品"
    case loadingUnloading = "荷積み・荷下ろし"
    case eventSetup = "会場設営"
    case eventStaff = "イベントスタッフ"
    case receptionStaff = "受付"
    case dataEntry = "データ入力"
    case generalAffairs = "一般事務"
    case callCenter = "コールセンター"
    case cashier = "レジスタッフ"
    case stockClerk = "品出し"
    case buildingCleaning = "ビル清掃"
    case hotelCleaning = "客室清掃"
    case deliveryHelper = "配送助手"
    case careWorker = "介護スタッフ"
    case frontDesk = "フロント"
    case banquetStaff = "宴会スタッフ"
    case otherRole = "その他"

    var id: String { rawValue }

    var industry: JobIndustry {
        switch self {
        case .hallStaff, .kitchenStaff, .dishwasher, .barStaff, .cafeStaff: return .restaurant
        case .sorting, .picking, .packing, .inspection, .loadingUnloading: return .lightWork
        case .eventSetup, .eventStaff, .receptionStaff: return .event
        case .dataEntry, .generalAffairs, .callCenter: return .office
        case .cashier, .stockClerk: return .retail
        case .buildingCleaning, .hotelCleaning: return .cleaning
        case .deliveryHelper: return .delivery
        case .careWorker: return .nursing
        case .frontDesk, .banquetStaff: return .hotel
        case .otherRole: return .other
        }
    }

    static func roles(for industry: JobIndustry) -> [JobRole] {
        allCases.filter { $0.industry == industry }
    }
}

struct JobPostTemplate {
    let role: JobRole
    let title: String
    let description: String
    let requirements: String
    let benefits: String
    let dressCode: String
    let smokingPolicy: String
    let defaultWage: Int
    let startTime: String
    let endTime: String
    let autoMessage: String

    static func template(for role: JobRole) -> JobPostTemplate {
        switch role {
        case .hallStaff:
            return .init(role: role, title: "【ホールスタッフ】接客・配膳のお仕事",
                description: "レストランでのホール業務全般をお願いします。\n\n【主な業務内容】\n・お客様のご案内、オーダー取り\n・料理の配膳、片付け\n・テーブルセッティング\n・レジ対応\n\n丁寧にお教えしますので、未経験の方もご安心ください！",
                requirements: "未経験歓迎 / 18歳以上 / 日本語での接客が可能な方",
                benefits: "まかない付き / 交通費支給（上限1,000円） / 制服貸与",
                dressCode: "制服貸与（Tシャツ・エプロン）/ 黒いパンツ・靴は持参",
                smokingPolicy: "屋内全面禁煙（屋外喫煙所あり）",
                defaultWage: 1200, startTime: "10:00", endTime: "15:00",
                autoMessage: "ご応募ありがとうございます！\n当日は黒いパンツ・靴でお越しください。\n集合場所：店舗裏手のスタッフ入口")
        case .kitchenStaff:
            return .init(role: role, title: "【キッチンスタッフ】調理補助のお仕事",
                description: "キッチンでの調理補助業務をお願いします。\n\n【主な業務内容】\n・食材の仕込み（カット、下準備）\n・簡単な調理補助\n・盛り付け\n・キッチン内の清掃\n\n調理経験がなくても丁寧にお教えします！",
                requirements: "未経験歓迎 / 18歳以上 / 長い髪はまとめられる方",
                benefits: "まかない付き / 交通費支給（上限1,000円） / 制服貸与",
                dressCode: "制服貸与 / 黒いパンツ持参 / 爪は短く切ってきてください",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1200, startTime: "09:00", endTime: "14:00",
                autoMessage: "ご応募ありがとうございます！\n爪は短く切り、アクセサリーは外してきてください。\n集合場所：店舗裏手のスタッフ入口")
        case .dishwasher:
            return .init(role: role, title: "【洗い場スタッフ】食器洗浄のお仕事",
                description: "洗い場での食器洗浄業務をお願いします。\n\n【主な業務内容】\n・食器類の洗浄（食洗機あり）\n・調理器具の洗浄\n・食器の片付け、整理\n\nシンプルな作業なので未経験でもすぐに慣れます！",
                requirements: "未経験歓迎 / 18歳以上 / 立ち仕事が可能な方",
                benefits: "まかない付き / 交通費支給（上限1,000円） / 制服貸与",
                dressCode: "制服貸与 / 濡れても良い靴を持参",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1150, startTime: "17:00", endTime: "22:00",
                autoMessage: "ご応募ありがとうございます！濡れても良い靴をお持ちください。")
        case .sorting:
            return .init(role: role, title: "【仕分けスタッフ】商品の仕分け作業",
                description: "倉庫内での商品仕分け作業をお願いします。\n\n【主な業務内容】\n・届いた荷物の仕分け\n・指定の棚・エリアへの配置\n・ラベルの確認・貼付\n\n初めての方でもすぐに覚えられるシンプルな作業です！",
                requirements: "未経験歓迎 / 18歳以上 / 動きやすい服装で来られる方",
                benefits: "交通費支給（上限1,000円） / 飲み物無料",
                dressCode: "動きやすい服装（ジーンズ・スニーカーOK） / 安全靴は貸出あり",
                smokingPolicy: "屋内全面禁煙（屋外喫煙所あり）",
                defaultWage: 1200, startTime: "09:00", endTime: "17:00",
                autoMessage: "ご応募ありがとうございます！\n動きやすい服装でお越しください。\n集合場所：倉庫正面入口の受付")
        case .picking:
            return .init(role: role, title: "【ピッキング】倉庫内ピッキング作業",
                description: "倉庫内でのピッキング作業をお願いします。\n\n【主な業務内容】\n・リストに基づいた商品のピッキング\n・商品の数量確認\n・ハンディ端末の操作\n\n端末操作もすぐに覚えられます！",
                requirements: "未経験歓迎 / 18歳以上",
                benefits: "交通費支給（上限1,000円） / 飲み物無料",
                dressCode: "動きやすい服装・スニーカー",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1250, startTime: "09:00", endTime: "18:00",
                autoMessage: "ご応募ありがとうございます！動きやすい服装でお越しください。")
        case .packing:
            return .init(role: role, title: "【梱包スタッフ】商品の梱包作業",
                description: "商品の梱包・出荷準備をお願いします。\n\n【主な業務内容】\n・商品の検品\n・緩衝材を使った梱包\n・ラベル貼り\n\n座り仕事中心で体力に自信のない方でも安心です。",
                requirements: "未経験歓迎 / 18歳以上 / 丁寧に作業できる方",
                benefits: "交通費支給（上限1,000円）",
                dressCode: "動きやすい服装",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1150, startTime: "10:00", endTime: "17:00",
                autoMessage: "ご応募ありがとうございます！動きやすい服装でお越しください。")
        case .eventSetup:
            return .init(role: role, title: "【会場設営】イベント会場の準備・撤去",
                description: "イベント会場の設営・撤去をお願いします。\n\n【主な業務内容】\n・テーブル、椅子の搬入・配置\n・装飾の設置\n・機材のセットアップ補助\n・終了後の撤去・片付け\n\nチームで協力して行う作業です！",
                requirements: "未経験歓迎 / 18歳以上 / ある程度の体力がある方",
                benefits: "交通費全額支給 / 弁当支給",
                dressCode: "黒いTシャツ・ジーンズ・スニーカー",
                smokingPolicy: "会場内全面禁煙",
                defaultWage: 1300, startTime: "08:00", endTime: "17:00",
                autoMessage: "ご応募ありがとうございます！黒い服装（Tシャツ・パンツ）と動きやすい靴でお越しください。")
        case .eventStaff:
            return .init(role: role, title: "【イベントスタッフ】運営サポート",
                description: "イベントの運営スタッフとしてお手伝いいただきます。\n\n【主な業務内容】\n・来場者の誘導・案内\n・チケット確認\n・物販対応\n・会場内の巡回\n\n楽しいイベントの裏側を体験できます！",
                requirements: "未経験歓迎 / 18歳以上 / 明るく対応できる方",
                benefits: "交通費全額支給 / 弁当支給",
                dressCode: "スタッフTシャツ貸与 / 黒いパンツ・靴は持参",
                smokingPolicy: "会場内全面禁煙",
                defaultWage: 1200, startTime: "09:00", endTime: "18:00",
                autoMessage: "ご応募ありがとうございます！黒いパンツと靴でお越しください。スタッフTシャツは現場でお渡しします。")
        case .dataEntry:
            return .init(role: role, title: "【データ入力】PCでのデータ入力作業",
                description: "オフィスでのデータ入力業務をお願いします。\n\n【主な業務内容】\n・Excelへのデータ入力\n・書類のスキャン・PDF化\n・簡単なデータチェック\n\nPCの基本操作ができればOK！空調完備で快適です。",
                requirements: "PC基本操作（タイピング）ができる方 / 18歳以上",
                benefits: "交通費支給（上限1,000円） / オフィスカジュアルOK",
                dressCode: "オフィスカジュアル（ジーンズ・スニーカー可）",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1300, startTime: "09:00", endTime: "18:00",
                autoMessage: "ご応募ありがとうございます！オフィスカジュアルでお越しください。ビル1F受付にてお名前をお伝えください。")
        case .cashier:
            return .init(role: role, title: "【レジスタッフ】レジ対応・接客",
                description: "店舗でのレジ業務をお願いします。\n\n【主な業務内容】\n・レジ対応（POSレジ使用）\n・お会計対応（現金・キャッシュレス）\n・袋詰め\n\nPOSレジは操作がシンプルですぐに覚えられます！",
                requirements: "未経験歓迎 / 18歳以上 / 基本的な接客ができる方",
                benefits: "交通費支給（上限1,000円） / 制服貸与 / 社員割引あり",
                dressCode: "制服貸与 / 黒いパンツ・靴は持参",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1150, startTime: "10:00", endTime: "18:00",
                autoMessage: "ご応募ありがとうございます！黒いパンツと靴でお越しください。制服は店舗でお渡しします。")
        case .stockClerk:
            return .init(role: role, title: "【品出し】商品陳列・補充",
                description: "店舗での商品の品出し・陳列作業をお願いします。\n\n【主な業務内容】\n・商品の補充・陳列\n・在庫チェック\n・売場の整理整頓\n\n接客は最低限。黙々と作業したい方にピッタリ！",
                requirements: "未経験歓迎 / 18歳以上",
                benefits: "交通費支給（上限1,000円） / 制服貸与",
                dressCode: "制服貸与 / 動きやすい靴を持参",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1100, startTime: "07:00", endTime: "11:00",
                autoMessage: "ご応募ありがとうございます！動きやすい靴でお越しください。")
        case .buildingCleaning:
            return .init(role: role, title: "【清掃スタッフ】ビル・施設の清掃",
                description: "ビル・施設の清掃業務をお願いします。\n\n【主な業務内容】\n・共用部の掃除機がけ・拭き掃除\n・トイレ清掃\n・ゴミ回収\n\n一人で黙々と作業できるお仕事です。",
                requirements: "未経験歓迎 / 18歳以上",
                benefits: "交通費支給（上限1,000円） / 制服貸与",
                dressCode: "制服貸与 / 動きやすい靴を持参",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1200, startTime: "06:00", endTime: "09:00",
                autoMessage: "ご応募ありがとうございます！動きやすい靴でお越しください。ビル管理室にてお名前をお伝えください。")
        case .hotelCleaning:
            return .init(role: role, title: "【客室清掃】ホテルの客室クリーニング",
                description: "ホテル客室の清掃業務をお願いします。\n\n【主な業務内容】\n・ベッドメイキング\n・バスルーム清掃\n・アメニティ補充\n\nチームで行うので未経験でも安心です！",
                requirements: "未経験歓迎 / 18歳以上 / ある程度の体力がある方",
                benefits: "交通費支給（上限1,000円） / 制服貸与 / 従業員食堂利用可",
                dressCode: "制服貸与",
                smokingPolicy: "館内全面禁煙",
                defaultWage: 1200, startTime: "10:00", endTime: "15:00",
                autoMessage: "ご応募ありがとうございます！ホテル従業員入口からお入りください。")
        case .deliveryHelper:
            return .init(role: role, title: "【配送助手】ドライバーのサポート",
                description: "配送ドライバーの助手業務をお願いします。\n\n【主な業務内容】\n・荷物の積み込み・荷下ろし\n・配達先での荷物の搬入\n・伝票の確認\n\nドライバーと2人1組で行動するので安心です！",
                requirements: "未経験歓迎 / 18歳以上 / ある程度の体力がある方",
                benefits: "交通費全額支給 / 弁当支給",
                dressCode: "動きやすい服装・靴（安全靴貸与あり）",
                smokingPolicy: "車内禁煙",
                defaultWage: 1300, startTime: "08:00", endTime: "17:00",
                autoMessage: "ご応募ありがとうございます！動きやすい服装でお越しください。配送センター正面入口に集合です。")
        case .careWorker:
            return .init(role: role, title: "【介護スタッフ】施設での介護補助",
                description: "介護施設での補助業務をお願いします。\n\n【主な業務内容】\n・食事の配膳・片付け\n・レクリエーション補助\n・見守り\n\n専門的な介護は正社員が行いますので資格不要です。",
                requirements: "未経験歓迎 / 18歳以上 / 思いやりを持って接することができる方",
                benefits: "交通費支給（上限1,000円） / 制服貸与 / 食事補助あり",
                dressCode: "制服貸与 / 室内用靴を持参",
                smokingPolicy: "施設内全面禁煙",
                defaultWage: 1300, startTime: "09:00", endTime: "17:00",
                autoMessage: "ご応募ありがとうございます！室内用靴をお持ちください。施設正面受付にてお名前をお伝えください。")
        case .frontDesk:
            return .init(role: role, title: "【フロント】ホテルの受付業務",
                description: "ホテルフロントでの接客業務をお願いします。\n\n【主な業務内容】\n・チェックイン・チェックアウト対応\n・お客様からの問い合わせ対応\n・電話対応\n\nホテル業界に興味がある方におすすめです！",
                requirements: "PC基本操作ができる方 / 18歳以上 / 丁寧な接客ができる方",
                benefits: "交通費全額支給 / 制服貸与 / 従業員食堂利用可",
                dressCode: "制服貸与 / 清潔感のある髪型で来てください",
                smokingPolicy: "館内全面禁煙",
                defaultWage: 1400, startTime: "07:00", endTime: "15:00",
                autoMessage: "ご応募ありがとうございます！清潔感のある身だしなみでお越しください。従業員入口からお入りください。")
        case .banquetStaff:
            return .init(role: role, title: "【宴会スタッフ】パーティーの配膳",
                description: "ホテル宴会場でのサービス業務をお願いします。\n\n【主な業務内容】\n・料理の配膳・ドリンクサービス\n・テーブルセッティング\n・お客様のご案内\n\n華やかな雰囲気の中でのお仕事です！",
                requirements: "未経験歓迎 / 18歳以上",
                benefits: "交通費全額支給 / まかない付き / 制服貸与",
                dressCode: "制服貸与（黒いスラックス・革靴は持参）",
                smokingPolicy: "館内全面禁煙",
                defaultWage: 1350, startTime: "16:00", endTime: "22:00",
                autoMessage: "ご応募ありがとうございます！黒いスラックスと革靴をお持ちください。従業員入口から宴会事務所にお越しください。")
        default:
            return .init(role: role, title: "【\(role.rawValue)】スタッフ募集",
                description: "\(role.rawValue)のお仕事です。\n\n【主な業務内容】\n・（業務内容をご記入ください）\n\n未経験の方でも丁寧にお教えします！",
                requirements: "未経験歓迎 / 18歳以上",
                benefits: "交通費支給（上限1,000円）",
                dressCode: "動きやすい服装",
                smokingPolicy: "屋内全面禁煙",
                defaultWage: 1200, startTime: "09:00", endTime: "18:00",
                autoMessage: "ご応募ありがとうございます！当日の詳細はチャットでご連絡いたします。")
        }
    }
}

// MARK: - Time Modification Request

struct TimeModificationRequest: Codable, Identifiable {
    let id: String
    let applicationId: String
    let requestType: String
    let reason: String
    let status: String
    let requestedStartTime: String?
    let requestedEndTime: String?
    let createdAt: String?
    let jobTitle: String?
    let workerName: String?

    var requestTypeDisplay: String {
        switch requestType {
        case "late_arrival": return "遅刻"
        case "early_departure": return "早退"
        case "overtime": return "残業"
        case "missed_checkin": return "打刻忘れ（出勤）"
        case "missed_checkout": return "打刻忘れ（退勤）"
        case "employer_shortened": return "事業者都合の短縮"
        default: return requestType
        }
    }

    var statusDisplay: String {
        switch status {
        case "pending": return "申請中"
        case "approved": return "承認済み"
        case "rejected": return "却下"
        default: return status
        }
    }
}

// MARK: - Cancellation Policy

struct CancellationPolicy {
    static let rules: [(hours: Int, points: Int, label: String)] = [
        (72, 0, "72時間以上前：ペナルティなし"),
        (24, 1, "24〜72時間前：1ポイント"),
        (6, 2, "6〜24時間前：2ポイント"),
        (0, 3, "6時間以内：3ポイント"),
    ]

    static let restrictions: [(range: ClosedRange<Int>, label: String)] = [
        (0...3, "制限なし"),
        (4...5, "1週間以上先の求人のみ（1件まで）"),
        (6...7, "2週間以上先の求人のみ（1件まで）"),
        (8...100, "14日間の応募停止"),
    ]

    static func penalty(hoursRemaining: Int) -> Int {
        if hoursRemaining >= 72 { return 0 }
        if hoursRemaining >= 24 { return 1 }
        if hoursRemaining >= 6 { return 2 }
        return 3
    }
}

// MARK: - Help Article

struct HelpArticle: Identifiable {
    let id: String
    let category: String
    let title: String
    let content: String

    static let categories: [(name: String, icon: String)] = [
        ("はじめに", "book.fill"),
        ("求人を探す", "magnifyingglass"),
        ("応募について", "paperplane.fill"),
        ("お仕事当日", "briefcase.fill"),
        ("報酬・振込", "yensign.circle.fill"),
        ("レビュー", "star.fill"),
        ("ペナルティ", "exclamationmark.triangle.fill"),
        ("アカウント", "person.circle.fill"),
        ("事業者向け", "building.2.fill"),
        ("安全・安心", "shield.checkered"),
    ]

    static let articles: [HelpArticle] = [
        // はじめに
        HelpArticle(id: "gs1", category: "はじめに", title: "Bytersの使い方", content: "Bytersは、短期のお仕事を探して応募できるアプリです。\n\n1. プロフィールを完成させる\n2. 本人確認書類を提出する\n3. 銀行口座を登録する\n4. お仕事を探して応募する\n5. 承認されたらQRコードで出勤\n6. お仕事終了後にチェックアウト\n7. 報酬が自動で振り込まれます"),
        HelpArticle(id: "gs2", category: "はじめに", title: "本人確認について", content: "初めてお仕事に応募するには本人確認が必要です。\n\n【使用できる書類】\n・運転免許証\n・マイナンバーカード\n・パスポート\n・在留カード（外国籍の方）\n\n※ 健康保険証、学生証は使用できません\n\n審査には最大3営業日かかります。"),
        HelpArticle(id: "gs3", category: "はじめに", title: "プロフィールの設定", content: "プロフィールを完成させると、応募の通過率がアップします。\n\n【設定推奨項目】\n・プロフィール写真（清潔感のある写真）\n・自己紹介文\n・スキル・資格\n・希望勤務エリア"),
        // 求人を探す
        HelpArticle(id: "sr1", category: "求人を探す", title: "求人の検索方法", content: "ホームタブの「さがす」から求人を検索できます。\n\n【絞り込み条件】\n・エリア（都道府県・市区町村）\n・日付\n・時給\n・カテゴリ（飲食、軽作業など）\n・キーワード\n\nマップ表示で近くの求人を探すこともできます。"),
        HelpArticle(id: "sr2", category: "求人を探す", title: "お気に入り機能", content: "気になる求人はハートマークをタップしてお気に入りに保存できます。\n\nお気に入りはマイページから一覧で確認できます。"),
        // 応募について
        HelpArticle(id: "ap1", category: "応募について", title: "応募の流れ", content: "1. 求人詳細画面で「応募する」をタップ\n2. 応募メッセージを入力（任意）\n3. 事業者が応募を確認\n4. 承認されるとチャットが開きます\n\n※ 本人確認が完了している必要があります"),
        HelpArticle(id: "ap2", category: "応募について", title: "応募のキャンセル", content: "応募はキャンセルできますが、タイミングによりペナルティが発生します。\n\n・72時間以上前：ペナルティなし\n・24〜72時間前：1ポイント\n・6〜24時間前：2ポイント\n・6時間以内：3ポイント\n\n※ 無断欠勤はアカウント停止の対象です"),
        // お仕事当日
        HelpArticle(id: "wk1", category: "お仕事当日", title: "出勤・退勤の方法", content: "勤務先に設置されたQRコードをスキャンして出退勤します。\n\n【出勤】開始時刻の30分前からチェックイン可能\n【退勤】お仕事終了後にチェックアウト\n\n※ 位置情報の許可が必要です\n※ 開始5分以内、終了15分以内は自動調整されます"),
        HelpArticle(id: "wk2", category: "お仕事当日", title: "勤務時間の修正", content: "実際の勤務時間が予定と異なる場合、修正リクエストを送ることができます。\n\n「お仕事」タブ → 該当のお仕事 → 「時間修正をリクエスト」\n\n理由を10文字以上で入力してください。事業者の承認後に反映されます。"),
        // 報酬・振込
        HelpArticle(id: "py1", category: "報酬・振込", title: "報酬の受け取り方", content: "報酬は以下の方法で受け取れます。\n\n【即時振込】\n・24時間いつでも振込可能\n・振込手数料：無料\n・10〜30分で着金\n\n【定期振込】\n・毎月15日に前月分を自動振込\n\n※ 銀行口座の登録が必要です"),
        HelpArticle(id: "py2", category: "報酬・振込", title: "源泉徴収について", content: "日当が9,800円を超える場合、源泉徴収税が自動で控除されます。\n\n源泉徴収票はマイページからダウンロードできます。\n\n確定申告が必要な場合がありますのでご注意ください。"),
        // レビュー
        HelpArticle(id: "rv1", category: "レビュー", title: "レビューの仕組み", content: "お仕事完了後、事業者と求職者がお互いにレビューを投稿します。\n\n【レビュー項目】\n・Good / Bad 評価\n・コメント（任意）\n\nレビューは両者が投稿するか、14日経過後に公開されます。\n\n※ レビューを投稿するとペナルティが1ポイント減少します"),
        // ペナルティ
        HelpArticle(id: "pn1", category: "ペナルティ", title: "ペナルティポイント", content: "ルール違反でペナルティポイントが加算されます。\n\n【加算ルール】\n・直前キャンセル：1〜3ポイント\n・無断欠勤：アカウント停止\n\n【制限】\n・4〜5ポイント：応募制限\n・6〜7ポイント：さらに制限\n・8ポイント以上：14日間の応募停止\n\n【減少方法】\n・レビュー投稿：-1ポイント"),
        // アカウント
        HelpArticle(id: "ac1", category: "アカウント", title: "アカウント削除", content: "マイページ → 設定 → アカウントを削除\n\n※ 削除すると全てのデータが消去され、元に戻せません\n※ 未払いの報酬がある場合は先に出金してください"),
        // 事業者向け
        HelpArticle(id: "em1", category: "事業者向け", title: "求人の投稿方法", content: "1. ダッシュボードの「求人作成」をタップ\n2. 業種・職種を選択で自動入力（かんたん入力）\n3. 詳細を編集\n4. 公開\n\nテンプレートを保存すれば次回から簡単に投稿できます。"),
        HelpArticle(id: "em2", category: "事業者向け", title: "料金について", content: "【初期費用】無料\n【月額費用】無料\n【求人掲載費】無料\n\n【手数料】\nワーカーの報酬の30% + 220円/人/月\n\n成功報酬型なので、マッチングが成立するまで費用はかかりません。"),
        // 安全・安心
        HelpArticle(id: "sf1", category: "安全・安心", title: "通報・報告", content: "不適切な求人やメッセージを見つけた場合は、通報ボタンから報告できます。\n\n24時間体制で確認し、適切に対応いたします。\n\n【通報対象】\n・詐欺的な求人\n・ハラスメント\n・違法な労働条件\n・個人情報の不正収集"),
    ]
}

// MARK: - Favorite / Blocked Worker

struct FavoriteWorker: Codable, Identifiable {
    let id: String
    let workerId: String
    let workerName: String?
    let goodRate: Int?
    let completedJobs: Int?
    let addedAt: String?
}

struct BlockedWorker: Codable, Identifiable {
    let id: String
    let workerId: String
    let workerName: String?
    let reason: String?
    let blockedAt: String?
}

// MARK: - Referral

struct ReferralInfo: Codable {
    let referralCode: String
    let referralCount: Int
    let totalReward: Int
    let referralUrl: String?
}

// MARK: - Withholding Tax (源泉徴収)

struct WithholdingTaxCalculation {
    let grossEarnings: Int
    let taxAmount: Int
    let netEarnings: Int
    let taxRate: Double
    let isApplicable: Bool

    /// 日額9,800円超の場合に源泉徴収税を計算
    /// 甲欄・日額表に基づく簡易計算
    static func calculate(dailyEarnings: Int) -> WithholdingTaxCalculation {
        // 日額9,800円以下は非課税
        guard dailyEarnings > 9800 else {
            return WithholdingTaxCalculation(
                grossEarnings: dailyEarnings,
                taxAmount: 0,
                netEarnings: dailyEarnings,
                taxRate: 0,
                isApplicable: false
            )
        }

        // 乙欄適用（日雇い・短期アルバイト向け）
        let taxableAmount = dailyEarnings - 9800
        let taxRate = 0.03102 // 3.102%（復興特別所得税含む）
        let taxAmount = Int(Double(taxableAmount) * taxRate)

        return WithholdingTaxCalculation(
            grossEarnings: dailyEarnings,
            taxAmount: taxAmount,
            netEarnings: dailyEarnings - taxAmount,
            taxRate: taxRate,
            isApplicable: true
        )
    }
}

// MARK: - Schedule Conflict Detection

struct ScheduleConflict {
    let existingJob: Application
    let conflictType: ConflictType

    enum ConflictType {
        case overlap       // 時間帯が重複
        case tooClose      // 移動時間不足（1時間以内）
        case sameDay       // 同日の別勤務あり（警告のみ）

        var message: String {
            switch self {
            case .overlap: return "既存の勤務と時間が重複しています"
            case .tooClose: return "既存の勤務との間隔が1時間未満です（移動時間にご注意ください）"
            case .sameDay: return "同じ日に別の勤務が入っています"
            }
        }

        var severity: ConflictSeverity {
            switch self {
            case .overlap: return .blocking
            case .tooClose: return .warning
            case .sameDay: return .info
            }
        }
    }

    enum ConflictSeverity {
        case blocking  // 応募不可
        case warning   // 警告付きで応募可能
        case info      // 情報のみ
    }
}

// MARK: - Job Alert

struct JobAlert: Codable, Identifiable {
    let id: String
    var keyword: String?
    var minWage: Int?
    var maxWage: Int?
    var categories: [String]?
    var areas: [String]?
    var daysOfWeek: [Int]?  // 0=日, 1=月, ... 6=土
    var timeRange: String?  // "morning", "afternoon", "evening", "night"
    var isEnabled: Bool

    static let timeRanges: [(id: String, label: String, hours: String)] = [
        ("morning", "朝", "6:00-12:00"),
        ("afternoon", "昼", "12:00-18:00"),
        ("evening", "夕方", "18:00-22:00"),
        ("night", "夜", "22:00-6:00"),
    ]
}

// MARK: - Saved Search

struct SavedSearch: Codable, Identifiable {
    let id: String
    let name: String
    let keyword: String?
    let filters: SearchFilters
    let createdAt: String?
    let resultCount: Int?
}

struct SearchFilters: Codable {
    let area: String?
    let minWage: Int?
    let maxWage: Int?
    let category: String?
    let dateFrom: String?
    let dateTo: String?
    let sortBy: String?
}

// MARK: - Bulk Message

struct BulkMessage: Codable {
    let recipientIds: [String]
    let message: String
    let jobId: String?
}

// MARK: - Work Certificate (就業証明書)

struct WorkCertificate: Codable, Identifiable {
    let id: String
    let workerId: String
    let workerName: String
    let employerName: String
    let jobTitle: String
    let workDate: String
    let checkInTime: String?
    let checkOutTime: String?
    let totalHours: Double?
    let earnings: Int?
    let status: String
    let issuedAt: String?
    let certificateNumber: String?
}

struct WorkCertificateListResponse: Codable {
    let certificates: [WorkCertificate]
}

// MARK: - CSV Export

struct ExportRequest {
    let type: ExportType
    let dateFrom: Date
    let dateTo: Date

    enum ExportType: String, CaseIterable {
        case attendance = "attendance"
        case payment = "payment"
        case workers = "workers"

        var displayName: String {
            switch self {
            case .attendance: return "勤怠データ"
            case .payment: return "支払データ"
            case .workers: return "ワーカーリスト"
            }
        }

        var icon: String {
            switch self {
            case .attendance: return "clock"
            case .payment: return "yensign.circle"
            case .workers: return "person.3"
            }
        }
    }
}

// MARK: - Dispute (紛争)

struct Dispute: Codable, Identifiable {
    let id: String
    let reportId: String?
    let workHistoryId: String?
    let jobId: String?
    let workerId: String?
    let employerId: String?
    let workerName: String?
    let employerName: String?
    let jobTitle: String?
    let type: String?
    let reason: String?
    let description: String?
    let workerClaim: String?
    let employerClaim: String?
    let status: String?
    let resolution: String?
    let adminNote: String?
    let amount: Int?
    let resolvedAmount: Int?
    let createdAt: String?
    let resolvedAt: String?

    var statusDisplay: String {
        switch status {
        case "open": return "未対応"
        case "investigating": return "調査中"
        case "awaiting_response": return "回答待ち"
        case "resolved": return "解決済み"
        case "escalated": return "エスカレーション"
        case "closed": return "クローズ"
        default: return status ?? "不明"
        }
    }

    var typeDisplay: String {
        switch type {
        case "payment": return "支払い紛争"
        case "no_show": return "無断欠勤"
        case "work_quality": return "業務品質"
        case "harassment": return "ハラスメント"
        case "time_dispute": return "勤務時間相違"
        case "cancellation": return "キャンセル"
        default: return type ?? "その他"
        }
    }
}

struct DisputeListResponse: Codable {
    let disputes: [Dispute]
    let total: Int?
}
