import Foundation
import UIKit

// MARK: - Analytics & Crash Reporting Service
// Lightweight self-hosted analytics and crash reporting
// Sends events and crash logs to the backend API

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let api = APIClient.shared
    private var sessionId: String
    private var sessionStartTime: Date
    private var eventQueue: [AnalyticsEvent] = []
    private let maxQueueSize = 50
    private let flushInterval: TimeInterval = 60
    private var isEndpointAvailable = true
    private var endpointCheckDate: Date?
    private let diskQueueURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("analytics_queue.json")
    }()
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    private init() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        loadPersistedEvents()
        setupCrashReporting()
        startPeriodicFlush()
    }

    // MARK: - Event Persistence

    private func loadPersistedEvents() {
        guard let data = try? Data(contentsOf: diskQueueURL),
              let events = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) else { return }
        eventQueue.append(contentsOf: events.prefix(maxQueueSize))
        try? FileManager.default.removeItem(at: diskQueueURL)
    }

    private func persistEvents() {
        guard !eventQueue.isEmpty else { return }
        if let data = try? JSONEncoder().encode(eventQueue) {
            try? data.write(to: diskQueueURL, options: .atomic)
        }
    }

    // MARK: - Event Tracking

    func track(_ event: String, properties: [String: String]? = nil) {
        let analyticsEvent = AnalyticsEvent(
            name: event,
            properties: properties ?? [:],
            timestamp: Self.isoFormatter.string(from: Date()),
            sessionId: sessionId
        )

        eventQueue.append(analyticsEvent)

        if eventQueue.count >= maxQueueSize {
            Task { await flush() }
        }
    }

    // MARK: - Screen View Tracking

    func trackScreenView(_ screenName: String) {
        track("screen_view", properties: ["screen": screenName])
    }

    // MARK: - User Action Tracking

    func trackAction(_ action: String, target: String? = nil) {
        var props: [String: String] = ["action": action]
        if let target = target { props["target"] = target }
        track("user_action", properties: props)
    }

    // MARK: - Error Tracking

    func trackError(_ error: Error, context: String? = nil) {
        var props: [String: String] = [
            "error": error.localizedDescription,
            "type": String(describing: type(of: error))
        ]
        if let context = context { props["context"] = context }
        track("error", properties: props)
    }

    // MARK: - Session Management

    func startNewSession() {
        // Flush previous session events
        Task { await flush() }

        sessionId = UUID().uuidString
        sessionStartTime = Date()

        track("session_start", properties: [
            "device": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "locale": Locale.current.identifier
        ])
    }

    func endSession() {
        let duration = Date().timeIntervalSince(sessionStartTime)
        track("session_end", properties: [
            "duration_seconds": String(Int(duration))
        ])
        Task { await flush() }
    }

    // MARK: - Flush Events to Backend

    func flush() async {
        guard !eventQueue.isEmpty else { return }

        // Skip flush if endpoint was confirmed unavailable recently (re-check every 1 hour)
        if !isEndpointAvailable,
           let checkDate = endpointCheckDate,
           Date().timeIntervalSince(checkDate) < 3600 {
            persistEvents()
            return
        }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        guard let url = URL(string: "\(StripeConfig.apiBaseURL)/analytics") else {
            eventQueue.insert(contentsOf: eventsToSend, at: 0)
            persistEvents()
            return
        }

        do {
            let payload = AnalyticsPayload(events: eventsToSend)
            let data = try JSONEncoder().encode(payload)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = KeychainHelper.load(key: "auth_token") {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            request.httpBody = data

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    isEndpointAvailable = true
                    endpointCheckDate = Date()
                    return
                }

                if httpResponse.statusCode == 404 {
                    // Endpoint not implemented - mark unavailable, persist events for later
                    isEndpointAvailable = false
                    endpointCheckDate = Date()
                    eventQueue.insert(contentsOf: eventsToSend, at: 0)
                    persistEvents()
                    #if DEBUG
                    print("[Analytics] Endpoint not available (404), events persisted to disk")
                    #endif
                    return
                }

                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("text/html") {
                    isEndpointAvailable = false
                    endpointCheckDate = Date()
                    eventQueue.insert(contentsOf: eventsToSend, at: 0)
                    persistEvents()
                    return
                }

                // Server error (5xx) - re-queue for retry
                if httpResponse.statusCode >= 500 {
                    if eventQueue.count + eventsToSend.count <= maxQueueSize {
                        eventQueue.insert(contentsOf: eventsToSend, at: 0)
                    }
                }
            }
        } catch {
            // Network error - re-queue and persist
            if eventQueue.count + eventsToSend.count <= maxQueueSize {
                eventQueue.insert(contentsOf: eventsToSend, at: 0)
            }
            persistEvents()
        }
    }

    // MARK: - Crash Reporting

    /// Static device info captured at setup time for use in crash handler
    private static var _appVersion = "unknown"
    private static var _buildNumber = "unknown"
    private static var _osVersion = "unknown"
    private static var _deviceModel = "unknown"

    private func setupCrashReporting() {
        // 起動時にデバイス情報をキャプチャ（クラッシュ時にMainActorにアクセスできないため）
        AnalyticsService._appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        AnalyticsService._buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        AnalyticsService._osVersion = UIDevice.current.systemVersion
        AnalyticsService._deviceModel = UIDevice.current.model

        NSSetUncaughtExceptionHandler { exception in
            let crashReport = CrashReport(
                name: exception.name.rawValue,
                reason: exception.reason ?? "Unknown",
                callStack: exception.callStackSymbols,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                appVersion: AnalyticsService._appVersion,
                buildNumber: AnalyticsService._buildNumber,
                osVersion: AnalyticsService._osVersion,
                deviceModel: AnalyticsService._deviceModel
            )

            if let data = try? JSONEncoder().encode(crashReport) {
                let path = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
                    .appendingPathComponent("pending_crash_report.json")
                try? data.write(to: path)
            }
        }

        // Send any pending crash reports from previous session
        Task { await sendPendingCrashReports() }
    }

    private func sendPendingCrashReports() async {
        let path = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("pending_crash_report.json")

        guard let data = try? Data(contentsOf: path) else { return }

        do {
            guard let url = URL(string: "\(StripeConfig.apiBaseURL)/crash-reports") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = KeychainHelper.load(key: "auth_token") {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            request.httpBody = data

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode < 400 {
                    try? FileManager.default.removeItem(at: path)
                }
                // If endpoint doesn't exist (HTML response or 404), remove file to prevent infinite retries
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("text/html") {
                    try? FileManager.default.removeItem(at: path)
                }
                if httpResponse.statusCode == 404 {
                    try? FileManager.default.removeItem(at: path)
                }
            }
        } catch {
            // Will retry next launch
        }
    }

    // MARK: - Periodic Flush

    private func startPeriodicFlush() {
        Task(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                await flush()
            }
        }
    }
}

