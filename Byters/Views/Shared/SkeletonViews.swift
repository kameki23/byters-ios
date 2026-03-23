import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.4),
                            Color.white.opacity(0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Reusable skeleton placeholder block
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Reusable Skeleton Loading Views

/// A generic skeleton loading row with shimmer animation.
struct SkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: 120, height: 12)
                    SkeletonBlock(width: 200, height: 16)
                    SkeletonBlock(width: 150, height: 12)
                }
                Spacer()
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .shimmer()
            }
            HStack(spacing: 8) {
                SkeletonBlock(width: 80, height: 12)
                SkeletonBlock(width: 60, height: 12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

/// A chat-style skeleton row for chat list loading states.
struct ChatSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SkeletonBlock(width: 140, height: 14)
                    Spacer()
                    SkeletonBlock(width: 40, height: 10)
                }
                SkeletonBlock(width: 200, height: 12)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
}

/// A VStack of multiple `SkeletonRow`s for list loading states.
struct SkeletonList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .padding()
    }
}

/// A VStack of multiple `ChatSkeletonRow`s for chat list loading states.
struct ChatSkeletonList: View {
    var count: Int = 6

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                ChatSkeletonRow()
            }
        }
    }
}

// MARK: - Home Skeleton View

/// Full-screen skeleton for HomeView loading state (Timee-style).
struct HomeSkeletonView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Banner skeleton
            SkeletonBlock(height: 160, cornerRadius: 16)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Stats cards skeleton
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonBlock(width: 40, height: 40, cornerRadius: 8)
                        SkeletonBlock(width: 50, height: 12)
                        SkeletonBlock(width: 30, height: 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Category shortcuts skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 48, height: 48)
                                .shimmer()
                            SkeletonBlock(width: 40, height: 10)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 20)

            // Job section skeleton
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SkeletonBlock(width: 140, height: 18)
                    Spacer()
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { _ in
                            HomeJobCardSkeleton()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 20)

            Spacer()
        }
    }
}

/// Skeleton for a single home job card.
struct HomeJobCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.systemGray5))
                .frame(width: 220, height: 110)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 60, height: 10)
                SkeletonBlock(width: 180, height: 14)
                SkeletonBlock(width: 100, height: 12)
                SkeletonBlock(width: 70, height: 12)
            }
            .padding(12)
        }
        .frame(width: 220)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Job Detail Skeleton View

/// Full-screen skeleton for JobDetailView loading state.
struct JobDetailSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Image placeholder
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.systemGray5))
                .frame(height: 220)
                .shimmer()

            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(width: 100, height: 14)
                SkeletonBlock(height: 22)
                HStack(spacing: 8) {
                    SkeletonBlock(width: 60, height: 24, cornerRadius: 12)
                    SkeletonBlock(width: 80, height: 24, cornerRadius: 12)
                    SkeletonBlock(width: 70, height: 24, cornerRadius: 12)
                }
            }
            .padding(.horizontal)

            // Info cards skeleton
            HStack(spacing: 12) {
                InfoCardSkeleton()
                InfoCardSkeleton()
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                InfoCardSkeleton()
                InfoCardSkeleton()
            }
            .padding(.horizontal)

            // Location skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(width: 60, height: 18)
                SkeletonBlock(height: 14)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(height: 180)
                    .shimmer()
            }
            .padding(.horizontal)

            // Description skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(width: 80, height: 18)
                SkeletonBlock(height: 12)
                SkeletonBlock(height: 12)
                SkeletonBlock(width: 200, height: 12)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }
}

struct InfoCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 28, height: 28)
                .shimmer()
            SkeletonBlock(width: 80, height: 16)
            SkeletonBlock(width: 40, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Work Skeleton View

/// Full-screen skeleton for WorkView loading state.
struct WorkSkeletonView: View {
    var body: some View {
        VStack(spacing: 24) {
            // QR button skeleton
            SkeletonBlock(height: 52, cornerRadius: 12)
                .padding(.horizontal)

            Divider().padding(.horizontal)

            // Upcoming work section skeleton
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 120, height: 18)
                    .padding(.horizontal)

                ForEach(0..<2, id: \.self) { _ in
                    WorkCardSkeleton()
                        .padding(.horizontal)
                }
            }

            Divider().padding(.horizontal)

            // History section skeleton
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 100, height: 18)
                    .padding(.horizontal)

                ForEach(0..<3, id: \.self) { _ in
                    WorkHistorySkeleton()
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .padding(.vertical)
    }
}

struct WorkCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: 80, height: 12)
                    SkeletonBlock(width: 180, height: 16)
                }
                Spacer()
                SkeletonBlock(width: 60, height: 24, cornerRadius: 12)
            }
            HStack(spacing: 16) {
                SkeletonBlock(width: 100, height: 12)
                SkeletonBlock(width: 80, height: 12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

struct WorkHistorySkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .shimmer()
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 160, height: 14)
                SkeletonBlock(width: 100, height: 11)
            }
            Spacer()
            SkeletonBlock(width: 70, height: 14)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Enhanced Error State View

/// Timee-style error state with illustration and retry.
struct EnhancedErrorView: View {
    let icon: String
    let title: String
    let message: String
    var retryAction: (() async -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(.red.opacity(0.7))
            }

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let retryAction = retryAction {
                Button(action: {
                    Task { await retryAction() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("再試行")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Enhanced Empty State View

/// Timee-style empty state with illustration and optional action.
struct EnhancedEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(.blue.opacity(0.5))
            }

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Text(actionLabel)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
