import SwiftUI
import UIKit
import AVFoundation

/// The guessing screen, rebuilt from the running fakester.app (phone format
/// 375×812, October 2026):
/// - top: "ROUND n / 5", the clock pill and "Leave", then a 4 pt time bar
///   across the full width,
/// - a row of player chips (your own one highlighted),
/// - a scroll area with the cover ("NOW PLAYING" strip), the player card and
///   the answers - two columns of choices or one text field per guess type -
///   ending in the lock-in button,
/// - a fixed emoji bar at the bottom.
///
/// The scroll area starts right at the top edge of the cover. When you scroll,
/// the cover slides under that edge and only its bottom strip stays visible -
/// that is what the website's "-s1" shots show, nothing more.
///
/// The button at the bottom is deliberately not final: the server allows
/// changing the answer any number of times, because the speed bonus depends on
/// the lock-in time - changing later pays for itself.
struct RoundView: View {
    @EnvironmentObject private var game: Game
    /// While the keyboard is up the emoji bar steps aside. In iOS Safari it
    /// ends up behind the keyboard; here it would otherwise eat 65 pt of the
    /// little room that is left above it.
    @State private var typing = false

    var body: some View {
        VStack(spacing: 0) {
            RoundTopBar()
            RoundChipRow()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        LargeCover()
                        PlaybackCard()
                    }
                    AnswerColumn()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            if !typing {
                ReactionBar()
                    .overlay(alignment: .top) { ReactionCloud() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            typing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            typing = false
        }
    }
}

// MARK: - Colors

/// Values that only appear on this screen (read from the web bundle).
private enum RoundPalette {
    /// --acc-pale for #b15cff: text of a picked answer.
    static let pale = Color(hex: 0xCC95FF)
    /// #b0aed2: answer text, other players' names, "Change answer".
    static let optionText = Color(hex: 0xB0AED2)
    /// #f59e0b: the clock from 10 seconds on.
    static let amber = Color(hex: 0xF59E0B)
    static let amberDeep = Color(hex: 0xB45309)
    static let redDeep = Color(hex: 0xB91C1C)
    /// The player card: rgba(24,23,39,.95).
    static let cardFill = rgba(24, 23, 39, 0.95)
    /// Other players' chips: rgba(24,23,39,.9).
    static let chipFill = rgba(24, 23, 39, 0.9)
    /// Free-text fields: rgba(10,9,20,.6).
    static let fieldFill = rgba(10, 9, 20, 0.6)
    /// Placeholder: the text color at 50 %.
    static let placeholder = Color(hex: 0xEEEEFF).opacity(0.5)
    /// The emoji bar: rgba(7,7,14,.8).
    static let barFill = rgba(7, 7, 14, 0.8)
    /// Name tag under a floating emoji: rgba(7,7,14,.75).
    static let nameTag = rgba(7, 7, 14, 0.75)
    /// Bottom shade of the cover: rgba(4,4,10,.75).
    static let coverShade = rgba(4, 4, 10, 0.75)
    /// Ring around the white scrubber knob: rgba(7,7,12,.85).
    static let knobRing = rgba(7, 7, 12, 0.85)
    /// Volume knob #9d9cbb, muted fill #6a6889.
    static let volumeKnob = Color(hex: 0x9D9CBB)
    static let mutedFill = Color(hex: 0x6A6889)
    /// linear-gradient(145deg, #0d0020, #1a0040, #120030, #050015) behind the cover.
    static let coverGround: [Color] = [Color(hex: 0x0D0020), Color(hex: 0x1A0040),
                                       Color(hex: 0x120030), Color(hex: 0x050015)]
    /// conic-gradient of the vinyl shown when there is no cover.
    static let vinyl: [Color] = [Color(hex: 0x1A0040), Color(hex: 0x2D1B69), Color(hex: 0x1A0040),
                                 Color(hex: 0x3B0764), Color(hex: 0x1A0040)]

    static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

/// Framer's `whileTap` scale, without any other effect.
private struct RoundPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// `inset 0 1px 0 <color>`: a hairline of light just inside the top edge.
private struct InsetTopLine: View {
    let radius: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .circular)
            .inset(by: 1)
            .strokeBorder(
                LinearGradient(colors: [color, color.opacity(0)],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.12)),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

/// A CSS `box-shadow: 0 0 <blur> <color>` around a translucent shape. SwiftUI's
/// `.shadow` takes the shape's own transparency into account and would almost
/// vanish at 28 % fill; the browser draws the glow at full strength, but only
/// outside the shape. This draws the shadow of an opaque shape and then cuts
/// the shape itself out again.
private struct OuterGlow: View {
    let radius: CGFloat
    let color: Color
    let blur: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .circular)
        ZStack {
            shape.fill(Color.black).shadow(color: color, radius: blur)
            shape.fill(Color.black).blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Header

/// "ROUND 1 / 5", the clock pill, "n/m answered" when there are several
/// players, "Leave" - and below it the time bar (4 pt, full width).
///
/// The clock turns amber at 10 seconds and red at 5, and from then on the pill
/// pulses with every second - the only moment the page gets loud.
private struct RoundTopBar: View {
    @EnvironmentObject private var game: Game
    /// Becomes true with the first tick of the clock, see `barFraction`.
    @State private var counting = false
    @State private var beat = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                roundLabel.fixedSize()
                clockPill.fixedSize()
                if game.player.count > 1 {
                    answeredLabel
                }
                Spacer(minLength: 0)
                LeaveButton { game.leave() }
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            RoundTimeBar(fraction: barFraction, fill: barFill)
                .animation(.linear(duration: counting ? 1 : 0), value: barFraction)
        }
        .onChange(of: game.secondsLeft) { _ in
            counting = true
            if urgent { pulse() }
        }
    }

