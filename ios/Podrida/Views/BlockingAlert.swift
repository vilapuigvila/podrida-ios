import SwiftUI

/// A modal card in the ledger's paper style, replacing the system alert. It dims and blocks the
/// screen like one, but never takes focus, so a keyboard already up stays up.
struct BlockingAlert<Actions: View>: View {
    let emoji: String
    let title: String
    var titleColor: Color = Palette.ink
    /// A top accent stripe, for the rule alert's warning look.
    var accent: Color?
    let message: String?
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture {}
            card
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("blockingAlert")
        .transition(.opacity)
    }

    private var card: some View {
        VStack(spacing: 0) {
            if let accent {
                Rectangle().fill(accent).frame(height: 4)
            }
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 30))
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typeface.typewriter(16))
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let message {
                    Text(message)
                        .font(Typeface.mono(13))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 10) { actions }
            }
            .padding(20)
        }
        .frame(maxWidth: 320)
        .background(Palette.paper, in: .rect(cornerRadius: 6))
        .clipShape(.rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.ink, lineWidth: 1.5))
        .padding(28)
    }
}

extension View {
    /// Shows a `BlockingAlert` over this view, like `.alert`, but without taking focus or dropping
    /// the keyboard.
    func blockingAlert<Actions: View>(
        isPresented: Bool,
        emoji: String,
        title: String,
        titleColor: Color = Palette.ink,
        accent: Color? = nil,
        message: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        overlay {
            if isPresented {
                BlockingAlert(
                    emoji: emoji,
                    title: title,
                    titleColor: titleColor,
                    accent: accent,
                    message: message,
                    actions: actions
                )
            }
        }
        .animation(.default, value: isPresented)
    }
}
