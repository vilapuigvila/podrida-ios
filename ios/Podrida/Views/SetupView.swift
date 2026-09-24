import SwiftUI

/// The new-game screen: how many players, their names, and how many turns.
struct SetupView: View {
    let onStart: (Game) -> Void

    @State private var names = Array(repeating: "", count: 4)
    @State private var turnCount = 10
    @FocusState private var focusedName: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("New game")
                    .font(Typeface.typewriter(11))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Palette.rule)
                    .padding(.bottom, 14)

                Text("Podrida\nScore")
                    .font(Typeface.typewriter(30))
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 12)

                Text("Every player gets a column. Every turn gets a line.")
                    .font(Typeface.mono(13))
                    .lineSpacing(4)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.bottom, 30)

                field("Players") {
                    BoxedStepper(title: "Players", value: playerCount, range: 1...Game.maxPlayers)
                }

                field("Player names") {
                    VStack(spacing: 8) {
                        ForEach(names.indices, id: \.self) { index in
                            nameField(index)
                        }
                    }
                }

                field("Turns") {
                    BoxedStepper(title: "Turns", value: $turnCount, range: 1...Game.maxTurns)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 34)
            .padding(.bottom, 24)
            .frame(maxWidth: 420, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        // The main action stays at the bottom of the screen, above the home indicator.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Open the Ledger →") {
                onStart(.starting(names: names, turnCount: turnCount))
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 368)
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(Palette.paper)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        }
        .background(Palette.paper.ignoresSafeArea())
    }

    /// Changing the count keeps names already typed for the remaining seats.
    private var playerCount: Binding<Int> {
        Binding {
            names.count
        } set: { count in
            if count > names.count {
                names += Array(repeating: "", count: count - names.count)
            } else {
                names.removeLast(names.count - count)
            }
        }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).fieldCaption()
            content()
        }
        .padding(.bottom, 22)
    }

    private func nameField(_ index: Int) -> some View {
        // Bounds-checked so a field being removed never reads past the end of `names`.
        let text = Binding {
            names.indices.contains(index) ? names[index] : ""
        } set: { newValue in
            if names.indices.contains(index) { names[index] = newValue }
        }
        let isFocused = focusedName == index
        return TextField(
            "Player \(index + 1)",
            text: text,
            prompt: Text("Player \(index + 1)").foregroundStyle(Palette.inkSoft.opacity(0.65))
        )
        .font(Typeface.mono(14))
        .foregroundStyle(Palette.ink)
        .tint(Palette.rule)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(index == names.count - 1 ? .done : .next)
        .focused($focusedName, equals: index)
        .onSubmit { focusedName = index + 1 < names.count ? index + 1 : nil }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isFocused ? Palette.rule : Palette.line)
                .frame(height: 1.5)
        }
    }
}
