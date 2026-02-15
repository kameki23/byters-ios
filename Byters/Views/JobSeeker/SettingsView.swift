import SwiftUI

// MARK: - Job Seeker Notification Settings View

struct JobSeekerNotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        Form {
            Section(header: Text("お仕事関連")) {
                Toggle("おすすめ求人", isOn: $viewModel.settings.jobMatches)
                Toggle("応募状況の更新", isOn: $viewModel.settings.applicationUpdates)
                Toggle("勤務リマインダー", isOn: $viewModel.settings.reminders)
            }

            Section(header: Text("メッセージ")) {
                Toggle("チャットメッセージ", isOn: $viewModel.settings.chatMessages)
            }

            Section(header: Text("その他")) {
                Toggle("お得な情報・キャンペーン", isOn: $viewModel.settings.marketing)
            }

            Section {
                Button("設定を保存") {
                    Task { await viewModel.saveSettings() }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(viewModel.isError ? .red : .green)
                }
            }
        }
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    @Published var settings = NotificationSettings(
        jobMatches: true,
        applicationUpdates: true,
        chatMessages: true,
        reminders: true,
        marketing: false
    )
    @Published var isLoading = true
    @Published var message: String?
    @Published var isError = false

    private let api = APIClient.shared

    func loadSettings() async {
        isLoading = true
        do {
            settings = try await api.getNotificationSettings()
        } catch {
            message = error.localizedDescription
            isError = true
        }
        isLoading = false
    }

    func saveSettings() async {
        message = nil
        do {
            settings = try await api.updateNotificationSettings(settings: [
                "job_matches": settings.jobMatches,
                "application_updates": settings.applicationUpdates,
                "chat_messages": settings.chatMessages,
                "reminders": settings.reminders,
                "marketing": settings.marketing
            ])
            message = "保存しました"
            isError = false
        } catch {
            message = "保存に失敗しました"
            isError = true
        }
    }
}

// MARK: - Email Settings View

struct EmailSettingsView: View {
    @StateObject private var viewModel = EmailSettingsViewModel()

