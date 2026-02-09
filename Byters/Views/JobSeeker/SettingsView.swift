import SwiftUI

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
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
            print("Failed to load notification settings: \(error)")
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
            print("Failed to load email settings: \(error)")
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
            print("Failed to load location settings: \(error)")
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

    private let api = APIClient.shared

    func loadMutedEmployers() async {
        isLoading = true
        do {
            mutedEmployers = try await api.getMutedEmployers()
        } catch {
            print("Failed to load muted employers: \(error)")
        }
        isLoading = false
    }

    func unmuteEmployer(id: String) async {
        do {
            _ = try await api.unmuteEmployer(employerId: id)
            await loadMutedEmployers()
        } catch {
            print("Failed to unmute employer: \(error)")
        }
    }
}

// MARK: - Timesheet Adjustment Request View

struct TimesheetAdjustmentView: View {
    @StateObject private var viewModel = TimesheetAdjustmentViewModel()
    @State private var showRequestSheet = false

    var body: some View {
        List {
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
    @State private var requestedCheckIn = ""
    @State private var requestedCheckOut = ""
    @State private var reason = ""
    @State private var isLoading = false

    let onComplete: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("修正希望時間")) {
                    TextField("出勤時刻（例: 09:00）", text: $requestedCheckIn)
                    TextField("退勤時刻（例: 18:00）", text: $requestedCheckOut)
                }

                Section(header: Text("修正理由")) {
                    TextEditor(text: $reason)
                        .frame(height: 100)
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
                    .disabled(reason.isEmpty || isLoading)
                }
            }
        }
    }

    private func submitRequest() async {
        isLoading = true
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
            print("Failed to submit request: \(error)")
        }
        isLoading = false
    }
}

@MainActor
class TimesheetAdjustmentViewModel: ObservableObject {
    @Published var adjustments: [TimesheetAdjustment] = []
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadAdjustments() async {
        isLoading = true
        do {
            adjustments = try await api.getMyTimesheetAdjustments()
        } catch {
            print("Failed to load adjustments: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Tax Documents View (源泉徴収票)

struct TaxDocumentsView: View {
    @StateObject private var viewModel = TaxDocumentsViewModel()

    var body: some View {
        List {
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
                // Download or view document
            }) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
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

    private let api = APIClient.shared

    func loadDocuments() async {
        isLoading = true
        do {
            documents = try await api.getTaxDocuments()
        } catch {
            print("Failed to load tax documents: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Upcoming Work View (予定のお仕事)

struct UpcomingWorkView: View {
    @StateObject private var viewModel = UpcomingWorkViewModel()

    var body: some View {
        List {
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
                            UpcomingWorkRow(work: work)
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

            if work.canCheckIn {
                HStack {
                    Spacer()
                    Button(action: {
                        // Check-in action
                    }) {
                        HStack {
                            Image(systemName: "clock.badge.checkmark")
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
            print("Failed to load upcoming work: \(error)")
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
        NavigationStack {
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
                    // Device info display
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
            }
            .navigationTitle("バグ報告・機能リクエスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送信") {
                        Task { await submitReport() }
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                }
            }
            .alert("送信完了", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("フィードバックをお送りいただきありがとうございます。")
            }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("利用規約")
                    .font(.title)
                    .fontWeight(.bold)

                Text("最終更新日: 2024年1月1日")
                    .font(.caption)
                    .foregroundColor(.gray)

                Group {
                    Text("第1条（適用）")
                        .font(.headline)
                    Text("本規約は、本サービスの利用に関する条件を、本サービスを利用する全てのユーザーと当社との間で定めるものです。")

                    Text("第2条（定義）")
                        .font(.headline)
                    Text("「本サービス」とは、当社が提供する短期アルバイトマッチングサービス「Byters」をいいます。")

                    Text("第3条（利用登録）")
                        .font(.headline)
                    Text("本サービスの利用を希望する者は、当社の定める方法により利用登録を行うものとします。")

                    Text("第4条（禁止事項）")
                        .font(.headline)
                    Text("""
                    ユーザーは、本サービスの利用にあたり、以下の行為をしてはなりません。
                    - 法令または公序良俗に違反する行為
                    - 犯罪行為に関連する行為
                    - 当社のサーバーまたはネットワークの機能を破壊したり、妨害したりする行為
                    - 他のユーザーに成りすます行為
                    - 本サービスの運営を妨害する行為
                    """)
                }

                Text("第5条（免責事項）")
                    .font(.headline)
                Text("当社は、本サービスに関連してユーザーに生じた損害について、一切の責任を負いません。")
            }
            .padding()
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("プライバシーポリシー")
                    .font(.title)
                    .fontWeight(.bold)

                Text("最終更新日: 2024年1月1日")
                    .font(.caption)
                    .foregroundColor(.gray)

                Group {
                    Text("1. 収集する情報")
                        .font(.headline)
                    Text("""
                    当社は、以下の情報を収集する場合があります：
                    - 氏名、メールアドレス、電話番号などの個人情報
                    - 本人確認書類の画像
                    - 位置情報
                    - デバイス情報
                    """)

                    Text("2. 情報の利用目的")
                        .font(.headline)
                    Text("""
                    収集した情報は、以下の目的で利用します：
                    - 本サービスの提供・運営
                    - ユーザーからのお問い合わせへの対応
                    - 本サービスの改善
                    - 新機能やキャンペーンのお知らせ
                    """)

                    Text("3. 情報の第三者提供")
                        .font(.headline)
                    Text("当社は、法令に基づく場合を除き、ユーザーの同意なく個人情報を第三者に提供しません。")

                    Text("4. 情報の管理")
                        .font(.headline)
                    Text("当社は、個人情報の漏洩、紛失、破損を防止するため、適切なセキュリティ対策を講じます。")
                }

                Text("5. お問い合わせ")
                    .font(.headline)
                Text("プライバシーポリシーに関するお問い合わせは、アプリ内のお問い合わせフォームよりお願いします。")
            }
            .padding()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
