import Foundation

struct ValidationHelper {

    // MARK: - Email

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    static func emailError(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil } // Don't show error for empty field
        if !isValidEmail(trimmed) {
            return "有効なメールアドレスを入力してください"
        }
        return nil
    }

    // MARK: - Password

    static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let hasLetter = password.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        return hasLetter && hasNumber
    }

    static func passwordError(_ password: String) -> String? {
        if password.isEmpty { return nil }
        if password.count < 8 {
            return "パスワードは8文字以上で入力してください"
        }
        let hasLetter = password.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        if !hasLetter || !hasNumber {
            return "パスワードには英字と数字の両方を含めてください"
        }
        return nil
    }

    // MARK: - Phone (Japanese)

    static func isValidPhone(_ phone: String) -> Bool {
        let digits = phone.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !digits.isEmpty else { return false }
        // Japanese phone: 070/080/090 (11 digits) or 0X-XXXX-XXXX (10 digits) or +81
        let pattern = #"^(\+81|0)\d{9,10}$"#
        return digits.range(of: pattern, options: .regularExpression) != nil
    }

    static func phoneError(_ phone: String) -> String? {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if !isValidPhone(trimmed) {
            return "有効な電話番号を入力してください（例: 09012345678）"
        }
        return nil
    }

    // MARK: - Name

    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 50
    }

    static func nameError(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.count > 50 {
            return "名前は50文字以内で入力してください"
        }
        return nil
    }

    // MARK: - Text Length

    static func textLengthError(_ text: String, maxLength: Int, fieldName: String) -> String? {
        if text.count > maxLength {
            return "\(fieldName)は\(maxLength)文字以内で入力してください"
        }
        return nil
    }

    // MARK: - Time Format (HH:MM)

    static func isValidTimeFormat(_ time: String) -> Bool {
        let pattern = #"^([01]\d|2[0-3]):[0-5]\d$"#
        return time.range(of: pattern, options: .regularExpression) != nil
    }

    static func timeFormatError(_ time: String) -> String? {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if !isValidTimeFormat(trimmed) {
            return "時刻はHH:MM形式で入力してください（例: 09:00）"
        }
        return nil
    }

    // MARK: - Wage

    static func isValidWage(_ wage: String) -> Bool {
        guard let value = Int(wage) else { return false }
        return value >= 1 && value <= 100000
    }

    static func wageError(_ wage: String) -> String? {
        if wage.isEmpty { return nil }
        guard let value = Int(wage) else {
            return "数値を入力してください"
        }
        if value < 1 {
            return "時給は1円以上で入力してください"
        }
        if value > 100000 {
            return "時給は100,000円以内で入力してください"
        }
        return nil
    }
}

// MARK: - Character Extension

private extension Character {
    var isKatakana: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x30A0...0x30FF).contains(scalar.value)
    }
}
