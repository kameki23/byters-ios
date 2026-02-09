import SwiftUI

// MARK: - Earnings Goal View

struct EarningsGoalView: View {
    @StateObject private var viewModel = EarningsGoalViewModel()
    @State private var showSetGoalSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Goal Progress
                GoalProgressCard(
                    currentAmount: viewModel.currentEarnings,
                    goalAmount: viewModel.goalAmount,
                    period: viewModel.goalPeriod
                )

                // Quick Stats
                HStack(spacing: 12) {
                    StatCard(
                        title: "今月の収入",
                        value: "¥\(viewModel.thisMonthEarnings.formatted())",
                        icon: "calendar",
                        color: .blue
                    )

                    StatCard(
                        title: "残り日数",
                        value: "\(viewModel.remainingDays)日",
                        icon: "clock",
                        color: .orange
                    )
                }

                // Daily Target
                if viewModel.goalAmount > 0 {
                    DailyTargetCard(
                        dailyTarget: viewModel.dailyTarget,
                        remainingAmount: viewModel.remainingAmount,
                        remainingDays: viewModel.remainingDays
                    )
                }

                // Earnings History Chart
                EarningsChartView(weeklyData: viewModel.weeklyEarnings)

                // Recent Earnings
                RecentEarningsSection(earnings: viewModel.recentEarnings)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("収入目標")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSetGoalSheet = true }) {
                    Image(systemName: "target")
                }
            }
        }
        .sheet(isPresented: $showSetGoalSheet) {
            SetGoalSheet(
                currentGoal: viewModel.goalAmount,
                currentPeriod: viewModel.goalPeriod
            ) { newGoal, period in
                Task { await viewModel.setGoal(amount: newGoal, period: period) }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }
}

struct GoalProgressCard: View {
    let currentAmount: Int
    let goalAmount: Int
    let period: String

    var progress: Double {
        guard goalAmount > 0 else { return 0 }
        return min(Double(currentAmount) / Double(goalAmount), 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("¥\(currentAmount.formatted())")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                Spacer()

                if goalAmount > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("目標")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("¥\(goalAmount.formatted())")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }

            if goalAmount > 0 {
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 8)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 16)

