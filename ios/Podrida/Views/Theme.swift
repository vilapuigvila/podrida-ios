import SwiftUI

/// The ledger-paper palette from the web version. The app keeps this one look in light and dark mode.
enum Palette {
    static let paper = Color(hex: 0xEAF0E3)
    static let line = Color(hex: 0xC7D3BE)
    static let rule = Color(hex: 0xA63D33)
    static let ink = Color(hex: 0x202B21)
    static let inkSoft = Color(hex: 0x5B6B57)
    static let brass = Color(hex: 0xA9812E)
}

/// Built-in faces standing in for the web version's Google Fonts, so the app looks the same offline.
enum Typeface {
    /// Typewriter display face (the web version uses Special Elite).
    static func typewriter(_ size: CGFloat) -> Font {
        .custom("AmericanTypewriter", fixedSize: size)
    }

    /// Monospaced text face (the web version uses IBM Plex Mono).
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// Small uppercase label, as used above fields and in the table's corner cells.
    func fieldCaption(size: CGFloat = 11, tracking: CGFloat = 1.1, color: Color = Palette.inkSoft) -> some View {
        font(Typeface.mono(size)).textCase(.uppercase).tracking(tracking).foregroundStyle(color)
    }
}

/// Text button with a dashed outline, for the ledger's secondary actions.
struct DashedButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        DashedButton(configuration: configuration, tint: tint)
    }

    private struct DashedButton: View {
        let configuration: Configuration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Typeface.mono(12))
                .foregroundStyle(tint)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(tint.opacity(configuration.isPressed ? 0.1 : 0), in: .rect(cornerRadius: 3))
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(tint, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

/// Outlined button, for the ledger's New Game action.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.mono(11))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.ink.opacity(configuration.isPressed ? 0.1 : 0), in: .rect(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 1.5))
    }
}

/// Solid red call-to-action.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.typewriter(16))
            .foregroundStyle(Palette.paper)
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(Palette.rule, in: .rect(cornerRadius: 3))
            .brightness(configuration.isPressed ? -0.06 : 0)
    }
}

/// The boxed − value + control from the setup screen. VoiceOver reads it as a standard stepper.
struct BoxedStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 0) {
            step(-1, symbol: "−", label: "Fewer \(title.lowercased())")
            Text(value, format: .number)
                .font(Typeface.mono(18, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 56, minHeight: 44)
                .padding(.horizontal, 6)
                .overlay(alignment: .leading) { Rectangle().frame(width: 1.5) }
                .overlay(alignment: .trailing) { Rectangle().frame(width: 1.5) }
            step(1, symbol: "+", label: "More \(title.lowercased())")
        }
        .foregroundStyle(Palette.ink)
        .clipShape(.rect(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 1.5))
        .buttonRepeatBehavior(.enabled)
        .accessibilityRepresentation {
            Stepper(title, value: $value, in: range)
        }
    }

    private func step(_ delta: Int, symbol: String, label: String) -> some View {
        let target = value + delta
        return Button {
            value = target
        } label: {
            Text(symbol)
                .font(Typeface.mono(20))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressHighlightStyle())
        .disabled(!range.contains(target))
        .accessibilityLabel(label)
    }
}

/// Tints the background while pressed and fades when disabled.
private struct PressHighlightStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressHighlight(configuration: configuration)
    }

    private struct PressHighlight: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .background(Palette.ink.opacity(configuration.isPressed ? 0.14 : 0))
                .opacity(isEnabled ? 1 : 0.3)
        }
    }
}