    private var roundLabel: some View {
        let number: Int = game.activeRound?.round ?? 1
        let total: Int = game.activeRound?.totalRounds ?? 0
        let first: Text = Text("ROUND \(number)").foregroundColor(Palette.accent)
        let second: Text = Text(" / \(total)").foregroundColor(Palette.subdued)
        return (first + second)
            .font(.brand(12, .bold))
            .lineLimit(1)
    }

    private var clockPill: some View {
        let hue: Color = clockColor
        return HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .semibold))
            Text("\(shownSeconds)s")
                .font(Font.brand(11, .bold).monospacedDigit())
        }
        .foregroundColor(hue)
        .padding(.horizontal, 11)
        .frame(height: 27)
        .background(Capsule().fill(hue.opacity(0.12)))
        .overlay(Capsule().strokeBorder(hue.opacity(0.35), lineWidth: 1))
        .scaleEffect(beat ? 1.08 : 1)
        .animation(.easeInOut(duration: 0.4), value: clockColor)
    }

    private var answeredLabel: some View {
        let players: [Player] = game.player.filter { !$0.watchOnly }
        let ready: Int = players.filter { $0.isReady }.count
        return Text("\(ready)/\(game.player.count) answered")
            .font(.brand(11, .semibold))
            .foregroundColor(Palette.subdued)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// The round length. The browser takes `guessTime` from the settings too.
    private var fullTime: Int { max(1, game.lobbySettings?.guessTime ?? 30) }

    /// The app's clock includes the server's grace period before the round
    /// (`startDelayMs`) and would briefly show "21s"; the browser stays at the
    /// round length until the grace period is over.
    private var shownSeconds: Int { max(0, min(game.secondsLeft, fullTime)) }

    private var urgent: Bool { shownSeconds <= 5 }
    private var warning: Bool { shownSeconds <= 10 }

    private var clockColor: Color {
        if urgent { return Palette.bad }
        if warning { return RoundPalette.amber }
        return Palette.accent
    }

    private var barFill: AnyShapeStyle {
        if urgent {
            return AnyShapeStyle(LinearGradient(colors: [RoundPalette.redDeep, Palette.bad],
                                                startPoint: .leading, endPoint: .trailing))
        }
        if warning {
            return AnyShapeStyle(LinearGradient(colors: [RoundPalette.amberDeep, RoundPalette.amber],
                                                startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(Palette.accent)
    }

    /// The browser recomputes the bar every 100 ms. The app only knows whole
    /// seconds (rounded up), so the bar is sent to where it will be one second
    /// later and gets exactly that second to get there: when the clock jumps
    /// to n, the true remaining time is just under n, and it reaches n - 1 when
    /// the animation ends. Before the first tick (view just appeared) the bar
    /// simply shows the current value.
    private var barFraction: Double {
        let left: Int = game.secondsLeft
        let total: Double = Double(fullTime)
        if left > fullTime { return 1 }
        if !counting { return min(1, Double(left) / total) }
        return max(0, Double(left - 1) / total)
    }

    /// Framer's `scale: [1, 1.08, 1]` once per second.
    private func pulse() {
        withAnimation(.easeOut(duration: 0.45)) { beat = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.easeIn(duration: 0.45)) { beat = false }
        }
    }
}

/// The 4 pt bar under the header: track white 6 %, fill without rounded ends.
private struct RoundTimeBar: View {
    let fraction: Double
    let fill: AnyShapeStyle

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.06))
                Rectangle()
                    .fill(fill)
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Player chips

/// Everyone in the game as small chips (8 pt apart, scrolls sideways when
/// there are many). Your own chip is purple; a green edge and a check mean
/// that player has locked in.
private struct RoundChipRow: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(game.player) { p in
                    RoundChip(player: p, isMe: p.id.text == game.ownId)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One chip: padding 4/10/4/4, 30 pt high, avatar 20, name 11 pt bold, score
/// 10 pt.
private struct RoundChip: View {
    let player: Player
    let isMe: Bool

    var body: some View {
        HStack(spacing: 6) {
            RoundAvatar(player: player)
            Text(player.nickname)
                .font(.brand(11, .bold))
                .foregroundColor(isMe ? Palette.accent : RoundPalette.optionText)
                .lineLimit(1)
            Text("\(player.score)")
                .font(Font.brand(10).monospacedDigit())
                .foregroundColor(Palette.subdued)
            if player.isReady {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Palette.good)
                    .frame(width: 10, height: 10)
            }
        }
        // Padding plus the 1 pt border.
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(edge, lineWidth: 1))
    }

    private var fill: Color {
        isMe ? Palette.accentDeep.opacity(0.18) : RoundPalette.chipFill
    }

    private var edge: Color {
        if player.isReady { return Palette.good.opacity(0.4) }
        if isMe { return Palette.accent.opacity(0.4) }
        return Color.white.opacity(0.08)
    }
}

