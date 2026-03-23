import SwiftUI
import PDFKit

struct TaxDocumentListView: View {
    @StateObject private var viewModel = TaxDocumentViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("年度", selection: $viewModel.selectedYear) {
                        ForEach(viewModel.availableYears, id: \.self) { year in
                            Text("\(year)年").tag(year)
                        }
                    }
                }

                Section("源泉徴収票") {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.taxDocuments.isEmpty {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                            Text("書類がありません")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(viewModel.taxDocuments, id: \.id) { doc in
                            EnhancedTaxDocumentRow(document: doc) {
                                viewModel.selectedDocument = doc
                                viewModel.showPreview = true
                            } onDownload: {
                                viewModel.downloadDocument(doc)
                            }
                        }
                    }
                }

                Section("年末調整") {
                    NavigationLink {
                        YearEndAdjustmentInfoView()
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("年末調整について")
                                    .font(.subheadline)
                                Text("年末調整の手続きと必要書類")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("確定申告について", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Text("複数の事業者から収入がある場合、確定申告が必要になる場合があります。詳しくは税務署にお問い合わせください。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("税務書類")
            .refreshable { await viewModel.loadDocuments() }
            .task { await viewModel.loadDocuments() }
            .sheet(isPresented: $viewModel.showPreview) {
                if let doc = viewModel.selectedDocument, let url = URL(string: doc.documentUrl ?? "") {
                    NavigationStack {
                        PDFPreviewView(url: url, title: "\(doc.year)年 源泉徴収票")
                    }
                }
            }
        }
    }
}

struct EnhancedTaxDocumentRow: View {
    let document: TaxDocument
    let onPreview: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(document.year)年 源泉徴収票")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("収入: ¥\(document.totalEarnings.formatted()) / 源泉徴収: ¥\(document.totalWithholding.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("発行日: \(document.issuedAt)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onPreview) {
                    Image(systemName: "eye")
                        .foregroundColor(.blue)
                }
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct YearEndAdjustmentInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TaxInfoSection(icon: "1.circle.fill", title: "年末調整とは",
                    description: "1年間の給与所得に対する所得税の過不足を精算する手続きです。通常、勤務先の企業が12月に行います。")
                TaxInfoSection(icon: "2.circle.fill", title: "複数の勤務先がある場合",
                    description: "Bytersで複数の事業者から収入を得ている場合、主たる勤務先で年末調整を行い、その他の収入については確定申告が必要です。")
                TaxInfoSection(icon: "3.circle.fill", title: "必要書類",
                    description: "源泉徴収票（各事業者発行）、マイナンバー、保険料控除証明書、住宅ローン控除証明書（該当する場合）")
                TaxInfoSection(icon: "4.circle.fill", title: "確定申告が必要なケース",
                    description: "年間の副収入が20万円を超える場合、または2箇所以上から給与を受けている場合は確定申告が必要です。")
            }
            .padding()
        }
        .navigationTitle("年末調整の手続き")
    }
}

struct TaxInfoSection: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class TaxDocumentViewModel: ObservableObject {
    @Published var taxDocuments: [TaxDocument] = []
    @Published var isLoading = false
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedDocument: TaxDocument?
    @Published var showPreview = false

    var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 3)...current).reversed()
    }

    func loadDocuments() async {
        isLoading = true
        do {
            let docs = try await APIClient.shared.getTaxDocuments(year: selectedYear)
            taxDocuments = docs
        } catch {
            #if DEBUG
            print("[TaxDocs] Failed to load: \(error.localizedDescription)")
            #endif
        }
        isLoading = false
    }

    func downloadDocument(_ doc: TaxDocument) {
        guard let urlString = doc.documentUrl else { return }
        BackgroundDownloadManager.shared.download(
            from: urlString,
            fileName: "\(doc.year)_tax_document.pdf"
        )
    }
}
