import Foundation

/// Lightweight disk cache for API responses.
/// Stores JSON data in the app's Caches directory with a configurable TTL.
final class CacheService {
    static let shared = CacheService()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let defaultTTL: TimeInterval = 60 * 30 // 30 minutes
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        cacheDirectory = cachesDir.appendingPathComponent("APICache", isDirectory: true)
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            print("[CacheService] Failed to create cache directory: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Public API

    /// Save encodable data to disk cache.
    func save<T: Encodable>(_ data: T, forKey key: String) {
        let fileURL = fileURL(for: key)
        let enc = self.encoder
        let cacheDir = self.cacheDirectory
        let fm = self.fileManager
        Task.detached(priority: .utility) {
            do {
                let wrapper = CacheEntry(timestamp: Date(), data: try enc.encode(data))
                let encoded = try enc.encode(wrapper)
                if !fm.fileExists(atPath: cacheDir.path) {
                    try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                }
                try encoded.write(to: fileURL, options: .atomic)
            } catch {
                #if DEBUG
                print("[Cache] Failed to save \(key): \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Load cached data if it exists and hasn't expired.
    func load<T: Decodable>(_ type: T.Type, forKey key: String, ttl: TimeInterval? = nil) -> T? {
        let fileURL = fileURL(for: key)
        guard let rawData = try? Data(contentsOf: fileURL),
              let entry = try? decoder.decode(CacheEntry.self, from: rawData) else {
            return nil
        }

        // Check TTL
        let maxAge = ttl ?? defaultTTL
        guard Date().timeIntervalSince(entry.timestamp) < maxAge else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        return try? decoder.decode(type, from: entry.data)
    }

    /// Remove a specific cache entry.
    func remove(forKey key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    /// Clear all cached data.
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func fileURL(for key: String) -> URL {
        let safeKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent(safeKey + ".json")
    }
}

private struct CacheEntry: Codable {
    let timestamp: Date
    let data: Data
}