                    HStack {
                        Text("\(Int(progress * 100))% 達成")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(progressColor)

                        Spacer()

                        if currentAmount < goalAmount {
                            Text("あと ¥\((goalAmount - currentAmount).formatted())")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("目標達成!")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
            } else {
                Text("目標を設定してモチベーションを高めよう!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var periodText: String {
        switch period {
        case "monthly": return "今月の収入"
        case "weekly": return "今週の収入"
        default: return "収入"
        }
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.75 { return .blue }
        if progress >= 0.5 { return .orange }
        return .red
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct DailyTargetCard: View {
    let dailyTarget: Int
    let remainingAmount: Int
    let remainingDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目標達成のために")
                .font(.subheadline)
                .foregroundColor(.gray)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1日あたり")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("¥\(dailyTarget.formatted())")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Spacer()

                if remainingDays > 0 {
                    Text("稼ぐ必要があります")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EarningsChartView: View {
    let weeklyData: [DayEarnings]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("週間推移")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyData) { day in
                    VStack(spacing: 4) {
                        if day.amount > 0 {
                            Text("¥\(day.amount / 1000)k")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.isToday ? Color.blue : Color.blue.opacity(0.3))
                            .frame(width: 30, height: barHeight(for: day.amount))

                        Text(day.dayLabel)
                            .font(.caption)
                            .foregroundColor(day.isToday ? .blue : .gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .padding(.top, 20)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func barHeight(for amount: Int) -> CGFloat {
        let maxAmount = weeklyData.map { $0.amount }.max() ?? 1
        guard maxAmount > 0 else { return 10 }
        let ratio = CGFloat(amount) / CGFloat(maxAmount)
        return max(ratio * 100, 10)
    }
}

struct RecentEarningsSection: View {
    let earnings: [EarningRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の収入")
                .font(.headline)

            if earnings.isEmpty {
                Text("まだ収入記録がありません")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.vertical)
            } else {
                ForEach(earnings) { earning in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(earning.jobTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(earning.date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text("+¥\(earning.amount.formatted())")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)

                    if earning.id != earnings.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Set Goal Sheet

struct SetGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goalAmount: String
    @State private var selectedPeriod: String
    let onSave: (Int, String) async -> Void

    init(currentGoal: Int, currentPeriod: String, onSave: @escaping (Int, String) async -> Void) {
        _goalAmount = State(initialValue: currentGoal > 0 ? String(currentGoal) : "")
        _selectedPeriod = State(initialValue: currentPeriod.isEmpty ? "monthly" : currentPeriod)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("目標金額") {
                    HStack {
                        Text("¥")
                        TextField("目標金額を入力", text: $goalAmount)
                            .keyboardType(.numberPad)
                    }
                }

                Section("期間") {
                    Picker("期間", selection: $selectedPeriod) {
                        Text("月間").tag("monthly")
                        Text("週間").tag("weekly")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("おすすめ目標")
                            .font(.caption)
                            .foregroundColor(.gray)

                        HStack(spacing: 12) {
                            GoalPresetButton(amount: 50000) { goalAmount = "50000" }
                            GoalPresetButton(amount: 100000) { goalAmount = "100000" }
                            GoalPresetButton(amount: 150000) { goalAmount = "150000" }
                        }
                    }
                }
            }
            .navigationTitle("目標を設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await onSave(Int(goalAmount) ?? 0, selectedPeriod)
                            dismiss()
                        }
                    }
                    .disabled(goalAmount.isEmpty)
                }
            }
        }
    }
}

struct GoalPresetButton: View {
    let amount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("¥\(amount / 10000)万")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
    }
}

// MARK: - ViewModel

@MainActor
class EarningsGoalViewModel: ObservableObject {
    @Published var currentEarnings: Int = 0
    @Published var goalAmount: Int = 0
    @Published var goalPeriod: String = "monthly"
    @Published var thisMonthEarnings: Int = 0
    @Published var remainingDays: Int = 0
    @Published var weeklyEarnings: [DayEarnings] = []
    @Published var recentEarnings: [EarningRecord] = []

    var remainingAmount: Int {
        max(goalAmount - currentEarnings, 0)
    }

    var dailyTarget: Int {
        guard remainingDays > 0, remainingAmount > 0 else { return 0 }
        return remainingAmount / remainingDays
    }

    private let api = APIClient.shared

    func loadData() async {
        // Calculate remaining days in month
        let calendar = Calendar.current
        let now = Date()
        if let range = calendar.range(of: .day, in: .month, for: now) {
            let currentDay = calendar.component(.day, from: now)
            remainingDays = range.count - currentDay
        }

        // Load earnings goal from API
        do {
            let goalData = try await api.getEarningsGoal()
            goalAmount = goalData.goalAmount
            goalPeriod = goalData.period
            currentEarnings = goalData.currentEarnings
            thisMonthEarnings = goalData.currentEarnings
        } catch {
            print("Failed to load earnings goal: \(error)")
        }

        // Load weekly earnings
        weeklyEarnings = generateWeeklyData()

        // Load recent earnings
        do {
            recentEarnings = try await api.getRecentEarnings()
        } catch {
            print("Failed to load recent earnings: \(error)")
        }
    }

    func setGoal(amount: Int, period: String) async {
        do {
            _ = try await api.setEarningsGoal(amount: amount, period: period)
            goalAmount = amount
            goalPeriod = period
        } catch {
            print("Failed to set goal: \(error)")
        }
    }

    private func generateWeeklyData() -> [DayEarnings] {
        let calendar = Calendar.current
        let today = Date()
        var data: [DayEarnings] = []

        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayFormatter = DateFormatter()
                dayFormatter.locale = Locale(identifier: "ja_JP")
                dayFormatter.dateFormat = "E"
                let dayLabel = dayFormatter.string(from: date)

                data.append(DayEarnings(
                    id: String(i),
                    dayLabel: dayLabel,
                    amount: 0, // Will be filled from API
                    isToday: i == 0
                ))
            }
        }

        return data
    }
}

// MARK: - Models

struct DayEarnings: Identifiable {
    let id: String
    let dayLabel: String
    let amount: Int
    let isToday: Bool
}

struct EarningRecord: Codable, Identifiable {
    let id: String
    let jobTitle: String
    let amount: Int
    let date: String
}

struct EarningsGoalData: Codable {
    let goalAmount: Int
    let period: String
    let currentEarnings: Int
}
