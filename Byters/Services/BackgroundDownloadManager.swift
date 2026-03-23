import Foundation
import UIKit

@MainActor
final class BackgroundDownloadManager: NSObject, ObservableObject {
    static let shared = BackgroundDownloadManager()

    @Published var activeDownloads: [String: DownloadTask] = [:]
    @Published var completedDownloads: [CompletedDownload] = []

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "jp.byters.app.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    struct DownloadTask: Identifiable {
        let id: String
        let fileName: String
        let url: URL
        var progress: Double
        var status: DownloadStatus
    }

    struct CompletedDownload: Identifiable {
        let id: String
        let fileName: String
        let localURL: URL
        let completedAt: Date
    }

    enum DownloadStatus {
        case downloading, paused, completed, failed(String)
    }

    func download(from urlString: String, fileName: String) {
        guard let url = URL(string: urlString) else { return }

        let id = UUID().uuidString
        var request = URLRequest(url: url)
        if let token = KeychainHelper.load(key: "auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = session.downloadTask(with: request)
        task.taskDescription = id

        activeDownloads[id] = DownloadTask(
            id: id, fileName: fileName, url: url,
            progress: 0, status: .downloading
        )

        task.resume()
    }

    func cancelDownload(id: String) {
        activeDownloads.removeValue(forKey: id)
    }

    private func documentsDirectory() -> URL {
        (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Downloads", isDirectory: true)
    }
}

extension BackgroundDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskId = downloadTask.taskDescription else { return }

        let docsDir = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)

        let fileName = downloadTask.response?.suggestedFilename ?? "\(taskId).pdf"
        let destURL = docsDir.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: destURL)
        try? FileManager.default.moveItem(at: location, to: destURL)

        Task { @MainActor in
            activeDownloads.removeValue(forKey: taskId)
            completedDownloads.append(CompletedDownload(
                id: taskId, fileName: fileName, localURL: destURL, completedAt: Date()
            ))
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let taskId = downloadTask.taskDescription else { return }
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0

        Task { @MainActor in
            activeDownloads[taskId]?.progress = progress
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskId = task.taskDescription, let error else { return }
        Task { @MainActor in
            activeDownloads[taskId]?.status = .failed(error.localizedDescription)
        }
    }
}
