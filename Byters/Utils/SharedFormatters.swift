import Foundation

/// Shared, reusable date formatters to avoid repeated allocation in view bodies.
/// DateFormatter and ISO8601DateFormatter are expensive to create (~5ms each).
enum SharedFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    /// "HH:mm" (Japanese locale)
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// "MM/dd" (Japanese locale)
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "MM/dd"
        return f
    }()

    /// "yyyy-MM-dd"
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "M月d日(E)" (Japanese locale)
    static let japaneseDateWithDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f
    }()

    /// "yyyy年M月d日" (Japanese locale)
    static let japaneseFullDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    /// "M/d HH:mm" (Japanese locale)
    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    /// "yyyy/MM/dd" (Japanese locale)
    static let slashDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    /// "M/d" for compact date display
    static let compactMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        return f
    }()

    // MARK: - Convenience

    /// Parse ISO8601 string and format for display (returns nil on failure)
    static func displayDate(from isoString: String, formatter: DateFormatter = japaneseFullDate) -> String? {
        guard let date = iso8601.date(from: isoString) else { return nil }
        return formatter.string(from: date)
    }

    /// Format for relative time display: "今日 HH:mm" or "MM/dd"
    static func relativeDisplay(from isoString: String) -> String {
        guard let date = iso8601.date(from: isoString) else {
            return isoString.prefix(10).replacingOccurrences(of: "-", with: "/")
        }
        if Calendar.current.isDateInToday(date) {
            return timeOnly.string(from: date)
        } else {
            return monthDay.string(from: date)
        }
    }
}
