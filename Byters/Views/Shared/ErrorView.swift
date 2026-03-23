import SwiftUI

// MARK: - Reusable Error View

struct ErrorBannerView: View {
    let message: String
    let retryAction: (() async -> Void)?
    @State private var isRetrying = false

    init(_ message: String, retryAction: (() async -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let retryAction {
                Button {
                    isRetrying = true
                    Task {
                        await retryAction()
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("もう一度試す")
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 140)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isRetrying)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Inline Error Message

struct InlineErrorView: View {
    let error: APIError
    let retryAction: (() async -> Void)?

    init(_ error: APIError, retryAction: (() async -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.isRetryable ? "arrow.clockwise.circle" : "exclamationmark.circle")
                .foregroundColor(error.isRetryable ? .orange : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.primary)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if error.isRetryable, let retryAction {
                Button("リトライ") {
                    Task { await retryAction() }
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Toast Error

struct ErrorToastModifier: ViewModifier {
    @Binding var error: String?
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let error {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation { self.error = nil }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: error)
    }
}

extension View {
    func errorToast(_ error: Binding<String?>, duration: TimeInterval = 4) -> some View {
        modifier(ErrorToastModifier(error: error, duration: duration))
    }
}
