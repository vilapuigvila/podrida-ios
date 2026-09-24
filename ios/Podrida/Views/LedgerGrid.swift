import SwiftUI

/// The score table: a column per player, a line per turn.
///
/// Only the cells scroll. The player names, the turn numbers and the totals row sit outside the scroll
/// view and are shifted by its offset, so they stay pinned while following it along their own axis.
struct LedgerGrid: View {
    @Binding var game: Game
    let activeTurn: Int
    var focus: FocusState<LedgerField?>.Binding

    @State private var scroll = ScrollOffset()

    private static let turnColumnWidth: CGFloat = 48
    private static let minColumnWidth: CGFloat = 84
    private static let headerHeight: CGFloat = 50
    private static let rowHeight: CGFloat = 146
    private static let footerHeight: CGFloat = 64

    var body: some View {
        GeometryReader { proxy in
            // Few players share the width; many keep a readable minimum and scroll sideways.
            let columnWidth = max(
                Self.minColumnWidth,
                (proxy.size.width - Self.turnColumnWidth) / CGFloat(max(game.playerCount, 1))
            )
            VStack(spacing: 0) {
                header(columnWidth: columnWidth)
                HStack(alignment: .top, spacing: 0) {
                    turnNumbers
                    cells(columnWidth: columnWidth)
                }
                footer(columnWidth: columnWidth)
            }
        }
    }

    // MARK: Rows

    /// A turn stays editable while it's the active one, and while the keyboard is still in it after it's
    /// complete, so a two-digit entry or a correction isn't cut off the moment the turn fills up.
    private func isEditable(_ turn: Int) -> Bool {
        turn == activeTurn || turn == focus.wrappedValue?.turn
    }

    private func isPending(_ turn: Int) -> Bool {
        turn > activeTurn && !isEditable(turn)
    }

    private func stripe(_ turn: Int) -> Color {
        turn.isMultiple(of: 2) ? .clear : Palette.ink.opacity(0.025)
    }

    private func header(columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            cornerLabel("Turn")
            Synced(offset: scroll, axis: .horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<game.playerCount, id: \.self) { player in
                        PlayerNameField(
                            name: $game.playerNames[player],
                            player: player,
                            focus: focus
                        )
                        .frame(width: columnWidth)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .frame(height: Self.headerHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private var turnNumbers: some View {
        Synced(offset: scroll, axis: .vertical) {
            VStack(spacing: 0) {
                ForEach(0..<game.turnCount, id: \.self) { turn in
                    Text(turn + 1, format: .number)
                        .font(Typeface.typewriter(14))
                        .foregroundStyle(Palette.rule)
                        .frame(width: Self.turnColumnWidth, height: Self.rowHeight)
                        .background(stripe(turn))
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
                        .overlay(alignment: .trailing) { Rectangle().fill(Palette.rule).frame(width: 2) }
                        .opacity(isPending(turn) ? 0.4 : 1)
                        .accessibilityLabel("Turn \(turn + 1)")
                }
            }
        }
        .frame(width: Self.turnColumnWidth)
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    private func cells(columnWidth: CGFloat) -> some View {
        let runningTotals = game.runningTotals
        return ScrollViewReader { reader in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<game.turnCount, id: \.self) { turn in
                        HStack(spacing: 0) {
                            ForEach(0..<game.playerCount, id: \.self) { player in
                                TurnCell(
                                    called: $game.hands[turn][player],
                                    won: $game.won[turn][player],
                                    total: runningTotals[turn][player],
                                    turn: turn,
                                    player: player,
                                    playerName: game.playerNames[player],
                                    isEditable: isEditable(turn),
                                    focus: focus
                                )
                                .frame(width: columnWidth, height: Self.rowHeight)
                                .id(CellID(turn: turn, player: player))
                            }
                        }
                        .background(stripe(turn))
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
                        .opacity(isPending(turn) ? 0.4 : 1)
                    }
                }
            }
            .defaultScrollAnchor(.topLeading)
            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
            .onScrollGeometryChange(for: CGPoint.self) { geometry in
                CGPoint(
                    x: geometry.contentOffset.x + geometry.contentInsets.leading,
                    y: geometry.contentOffset.y + geometry.contentInsets.top
                )
            } action: { _, offset in
                scroll.x = offset.x
                scroll.y = offset.y
            }
            .onChange(of: focus.wrappedValue) { _, field in
                guard let field, let turn = field.turn else { return }
                withAnimation { reader.scrollTo(CellID(turn: turn, player: field.player)) }
            }
        }
    }

    private func footer(columnWidth: CGFloat) -> some View {
        let totals = game.totals
        let leaders = game.leaders
        return HStack(spacing: 0) {
            cornerLabel("Total")
            Synced(offset: scroll, axis: .horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<game.playerCount, id: \.self) { player in
                        TotalCell(
                            total: totals[player],
                            isLeader: leaders.contains(player),
                            playerName: game.playerNames[player]
                        )
                        .frame(width: columnWidth)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .frame(height: Self.footerHeight)
        .overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 2) }
    }

    private func cornerLabel(_ text: String) -> some View {
        Text(text)
            .font(Typeface.typewriter(10))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Palette.inkSoft)
            .frame(width: Self.turnColumnWidth)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .trailing) { Rectangle().fill(Palette.rule).frame(width: 2) }
            .accessibilityHidden(true)
    }
}