    var body: some View {
        Form {
            Section(header: Text("メール通知")) {
                Toggle("週間ダイジェスト", isOn: $viewModel.settings.weeklyDigest)
                Toggle("応募状況のお知らせ", isOn: $viewModel.settings.applicationAlerts)
                Toggle("支払い領収書", isOn: $viewModel.settings.paymentReceipts)
            }

            Section(header: Text("プロモーション")) {
                Toggle("お得な情報・キャンペーン", isOn: $viewModel.settings.promotions)
            }

            Section {
                Button("設定を保存") {
                    Task { await viewModel.saveSettings() }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(viewModel.isError ? .red : .green)
                }
            }
        }
        .navigationTitle("メール設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

@MainActor
class EmailSettingsViewModel: ObservableObject {
    @Published var settings = EmailSettings(
        weeklyDigest: true,
        applicationAlerts: true,
        paymentReceipts: true,
        promotions: false
    )
    @Published var isLoading = true
    @Published var message: String?
    @Published var isError = false

    private let api = APIClient.shared

    func loadSettings() async {
        isLoading = true
        do {
            settings = try await api.getEmailSettings()
        } catch {
            message = error.localizedDescription
            isError = true
        }
        isLoading = false
    }

    func saveSettings() async {
        message = nil
        do {
            settings = try await api.updateEmailSettings(settings: [
                "weekly_digest": settings.weeklyDigest,
                "application_alerts": settings.applicationAlerts,
                "payment_receipts": settings.paymentReceipts,
                "promotions": settings.promotions
            ])
            message = "保存しました"
            isError = false
        } catch {
            message = "保存に失敗しました"
            isError = true
        }
    }
}

// MARK: - Location Settings View

struct LocationSettingsView: View {
    @StateObject private var viewModel = LocationSettingsViewModel()

    var body: some View {
        Form {
            Section(header: Text("検索エリア")) {
                Picker("都道府県", selection: $viewModel.prefecture) {
                    Text("選択してください").tag("")
                    ForEach(viewModel.prefectures, id: \.self) { pref in
                        Text(pref).tag(pref)
                    }
                }

                TextField("市区町村", text: $viewModel.city)
            }

            Section(header: Text("検索範囲")) {
                Picker("距離", selection: $viewModel.searchRadius) {
                    Text("5km").tag(5)
                    Text("10km").tag(10)
                    Text("20km").tag(20)
                    Text("30km").tag(30)
                    Text("50km").tag(50)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section {
                Button("設定を保存") {
                    Task { await viewModel.saveSettings() }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(viewModel.isError ? .red : .green)
                }
            }
        }
        .navigationTitle("エリア設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

@MainActor
class LocationSettingsViewModel: ObservableObject {
    @Published var prefecture = ""
    @Published var city = ""
    @Published var searchRadius = 10
    @Published var isLoading = true
    @Published var message: String?
    @Published var isError = false

    let prefectures = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
        "岐阜県", "静岡県", "愛知県", "三重県",
        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]

    private let api = APIClient.shared

    func loadSettings() async {
        isLoading = true
        do {
            let settings = try await api.getLocationSettings()
            prefecture = settings.prefecture
            city = settings.city
            searchRadius = settings.searchRadiusKm
        } catch {
            message = error.localizedDescription
            isError = true
        }
        isLoading = false
    }

    func saveSettings() async {
        message = nil
        do {
            _ = try await api.updateLocationSettings(
                prefecture: prefecture,
                city: city,
                radius: searchRadius
            )
            message = "保存しました"
            isError = false
        } catch {
            message = "保存に失敗しました"
            isError = true
        }
    }
}

// MARK: - Muted Employers View

struct MutedEmployersView: View {
    @StateObject private var viewModel = MutedEmployersViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.mutedEmployers.isEmpty {
                Text("ミュートしている事業者はありません")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.mutedEmployers) { employer in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(employer.employerName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("ミュート日: \(formatDate(employer.mutedAt))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Button("解除") {
                            Task { await viewModel.unmuteEmployer(id: employer.employerId) }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("ミュートした事業者")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMutedEmployers()
        }
        .refreshable {
            await viewModel.loadMutedEmployers()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
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

@MainActor
class MutedEmployersViewModel: ObservableObject {
    @Published var mutedEmployers: [MutedEmployer] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadMutedEmployers() async {
        isLoading = true
        do {
            mutedEmployers = try await api.getMutedEmployers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func unmuteEmployer(id: String) async {
        do {
            _ = try await api.unmuteEmployer(employerId: id)
            await loadMutedEmployers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Timesheet Adjustment Request View

struct TimesheetAdjustmentView: View {
    @StateObject private var viewModel = TimesheetAdjustmentViewModel()
    @State private var showRequestSheet = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.adjustments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("時間修正リクエストはありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.adjustments) { adjustment in
                    TimesheetAdjustmentRow(adjustment: adjustment)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("勤務時間修正")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showRequestSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showRequestSheet) {
            TimesheetAdjustmentRequestSheet {
                Task { await viewModel.loadAdjustments() }
            }
        }
        .task {
            await viewModel.loadAdjustments()
        }
        .refreshable {
            await viewModel.loadAdjustments()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

struct TimesheetAdjustmentRow: View {
    let adjustment: TimesheetAdjustment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(adjustment.jobTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("元の時間:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(adjustment.originalCheckIn) - \(adjustment.originalCheckOut)")
                        .font(.caption)
                }

                if let reqIn = adjustment.requestedCheckIn, let reqOut = adjustment.requestedCheckOut {
                    HStack {
                        Text("修正希望:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(reqIn) - \(reqOut)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Text("理由: \(adjustment.reason)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch adjustment.status {
        case "pending": return "審査中"
        case "approved": return "承認"
        case "rejected": return "却下"
        default: return adjustment.status
        }
    }

    private var statusColor: Color {
        switch adjustment.status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

struct TimesheetAdjustmentRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedApplicationId = ""
    @State private var applications: [Application] = []
    @State private var requestedCheckIn = ""
    @State private var requestedCheckOut = ""
    @State private var reason = ""
    @State private var isLoading = false
    @State private var isLoadingApplications = true
    @State private var errorMessage: String?

    let onComplete: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("対象のお仕事")) {
                    if isLoadingApplications {
                        ProgressView("読み込み中...")
                    } else if applications.isEmpty {
                        Text("承認済みの応募がありません")
                            .foregroundColor(.gray)
                    } else {
                        Picker("お仕事を選択", selection: $selectedApplicationId) {
                            Text("選択してください").tag("")
                            ForEach(applications) { app in
                                Text(app.jobTitle ?? "求人ID: \(app.jobId)")
                                    .tag(app.id)
                            }
                        }
                    }
                }

                Section(header: Text("修正希望時間")) {
                    TextField("出勤時刻（例: 09:00）", text: $requestedCheckIn)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("退勤時刻（例: 18:00）", text: $requestedCheckOut)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section(header: Text("修正理由")) {
                    TextEditor(text: $reason)
                        .frame(height: 100)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("時間修正リクエスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送信") {
                        Task { await submitRequest() }
                    }
                    .disabled(reason.isEmpty || selectedApplicationId.isEmpty || isLoading)
                }
            }
            .task {
                await loadApplications()
            }
        }
    }

    private func loadApplications() async {
        isLoadingApplications = true
        do {
            let allApps = try await APIClient.shared.getMyApplications()
            applications = allApps.filter { $0.status == "approved" || $0.status == "completed" }
        } catch {
            errorMessage = "応募一覧の取得に失敗しました"
        }
        isLoadingApplications = false
    }

    private func submitRequest() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.requestTimesheetAdjustment(
                applicationId: selectedApplicationId,
                requestedCheckIn: requestedCheckIn.isEmpty ? nil : requestedCheckIn,
                requestedCheckOut: requestedCheckOut.isEmpty ? nil : requestedCheckOut,
                reason: reason
            )
            await onComplete()
            dismiss()
        } catch {
            errorMessage = "送信に失敗しました"
        }
        isLoading = false
    }
}

@MainActor
class TimesheetAdjustmentViewModel: ObservableObject {
    @Published var adjustments: [TimesheetAdjustment] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadAdjustments() async {
        isLoading = true
        do {
            adjustments = try await api.getMyTimesheetAdjustments()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Tax Documents View (源泉徴収票)

struct TaxDocumentsView: View {
    @StateObject private var viewModel = TaxDocumentsViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.documents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("税務書類はありません")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("年末調整後に源泉徴収票が\nここに表示されます")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.documents) { doc in
                    TaxDocumentRow(document: doc)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("源泉徴収票")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDocuments()
        }
        .refreshable {
            await viewModel.loadDocuments()
        }
    }
}

struct TaxDocumentRow: View {
    let document: TaxDocument
    @State private var isDownloading = false
    @State private var downloadError: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(document.year)年分 源泉徴収票")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("発行日: \(formatDate(document.issuedAt))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: {
                Task { await downloadDocument() }
            }) {
                if isDownloading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .disabled(isDownloading)
        }
        .padding(.vertical, 8)
        .alert("エラー", isPresented: Binding(
            get: { downloadError != nil },
            set: { if !$0 { downloadError = nil } }
        )) {
            Button("OK") { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
        }
    }

    private func downloadDocument() async {
        if let urlString = document.documentUrl, let url = URL(string: urlString) {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
            return
        }
        isDownloading = true
        do {
            let response = try await APIClient.shared.downloadTaxDocument(documentId: document.id)
            if let urlString = response.downloadUrl, let url = URL(string: urlString) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        } catch {
            downloadError = "ダウンロードに失敗しました"
        }
        isDownloading = false
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

@MainActor
class TaxDocumentsViewModel: ObservableObject {
    @Published var documents: [TaxDocument] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadDocuments() async {
        isLoading = true
        do {
            documents = try await api.getTaxDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Upcoming Work View (予定のお仕事)

struct UpcomingWorkView: View {
    @StateObject private var viewModel = UpcomingWorkViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.upcomingWork.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("予定のお仕事はありません")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("採用が決まると\nここに予定が表示されます")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                // Group by date
                ForEach(viewModel.groupedWork, id: \.date) { group in
                    Section(header: Text(formatSectionDate(group.date))) {
                        ForEach(group.items) { work in
                            UpcomingWorkRow(work: work) { _ in
                                await viewModel.loadUpcomingWork()
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("予定のお仕事")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadUpcomingWork()
        }
        .refreshable {
            await viewModel.loadUpcomingWork()
        }
    }

    private func formatSectionDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "ja_JP")

        if Calendar.current.isDateInToday(date) {
            return "今日"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "明日"
        } else {
            displayFormatter.dateFormat = "M月d日(E)"
            return displayFormatter.string(from: date)
        }
    }
}

struct UpcomingWorkRow: View {
    let work: UpcomingWorkItem
    var onCheckIn: ((String) async -> Void)?
    @State private var isCheckingIn = false
    @State private var checkInError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(work.jobTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(work.statusDisplay)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(work.statusColor.opacity(0.1))
                    .foregroundColor(work.statusColor)
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                Label(work.startTime + " - " + work.endTime, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray)

                Label(work.location, systemImage: "mappin")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Text(work.employerName)
                .font(.caption)
                .foregroundColor(.blue)

            if let error = checkInError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if work.canCheckIn {
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            isCheckingIn = true
                            checkInError = nil
                            do {
                                _ = try await APIClient.shared.checkIn(applicationId: work.applicationId)
                                await onCheckIn?(work.applicationId)
                            } catch {
                                checkInError = "チェックインに失敗しました"
                            }
                            isCheckingIn = false
                        }
                    }) {
                        HStack {
                            if isCheckingIn {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "clock.badge.checkmark")
                            }
                            Text("チェックイン")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(isCheckingIn)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension UpcomingWorkItem {
    var statusDisplay: String {
        switch status {
        case "accepted": return "確定"
        case "checked_in": return "勤務中"
        case "completed": return "完了"
        default: return status
        }
    }

    var statusColor: Color {
        switch status {
        case "accepted": return .blue
        case "checked_in": return .green
        case "completed": return .gray
        default: return .gray
        }
    }

    var canCheckIn: Bool {
        status == "accepted" && checkInTime == nil
    }
}

struct WorkDateGroup {
    let date: String
    let items: [UpcomingWorkItem]
}

@MainActor
class UpcomingWorkViewModel: ObservableObject {
    @Published var upcomingWork: [UpcomingWorkItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    var groupedWork: [WorkDateGroup] {
        let grouped = Dictionary(grouping: upcomingWork, by: { $0.workDate })
        return grouped.map { WorkDateGroup(date: $0.key, items: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private let api = APIClient.shared

    func loadUpcomingWork() async {
        isLoading = true
        do {
            upcomingWork = try await api.getUpcomingWork()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Bug Report View

struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category = "bug"
    @State private var title = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(header: Text("カテゴリ")) {
                Picker("報告種別", selection: $category) {
                    Text("バグ報告").tag("bug")
                    Text("機能リクエスト").tag("feature")
                    Text("改善提案").tag("improvement")
                    Text("その他").tag("other")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section(header: Text("タイトル")) {
                TextField("問題の概要を入力", text: $title)
            }

            Section(header: Text("詳細")) {
                TextEditor(text: $description)
                    .frame(height: 150)
            }

            Section(footer: Text("アプリのバージョンとデバイス情報は自動的に送信されます")) {
                HStack {
                    Text("デバイス")
                    Spacer()
                    Text(UIDevice.current.model)
                        .foregroundColor(.gray)
                }

                HStack {
                    Text("iOS バージョン")
                    Spacer()
                    Text(UIDevice.current.systemVersion)
                        .foregroundColor(.gray)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section {
                Button("送信") {
                    Task { await submitReport() }
                }
                .frame(maxWidth: .infinity)
                .disabled(title.isEmpty || description.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("バグ報告・機能リクエスト")
        .navigationBarTitleDisplayMode(.inline)
        .alert("送信完了", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("フィードバックをお送りいただきありがとうございます。")
        }
    }

    private func submitReport() async {
        isSubmitting = true
        errorMessage = nil

        do {
            _ = try await APIClient.shared.submitBugReport(
                category: category,
                title: title,
                description: description,
                deviceInfo: "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
            )
            showSuccess = true
        } catch {
            errorMessage = "送信に失敗しました: \(error.localizedDescription)"
        }
        isSubmitting = false
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    var body: some View {
        WebPageView(
            url: URL(string: "\(StripeConfig.apiBaseURL.replacingOccurrences(of: "/api", with: ""))/terms")!,
            title: "利用規約"
        )
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        WebPageView(
            url: URL(string: "\(StripeConfig.apiBaseURL.replacingOccurrences(of: "/api", with: ""))/privacy")!,
            title: "プライバシーポリシー"
        )
    }
}

// MARK: - WebPage View

import WebKit

struct WebPageView: View {
    let url: URL
    let title: String

    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        Group {
            if loadFailed {
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("ページを読み込めませんでした")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("インターネット接続を確認してください")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 80)
                }
            } else {
                WebViewRepresentable(url: url, isLoading: $isLoading, loadFailed: $loadFailed)
                    .overlay {
                        if isLoading {
                            ProgressView("読み込み中...")
                        }
                    }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewRepresentable

        init(parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadFailed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadFailed = true
        }
    }
}

#Preview {
    NavigationStack {
        JobSeekerNotificationSettingsView()
    }
}
