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
                                onCheckOut: {
                                    selectedApplication = working
                                    isCheckingOut = true
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
                                WorkCard(
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
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView(
                    onScanComplete: { result in
                        showQRScanner = false
                        Task {
                            await viewModel.handleQRScan(result: result, application: selectedApplication)
                        }
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
                        if let app = selectedApplication {
                            await viewModel.checkOut(applicationId: app.id)
                        }
                        selectedApplication = nil
                    }
                }
            } message: {
                Text("勤務を終了しますか？")
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
            .alert("成功", isPresented: $showSuccessAlert) {
                Button("OK") {
                    viewModel.successMessage = nil
                }
                Button("レビューを書く") {
                    viewModel.successMessage = nil
                    showReviewSheet = true
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .sheet(isPresented: $showReviewSheet) {
                NavigationStack {
                    PendingReviewsView()
                }
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

    private let api = APIClient.shared
    private let locationManager = CLLocationManager()
    private var locationDelegate: NSObject?

    func loadData() async {
        isLoading = true
        do {
            let apps = try await api.getMyApplications()
            upcomingWork = apps.filter { $0.status == "accepted" }
            workHistory = apps.filter { $0.status == "completed" }
            currentlyWorking = apps.first { $0.status == "checked_in" }
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
            // Parse QR code: format is "job_id|token" or just token
            let components = result.payload.components(separatedBy: "|")
            let token = components.last ?? result.payload

            // Get current location
            let location = await getCurrentLocation()

            // Call check-in API
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

    func checkOut(applicationId: String) async {
        isProcessing = true
        processingMessage = "チェックアウト・決済処理中..."

        do {
            let location = await getCurrentLocation()

            let response = try await api.checkOutWithLocation(
                applicationId: applicationId,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                deviceTime: ISO8601DateFormatter().string(from: Date())
            )

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            let hours = String(format: "%.1f", response.workedHours ?? 0)
            let earnings = response.earnings ?? 0

            if response.paid == true {
                successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬: ¥\(earnings.formatted())\n\n報酬が自動で確定しました！\nレビューを書いてバッジを獲得しよう！"
            } else {
                successMessage = "お疲れ様でした！\n\n勤務時間: \(hours)時間\n報酬見込み: ¥\(earnings.formatted())\n\n\(response.message ?? "事業者の確認後に報酬が確定します。")\n\nレビューを書いてバッジを獲得しよう！"
            }
            await loadData()
        } catch {
            errorMessage = "チェックアウトに失敗しました: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    private func getCurrentLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus

        // 権限が未決定の場合、リクエストして待つ
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

        // 権限が拒否されている場合
        if status == .denied || status == .restricted {
            return nil
        }

        // 位置情報を取得
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
                    // Camera permission denied
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
                    // Camera preview
                    QRCameraPreview(scanner: scanner)
                        .ignoresSafeArea()

                    // Overlay
                    VStack {
                        Spacer()

                        // Scan frame
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 250, height: 250)
                            .background(Color.clear)

                        Spacer()

                        // Instructions
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

// MARK: - Subviews

struct CurrentWorkCard: View {
    let application: Application
    let onCheckOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                Text("勤務中")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(application.jobTitle ?? "求人")
                    .font(.headline)

                Text(application.employerName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

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
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green, lineWidth: 2)
        )
    }
}

struct WorkCard: View {
    let application: Application
    let onCheckIn: () -> Void
    let onCancel: () -> Void

    @State private var showCancelAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.jobTitle ?? "求人")
                        .font(.headline)

                    Text(application.employerName ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    if let workDate = application.workDate {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(workDate)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Button(action: onCheckIn) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("出勤")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }

                    Button(action: { showCancelAlert = true }) {
                        Text("キャンセル")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
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
            Text("この応募をキャンセルしますか？この操作は取り消せません。")
        }
    }
}

struct WorkCompletedRow: View {
    let application: Application

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
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    WorkView()
}
