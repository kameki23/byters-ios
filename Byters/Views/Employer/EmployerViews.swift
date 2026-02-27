import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins

// MARK: - Employer Dashboard

struct EmployerDashboardView: View {
    @StateObject private var viewModel = EmployerDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                            Button("再試行") {
                                Task { await viewModel.loadData() }
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                        .padding(.horizontal)
                    }

                    // Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "掲載中",
                            value: "\(viewModel.stats?.activeJobs ?? 0)",
                            icon: "doc.text.fill",
                            color: .blue
                        )
                        StatCard(
                            title: "応募者",
                            value: "\(viewModel.stats?.totalApplicants ?? 0)",
                            icon: "person.2.fill",
                            color: .green
                        )
                        StatCard(
                            title: "今月の採用",
                            value: "\(viewModel.stats?.thisMonthHires ?? 0)",
                            icon: "checkmark.circle.fill",
                            color: .purple
                        )
                        StatCard(
                            title: "評価",
                            value: String(format: "%.1f", viewModel.stats?.averageRating ?? 0),
                            icon: "star.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // Pending Applications Alert
                    if let pending = viewModel.stats?.pendingApplications, pending > 0 {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.orange)
                            Text("\(pending)件の未対応の応募があります")
                                .font(.subheadline)
                            Spacer()
                            NavigationLink(destination: EmployerApplicationsView()) {
                                Text("確認")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("クイックアクション")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 16) {
                            NavigationLink(destination: JobCreateView()) {
                                EmployerQuickActionButton(title: "求人作成", icon: "plus.circle.fill", color: .blue)
                            }
                            NavigationLink(destination: EmployerApplicationsView()) {
                                EmployerQuickActionButton(title: "応募確認", icon: "bell.fill", color: .orange)
                            }
                        }
                        .padding(.horizontal)

                        HStack(spacing: 16) {
                            NavigationLink(destination: JobTemplatesView()) {
                                EmployerQuickActionButton(title: "テンプレート", icon: "doc.on.doc.fill", color: .purple)
                            }
                            NavigationLink(destination: TimesheetBulkApprovalView()) {
                                EmployerQuickActionButton(title: "勤怠一括承認", icon: "checkmark.circle.fill", color: .green)
                            }
                        }
                        .padding(.horizontal)

                        NavigationLink(destination: ReliableWorkersView()) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .foregroundColor(.blue)
                                Text("信頼できるワーカー一覧")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        NavigationLink(destination: EmployerAttendanceDashboardView()) {
                            HStack {
                                Image(systemName: "person.badge.clock")
                                    .foregroundColor(.green)
                                Text("出勤ダッシュボード")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        NavigationLink(destination: EmployerInvoiceView()) {
                            HStack {
                                Image(systemName: "doc.text.below.ecg")
                                    .foregroundColor(.purple)
                                Text("請求・支払管理")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        HStack(spacing: 16) {
                            NavigationLink(destination: BulkMessageView(jobId: nil)) {
                                EmployerQuickActionButton(title: "一括メッセージ", icon: "paperplane.fill", color: .teal)
                            }
                            NavigationLink(destination: CSVExportView()) {
                                EmployerQuickActionButton(title: "データ出力", icon: "square.and.arrow.up", color: .indigo)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Recent Jobs
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最近の求人")
                                .font(.headline)
                            Spacer()
                            NavigationLink(destination: EmployerJobsView()) {
                                Text("すべて見る")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        if viewModel.recentJobs.isEmpty {
                            Text("まだ求人がありません")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(viewModel.recentJobs.prefix(3)) { job in
                                EmployerJobCard(job: job)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ダッシュボード")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct EmployerJobCard: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(job.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(job.status == "active" ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundColor(job.status == "active" ? .green : .gray)
                    .clipShape(Capsule())
            }

            HStack {
                Label(job.wageDisplay, systemImage: "yensign.circle")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()

                if let applicants = job.currentApplicants {
                    Label("\(applicants)名応募", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
class EmployerDashboardViewModel: ObservableObject {
    @Published var stats: EmployerStats?
    @Published var recentJobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            stats = try await api.getEmployerStats()
            recentJobs = try await api.getEmployerJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct EmployerQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Employer Jobs

struct EmployerJobsView: View {
    @StateObject private var viewModel = EmployerJobsViewModel()
    @State private var showingCreateSheet = false
    @State private var selectedJobForQR: Job?
    @State private var repostTargetJob: Job?
    @State private var showRepostSheet = false
    @State private var showLimitAlert = false
    @State private var duplicateTargetJob: Job?

    private let maxActiveJobs = 3

    private var activeJobs: [Job] {
        viewModel.jobs.filter { $0.status == "active" || $0.status == "recruiting" }
    }
    private var draftJobs: [Job] {
        viewModel.jobs.filter { $0.status == "draft" }
    }
    private var closedJobs: [Job] {
        viewModel.jobs.filter { $0.status == "closed" || $0.status == "expired" }
    }

    private var canCreateNewJob: Bool {
        activeJobs.count < maxActiveJobs
    }

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                if !canCreateNewJob {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("掲載中の求人が上限（\(maxActiveJobs)件）に達しています")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
                activeJobsSection
                draftJobsSection
                closedJobsSection
                emptySection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("求人管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if canCreateNewJob {
                        showingCreateSheet = true
                    } else {
                        showLimitAlert = true
                    }
                }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新しい求人を作成")
            }
        }
        .alert("投稿上限", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("掲載中の求人は最大\(maxActiveJobs)件までです。新しい求人を作成するには、既存の求人を終了してください。")
        }
        .sheet(isPresented: $showingCreateSheet) {
            JobCreateView(onSuccess: {
                Task { await viewModel.loadData() }
            })
        }
        .sheet(item: $selectedJobForQR) { job in
            JobQRCodeView(job: job)
        }
        .sheet(isPresented: $showRepostSheet) {
            if let job = repostTargetJob {
                RepostJobSheet(job: job, onSuccess: {
                    Task { await viewModel.loadData() }
                })
            }
        }
        .sheet(item: $duplicateTargetJob) { job in
            JobCreateView(duplicateFrom: job, onSuccess: {
                Task { await viewModel.loadData() }
            })
        }
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
    }

    @ViewBuilder
    private var activeJobsSection: some View {
        if !activeJobs.isEmpty {
            Section("掲載中") {
                ForEach(activeJobs) { job in
                    ActiveJobRow(job: job, onQR: { selectedJobForQR = job }, onClose: {
                        Task {
                            _ = try? await APIClient.shared.closeJob(jobId: job.id)
                            await viewModel.loadData()
                        }
                    }, onDuplicate: { duplicateTargetJob = job })
                }
            }
        }
    }

    @ViewBuilder
    private var draftJobsSection: some View {
        if !draftJobs.isEmpty {
            Section("下書き") {
                ForEach(draftJobs) { job in
                    NavigationLink(destination: JobEditView(job: job)) {
                        EmployerJobRow(job: job)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var closedJobsSection: some View {
        if !closedJobs.isEmpty {
            Section("終了") {
                ForEach(closedJobs) { job in
                    ClosedJobRow(job: job, onRepost: {
                        repostTargetJob = job
                        showRepostSheet = true
                    }, onDuplicate: { duplicateTargetJob = job })
                }
            }
        }
    }

    @ViewBuilder
    private var emptySection: some View {
        if viewModel.jobs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("求人がありません")
                    .foregroundColor(.gray)
                Button("求人を作成") { showingCreateSheet = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

// MARK: - Active Job Row

struct ActiveJobRow: View {
    let job: Job
    let onQR: () -> Void
    let onClose: () -> Void
    var onDuplicate: (() -> Void)? = nil

    var body: some View {
        EmployerJobRow(job: job)
            .swipeActions(edge: .trailing) {
                Button { onQR() } label: {
                    Label("QR", systemImage: "qrcode")
                }.tint(.blue)
                Button { onClose() } label: {
                    Label("終了", systemImage: "xmark.circle")
                }.tint(.orange)
            }
            .contextMenu {
                Button { onQR() } label: {
                    Label("チェックインQR表示", systemImage: "qrcode")
                }
                Button { onDuplicate?() } label: {
                    Label("求人を複製", systemImage: "doc.on.doc")
                }
                Button { onClose() } label: {
                    Label("募集を終了", systemImage: "xmark.circle")
                }
            }
    }
}

// MARK: - Closed Job Row

struct ClosedJobRow: View {
    let job: Job
    let onRepost: () -> Void
    var onDuplicate: (() -> Void)? = nil

    var body: some View {
        EmployerJobRow(job: job)
            .swipeActions(edge: .trailing) {
                Button { onRepost() } label: {
                    Label("再投稿", systemImage: "arrow.clockwise")
                }.tint(.green)
            }
            .contextMenu {
                Button { onRepost() } label: {
                    Label("再投稿する", systemImage: "arrow.clockwise")
                }
                Button { onDuplicate?() } label: {
                    Label("求人を複製", systemImage: "doc.on.doc")
                }
            }
    }
}

// MARK: - Repost Job Sheet

struct RepostJobSheet: View {
    let job: Job
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var workDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("求人を再投稿")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(job.title)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("新しい勤務日") {
                    DatePicker("勤務日", selection: $workDate, in: Date()..., displayedComponents: .date)
                }

                Section("求人情報（前回と同じ）") {
                    LabeledContent("時給", value: "¥\(job.hourlyRate ?? 0)")
                    LabeledContent("勤務時間", value: job.workTime ?? "未設定")
                    LabeledContent("募集人数", value: "\(job.requiredPeople ?? 1)名")
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }

                Section {
                    Button(action: repost) {
                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else {
                            HStack {
                                Spacer()
                                Label("再投稿する", systemImage: "paperplane.fill")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func repost() {
        isLoading = true
        errorMessage = nil
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: workDate)

        Task {
            do {
                _ = try await APIClient.shared.repostJob(
                    jobId: job.id,
                    workDate: dateStr,
                    hourlyRate: job.hourlyRate,
                    requiredPeople: job.requiredPeople
                )
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "再投稿に失敗しました"
                }
            }
        }
    }
}

// MARK: - Job QR Code View

struct JobQRCodeView: View {
    let job: Job
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = JobQRCodeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(job.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(width: 200, height: 200)
                } else if let qrImage = viewModel.qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text("QRコードを生成できません")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 250, height: 250)
                }

                VStack(spacing: 8) {
                    Text("出勤チェックイン用QRコード")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("従業員にこのQRコードをスキャンしてもらい\n出勤を記録します")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if let token = viewModel.checkInToken {
                    HStack {
                        Text("コード: \(token.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Button(action: {
                            UIPasteboard.general.string = token
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button(action: {
                    Task {
                        await viewModel.regenerateQR(jobId: job.id)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("QRコードを再生成")
                    }
                    .foregroundColor(.blue)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("チェックインQR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.qrImage != nil {
                        ShareLink(item: Image(uiImage: viewModel.qrImage!), preview: SharePreview("QRコード", image: Image(uiImage: viewModel.qrImage!)))
                    }
                }
            }
        }
        .task {
            await viewModel.loadQR(jobId: job.id)
        }
    }
}

@MainActor
class JobQRCodeViewModel: ObservableObject {
    @Published var qrImage: UIImage?
    @Published var checkInToken: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadQR(jobId: String) async {
        isLoading = true
        do {
            let response = try await api.getJobQRCode(jobId: jobId)
            checkInToken = response.token
            qrImage = generateQRCode(from: "\(jobId)|\(response.token)")
        } catch {
            qrImage = generateQRCode(from: jobId)
            errorMessage = "QRコードの取得に失敗しました。再生成してください。"
        }
        isLoading = false
    }

    func regenerateQR(jobId: String) async {
        isLoading = true
        do {
            let response = try await api.regenerateJobQRCode(jobId: jobId)
            checkInToken = response.token
            qrImage = generateQRCode(from: "\(jobId)|\(response.token)")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }

        return nil
    }
}

struct EmployerJobRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.title)
                    .font(.headline)
                Spacer()
                Text(job.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            HStack {
                Text(job.wageDisplay)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()

                if let count = job.currentApplicants, count > 0 {
                    Text("応募者: \(count)名")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            if let date = job.workDate {
                Text("勤務日: \(date)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }

    var statusColor: Color {
        switch job.status {
        case "active", "recruiting": return .green
        case "draft": return .orange
        case "closed", "expired": return .gray
        default: return .gray
        }
    }

    var statusText: String {
        switch job.status {
        case "active", "recruiting": return "掲載中"
        case "draft": return "下書き"
        case "closed": return "終了"
        case "expired": return "期限切れ"
        default: return job.status ?? "不明"
        }
    }
}

@MainActor
class EmployerJobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            jobs = try await api.getEmployerJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Job Create View

struct JobCreateView: View {
    @Environment(\.dismiss) var dismiss
    var duplicateFrom: Job? = nil
    var onSuccess: (() -> Void)? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var prefecture = ""
    @State private var city = ""
    @State private var address = ""
    @State private var hourlyWage = ""
    @State private var workDateStart = Date()
    @State private var workDateEnd = Date()
    @State private var isMultiDay = false
    @State private var startTime = "09:00"
    @State private var endTime = "18:00"
    @State private var requiredPeople = "1"
    @State private var requirements = ""
    @State private var benefits = ""
    @State private var paymentType: PaymentType = .auto
    @State private var isLoading = false
    @State private var errorMessage: String?

    // New fields for Timee parity
    @State private var dressCode = ""
    @State private var smokingPolicy = "屋内全面禁煙"
    @State private var accessDirections = ""
    @State private var autoMessage = ""

    // Recurring job
    @State private var isRecurring = false
    @State private var recurringFrequency: RecurringFrequency = .weekly
    @State private var recurringEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    enum RecurringFrequency: String, CaseIterable {
        case daily = "毎日"
        case weekly = "毎週"
        case biweekly = "隔週"
        case monthly = "毎月"
    }

    // Template selection
    @State private var showTemplateSheet = false
    @State private var selectedIndustry: JobIndustry?
    @State private var selectedRole: JobRole?
    @State private var templateApplied = false

    // Image upload states
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var thumbnailIndex: Int = 0
    @State private var showImageValidationAlert = false
    @State private var imageValidationMessage = ""

    // Platform fee (fetched from backend, default 20%)
    @State private var platformFeePercent: Double = 20.0

    var body: some View {
        NavigationStack {
            Form {
                // Template Quick-Fill Section
                Section {
                    Button(action: { showTemplateSheet = true }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundColor(.blue)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("かんたん自動入力")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text("業種・職種を選ぶだけで内容が自動入力されます")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    if templateApplied, let role = selectedRole {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(role.industry.rawValue) > \(role.rawValue) のテンプレートを適用済み")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                Section("基本情報") {
                    TextField("求人タイトル", text: $title)
                        .submitLabel(.done)
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 100 { title = String(newValue.prefix(100)) }
                        }

                    if let titleErr = ValidationHelper.textLengthError(title, maxLength: 100, fieldName: "タイトル") {
                        Text(titleErr)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    TextEditor(text: $description)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("仕事内容の詳細")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                        .onChange(of: description) { _, newValue in
                            if newValue.count > 2000 { description = String(newValue.prefix(2000)) }
                        }
                    Text("\(description.count)/2000")
                        .font(.caption2)
                        .foregroundColor(description.count > 1800 ? .orange : .gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Image Upload Section
                Section("写真（最大5枚）") {
                    if selectedImages.isEmpty {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("写真を追加")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(thumbnailIndex == index ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                            .onTapGesture {
                                                thumbnailIndex = index
                                            }

                                        Button(action: {
                                            selectedImages.remove(at: index)
                                            selectedPhotos.remove(at: index)
                                            if thumbnailIndex >= selectedImages.count {
                                                thumbnailIndex = max(0, selectedImages.count - 1)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.red))
                                        }
                                        .offset(x: 8, y: -8)

                                        if thumbnailIndex == index {
                                            Text("表紙")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .clipShape(Capsule())
                                                .offset(y: 80)
                                        }
                                    }
                                }

                                if selectedImages.count < 5 {
                                    PhotosPicker(
                                        selection: $selectedPhotos,
                                        maxSelectionCount: 5,
                                        matching: .images
                                    ) {
                                        VStack {
                                            Image(systemName: "plus")
                                                .font(.title2)
                                            Text("追加")
                                                .font(.caption)
                                        }
                                        .frame(width: 100, height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        Text("タップして表紙に設定")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .onChange(of: selectedPhotos) { _, newItems in
                    Task {
                        selectedImages = []
                        for item in newItems {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                // Validate file size (max 10MB)
                                let maxSize = 10 * 1024 * 1024 // 10MB in bytes
                                if data.count > maxSize {
                                    imageValidationMessage = "画像サイズが大きすぎます。最大10MBまでです。"
                                    showImageValidationAlert = true
                                    continue
                                }

                                // Validate file format (JPEG, PNG)
                                guard let image = UIImage(data: data) else {
                                    imageValidationMessage = "サポートされていない画像形式です。JPEG、PNGのみ対応しています。"
                                    showImageValidationAlert = true
                                    continue
                                }

                                selectedImages.append(image)
                            }
                        }
                    }
                }

                Section("勤務地") {
                    Picker("都道府県", selection: $prefecture) {
                        Text("選択してください").tag("")
                        ForEach(Prefecture.all) { pref in
                            Text(pref.name).tag(pref.name)
                        }
                    }
                    TextField("市区町村", text: $city)
                        .submitLabel(.done)
                    TextField("詳細住所", text: $address)
                        .submitLabel(.done)
                }

                Section("勤務条件") {
                    HStack {
                        Text("時給")
                        Spacer()
                        TextField("1200", text: $hourlyWage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("円")
                    }

                    if let wageErr = ValidationHelper.wageError(hourlyWage) {
                        Text(wageErr)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Toggle("複数日募集", isOn: $isMultiDay)

                    DatePicker("開始日", selection: $workDateStart, in: Date()..., displayedComponents: .date)

                    if isMultiDay {
                        DatePicker("終了日", selection: $workDateEnd, in: workDateStart..., displayedComponents: .date)
                            .onChange(of: workDateStart) { _, newValue in
                                if workDateEnd < newValue {
                                    workDateEnd = newValue
                                }
                            }
                    }

                    HStack {
                        Text("開始時間")
                        Spacer()
                        TextField("09:00", text: $startTime)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    if let timeErr = ValidationHelper.timeFormatError(startTime) {
                        Text(timeErr)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    HStack {
                        Text("終了時間")
                        Spacer()
                        TextField("18:00", text: $endTime)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    if let timeErr = ValidationHelper.timeFormatError(endTime) {
                        Text(timeErr)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    HStack {
                        Text("募集人数")
                        Spacer()
                        TextField("1", text: $requiredPeople)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("名")
                    }
                }

                // Recurring Job Section
                Section("定期求人") {
                    Toggle("定期的に繰り返す", isOn: $isRecurring)

                    if isRecurring {
                        Picker("頻度", selection: $recurringFrequency) {
                            ForEach(RecurringFrequency.allCases, id: \.rawValue) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }

                        DatePicker("繰り返し終了日", selection: $recurringEndDate, in: workDateStart..., displayedComponents: .date)

                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("選択した頻度で自動的に求人が再投稿されます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Payment Type Section
                Section("支払い方式") {
                    Picker("支払い方式", selection: $paymentType) {
                        ForEach(PaymentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        Image(systemName: paymentType == .auto ? "bolt.fill" : "pencil.and.list.clipboard")
                            .foregroundColor(paymentType == .auto ? .blue : .orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(paymentType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(paymentType.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Fee Breakdown
                if let wage = Int(hourlyWage), wage > 0 {
                    Section("費用見積もり") {
                        let estimatedHours = calculateHours()
                        let workerPay = wage * estimatedHours
                        let feeRate = platformFeePercent / 100.0
                        let fee = Int(Double(workerPay) * feeRate)
                        let totalPerPerson = workerPay + fee
                        let people = Int(requiredPeople) ?? 1
                        let feeDisplay = platformFeePercent.truncatingRemainder(dividingBy: 1) == 0
                            ? String(format: "%.0f", platformFeePercent)
                            : String(format: "%.1f", platformFeePercent)

                        LabeledContent("労働者報酬", value: "¥\(workerPay.formatted())")
                        LabeledContent("手数料（\(feeDisplay)%）", value: "¥\(fee.formatted())")
                            .foregroundColor(.orange)
                        LabeledContent("1人あたり合計", value: "¥\(totalPerPerson.formatted())")
                            .fontWeight(.semibold)
                        if people > 1 {
                            LabeledContent("総額（\(people)名）", value: "¥\((totalPerPerson * people).formatted())")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        Text("※ 手数料はプラットフォーム利用料です")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Section("応募条件（任意）") {
                    TextEditor(text: $requirements)
                        .frame(height: 80)
                        .overlay(
                            Group {
                                if requirements.isEmpty {
                                    Text("例：未経験歓迎 / 18歳以上 / 日本語での接客が可能な方")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                Section("待遇・福利厚生（任意）") {
                    TextEditor(text: $benefits)
                        .frame(height: 80)
                        .overlay(
                            Group {
                                if benefits.isEmpty {
                                    Text("例：交通費支給 / まかない付き / 制服貸与")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                Section(header: Text("服装規定"), footer: Text("ワーカーが当日の準備をしやすくなります")) {
                    TextEditor(text: $dressCode)
                        .frame(height: 60)
                        .overlay(
                            Group {
                                if dressCode.isEmpty {
                                    Text("例：制服貸与 / 黒いパンツ・靴は持参")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                Section("受動喫煙対策") {
                    Picker("喫煙対策", selection: $smokingPolicy) {
                        Text("屋内全面禁煙").tag("屋内全面禁煙")
                        Text("屋内全面禁煙（喫煙所あり）").tag("屋内全面禁煙（屋外喫煙所あり）")
                        Text("分煙").tag("分煙")
                        Text("喫煙可").tag("喫煙可")
                    }
                }

                Section(header: Text("アクセス・集合場所"), footer: Text("最寄駅からの行き方や集合場所を記載すると到着がスムーズです")) {
                    TextEditor(text: $accessDirections)
                        .frame(height: 80)
                        .overlay(
                            Group {
                                if accessDirections.isEmpty {
                                    Text("例：JR〇〇駅北口から徒歩5分。ビル裏のスタッフ入口から入ってください。")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                Section(header: Text("承認後の自動メッセージ"), footer: Text("応募を承認したとき自動でワーカーに送信されます")) {
                    TextEditor(text: $autoMessage)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if autoMessage.isEmpty {
                                    Text("例：ご応募ありがとうございます！当日は黒いパンツと靴でお越しください。集合場所は...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: createJob) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("求人を作成")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(duplicateFrom != nil ? "求人を複製" : "求人作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("画像エラー", isPresented: $showImageValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(imageValidationMessage)
            }
            .sheet(isPresented: $showTemplateSheet) {
                JobTemplateSelectionSheet(onSelect: { role in
                    applyTemplate(role)
                    showTemplateSheet = false
                })
            }
            .onAppear {
                if let job = duplicateFrom {
                    title = job.title + "（コピー）"
                    description = job.description ?? ""
                    prefecture = job.prefecture ?? ""
                    city = job.city ?? ""
                    address = job.address ?? ""
                    if let hw = job.hourlyWage { hourlyWage = String(hw) }
                    startTime = job.startTime ?? "09:00"
                    endTime = job.endTime ?? "18:00"
                    requiredPeople = String(job.requiredPeople ?? 1)
                    requirements = job.requirements ?? ""
                    benefits = job.benefits ?? ""
                }
            }
        }
    }

    private func applyTemplate(_ role: JobRole) {
        let t = JobPostTemplate.template(for: role)
        selectedRole = role
        selectedIndustry = role.industry
        title = t.title
        description = t.description
        requirements = t.requirements
        benefits = t.benefits
        dressCode = t.dressCode
        smokingPolicy = t.smokingPolicy
        hourlyWage = String(t.defaultWage)
        startTime = t.startTime
        endTime = t.endTime
        autoMessage = t.autoMessage
        templateApplied = true
    }

    var isValid: Bool {
        !title.isEmpty && title.count <= 100 &&
        !description.isEmpty && description.count <= 2000 &&
        !prefecture.isEmpty && !city.isEmpty &&
        !hourlyWage.isEmpty && ValidationHelper.isValidWage(hourlyWage) &&
        !startTime.isEmpty && ValidationHelper.isValidTimeFormat(startTime) &&
        !endTime.isEmpty && ValidationHelper.isValidTimeFormat(endTime) &&
        !requiredPeople.isEmpty && Int(requiredPeople) != nil
    }

    private func calculateHours() -> Int {
        let parts1 = startTime.split(separator: ":").compactMap { Int($0) }
        let parts2 = endTime.split(separator: ":").compactMap { Int($0) }
        guard parts1.count >= 2, parts2.count >= 2 else { return 8 }
        let start = parts1[0] * 60 + parts1[1]
        let end = parts2[0] * 60 + parts2[1]
        let diff = end > start ? end - start : (end + 24 * 60) - start
        return max(1, diff / 60)
    }

    func createJob() {
        isLoading = true
        errorMessage = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let workDateStr = dateFormatter.string(from: workDateStart)
        let workDateEndStr = isMultiDay ? dateFormatter.string(from: workDateEnd) : nil

        Task {
            do {
                // Convert images to base64
                var imageBase64Strings: [String] = []
                for image in selectedImages {
                    if let data = image.jpegData(compressionQuality: 0.7) {
                        imageBase64Strings.append(data.base64EncodedString())
                    }
                }

                // Build description with dress code and smoking policy
                var fullDescription = description
                if !dressCode.isEmpty {
                    fullDescription += "\n\n【服装規定】\n\(dressCode)"
                }
                fullDescription += "\n\n【受動喫煙対策】\n\(smokingPolicy)"
                if !accessDirections.isEmpty {
                    fullDescription += "\n\n【アクセス・集合場所】\n\(accessDirections)"
                }
                if isRecurring {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy/MM/dd"
                    fullDescription += "\n\n【定期求人】\n頻度: \(recurringFrequency.rawValue) / 終了日: \(df.string(from: recurringEndDate))"
                }

                _ = try await APIClient.shared.createJobWithImages(
                    title: title,
                    description: fullDescription,
                    prefecture: prefecture,
                    city: city,
                    address: address.isEmpty ? nil : address,
                    hourlyWage: Int(hourlyWage),
                    dailyWage: nil,
                    workDate: workDateStr,
                    workDateEnd: workDateEndStr,
                    startTime: startTime,
                    endTime: endTime,
                    requiredPeople: Int(requiredPeople) ?? 1,
                    categories: selectedIndustry != nil ? [selectedIndustry!.rawValue] : nil,
                    requirements: requirements.isEmpty ? nil : requirements,
                    benefits: benefits.isEmpty ? nil : benefits,
                    images: imageBase64Strings,
                    thumbnailIndex: thumbnailIndex,
                    paymentType: paymentType.rawValue
                )
                onSuccess?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Job Template Selection Sheet

struct JobTemplateSelectionSheet: View {
    let onSelect: (JobRole) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedIndustry: JobIndustry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("かんたん自動入力")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("業種と職種を選ぶだけで\n求人内容が自動で入力されます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if selectedIndustry == nil {
                        // Industry Selection Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("業種を選択")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(JobIndustry.allCases) { industry in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedIndustry = industry
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: industry.icon)
                                                .font(.title2)
                                            Text(industry.rawValue)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.blue.opacity(0.08))
                                        .foregroundColor(.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Role Selection for chosen industry
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedIndustry = nil
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("業種を変更")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)

                            HStack {
                                Image(systemName: selectedIndustry!.icon)
                                    .foregroundColor(.blue)
                                Text(selectedIndustry!.rawValue)
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            Text("職種を選択")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            let roles = JobRole.roles(for: selectedIndustry!)
                            ForEach(roles) { role in
                                Button(action: { onSelect(role) }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(role.rawValue)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            let t = JobPostTemplate.template(for: role)
                                            Text("時給 ¥\(t.defaultWage) / \(t.startTime)〜\(t.endTime)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("テンプレート選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Job Edit View

struct JobEditView: View {
    let job: Job
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var description: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    init(job: Job) {
        self.job = job
        _title = State(initialValue: job.title)
        _description = State(initialValue: job.description ?? "")
    }

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("タイトル", text: $title)
                TextEditor(text: $description)
                    .frame(height: 100)
            }

            Section("詳細") {
                LabeledContent("時給", value: job.wageDisplay)
                LabeledContent("勤務地", value: job.locationDisplay)
                LabeledContent("勤務時間", value: job.timeDisplay)
                if let date = job.workDate {
                    LabeledContent("勤務日", value: date)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            if job.status == "draft" {
                Section {
                    Button("公開する") {
                        publishJob()
                    }
                    .foregroundColor(.green)
                    .disabled(isLoading)
                }
            }

            Section {
                Button("削除", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(isLoading)
            }
        }
        .navigationTitle("求人編集")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveJob()
                }
                .disabled(isLoading || title.isEmpty)
            }
        }
        .alert("求人を削除", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                deleteJob()
            }
        } message: {
            Text("この求人を削除しますか？この操作は取り消せません。")
        }
    }

    func saveJob() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                var updates: [String: Any] = ["title": title]
                if !description.isEmpty {
                    updates["description"] = description
                }
                _ = try await APIClient.shared.updateJob(jobId: job.id, updates: updates)
                dismiss()
            } catch {
                errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func publishJob() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIClient.shared.publishJob(jobId: job.id)
                dismiss()
            } catch {
                errorMessage = "公開に失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func deleteJob() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIClient.shared.deleteJob(jobId: job.id)
                dismiss()
            } catch {
                errorMessage = "削除に失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - Employer Applications

struct EmployerApplicationsView: View {
    @StateObject private var viewModel = EmployerApplicationsViewModel()
    @State private var noShowTargetApplication: Application?
    @State private var showNoShowConfirmation = false
    @State private var noShowSuccessMessage: String?

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                if let successMsg = noShowSuccessMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMsg)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Pending Applications
                let pending = viewModel.applications.filter { $0.status == "pending" }
                if !pending.isEmpty {
                    Section("未対応") {
                        ForEach(pending) { application in
                            ApplicationReviewRow(
                                application: application,
                                onApprove: { await viewModel.approve(application) },
                                onReject: { await viewModel.reject(application) }
                            )
                        }
                    }
                }

                // Accepted Applications
                let accepted = viewModel.applications.filter { $0.status == "accepted" }
                if !accepted.isEmpty {
                    Section("承認済み") {
                        ForEach(accepted) { application in
                            AcceptedApplicationRow(
                                application: application,
                                onReportNoShow: {
                                    noShowTargetApplication = application
                                    showNoShowConfirmation = true
                                }
                            )
                        }
                    }
                }

                // Other Applications
                let others = viewModel.applications.filter { $0.status != "pending" && $0.status != "accepted" }
                if !others.isEmpty {
                    Section("その他") {
                        ForEach(others) { application in
                            ApplicationInfoRow(application: application)
                        }
                    }
                }

                if viewModel.applications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("応募はまだありません")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("応募者管理")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
        .alert("無断欠勤を報告", isPresented: $showNoShowConfirmation) {
            Button("報告する", role: .destructive) {
                if let application = noShowTargetApplication {
                    Task {
                        await viewModel.reportNoShow(application)
                        noShowSuccessMessage = "\(application.applicantName ?? "ワーカー")の無断欠勤を報告しました"
                        // Auto-dismiss success message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            noShowSuccessMessage = nil
                        }
                    }
                }
            }
            Button("キャンセル", role: .cancel) {
                noShowTargetApplication = nil
            }
        } message: {
            if let application = noShowTargetApplication {
                Text("\(application.applicantName ?? "このワーカー")がチェックインせずに欠勤したことを報告しますか？\n\nこの操作はワーカーのペナルティに影響します。")
            }
        }
    }
}

struct AcceptedApplicationRow: View {
    let application: Application
    let onReportNoShow: () -> Void

    private var hasCheckedIn: Bool {
        application.checkInTime != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ApplicationInfoRow(application: application)

            if !hasCheckedIn {
                Button(action: onReportNoShow) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("無断欠勤を報告")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

struct ApplicationReviewRow: View {
    let application: Application
    let onApprove: () async -> Void
    let onReject: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.applicantName ?? "応募者")
                        .font(.headline)
                    Text(application.jobTitle ?? "求人")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
            }

            if let message = application.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Button(action: {
                    isProcessing = true
                    Task {
                        await onApprove()
                        isProcessing = false
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("承認")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isProcessing)

                Button(action: {
                    isProcessing = true
                    Task {
                        await onReject()
                        isProcessing = false
                    }
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("却下")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isProcessing)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 8)
    }
}

struct ApplicationInfoRow: View {
    let application: Application

    var statusColor: Color {
        switch application.status {
        case "accepted": return .green
        case "rejected": return .red
        case "completed": return .blue
        default: return .gray
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(application.applicantName ?? "応募者")
                        .font(.headline)
                    if application.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                Text(application.jobTitle ?? "求人")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Worker stats
                HStack(spacing: 8) {
                    if let rate = application.goodRate, rate > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 9))
                            Text("\(rate)%")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(rate >= 80 ? .green : .orange)
                    }
                    if let count = application.completedJobs, count > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "briefcase.fill")
                                .font(.system(size: 9))
                            Text("\(count)件完了")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            Text(application.statusDisplay)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
        }
    }
}

@MainActor
class EmployerApplicationsViewModel: ObservableObject {
    @Published var applications: [Application] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            applications = try await api.getEmployerApplications()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func approve(_ application: Application) async {
        do {
            _ = try await api.approveApplication(applicationId: application.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await loadData()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = error.localizedDescription
        }
    }

    func reject(_ application: Application) async {
        do {
            _ = try await api.rejectApplication(applicationId: application.id, reason: nil)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            await loadData()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = error.localizedDescription
        }
    }

    func reportNoShow(_ application: Application) async {
        do {
            _ = try await api.reportNoShow(applicationId: application.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await loadData()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = "無断欠勤の報告に失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - Employer Settings

struct EmployerSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountFinalConfirm = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("会社情報") {
                    NavigationLink(destination: CompanyProfileEditView()) {
                        Label("会社プロフィール", systemImage: "building.2.fill")
                    }
                }

                Section("決済・収支") {
                    NavigationLink(destination: PaymentMethodsView()) {
                        Label("クレジットカード", systemImage: "creditcard.fill")
                    }

                    NavigationLink(destination: PaymentHistoryView()) {
                        Label("支払い履歴", systemImage: "list.bullet.rectangle")
                    }

                    NavigationLink(destination: EmployerFinanceReportView()) {
                        Label("収支レポート", systemImage: "chart.bar.fill")
                    }

                    NavigationLink(destination: EmployerInvoiceView()) {
                        Label("請求・支払管理", systemImage: "doc.text.below.ecg")
                    }
                }

                Section("勤怠") {
                    NavigationLink(destination: EmployerTimesheetView()) {
                        Label("勤怠管理", systemImage: "clock.badge.checkmark")
                    }

                    NavigationLink(destination: EmployerAttendanceDashboardView()) {
                        Label("出勤ダッシュボード", systemImage: "person.badge.clock")
                    }

                    NavigationLink(destination: EmployerTimeModificationReviewView()) {
                        Label("時間修正リクエスト", systemImage: "clock.arrow.2.circlepath")
                    }
                }

                Section("ワーカー管理") {
                    NavigationLink(destination: WorkerManagementView()) {
                        Label("お気に入り・ブロック", systemImage: "person.2.fill")
                    }

                    NavigationLink(destination: BulkMessageView(jobId: nil)) {
                        Label("一括メッセージ", systemImage: "paperplane.fill")
                    }
                }

                Section("データ管理") {
                    NavigationLink(destination: CSVExportView()) {
                        Label("データエクスポート", systemImage: "square.and.arrow.up")
                    }
                }

                Section("通知") {
                    NavigationLink(destination: NotificationListView()) {
                        Label("通知一覧", systemImage: "bell.badge.fill")
                    }

                    NavigationLink(destination: QuickNotificationSettingsView()) {
                        Label("通知設定", systemImage: "bell.fill")
                    }
                }

                Section("レビュー") {
                    NavigationLink(destination: EmployerMyReviewsView()) {
                        Label("レビュー一覧", systemImage: "star.bubble.fill")
                    }
                }

                Section("表示") {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("表示設定", systemImage: "moon.fill")
                    }
                }

                Section("その他") {
                    NavigationLink(destination: EmployerPlanView()) {
                        Label("プラン確認", systemImage: "crown.fill")
                    }
                }

                Section {
                    Button(action: { authManager.logout() }) {
                        HStack {
                            Spacer()
                            Text("ログアウト")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }

                Section {
                    Button(action: { showDeleteAccountAlert = true }) {
                        HStack {
                            Spacer()
                            Text("アカウントを削除する")
                                .foregroundColor(.red)
                                .font(.footnote)
                            Spacer()
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Byters for Business")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .alert("アカウント削除", isPresented: $showDeleteAccountAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除する", role: .destructive) {
                    showDeleteAccountFinalConfirm = true
                }
            } message: {
                Text("アカウントを削除すると、すべてのデータが完全に削除され、元に戻すことはできません。本当に削除しますか？")
            }
            .alert("最終確認", isPresented: $showDeleteAccountFinalConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("完全に削除する", role: .destructive) {
                    Task {
                        do {
                            _ = try await APIClient.shared.deleteMyAccount()
                            authManager.logout()
                        } catch {
                            deleteErrorMessage = "アカウント削除に失敗しました: \(error.localizedDescription)"
                        }
                    }
                }
            } message: {
                Text("この操作は取り消せません。アカウントに関連するすべてのデータ（求人、応募者情報、決済情報等）が削除されます。")
            }
            .alert("エラー", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("OK") { deleteErrorMessage = nil }
            } message: {
                Text(deleteErrorMessage ?? "")
            }
        }
    }
}

// MARK: - Company Profile Edit

struct CompanyProfileEditView: View {
    @StateObject private var viewModel = CompanyProfileViewModel()
    @State private var showingSaved = false
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var selectedLogoImage: UIImage?
    @State private var isUploadingLogo = false
    @State private var logoUploadError: String?

    var body: some View {
        Form {
            Section("会社ロゴ") {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        if let image = selectedLogoImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if let logoUrl = viewModel.logoUrl, let url = URL(string: logoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "building.2.fill")
                                            .font(.title)
                                            .foregroundColor(.blue)
                                    )
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "building.2.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                )
                        }

                        if isUploadingLogo {
                            ProgressView("アップロード中...")
                                .font(.caption)
                        } else {
                            PhotosPicker(
                                selection: $selectedLogoItem,
                                matching: .images
                            ) {
                                Text("ロゴを変更")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        if let error = logoUploadError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    Spacer()
                }
            }
            .onChange(of: selectedLogoItem) { _, newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedLogoImage = uiImage
                        await uploadLogo(image: uiImage)
                    }
                }
            }

            Section("基本情報") {
                TextField("会社名", text: $viewModel.businessName)
                    .submitLabel(.done)
                TextEditor(text: $viewModel.description)
                    .frame(height: 100)
            }

            Section("所在地") {
                Picker("都道府県", selection: $viewModel.prefecture) {
                    Text("選択してください").tag("")
                    ForEach(Prefecture.all) { pref in
                        Text(pref.name).tag(pref.name)
                    }
                }
                TextField("市区町村", text: $viewModel.city)
                    .textContentType(.addressCity)
                    .submitLabel(.done)
                TextField("詳細住所", text: $viewModel.address)
                    .textContentType(.streetAddressLine1)
                    .submitLabel(.done)
            }

            Section("連絡先") {
                TextField("電話番号", text: $viewModel.contactPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                if let phoneErr = ValidationHelper.phoneError(viewModel.contactPhone) {
                    Text(phoneErr)
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                TextField("メールアドレス", text: $viewModel.contactEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .submitLabel(.done)

                if let emailErr = ValidationHelper.emailError(viewModel.contactEmail) {
                    Text(emailErr)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section {
                Button(action: {
                    Task {
                        await viewModel.save()
                        showingSaved = true
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("会社プロフィール")
        .alert("保存しました", isPresented: $showingSaved) {
            Button("OK") {}
        }
        .task {
            await viewModel.loadData()
        }
    }

    private func uploadLogo(image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            logoUploadError = "画像の処理に失敗しました"
            return
        }

        let maxSize = 10 * 1024 * 1024
        guard imageData.count <= maxSize else {
            logoUploadError = "画像サイズが大きすぎます（最大10MB）"
            return
        }

        isUploadingLogo = true
        logoUploadError = nil

        do {
            _ = try await APIClient.shared.uploadEmployerLogo(imageData: imageData)
            await viewModel.loadData()
        } catch {
            logoUploadError = "アップロードに失敗しました"
        }

        isUploadingLogo = false
    }
}

@MainActor
class CompanyProfileViewModel: ObservableObject {
    @Published var businessName = ""
    @Published var description = ""
    @Published var prefecture = ""
    @Published var city = ""
    @Published var address = ""
    @Published var contactPhone = ""
    @Published var contactEmail = ""
    @Published var logoUrl: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        do {
            let profile = try await api.getEmployerProfile()
            businessName = profile.businessName ?? ""
            description = profile.description ?? ""
            prefecture = profile.prefecture ?? ""
            city = profile.city ?? ""
            address = profile.address ?? ""
            contactPhone = profile.contactPhone ?? ""
            contactEmail = profile.contactEmail ?? ""
            logoUrl = profile.logoUrl
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isLoading = true
        do {
            _ = try await api.updateEmployerProfile(
                businessName: businessName.isEmpty ? nil : businessName,
                description: description.isEmpty ? nil : description,
                prefecture: prefecture.isEmpty ? nil : prefecture,
                city: city.isEmpty ? nil : city,
                address: address.isEmpty ? nil : address,
                contactPhone: contactPhone.isEmpty ? nil : contactPhone,
                contactEmail: contactEmail.isEmpty ? nil : contactEmail
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Payment Methods

struct PaymentMethodsView: View {
    @StateObject private var viewModel = PaymentMethodsViewModel()
    @State private var showAddCard = false

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.methods.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("カードが登録されていません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.methods) { method in
                    HStack {
                        Image(systemName: cardIcon(for: method.brand))
                            .font(.title2)
                            .foregroundColor(cardColor(for: method.brand))
                            .frame(width: 40)

                        VStack(alignment: .leading) {
                            Text(method.displayText)
                                .font(.headline)
                            Text("有効期限: \(method.expiryDisplay)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if method.isDefault == true {
                            Text("デフォルト")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .swipeActions {
                        if method.isDefault != true {
                            Button("デフォルトに設定") {
                                Task {
                                    await viewModel.setDefault(method: method)
                                }
                            }
                            .tint(.blue)
                        }
                    }
                }
                .onDelete { indexSet in
                    Task {
                        await viewModel.deleteMethod(at: indexSet)
                    }
                }
            }

            if !StripeConfig.isConfigured {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("決済機能が現在利用できません。しばらくしてからお試しください。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Section {
                    Button(action: { showAddCard = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("カードを追加")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("クレジットカード")
        .sheet(isPresented: $showAddCard) {
            AddCardView(onSuccess: {
                showAddCard = false
                Task {
                    await viewModel.loadData()
                }
            })
        }
        .task {
            await viewModel.loadData()
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func cardIcon(for brand: String) -> String {
        switch brand.lowercased() {
        case "visa": return "creditcard.fill"
        case "mastercard": return "creditcard.fill"
        case "amex": return "creditcard.fill"
        case "jcb": return "creditcard.fill"
        default: return "creditcard"
        }
    }

    private func cardColor(for brand: String) -> Color {
        switch brand.lowercased() {
        case "visa": return .blue
        case "mastercard": return .orange
        case "amex": return .green
        case "jcb": return .red
        default: return .gray
        }
    }
}

@MainActor
class PaymentMethodsViewModel: ObservableObject {
    @Published var methods: [PaymentMethod] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            methods = try await api.getPaymentMethods()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteMethod(at indexSet: IndexSet) async {
        let methodsToDelete = indexSet.map { methods[$0] }
        for method in methodsToDelete {
            do {
                _ = try await api.deletePaymentMethod(paymentMethodId: method.id)
            } catch {
                errorMessage = "カードの削除に失敗しました"
                await loadData()
                return
            }
        }
        methods.removeAll { deleted in methodsToDelete.contains { $0.id == deleted.id } }
    }

    func setDefault(method: PaymentMethod) async {
        do {
            _ = try await api.setDefaultPaymentMethod(paymentMethodId: method.id)
            await loadData()
        } catch {
            errorMessage = "デフォルト設定に失敗しました"
        }
    }
}

// MARK: - Add Card View

struct AddCardView: View {
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var cardNumber = ""
    @State private var expiryMonth = ""
    @State private var expiryYear = ""
    @State private var cvc = ""
    @State private var cardholderName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let stripeService = StripeService.shared

    var body: some View {
        NavigationStack {
            Form {
                if StripeConfig.isTestMode {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("テストモード - 実際の課金は発生しません")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section("カード情報") {
                    TextField("カード名義（ローマ字）", text: $cardholderName)
                        .textContentType(.name)
                        .autocapitalization(.allCharacters)

                    TextField("カード番号", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                        .onChange(of: cardNumber) { _, newValue in
                            cardNumber = formatCardNumber(newValue)
                        }

                    HStack {
                        TextField("MM", text: $expiryMonth)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                        Text("/")
                        TextField("YY", text: $expiryYear)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                        Spacer()
                        TextField("CVC", text: $cvc)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                    }
                }

                Section {
                    Text("カード情報はStripeにより安全に処理されます")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: addCard) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("カードを追加")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .navigationTitle("カード追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        let cleanedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        return !cardholderName.isEmpty &&
            cleanedNumber.count >= 15 &&
            cleanedNumber.count <= 16 &&
            expiryMonth.count == 2 &&
            expiryYear.count == 2 &&
            cvc.count >= 3 &&
            cvc.count <= 4 &&
            isValidExpiryDate
    }

    private var isValidExpiryDate: Bool {
        guard let month = Int(expiryMonth),
              let year = Int(expiryYear) else { return false }

        let currentYear = Calendar.current.component(.year, from: Date()) % 100
        let currentMonth = Calendar.current.component(.month, from: Date())

        if month < 1 || month > 12 { return false }
        if year < currentYear { return false }
        if year == currentYear && month < currentMonth { return false }

        return true
    }

    private func formatCardNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "").filter { $0.isNumber }
        var result = ""
        for (index, char) in cleaned.prefix(16).enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }

    private func addCard() {
        guard stripeService.isConfigured else {
            errorMessage = "決済システムが現在利用できません。しばらくしてからお試しください。"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Step 1: Create payment method via Stripe
                guard let expMonth = UInt(expiryMonth),
                      let expYear = UInt(expiryYear) else {
                    throw StripeError.invalidCard
                }

                let paymentMethodId = try await stripeService.createPaymentMethod(
                    cardNumber: cardNumber,
                    expMonth: expMonth,
                    expYear: expYear,
                    cvc: cvc
                )

                // Step 2: Get SetupIntent from backend
                let setupIntent = try await APIClient.shared.createSetupIntent()

                // Step 3: Confirm SetupIntent to save the card
                let confirmed = try await stripeService.confirmSetupIntent(
                    clientSecret: setupIntent.clientSecret,
                    paymentMethodId: paymentMethodId
                )

                if confirmed {
                    // Step 4: Attach the payment method to the customer on backend
                    _ = try await APIClient.shared.attachPaymentMethod(paymentMethodId: paymentMethodId)
                    onSuccess()
                    dismiss()
                } else {
                    throw StripeError.unknownError
                }
            } catch let error as StripeError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "カードの追加に失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - Payment History

struct PaymentHistoryView: View {
    @StateObject private var viewModel = PaymentHistoryViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("支払い履歴はありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transaction.description ?? "支払い")
                                .font(.headline)
                            if let date = transaction.createdAt {
                                Text(formatDate(date))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Text("¥\(transaction.amount.formatted())")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("支払い履歴")
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy/MM/dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

@MainActor
class PaymentHistoryViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            // Filter for payment-type transactions only
            let allTransactions = try await api.getTransactions()
            transactions = allTransactions.filter { $0.type == "payment" || $0.type == "charge" }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// Note: NotificationSettingsView is defined in MyPageView.swift

// MARK: - Finance Report View

struct EmployerFinanceReportView: View {
    @StateObject private var viewModel = EmployerFinanceViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Cards
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        FinanceStatCard(
                            title: "今月の支払い",
                            value: "¥\(viewModel.thisMonthTotal.formatted())",
                            icon: "yensign.circle.fill",
                            color: .blue
                        )
                        FinanceStatCard(
                            title: "今月の雇用数",
                            value: "\(viewModel.thisMonthHires)",
                            icon: "person.2.fill",
                            color: .green
                        )
                    }

                    HStack(spacing: 12) {
                        FinanceStatCard(
                            title: "手数料合計",
                            value: "¥\(viewModel.totalFees.formatted())",
                            icon: "percent",
                            color: .orange
                        )
                        FinanceStatCard(
                            title: "累計支払い",
                            value: "¥\(viewModel.totalPayments.formatted())",
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                    }
                }
                .padding(.horizontal)

                // Monthly Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("月別支払い推移")
                        .font(.headline)

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(viewModel.monthlyData) { month in
                            VStack(spacing: 4) {
                                if month.amount > 0 {
                                    Text("¥\(month.amount / 10000)万")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(month.isCurrentMonth ? Color.blue : Color.blue.opacity(0.3))
                                    .frame(height: barHeight(for: month.amount))

                                Text(month.label)
                                    .font(.caption2)
                                    .foregroundColor(month.isCurrentMonth ? .blue : .gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 150)
                    .padding(.top, 20)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Recent Transactions
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近の取引")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.recentTransactions.isEmpty {
                        Text("まだ取引がありません")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(viewModel.recentTransactions) { transaction in
                            FinanceTransactionRow(transaction: transaction)
                        }
                    }
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("収支レポート")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    private func barHeight(for amount: Int) -> CGFloat {
        let maxAmount = viewModel.monthlyData.map { $0.amount }.max() ?? 1
        guard maxAmount > 0 else { return 10 }
        let ratio = CGFloat(amount) / CGFloat(maxAmount)
        return max(ratio * 100, 10)
    }
}

struct FinanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct FinanceTransactionRow: View {
    let transaction: EmployerTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(transaction.date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("-¥\(transaction.amount.formatted())")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct MonthlyFinanceData: Identifiable {
    let id = UUID()
    let label: String
    let amount: Int
    let isCurrentMonth: Bool
}

struct EmployerTransaction: Identifiable {
    let id: String
    let description: String
    let amount: Int
    let date: String
    let type: String
}

@MainActor
class EmployerFinanceViewModel: ObservableObject {
    @Published var thisMonthTotal: Int = 0
    @Published var thisMonthHires: Int = 0
    @Published var totalFees: Int = 0
    @Published var totalPayments: Int = 0
    @Published var monthlyData: [MonthlyFinanceData] = []
    @Published var recentTransactions: [EmployerTransaction] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true

        // Initialize monthly labels with calendar-based data
        let calendar = Calendar.current
        let now = Date()
        var data: [MonthlyFinanceData] = []

        for i in (0..<6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ja_JP")
                formatter.dateFormat = "M月"
                let label = formatter.string(from: date)

                data.append(MonthlyFinanceData(
                    label: label,
                    amount: 0,
                    isCurrentMonth: i == 0
                ))
            }
        }
        monthlyData = data

        // Load data from API
        do {
            let stats = try await api.getEmployerFinanceStats()
            thisMonthTotal = stats.thisMonthTotal
            thisMonthHires = stats.thisMonthHires
            totalFees = stats.totalFees
            totalPayments = stats.totalPayments

            // Update monthly data with actual values
            if !stats.monthlyBreakdown.isEmpty {
                monthlyData = stats.monthlyBreakdown.suffix(6).enumerated().map { index, item in
                    MonthlyFinanceData(
                        label: item.month,
                        amount: item.amount,
                        isCurrentMonth: index == stats.monthlyBreakdown.count - 1
                    )
                }
            }

            recentTransactions = stats.recentTransactions.map { tx in
                EmployerTransaction(
                    id: tx.id,
                    description: tx.description,
                    amount: tx.amount,
                    date: tx.date,
                    type: tx.type
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Timesheet Management View

struct EmployerTimesheetView: View {
    @StateObject private var viewModel = EmployerTimesheetViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("読み込み中...")
            } else if viewModel.timesheets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("承認待ちの勤怠はありません")
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    ForEach(viewModel.timesheets) { timesheet in
                        TimesheetRow(timesheet: timesheet) { approved in
                            Task {
                                await viewModel.updateTimesheet(id: timesheet.id, approved: approved)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("勤怠管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTimesheets()
        }
        .refreshable {
            await viewModel.loadTimesheets()
        }
    }
}

struct TimesheetRow: View {
    let timesheet: TimesheetEntry
    let onAction: (Bool) -> Void
    @State private var showReviewSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timesheet.workerName)
                        .font(.headline)
                    Text(timesheet.jobTitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(timesheet.statusDisplay)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(timesheet.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(timesheet.statusColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Text(timesheet.isManualPayment ? "実績精算" : "自動支払い")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(timesheet.isManualPayment ? .orange : .blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(timesheet.isManualPayment ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()
            }

            HStack(spacing: 16) {
                Label(timesheet.date, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.gray)

                Label("\(timesheet.checkIn) - \(timesheet.checkOut)", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Text("¥\(timesheet.amount.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }

            if timesheet.status == "pending" {
                HStack(spacing: 12) {
                    Button(action: { onAction(true) }) {
                        Text("承認")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: { onAction(false) }) {
                        Text("修正依頼")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            if timesheet.status == "approved" {
                if timesheet.isManualPayment {
                    NavigationLink(destination: ManualPaymentView(timesheet: timesheet)) {
                        Label("実績精算する", systemImage: "pencil.and.list.clipboard")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                } else {
                    NavigationLink(destination: EmployerCheckoutPaymentView(timesheet: timesheet)) {
                        Label("決済する", systemImage: "creditcard.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            if timesheet.status == "completed" || timesheet.status == "paid" {
                Button(action: { showReviewSheet = true }) {
                    Label("レビューを書く", systemImage: "star.bubble")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showReviewSheet) {
            NavigationStack {
                EmployerWriteReviewView(
                    workerId: timesheet.workerId,
                    workerName: timesheet.workerName,
                    jobId: timesheet.jobId,
                    jobTitle: timesheet.jobTitle,
                    onComplete: { showReviewSheet = false }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { showReviewSheet = false }
                    }
                }
            }
        }
    }
}

struct TimesheetEntry: Identifiable {
    let id: String
    let workerId: String
    let jobId: String
    let workerName: String
    let jobTitle: String
    let date: String
    let checkIn: String
    let checkOut: String
    let amount: Int
    let status: String
    let paymentType: String
    let hourlyWage: Int

    var isManualPayment: Bool { paymentType == "manual" }

    var calculatedWorkedHours: Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let start = formatter.date(from: checkIn),
              let end = formatter.date(from: checkOut) else { return 0 }
        return max(0, end.timeIntervalSince(start) / 3600.0)
    }

    var statusDisplay: String {
        switch status {
        case "pending": return "承認待ち"
        case "approved": return "承認済み"
        case "rejected": return "差戻し"
        default: return status
        }
    }

    var statusColor: Color {
        switch status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

@MainActor
class EmployerTimesheetViewModel: ObservableObject {
    @Published var timesheets: [TimesheetEntry] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadTimesheets() async {
        isLoading = true
        do {
            let data = try await api.getEmployerTimesheets()
            timesheets = data.map { ts in
                TimesheetEntry(
                    id: ts.id,
                    workerId: ts.workerId ?? "",
                    jobId: ts.jobId ?? "",
                    workerName: ts.workerName,
                    jobTitle: ts.jobTitle,
                    date: ts.date,
                    checkIn: ts.checkIn,
                    checkOut: ts.checkOut,
                    amount: ts.amount,
                    status: ts.status,
                    paymentType: ts.paymentType ?? "auto",
                    hourlyWage: ts.hourlyWage ?? 0
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func updateTimesheet(id: String, approved: Bool) async {
        do {
            _ = try await api.updateTimesheet(timesheetId: id, approved: approved)
            await loadTimesheets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Employer Plan Management View

struct EmployerPlanView: View {
    @StateObject private var viewModel = EmployerPlanViewModel()
    @State private var showUpgradeSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let plan = viewModel.currentPlan {
                    // Current Plan Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(plan.planId == "premium" ? .yellow : .blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.planName)
                                    .font(.headline)

                                if plan.isActive {
                                    Text("アクティブ")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("無効")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            Spacer()

                            if let price = plan.monthlyPrice, price > 0 {
                                VStack(alignment: .trailing) {
                                    Text("¥\(price.formatted())")
                                        .font(.headline)
                                    Text("/月")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        if let expires = plan.expiresAt {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.gray)
                                Text("有効期限: \(formatDate(expires))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Divider()

                        // Features
                        VStack(alignment: .leading, spacing: 8) {
                            Text("含まれる機能")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            ForEach(plan.features, id: \.self) { feature in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(feature)
                                        .font(.caption)
                                }
                            }

                            if let maxJobs = plan.maxJobPostings {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("最大\(maxJobs)件の求人掲載")
                                        .font(.caption)
                                }
                            }

                            if let maxApps = plan.maxApplicationsPerJob {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.3.fill")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text("1求人あたり最大\(maxApps)件の応募受付")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)

                    // Upgrade Button
                    if plan.planId != "premium" {
                        Button(action: { showUpgradeSheet = true }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("プレミアムにアップグレード")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }

                    // Cancel Button
                    if plan.isActive && plan.planId != "free" {
                        Button(action: { Task { await viewModel.cancelPlan() } }) {
                            Text("プランを解約")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // No plan info
                    VStack(spacing: 12) {
                        Image(systemName: "crown")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("プラン情報が見つかりません")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }

                // Plan Comparison
                VStack(alignment: .leading, spacing: 16) {
                    Text("プラン比較")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        PlanComparisonRow(
                            planName: "フリー",
                            price: "無料",
                            features: ["月3件まで求人掲載", "基本機能"],
                            isHighlighted: viewModel.currentPlan?.planId == "free"
                        )

                        PlanComparisonRow(
                            planName: "スタンダード",
                            price: "¥9,800/月",
                            features: ["月10件まで求人掲載", "優先サポート", "応募者分析"],
                            isHighlighted: viewModel.currentPlan?.planId == "standard"
                        )

                        PlanComparisonRow(
                            planName: "プレミアム",
                            price: "¥29,800/月",
                            features: ["無制限の求人掲載", "優先表示", "専任サポート", "詳細分析"],
                            isHighlighted: viewModel.currentPlan?.planId == "premium"
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("プラン管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePlanSheet(
                onUpgrade: { planId in
                    Task {
                        await viewModel.upgradePlan(planId: planId)
                        showUpgradeSheet = false
                    }
                }
            )
        }
        .task {
            await viewModel.loadPlan()
        }
        .refreshable {
            await viewModel.loadPlan()
        }
        .alert("エラー", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy年MM月dd日"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct PlanComparisonRow: View {
    let planName: String
    let price: String
    let features: [String]
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(planName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(price)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(feature)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(isHighlighted ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.blue : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct UpgradePlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan = "standard"

    let onUpgrade: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("アップグレード先を選択")
                    .font(.headline)

                VStack(spacing: 16) {
                    PlanSelectionCard(
                        planName: "スタンダード",
                        price: "¥9,800/月",
                        description: "中規模事業者向け",
                        isSelected: selectedPlan == "standard"
                    ) {
                        selectedPlan = "standard"
                    }

                    PlanSelectionCard(
                        planName: "プレミアム",
                        price: "¥29,800/月",
                        description: "大規模事業者向け",
                        isSelected: selectedPlan == "premium"
                    ) {
                        selectedPlan = "premium"
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button(action: { onUpgrade(selectedPlan) }) {
                    Text("アップグレードする")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("プランのアップグレード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}

struct PlanSelectionCard: View {
    let planName: String
    let price: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(price)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

@MainActor
class EmployerPlanViewModel: ObservableObject {
    @Published var currentPlan: EmployerPlanInfo?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadPlan() async {
        isLoading = true
        do {
            currentPlan = try await api.getEmployerPlan()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upgradePlan(planId: String) async {
        do {
            // Get default payment method for upgrade
            let methods = try await api.getPaymentMethods()
            let defaultMethod = methods.first(where: { $0.isDefault == true }) ?? methods.first
            currentPlan = try await api.upgradeEmployerPlan(planId: planId, paymentMethodId: defaultMethod?.id)
        } catch {
            errorMessage = "アップグレードに失敗しました。クレジットカードを登録してください。"
        }
    }

    func cancelPlan() async {
        do {
            _ = try await api.cancelEmployerPlan()
            await loadPlan()
        } catch {
            errorMessage = "解約に失敗しました"
        }
    }
}

// MARK: - Job Templates View

struct JobTemplatesView: View {
    @StateObject private var viewModel = JobTemplatesViewModel()
    @State private var showCreateFromTemplate = false
    @State private var selectedTemplate: JobTemplate?
    @State private var showDeleteConfirm = false
    @State private var templateToDelete: JobTemplate?
    @State private var searchText = ""

    private var filteredTemplates: [JobTemplate] {
        if searchText.isEmpty {
            return viewModel.templates
        }
        return viewModel.templates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView("読み込み中...")
                Spacer()
            } else if viewModel.templates.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 56))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("テンプレートがありません")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    Text("求人作成時に「テンプレートとして保存」を\n選択するとここに保存されます")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    NavigationLink(destination: JobCreateView()) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("求人を作成する")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding()
                Spacer()
            } else {
                // Search bar for templates
                if viewModel.templates.count > 3 {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("テンプレートを検索", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Template count header
                HStack {
                    Text("\(filteredTemplates.count)件のテンプレート")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)

                List {
                    ForEach(filteredTemplates) { template in
                        TemplateRow(template: template)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTemplate = template
                                showCreateFromTemplate = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    templateToDelete = template
                                    showDeleteConfirm = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .accessibilityLabel("テンプレート: \(template.name)")
                            .accessibilityHint("タップしてこのテンプレートから求人を作成")
                    }
                }
                .listStyle(.insetGrouped)
            }

            // Error display
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button("再試行") {
                        Task { await viewModel.loadData() }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("求人テンプレート")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: JobCreateView()) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新しい求人を作成")
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showCreateFromTemplate) {
            if let template = selectedTemplate {
                CreateFromTemplateSheet(template: template) {
                    Task { await viewModel.loadData() }
                }
            }
        }
        .alert("テンプレートを削除", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) {
                templateToDelete = nil
            }
            Button("削除", role: .destructive) {
                if let template = templateToDelete {
                    Task { await viewModel.deleteTemplate(id: template.id) }
                }
                templateToDelete = nil
            }
        } message: {
            Text("「\(templateToDelete?.name ?? "")」を削除しますか？この操作は元に戻せません。")
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct TemplateRow: View {
    let template: JobTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.purple)
                Text(template.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Text(template.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                if let wage = template.hourlyWage {
                    Label("¥\(wage.formatted())/時", systemImage: "yensign.circle")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if let pref = template.prefecture {
                    Label(pref, systemImage: "mappin")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if let time = template.startTime, let end = template.endTime {
                    Label("\(time)〜\(end)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if let people = template.requiredPeople {
                    Label("\(people)名", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Categories tags
            if let categories = template.categories, !categories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(categories.prefix(3), id: \.self) { category in
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct CreateFromTemplateSheet: View {
    let template: JobTemplate
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var workDate = Date()
    @State private var requiredPeople = 1
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("テンプレート情報") {
                    LabeledContent("タイトル", value: template.title)
                    if let wage = template.hourlyWage {
                        LabeledContent("時給", value: "¥\(wage.formatted())")
                    }
                    if let pref = template.prefecture {
                        LabeledContent("場所", value: pref)
                    }
                }

                Section("新しい求人の設定") {
                    DatePicker("勤務日", selection: $workDate, displayedComponents: .date)
                    Stepper("募集人数: \(requiredPeople)名", value: $requiredPeople, in: 1...50)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("テンプレートから作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        createJob()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }

    private func createJob() {
        isCreating = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: workDate)

        Task {
            do {
                _ = try await APIClient.shared.createJobFromTemplate(
                    templateId: template.id,
                    workDate: dateString,
                    requiredPeople: requiredPeople
                )
                onSuccess()
                dismiss()
            } catch {
                errorMessage = "作成に失敗しました"
            }
            isCreating = false
        }
    }
}

@MainActor
class JobTemplatesViewModel: ObservableObject {
    @Published var templates: [JobTemplate] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            templates = try await APIClient.shared.getJobTemplates()
        } catch {
            errorMessage = "テンプレートの読み込みに失敗しました"
        }
        isLoading = false
    }

    func deleteTemplate(id: String) async {
        do {
            _ = try await APIClient.shared.deleteJobTemplate(templateId: id)
            withAnimation {
                templates.removeAll { $0.id == id }
            }
        } catch {
            errorMessage = "テンプレートの削除に失敗しました"
        }
    }
}

// MARK: - Timesheet Bulk Approval View

struct TimesheetBulkApprovalView: View {
    @StateObject private var viewModel = TimesheetBulkApprovalViewModel()
    @State private var selectedIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.timesheets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("承認待ちのタイムシートはありません")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Select All / Actions Bar
                HStack {
                    Button(action: toggleSelectAll) {
                        HStack(spacing: 6) {
                            Image(systemName: selectedIds.count == pendingTimesheets.count ? "checkmark.square.fill" : "square")
                                .foregroundColor(.blue)
                            Text("すべて選択 (\(pendingTimesheets.count)件)")
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if !selectedIds.isEmpty {
                        Button(action: {
                            Task { await viewModel.bulkApprove(ids: Array(selectedIds)) }
                            selectedIds.removeAll()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("\(selectedIds.count)件を一括承認")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))

                Divider()

                // Timesheet List
                List {
                    ForEach(viewModel.timesheets) { timesheet in
                        TimesheetApprovalRow(
                            timesheet: timesheet,
                            isSelected: selectedIds.contains(timesheet.id),
                            onToggle: { toggleSelection(timesheet.id) },
                            onApprove: {
                                Task { await viewModel.approveTimesheet(id: timesheet.id) }
                            },
                            onReject: {
                                Task { await viewModel.rejectTimesheet(id: timesheet.id) }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("勤怠一括承認")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("完了", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    private var pendingTimesheets: [TimesheetData] {
        viewModel.timesheets.filter { $0.status == "pending" }
    }

    private func toggleSelectAll() {
        if selectedIds.count == pendingTimesheets.count {
            selectedIds.removeAll()
        } else {
            selectedIds = Set(pendingTimesheets.map { $0.id })
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

struct TimesheetApprovalRow: View {
    let timesheet: TimesheetData
    let isSelected: Bool
    let onToggle: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if timesheet.status == "pending" {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(timesheet.workerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(timesheet.jobTitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Label(timesheet.date, systemImage: "calendar")
                        .font(.caption2)
                    Label("\(timesheet.checkIn) 〜 \(timesheet.checkOut)", systemImage: "clock")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(timesheet.amount.formatted())")
                    .font(.subheadline)
                    .fontWeight(.bold)

                if timesheet.status == "pending" {
                    HStack(spacing: 8) {
                        Button(action: onApprove) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onReject) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(timesheet.status == "approved" ? "承認済" : "却下")
                        .font(.caption2)
                        .foregroundColor(timesheet.status == "approved" ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class TimesheetBulkApprovalViewModel: ObservableObject {
    @Published var timesheets: [TimesheetData] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            timesheets = try await api.getEmployerTimesheets()
        } catch {
            errorMessage = "タイムシートの読み込みに失敗しました"
        }
        isLoading = false
    }

    func approveTimesheet(id: String) async {
        do {
            _ = try await api.updateTimesheet(timesheetId: id, approved: true)
            if let index = timesheets.firstIndex(where: { $0.id == id }) {
                timesheets.remove(at: index)
            }
        } catch {
            errorMessage = "承認に失敗しました"
        }
    }

    func rejectTimesheet(id: String) async {
        do {
            _ = try await api.updateTimesheet(timesheetId: id, approved: false)
            if let index = timesheets.firstIndex(where: { $0.id == id }) {
                timesheets.remove(at: index)
            }
        } catch {
            errorMessage = "却下に失敗しました"
        }
    }

    func bulkApprove(ids: [String]) async {
        do {
            _ = try await api.bulkApproveTimesheets(timesheetIds: ids)
            timesheets.removeAll { ids.contains($0.id) }
            successMessage = "\(ids.count)件のタイムシートを承認しました"
        } catch {
            errorMessage = "一括承認に失敗しました"
        }
    }
}

// MARK: - Reliable Workers View

struct ReliableWorkersView: View {
    @StateObject private var viewModel = ReliableWorkersViewModel()
    @State private var selectedWorkerForReinvite: ReliableWorker?

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.workers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("まだ信頼できるワーカーがいません")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("お仕事が完了したワーカーがここに表示されます")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.workers) { worker in
                    ReliableWorkerRow(worker: worker, onReinvite: {
                        selectedWorkerForReinvite = worker
                    })
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("信頼できるワーカー")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
        .sheet(item: $selectedWorkerForReinvite) { worker in
            NavigationStack {
                ReinviteWorkerSheet(worker: worker)
            }
        }
    }
}

struct ReliableWorkerRow: View {
    let worker: ReliableWorker
    var onReinvite: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(worker.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 10))
                        Text("\(worker.completedJobs)件")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)

                    HStack(spacing: 3) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10))
                        Text("\(worker.goodRate)%")
                            .font(.caption)
                    }
                    .foregroundColor(worker.goodRate >= 80 ? .green : .orange)
                }

                if let categories = worker.categories, !categories.isEmpty {
                    Text(categories.prefix(3).joined(separator: " / "))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let lastWorked = worker.lastWorkedAt {
                    Text(lastWorked.prefix(10).replacingOccurrences(of: "-", with: "/"))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                if let onReinvite = onReinvite {
                    Button(action: onReinvite) {
                        Label("招待", systemImage: "envelope.fill")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
    }
}

@MainActor
class ReliableWorkersViewModel: ObservableObject {
    @Published var workers: [ReliableWorker] = []
    @Published var isLoading = true

    func loadData() async {
        isLoading = true
        do {
            workers = try await APIClient.shared.getReliableWorkers()
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

// MARK: - Reinvite Worker Sheet

struct ReinviteWorkerSheet: View {
    let worker: ReliableWorker
    @State private var jobs: [Job] = []
    @State private var isLoading = true
    @State private var isSending = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                        )
                    VStack(alignment: .leading) {
                        Text(worker.name)
                            .font(.headline)
                        Text("\(worker.completedJobs)件完了")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } header: {
                Text("ワーカー")
            }

            Section {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if jobs.isEmpty {
                    Text("招待できる求人がありません")
                        .foregroundColor(.gray)
                } else {
                    ForEach(jobs) { job in
                        Button(action: { reinvite(jobId: job.id) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(job.title)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    if let date = job.workDate {
                                        Text(date)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                if isSending {
                                    ProgressView()
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(isSending)
                    }
                }
            } header: {
                Text("招待する求人を選択")
            }

            if let msg = successMessage {
                Section {
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            if let err = errorMessage {
                Section {
                    Text(err).foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ワーカーを招待")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
        .task {
            do {
                let allJobs = try await APIClient.shared.getEmployerJobs()
                jobs = allJobs.filter { $0.status == "active" || $0.status == "recruiting" }
            } catch {}
            isLoading = false
        }
    }

    private func reinvite(jobId: String) {
        isSending = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIClient.shared.reinviteWorker(workerId: worker.id, jobId: jobId)
                successMessage = "\(worker.name)さんに招待を送信しました"
            } catch {
                errorMessage = "招待の送信に失敗しました"
            }
            isSending = false
        }
    }
}

// MARK: - Employer Write Review View

struct EmployerWriteReviewView: View {
    let workerId: String
    let workerName: String
    let jobId: String
    let jobTitle: String
    let onComplete: () -> Void

    @State private var ratingType: String? = nil
    @State private var comment = ""
    @State private var selectedTags: Set<String> = []
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let goodTags = ["時間通り", "真面目", "また依頼したい", "スキルが高い", "コミュニケーション良好"]
    private let badTags = ["遅刻", "無断欠勤", "態度が悪い", "スキル不足", "連絡が取れない"]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Text(jobTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(workerName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            Section("このワーカーはどうでしたか？") {
                HStack(spacing: 24) {
                    Spacer()
                    Button(action: { ratingType = "good"; selectedTags = [] }) {
                        VStack(spacing: 8) {
                            Image(systemName: ratingType == "good" ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 40))
                                .foregroundColor(ratingType == "good" ? .green : .gray)
                            Text("Good")
                                .font(.headline)
                                .foregroundColor(ratingType == "good" ? .green : .gray)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: { ratingType = "bad"; selectedTags = [] }) {
                        VStack(spacing: 8) {
                            Image(systemName: ratingType == "bad" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.system(size: 40))
                                .foregroundColor(ratingType == "bad" ? .red : .gray)
                            Text("Bad")
                                .font(.headline)
                                .foregroundColor(ratingType == "bad" ? .red : .gray)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
                .padding(.vertical, 12)
            }

            if let type = ratingType {
                Section("タグを選択（任意）") {
                    let tags = type == "good" ? goodTags : badTags
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }) {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTags.contains(tag) ? (type == "good" ? Color.green.opacity(0.2) : Color.red.opacity(0.2)) : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedTags.contains(tag) ? (type == "good" ? .green : .red) : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }

            Section("コメント（任意）") {
                TextEditor(text: $comment)
                    .frame(height: 100)
            }

            if let error = errorMessage {
                Section { Text(error).foregroundColor(.red) }
            }

            Section {
                Button(action: submitReview) {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("レビューを投稿")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || ratingType == nil)
            }
        }
        .navigationTitle("レビューを書く")
        .navigationBarTitleDisplayMode(.inline)
        .alert("レビューを投稿しました！", isPresented: $showSuccess) {
            Button("OK") {
                onComplete()
                dismiss()
            }
        }
    }

    private func submitReview() {
        guard let type = ratingType else { return }
        isSubmitting = true
        errorMessage = nil

        let fullComment: String? = {
            var parts: [String] = []
            if !selectedTags.isEmpty { parts.append(selectedTags.joined(separator: ", ")) }
            if !comment.isEmpty { parts.append(comment) }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }()

        Task {
            do {
                _ = try await APIClient.shared.submitReview(
                    jobId: jobId,
                    revieweeId: workerId,
                    rating: type == "good" ? 5 : 1,
                    comment: fullComment
                )
                showSuccess = true
            } catch {
                errorMessage = "レビューの投稿に失敗しました"
            }
            isSubmitting = false
        }
    }
}

// MARK: - Employer Checkout Payment View

struct EmployerCheckoutPaymentView: View {
    let timesheet: TimesheetEntry
    @State private var quote: PaymentQuoteResponse?
    @State private var paymentMethods: [PaymentMethod] = []
    @State private var selectedMethodId: String?
    @State private var isLoading = true
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var paymentSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if isLoading {
                ProgressView("決済情報を取得中...")
            } else if paymentSuccess {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("決済が完了しました")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("ワーカーへの支払いが処理されました")
                        .foregroundColor(.secondary)
                    Button("閉じる") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                Form {
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Section("勤務詳細") {
                        LabeledContent("ワーカー", value: timesheet.workerName)
                        LabeledContent("求人", value: timesheet.jobTitle)
                        LabeledContent("勤務日", value: timesheet.date)
                        LabeledContent("勤務時間", value: "\(timesheet.checkIn) - \(timesheet.checkOut)")
                    }

                    if let quote = quote {
                        Section("金額") {
                            LabeledContent("報酬", value: "¥\(quote.amount.formatted())")
                            LabeledContent("手数料", value: "¥\(quote.fee.formatted())")
                            HStack {
                                Text("合計")
                                    .fontWeight(.bold)
                                Spacer()
                                Text("¥\(quote.total.formatted())")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Section("お支払い方法") {
                        if paymentMethods.isEmpty {
                            Text("登録済みのカードがありません")
                                .foregroundColor(.secondary)
                            NavigationLink("カードを追加する", destination: PaymentMethodsView())
                        } else {
                            ForEach(paymentMethods) { method in
                                HStack {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(.blue)
                                    Text(method.displayText)
                                    Spacer()
                                    if selectedMethodId == method.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMethodId = method.id
                                }
                            }
                        }
                    }

                    Section {
                        Button(action: processPayment) {
                            if isProcessing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("決済を実行する")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(selectedMethodId == nil || isProcessing || quote == nil)
                    }
                }
            }
        }
        .navigationTitle("決済")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPaymentInfo()
        }
    }

    private func loadPaymentInfo() async {
        isLoading = true
        errorMessage = nil
        do {
            async let quoteResult = APIClient.shared.getPaymentQuote(
                jobId: timesheet.jobId,
                workerId: timesheet.workerId,
                hours: Double(timesheet.amount) / 1000.0
            )
            async let methodsResult = APIClient.shared.getPaymentMethods()

            quote = try await quoteResult
            paymentMethods = try await methodsResult

            if let defaultMethod = paymentMethods.first(where: { $0.isDefault == true }) {
                selectedMethodId = defaultMethod.id
            } else {
                selectedMethodId = paymentMethods.first?.id
            }
        } catch {
            errorMessage = "決済情報の取得に失敗しました"
        }
        isLoading = false
    }

    private func processPayment() {
        guard let methodId = selectedMethodId, let quote = quote else { return }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let result = try await APIClient.shared.chargePayment(
                    jobId: timesheet.jobId,
                    workerId: timesheet.workerId,
                    amount: quote.total,
                    paymentMethodId: methodId,
                    idempotencyKey: UUID().uuidString
                )
                if result.ok {
                    paymentSuccess = true
                } else {
                    errorMessage = result.message ?? "決済に失敗しました"
                }
            } catch {
                errorMessage = "決済に失敗しました: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }
}

// MARK: - Manual Payment View

struct ManualPaymentView: View {
    let timesheet: TimesheetEntry
    @State private var transportationFee = ""
    @State private var overtimeMinutes = ""
    @State private var paymentMethods: [PaymentMethod] = []
    @State private var selectedMethodId: String?
    @State private var isLoading = true
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var paymentSuccess = false
    @Environment(\.dismiss) private var dismiss

    private var workedHours: Double { timesheet.calculatedWorkedHours }
    private var basePay: Int { Int(workedHours * Double(timesheet.hourlyWage)) }
    private var transportationFeeInt: Int { Int(transportationFee) ?? 0 }
    private var overtimeMinutesInt: Int { Int(overtimeMinutes) ?? 0 }
    private var overtimePay: Int {
        guard overtimeMinutesInt > 0, timesheet.hourlyWage > 0 else { return 0 }
        return Int(Double(timesheet.hourlyWage) * 1.25 * Double(overtimeMinutesInt) / 60.0)
    }
    private var totalAmount: Int { basePay + transportationFeeInt + overtimePay }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("情報を取得中...")
            } else if paymentSuccess {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("精算が完了しました")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("ワーカーへの支払いが処理されました")
                        .foregroundColor(.secondary)
                    Button("閉じる") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                Form {
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Section("勤務詳細") {
                        LabeledContent("ワーカー", value: timesheet.workerName)
                        LabeledContent("求人", value: timesheet.jobTitle)
                        LabeledContent("勤務日", value: timesheet.date)
                        LabeledContent("勤務時間", value: "\(timesheet.checkIn) - \(timesheet.checkOut)")
                        LabeledContent("実働時間", value: String(format: "%.1f時間", workedHours))
                        LabeledContent("時給", value: "¥\(timesheet.hourlyWage.formatted())")
                    }

                    Section("基本報酬") {
                        HStack {
                            Text("実働時間 × 時給")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("¥\(basePay.formatted())")
                                .fontWeight(.semibold)
                        }
                    }

                    Section("交通費") {
                        TextField("交通費（円）", text: $transportationFee)
                            .keyboardType(.numberPad)
                    }

                    Section("残業代") {
                        TextField("残業分数", text: $overtimeMinutes)
                            .keyboardType(.numberPad)
                        if overtimeMinutesInt > 0 {
                            HStack {
                                Text("残業代（時給×125%）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("¥\(overtimePay.formatted())")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }

                    Section("合計金額") {
                        if basePay > 0 {
                            LabeledContent("基本給", value: "¥\(basePay.formatted())")
                        }
                        if transportationFeeInt > 0 {
                            LabeledContent("交通費", value: "¥\(transportationFeeInt.formatted())")
                        }
                        if overtimePay > 0 {
                            LabeledContent("残業代", value: "¥\(overtimePay.formatted())")
                        }
                        HStack {
                            Text("合計")
                                .fontWeight(.bold)
                            Spacer()
                            Text("¥\(totalAmount.formatted())")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }

                    Section("お支払い方法") {
                        if paymentMethods.isEmpty {
                            Text("登録済みのカードがありません")
                                .foregroundColor(.secondary)
                            NavigationLink("カードを追加する", destination: PaymentMethodsView())
                        } else {
                            ForEach(paymentMethods) { method in
                                HStack {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(.blue)
                                    Text(method.displayText)
                                    Spacer()
                                    if selectedMethodId == method.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMethodId = method.id
                                }
                            }
                        }
                    }

                    Section {
                        Button(action: processManualPayment) {
                            if isProcessing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("精算を実行する（¥\(totalAmount.formatted())）")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(selectedMethodId == nil || isProcessing || totalAmount <= 0)
                    }
                }
            }
        }
        .navigationTitle("実績精算")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPaymentMethods()
        }
    }

    private func loadPaymentMethods() async {
        isLoading = true
        do {
            paymentMethods = try await APIClient.shared.getPaymentMethods()
            if let defaultMethod = paymentMethods.first(where: { $0.isDefault == true }) {
                selectedMethodId = defaultMethod.id
            } else {
                selectedMethodId = paymentMethods.first?.id
            }
        } catch {
            errorMessage = "支払い方法の取得に失敗しました"
        }
        isLoading = false
    }

    private func processManualPayment() {
        guard let methodId = selectedMethodId else { return }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let result = try await APIClient.shared.submitManualPayment(
                    timesheetId: timesheet.id,
                    basePay: basePay,
                    transportationFee: transportationFeeInt,
                    overtimeMinutes: overtimeMinutesInt,
                    overtimePay: overtimePay,
                    totalAmount: totalAmount,
                    paymentMethodId: methodId,
                    idempotencyKey: UUID().uuidString
                )
                if result.ok {
                    paymentSuccess = true
                } else {
                    errorMessage = result.message ?? "精算に失敗しました"
                }
            } catch {
                errorMessage = "精算に失敗しました: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }
}

// MARK: - Employer My Reviews View

struct EmployerMyReviewsView: View {
    @State private var reviews: [Review] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("再試行") { Task { await loadReviews() } }
                        .buttonStyle(.bordered)
                }
            } else if reviews.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("レビューはまだありません")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("ワーカーにレビューを書くと、ここに表示されます")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding()
            } else {
                List(reviews) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }

                            Spacer()

                            if let date = review.createdAt {
                                Text(formatDate(date))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }

                        if let name = review.reviewerName {
                            Text("投稿者: \(name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let comment = review.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("レビュー一覧")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadReviews()
        }
        .refreshable {
            await loadReviews()
        }
    }

    private func loadReviews() async {
        isLoading = true
        errorMessage = nil
        do {
            reviews = try await APIClient.shared.getMyReviews()
        } catch {
            errorMessage = "レビューの読み込みに失敗しました"
        }
        isLoading = false
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy年M月d日"
            return displayFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            displayFormatter.dateFormat = "yyyy年M月d日"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Employer Invoice / Billing View

struct EmployerInvoiceView: View {
    @StateObject private var viewModel = EmployerInvoiceViewModel()
    @State private var showPDFAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Monthly Summary Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("月間サマリー")
                        .font(.headline)

                    HStack(spacing: 12) {
                        FinanceStatCard(
                            title: "今月の請求額",
                            value: "¥\(viewModel.monthlySummary.totalAmount.formatted())",
                            icon: "yensign.circle.fill",
                            color: .blue
                        )
                        FinanceStatCard(
                            title: "支払件数",
                            value: "\(viewModel.monthlySummary.invoiceCount)件",
                            icon: "doc.text.fill",
                            color: .green
                        )
                    }

                    HStack(spacing: 12) {
                        FinanceStatCard(
                            title: "雇用ワーカー数",
                            value: "\(viewModel.monthlySummary.workerCount)名",
                            icon: "person.2.fill",
                            color: .purple
                        )
                        FinanceStatCard(
                            title: "未払い",
                            value: "¥\(viewModel.monthlySummary.unpaidAmount.formatted())",
                            icon: "exclamationmark.circle.fill",
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal)

                // PDF Export Button
                Button(action: { showPDFAlert = true }) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("PDF出力")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Invoice List
                VStack(alignment: .leading, spacing: 12) {
                    Text("請求一覧")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.invoices.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("請求データはありません")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(viewModel.invoices) { invoice in
                            InvoiceRow(invoice: invoice)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("請求・支払管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("PDF出力", isPresented: $showPDFAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("PDFのダウンロードを開始しました")
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }
}

struct InvoiceItem: Identifiable {
    let id: String
    let date: String
    let jobTitle: String
    let workerCount: Int
    let totalAmount: Int
    let status: String

    var statusDisplay: String {
        switch status {
        case "paid": return "支払済"
        case "pending": return "未払い"
        case "overdue": return "期限超過"
        default: return status
        }
    }

    var statusColor: Color {
        switch status {
        case "paid": return .green
        case "pending": return .orange
        case "overdue": return .red
        default: return .gray
        }
    }
}

struct InvoiceMonthlySummary {
    var totalAmount: Int = 0
    var invoiceCount: Int = 0
    var workerCount: Int = 0
    var unpaidAmount: Int = 0
}

struct InvoiceRow: View {
    let invoice: InvoiceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(invoice.jobTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text(invoice.statusDisplay)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(invoice.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(invoice.statusColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                Label(invoice.date, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.gray)

                Label("\(invoice.workerCount)名", systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Text("¥\(invoice.totalAmount.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 8)
    }
}

@MainActor
class EmployerInvoiceViewModel: ObservableObject {
    @Published var invoices: [InvoiceItem] = []
    @Published var monthlySummary = InvoiceMonthlySummary()
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true

        do {
            // Build invoice items from timesheet data
            let timesheets = try await api.getEmployerTimesheets()

            // Group timesheets by jobTitle + date to create invoice items
            var grouped: [String: (date: String, jobTitle: String, workerCount: Int, totalAmount: Int, hasPending: Bool)] = [:]

            for ts in timesheets {
                let key = "\(ts.jobTitle)_\(ts.date)"
                if var existing = grouped[key] {
                    existing.workerCount += 1
                    existing.totalAmount += ts.amount
                    if ts.status == "pending" || ts.status == "approved" {
                        existing.hasPending = true
                    }
                    grouped[key] = existing
                } else {
                    grouped[key] = (
                        date: ts.date,
                        jobTitle: ts.jobTitle,
                        workerCount: 1,
                        totalAmount: ts.amount,
                        hasPending: ts.status == "pending" || ts.status == "approved"
                    )
                }
            }

            invoices = grouped.map { (key, value) in
                InvoiceItem(
                    id: key,
                    date: value.date,
                    jobTitle: value.jobTitle,
                    workerCount: value.workerCount,
                    totalAmount: value.totalAmount,
                    status: value.hasPending ? "pending" : "paid"
                )
            }
            .sorted { $0.date > $1.date }

            // Calculate monthly summary
            let calendar = Calendar.current
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            let thisMonthInvoices = invoices.filter { invoice in
                if let date = dateFormatter.date(from: invoice.date) {
                    return calendar.isDate(date, equalTo: now, toGranularity: .month)
                }
                return false
            }

            var uniqueWorkerIds = Set<String>()
            for ts in timesheets {
                if let date = dateFormatter.date(from: ts.date),
                   calendar.isDate(date, equalTo: now, toGranularity: .month) {
                    if let workerId = ts.workerId {
                        uniqueWorkerIds.insert(workerId)
                    }
                }
            }

            monthlySummary = InvoiceMonthlySummary(
                totalAmount: thisMonthInvoices.reduce(0) { $0 + $1.totalAmount },
                invoiceCount: thisMonthInvoices.count,
                workerCount: uniqueWorkerIds.count,
                unpaidAmount: thisMonthInvoices.filter { $0.status == "pending" }.reduce(0) { $0 + $1.totalAmount }
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Employer Attendance Dashboard View

struct EmployerAttendanceDashboardView: View {
    @StateObject private var viewModel = EmployerAttendanceDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Today's Date
                VStack(spacing: 4) {
                    Text(viewModel.todayDateString)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(viewModel.todayWeekdayString)
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Summary Stats
                HStack(spacing: 12) {
                    AttendanceStatCard(
                        title: "出勤予定",
                        value: "\(viewModel.totalExpected)",
                        icon: "person.2.fill",
                        color: .blue
                    )
                    AttendanceStatCard(
                        title: "出勤済",
                        value: "\(viewModel.checkedInCount)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    AttendanceStatCard(
                        title: "退勤済",
                        value: "\(viewModel.completedCount)",
                        icon: "flag.checkered",
                        color: .blue
                    )
                }
                .padding(.horizontal)

                // Worker List
                VStack(alignment: .leading, spacing: 12) {
                    Text("本日のワーカー")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.isLoading {
                        ProgressView("読み込み中...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.workers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("本日の出勤予定者はいません")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(viewModel.workers) { worker in
                            AttendanceWorkerRow(worker: worker)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("出勤ダッシュボード")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }
}

struct AttendanceWorkerInfo: Identifiable {
    let id: String
    let name: String
    let jobTitle: String
    let checkInStatus: AttendanceStatus
    let checkInTime: String?
    let checkOutTime: String?

    enum AttendanceStatus: String {
        case notYet = "not_yet"
        case checkedIn = "checked_in"
        case completed = "completed"

        var display: String {
            switch self {
            case .notYet: return "未出勤"
            case .checkedIn: return "出勤済"
            case .completed: return "退勤済"
            }
        }

        var color: Color {
            switch self {
            case .notYet: return .gray
            case .checkedIn: return .green
            case .completed: return .blue
            }
        }
    }
}

struct AttendanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct AttendanceWorkerRow: View {
    let worker: AttendanceWorkerInfo

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(worker.checkInStatus.color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: statusIcon)
                        .foregroundColor(worker.checkInStatus.color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(worker.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(worker.jobTitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(worker.checkInStatus.display)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(worker.checkInStatus.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(worker.checkInStatus.color.opacity(0.1))
                    .clipShape(Capsule())

                if let checkIn = worker.checkInTime {
                    Text(checkIn)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                if let checkOut = worker.checkOutTime {
                    Text("~ \(checkOut)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var statusIcon: String {
        switch worker.checkInStatus {
        case .notYet: return "clock"
        case .checkedIn: return "checkmark"
        case .completed: return "flag.checkered"
        }
    }
}

@MainActor
class EmployerAttendanceDashboardViewModel: ObservableObject {
    @Published var workers: [AttendanceWorkerInfo] = []
    @Published var totalExpected: Int = 0
    @Published var checkedInCount: Int = 0
    @Published var completedCount: Int = 0
    @Published var isLoading = true
    @Published var errorMessage: String?

    var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: Date())
    }

    var todayWeekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true

        let todayFormatter = DateFormatter()
        todayFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = todayFormatter.string(from: Date())

        do {
            // Load applications and timesheets
            let applications = try await api.getEmployerApplications()
            let timesheets = try await api.getEmployerTimesheets()

            // Filter accepted/confirmed applications for today
            let todayApplications = applications.filter { app in
                (app.status == "accepted" || app.status == "confirmed" || app.status == "working" || app.status == "completed") &&
                app.workDate == todayStr
            }

            // Build a lookup from timesheets for today
            var timesheetByWorker: [String: TimesheetData] = [:]
            for ts in timesheets where ts.date == todayStr {
                if let workerId = ts.workerId {
                    timesheetByWorker[workerId] = ts
                }
            }

            // Build worker attendance info
            var workerList: [AttendanceWorkerInfo] = []
            for app in todayApplications {
                let ts = timesheetByWorker[app.applicantId]

                let status: AttendanceWorkerInfo.AttendanceStatus
                let checkIn: String?
                let checkOut: String?

                if let tsData = ts {
                    if !tsData.checkOut.isEmpty && tsData.checkOut != "--:--" {
                        status = .completed
                        checkIn = tsData.checkIn
                        checkOut = tsData.checkOut
                    } else if !tsData.checkIn.isEmpty && tsData.checkIn != "--:--" {
                        status = .checkedIn
                        checkIn = tsData.checkIn
                        checkOut = nil
                    } else {
                        status = .notYet
                        checkIn = nil
                        checkOut = nil
                    }
                } else if let appCheckOut = app.checkOutTime, !appCheckOut.isEmpty {
                    status = .completed
                    checkIn = app.checkInTime
                    checkOut = appCheckOut
                } else if let appCheckIn = app.checkInTime, !appCheckIn.isEmpty {
                    status = .checkedIn
                    checkIn = appCheckIn
                    checkOut = nil
                } else {
                    status = .notYet
                    checkIn = nil
                    checkOut = nil
                }

                workerList.append(AttendanceWorkerInfo(
                    id: app.id,
                    name: app.applicantName ?? "ワーカー",
                    jobTitle: app.jobTitle ?? "求人",
                    checkInStatus: status,
                    checkInTime: checkIn,
                    checkOutTime: checkOut
                ))
            }

            // Sort: notYet first, then checkedIn, then completed
            workers = workerList.sorted { a, b in
                let order: [AttendanceWorkerInfo.AttendanceStatus] = [.notYet, .checkedIn, .completed]
                let aIndex = order.firstIndex(of: a.checkInStatus) ?? 0
                let bIndex = order.firstIndex(of: b.checkInStatus) ?? 0
                return aIndex < bIndex
            }

            totalExpected = workers.count
            checkedInCount = workers.filter { $0.checkInStatus == .checkedIn }.count
            completedCount = workers.filter { $0.checkInStatus == .completed }.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    EmployerDashboardView()
        .environmentObject(AuthManager.shared)
}