/// The round player picture at 20 pt: white 7 % as ground, the profile picture
/// or the player symbol in pale purple, otherwise the first letter.
private struct RoundAvatar: View {
    let player: Player
    private let dimension: CGFloat = 20

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(pictureURL == nil ? 0.07 : 0.05))
            if let url = pictureURL {
                AsyncImage(url: url) { phase in
                    if let loaded = phase.image {
                        loaded.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
                .frame(width: dimension, height: dimension)
                .clipShape(Circle())
            } else {
                fallback
            }
        }
        .frame(width: dimension, height: dimension)
    }

    private var pictureURL: URL? {
        guard let s = player.avatarUrl, s.hasPrefix("http") else { return nil }
        return URL(string: s)
    }

    @ViewBuilder
    private var fallback: some View {
        if player.iconId != 0 {
            Image(systemName: "person.fill")
                .font(.system(size: 9))
                .foregroundColor(RoundPalette.pale)
        } else {
            Text(String(player.nickname.first ?? "?").uppercased())
                .font(.brand(8, .bold))
                .foregroundColor(Palette.foreground)
        }
    }
}

// MARK: - Cover

/// The cover, 180 × 180, corners 16, centered. Behind the picture a blurred
/// and darkened copy of it, on top a shade toward the bottom and the "NOW
/// PLAYING" strip. While the clip is paused the picture turns a little grey
/// and dark, as in the browser. Without a cover (the host switched covers
/// off) there is a vinyl instead.
struct LargeCover: View {
    @EnvironmentObject private var game: Game
    @ObservedObject private var tone = AudioPlayer.instance

    private let side: CGFloat = 180

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: RoundPalette.coverGround,
                           startPoint: UnitPoint(x: 0.2, y: 0), endPoint: UnitPoint(x: 0.8, y: 1))
            if let url = coverURL {
                picture(url)
                LinearGradient(stops: [Gradient.Stop(color: Color.clear, location: 0.55),
                                       Gradient.Stop(color: RoundPalette.coverShade, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                nowPlaying
            } else {
                CoverPlaceholder(spinning: tone.isRunning)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .circular))
        .frame(maxWidth: .infinity)
    }

    private var coverURL: URL? {
        guard let s = game.activeRound?.albumArt, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    private func picture(_ url: URL) -> some View {
        let playing: Bool = tone.isRunning
        return AsyncImage(url: url) { phase in
            if let loaded = phase.image {
                ZStack {
                    // blur(18px) brightness(.55) scale(1.15), object-fit: cover
                    loaded.resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .scaleEffect(1.15)
                        .blur(radius: 9)
                        .colorMultiply(Color(white: 0.55))
                    // object-fit: contain; paused: grayscale(.4) brightness(.7)
                    loaded.resizable()
                        .scaledToFit()
                        .frame(width: side, height: side)
                        .saturation(playing ? 1 : 0.6)
                        .colorMultiply(Color(white: playing ? 1 : 0.7))
                        .animation(.easeInOut(duration: 0.4), value: playing)
                }
            } else {
                Color.clear
            }
        }
        .frame(width: side, height: side)
    }

    /// Bars and "NOW PLAYING", 12 pt from the bottom left.
    private var nowPlaying: some View {
        HStack(spacing: 6) {
            WaveBars(hue: .white, strength: 0.85, size: 0.8)
            Text("NOW PLAYING")
                .font(.brand(10, .bold))
                .tracking(1)
                .foregroundColor(Color.white.opacity(0.75))
        }
        .padding(.leading, 12)
        .padding(.bottom, 12)
    }
}

/// No cover: a purple glow, a vinyl turning while the clip plays, and
/// "COVER HIDDEN".
private struct CoverPlaceholder: View {
    let spinning: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.accentDeep.opacity(0.4), Palette.accentDeep.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 52))
                .frame(width: 160, height: 160)
                .blur(radius: 10)
            VStack(spacing: 12) {
                SpinningVinyl(spinning: spinning)
                Text("COVER HIDDEN")
                    .font(.brand(11, .bold))
                    .tracking(1.1)
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The vinyl: 96 pt, one turn in 8 s; it stops where it is when the clip is
/// paused.
private struct SpinningVinyl: View {
    let spinning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !spinning)) { context in
            disc.rotationEffect(.degrees(angle(at: context.date)))
        }
    }

    private var disc: some View {
        let grooves = AngularGradient(gradient: Gradient(colors: RoundPalette.vinyl), center: .center,
                                      startAngle: .degrees(-90), endAngle: .degrees(270))
        let label = RadialGradient(colors: [Palette.accent, Palette.accentDeep],
                                   center: .center, startRadius: 0, endRadius: 14)
        return Circle()
            .fill(grooves)
            .frame(width: 96, height: 96)
            .overlay(Circle().fill(label).frame(width: 28, height: 28))
            .shadow(color: Palette.accentDeep.opacity(0.5), radius: 16)
    }

    private func angle(at date: Date) -> Double {
        let seconds: Double = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8)
        return seconds / 8 * 360
    }
}

