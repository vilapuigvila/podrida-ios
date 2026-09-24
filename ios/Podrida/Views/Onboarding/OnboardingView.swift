import Lottie
import SwiftUI

/// One page of the introduction: a Lottie animation from Resources/Animations and a short explanation.
struct OnboardingPage: Identifiable {
    let id: Int
    let animation: String
    let title: String
    let message: String
    /// The frame shown when the page isn't playing, or with Reduce Motion on: a moment with the whole picture drawn.
    let still: AnimationProgressTime
    /// The music under this page. The last page switches to a brighter track for the finish.
    let music: OnboardingMusic.Track

    static let all = [
        OnboardingPage(
            id: 0, animation: "deal", title: "Deal them in",
            message: "Podrida Score keeps the book for your card nights. Every player gets a column, every turn a line.",
            still: 0.5, music: .jazz
        ),
        OnboardingPage(
            id: 1, animation: "call", title: "Call your hands",
            message: "Each turn, everyone calls how many hands they'll win. The calls can't add up to the turn number, and the ledger tells you when they do.",
            still: 0.75, music: .jazz
        ),
        OnboardingPage(
            id: 2, animation: "stamp", title: "Hit it exactly",
            message: "An exact call scores 5, plus 3 per hand won. A miss costs 5, plus 3 per hand off.",
            still: 0.55, music: .jazz
        ),
        OnboardingPage(
            id: 3, animation: "crown", title: "Crown the leader",
            message: "Running totals stay pinned at the bottom, and whoever's ahead gets the high-score stamp.",
            still: 0.6, music: .chiptune
        ),
    ]
}

/// The introduction shown on first launch, and again from "How it works" on the setup screen.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page: Int? = 0
    @State private var music = OnboardingMusic()
    @AppStorage("onboardingMuted") private var isMuted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var current: Int { page ?? 0 }
    private var isLast: Bool { current == OnboardingPage.all.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(OnboardingPage.all) { item in
                        PageView(page: item, isCurrent: item.id == current, reduceMotion: reduceMotion)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)

            PageDots(count: OnboardingPage.all.count, current: current)
                .padding(.bottom, 20)

            Button {
                if isLast {
                    finish()
                } else {
                    withAnimation(.smooth(duration: 0.5)) { page = current + 1 }
                }
            } label: {
                Text(isLast ? "Start scoring →" : "Next")
                    .contentTransition(.interpolate)
                    .animation(.smooth, value: isLast)
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 368)
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
        }
        .background(RuledPaper().ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: current)
        .onAppear { music.play(OnboardingPage.all[current].music, muted: isMuted) }
        .onChange(of: current) { _, page in music.play(OnboardingPage.all[page].music, muted: isMuted) }
        .onDisappear { Task { await music.stop() } }
        .onChange(of: isMuted) { _, muted in music.setMuted(muted) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { music.resume() }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash" : "speaker.wave.2")
                    .contentTransition(.symbolEffect(.replace))
                    .font(.system(size: 17))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isMuted ? "Turn music on" : "Turn music off")

            Spacer()

            Button("Skip", action: finish)
                .font(Typeface.mono(13))
                .frame(minWidth: 44, minHeight: 44)
                .opacity(isLast ? 0 : 1)
                .disabled(isLast)
                .animation(.smooth, value: isLast)
        }
        .foregroundStyle(Palette.inkSoft)
        .padding(.horizontal, 14)
    }

    private func finish() {
        // The music fades out on its own while the setup screen comes in.
        Task { await music.stop() }
        onFinish()
    }
}

private struct PageView: View {
    let page: OnboardingPage
    let isCurrent: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            LottieView(animation: .named(page.animation))
                .playbackMode(playback)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 340, maxHeight: 340)
                .padding(.horizontal, 24)
                .accessibilityHidden(true)
                // While swiping, the picture turns away like a page and shrinks back.
                .scrollTransition(.interactive) { content, phase in
                    content
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : phase.value * -40), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                        .scaleEffect(1 - abs(phase.value) * 0.25)
                        .opacity(1 - abs(phase.value) * 0.8)
                }

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                Text("Step \(page.id + 1) of \(OnboardingPage.all.count)")
                    .fieldCaption(size: 11, tracking: 1.5, color: Palette.rule)
                Text(page.title)
                    .font(Typeface.typewriter(30))
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(page.message)
                    .font(Typeface.mono(14))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)
            // The text trails the picture a little, for depth.
            .scrollTransition(.interactive) { content, phase in
                content
                    .offset(x: reduceMotion ? 0 : phase.value * 90)
                    .opacity(1 - abs(phase.value) * 1.4)
            }

            Spacer(minLength: 20)
        }
        .accessibilityElement(children: .contain)
    }

    private var playback: LottiePlaybackMode {
        guard isCurrent, !reduceMotion else { return .paused(at: .progress(page.still)) }
        return .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
    }
}

/// The page indicator: a dot per page, with the current one stretched into a red dash.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.rule : Palette.line)
                    .frame(width: index == current ? 24 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.4), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// Ledger paper: faint ruled lines and a red margin.
private struct RuledPaper: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            var y = spacing
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Palette.line.opacity(0.45)))
                y += spacing
            }
            context.fill(Path(CGRect(x: 30, y: 0, width: 1.5, height: size.height)), with: .color(Palette.rule.opacity(0.22)))
        }
        .background(Palette.paper)
    }
}

#Preview {
    OnboardingView {}
}
