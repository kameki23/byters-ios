import SwiftUI
import MapKit
import CoreLocation

struct JobSearchView: View {
    @StateObject private var viewModel = JobSearchViewModel()
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var showMap = false
    @State private var showFavorites = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("キーワードで検索", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            Task {
                                await viewModel.search()
                            }
                        }

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top)

                // Quick Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Today button
                        QuickFilterButton(
                            title: "今日",
                            icon: "sun.max.fill",
                            isActive: viewModel.selectedDateFilter == .today
                        ) {
                            viewModel.selectedDateFilter = viewModel.selectedDateFilter == .today ? nil : .today
                            Task { await viewModel.search() }
                        }

                        // Tomorrow button
                        QuickFilterButton(
                            title: "明日",
                            icon: "sunrise.fill",
                            isActive: viewModel.selectedDateFilter == .tomorrow
                        ) {
                            viewModel.selectedDateFilter = viewModel.selectedDateFilter == .tomorrow ? nil : .tomorrow
                            Task { await viewModel.search() }
                        }

                        // This week button
                        QuickFilterButton(
                            title: "今週",
                            icon: "calendar",
                            isActive: viewModel.selectedDateFilter == .thisWeek
                        ) {
                            viewModel.selectedDateFilter = viewModel.selectedDateFilter == .thisWeek ? nil : .thisWeek
                            Task { await viewModel.search() }
                        }

                        Divider()
                            .frame(height: 30)

                        // Area filter
                        FilterChip(
                            title: viewModel.selectedPrefecture ?? "エリア",
                            isActive: viewModel.selectedPrefecture != nil
                        ) {
                            showFilters = true
                        }

                        // Wage filter
                        FilterChip(
                            title: viewModel.selectedWageRange?.display ?? "時給",
                            isActive: viewModel.selectedWageRange != nil
                        ) {
                            showFilters = true
                        }

                        // Category filter
                        FilterChip(
                            title: viewModel.selectedCategory ?? "カテゴリ",
                            isActive: viewModel.selectedCategory != nil
                        ) {
                            showFilters = true
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Results Count & Active Filters Display
                HStack {
                    Text("\(viewModel.jobs.count)件の求人")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    if viewModel.hasActiveFilters {
                        Button(action: {
                            viewModel.clearFilters()
                            Task { await viewModel.search() }
                        }) {
                            Text("フィルターをクリア")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                // View Mode Toggle
                HStack {
                    Picker("View Mode", selection: $showMap) {
                        Image(systemName: "list.bullet").tag(false)
                        Image(systemName: "map").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)

                    Spacer()

                    // Sort options
                    Menu {
                        Button(action: { viewModel.sortBy = .newest }) {
                            Label("新着順", systemImage: viewModel.sortBy == .newest ? "checkmark" : "")
                        }
                        Button(action: { viewModel.sortBy = .wageHigh }) {
                            Label("時給が高い順", systemImage: viewModel.sortBy == .wageHigh ? "checkmark" : "")
                        }
                        Button(action: { viewModel.sortBy = .wageLow }) {
                            Label("時給が低い順", systemImage: viewModel.sortBy == .wageLow ? "checkmark" : "")
                        }
                        Button(action: { viewModel.sortBy = .dateNearest }) {
                            Label("勤務日が近い順", systemImage: viewModel.sortBy == .dateNearest ? "checkmark" : "")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(viewModel.sortBy.display)
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Error Display
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                        Button("再試行") {
                            Task { await viewModel.search() }
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                }

                // Results
                if viewModel.isLoading {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(0..<5, id: \.self) { _ in
                                JobSkeletonRow()
                            }
                        }
                        .padding()
                    }
                } else if viewModel.jobs.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "求人が見つかりません",
                        message: "検索条件を変更してお試しください"
                    )
                    Spacer()
                } else if showMap {
                    JobMapView(jobs: viewModel.jobs)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.jobs) { job in
                                NavigationLink(destination: JobDetailView(jobId: job.id)) {
                                    JobListRow(
                                        job: job,
                                        isFavorite: viewModel.favoriteJobIds.contains(job.id),
                                        onFavoriteToggle: {
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                            Task {
                                                await viewModel.toggleFavorite(jobId: job.id)
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.search()
                    }
                }
            }
            .navigationTitle("求人検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showFavorites = true }) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                    .accessibilityLabel("お気に入り一覧")
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheetView(viewModel: viewModel) {
                    showFilters = false
                    Task { await viewModel.search() }
                }
            }
            .sheet(isPresented: $showFavorites) {
                FavoriteJobsView()
            }
        }
        .task {
            await viewModel.loadJobs()
            await viewModel.loadFavorites()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.keyword = newValue
        }
    }
}

// MARK: - View Model

enum DateFilter: Equatable {
    case today, tomorrow, thisWeek, custom(Date)

    var display: String {
        switch self {
        case .today: return "今日"
        case .tomorrow: return "明日"
        case .thisWeek: return "今週"
        case .custom(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }

    static func == (lhs: DateFilter, rhs: DateFilter) -> Bool {
        switch (lhs, rhs) {
        case (.today, .today): return true
        case (.tomorrow, .tomorrow): return true
        case (.thisWeek, .thisWeek): return true
        case (.custom(let d1), .custom(let d2)): return d1 == d2
        default: return false
        }
    }
}

enum WageRange: CaseIterable {
    case any, over1000, over1200, over1500, over2000

    var display: String {
        switch self {
        case .any: return "指定なし"
        case .over1000: return "¥1,000〜"
        case .over1200: return "¥1,200〜"
        case .over1500: return "¥1,500〜"
        case .over2000: return "¥2,000〜"
        }
    }

    var minWage: Int? {
        switch self {
        case .any: return nil
        case .over1000: return 1000
        case .over1200: return 1200
        case .over1500: return 1500
        case .over2000: return 2000
        }
    }
}

enum SortOption {
    case newest, wageHigh, wageLow, dateNearest

    var display: String {
        switch self {
        case .newest: return "新着順"
        case .wageHigh: return "時給高い順"
        case .wageLow: return "時給低い順"
        case .dateNearest: return "日付近い順"
        }
    }
}

enum DistanceFilter: CaseIterable {
    case any, within5km, within10km, within20km, within30km

    var display: String {
        switch self {
        case .any: return "指定なし"
        case .within5km: return "5km以内"
        case .within10km: return "10km以内"
        case .within20km: return "20km以内"
        case .within30km: return "30km以内"
        }
    }

    var radiusKm: Int? {
        switch self {
        case .any: return nil
        case .within5km: return 5
        case .within10km: return 10
        case .within20km: return 20
        case .within30km: return 30
        }
    }
}

@MainActor
class JobSearchViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var keyword = ""
    @Published var selectedPrefecture: String?
    @Published var selectedCity: String?
    @Published var selectedCategory: String?
    @Published var selectedDateFilter: DateFilter?
    @Published var selectedWageRange: WageRange?
    @Published var selectedDistanceFilter: DistanceFilter?
    @Published var sortBy: SortOption = .newest {
        didSet {
            if sortBy != oldValue {
                jobs = sortJobs(jobs)
            }
        }
    }
    @Published var favoriteJobIds: Set<String> = []
    @Published var categories: [JobCategory] = []
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var locationError: String?
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private let locationManager = LocationManager()

    var hasActiveFilters: Bool {
        selectedPrefecture != nil || selectedCity != nil ||
        selectedCategory != nil || selectedDateFilter != nil ||
        selectedWageRange != nil || selectedDistanceFilter != nil || !keyword.isEmpty
    }

    func requestLocationPermission() {
        locationManager.requestPermission()
    }

    func getCurrentLocation() async {
        do {
            let location = try await locationManager.getCurrentLocation()
            userLocation = location
        } catch {
            locationError = "位置情報の取得に失敗しました"
        }
    }

    func loadJobs() async {
        isLoading = true
        do {
            jobs = try await api.getJobs()
            categories = try await api.getCategories()
        } catch {
            errorMessage = "求人の読み込みに失敗しました"
        }
        isLoading = false
    }

    func loadFavorites() async {
        do {
            let favorites = try await api.getFavoriteJobs()
            favoriteJobIds = Set(favorites.map { $0.id })
        } catch {
            // Non-critical - favorites just won't show
        }
    }

    func search() async {
        isLoading = true
        do {
            var allJobs: [Job]

            // Check if distance search is requested
            if let distanceFilter = selectedDistanceFilter,
               let radius = distanceFilter.radiusKm,
               let location = userLocation {
                // Use distance-based search
                allJobs = try await api.searchJobsByDistance(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    radiusKm: radius,
                    category: selectedCategory
                )
            } else {
                // Standard search
                allJobs = try await api.getJobs(
                    search: keyword.isEmpty ? nil : keyword,
                    prefecture: selectedPrefecture,
                    city: selectedCity,
                    category: selectedCategory
                )
            }

            // Apply wage filter
            if let minWage = selectedWageRange?.minWage {
                allJobs = allJobs.filter { ($0.hourlyWage ?? 0) >= minWage }
            }

            // Apply date filter
            if let dateFilter = selectedDateFilter {
                let today = Calendar.current.startOfDay(for: Date())
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"

                allJobs = allJobs.filter { job in
                    guard let workDateStr = job.workDate,
                          let workDate = formatter.date(from: workDateStr) else {
                        return false
                    }

                    switch dateFilter {
                    case .today:
                        return Calendar.current.isDate(workDate, inSameDayAs: today)
                    case .tomorrow:
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
                        return Calendar.current.isDate(workDate, inSameDayAs: tomorrow)
                    case .thisWeek:
                        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: today)!
                        return workDate >= today && workDate <= weekEnd
                    case .custom(let date):
                        return Calendar.current.isDate(workDate, inSameDayAs: date)
                    }
                }
            }

            // Apply sorting
            jobs = sortJobs(allJobs)
        } catch {
            errorMessage = "検索に失敗しました"
        }
        isLoading = false
    }

    func sortJobs(_ jobs: [Job]) -> [Job] {
        switch sortBy {
        case .newest:
            return jobs.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        case .wageHigh:
            return jobs.sorted { ($0.hourlyWage ?? 0) > ($1.hourlyWage ?? 0) }
        case .wageLow:
            return jobs.sorted { ($0.hourlyWage ?? 0) < ($1.hourlyWage ?? 0) }
        case .dateNearest:
            return jobs.sorted { ($0.workDate ?? "") < ($1.workDate ?? "") }
        }
    }

    func clearFilters() {
        keyword = ""
        selectedPrefecture = nil
        selectedCity = nil
        selectedCategory = nil
        selectedDateFilter = nil
        selectedWageRange = nil
        selectedDistanceFilter = nil
    }

    func toggleFavorite(jobId: String) async {
        do {
            if favoriteJobIds.contains(jobId) {
                _ = try await api.removeFavoriteJob(jobId: jobId)
                favoriteJobIds.remove(jobId)
            } else {
                _ = try await api.addFavoriteJob(jobId: jobId)
                favoriteJobIds.insert(jobId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Filter Sheet View

struct FilterSheetView: View {
    @ObservedObject var viewModel: JobSearchViewModel
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("エリア") {
                    Picker("都道府県", selection: $viewModel.selectedPrefecture) {
                        Text("すべて").tag(nil as String?)
                        ForEach(Prefecture.all) { pref in
                            Text(pref.name).tag(pref.name as String?)
                        }
                    }
                }

                Section("現在地から検索") {
                    Button(action: {
                        Task {
                            await viewModel.getCurrentLocation()
                        }
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("現在地を取得")
                            Spacer()
                            if viewModel.userLocation != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    if viewModel.userLocation != nil {
                        Picker("距離", selection: $viewModel.selectedDistanceFilter) {
                            Text("指定なし").tag(nil as DistanceFilter?)
                            ForEach(DistanceFilter.allCases.filter { $0 != .any }, id: \.self) { filter in
                                Text(filter.display).tag(filter as DistanceFilter?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if let error = viewModel.locationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("時給") {
                    Picker("最低時給", selection: $viewModel.selectedWageRange) {
                        Text("指定なし").tag(nil as WageRange?)
                        ForEach(WageRange.allCases.filter { $0 != .any }, id: \.self) { range in
                            Text(range.display).tag(range as WageRange?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("カテゴリ") {
                    Picker("カテゴリ", selection: $viewModel.selectedCategory) {
                        Text("すべて").tag(nil as String?)
                        ForEach(viewModel.categories) { cat in
                            Text(cat.name).tag(cat.name as String?)
                        }
                    }
                }

                Section("勤務日") {
                    Button(action: { viewModel.selectedDateFilter = .today }) {
                        HStack {
                            Text("今日")
                            Spacer()
                            if case .today = viewModel.selectedDateFilter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    Button(action: { viewModel.selectedDateFilter = .tomorrow }) {
                        HStack {
                            Text("明日")
                            Spacer()
                            if case .tomorrow = viewModel.selectedDateFilter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    Button(action: { viewModel.selectedDateFilter = .thisWeek }) {
                        HStack {
                            Text("今週")
                            Spacer()
                            if case .thisWeek = viewModel.selectedDateFilter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    Button(action: { viewModel.selectedDateFilter = nil }) {
                        HStack {
                            Text("指定なし")
                            Spacer()
                            if viewModel.selectedDateFilter == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") { onApply() }
                }
            }
        }
    }
}

// MARK: - Job Map View

struct JobMapView: View {
    let jobs: [Job]
    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    var body: some View {
        Map(initialPosition: .region(region)) {
            ForEach(jobAnnotations) { item in
                Annotation(item.job.wageDisplay, coordinate: item.coordinate) {
                    NavigationLink(destination: JobDetailView(jobId: item.job.id)) {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
            }
        }
    }

    var jobAnnotations: [JobAnnotation] {
        jobs.compactMap { job in
            if let lat = job.latitude, let lng = job.longitude {
                return JobAnnotation(job: job, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            return nil
        }
    }
}

struct JobAnnotation: Identifiable {
    let id = UUID()
    let job: Job
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Favorite Jobs View

struct FavoriteJobsView: View {
    @StateObject private var viewModel = FavoriteJobsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.errorMessage {
                    VStack {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }

                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.jobs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("お気に入りはありません")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("求人のハートマークをタップして\nお気に入りに追加しましょう")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.jobs) { job in
                                NavigationLink(destination: JobDetailView(jobId: job.id)) {
                                    JobListRow(
                                        job: job,
                                        isFavorite: true,
                                        onFavoriteToggle: {
                                            Task {
                                                await viewModel.removeFavorite(jobId: job.id)
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("お気に入り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadFavorites()
        }
    }
}

@MainActor
class FavoriteJobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadFavorites() async {
        isLoading = true
        do {
            jobs = try await api.getFavoriteJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func removeFavorite(jobId: String) async {
        do {
            _ = try await api.removeFavoriteJob(jobId: jobId)
            jobs.removeAll { $0.id == jobId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Quick Filter Button

struct QuickFilterButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue : Color.gray.opacity(0.1))
            .foregroundColor(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Subviews

struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue : Color.gray.opacity(0.1))
            .foregroundColor(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct JobListRow: View {
    let job: Job
    var isFavorite: Bool = false
    var onFavoriteToggle: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with favorite button
            HStack {
                Text(job.employerName ?? "企業名")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Employer rating
                if let rate = job.employerGoodRate ?? job.goodRate, rate > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10))
                        Text("\(rate)%")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(rate >= 80 ? .green : rate >= 50 ? .orange : .red)
                }

                Spacer()

                if let onFavoriteToggle = onFavoriteToggle {
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .red : .gray)
                    }
                }

                if let date = job.workDate {
                    Text(formatWorkDate(date))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Title
            Text(job.title)
                .font(.headline)
                .lineLimit(2)

            // Details
            HStack(spacing: 16) {
                Label(job.locationDisplay, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)

                if !job.timeDisplay.isEmpty {
                    Label(job.timeDisplay, systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Footer
            HStack {
                Text(job.wageDisplay)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Spacer()

                if let required = job.requiredPeople, let current = job.currentApplicants {
                    let remaining = max(0, required - current)
                    if remaining > 0 {
                        Text("残り\(remaining)名")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    } else {
                        Text("募集終了")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func formatWorkDate(_ dateString: String) -> String {
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
            displayFormatter.dateFormat = "M/d(E)"
            return displayFormatter.string(from: date)
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            locationContinuation?.resume(returning: location.coordinate)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}

// MARK: - Skeleton Loading

struct JobSkeletonRow: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 150, height: 12)
                }
                Spacer()
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

#Preview {
    JobSearchView()
}