/// The bouncing bars (`Ft` in the bundle): nine bars 3 pt apart, each
/// shrinking to 22 % and back at its own pace, anchored at the bottom.
/// `size` scales width and height like the browser's `size` prop (the cover
/// and the reveal use 0.8).
struct WaveBars: View {
    var hue: Color = .white
    /// Opacity of the bars.
    var strength: Double = 0.9
    var size: CGFloat = 0.8

    /// Height, cycle duration and delay per bar, straight from the bundle.
    private static let bars: [(height: CGFloat, duration: Double, delay: Double)] = [
        (8, 0.55, 0.00), (14, 0.40, 0.08), (10, 0.70, 0.04),
        (18, 0.45, 0.12), (12, 0.60, 0.06), (16, 0.50, 0.10),
        (9, 0.65, 0.02), (13, 0.42, 0.14), (11, 0.58, 0.07)
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<WaveBars.bars.count, id: \.self) { i in
                WaveBar(width: 3 * size,
                        height: WaveBars.bars[i].height * size,
                        duration: WaveBars.bars[i].duration,
                        delay: WaveBars.bars[i].delay,
                        hue: hue.opacity(strength))
            }
        }
        .frame(height: 20 * size, alignment: .bottom)
    }
}

/// One bar: `@keyframes eq { 0%, 100% { scaleY(1) } 50% { scaleY(.22) } }`.
private struct WaveBar: View {
    let width: CGFloat
    let height: CGFloat
    let duration: Double
    let delay: Double
    let hue: Color
    @State private var low = false

    var body: some View {
        Capsule()
            .fill(hue)
            .frame(width: width, height: height)
            .scaleEffect(x: 1, y: low ? 0.22 : 1, anchor: .bottom)
            .onAppear {
                withAnimation(.easeInOut(duration: duration / 2).repeatForever(autoreverses: true).delay(delay)) {
                    low = true
                }
            }
    }
}

// MARK: - Player card

/// The card under the cover (343 × 112): status ("Now playing" / "Paused" /
/// "No preview") and time, the play button with the progress bar, and the
/// volume row. It is the proof that sound is coming - without it, someone on
/// a muted phone sits there puzzled.
///
/// The progress bar only shows progress. The browser also lets you scrub; the
/// app deliberately does not rewind (see `AudioPlayer.flip`).
struct PlaybackCard: View {
    @EnvironmentObject private var game: Game
    @ObservedObject private var tone = AudioPlayer.instance
    @ObservedObject private var volume = ClipVolume.shared

    var body: some View {
        VStack(spacing: 10) {
            statusRow
            HStack(spacing: 8) {
                playButton
                RoundScrubber(fraction: tone.fraction)
            }
            volumeRow
        }
        // 12 pt padding plus the 1 pt border
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(RoundCardBackground())
        // Every round brings a new clip player, which starts at full volume.
        .onAppear { volume.apply() }
        .onChange(of: tone.isRunning) { _ in volume.apply() }
        .onChange(of: game.activeRound?.round) { _ in volume.apply() }
    }

    private var statusRow: some View {
        HStack {
            Text(status)
                .font(.brand(10, .bold))
                .foregroundColor(Palette.accent)
            Spacer(minLength: 8)
            Text("\(clockText(tone.elapsed)) / \(clockText(tone.length))")
                .font(Font.brand(10).monospacedDigit())
                .foregroundColor(Palette.subdued)
        }
        .frame(height: 15)
    }

    private var status: String {
        let address: String = game.activeRound?.previewUrl ?? ""
        if address.isEmpty { return "No preview" }
        return tone.isRunning ? "Now playing" : "Paused"
    }

    private var playLabel: String { tone.isRunning ? "Pause" : "Play" }

