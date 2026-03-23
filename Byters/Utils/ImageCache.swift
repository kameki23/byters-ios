import SwiftUI
import UIKit

// MARK: - Image Cache (Memory + Disk)

final class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private let maxDiskCacheSize: Int = 100 * 1024 * 1024 // 100 MB
    private let maxDiskCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private init() {
        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 80 * 1024 * 1024 // 80 MB

        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        diskCacheURL = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)

        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Clean expired cache on init (background)
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.cleanExpiredDiskCache()
        }
    }

    // MARK: - Memory Cache

    /// Fast memory-only lookup (no disk I/O, safe for main thread)
    func memoryImage(for key: String) -> UIImage? {
        return memoryCache.object(forKey: key as NSString)
    }

    func image(for key: String) -> UIImage? {
        if let memoryImage = memoryCache.object(forKey: key as NSString) {
            return memoryImage
        }

        // Try disk cache
        if let diskImage = loadFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        return nil
    }

    func setImage(_ image: UIImage, for key: String) {
        memoryCache.setObject(image, forKey: key as NSString)

        // Save to disk cache asynchronously
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.saveToDisk(image: image, key: key)
        }
    }

    // MARK: - Disk Cache

    private func diskCachePath(for key: String) -> URL {
        let filename = (key.data(using: .utf8) ?? Data()).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(64)
        return diskCacheURL.appendingPathComponent(String(filename) + ".jpg")
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskCachePath(for: key)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        let path = diskCachePath(for: key)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: path, options: .atomic)
    }

    private func cleanExpiredDiskCache() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoffDate = Date().addingTimeInterval(-maxDiskCacheAge)
        var totalSize: Int = 0

        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { continue }

            if let modDate = attrs.contentModificationDate, modDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            } else {
                totalSize += attrs.fileSize ?? 0
            }
        }

        // If still over limit, remove oldest files
        if totalSize > maxDiskCacheSize {
            let sortedFiles = files
                .compactMap { url -> (URL, Date)? in
                    guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else { return nil }
                    return (url, attrs.contentModificationDate ?? Date.distantPast)
                }
                .sorted { $0.1 < $1.1 }

            for (fileURL, _) in sortedFiles {
                try? fileManager.removeItem(at: fileURL)
                totalSize -= 1024 * 100 // approximate
                if totalSize <= maxDiskCacheSize / 2 { break }
            }
        }
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    init(url: URL, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        let key = url.absoluteString

        // Check memory cache first (fast, no disk I/O)
        if let memCached = ImageCache.shared.memoryImage(for: key) {
            self.uiImage = memCached
            self.isLoading = false
            return
        }

        // Move disk I/O and network off the main thread
        let result: UIImage? = await Task.detached(priority: .userInitiated) {
            // Check disk cache
            if let cached = ImageCache.shared.image(for: key) {
                return cached
            }

            // Download the image
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let downloaded = UIImage(data: data) else {
                    return nil
                }

                ImageCache.shared.setImage(downloaded, for: key)
                return downloaded
            } catch {
                return nil
            }
        }.value

        self.uiImage = result
        isLoading = false
    }
}
