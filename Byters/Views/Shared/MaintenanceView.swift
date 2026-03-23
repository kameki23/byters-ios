import SwiftUI

struct MaintenanceView: View {
    var estimatedEndTime: String?
    var onRetry: () async -> Void

    @State private var isRetrying = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Maintenance icon
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            rotation = 15
                        }
                    }

                // Title
                Text("メンテナンス中")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                // Message
                Text("現在システムメンテナンスを実施しています。しばらくお待ちください。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Estimated end time
                if let endTime = estimatedEndTime, !endTime.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("復旧予定: \(endTime)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()

                // Retry button
                Button(action: {
                    isRetrying = true
                    Task {
                        await onRetry()
                        isRetrying = false
                    }
                }) {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("再試行")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRetrying)
                .opacity(isRetrying ? 0.7 : 1.0)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview("Maintenance - with end time") {
    MaintenanceView(
        estimatedEndTime: "15:00",
        onRetry: {}
    )
}

#Preview("Maintenance - no end time") {
    MaintenanceView(
        onRetry: {}
    )
}