    private var volumeText: String {
        volume.muted ? "off" : "\(Int((volume.level * 100).rounded()))%"
    }

    /// 36 pt, flat --acc, glow 0 0 16px --acc-deep 40 %.
    private var playButton: some View {
        Button {
            Haptics.tap()
            tone.flip()
        } label: {
            ZStack {
                Circle()
                    .fill(Palette.accent)
                    .shadow(color: Palette.accentDeep.opacity(0.4), radius: 8)
                Image(systemName: tone.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Palette.onAccent)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(RoundPressStyle(pressedScale: 0.92))
        .accessibilityLabel(Text(playLabel))
    }

    private var volumeRow: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                volume.toggleMute()
            } label: {
                Image(systemName: volume.silent ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(volume.silent ? Palette.bad : Palette.subdued)
                    .frame(width: 13, height: 13)
                    .contentShape(Rectangle().inset(by: -6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(muteLabel))

            RoundVolumeSlider()

            Text(volumeText)
                .font(Font.brand(10, .bold).monospacedDigit())
                .foregroundColor(Palette.subdued)
                .frame(minWidth: 26, alignment: .trailing)
        }
        .frame(height: 15)
    }

    private var muteLabel: String { volume.muted ? "Unmute" : "Mute" }

    private func clockText(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let whole: Int = Int(s)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

/// rgba(24,23,39,.95), border white 7 %, corners 16,
/// shadow 0 2px 16px black 30 % and a hairline of light at the top.
private struct RoundCardBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        ZStack {
            shape.fill(RoundPalette.cardFill)
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
            shape.strokeBorder(Palette.border, lineWidth: 1)
            InsetTopLine(radius: 16, color: Color.white.opacity(0.04))
        }
    }
}

/// The progress bar: track 8 pt white 13 %, fill --acc, a white 12 pt knob with
/// a dark ring at the end of the fill.
private struct RoundScrubber: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            let reach: CGFloat = geo.size.width * CGFloat(min(1, max(0, fraction)))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.13))
                Capsule().fill(Palette.accent).frame(width: reach)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(RoundPalette.knobRing, lineWidth: 2))
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .offset(x: reach - 6)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// The volume slider: track 4 pt white 9 %, fill white 26 %, knob 8 pt.
/// Dragging sets the volume (and unmutes, like the browser); the touch area
/// reaches a few points beyond the thin track.
private struct RoundVolumeSlider: View {
    @ObservedObject private var volume = ClipVolume.shared

    var body: some View {
        GeometryReader { geo in
            let width: CGFloat = geo.size.width
            let shown: Double = volume.muted ? 0 : volume.level
            let reach: CGFloat = width * CGFloat(shown)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.09))
                    .frame(height: 4)
                Capsule()
                    .fill(volume.muted ? RoundPalette.mutedFill : Color.white.opacity(0.26))
                    .frame(width: reach, height: 4)
                Circle()
                    .fill(volume.muted ? Palette.subdued : RoundPalette.volumeKnob)
                    .frame(width: 8, height: 8)
                    .offset(x: reach - 4)
            }
            .frame(width: width, height: geo.size.height)
            .contentShape(Rectangle().inset(by: -5))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0 else { return }
                        volume.setLevel(Double(drag.location.x / width))
                    }
            )
        }
        .frame(height: 15)
        .accessibilityLabel(Text("Volume"))
    }
}

/// The clip volume, as the browser's slider handles it: 80 % by default and
/// remembered across games (`fk_game_volume` there, `gameVolume` here); muting
/// only lasts for this app session.
///
/// `AudioPlayer` (Audio.swift) has no volume of its own and keeps its
/// `AVPlayer` private. Until it gets one, the player is looked up by reflection
/// under its property name `player`. If that name ever changes, the slider
/// simply stops having an effect - nothing breaks.
private final class ClipVolume: ObservableObject {
    static let shared = ClipVolume()
    private static let storageKey: String = "gameVolume"

    @Published private(set) var level: Double = 0.8
    @Published private(set) var muted: Bool = false

    /// Muted or at zero - then the speaker icon is the red crossed-out one.
    var silent: Bool { muted || level <= 0 }

    private init() {
        if let stored = UserDefaults.standard.object(forKey: ClipVolume.storageKey) as? Double, stored.isFinite {
            level = min(1, max(0, stored))
        }
    }

    func setLevel(_ value: Double) {
        let clamped: Double = min(1, max(0, value))
        level = clamped
        if clamped > 0 && muted { muted = false }
        UserDefaults.standard.set(clamped, forKey: ClipVolume.storageKey)
        apply()
    }

    func toggleMute() {
        muted.toggle()
        apply()
    }

    /// Hands the current values to the audio player (the clip playing now and
    /// every later one).
    func apply() {
        AudioPlayer.instance.volume = Float(muted ? 0 : level)
    }
}

