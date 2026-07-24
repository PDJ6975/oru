import SwiftUI

// MARK: - Colors

extension Color {
    static let oruPrimary = Color.cyan
    static let oruSecondary = Color.purple
    static let oruBackground = Color.indigo.opacity(0.2) // A establecer más adelante
}

// MARK: - Title

private struct OruTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 25, weight: .medium, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Color.oruPrimary)
    }
}

// MARK: - Body

private struct OruBodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .tracking(0.8)
            .lineSpacing(3)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Label

private struct OruLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Button

private struct OruButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold, design: .rounded))
    }
}

private struct OruExpandButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium, design: .rounded))
    }
}

// MARK: - Input Big

private struct OruInputBigModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 22, weight: .light, design: .rounded))
            .tracking(0.8)
    }
}

// MARK: - Input Medium

private struct OruInputMediumModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .regular, design: .rounded))
    }
}

// MARK: - Input Small

private struct OruInputSmallModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .regular, design: .rounded))
    }
}

// MARK: - Pill Circle

private struct OruPillCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .semibold, design: .rounded))
    }
}

// MARK: - Greeting

private struct OruGreetingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 25, weight: .regular, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Date Subtitle

private struct OruDateSubtitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .light, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Text Primary

private struct OruTextPrimaryModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium, design: .rounded))
    }
}

// MARK: - Text Secondary

private struct OruTextSecondaryModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Tip (consejos con icono)

private struct OruTipModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Hero Value

private struct OruHeroValueModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.oruPrimary)
    }
}

// MARK: - Metric Value

private struct OruMetricValueModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Metric Label

private struct OruMetricLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Section Title

private struct OruSectionTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 19, weight: .regular, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Accent

private struct OruAccentModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .medium, design: .serif))
            .italic()
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Accent Primary (mismo estilo que Accent pero con color cyan)

private struct OruAccentPrimaryModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .medium, design: .serif))
            .italic()
            .tracking(0.8)
            .foregroundStyle(Color.oruPrimary)
    }
}

// MARK: - Navigation Icon Secondary

private struct OruNavigationIconSecondaryModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.secondary)
            .frame(width: 30, height: 30)
    }
}

// MARK: - Consolidation Progress

private struct ConsolidationCardBackground: View {
    let progress: Double

    var body: some View {
        let clampedProgress = min(max(progress, 0), 1)

        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background)
            
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 12, bottomLeading: 12),
                style: .continuous
            )
            .fill(Color.oruPrimary.opacity(0.08))
            .frame(width: geo.size.width * clampedProgress)
        }
    }
}

// MARK: - Pulse Animation

private struct OruPulseModifier: ViewModifier {
    let scale: CGFloat
    let action: () -> Void
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeIn(duration: 0.1)) {
                        isPressed = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        action()
                    }
                }
            }
    }
}

// MARK: - Timer Display

private struct OruTimerDisplayModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 65, weight: .light, design: .rounded))
            .tracking(2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

// MARK: - Icon Button

private struct OruIconButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(.secondary)
    }
}

// MARK: - View Extension

extension View {
    func oruTitle() -> some View {
        modifier(OruTitleModifier())
    }

    func oruBody() -> some View {
        modifier(OruBodyModifier())
    }

    func oruLabel() -> some View {
        modifier(OruLabelModifier())
    }

    func oruButton() -> some View {
        modifier(OruButtonModifier())
    }

    func oruExpandButton() -> some View {
        modifier(OruExpandButtonModifier())
    }

    func oruInputBig() -> some View {
        modifier(OruInputBigModifier())
    }

    func oruInputMedium() -> some View {
        modifier(OruInputMediumModifier())
    }

    func oruInputSmall() -> some View {
        modifier(OruInputSmallModifier())
    }

    func oruPillCircle() -> some View {
        modifier(OruPillCircleModifier())
    }

    func oruGreeting() -> some View {
        modifier(OruGreetingModifier())
    }

    func oruDateSubtitle() -> some View {
        modifier(OruDateSubtitleModifier())
    }

    func oruTextPrimary() -> some View {
        modifier(OruTextPrimaryModifier())
    }

    func oruTextSecondary() -> some View {
        modifier(OruTextSecondaryModifier())
    }

    func oruTip() -> some View {
        modifier(OruTipModifier())
    }

    func oruHeroValue() -> some View {
        modifier(OruHeroValueModifier())
    }

    func oruMetricValue() -> some View {
        modifier(OruMetricValueModifier())
    }

    func oruMetricLabel() -> some View {
        modifier(OruMetricLabelModifier())
    }

    func oruSectionTitle() -> some View {
        modifier(OruSectionTitleModifier())
    }

    func oruAccent() -> some View {
        modifier(OruAccentModifier())
    }

    func oruAccentPrimary() -> some View {
        modifier(OruAccentPrimaryModifier())
    }

    func oruNavigationIconSecondary() -> some View {
        modifier(OruNavigationIconSecondaryModifier())
    }

    func oruPulse(scale: CGFloat = 1.25, action: @escaping () -> Void) -> some View {
        modifier(OruPulseModifier(scale: scale, action: action))
    }

    func oruTimerDisplay() -> some View {
        modifier(OruTimerDisplayModifier())
    }

    func oruIconButton() -> some View {
        modifier(OruIconButtonModifier())
    }

    func oruConsolidationCard(progress: Double) -> some View {
        self
            .listRowBackground(ConsolidationCardBackground(progress: progress))
    }

    /// Resetea el tint heredado del TabView (.oruPrimary) al color por defecto de controles.
    /// Necesario porque SwiftUI no ofrece forma de limitar .tint() solo a la tab bar.
    func oruDefaultTint() -> some View {
        self.tint(Color.secondary)
    }
}
