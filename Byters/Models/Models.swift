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
    let startTime: String?
    let endTime: String?
    let requiredPeople: Int?
    let currentApplicants: Int?
    let status: String?
    let categories: [String]?
    let requirements: String?
    let benefits: String?
    let imageUrl: String?
    let createdAt: String?

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
        case "active": return "公開中"
        case "draft": return "下書き"
        case "closed": return "終了"
        case "pending": return "審査中"
        default: return status ?? ""
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
    let createdAt: String?
    let updatedAt: String?

    var statusDisplay: String {
        switch status {
        case "pending": return "審査中"
        case "accepted": return "承認済み"
        case "rejected": return "不採用"
        case "canceled": return "キャンセル"
        case "completed": return "完了"
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
    let businessName: String?
    let description: String?
    let prefecture: String?
    let city: String?
    let address: String?
    let categories: [String]?
    let contactPhone: String?
    let contactEmail: String?
    let logoUrl: String?
    let coverImageUrl: String?
    let createdAt: String?
    let totalJobs: Int?
    let totalHires: Int?
    let averageRating: Double?
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
        Prefecture(id: "tokyo", name: "東京都"),
        Prefecture(id: "kanagawa", name: "神奈川県"),
        Prefecture(id: "osaka", name: "大阪府"),
        Prefecture(id: "aichi", name: "愛知県"),
        Prefecture(id: "fukuoka", name: "福岡県"),
        Prefecture(id: "saitama", name: "埼玉県"),
        Prefecture(id: "chiba", name: "千葉県"),
        Prefecture(id: "hyogo", name: "兵庫県"),
        Prefecture(id: "kyoto", name: "京都府")
        // Add more as needed
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
    let message: String?
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
}
