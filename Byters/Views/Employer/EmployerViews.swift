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
                                EmployerQuickActionButton(title: "求人作成", icon: "plus.circle.fill", color: .blue) {}
                            }
                            NavigationLink(destination: EmployerApplicationsView()) {
                                EmployerQuickActionButton(title: "応募確認", icon: "bell.fill", color: .orange) {}
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
            .navigationBarTitleDisplayMode(.large)
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
class EmployerDashboardViewModel: ObservableObject {
    @Published var stats: EmployerStats?
    @Published var recentJobs: [Job] = []
    @Published var isLoading = false

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            stats = try await api.getEmployerStats()
            recentJobs = try await api.getEmployerJobs()
        } catch {
            print("Error loading employer data: \(error)")
        }
        isLoading = false
    }
}

struct EmployerQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Employer Jobs

struct EmployerJobsView: View {
    @StateObject private var viewModel = EmployerJobsViewModel()
    @State private var showingCreateSheet = false
    @State private var selectedJobForQR: Job?

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                // Active Jobs
                let activeJobs = viewModel.jobs.filter { $0.status == "active" }
                if !activeJobs.isEmpty {
                    Section("掲載中") {
                        ForEach(activeJobs) { job in
                            EmployerJobRow(job: job)
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        selectedJobForQR = job
                                    } label: {
                                        Label("QR", systemImage: "qrcode")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button {
                                        selectedJobForQR = job
                                    } label: {
                                        Label("チェックインQR表示", systemImage: "qrcode")
                                    }
                                    NavigationLink(destination: JobEditView(job: job)) {
                                        Label("編集", systemImage: "pencil")
                                    }
                                }
                        }
                    }
                }

                // Draft Jobs
                let draftJobs = viewModel.jobs.filter { $0.status == "draft" }
                if !draftJobs.isEmpty {
                    Section("下書き") {
                        ForEach(draftJobs) { job in
                            NavigationLink(destination: JobEditView(job: job)) {
                                EmployerJobRow(job: job)
                            }
                        }
                    }
                }

                // Closed Jobs
                let closedJobs = viewModel.jobs.filter { $0.status == "closed" }
                if !closedJobs.isEmpty {
                    Section("終了") {
                        ForEach(closedJobs) { job in
                            NavigationLink(destination: JobEditView(job: job)) {
                                EmployerJobRow(job: job)
                            }
                        }
                    }
                }

                if viewModel.jobs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("求人がありません")
                            .foregroundColor(.gray)
                        Button("求人を作成") {
                            showingCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("求人管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            JobCreateView(onSuccess: {
                Task { await viewModel.loadData() }
            })
        }
        .sheet(item: $selectedJobForQR) { job in
            JobQRCodeView(job: job)
        }
        .task {
            await viewModel.loadData()
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
                        .background(Color.white)
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

    private let api = APIClient.shared

    func loadQR(jobId: String) async {
        isLoading = true
        do {
            let response = try await api.getJobQRCode(jobId: jobId)
            checkInToken = response.token
            qrImage = generateQRCode(from: "\(jobId)|\(response.token)")
        } catch {
            print("Failed to load QR: \(error)")
            // Generate a fallback QR with just the job ID
            qrImage = generateQRCode(from: jobId)
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
            print("Failed to regenerate QR: \(error)")
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
        case "active": return .green
        case "draft": return .orange
        case "closed": return .gray
        default: return .gray
        }
    }
}

