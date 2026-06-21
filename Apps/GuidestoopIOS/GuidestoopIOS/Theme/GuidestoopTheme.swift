import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum GuidestoopTheme {
    static let background = dynamicColor(
        light: (0.97, 0.96, 0.94),
        dark: (0.08, 0.08, 0.09)
    )
    static let surface = dynamicColor(
        light: (0.93, 0.92, 0.90),
        dark: (0.12, 0.12, 0.13)
    )
    static let textPrimary = dynamicColor(
        light: (0.12, 0.11, 0.10),
        dark: (0.92, 0.91, 0.88)
    )
    static let textSecondary = dynamicColor(
        light: (0.42, 0.41, 0.39),
        dark: (0.55, 0.54, 0.52)
    )
    /// Monochrome accent — same family as primary text, not a separate hue.
    static let accent = textPrimary
    static let dashedBorder = dynamicColor(
        light: (0.78, 0.77, 0.75),
        dark: (0.30, 0.30, 0.32)
    )
    static let warning = dynamicColor(
        light: (0.35, 0.34, 0.32),
        dark: (0.65, 0.64, 0.62)
    )
    /// Filled button background — primary text color inverted against `buttonLabel`.
    static let buttonFill = textPrimary
    /// Filled button label — contrasts with `buttonFill` in light and dark mode.
    static let buttonLabel = background

    private static func dynamicColor(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #else
        Color(red: dark.0, green: dark.1, blue: dark.2)
        #endif
    }
}

enum GuidestoopTypography {
    static let logo = Font.system(.title, design: .serif).weight(.light)
    static let body = Font.body
    static let meta = Font.caption.monospaced()
    static let mono = Font.system(.footnote, design: .monospaced)
}

struct GuidestoopProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(isEnabled ? GuidestoopTheme.buttonLabel : GuidestoopTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isEnabled ? GuidestoopTheme.buttonFill : GuidestoopTheme.surface)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct GuidestoopBorderedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(isEnabled ? GuidestoopTheme.textPrimary : GuidestoopTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isEnabled ? GuidestoopTheme.dashedBorder : GuidestoopTheme.surface,
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct GuidestoopScreenStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GuidestoopTheme.background)
            .foregroundStyle(GuidestoopTheme.textPrimary)
            .tint(GuidestoopTheme.accent)
    }
}

struct GuidestoopFormStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(GuidestoopTheme.background)
            .foregroundStyle(GuidestoopTheme.textPrimary)
            .tint(GuidestoopTheme.accent)
    }
}

extension View {
    func guidestoopProminentButton() -> some View {
        buttonStyle(GuidestoopProminentButtonStyle())
    }

    func guidestoopBorderedButton() -> some View {
        buttonStyle(GuidestoopBorderedButtonStyle())
    }

    func guidestoopScreenStyle() -> some View {
        modifier(GuidestoopScreenStyle())
    }

    func guidestoopFormStyle() -> some View {
        modifier(GuidestoopFormStyle())
    }

    func guidestoopSyncToolbar(
        isSyncing: Bool,
        outboxCount: Int,
        onSync: @escaping () -> Void
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SyncToolbarButton(
                    isSyncing: isSyncing,
                    outboxCount: outboxCount,
                    onSync: onSync
                )
            }
        }
    }
}
