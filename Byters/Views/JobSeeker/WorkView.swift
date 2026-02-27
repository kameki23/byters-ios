import SwiftUI
import AVFoundation
import CoreLocation

struct WorkView: View {
    @StateObject private var viewModel = WorkViewModel()
    @State private var showQRScanner = false
    @State private var selectedApplication: Application?
    @State private var isCheckingOut = false
    @State private var showErrorAlert = false
    @State private var showSuccessAlert = false
    @State private var showReviewSheet = false
    @State private var showWithholdingTax = false
    @State private var withholdingTaxCalc: WithholdingTaxCalculation?
    @State private var showPhotoCheckIn = false
    @State private var pendingQRResult: QRScanResult?

    // Break time tracking
    @State private var breakStartTime: Date?
    @State private var isOnBreak = false
    @State private var totalBreakMinutes: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // QR Check-in Section
                    VStack(spacing: 16) {
                        Button(action: { showQRScanner = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                Text("QRコードで出勤打刻")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("QRコードをスキャンして出勤打刻")
                        .padding(.horizontal)
                    }

                    // Currently Working Section
                    if let working = viewModel.currentlyWorking {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("勤務中")
                                .font(.headline)
                                .padding(.horizontal)

                            CurrentWorkCard(
                                application: working,
                                elapsedSeconds: viewModel.elapsedSeconds,
                                estimatedEarnings: viewModel.estimatedEarnings,
                                isOnBreak: isOnBreak,
                                totalBreakMinutes: totalBreakMinutes,
                                onCheckOut: {
                                    selectedApplication = working
                                    isCheckingOut = true
                                },
                                onToggleBreak: {
                                    if isOnBreak {
                                        // End break - sync to server
                                        if let start = breakStartTime {
                                            let elapsed = Int(Date().timeIntervalSince(start) / 60)
                                            totalBreakMinutes += max(elapsed, 1)
                                        }
                                        breakStartTime = nil
                                        isOnBreak = false
                                        let appId = working.id
                                        Task {
                                            // Best-effort server sync; break time tracked locally and sent at checkout
                                            _ = try? await APIClient.shared.endBreak(applicationId: appId)
                                        }
                                    } else {
                                        // Start break
                                        breakStartTime = Date()
                                        isOnBreak = true
                                        let appId = working.id
                                        Task {
                                            // Best-effort server sync; break time tracked locally and sent at checkout
                                            _ = try? await APIClient.shared.startBreak(applicationId: appId)
                                        }
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }

                    Divider()
                        .padding(.horizontal)

                    // Upcoming Work Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("予定のお仕事")
                            .font(.headline)
                            .padding(.horizontal)

                        if viewModel.upcomingWork.isEmpty {
                            EmptyStateView(
                                icon: "calendar",
                                title: "予定なし",
                                message: "承認された求人がここに表示されます"
                            )
                        } else {
                            ForEach(viewModel.upcomingWork) { app in
                                UpcomingWorkCard(
                                    application: app,
                                    onCheckIn: {
                                        selectedApplication = app
                                        showQRScanner = true
                                    },
                                    onCancel: {
                                        Task { await viewModel.cancelApplication(applicationId: app.id) }
                                    }
                                )
                            }
                            .padding(.horizontal)
                        }
                    }

                    Divider()
                        .padding(.horizontal)

                    // Work History Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("お仕事履歴")
                            .font(.headline)
                            .padding(.horizontal)

                        if viewModel.workHistory.isEmpty {
                            Text("まだ履歴がありません")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(viewModel.workHistory) { app in
                                WorkCompletedRow(application: app)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("お仕事")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView(
                    onScanComplete: { result in
                        showQRScanner = false
                        pendingQRResult = result
                        showPhotoCheckIn = true
                    },
                    onCancel: {
                        showQRScanner = false
                        selectedApplication = nil
                    }
                )
            }
            .alert("チェックアウト", isPresented: $isCheckingOut) {
                Button("キャンセル", role: .cancel) {
                    selectedApplication = nil
                }
                Button("チェックアウト") {
                    Task {
                        // Calculate final break minutes including any ongoing break
                        var finalBreakMinutes = totalBreakMinutes
                        if isOnBreak, let start = breakStartTime {
                            let elapsed = Int(Date().timeIntervalSince(start) / 60)
                            finalBreakMinutes += max(elapsed, 1)
                        }
                        if let app = selectedApplication {
                            await viewModel.checkOut(applicationId: app.id, breakMinutes: finalBreakMinutes)
                        }
                        selectedApplication = nil
                        // Reset break state on checkout
                        isOnBreak = false
                        breakStartTime = nil
                        totalBreakMinutes = 0
                    }
                }
            } message: {
                if viewModel.currentlyWorking != nil {
                    let hours = viewModel.elapsedSeconds / 3600
                    let minutes = (viewModel.elapsedSeconds % 3600) / 60
                    let breakText = totalBreakMinutes > 0 ? "\n休憩: \(totalBreakMinutes)分" : ""
                    Text("勤務を終了しますか？\n\n経過時間: \(hours)時間\(minutes)分\(breakText)\n見込み報酬: ¥\(viewModel.estimatedEarnings.formatted())")
                } else {
                    Text("勤務を終了しますか？")
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(viewModel.processingMessage)
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("お疲れ様でした！", isPresented: $showSuccessAlert) {
                if let taxCalc = viewModel.lastTaxCalculation, taxCalc.isApplicable {
                    Button("源泉徴収の詳細を見る") {
                        viewModel.successMessage = nil
                        withholdingTaxCalc = taxCalc
                        showWithholdingTax = true
                        viewModel.lastTaxCalculation = nil
                    }
                }
                Button("レビューを書く") {
                    viewModel.successMessage = nil
                    viewModel.lastTaxCalculation = nil
                    showReviewSheet = true
                }
            } message: {
                Text((viewModel.successMessage ?? "") + "\n\n事業者へのレビューをお願いします")
            }
            .sheet(isPresented: $showReviewSheet) {
                NavigationStack {
                    PendingReviewsView()
                }
            }
            .sheet(isPresented: $showWithholdingTax) {
                if let calc = withholdingTaxCalc {
                    WithholdingTaxView(calculation: calc) {
                        showWithholdingTax = false
                    }
                }
            }
            .sheet(isPresented: $showPhotoCheckIn) {
                PhotoCheckInView(
                    onPhotoTaken: { _ in
                        showPhotoCheckIn = false
                        // チェックイン処理を続行
                        if let result = pendingQRResult {
                            Task {
                                await viewModel.handleQRScan(result: result, application: selectedApplication)
                                pendingQRResult = nil
                            }
                        }
                    },
                    onSkip: {
                        showPhotoCheckIn = false
                        if let result = pendingQRResult {
                            Task {
                                await viewModel.handleQRScan(result: result, application: selectedApplication)
                                pendingQRResult = nil
                            }
                        }
                    }
                )
            }
            .alert("位置情報が無効です", isPresented: $viewModel.locationDeniedWarning) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("このまま続ける", role: .cancel) {}
            } message: {
                Text("位置情報の権限が無効です。正確なチェックインのために、設定から位置情報を許可してください。")
            }
        }
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .onChange(of: viewModel.successMessage) { _, newValue in
            showSuccessAlert = newValue != nil
        }
    }
}

// MARK: - View Model

@MainActor
class WorkViewModel: ObservableObject {
    @Published var upcomingWork: [Application] = []
    @Published var workHistory: [Application] = []
    @Published var currentlyWorking: Application?
    @Published var isLoading = true
    @Published var isProcessing = false
    @Published var processingMessage = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var locationDeniedWarning = false
    @Published var elapsedSeconds: Int = 0
    @Published var estimatedEarnings: Int = 0
    @Published var lastTaxCalculation: WithholdingTaxCalculation?

    private let api = APIClient.shared
    private let locationManager = CLLocationManager()
    private var locationDelegate: NSObject?
    private var timer: Timer?

    func loadData() async {
        isLoading = true
        do {
            let apps = try await api.getMyApplications()
            upcomingWork = apps.filter { $0.status == "accepted" }
                .sorted { ($0.workDate ?? "") < ($1.workDate ?? "") }
            workHistory = apps.filter { $0.status == "completed" || $0.status == "paid" }
                .sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
            currentlyWorking = apps.first { $0.status == "checked_in" }

            // Start or stop timer based on working status
            if currentlyWorking != nil {
                startTimer()
            } else {
                stopTimer()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func cancelApplication(applicationId: String) async {
        do {
            _ = try await api.cancelApplication(applicationId: applicationId)
            successMessage = "応募をキャンセルしました"
            await loadData()
        } catch {
            errorMessage = "キャンセルに失敗しました"
        }
    }

    func refresh() async {
        await loadData()
    }

    func handleQRScan(result: QRScanResult, application: Application?) async {
        isProcessing = true
        processingMessage = "チェックイン中..."

        do {
            let components = result.payload.components(separatedBy: "|")
            let token = components.last ?? result.payload
            let location = await getCurrentLocation()

            let response = try await api.checkInWithQR(
                token: token,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                deviceTime: ISO8601DateFormatter().string(from: Date())
            )

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            successMessage = "チェックインしました！\n\(response.jobTitle ?? "")で勤務開始"
            await loadData()
        } catch {
            errorMessage = "チェックインに失敗しました: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func checkOut(applicationId: String, breakMinutes: Int = 0) async {
        isProcessing = true
        processingMessage = "チェックアウト処理中..."

        do {
            let location = await getCurrentLocation()

            let response = try await api.checkOutWithLocation(
                applicationId: applicationId,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                deviceTime: ISO8601DateFormatter().string(from: Date()),
                breakMinutes: breakMinutes > 0 ? breakMinutes : nil
            )

            let hours = String(format: "%.1f", response.workedHours ?? 0)
            let earnings = response.earnings ?? 0

            // 源泉徴収計算
            let taxCalc = WithholdingTaxCalculation.calculate(dailyEarnings: earnings)
            if taxCalc.isApplicable {
                lastTaxCalculation = taxCalc
            }

            // 支払い方式による分岐
            if response.paymentType == "manual" {
                // 実績精算払い: 即時決済をスキップ
                let taxNote = taxCalc.isApplicable ? "\n※源泉徴収が適用される場合があります" : ""
                successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬見込み: ¥\(earnings.formatted())\(taxNote)\n\n事業者が実績を確認後、交通費・残業代を含めた精算が行われます。\n\nレビューを書いてバッジを獲得しよう！"
            } else {
                // 自動支払い: 既存の即時決済フロー
                // チェックアウト後の即時決済を試行
                // 事業者のクレカで求職者へ即時支払い → ウォレットに反映
                if response.paid != true {
                    processingMessage = "決済処理中...\n事業者への課金を実行しています"

                    do {
                        let paymentResponse = try await api.requestInstantPayment(applicationId: applicationId)

                        if paymentResponse.ok {
                            // Stripe 3D Secure対応が必要な場合
                            if paymentResponse.requiresAction == true, let clientSecret = paymentResponse.clientSecret {
                                processingMessage = "追加認証が必要です..."
                                // 3DS認証が必要 - StripeServiceで処理
                                let paymentMethodId = paymentResponse.paymentId ?? ""
                                let confirmed = try await StripeService.shared.confirmPaymentIntent(
                                    clientSecret: clientSecret,
                                    paymentMethodId: paymentMethodId
                                )
                                if confirmed {
                                    let netAmount = paymentResponse.netAmount ?? earnings
                                    let taxNote = taxCalc.isApplicable ? "\n源泉徴収税: -¥\(taxCalc.taxAmount.formatted())\nお受取額: ¥\(taxCalc.netEarnings.formatted())" : ""
                                    successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬: ¥\(netAmount.formatted())\(taxNote)\n\n決済完了！ウォレットに反映されました。\nレビューを書いてバッジを獲得しよう！"
                                } else {
                                    let taxNote = taxCalc.isApplicable ? "\n※源泉徴収が適用される場合があります" : ""
                                    successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬見込み: ¥\(earnings.formatted())\(taxNote)\n\n決済認証に失敗しました。事業者の確認後に報酬が確定します。"
                                }
                            } else {
                                // 即時決済成功
                                let netAmount = paymentResponse.netAmount ?? earnings
                                let walletBalance = paymentResponse.walletBalance
                                let taxNote = taxCalc.isApplicable ? "\n源泉徴収税: -¥\(taxCalc.taxAmount.formatted())\nお受取額: ¥\(taxCalc.netEarnings.formatted())" : ""
                                let walletNote = walletBalance != nil ? "\nウォレット残高: ¥\(walletBalance!.formatted())" : ""
                                successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬: ¥\(netAmount.formatted())\(taxNote)\(walletNote)\n\n即時決済完了！ウォレットに反映されました。\nレビューを書いてバッジを獲得しよう！"
                            }
                        } else {
                            // 即時決済が利用不可 - 通常フロー
                            let taxNote = taxCalc.isApplicable ? "\n※日額9,800円超のため源泉徴収が適用されます" : ""
                            successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬見込み: ¥\(earnings.formatted())\(taxNote)\n\n\(paymentResponse.message ?? "事業者の確認後に報酬が確定します。")\n\nレビューを書いてバッジを獲得しよう！"
                        }
                    } catch {
                        // 即時決済に失敗 - 通常のチェックアウト成功メッセージ
                        #if DEBUG
                        print("[Payment] Instant payment failed: \(error.localizedDescription)")
                        #endif
                        let taxNote = taxCalc.isApplicable ? "\n※日額9,800円超のため源泉徴収が適用されます" : ""
                        successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬見込み: ¥\(earnings.formatted())\(taxNote)\n\n\(response.message ?? "事業者の確認後に報酬が確定します。")\n\nレビューを書いてバッジを獲得しよう！"
                    }
                } else {
                    // 既にバックエンドで決済済み
                    let taxNote = taxCalc.isApplicable ? "\n源泉徴収税: -¥\(taxCalc.taxAmount.formatted())\nお受取額: ¥\(taxCalc.netEarnings.formatted())" : ""
                    successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬: ¥\(earnings.formatted())\(taxNote)\n\n報酬が確定しウォレットに反映されました！\nレビューを書いてバッジを獲得しよう！"
                }
            }

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            await loadData()
        } catch let error as APIError {
            // Stripe/決済関連の詳細エラーハンドリング
            switch error {
            case .serverError(let message):
                if message.contains("payment") || message.contains("stripe") || message.contains("カード") {
                    errorMessage = "決済エラー: \(message)\n\n事業者のカード情報に問題がある可能性があります。管理者にお問い合わせください。"
                } else {
                    errorMessage = "チェックアウトに失敗しました: \(message)"
                }
            case .networkError:
                errorMessage = "ネットワークエラー: インターネット接続を確認してください。チェックアウトが完了していない可能性があります。"
            default:
                errorMessage = "チェックアウトに失敗しました: \(error.errorDescription ?? "不明なエラー")"
            }
        } catch {
            errorMessage = "チェックアウトに失敗しました: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        updateElapsed()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsed()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
        estimatedEarnings = 0
    }

    private func updateElapsed() {
        guard let working = currentlyWorking else { return }

        // Calculate elapsed from checkInTime or fallback to startTime on workDate
        if let checkInStr = working.checkInTime, let checkIn = parseISO8601(checkInStr) {
            elapsedSeconds = max(0, Int(Date().timeIntervalSince(checkIn)))
        } else if let workDate = working.workDate, let startTime = working.startTime {
            let dateStr = "\(workDate)T\(startTime):00"
            if let start = parseDateTime(dateStr) {
                elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
            }
        }

        // Calculate estimated earnings
        if let wage = working.hourlyWage {
            let hoursWorked = Double(elapsedSeconds) / 3600.0
            estimatedEarnings = Int(hoursWorked * Double(wage))
        }
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func parseDateTime(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.date(from: string)
    }

    // MARK: - Location

    private func getCurrentLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus

        if status == .notDetermined {
            let authorized = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                let authDelegate = LocationAuthDelegate { granted in
                    continuation.resume(returning: granted)
                }
                self.locationDelegate = authDelegate
                locationManager.delegate = authDelegate
                locationManager.requestWhenInUseAuthorization()
            }
            if !authorized { return nil }
        }

        if status == .denied || status == .restricted {
            locationDeniedWarning = true
            return nil
        }

        return await withCheckedContinuation { continuation in
            let delegate = LocationDelegate { [weak self] location in
                self?.locationDelegate = nil
                continuation.resume(returning: location)
            }
            self.locationDelegate = delegate
            locationManager.delegate = delegate
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestLocation()
        }
    }
}

// MARK: - Location Auth Delegate

class LocationAuthDelegate: NSObject, CLLocationManagerDelegate {
    private var completion: ((Bool) -> Void)?

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        completion?(status == .authorizedWhenInUse || status == .authorizedAlways)
        completion = nil
    }
}

// MARK: - Location Delegate

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private var completion: ((CLLocation?) -> Void)?

    init(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completion?(locations.first)
        completion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
        completion = nil
    }
}

// MARK: - QR Scanner View

struct QRScannerView: View {
    let onScanComplete: (QRScanResult) -> Void
    let onCancel: () -> Void

    @StateObject private var scanner = QRScannerController()
    @State private var manualToken = ""
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ZStack {
                if scanner.cameraPermissionDenied {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("カメラへのアクセスが必要です")
                            .font(.headline)
                        Text("QRコードをスキャンするにはカメラへのアクセスを許可してください")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("手動で入力") {
                            showManualEntry = true
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                } else {
                    QRCameraPreview(scanner: scanner)
                        .ignoresSafeArea()

                    VStack {
                        Spacer()

                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 250, height: 250)
                            .background(Color.clear)

                        Spacer()

                        VStack(spacing: 16) {
                            Text("QRコードをスキャン")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("勤務先に設置されたQRコードをカメラで読み取ってください")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button(action: { showManualEntry = true }) {
                                Text("手動で入力")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemBackground))
                                    .clipShape(Capsule())
                            }
                            .accessibilityLabel("チェックインコードを手動で入力")
                        }
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationTitle("QRスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .foregroundColor(scanner.cameraPermissionDenied ? .primary : .white)
                }
            }
            .onAppear {
                scanner.startScanning { code in
                    onScanComplete(QRScanResult(payload: code))
                }
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .sheet(isPresented: $showManualEntry) {
                ManualTokenEntryView(
                    token: $manualToken,
                    onSubmit: {
                        if !manualToken.isEmpty {
                            showManualEntry = false
                            onScanComplete(QRScanResult(payload: manualToken))
                        }
                    },
                    onCancel: {
                        showManualEntry = false
                    }
                )
            }
        }
    }
}

// MARK: - Manual Token Entry

struct ManualTokenEntryView: View {
    @Binding var token: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("トークンを手動で入力")
                    .font(.headline)

                TextField("チェックインコード", text: $token)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button(action: onSubmit) {
                    Text("チェックイン")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(token.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(token.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("手動入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - QR Camera Preview

struct QRCameraPreview: UIViewRepresentable {
    let scanner: QRScannerController

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        scanner.previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(scanner.previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        scanner.previewLayer.frame = uiView.bounds
    }
}

// MARK: - QR Scanner Controller

class QRScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession?
    var previewLayer = AVCaptureVideoPreviewLayer()
    private var onCodeScanned: ((String) -> Void)?
    private var hasScanned = false
    @Published var cameraPermissionDenied = false
    @Published var cameraReady = false

    override init() {
        super.init()
    }

    func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.cameraPermissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.cameraPermissionDenied = true
            }
        @unknown default:
            break
        }
    }

    private func setupSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let session = captureSession,
              session.canAddInput(videoInput) else {
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async {
            self.cameraReady = true
        }
    }

    func startScanning(onCodeScanned: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned
        self.hasScanned = false
        requestCameraAccess()
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(stringValue)
    }
}

// MARK: - QR Scan Result

struct QRScanResult {
    let payload: String
}

// MARK: - Currently Working Card (with Timer & Earnings)

struct CurrentWorkCard: View {
    let application: Application
    let elapsedSeconds: Int
    let estimatedEarnings: Int
    var isOnBreak: Bool = false
    var totalBreakMinutes: Int = 0
    let onCheckOut: () -> Void
    var onToggleBreak: (() -> Void)?

    private var hours: Int { elapsedSeconds / 3600 }
    private var minutes: Int { (elapsedSeconds % 3600) / 60 }
    private var seconds: Int { elapsedSeconds % 60 }

    private var timeString: String {
        String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status badge
            HStack {
                Circle()
                    .fill(isOnBreak ? Color.orange : Color.green)
                    .frame(width: 12, height: 12)
                Text(isOnBreak ? "休憩中" : "勤務中")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isOnBreak ? .orange : .green)
                Spacer()
                if let startTime = application.startTime, let endTime = application.endTime {
                    Text("\(startTime) 〜 \(endTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Job info
            VStack(alignment: .leading, spacing: 4) {
                Text(application.jobTitle ?? "求人")
                    .font(.headline)
                Text(application.employerName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Timer display
            VStack(spacing: 8) {
                Text(timeString)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(isOnBreak ? .orange : .green)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("経過時間: \(hours)時間\(minutes)分\(seconds)秒")

                Text("経過時間")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Break time display
                if totalBreakMinutes > 0 || isOnBreak {
                    HStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.caption2)
                        Text("休憩: \(totalBreakMinutes)分")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)

            // Earnings display
            HStack(spacing: 0) {
                // Estimated earnings
                VStack(spacing: 4) {
                    Text("見込み報酬")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("¥\(estimatedEarnings.formatted())")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("見込み報酬: \(estimatedEarnings)円")

                Divider()
                    .frame(height: 40)

                // Hourly wage
                VStack(spacing: 4) {
                    Text("時給")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let wage = application.hourlyWage {
                        Text("¥\(wage.formatted())")
                            .font(.title2)
                            .fontWeight(.bold)
                    } else {
                        Text("-")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Break button
            if let onToggleBreak = onToggleBreak {
                Button(action: onToggleBreak) {
                    HStack {
                        Image(systemName: isOnBreak ? "play.fill" : "pause.fill")
                        Text(isOnBreak ? "休憩終了" : "休憩開始")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isOnBreak ? Color.green : Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel(isOnBreak ? "休憩を終了して勤務に戻る" : "休憩を開始する")
            }

            // Check out button
            Button(action: onCheckOut) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                    Text("チェックアウト")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("勤務を終了してチェックアウト")
        }
        .padding()
        .background(isOnBreak ? Color.orange.opacity(0.05) : Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOnBreak ? Color.orange : Color.green, lineWidth: 2)
        )
    }
}

// MARK: - Upcoming Work Card (with Countdown & Reminders)

struct UpcomingWorkCard: View {
    let application: Application
    let onCheckIn: () -> Void
    let onCancel: () -> Void

    @State private var showCancelAlert = false
    @State private var timeUntilStart: String = ""
    @State private var canCheckIn = false

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with countdown
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.jobTitle ?? "求人")
                        .font(.headline)
                    Text(application.employerName ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                if !timeUntilStart.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timeUntilStart)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(canCheckIn ? .green : .orange)
                        Text(canCheckIn ? "出勤可能" : "開始まで")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(canCheckIn ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Schedule info
            HStack(spacing: 16) {
                if let workDate = application.workDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(formatWorkDate(workDate))
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }

                if let startTime = application.startTime, let endTime = application.endTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(startTime) 〜 \(endTime)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                if let wage = application.hourlyWage {
                    HStack(spacing: 4) {
                        Image(systemName: "yensign.circle")
                            .font(.caption)
                        Text("¥\(wage.formatted())/時")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onCheckIn) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("出勤")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canCheckIn ? Color.blue : Color.blue.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { showCancelAlert = true }) {
                    Text("キャンセル")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .alert("応募をキャンセル", isPresented: $showCancelAlert) {
            Button("キャンセルする", role: .destructive) { onCancel() }
            Button("戻る", role: .cancel) {}
        } message: {
            Text("この応募をキャンセルしますか？\n当日キャンセルはペナルティの対象となる場合があります。")
        }
        .onAppear { updateCountdown() }
        .onReceive(timer) { _ in updateCountdown() }
    }

    private func updateCountdown() {
        guard let workDate = application.workDate,
              let startTime = application.startTime else {
            timeUntilStart = ""
            canCheckIn = true
            return
        }

        let dateStr = "\(workDate)T\(startTime):00"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")

        guard let startDate = formatter.date(from: dateStr) else {
            timeUntilStart = ""
            canCheckIn = true
            return
        }

        let now = Date()
        let diff = startDate.timeIntervalSince(now)

        // Can check in 30 minutes before start
        canCheckIn = diff <= 30 * 60

        if diff <= 0 {
            timeUntilStart = "開始時刻を過ぎています"
            canCheckIn = true
        } else if diff < 3600 {
            let mins = Int(diff / 60)
            timeUntilStart = "あと\(mins)分"
        } else if diff < 86400 {
            let hrs = Int(diff / 3600)
            let mins = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            timeUntilStart = "あと\(hrs)時間\(mins)分"
        } else {
            let days = Int(diff / 86400)
            timeUntilStart = "あと\(days)日"
        }
    }

    private func formatWorkDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "M/d (E)"
        displayFormatter.locale = Locale(identifier: "ja_JP")
        return displayFormatter.string(from: date)
    }
}

// MARK: - Work Completed Row

struct WorkCompletedRow: View {
    let application: Application
    @State private var showTimeModification = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(application.jobTitle ?? "求人")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(application.employerName ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)

                if let workDate = application.workDate {
                    Text(workDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let wage = application.hourlyWage {
                    Text("¥\(wage.formatted())")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                HStack(spacing: 8) {
                    Button(action: { showTimeModification = true }) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.borderless)

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showTimeModification) {
            TimeModificationRequestView(
                applicationId: application.id,
                jobTitle: application.jobTitle,
                originalStartTime: application.startTime,
                originalEndTime: application.endTime
            )
        }
    }
}

#Preview {
    WorkView()
}
