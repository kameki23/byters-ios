import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import QuickLook

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if viewModel.isLoading {
                    ChatSkeletonList()
                } else if viewModel.chatRooms.isEmpty {
                    EmptyStateView(
                        icon: "message",
                        title: "メッセージなし",
                        message: "求人に応募するとチャットが開始されます"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.chatRooms) { room in
                                NavigationLink(destination: ChatRoomView(roomId: room.id, room: room)) {
                                    ChatRoomRow(room: room)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Divider()
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("チャット")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadRooms()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatMessageReceived)) { _ in
            Task { await viewModel.refresh() }
        }
    }
}

// MARK: - View Model

@MainActor
class ChatListViewModel: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    var totalUnreadCount: Int {
        chatRooms.compactMap(\.unreadCount).reduce(0, +)
    }

    private let api = APIClient.shared

    func loadRooms() async {
        isLoading = true
        do {
            chatRooms = try await api.getChatRooms()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadRooms()
    }
}

// MARK: - Subviews

struct ChatRoomRow: View {
    let room: ChatRoom

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(room.jobTitle ?? "チャット")
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessageAt = room.lastMessageAt {
                        Text(formatDate(lastMessageAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                HStack {
                    Text(room.lastMessage ?? "メッセージなし")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Spacer()

                    if let unread = room.unreadCount, unread > 0 {
                        Text("\(unread)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ dateString: String) -> String {
        SharedFormatters.relativeDisplay(from: dateString)
    }
}

// MARK: - Chat Room View

struct ChatRoomView: View {
    let roomId: String
    let room: ChatRoom?

    @StateObject private var viewModel = ChatRoomViewModel()
    @State private var messageText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showImagePreviewSheet = false
    @State private var imagePreviewCaption = ""
    @State private var showDocumentPicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String?
    @State private var selectedFileSize: Int64?
    @State private var showCamera = false
    @State private var fullScreenImageURL: String?
    @State private var previewFileURL: URL?
    @State private var showQuickReplies = false

    init(roomId: String, room: ChatRoom? = nil) {
        self.roomId = roomId
        self.room = room
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isMe: message.senderId == viewModel.currentUserId,
                                senderName: message.senderId == viewModel.currentUserId ? nil : (room?.employerName ?? room?.workerName),
                                onImageTap: { imageUrl in
                                    fullScreenImageURL = imageUrl
                                },
                                onFileTap: { fileUrl in
                                    Task {
                                        if let localURL = await viewModel.downloadFile(from: fileUrl) {
                                            previewFileURL = localURL
                                        }
                                    }
                                }
                            )
                            .id(message.id)
                        }

                        // Typing indicator - shown when text field has content
                        if !messageText.isEmpty {
                            HStack {
                                TypingIndicatorView()
                                Spacer()
                            }
                            .id("typing-indicator")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // File attachment indicator (enhanced)
            if let fileName = selectedFileName {
                FileAttachmentIndicator(
                    fileName: fileName,
                    fileSize: selectedFileSize,
                    onRemove: {
                        selectedFileURL = nil
                        selectedFileName = nil
                        selectedFileSize = nil
                    }
                )
            }

            // Quick Reply Templates
            if showQuickReplies {
                QuickReplyBar(onSelect: { template in
                    messageText = template
                    showQuickReplies = false
                })
            }

            // Input bar
            HStack(spacing: 12) {
                // Attachment menu (replaces separate photo/file buttons)
                AttachmentMenuButton(
                    selectedPhoto: $selectedPhoto,
                    showCamera: $showCamera,
                    showDocumentPicker: $showDocumentPicker
                )

                Button(action: { showQuickReplies.toggle() }) {
                    Image(systemName: "text.bubble.fill")
                        .font(.title3)
                        .foregroundColor(showQuickReplies ? .blue : .gray)
                }

                TextField("メッセージを入力", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(canSend ? Color.blue : Color.gray)
                        .clipShape(Circle())
                }
                .disabled(!canSend)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
        }
        .navigationTitle(room?.jobTitle ?? "チャット")
        .navigationBarTitleDisplayMode(.inline)
        // Image preview sheet (shown when user selects a photo)
        .sheet(isPresented: $showImagePreviewSheet) {
            if let image = selectedImage {
                ImagePreviewSheet(
                    image: image,
                    caption: $imagePreviewCaption,
                    onSend: {
                        let captionText = imagePreviewCaption
                        let img = image
                        showImagePreviewSheet = false
                        selectedImage = nil
                        selectedPhoto = nil
                        imagePreviewCaption = ""
                        Task {
                            await viewModel.sendImageMessage(
                                roomId: roomId,
                                image: img,
                                caption: captionText.isEmpty ? nil : captionText
                            )
                        }
                    },
                    onCancel: {
                        showImagePreviewSheet = false
                        selectedImage = nil
                        selectedPhoto = nil
                        imagePreviewCaption = ""
                    }
                )
            }
        }
        // Document picker sheet
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                let accessing = url.startAccessingSecurityScopedResource()
                selectedFileURL = url
                selectedFileName = url.lastPathComponent
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    selectedFileSize = size
                }
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
        }
        // Camera sheet
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                selectedImage = image
                imagePreviewCaption = ""
                showImagePreviewSheet = true
            }
        }
        // Full-screen image viewer
        .fullScreenCover(item: $fullScreenImageURL) { imageUrl in
            FullScreenImageViewer(imageUrl: imageUrl)
        }
        // File preview via QuickLook
        .quickLookPreview($previewFileURL)
        // Load selected photo and show preview sheet
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                do {
                    if let data = try await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        imagePreviewCaption = ""
                        showImagePreviewSheet = true
                    }
                } catch {
                    viewModel.errorMessage = "画像の読み込みに失敗しました"
                }
            }
        }
        .task {
            await viewModel.loadMessages(roomId: roomId)
            viewModel.startPolling(roomId: roomId)
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatMessageReceived)) { _ in
            viewModel.stopPolling()
            Task {
                await viewModel.loadMessages(roomId: roomId)
                viewModel.startPolling(roomId: roomId)
            }
        }
    }

    private var canSend: Bool {
        !messageText.isEmpty || selectedFileURL != nil
    }

    private func sendMessage() {
        let text = messageText
        let fileURL = selectedFileURL
        let fileName = selectedFileName
        messageText = ""
        selectedFileURL = nil
        selectedFileName = nil
        selectedFileSize = nil

        Task {
            if let fileURL = fileURL, let fileName = fileName {
                await viewModel.sendFileMessage(roomId: roomId, fileURL: fileURL, fileName: fileName, caption: text.isEmpty ? nil : text)
            } else if !text.isEmpty {
                await viewModel.sendMessage(roomId: roomId, content: text)
            }
        }
    }
}

