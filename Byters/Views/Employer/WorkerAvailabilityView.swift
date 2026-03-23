import SwiftUI

// MARK: - Worker Availability Model

struct WorkerAvailability: Codable, Identifiable {
    let id: String
    let workerId: String
    let workerName: String
    let workerRating: Double
    let completionRate: Double
    let availableDates: [String] // ISO dates "YYYY-MM-DD"
    let preferredTimeSlots: [String]? // "morning", "afternoon", "evening"
}

// MARK: - Worker Availability Calendar View

struct WorkerAvailabilityView: View {
    @StateObject private var viewModel = WorkerAvailabilityViewModel()
    @State private var selectedDate: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Month Navigation
                monthNavigationHeader

                // Weekday Headers
                weekdayHeaders

                // Calendar Grid
                calendarGrid

                // Legend
                legendView

                // Selected Date Workers
                if let date = selectedDate {
                    selectedDateWorkersSection(for: date)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ワーカー空き状況")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAvailability()
        }
    }

    // MARK: - Month Navigation

    private var monthNavigationHeader: some View {
        HStack {
            Button(action: { viewModel.goToPreviousMonth() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            Spacer()

            Text(viewModel.currentMonthYearString)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: { viewModel.goToNextMonth() }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : .gray))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = viewModel.daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { day in
                if let day = day {
                    let status = viewModel.availabilityStatus(for: day)
                    let isSelected = isSameDay(day, selectedDate)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = day
                        }
                    }) {
                        CalendarDayCell(
                            day: Calendar.current.component(.day, from: day),
                            status: status,
                            isSelected: isSelected,
                            isToday: isSameDay(day, Date())
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 20) {
            legendItem(color: .green, label: "空きあり")
            legendItem(color: .yellow, label: "一部空き")
            legendItem(color: Color(.systemGray4), label: "空きなし")
        }
        .font(.caption)
        .padding(.horizontal)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.6))
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Workers for Selected Date

    private func selectedDateWorkersSection(for date: Date) -> some View {
        let dateString = viewModel.isoDateString(from: date)
        let workers = viewModel.workers(availableOn: dateString)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.displayDateString(from: date))
                    .font(.headline)
                Text("の空きワーカー")
                    .font(.headline)
                Spacer()
                Text("\(workers.count)名")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            if workers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("この日に空いているワーカーはいません")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(workers) { worker in
                    WorkerAvailabilityCard(
                        worker: worker,
                        dateString: dateString,
                        onInvite: {
                            viewModel.inviteWorker(workerId: worker.workerId, date: dateString)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func isSameDay(_ date1: Date?, _ date2: Date?) -> Bool {
        guard let d1 = date1, let d2 = date2 else { return false }
        return Calendar.current.isDate(d1, inSameDayAs: d2)
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let day: Int
    let status: DayAvailabilityStatus
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .frame(height: 44)

            // Selection ring
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2.5)
                    .frame(height: 44)
            }

            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundColor(textColor)

                // Availability dot
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var backgroundColor: Color {
        if isToday {
            return Color.blue.opacity(0.1)
        }
        return Color.clear
    }

    private var textColor: Color {
        if isToday { return .blue }
        return .primary
    }

    private var dotColor: Color {
        switch status {
        case .available:
            return .green
        case .partial:
            return .yellow
        case .unavailable:
            return Color(.systemGray4)
        case .unknown:
            return .clear
        }
    }
}

// MARK: - Worker Availability Card

struct WorkerAvailabilityCard: View {
    let worker: WorkerAvailability
    let dateString: String
    let onInvite: () -> Void
    @State private var isInvited = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(String(worker.workerName.prefix(1)))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(worker.workerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", worker.workerRating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Completion Rate
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(Int(worker.completionRate))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Time Slots
                if let slots = worker.preferredTimeSlots, !slots.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(slots, id: \.self) { slot in
                            Text(timeSlotLabel(slot))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            // Invite Button
            Button(action: {
                isInvited = true
                onInvite()
            }) {
                if isInvited {
                    Label("招待済み", systemImage: "checkmark")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("招待する")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(isInvited)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func timeSlotLabel(_ slot: String) -> String {
        switch slot {
        case "morning": return "午前"
        case "afternoon": return "午後"
        case "evening": return "夜間"
        default: return slot
        }
    }
}

// MARK: - Day Availability Status

enum DayAvailabilityStatus {
    case available   // Many workers available
    case partial     // Few workers available
    case unavailable // No workers available
    case unknown     // No data
}

// MARK: - ViewModel

@MainActor
class WorkerAvailabilityViewModel: ObservableObject {
    @Published var availabilities: [WorkerAvailability] = []
    @Published var currentMonth: Date = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inviteMessage: String?

    private let api = APIClient.shared
    private let calendar = Calendar.current
    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日（E）"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    var currentMonthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: currentMonth)
    }

    // MARK: - Data Loading

    func loadAvailability() async {
        isLoading = true
        defer { isLoading = false }

        let monthString = monthFormatter.string(from: currentMonth)
        do {
            availabilities = try await api.getWorkerAvailability(month: monthString)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Month Navigation

    func goToPreviousMonth() {
        if let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = prev
            Task { await loadAvailability() }
        }
    }

    func goToNextMonth() {
        if let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = next
            Task { await loadAvailability() }
        }
    }

    // MARK: - Calendar Days

    func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) - 1 // Sunday = 0

        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        // Pad trailing
        let remaining = (7 - (days.count % 7)) % 7
        for _ in 0..<remaining {
            days.append(nil)
        }

        return days
    }

    // MARK: - Availability Status

    func availabilityStatus(for date: Date) -> DayAvailabilityStatus {
        let dateStr = isoDateString(from: date)
        let count = availabilities.filter { $0.availableDates.contains(dateStr) }.count

        if count >= 3 {
            return .available
        } else if count >= 1 {
            return .partial
        } else {
            return .unavailable
        }
    }

    func workers(availableOn dateString: String) -> [WorkerAvailability] {
        return availabilities.filter { $0.availableDates.contains(dateString) }
    }

    // MARK: - Invite

    func inviteWorker(workerId: String, date: String) {
        // Fire-and-forget invite
        Task {
            do {
                _ = try await api.inviteWorkerForDate(workerId: workerId, date: date)
                inviteMessage = "招待を送信しました"
            } catch {
                inviteMessage = "招待の送信に失敗しました"
            }
        }
    }

    // MARK: - Formatting

    func isoDateString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    func displayDateString(from date: Date) -> String {
        displayFormatter.string(from: date)
    }
}
