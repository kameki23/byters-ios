import SwiftUI

// MARK: - Cancellation Policy View

struct EnhancedCancellationPolicyView: View {
    @State private var penalties: [Penalty] = []
    @State private var isLoading = true
    @State private var showHistory = false

    private let api = APIClient.shared

    private var activePenaltyPoints: Int {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterFallback = ISO8601DateFormatter()
        formatterFallback.formatOptions = [.withInternetDateTime]

        return penalties.filter { penalty in
            guard let expiresStr = penalty.expiresAt else { return true }
            if let expires = formatter.date(from: expiresStr) {
                return expires > now
            }
            if let expires = formatterFallback.date(from: expiresStr) {
                return expires > now
            }
            return true
        }.reduce(0) { $0 + $1.penaltyPoints }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Points
                currentPointsCard

                // Policy Timeline
                policyTimeline

                // Penalty History Link
                historyLink

                // FAQ
                faqSection
            }
            .padding()
        }
        .navigationTitle("キャンセルポリシー")
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showHistory) {
            NavigationView {
                PenaltyHistoryView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { showHistory = false }
                        }
                    }
            }
        }
        .task {
            await loadPenalties()
        }
    }

    // MARK: - Current Points Card

    private var currentPointsCard: some View {
        VStack(spacing: 12) {
            Text("現在のペナルティポイント")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if isLoading {
                ProgressView()
                    .frame(height: 50)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(activePenaltyPoints)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(pointsColor)
                    Text("pt")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                Text(pointsStatusText)
                    .font(.caption)
                    .foregroundColor(pointsColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(pointsColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var pointsColor: Color {
        if activePenaltyPoints >= 5 { return .red }
        if activePenaltyPoints >= 3 { return .orange }
        if activePenaltyPoints >= 1 { return .yellow }
        return .green
    }

    private var pointsStatusText: String {
        if activePenaltyPoints >= 5 { return "アカウント一時停止の可能性" }
        if activePenaltyPoints >= 3 { return "注意が必要です" }
        if activePenaltyPoints >= 1 { return "軽度の警告" }
        return "問題なし"
    }

    // MARK: - Policy Timeline

    private var policyTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("キャンセル時のペナルティ")
                .font(.headline)
                .padding(.bottom, 16)

            policyTier(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "24時間前まで",
                subtitle: "ペナルティなし",
                points: nil,
                description: "自由にキャンセルできます",
                isLast: false
            )

            policyTier(
                icon: "exclamationmark.circle.fill",
                iconColor: .yellow,
                title: "12〜24時間前",
                subtitle: "警告",
                points: nil,
                description: "警告が記録されますが、ポイントは付与されません",
                isLast: false
            )

            policyTier(
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                title: "6〜12時間前",
                subtitle: "軽度ペナルティ",
                points: 1,
                description: "1ポイントのペナルティが付与されます",
                isLast: false
            )

            policyTier(
                icon: "xmark.circle.fill",
                iconColor: .red,
                title: "6時間以内",
                subtitle: "重度ペナルティ",
                points: 3,
                description: "3ポイントのペナルティが付与されます",
                isLast: false
            )

            policyTier(
                icon: "nosign",
                iconColor: .red,
                title: "無断欠勤",
                subtitle: "5pt + 一時停止",
                points: 5,
                description: "5ポイント付与に加え、アカウントが一時停止されます",
                isLast: true
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func policyTier(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        points: Int?,
        description: String,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)

                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(subtitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(iconColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let pts = points {
                    Text("+\(pts)ポイント")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(iconColor)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
    }

    // MARK: - History Link

    private var historyLink: some View {
        Button {
            showHistory = true
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text("ペナルティ履歴を見る")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("よくある質問")
                .font(.headline)

            faqItem(
                question: "ペナルティポイントはいつ消えますか？",
                answer: "ペナルティポイントは付与日から90日後に自動的に失効します。"
            )

            faqItem(
                question: "アカウント一時停止とは？",
                answer: "累計ペナルティポイントが5pt以上になると、一時的にお仕事への応募ができなくなります。ポイントが失効して5pt未満になると自動的に解除されます。"
            )

            faqItem(
                question: "体調不良の場合はどうなりますか？",
                answer: "やむを得ない事情の場合でも、直前のキャンセルにはペナルティが発生します。できるだけ早くキャンセル手続きを行ってください。"
            )

            faqItem(
                question: "ペナルティに異議がある場合は？",
                answer: "ヘルプセンターからお問い合わせください。状況を確認の上、対応いたします。"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func faqItem(question: String, answer: String) -> some View {
        DisclosureGroup {
            Text(answer)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        } label: {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Actions

    private func loadPenalties() async {
        isLoading = true
        do {
            penalties = try await api.getPenalties()
        } catch {
            // Use empty array on failure
        }
        isLoading = false
    }
}

// MARK: - Cancel Confirmation Sheet

struct CancelConfirmationSheet: View {
    let jobTitle: String
    let workDate: String?
    let startTime: String?
    let hoursUntilStart: Double?
    var onConfirm: ((String) -> Void)?
    var onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: String?
    @State private var isSubmitting = false

    private let reasons = [
        "体調不良",
        "急用",
        "交通機関の問題",
        "その他"
    ]

    private var penaltyLevel: PenaltyLevel {
        guard let hours = hoursUntilStart else { return .none }
        if hours >= 24 { return .none }
        if hours >= 12 { return .warning }
        if hours >= 6 { return .light }
        return .severe
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Job info
                    jobInfoSection

                    // Penalty warning
                    penaltyWarningSection

                    // Reason selection
                    reasonSection

                    // Buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("キャンセル確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") {
                        onCancel?()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Job Info

    private var jobInfoSection: some View {
        VStack(spacing: 8) {
            Text(jobTitle)
                .font(.headline)

            HStack(spacing: 16) {
                if let date = workDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(date)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }

                if let time = startTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(time)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Penalty Warning

    private var penaltyWarningSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: penaltyLevel.icon)
                    .font(.title3)
                    .foregroundColor(penaltyLevel.color)

                Text(penaltyLevel.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(penaltyLevel.color)
            }

            Text(penaltyLevel.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let points = penaltyLevel.points {
                Text("+\(points)ペナルティポイント")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(penaltyLevel.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(penaltyLevel.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(penaltyLevel.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(penaltyLevel.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Reason Selection

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("キャンセル理由を選択してください")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(reasons, id: \.self) { reason in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedReason = reason
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedReason == reason ? .blue : Color(.systemGray3))

                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding()
                    .background(selectedReason == reason ? Color.blue.opacity(0.06) : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                guard let reason = selectedReason else { return }
                isSubmitting = true
                AnalyticsService.shared.track("cancellation_confirmed", properties: [
                    "reason": reason,
                    "penalty_level": penaltyLevel.rawValue,
                    "hours_until_start": hoursUntilStart.map { String(format: "%.1f", $0) } ?? "unknown"
                ])
                onConfirm?(reason)
                dismiss()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("キャンセルする")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedReason != nil ? Color.red : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedReason == nil || isSubmitting)

            Button {
                onCancel?()
                dismiss()
            } label: {
                Text("キャンセルしない")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Penalty Level

private enum PenaltyLevel: String {
    case none
    case warning
    case light
    case severe

    var title: String {
        switch self {
        case .none: return "ペナルティなし"
        case .warning: return "警告"
        case .light: return "軽度ペナルティ"
        case .severe: return "重度ペナルティ"
        }
    }

    var description: String {
        switch self {
        case .none: return "24時間以上前のキャンセルのため、ペナルティは発生しません。"
        case .warning: return "12〜24時間前のキャンセルです。警告として記録されます。"
        case .light: return "6〜12時間前のキャンセルです。ペナルティポイントが付与されます。"
        case .severe: return "6時間以内のキャンセルです。重度のペナルティが発生します。"
        }
    }

    var icon: String {
        switch self {
        case .none: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .light: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .none: return .green
        case .warning: return .yellow
        case .light: return .orange
        case .severe: return .red
        }
    }

    var points: Int? {
        switch self {
        case .none: return nil
        case .warning: return nil
        case .light: return 1
        case .severe: return 3
        }
    }
}

// MARK: - Penalty History View

struct DetailedPenaltyHistoryView: View {
    @State private var penalties: [Penalty] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let api = APIClient.shared

    private var activePenalties: [Penalty] {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterFallback = ISO8601DateFormatter()
        formatterFallback.formatOptions = [.withInternetDateTime]

        return penalties.filter { penalty in
            guard let expiresStr = penalty.expiresAt else { return true }
            if let expires = formatter.date(from: expiresStr) {
                return expires > now
            }
            if let expires = formatterFallback.date(from: expiresStr) {
                return expires > now
            }
            return true
        }
    }

    private var totalActivePoints: Int {
        activePenalties.reduce(0) { $0 + $1.penaltyPoints }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.gray)
                    Button("再読み込み") {
                        Task { await loadPenalties() }
                    }
                }
                .padding()
            } else if penalties.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("ペナルティはありません")
                        .foregroundColor(.gray)
                    Text("この調子で頑張りましょう！")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary
                        summaryCard

                        // Penalty list
                        LazyVStack(spacing: 10) {
                            ForEach(penalties) { penalty in
                                penaltyRow(penalty)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("ペナルティ履歴")
        .task {
            await loadPenalties()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(totalActivePoints)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(totalActivePoints >= 5 ? .red : totalActivePoints >= 3 ? .orange : .primary)
                Text("有効ポイント")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 50)

            VStack(spacing: 4) {
                Text("\(activePenalties.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("有効件数")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 50)

            VStack(spacing: 4) {
                Text("\(penalties.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text("累計件数")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Penalty Row

    private func penaltyRow(_ penalty: Penalty) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: penalty.typeIcon)
                .font(.title3)
                .foregroundColor(penaltyTypeColor(penalty.type))
                .frame(width: 36, height: 36)
                .background(penaltyTypeColor(penalty.type).opacity(0.12))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(penalty.typeDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("+\(penalty.penaltyPoints)pt")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(penaltyTypeColor(penalty.type))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(penaltyTypeColor(penalty.type).opacity(0.12))
                        .clipShape(Capsule())
                }

                if let title = penalty.jobTitle {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let reason = penalty.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    if let created = penalty.createdAt {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(formatDate(created))
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                    }

                    if let expires = penalty.expiresAt {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text("期限: \(formatDate(expires))")
                        }
                        .font(.caption2)
                        .foregroundColor(isExpired(expires) ? .green : .gray)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .opacity(isExpiredPenalty(penalty) ? 0.6 : 1.0)
    }

    // MARK: - Helpers

    private func penaltyTypeColor(_ type: String) -> Color {
        switch type {
        case "no_show": return .red
        case "late_cancel": return .orange
        case "early_leave": return .yellow
        case "late_arrival": return .blue
        case "violation": return .red
        default: return .gray
        }
    }

    private func isExpired(_ dateString: String) -> Bool {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date <= now
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date <= now
        }
        return false
    }

    private func isExpiredPenalty(_ penalty: Penalty) -> Bool {
        guard let expires = penalty.expiresAt else { return false }
        return isExpired(expires)
    }

    private func loadPenalties() async {
        isLoading = true
        errorMessage = nil
        do {
            penalties = try await api.getPenalties()
        } catch {
            errorMessage = "ペナルティ履歴の読み込みに失敗しました"
        }
        isLoading = false
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "yyyy/M/d"
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ja_JP")
            display.dateFormat = "yyyy/M/d"
            return display.string(from: date)
        }
        return dateString
    }
}