// MARK: - Answers

/// The answer column: one block per guess type (12 pt apart), then the lock-in
/// button - or, once locked in, the green "Locked in" panel.
private struct AnswerColumn: View {
    @EnvironmentObject private var game: Game
    @FocusState private var focusedKind: String?

    /// Spelled out: the focus state must not end up in a memberwise initializer.
    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(game.guessKinds, id: \.self) { kind in
                if isMultipleChoice {
                    AnswerBlock(kind: kind)
                } else {
                    freeTextBlock(kind)
                }
            }
            bottomArea
        }
        .onChange(of: game.lockedIn) { locked in
            if locked { focusedKind = nil }
        }
    }

    private var isMultipleChoice: Bool { game.lobbySettings?.isMultipleChoice ?? true }

    @ViewBuilder
    private var bottomArea: some View {
        if game.lockedIn {
            LockedInPanel()
        } else {
            lockButton
        }
    }

    private var missingKinds: [String] {
        game.guessKinds.filter { kind in
            game.answer[kind].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: Lock-in button

    /// Says what is still missing ("Pick title, artist & year") instead of
    /// just staying grey - the difference between "can't" and "do this next".
    private var lockButton: some View {
        let missing: [String] = missingKinds
        let ready: Bool = missing.isEmpty
        return Button {
            lockIn()
        } label: {
            LockButtonLabel(title: ready ? "Lock in answer" : pickTitle(missing), ready: ready)
        }
        .buttonStyle(RoundPressStyle(pressedScale: ready ? 0.97 : 1))
        .disabled(!ready)
        .accessibilityIdentifier("lock-in")
    }

    private func pickTitle(_ missing: [String]) -> String {
        let words: [String] = missing.map { DisplayName.guessKind($0).lowercased() }
        return "Pick " + joinedList(words)
    }

    /// "a", "a & b", "a, b & c" - like the browser.
    private func joinedList(_ words: [String]) -> String {
        guard words.count > 1 else { return words.first ?? "" }
        let head: String = words.dropLast().joined(separator: ", ")
        return head + " & " + (words.last ?? "")
    }

    /// Like the browser, the answers go out trimmed.
    private func lockIn() {
        guard missingKinds.isEmpty else { return }
        var cleaned: Answer = game.answer
        cleaned.title = cleaned.title.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.artist = cleaned.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.year = cleaned.year.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned != game.answer { game.answer = cleaned }
        focusedKind = nil
        Haptics.lock()
        game.lockIn()
    }

    // MARK: Free text

    /// Label plus field: 46 pt high, 13 pt bold, rgba(10,9,20,.6), border white
    /// 8 % - --acc 45 % as soon as something is typed; half transparent once
    /// locked in.
    private func freeTextBlock(_ kind: String) -> some View {
        let value: String = game.answer[kind]
        let filled: Bool = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isLast: Bool = kind == game.guessKinds.last
        let isYear: Bool = kind == "year"
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        let hintText: String = isYear ? "e.g. 1998" : "Type the \(kind)…"
        let hint: Text = Text(hintText).foregroundColor(RoundPalette.placeholder)
        let caps: TextInputAutocapitalization = isYear ? .never : .words
        let keys: UIKeyboardType = isYear ? .numberPad : .default
        let returnKey: SubmitLabel = isLast ? .done : .next
        let edge: Color = filled ? Palette.accent.opacity(0.45) : Color.white.opacity(0.08)
        return VStack(alignment: .leading, spacing: 6) {
            GuessLabel(kind: kind, filled: filled)
            TextField("", text: textBinding(kind), prompt: hint)
                .focused($focusedKind, equals: kind)
                .font(.brand(13, .semibold))
                .foregroundColor(Palette.foreground)
                .autocorrectionDisabled()
                .textInputAutocapitalization(caps)
                .keyboardType(keys)
                .submitLabel(returnKey)
                .onSubmit { advance(from: kind) }
                .padding(.horizontal, 15)
                .frame(height: 46)
                .background(shape.fill(RoundPalette.fieldFill))
                .overlay(shape.strokeBorder(edge, lineWidth: 1))
                .opacity(game.lockedIn ? 0.5 : 1)
                .disabled(game.lockedIn)
                .accessibilityIdentifier("answer-field-\(kind)")
        }
    }

    /// At most 80 characters, like the browser's `maxLength`.
    private func textBinding(_ kind: String) -> Binding<String> {
        Binding<String>(
            get: { game.answer[kind] },
            set: { newValue in game.answer[kind] = String(newValue.prefix(80)) }
        )
    }

    /// Return jumps to the next empty field; on the last one it locks in when
    /// everything is filled.
    private func advance(from kind: String) {
        let kinds: [String] = game.guessKinds
        guard let index = kinds.firstIndex(of: kind) else { return }
        let later: [String] = Array(kinds.dropFirst(index + 1))
        let nextEmpty: String? = later.first(where: { k in
            game.answer[k].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        if let next = nextEmpty {
            focusedKind = next
        } else if missingKinds.isEmpty && !game.lockedIn {
            lockIn()
        } else {
            focusedKind = nil
        }
    }
}

/// "TITLE ✓": 10 pt bold, 1 pt tracking, #8d8ba4; the purple check appears as
/// soon as something is picked or typed - so you see what is still open while
/// scrolling.
private struct GuessLabel: View {
    let kind: String
    let filled: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(DisplayName.guessKind(kind).uppercased()).eyebrow()
            if filled {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Palette.accent)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(height: 15)
    }
}

/// The lock-in button: 343 wide, 15 pt bold with a check, corners 16.
/// Ready: flat --acc, white text, glow 0 0 28px --acc-deep 40 %, 51 pt high.
/// Not ready: --acc-deep 20 %, border --acc 20 %, grey text, 53 pt high (the
/// border adds to the height in the browser).
private struct LockButtonLabel: View {
    let title: String
    let ready: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.brand(15, .bold))
        .foregroundColor(ready ? Palette.onAccent : Palette.subdued)
        .frame(maxWidth: .infinity)
        .frame(height: ready ? 51 : 53)
        .background(
            shape.fill(ready ? Palette.accent : Palette.accentDeep.opacity(0.2))
                .shadow(color: ready ? Palette.accentDeep.opacity(0.4) : Color.clear, radius: 14)
        )
        .overlay(shape.strokeBorder(ready ? Color.clear : Palette.accent.opacity(0.2), lineWidth: 1))
        .animation(.easeOut(duration: 0.3), value: ready)
    }
}