private struct CellID: Hashable {
    let turn: Int
    let player: Int
}

/// The body's scroll position, read only by the pinned rows and column so scrolling doesn't redraw the cells.
@MainActor
@Observable
private final class ScrollOffset {
    var x: CGFloat = 0
    var y: CGFloat = 0
}

/// Shifts its content to follow the body's scroll position along one axis.
private struct Synced<Content: View>: View {
    let offset: ScrollOffset
    let axis: Axis
    @ViewBuilder var content: Content

    var body: some View {
        content.offset(
            x: axis == .horizontal ? -offset.x : 0,
            y: axis == .vertical ? -offset.y : 0
        )
    }
}

/// A player's name in the header; editable at any point in the game.
private struct PlayerNameField: View {
    @Binding var name: String
    let player: Int
    var focus: FocusState<LedgerField?>.Binding

    var body: some View {
        let isFocused = focus.wrappedValue == .name(player: player)
        TextField("Player \(player + 1)", text: $name)
            .font(Typeface.mono(13, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .tint(Palette.rule)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused(focus, equals: .name(player: player))
            .onSubmit { focus.wrappedValue = nil }
            .padding(.vertical, 6)
            .background(isFocused ? Palette.rule.opacity(0.06) : .clear)
            .overlay(alignment: .bottom) {
                if isFocused {
                    Rectangle().fill(Palette.rule).frame(height: 1.5)
                } else {
                    DashedLine().stroke(Palette.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).frame(height: 1.5)
                }
            }
            .padding(.horizontal, 6)
            .accessibilityLabel("Player \(player + 1) name")
    }
}

/// A player's total, with the brass "high score" stamp on the leader.
private struct TotalCell: View {
    let total: Int
    let isLeader: Bool
    let playerName: String

    var body: some View {
        VStack(spacing: 4) {
            Text(total, format: .number)
                .font(Typeface.mono(15, weight: .bold))
                .foregroundStyle(isLeader ? Palette.brass : Palette.ink)
            if isLeader {
                Text("High score")
                    .font(Typeface.typewriter(8))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(Palette.brass)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .overlay(Capsule().stroke(Palette.brass, lineWidth: 1))
                    .rotationEffect(.degrees(-3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(playerName) total")
        .accessibilityValue(isLeader ? "\(total), high score" : "\(total)")
    }
}

/// A horizontal line through the middle of its frame, for dashed rules.
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
