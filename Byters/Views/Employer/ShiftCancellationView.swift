import SwiftUI

// MARK: - Shift Cancellation View

struct ShiftCancellationView: View {
    let job: Job
    let onCancelled: () -> Void

    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ShiftCancellationViewModel()
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                jobInfoSection
                penaltySection
                reasonSection
                affectedWorkersSection
                cancelButtonSection
            }
            .navigationTitle("シフトキャンセル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("キャンセル確認", isPresented: $showConfirmation) {
                Button("キャンセルする", role: .destructive) {
                    Task { await performCancellation() }
                }
                Button("戻る", role: .cancel) {}
            } message: {
                Text(confirmationMessage)
            }
            .alert("完了", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                    onCancelled()
                }
            } message: {
                Text("シフトのキャンセルが完了しました。対象ワーカーに通知が送信されます。")
            }
            .alert("エラー", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "キャンセルに失敗しました")
            }
            .task {
                viewModel.calculatePenalty(for: job)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var jobInfoSection: some View {
        Section("求人情報") {
            VStack(alignment: .leading, spacing: 8) {
                Text(job.title)
                    .font(.headline)

                if let location = job.location ?? job.address {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let workDate = job.workDate {
                    Label(workDate, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let startTime = job.startTime, let endTime = job.endTime {
                    Label("\(startTime) - \(endTime)", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var penaltySection: some View {
        Section("キャンセルペナルティ") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: viewModel.penaltyLevel.icon)
                        .foregroundColor(viewModel.penaltyLevel.color)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.penaltyLevel.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(viewModel.penaltyLevel.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                if let amount = viewModel.penaltyAmount, amount > 0 {
                    HStack {
                        Text("ペナルティ金額")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(amount)円")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }

                // Penalty tier explanation
                VStack(alignment: .leading, spacing: 6) {
                    Text("ペナルティ基準")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    PenaltyTierRow(label: "開始48時間以上前", detail: "ペナルティなし", color: .green)
                    PenaltyTierRow(label: "開始24〜48時間前", detail: "中程度のペナルティ", color: .orange)
                    PenaltyTierRow(label: "開始24時間以内", detail: "高額ペナルティ", color: .red)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var reasonSection: some View {
        Section("キャンセル理由") {
            Picker("理由を選択", selection: $viewModel.selectedReason) {
                Text("選択してください").tag(CancellationReason?.none)
                ForEach(CancellationReason.allCases, id: \.self) { reason in
                    Text(reason.displayName).tag(CancellationReason?.some(reason))
                }
            }
            .pickerStyle(.menu)

            if viewModel.selectedReason == .other {
                TextField("詳細を入力してください", text: $viewModel.otherReasonText, axis: .vertical)
                    .lineLimit(3...5)
            }

            Toggle("ワーカーに通知する", isOn: $viewModel.notifyWorkers)

            if viewModel.notifyWorkers {
                Text("キャンセル通知がすべての対象ワーカーに送信されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var affectedWorkersSection: some View {
        Section("影響を受けるワーカー") {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                Text("対象ワーカー数")
                Spacer()
                Text("\(viewModel.affectedWorkersCount)名")
                    .fontWeight(.semibold)
            }

            if viewModel.affectedWorkersCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("キャンセルにより、対象ワーカーのシフトが取り消されます")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var cancelButtonSection: some View {
        Section {
            Button(action: { showConfirmation = true }) {
                HStack {
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                        Text("このシフトをキャンセルする")
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .foregroundColor(.white)
            .listRowBackground(
                viewModel.canSubmit ? Color.red : Color.gray.opacity(0.5)
            )
            .disabled(!viewModel.canSubmit || viewModel.isLoading)
        }
    }

    // MARK: - Helpers

    private var confirmationMessage: String {
        var msg = "「\(job.title)」をキャンセルしますか？"
        if let amount = viewModel.penaltyAmount, amount > 0 {
            msg += "\n\nペナルティ: \(amount)円が発生します。"
        }
        if viewModel.affectedWorkersCount > 0 {
            msg += "\n\(viewModel.affectedWorkersCount)名のワーカーに影響があります。"
        }
        msg += "\n\nこの操作は取り消せません。"
        return msg
    }

    private func performCancellation() async {
        await viewModel.cancelJob(jobId: job.id)
    }
}

// MARK: - Penalty Tier Row

private struct PenaltyTierRow: View {
    let label: String
    let detail: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Cancellation Reason

enum CancellationReason: String, CaseIterable {
    case weather = "天候不良"
    case staffSufficient = "人員充足"
    case businessChange = "業務変更"
    case other = "その他"

    var displayName: String { rawValue }
}

// MARK: - Penalty Level

enum ShiftPenaltyLevel {
    case none
    case medium
    case high

    var title: String {
        switch self {
        case .none: return "ペナルティなし"
        case .medium: return "中程度のペナルティ"
        case .high: return "高額ペナルティ"
        }
    }

    var description: String {
        switch self {
        case .none: return "開始まで48時間以上あるため、ペナルティは発生しません"
        case .medium: return "開始まで24〜48時間のため、中程度のペナルティが発生します"
        case .high: return "開始まで24時間以内のため、高額ペナルティが発生します"
        }
    }

    var icon: String {
        switch self {
        case .none: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .none: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - ViewModel

@MainActor
class ShiftCancellationViewModel: ObservableObject {
    @Published var selectedReason: CancellationReason?
    @Published var otherReasonText = ""
    @Published var notifyWorkers = true
    @Published var penaltyLevel: ShiftPenaltyLevel = .none
    @Published var penaltyAmount: Int?
    @Published var affectedWorkersCount: Int = 0
    @Published var isLoading = false
    @Published var showSuccess = false
    @Published var showError = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    var canSubmit: Bool {
        guard let reason = selectedReason else { return false }
        if reason == .other && otherReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    func calculatePenalty(for job: Job) {
        // Calculate hours until job start
        let hoursUntilStart = calculateHoursUntilStart(job: job)

        if hoursUntilStart > 48 {
            penaltyLevel = .none
            penaltyAmount = 0
        } else if hoursUntilStart > 24 {
            penaltyLevel = .medium
            // Medium penalty: 50% of daily wage or estimate from hourly
            let baseWage = job.dailyWage ?? ((job.hourlyWage ?? job.hourlyRate ?? 1000) * 8)
            penaltyAmount = baseWage / 2
        } else {
            penaltyLevel = .high
            // High penalty: full daily wage equivalent
            let baseWage = job.dailyWage ?? ((job.hourlyWage ?? job.hourlyRate ?? 1000) * 8)
            penaltyAmount = baseWage
        }

        // Estimate affected workers from currentApplicants
        affectedWorkersCount = job.currentApplicants ?? 0
    }

    func cancelJob(jobId: String) async {
        guard canSubmit else { return }
        isLoading = true

        let reasonText: String
        if let reason = selectedReason {
            reasonText = reason == .other ? otherReasonText : reason.rawValue
        } else {
            reasonText = ""
        }

        do {
            _ = try await api.cancelShift(
                jobId: jobId,
                reason: reasonText,
                notifyWorkers: notifyWorkers
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    private func calculateHoursUntilStart(job: Job) -> Double {
        guard let workDateStr = job.workDate else { return 72 } // Default: no penalty

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        // Try multiple date formats
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy-MM-dd'T'HH:mm:ss"]
        var workDate: Date?
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: workDateStr) {
                workDate = date
                break
            }
        }

        guard let startDate = workDate else { return 72 }

        // Combine date with start time if available
        var finalStart = startDate
        if let startTime = job.startTime {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            if let time = timeFormatter.date(from: startTime) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                if let combined = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                 minute: timeComponents.minute ?? 0,
                                                 second: 0, of: startDate) {
                    finalStart = combined
                }
            }
        }

        return finalStart.timeIntervalSince(Date()) / 3600.0
    }
}
