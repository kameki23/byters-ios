import SwiftUI

// MARK: - Accessibility Modifiers

extension View {
    /// Add standard accessibility for interactive buttons
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for images
    func accessibleImage(label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }

    /// Add accessibility for headings
    func accessibleHeading(_ label: String? = nil) -> some View {
        self
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(label ?? "")
    }

    /// Mark as decorative (ignored by VoiceOver)
    func accessibilityDecorative() -> some View {
        self.accessibilityHidden(true)
    }

    /// Add accessibility for tab bar items
    func accessibleTab(label: String, badge: Int = 0) -> some View {
        let badgeText = badge > 0 ? "、\(badge)件の未読" : ""
        return self.accessibilityLabel("\(label)\(badgeText)")
    }

    /// Add accessibility for monetary values
    func accessibleCurrency(_ amount: Int) -> some View {
        self.accessibilityLabel("\(amount)円")
    }

    /// Add accessibility for star ratings
    func accessibleRating(_ rating: Double, outOf total: Int = 5) -> some View {
        self.accessibilityLabel("評価 \(String(format: "%.1f", rating))、\(total)段階中")
    }

    /// Add accessibility for job cards
    func accessibleJobCard(title: String, wage: String, location: String, date: String) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)、\(wage)、\(location)、\(date)")
    }

    /// Add accessibility for status badges
    func accessibleStatus(_ status: String) -> some View {
        self.accessibilityLabel("ステータス: \(status)")
    }
}

// MARK: - Dynamic Type Support

struct ScaledFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}