@MainActor
class EmployerJobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            jobs = try await api.getEmployerJobs()
        } catch {
            print("Error loading jobs: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Job Create View

struct JobCreateView: View {
    @Environment(\.dismiss) var dismiss
    var onSuccess: (() -> Void)? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var prefecture = ""
    @State private var city = ""
    @State private var address = ""
    @State private var hourlyWage = ""
    @State private var workDate = Date()
    @State private var startTime = "09:00"
    @State private var endTime = "18:00"
    @State private var requiredPeople = "1"
    @State private var requirements = ""
    @State private var benefits = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Image upload states
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var thumbnailIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("求人タイトル", text: $title)
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
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
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
                    TextField("詳細住所", text: $address)
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

                    DatePicker("勤務日", selection: $workDate, displayedComponents: .date)

                    HStack {
                        Text("開始時間")
                        Spacer()
                        TextField("09:00", text: $startTime)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Text("終了時間")
                        Spacer()
                        TextField("18:00", text: $endTime)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
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

                Section("応募条件（任意）") {
                    TextEditor(text: $requirements)
                        .frame(height: 80)
                }

                Section("待遇・福利厚生（任意）") {
                    TextEditor(text: $benefits)
                        .frame(height: 80)
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
            .navigationTitle("求人作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    var isValid: Bool {
        !title.isEmpty && !description.isEmpty && !prefecture.isEmpty && !city.isEmpty &&
        !hourlyWage.isEmpty && Int(hourlyWage) != nil &&
        !requiredPeople.isEmpty && Int(requiredPeople) != nil
    }

    func createJob() {
        isLoading = true
        errorMessage = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let workDateStr = dateFormatter.string(from: workDate)

        Task {
            do {
                // Convert images to base64
                var imageBase64Strings: [String] = []
                for image in selectedImages {
                    if let data = image.jpegData(compressionQuality: 0.7) {
                        imageBase64Strings.append(data.base64EncodedString())
                    }
                }

                _ = try await APIClient.shared.createJobWithImages(
                    title: title,
                    description: description,
                    prefecture: prefecture,
                    city: city,
                    address: address.isEmpty ? nil : address,
                    hourlyWage: Int(hourlyWage),
                    dailyWage: nil,
                    workDate: workDateStr,
                    startTime: startTime,
                    endTime: endTime,
                    requiredPeople: Int(requiredPeople) ?? 1,
                    categories: nil,
                    requirements: requirements.isEmpty ? nil : requirements,
                    benefits: benefits.isEmpty ? nil : benefits,
                    images: imageBase64Strings,
                    thumbnailIndex: thumbnailIndex
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

// MARK: - Job Edit View

struct JobEditView: View {
    let job: Job
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var description: String
    @State private var isLoading = false

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

            if job.status == "draft" {
                Section {
                    Button("公開する") {
                        publishJob()
                    }
                    .foregroundColor(.green)
                }
            }

            Section {
                Button("削除", role: .destructive) {
                    deleteJob()
                }
            }
        }
        .navigationTitle("求人編集")
    }

    func publishJob() {
        isLoading = true
        Task {
            do {
                _ = try await APIClient.shared.publishJob(jobId: job.id)
                dismiss()
            } catch {
                print("Error publishing job: \(error)")
            }
            isLoading = false
        }
    }

    func deleteJob() {
        Task {
            do {
                _ = try await APIClient.shared.deleteJob(jobId: job.id)
                dismiss()
            } catch {
                print("Error deleting job: \(error)")
            }
        }
    }
}

// MARK: - Employer Applications

struct EmployerApplicationsView: View {
    @StateObject private var viewModel = EmployerApplicationsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
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
                            ApplicationInfoRow(application: application)
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
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
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
                Text(application.applicantName ?? "応募者")
                    .font(.headline)
                Text(application.jobTitle ?? "求人")
                    .font(.caption)
                    .foregroundColor(.gray)
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            applications = try await api.getEmployerApplications()
        } catch {
            print("Error loading applications: \(error)")
        }
        isLoading = false
    }

    func approve(_ application: Application) async {
        do {
            _ = try await api.approveApplication(applicationId: application.id)
            await loadData()
        } catch {
            print("Error approving application: \(error)")
        }
    }

    func reject(_ application: Application) async {
        do {
            _ = try await api.rejectApplication(applicationId: application.id, reason: nil)
            await loadData()
        } catch {
            print("Error rejecting application: \(error)")
        }
    }
}

// MARK: - Employer Settings

struct EmployerSettingsView: View {
    @EnvironmentObject var authManager: AuthManager

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
                }

                Section("勤怠") {
                    NavigationLink(destination: EmployerTimesheetView()) {
                        Label("勤怠管理", systemImage: "clock.badge.checkmark")
                    }
                }

                Section("通知") {
                    NavigationLink(destination: NotificationListView()) {
                        Label("通知一覧", systemImage: "bell.badge.fill")
                    }

                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("通知設定", systemImage: "bell.fill")
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
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Company Profile Edit

struct CompanyProfileEditView: View {
    @StateObject private var viewModel = CompanyProfileViewModel()
    @State private var showingSaved = false

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("会社名", text: $viewModel.businessName)
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
                TextField("詳細住所", text: $viewModel.address)
            }

            Section("連絡先") {
                TextField("電話番号", text: $viewModel.contactPhone)
                    .keyboardType(.phonePad)
                TextField("メールアドレス", text: $viewModel.contactEmail)
                    .keyboardType(.emailAddress)
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
        .navigationTitle("会社プロフィール")
        .alert("保存しました", isPresented: $showingSaved) {
            Button("OK") {}
        }
        .task {
            await viewModel.loadData()
        }
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
    @Published var isLoading = false

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
        } catch {
            print("Error loading profile: \(error)")
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
            print("Error saving profile: \(error)")
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
            print("Error loading payment methods: \(error)")
        }
        isLoading = false
    }

    func deleteMethod(at indexSet: IndexSet) async {
        for index in indexSet {
            let method = methods[index]
            do {
                _ = try await api.deletePaymentMethod(paymentMethodId: method.id)
                methods.remove(at: index)
            } catch {
                errorMessage = "カードの削除に失敗しました"
            }
        }
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            // Filter for payment-type transactions only
            let allTransactions = try await api.getTransactions()
            transactions = allTransactions.filter { $0.type == "payment" || $0.type == "charge" }
        } catch {
            print("Error loading payment history: \(error)")
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
                .background(Color.white)
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
                .background(Color.white)
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
        .background(Color.white)
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

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true

        // Generate mock monthly data for now
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

        // Load actual data from API
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
            print("Failed to load finance stats: \(error)")
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
        }
        .padding(.vertical, 8)
    }
}

struct TimesheetEntry: Identifiable {
    let id: String
    let workerName: String
    let jobTitle: String
    let date: String
    let checkIn: String
    let checkOut: String
    let amount: Int
    let status: String

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

    private let api = APIClient.shared

    func loadTimesheets() async {
        isLoading = true
        do {
            let data = try await api.getEmployerTimesheets()
            timesheets = data.map { ts in
                TimesheetEntry(
                    id: ts.id,
                    workerName: ts.workerName,
                    jobTitle: ts.jobTitle,
                    date: ts.date,
                    checkIn: ts.checkIn,
                    checkOut: ts.checkOut,
                    amount: ts.amount,
                    status: ts.status
                )
            }
        } catch {
            print("Failed to load timesheets: \(error)")
        }
        isLoading = false
    }

    func updateTimesheet(id: String, approved: Bool) async {
        do {
            _ = try await api.updateTimesheet(timesheetId: id, approved: approved)
            await loadTimesheets()
        } catch {
            print("Failed to update timesheet: \(error)")
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
                    .background(Color.white)
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
        .background(isHighlighted ? Color.blue.opacity(0.1) : Color.white)
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
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
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
            print("Failed to load employer plan: \(error)")
        }
        isLoading = false
    }

    func upgradePlan(planId: String) async {
        do {
            currentPlan = try await api.upgradeEmployerPlan(planId: planId, paymentMethodId: nil)
        } catch {
            errorMessage = "アップグレードに失敗しました"
            print("Failed to upgrade plan: \(error)")
        }
    }

    func cancelPlan() async {
        do {
            _ = try await api.cancelEmployerPlan()
            await loadPlan()
        } catch {
            errorMessage = "解約に失敗しました"
            print("Failed to cancel plan: \(error)")
        }
    }
}

#Preview {
    EmployerDashboardView()
        .environmentObject(AuthManager())
}