/// After locking in: green panel (green 8 %, border green 30 %, corners 16)
/// with "Locked in", who is still missing, and the small "Change answer"
/// button.
private struct LockedInPanel: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                Text("Locked in")
            }
            .font(.brand(14, .bold))
            .foregroundColor(Palette.good)
            .frame(height: 21)

            Text(waitingText)
                .font(.brand(11))
                .foregroundColor(Palette.subdued)
                .frame(minHeight: 16)

            Button {
                Haptics.tap()
                game.reconsider()
            } label: {
                Text("Change answer — costs your speed bonus")
                    .font(.brand(11, .bold))
                    .foregroundColor(RoundPalette.optionText)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: 29)
                    .background(RoundedRectangle(cornerRadius: 14, style: .circular)
                        .fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(RoundPressStyle(pressedScale: 0.96))
            .accessibilityIdentifier("lock-in")
            .padding(.top, 4)
        }
        // 12 pt padding plus the 1 pt border
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(shape.fill(Palette.good.opacity(0.08)))
        .overlay(shape.strokeBorder(Palette.good.opacity(0.3), lineWidth: 1))
    }

    private var waitingText: String {
        let players: [Player] = game.player.filter { !$0.watchOnly }
        guard players.count > 1 else { return "Waiting for the round to end…" }
        let ready: Int = players.filter { $0.isReady }.count
        return "Waiting for \(players.count - ready) more…"
    }
}

/// A guess type with its choices, two per row, 6 pt apart. Both buttons of a
/// row get the height of the taller one, like a CSS grid row.
struct AnswerBlock: View {
    @EnvironmentObject private var game: Game
    let kind: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GuessLabel(kind: kind, filled: !picked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            VStack(spacing: 6) {
                ForEach(rowStarts, id: \.self) { start in
                    row(start)
                }
            }
        }
    }

    /// The server's options, as text (the year arrives as a number).
    private var options: [String] {
        (game.activeRound?.mcOptions[kind] ?? []).map { $0.text }
    }

    private var picked: String { game.answer[kind] }

    private var rowStarts: [Int] { Array(stride(from: 0, to: options.count, by: 2)) }

    private func row(_ start: Int) -> some View {
        HStack(spacing: 6) {
            cell(start)
            if start + 1 < options.count {
                cell(start + 1)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The identifier carries the position in the server's list - the
    /// end-to-end test taps answers by it (`answer-title-0`).
    private func cell(_ index: Int) -> some View {
        let all: [String] = options
        let option: String = index < all.count ? all[index] : ""
        return ChoiceButton(text: option, selected: option == picked, locked: game.lockedIn,
                            testID: "answer-\(kind)-\(index)") {
            pick(option)
        }
    }

    /// Tapping picks; tapping the picked one again keeps it (as in the
    /// browser). Locked in, nothing can be picked.
    private func pick(_ option: String) {
        guard !game.lockedIn, !option.isEmpty else { return }
        Haptics.tap()
        game.answer[kind] = option
    }
}

/// One choice: 12 pt bold, padding 12, corners 18.
/// Open: white 4 %, border white 8 %, text #b0aed2.
/// Picked: --acc-deep 28 %, border --acc 65 %, text --acc-pale, purple glow.
/// Locked in, the ones not picked fade to 45 %.
struct ChoiceButton: View {
    let text: String
    let selected: Bool
    var locked: Bool = false
    /// Accessibility identifier, set right on the button so UI tests find it.
    var testID: String = ""
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.brand(12, .semibold))
                .lineSpacing(1.2)
                .multilineTextAlignment(.leading)
                .foregroundColor(selected ? RoundPalette.pale : RoundPalette.optionText)
                // 15 pt line + 2 × 12 padding + 2 × 1 border = 41 pt for one line
                .frame(maxWidth: .infinity, minHeight: 15, maxHeight: .infinity, alignment: .leading)
                .padding(13)
                .background(ChoiceBackground(selected: selected))
                .opacity(locked && !selected ? 0.45 : 1)
                .animation(.easeOut(duration: 0.15), value: selected)
                .animation(.easeOut(duration: 0.15), value: locked)
        }
        .buttonStyle(RoundPressStyle(pressedScale: locked ? 1 : 0.96))
        .disabled(locked)
        .accessibilityIdentifier(testID)
    }
}

