import SwiftUI
import PhotosUI

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
                    ProgressView()
                } else if viewModel.chatRooms.isEmpty {
                    EmptyStateView(
                        icon: "message",
                        title: "メッセージなし",
                        message: "求人に応募するとチャットが開始されます"
                    )
                } else {
                    List(viewModel.chatRooms) { room in
                        NavigationLink(destination: ChatRoomView(roomId: room.id, room: room)) {
                            ChatRoomRow(room: room)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("チャット")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadRooms()
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
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ja_JP")
            if Calendar.current.isDateInToday(date) {
                displayFormatter.dateFormat = "HH:mm"
            } else {
                displayFormatter.dateFormat = "MM/dd"
            }
            return displayFormatter.string(from: date)
        }
        return dateString.prefix(10).replacingOccurrences(of: "-", with: "/")
    }
}

// MARK: - Chat Room View

struct ChatRoomView: View {
    let roomId: String
    let room: ChatRoom?

    @StateObject private var viewModel = ChatRoomViewModel()
    @State private var messageText = ""
    @State private var showImagePicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showImagePreview = false

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
                                senderName: message.senderId == viewModel.currentUserId ? nil : (room?.employerName ?? room?.workerName)
                            )
                            .id(message.id)
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

            // Image preview if selected
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Button(action: {
                        selectedImage = nil
                        selectedPhoto = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
            }

            // Input
            HStack(spacing: 12) {
                // Attachment button
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
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
        .alert("準備中", isPresented: $viewModel.showComingSoon) {
            Button("OK") {}
        } message: {
            Text("通話機能は近日公開予定です。")
        }
        .task {
            await viewModel.loadMessages(roomId: roomId)
            viewModel.startPolling(roomId: roomId)
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private var canSend: Bool {
        !messageText.isEmpty || selectedImage != nil
    }

    private func sendMessage() {
        let text = messageText
        let image = selectedImage
        messageText = ""
        selectedImage = nil
        selectedPhoto = nil

        Task {
            if let image = image {
                await viewModel.sendImageMessage(roomId: roomId, image: image, caption: text.isEmpty ? nil : text)
            } else if !text.isEmpty {
                await viewModel.sendMessage(roomId: roomId, content: text)
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
    @Published var showComingSoon = false
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private var pollingTask: Task<Void, Never>?

    deinit {
        pollingTask?.cancel()
    }

    func loadMessages(roomId: String) async {
        do {
            let user = try await api.getCurrentUser()
            currentUserId = user.id
            messages = try await api.getChatMessages(roomId: roomId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPolling(roomId: String) {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func sendImageMessage(roomId: String, image: UIImage, caption: String?) async {
        isSending = true
        do {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                isSending = false
                return
            }
            let base64Image = imageData.base64EncodedString()
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
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool
    let senderName: String?

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
                    // Check if message contains image
                    if let imageUrl = message.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(ProgressView())
                        }
                    }

                    // Check if message contains file
                    if let _ = message.fileUrl, let fileName = message.fileName {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                            Text(fileName)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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

            // Timestamp
            if let createdAt = message.createdAt {
                Text(formatTime(createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
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
}

#Preview {
    ChatListView()
}