// MARK: - Analytics Models

struct AnalyticsEvent: Codable {
    let name: String
    let properties: [String: String]
    let timestamp: String
    let sessionId: String
}

struct AnalyticsPayload: Codable {
    let events: [AnalyticsEvent]
}

struct CrashReport: Codable {
    let name: String
    let reason: String
    let callStack: [String]
    let timestamp: String
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
}

// MARK: - Predefined Event Names

extension AnalyticsService {
    // Job Seeker Events
    static let eventJobViewed = "job_viewed"
    static let eventJobApplied = "job_applied"
    static let eventJobFavorited = "job_favorited"
    static let eventCheckIn = "check_in"
    static let eventCheckOut = "check_out"
    static let eventReviewSubmitted = "review_submitted"
    static let eventWithdrawalRequested = "withdrawal_requested"
    static let eventProfileUpdated = "profile_updated"
    static let eventSearchPerformed = "search_performed"
    static let eventJobAlertSet = "job_alert_set"
    static let eventReferralShared = "referral_shared"

    // Employer Events
    static let eventJobCreated = "job_created"
    static let eventJobTemplateUsed = "job_template_used"
    static let eventApplicationApproved = "application_approved"
    static let eventApplicationRejected = "application_rejected"
    static let eventTimesheetApproved = "timesheet_approved"
    static let eventBulkMessageSent = "bulk_message_sent"
    static let eventDataExported = "data_exported"

    // General Events
    static let eventLoginSuccess = "login_success"
    static let eventLoginFailed = "login_failed"
    static let eventSignup = "signup"
    static let eventLogout = "logout"
    static let eventNotificationTapped = "notification_tapped"
    static let eventChatMessageSent = "chat_message_sent"
}