private struct ChoiceBackground: View {
    let selected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        let fill: Color = selected ? Palette.accentDeep.opacity(0.28) : Color.white.opacity(0.04)
        let edge: Color = selected ? Palette.accent.opacity(0.65) : Color.white.opacity(0.08)
        let shine: Color = selected ? Palette.accent.opacity(0.1) : Color.white.opacity(0.03)
        ZStack {
            if selected {
                OuterGlow(radius: 18, color: Palette.accentDeep.opacity(0.25), blur: 8)
            }
            shape.fill(fill)
            shape.strokeBorder(edge, lineWidth: 1)
            InsetTopLine(radius: 18, color: shine)
        }
    }
}

// MARK: - Reactions

/// The emoji bar at the bottom as in the browser: full width, rgba(7,7,14,.8)
/// with a hairline on top, five round buttons (40 pt, 12 pt apart). Whatever
/// you tap, everyone sees - the server sends it back to everyone as
/// `player-reacted`, including yourself, so the app shows nothing in advance.
struct ReactionBar: View {
    @EnvironmentObject private var game: Game
    @State private var previous = Date.distantPast

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Reaction.choices, id: \.self) { emoji in
                Button {
                    send(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(Circle().strokeBorder(Palette.border, lineWidth: 1))
                }
                .buttonStyle(RoundPressStyle(pressedScale: 0.85))
            }
        }
        .padding(.vertical, 12)
        .padding(.top, 1)
        .frame(maxWidth: .infinity)
        .background(RoundPalette.barFill.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    private func send(_ emoji: String) {
        // A small brake, so holding a finger on it does not flood the lobby.
        guard Date().timeIntervalSince(previous) > 0.6 else { return }
        previous = Date()
        Haptics.tap()
        game.react(emoji)
    }
}

/// The emojis someone just sent: they rise from just above the emoji bar,
/// grow, and fade (1.6 s), each with the sender's name underneath. Laid over
/// the top edge of the bar; the horizontal spot follows the browser's formula
/// (18 % + n·37 mod 64 %).
struct ReactionCloud: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(game.reactions) { r in
                    FloatingReaction(reaction: r, width: geo.size.width)
                }
            }
            .frame(width: geo.size.width, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}

private struct FloatingReaction: View {
    let reaction: Reaction
    let width: CGFloat
    @State private var risen = false
    @State private var shown = false
    @State private var faded = false

    var body: some View {
        VStack(spacing: 2) {
            Text(reaction.reaction)
                .font(.system(size: 34))
            Text(reaction.nickname)
                .font(.brand(10, .bold))
                .foregroundColor(RoundPalette.optionText)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(RoundPalette.nameTag))
        }
        .fixedSize()
        .scaleEffect(risen ? 1.3 : 0.6)
        .opacity(faded ? 0 : (shown ? 1 : 0))
        // The browser's layer sits 76 pt above the screen bottom, i.e. 11 pt
        // above the top edge of the 65 pt bar.
        .offset(x: width * leftShare, y: -11 + (risen ? rise : 10))
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) { risen = true }
            withAnimation(.linear(duration: 0.53)) { shown = true }
            withAnimation(.linear(duration: 0.53).delay(1.07)) { faded = true }
        }
    }

    /// The browser numbers its reactions; here the random bytes of the ID
    /// stand in for that number, so the spot stays put for each emoji.
    private var leftShare: CGFloat {
        let n: Int = Int(reaction.id.uuid.0)
        return CGFloat(18 + (n * 37) % 64) / 100
    }

    /// 110, 130 or 150 pt up.
    private var rise: CGFloat {
        let lane: Int = Int(reaction.id.uuid.1) % 3
        return -110 - CGFloat(lane) * 20
    }
}