// Make String identifiable for fullScreenCover
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Image Preview Sheet (Before Send)

struct ImagePreviewSheet: View {
    let image: UIImage
    @Binding var caption: String
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Large image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                // Caption text field
                HStack(spacing: 12) {
                    TextField("キャプションを追加...", text: $caption)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: onSend) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
            }
            .navigationTitle("画像プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル", action: onCancel)
                }
            }
        }
    }
}

// MARK: - File Attachment Indicator (Enhanced)

struct FileAttachmentIndicator: View {
    let fileName: String
    let fileSize: Int64?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            Image(systemName: fileTypeIcon(for: fileName))
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(fileTypeColor(for: fileName))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let fileSize = fileSize {
                    Text(formatFileSize(fileSize))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.08))
    }

    private func fileTypeIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "ppt", "pptx": return "rectangle.on.rectangle"
        case "txt": return "doc.plaintext"
        case "zip", "rar": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo"
        default: return "doc.fill"
        }
    }

    private func fileTypeColor(for name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return .red
        case "doc", "docx": return .blue
        case "xls", "xlsx": return .green
        case "ppt", "pptx": return .orange
        case "txt": return .gray
        case "zip", "rar": return .purple
        default: return .blue
        }
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Attachment Menu Button

struct AttachmentMenuButton: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var showCamera: Bool
    @Binding var showDocumentPicker: Bool

    var body: some View {
        Menu {
            Button(action: { showCamera = true }) {
                Label("カメラ", systemImage: "camera")
            }

            // PhotosPicker embedded inside menu via a button workaround
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("写真を選択", systemImage: "photo.on.rectangle")
            }

            Button(action: { showDocumentPicker = true }) {
                Label("ファイルを選択", systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Full-Screen Image Viewer (Pinch-to-Zoom + Save)

struct FullScreenImageViewer: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showSaveSuccess = false
    @State private var loadedImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { value in
                                            lastScale = scale
                                            if scale < 1.0 {
                                                withAnimation {
                                                    scale = 1.0
                                                    lastScale = 1.0
                                                    offset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                        }
                                        .simultaneously(with:
                                            DragGesture()
                                                .onChanged { value in
                                                    if scale > 1.0 {
                                                        offset = CGSize(
                                                            width: lastOffset.width + value.translation.width,
                                                            height: lastOffset.height + value.translation.height
                                                        )
                                                    }
                                                }
                                                .onEnded { _ in
                                                    lastOffset = offset
                                                }
                                        )
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation {
                                        if scale > 1.0 {
                                            scale = 1.0
                                            lastScale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        } else {
                                            scale = 2.5
                                            lastScale = 2.5
                                        }
                                    }
                                }
                                .onAppear {
                                    // Cache UIImage for saving
                                    Task {
                                        if let data = try? Data(contentsOf: url) {
                                            loadedImage = UIImage(data: data)
                                        }
                                    }
                                }
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                Text("画像を読み込めませんでした")
                                    .foregroundColor(.white)
                            }
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveImage) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showSaveSuccess {
                    Text("画像を保存しました")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func saveImage() {
        guard let image = loadedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation {
            showSaveSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
}

// MARK: - Chat Room View Model

@MainActor
class ChatRoomViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentUserId: String = ""
    @Published var isSending = false
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private var pollingTask: Task<Void, Never>?

    deinit {
        pollingTask?.cancel()
    }

    func loadMessages(roomId: String) async {
        do {
            if currentUserId.isEmpty {
                let user = try await api.getCurrentUser()
                currentUserId = user.id
            }
            messages = try await api.getChatMessages(roomId: roomId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPolling(roomId: String) {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                guard !Task.isCancelled else { break }
                do {
                    let newMessages = try await APIClient.shared.getChatMessages(roomId: roomId)
                    await MainActor.run {
                        let lastLocalId = self?.messages.last?.id
                        let lastRemoteId = newMessages.last?.id
                        if lastLocalId != lastRemoteId || newMessages.count != self?.messages.count {
                            self?.messages = newMessages
                        }
                    }
                } catch {
                    // Continue polling even on error
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func sendMessage(roomId: String, content: String) async {
        isSending = true
        do {
            let message = try await api.sendMessage(roomId: roomId, content: content)
            messages.append(message)
            AnalyticsService.shared.track(AnalyticsService.eventChatMessageSent, properties: ["room_id": roomId])
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func sendImageMessage(roomId: String, image: UIImage, caption: String?) async {
        isSending = true
        do {
            let base64Image: String? = await Task.detached(priority: .userInitiated) {
                guard let imageData = image.jpegData(compressionQuality: 0.7) else { return nil }
                return imageData.base64EncodedString()
            }.value
            guard let base64Image else {
                isSending = false
                return
            }
            let message = try await api.sendMessageWithImage(
                roomId: roomId,
                content: caption,
                imageBase64: base64Image
            )
            messages.append(message)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func sendFileMessage(roomId: String, fileURL: URL, fileName: String, caption: String?) async {
        isSending = true
        do {
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

            let fileData = try Data(contentsOf: fileURL)
            let base64File = fileData.base64EncodedString()
            let message = try await api.sendMessageWithFile(
                roomId: roomId,
                content: caption,
                fileBase64: base64File,
                fileName: fileName
            )
            messages.append(message)
        } catch {
            errorMessage = "ファイルの送信に失敗しました"
        }
        isSending = false
    }

    /// Download a remote file to a temporary local URL for QuickLook preview
    func downloadFile(from urlString: String) async -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fileName = url.lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory
            let localURL = tempDir.appendingPathComponent(fileName)
            try data.write(to: localURL)
            return localURL
        } catch {
            errorMessage = "ファイルのダウンロードに失敗しました"
            return nil
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .plainText, .spreadsheet, .presentation,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "xls") ?? .data,
            UTType(filenameExtension: "xlsx") ?? .data,
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool
    let senderName: String?
    var onImageTap: ((String) -> Void)? = nil
    var onFileTap: ((String) -> Void)? = nil

    @State private var isDownloading = false

    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
            // Sender name for incoming messages
            if !isMe, let name = senderName {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack {
                if isMe { Spacer() }

                VStack(alignment: .leading, spacing: 4) {
                    // Check if message contains image (enhanced with tap to full-screen)
                    if let imageUrl = message.imageUrl, let url = URL(string: imageUrl) {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 200, height: 150)
                                .overlay(ProgressView())
                        }
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                        .onTapGesture {
                            onImageTap?(imageUrl)
                        }
                    }

                    // Check if message contains file (enhanced with download indicator)
                    if let fileUrl = message.fileUrl, let fileName = message.fileName {
                        Button(action: {
                            isDownloading = true
                            onFileTap?(fileUrl)
                            // Reset after a delay (download completion is handled elsewhere)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isDownloading = false
                            }
                        }) {
                            HStack(spacing: 10) {
                                // File type icon
                                Image(systemName: fileIconName(for: fileName))
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(fileIconColor(for: fileName))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fileName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if let size = message.fileSize {
                                        Text(formatFileSize(Int64(size)))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }

                                Spacer(minLength: 4)

                                if isDownloading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: 240)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Text content
                    if !message.content.isEmpty && message.messageType != "image" {
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isMe ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(isMe ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }

                if !isMe { Spacer() }
            }

            // Timestamp and read receipt
            HStack(spacing: 4) {
                if isMe, message.isRead == true {
                    Text("既読")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                if let createdAt = message.createdAt {
                    Text(formatTime(createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private func formatTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return displayFormatter.string(from: date)
        }
        return ""
    }

    private func fileIconName(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "ppt", "pptx": return "rectangle.on.rectangle"
        case "txt": return "doc.plaintext"
        case "zip", "rar": return "doc.zipper"
        default: return "doc.fill"
        }
    }

    private func fileIconColor(for fileName: String) -> Color {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return .red
        case "doc", "docx": return .blue
        case "xls", "xlsx": return .green
        case "ppt", "pptx": return .orange
        case "txt": return .gray
        case "zip", "rar": return .purple
        default: return .blue
        }
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var dotCount = 0

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotCount == index ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: dotCount)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}

// MARK: - Quick Reply Templates

struct QuickReplyBar: View {
    let onSelect: (String) -> Void

    private let templates: [(icon: String, text: String)] = [
        ("hand.wave", "お疲れ様です。よろしくお願いいたします。"),
        ("checkmark.circle", "承知いたしました。"),
        ("clock", "本日は何時に伺えばよろしいでしょうか？"),
        ("mappin", "勤務地への行き方を教えていただけますか？"),
        ("tshirt", "服装や持ち物について確認させてください。"),
        ("exclamationmark.triangle", "申し訳ございません、少し遅れます。"),
        ("hand.thumbsup", "ありがとうございます！"),
        ("calendar", "次回もぜひよろしくお願いいたします。"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(templates, id: \.text) { template in
                    Button(action: { onSelect(template.text) }) {
                        HStack(spacing: 4) {
                            Image(systemName: template.icon)
                                .font(.caption2)
                            Text(template.text)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ChatListView()
}
