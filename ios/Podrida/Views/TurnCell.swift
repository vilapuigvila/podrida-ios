import SwiftUI

/// One player's line for one turn: hands called, hands won, and the running score.
struct TurnCell: View {
    @Binding var called: Int?
    @Binding var won: Int?
    let total: Int?
    let turn: Int
    let player: Int
    let playerName: String
    let isEditable: Bool
    /// While this turn breaks a rule, only the numbers it's about can be edited (the calls or the
    /// results), and the rest is dimmed.
    var lockedTo: LockedPart?
    var focus: FocusState<LedgerField?>.Binding

    var body: some View {
        VStack(spacing: 0) {
            entry("Hands", value: $called, field: .hands(turn: turn, player: player), spoken: "hands called", part: .calls)
            divider
            entry("Won", value: $won, field: .won(turn: turn, player: player), spoken: "hands won", part: .results)
            divider
            VStack(spacing: 1) {
                caption("Score")
                Text(total.map { String($0) } ?? "–")
                    .font(Typeface.mono(14, weight: .semibold))
                    .foregroundStyle((total ?? 0) < 0 ? Palette.rule : Palette.ink)
                    .frame(height: 26)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(playerName), score after turn \(turn + 1)")
            .accessibilityValue(total.map { String($0) } ?? "Not scored yet")
            .opacity(lockedTo != nil ? 0.35 : 1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var divider: some View {
        DashedLine()
            .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.vertical, 5)
    }

    private func caption(_ text: String) -> some View {
        Text(text).fieldCaption(size: 8, tracking: 0.4)
    }

    private func entry(_ title: String, value: Binding<Int?>, field: LedgerField, spoken: String, part: LockedPart) -> some View {
        let editable = isEditable && (lockedTo == nil || lockedTo == part)
        return VStack(spacing: 1) {
            caption(title)
            // Only the turn being played gets text fields; every other line is plain text.
            if editable {
                NumberField(value: value, isFocused: focus.wrappedValue == field)
                    .focused(focus, equals: field)
                    .accessibilityLabel("\(playerName), turn \(turn + 1), \(spoken)")
            } else {
                Text(value.wrappedValue.map { String($0) } ?? "–")
                    .font(Typeface.mono(15))
                    .foregroundStyle(value.wrappedValue == nil ? Palette.line : Palette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .accessibilityLabel("\(playerName), turn \(turn + 1), \(spoken)")
                    .accessibilityValue(value.wrappedValue.map { String($0) } ?? "Empty")
            }
        }
        .background(lockedTo == part ? Palette.rule.opacity(0.1) : .clear, in: .rect(cornerRadius: 3))
        .opacity(lockedTo != nil && lockedTo != part ? 0.35 : 1)
    }
}

/// The half of a turn cell a broken rule is about.
enum LockedPart {
    case calls
    case results
}

/// Digits-only entry for a count of hands; empty means not entered yet.
private struct NumberField: View {
    @Binding var value: Int?
    let isFocused: Bool

    @State private var selection: TextSelection?

    var body: some View {
        TextField("", text: text, selection: $selection, prompt: Text("–").foregroundStyle(Palette.line))
            // Select the whole value on entry, so typing replaces it instead of appending digits.
            .onChange(of: isFocused) { _, focused in
                guard focused, let current = value.map({ String($0) }) else { return }
                selection = TextSelection(range: current.startIndex..<current.endIndex)
            }
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(Typeface.mono(15))
            .foregroundStyle(Palette.ink)
            .tint(Palette.rule)
            .frame(height: 26)
            .background(isFocused ? Palette.rule.opacity(0.1) : .clear)
            .overlay(alignment: .bottom) {
                if isFocused { Rectangle().fill(Palette.rule).frame(height: 2) }
            }
    }

    private var text: Binding<String> {
        Binding {
            value.map { String($0) } ?? ""
        } set: { newValue in
            let digits = newValue.filter { $0.isASCII && $0.isNumber }.prefix(3)
            value = digits.isEmpty ? nil : Int(digits)
        }
    }
}
