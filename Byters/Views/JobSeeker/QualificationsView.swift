import SwiftUI
import PhotosUI

// MARK: - Qualifications List View

struct QualificationsView: View {
    @StateObject private var viewModel = QualificationsViewModel()
    @State private var showAddSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("読み込み中...")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Info Card
                        InfoCard(
                            icon: "checkmark.seal.fill",
                            title: "資格・免許を登録",
                            message: "資格や免許を登録すると、対象の求人に応募できるようになります。"
                        )

                        // Qualifications List
                        if viewModel.qualifications.isEmpty {
                            EmptyQualificationsView()
                        } else {
                            ForEach(viewModel.qualifications) { qualification in
                                QualificationCard(qualification: qualification)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("資格・免許")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddQualificationSheet { await viewModel.loadQualifications() }
        }
        .task {
            await viewModel.loadQualifications()
        }
    }
}

struct EmptyQualificationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("登録された資格がありません")
                .font(.headline)
                .foregroundColor(.gray)
            Text("右上の＋ボタンから資格を追加してください")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding(.vertical, 40)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QualificationCard: View {
    let qualification: Qualification

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(qualification.name)
                        .font(.headline)

                    Text(qualification.typeDisplay)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                StatusBadge(status: qualification.status)
            }

            if let expiryDate = qualification.expiryDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    Text("有効期限: \(expiryDate)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if qualification.status == "rejected", let reason = qualification.rejectionReason {
                Text("却下理由: \(reason)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.1))
            .clipShape(Capsule())
    }

    private var statusText: String {
        switch status {
        case "pending": return "審査中"
        case "approved": return "承認済み"
        case "rejected": return "却下"
        default: return status
        }
    }

    private var statusColor: Color {
        switch status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

// MARK: - Add Qualification Sheet

struct AddQualificationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType = "drivers_license"
    @State private var name = ""
    @State private var expiryDate = Date()
    @State private var hasExpiry = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onComplete: () async -> Void

    private let qualificationTypes = [
        ("drivers_license", "普通自動車免許"),
        ("food_hygiene", "食品衛生責任者"),
        ("forklift", "フォークリフト免許"),
        ("nurse", "看護師免許"),
        ("care_worker", "介護福祉士"),
        ("other", "その他")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("資格の種類") {
                    Picker("種類", selection: $selectedType) {
                        ForEach(qualificationTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    if selectedType == "other" {
                        TextField("資格名を入力", text: $name)
                    }
                }

                Section("有効期限") {
                    Toggle("有効期限あり", isOn: $hasExpiry)

                    if hasExpiry {
                        DatePicker("有効期限", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("証明書の画像") {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        if imageData != nil {
                            Label("画像を変更", systemImage: "photo.fill")
                        } else {
                            Label("画像を選択", systemImage: "photo.badge.plus")
                        }
                    }

                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .navigationTitle("資格を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await saveQualification() }
                    }
                    .disabled(isLoading || imageData == nil)
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }

    private func saveQualification() async {
        isLoading = true
        errorMessage = nil

        guard let imageData else {
            errorMessage = "証明書の画像を選択してください"
            isLoading = false
            return
        }

        let qualificationName = selectedType == "other" ? name : qualificationTypes.first { $0.0 == selectedType }?.1 ?? ""

        do {
            _ = try await APIClient.shared.addQualification(
                type: selectedType,
                name: qualificationName,
                expiryDate: hasExpiry ? formatDateForAPI(expiryDate) : nil,
                imageData: imageData
            )
            await onComplete()
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
class QualificationsViewModel: ObservableObject {
    @Published var qualifications: [Qualification] = []
    @Published var isLoading = true

    private let api = APIClient.shared

    func loadQualifications() async {
        isLoading = true
        do {
            qualifications = try await api.getQualifications()
        } catch {
            print("Failed to load qualifications: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Model

struct Qualification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String
    let name: String
    let status: String
    let expiryDate: String?
    let rejectionReason: String?
    let createdAt: String?

    var typeDisplay: String {
        switch type {
        case "drivers_license": return "普通自動車免許"
        case "food_hygiene": return "食品衛生責任者"
        case "forklift": return "フォークリフト免許"
        case "nurse": return "看護師免許"
        case "care_worker": return "介護福祉士"
        default: return type
        }
    }
}
