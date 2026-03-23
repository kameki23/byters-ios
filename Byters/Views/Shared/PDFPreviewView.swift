import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let title: String

    @State private var pdfDocument: PDFDocument?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 0
    @State private var downloadProgress: Double = 0
    @State private var showShareSheet: Bool = false

    private let url: URL?
    private let data: Data?

    // MARK: - Initializers

    init(url: URL, title: String) {
        self.url = url
        self.data = nil
        self.title = title
    }

    init(data: Data, title: String) {
        self.url = nil
        self.data = data
        self.title = title
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    if url != nil && downloadProgress > 0 && downloadProgress < 1.0 {
                        ProgressView(value: downloadProgress)
                            .frame(width: 200)
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("読み込み中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        loadPDF()
                    } label: {
                        Label("再試行", systemImage: "arrow.clockwise")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let pdfDocument {
                VStack(spacing: 0) {
                    PDFKitView(
                        document: pdfDocument,
                        currentPage: $currentPage
                    )

                    if totalPages > 1 {
                        HStack {
                            Spacer()
                            Text("\(currentPage) / \(totalPages) ページ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                        .background(Color(.systemBackground))
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if pdfDocument != nil {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfDocument {
                ShareSheet(items: [pdfDocument.dataRepresentation() as Any])
            }
        }
        .onAppear {
            loadPDF()
        }
    }

    // MARK: - Private Methods

    private func loadPDF() {
        isLoading = true
        errorMessage = nil

        if let data {
            if let document = PDFDocument(data: data) {
                pdfDocument = document
                totalPages = document.pageCount
            } else {
                errorMessage = "PDFの読み込みに失敗しました"
            }
            isLoading = false
        } else if let url {
            if url.isFileURL {
                if let document = PDFDocument(url: url) {
                    pdfDocument = document
                    totalPages = document.pageCount
                } else {
                    errorMessage = "PDFファイルを開けませんでした"
                }
                isLoading = false
            } else {
                downloadRemotePDF(from: url)
            }
        } else {
            errorMessage = "PDFソースが指定されていません"
            isLoading = false
        }
    }

    private func downloadRemotePDF(from url: URL) {
        Task {
            do {
                let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)

                let expectedLength = response.expectedContentLength
                var data = Data()
                if expectedLength > 0 {
                    data.reserveCapacity(Int(expectedLength))
                }

                var downloaded: Int64 = 0
                for try await byte in asyncBytes {
                    data.append(byte)
                    downloaded += 1
                    if expectedLength > 0 {
                        let progress = Double(downloaded) / Double(expectedLength)
                        await MainActor.run {
                            downloadProgress = progress
                        }
                    }
                }

                await MainActor.run {
                    if let document = PDFDocument(data: data) {
                        pdfDocument = document
                        totalPages = document.pageCount
                    } else {
                        errorMessage = "PDFの解析に失敗しました"
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "ダウンロードに失敗しました: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - PDFKitView

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(currentPage: $currentPage)
    }

    class Coordinator: NSObject {
        @Binding var currentPage: Int

        init(currentPage: Binding<Int>) {
            _currentPage = currentPage
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPDFPage = pdfView.currentPage,
                  let document = pdfView.document,
                  let pageIndex = document.index(for: currentPDFPage) as Int? else { return }
            Task { @MainActor in
                self.currentPage = pageIndex + 1
            }
        }
    }
}

// ShareSheet is defined in AdditionalFeatureViews.swift
