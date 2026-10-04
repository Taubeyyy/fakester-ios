import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// The lobby, rebuilt after fakester.app in phone format (375×812, October 2026):
/// header with the round back arrow and a large "Lobby", the PIN card (covered
/// until it is revealed), the pill strip, the PLAYERS grid with four columns and
/// open slots, the chat card, and at the bottom "Invite players" + "Start Game".
/// "Invite" opens a sheet with QR code and link, as in the browser.
///
/// Left out on purpose because the app cannot send them: the host's sliders
/// button in the header and "Settings" next to "Invite players" (both open the
/// settings sheet, which saves via update-lobby-settings), the kick buttons on
/// other players' tiles, and the playlist suggestion for guests.
///
/// The browser shot has no status bar and no home indicator; on an iPhone those
/// take about 84 pt. So the view measures the height it gets: below 800 pt it
/// moves everything a little closer (`LobbyDensity`), and the chat history gives
/// up height (down to 60 pt) so the message field is on screen without
/// scrolling - as in the browser at 375×812.
struct LobbyView: View {
    @EnvironmentObject private var game: Game
    @State private var pinRevealed = false
    @State private var invite = false
    /// A host with other players in the lobby has to tap twice - as in the browser.
    @State private var leaveWarned = false
    /// The tallest height seen. The keyboard only ever makes the view shorter;
    /// holding on to the maximum keeps the layout still while someone types.
    @State private var tallestHeight: CGFloat = 0
    /// Height of the scroll area without the keyboard (also the maximum seen).
    @State private var viewportHeight: CGFloat = 0
    /// Top edge of the chat card inside the scroll content.
    @State private var chatTop: CGFloat = 0

    /// Coordinate space of the scroll content, used to measure `chatTop`.
    private static let contentSpace: String = "lobbyContent"

    /// Four columns, spacing 8 - as in the browser.
    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                mainContent(LobbyDensity(height: max(geo.size.height, tallestHeight)))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear { rememberHeight(geo.size.height) }
                    .onChange(of: geo.size.height) { latest in rememberHeight(latest) }
            }
            .blur(radius: invite ? 3 : 0)

            if invite {
                LobbyPalette.scrim
                    .ignoresSafeArea()
                    .onTapGesture { closeInvite() }
                    .transition(.opacity)
                    .zIndex(1)
                InviteSheet(pin: game.pin, guest: iAmGuest, close: { closeInvite() })
                    .transition(sheetTransition)
                    .zIndex(2)
            }
        }
    }

    private func mainContent(_ d: LobbyDensity) -> some View {
        VStack(spacing: 0) {
            LobbyHeaderBar(verticalPadding: d.headerPadding, goBack: { goBack() })

            ScrollView(showsIndicators: false) {
                scrollContent(d)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { rememberViewport(g.size.height) }
                        .onChange(of: g.size.height) { latest in rememberViewport(latest) }
                }
            )

            footerBar(d)
        }
    }

    private func scrollContent(_ d: LobbyDensity) -> some View {
        VStack(alignment: .leading, spacing: d.sectionSpacing) {
            PinCard(pin: game.pin, isOpen: $pinRevealed, invite: { openInvite() }, compact: d.compact)
            if let e = game.lobbySettings {
                Chips(lobbySettings: e, playMode: game.playMode, compact: d.compact)
            }
            playersBlock(d)
            LobbyChatCard(fitHeight: chatFitHeight(d))
                .background(GeometryReader { g in chatTopReader(g) })
        }
        .padding(.horizontal, 16)
        .padding(.vertical, d.contentPadding)
        .coordinateSpace(name: LobbyView.contentSpace)
    }

    private var iAmGuest: Bool {
        let me: Player? = game.player.first(where: { $0.id.text == game.ownId })
        return me?.isGuest ?? true
    }

    /// As in the browser: the sheet fades in, rising 18 pt and growing from 96 %.
    private var sheetTransition: AnyTransition {
        AnyTransition.opacity
            .combined(with: AnyTransition.offset(x: 0, y: 18))
            .combined(with: AnyTransition.scale(scale: 0.96, anchor: .bottom))
    }

    // MARK: Fitting the screen

    private func rememberHeight(_ h: CGFloat) {
        if h > tallestHeight { tallestHeight = h }
    }

    private func rememberViewport(_ h: CGFloat) {
        if h > viewportHeight { viewportHeight = h }
    }

    private func chatTopReader(_ g: GeometryProxy) -> some View {
        let top: CGFloat = g.frame(in: CoordinateSpace.named(LobbyView.contentSpace)).minY
        return Color.clear
            .onAppear { chatTop = top }
            .onChange(of: top) { latest in chatTop = latest }
    }

    /// How tall the chat history may get so the whole chat card, message field
    /// included, plus the bottom padding ends exactly at the footer - nothing
    /// left to scroll. nil until both values are measured.
    private func chatFitHeight(_ d: LobbyDensity) -> CGFloat? {
        guard viewportHeight > 0, chatTop > 0 else { return nil }
        return viewportHeight - chatTop - LobbyChatCard.chrome - d.contentPadding
    }

    // MARK: Back

    /// As in the browser: if you are the host and others are already here,
    /// leaving closes the lobby for everyone - so warn first, leave on the
    /// second tap.
    private func goBack() {
        if game.iAmHost && game.player.count > 1 && !leaveWarned {
            leaveWarned = true
            Haptics.tap()
            game.notice = "Leaving closes the lobby — tap back again"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                leaveWarned = false
            }
            return
        }
        game.leave()
    }

    // MARK: Players

    /// "PLAYERS (n)" above the grid (mb-3 = 12, compact 10).
    private func playersBlock(_ d: LobbyDensity) -> some View {
        VStack(alignment: .leading, spacing: d.playersSpacing) {
            playersHeader
            playersGrid
        }
    }

    /// Thin purple bar 2×16, people icon 12, 11 pt bold with letter spacing,
    /// spaced 8 apart (text starts at x 46 as in the browser).
    private var playersHeader: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(LinearGradient(colors: [Palette.accentDeep, Palette.accentDeep.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 2, height: 16)
            Image(systemName: "person.2")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Palette.subdued)
                .frame(width: 12, height: 12)
            Text("PLAYERS (\(game.player.count))")
                .font(.brand(11, .bold))
                .tracking(1.1)
                .foregroundColor(Palette.subdued)
                .lineLimit(1)
        }
        .frame(height: 17)
    }

    private var playersGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(Array(game.player.enumerated()), id: \.element.id) { ordinal, s in
                PlayerTile(player: s,
                           isHost: s.id.text == game.hostId,
                           isMe: s.id.text == game.ownId,
                           frameHeight: rowHeight(ordinal))
            }
            ForEach(0..<openSlots, id: \.self) { i in
                Button {
                    openInvite()
                } label: {
                    OpenSlot(numeral: i, frameHeight: rowHeight(game.player.count + i))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The browser only fills the first row with open slots
    /// (max(0, 4 - players)). Once more people join there are no gaps.
    private var openSlots: Int {
        max(0, 4 - game.player.count)
    }

    /// In the CSS grid every tile is as tall as the tallest one in its row.
    private func rowHeight(_ index: Int) -> CGFloat {
        let slotCount: Int = game.player.count + openSlots
        let start: Int = (index / 4) * 4
        let end: Int = min(start + 4, slotCount)
        var frameHeight: CGFloat = 0
        var i: Int = start
        while i < end {
            if i < game.player.count {
                let s: Player = game.player[i]
                frameHeight = max(frameHeight, PlayerTile.frameHeight(player: s, isHost: s.id.text == game.hostId))
            } else {
                frameHeight = max(frameHeight, OpenSlot.frameHeight)
            }
            i += 1
        }
        return frameHeight
    }

    // MARK: Footer

    /// rgba(7,7,14,.95) with a line on top, padding 12/16, spacing 8.
    /// No "Settings" next to "Invite players": see the type comment.
    private func footerBar(_ d: LobbyDensity) -> some View {
        VStack(spacing: 8) {
            inviteButton
            if game.iAmHost {
                startButton
            } else {
                waitingRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, d.footerTop)
        .padding(.bottom, d.footerBottom)
        .background(LobbyPalette.footer.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    /// "Invite players": 42 tall, outline only, user-plus 13, 13 pt bold.
    private var inviteButton: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return Button {
            openInvite()
        } label: {
            HStack(spacing: 6) {
                LobbyUserPlusIcon(size: 13)
                Text("Invite players")
                    .font(.brand(13, .bold))
                    .lineLimit(1)
            }
            .foregroundColor(Palette.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(LobbyPressStyle())
    }

    /// The label must stay "Start Game" - the UI test taps it by that name
    /// (the icon is hidden from accessibility so it cannot add to the label).
    private var startButton: some View {
        Button {
            Haptics.lock()
            game.startGame()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .accessibilityHidden(true)
                Text("Start Game")
                    .lineLimit(1)
            }
        }
        .buttonStyle(LobbyStartStyle())
    }

    /// Shown to other players instead of the start button: clock 14,
    /// 14 pt bold, #8d8ba4 on white 2 % with an outline.
    private var waitingRow: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 14, height: 14)
            Text("Waiting for the host to start…")
                .font(.brand(14, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(Palette.subdued)
        .frame(maxWidth: .infinity)
        .frame(height: 51)
        .background(shape.fill(Color.white.opacity(0.02)))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    // MARK: Invite

    private func openInvite() {
        Haptics.tap()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            invite = true
        }
    }

    private func closeInvite() {
        withAnimation(.easeOut(duration: 0.2)) {
            invite = false
        }
    }
}

// MARK: - Density

/// The lobby's spacing by available height. Not compact = the browser's values
/// (375×812 without a status bar). Below 800 pt - every iPhone except the
/// Plus/Max models, because status bar and home indicator eat into the height -
/// everything moves a little closer so the chat's message field fits on screen.
private struct LobbyDensity {
    let compact: Bool

    init(height: CGFloat) {
        compact = height > 0 && height < 800
    }

    /// Header: py-3.5 (14).
    var headerPadding: CGFloat { compact ? 8 : 14 }
    /// Scroll content: pt-4 / pb-4 (16).
    var contentPadding: CGFloat { compact ? 12 : 16 }
    /// Between the cards: gap-4 (16).
    var sectionSpacing: CGFloat { compact ? 12 : 16 }
    /// "PLAYERS" label to grid: mb-3 (12).
    var playersSpacing: CGFloat { compact ? 10 : 12 }
    /// Footer: py-3 (12). Compact keeps less at the bottom, where the home
    /// indicator area adds its own space.
    var footerTop: CGFloat { compact ? 10 : 12 }
    var footerBottom: CGFloat { compact ? 8 : 12 }
}

// MARK: - Header

/// The header as in the browser: rgba(7,7,14,.82), line at the bottom, padding
/// 14/16. Round back button 36 (white 4 %, edge 7 %, purple arrow 15) and
/// "Lobby" 25 pt extra bold, set tight.
private struct LobbyHeaderBar: View {
    var verticalPadding: CGFloat = 14
    let goBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: goBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Palette.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                        .overlay(Circle().strokeBorder(Palette.border, lineWidth: 1))
                        .overlay(EdgeHighlight(radius: 18, intensity: 0.05))
                        .contentShape(Circle())
                }
                .buttonStyle(LobbyPressStyle(pressed: 0.92))
                .accessibilityLabel(Text("Back"))

                Text("Lobby")
                    .font(.brand(25, .heavy))
                    .tracking(-0.625)
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPadding)

            Rectangle().fill(Palette.border).frame(height: 1)
        }
        .background(LobbyPalette.header.ignoresSafeArea(edges: .top))
    }
}

// MARK: - PIN

/// The PIN card: boxes 46×52, covered with "•" until revealed - the PIN often
/// sits on a screen that more people can see than should play. Below it
/// "Reveal", "Copy" and the purple "Invite".
struct PinCard: View {
    let pin: String
    @Binding var isOpen: Bool
    var invite: () -> Void = {}
    /// Tighter padding on shorter phones (see `LobbyDensity`).
    var compact: Bool = false
    @State private var copied = false
    @State private var bounce = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            header
            digitBoxRow
            buttonRow
        }
        .padding(compact ? 14 : 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(base)
    }

    /// rgba(24,23,39,.92), purple edge 25 %, shadow 0 4 24 black 30 % and a
    /// purple glow 0 0 40.
    private var base: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return ZStack {
            shape.fill(Palette.card)
            shape.strokeBorder(Palette.accent.opacity(0.25), lineWidth: 1)
            EdgeHighlight(radius: 16, intensity: 0.05)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
        .shadow(color: Palette.accentDeep.opacity(0.08), radius: 20, x: 0, y: 0)
    }

    /// "# GAME PIN": hash 11, 6 apart, 10 pt bold with letter spacing.
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 11, height: 11)
            Text("GAME PIN")
                .font(.brand(10, .bold))
                .tracking(1)
                .lineLimit(1)
        }
        .foregroundColor(Palette.accent)
        .frame(height: 15)
    }

    private var digitBoxRow: some View {
        Button {
            flip()
        } label: {
            HStack(spacing: 8) {
                ForEach(Array(chars.enumerated()), id: \.offset) { ordinal, c in
                    digitBox(c, ordinal)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var buttonRow: some View {
        HStack(spacing: 8) {
            smallButton(isOpen ? "Hide" : "Reveal",
                        isOpen ? "eye.slash" : "eye", greenTone: false) {
                flip()
            }
            if !pin.isEmpty {
                smallButton(copied ? "Copied" : "Copy",
                            copied ? "checkmark" : "square.on.square", greenTone: copied) {
                    copyToClipboard()
                }
            }
            Button(action: invite) {
                HStack(spacing: 6) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 12, height: 12)
                    Text("Invite")
                        .font(.brand(11, .bold))
                        .lineLimit(1)
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 17)
                .frame(height: 35)
                .background(Capsule().fill(Palette.accent))
            }
            .buttonStyle(LobbyPressStyle())
            Spacer(minLength: 0)
        }
    }

    /// The server hands out four digits; should that ever grow, boxes are
    /// added instead of cutting the PIN off.
    private var chars: [Character] {
        Array(pin.isEmpty ? "----" : pin)
    }

    /// 22 pt extra bold on purple 7 %. Covered: edge white 9 %; revealed: edge
    /// purple 45 % with a glow 0 0 14 purple 18 %.
    private func digitBox(_ c: Character, _ ordinal: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        let outline: Color = isOpen ? Palette.accent.opacity(0.45) : Color.white.opacity(0.09)
        let glow: Color = isOpen ? Palette.accent.opacity(0.18) : Color.clear
        let staggerDelay: Double = Double(ordinal) * 0.05
        return digitFace(c)
            .foregroundColor(Palette.foreground)
            .frame(width: 46, height: 52)
            .background(shape.fill(Palette.accent.opacity(0.07)).shadow(color: glow, radius: 7))
            .overlay(shape.strokeBorder(outline, lineWidth: 1))
            .scaleEffect(bounce ? 1.1 : 1)
            .animation(.easeOut(duration: 0.125).delay(staggerDelay), value: bounce)
    }

    /// The digit, or while covered a dot of about 6.5 pt - the size the
    /// browser's "•" at 22 px comes out at (Helvetica's bullet is smaller).
    @ViewBuilder
    private func digitFace(_ c: Character) -> some View {
        if isOpen {
            Text(String(c))
                .font(.brand(22, .heavy))
        } else {
            Circle()
                .frame(width: 6.5, height: 6.5)
        }
    }

    /// "Reveal" / "Copy": 35 tall, white 4 % with edge 8 %, text #b0aed2
    /// 11 pt bold, icon 12. "Copied" briefly turns green.
    private func smallButton(_ text: String, _ symbol: String, greenTone: Bool,
                             _ onTap: @escaping () -> Void) -> some View {
        let foreground: Color = greenTone ? Palette.good : LobbyPalette.buttonTextColor
        let base: Color = greenTone ? Palette.good.opacity(0.12) : Color.white.opacity(0.04)
        let outline: Color = greenTone ? Palette.good.opacity(0.3) : Color.white.opacity(0.08)
        return Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 12, height: 12)
                Text(text)
                    .font(.brand(11, .bold))
                    .lineLimit(1)
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 13)
            .frame(height: 35)
            .background(Capsule().fill(base))
            .overlay(Capsule().strokeBorder(outline, lineWidth: 1))
        }
        .buttonStyle(LobbyPressStyle())
    }

    private func flip() {
        Haptics.tap()
        let revealing: Bool = !isOpen
        withAnimation(.easeOut(duration: 0.2)) {
            isOpen = revealing
        }
        guard revealing else { return }
        // the boxes bounce briefly one after another, as in the browser
        bounce = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 125_000_000)
            bounce = false
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = pin
        Haptics.correct()
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            copied = false
        }
    }
}

// MARK: - Pills

/// The settings as pills in their own strip: rgba(24,23,39,.9), edge 7 %,
/// padding 10/12, scrolls sideways. The playlist in purple (at most 45 % wide),
/// then ♪ songs, ⏱ time, ? mode - and Sneaky/Speaker when they are on.
struct Chips: View {
    let lobbySettings: LobbySettings
    let playMode: String
    /// Less vertical padding on shorter phones (see `LobbyDensity`).
    var compact: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                playlistPill
                pill("music.note", "\(lobbySettings.songCount)")
                pill("clock", "\(lobbySettings.guessTime)s")
                pill("questionmark.circle", displayMode)
                if lobbySettings.sneakyMode {
                    pill("shield", "Sneaky")
                }
                if lobbySettings.boxMode {
                    pill("speaker.wave.2", "Speaker")
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, compact ? 8 : 11)
        }
        .background(shape.fill(LobbyPalette.stripFill))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
        .clipShape(shape)
    }

    /// 27 tall: icon 10, 6 apart, padding 10 + edge.
    private var playlistPill: some View {
        let name: String = (lobbySettings.playlistName ?? "").isEmpty ? "Playlist" : (lobbySettings.playlistName ?? "")
        return HStack(spacing: 6) {
            Image(systemName: "record.circle")
                .font(.system(size: 9, weight: .medium))
                .frame(width: 10, height: 10)
            LobbyWidthCap(span: 105) {
                Text(name)
                    .font(.brand(11, .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .foregroundColor(Palette.accent)
        .padding(.horizontal, 11)
        .frame(height: 27)
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
    }

    /// 27 tall: icon 10, 4 apart, padding 8 + edge.
    private func pill(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .medium))
                .frame(width: 10, height: 10)
            Text(text)
                .font(.brand(11, .bold))
                .lineLimit(1)
        }
        .foregroundColor(Palette.foreground)
        .padding(.horizontal, 9)
        .frame(height: 27)
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
        .fixedSize()
    }

    /// The names as in the browser; anything it does not know is called "Quiz" there.
    private var displayMode: String {
        switch playMode {
        case "timeline":          return "Timeline"
        case "higherlower", "hl": return "Higher / Lower"
        case "reverse":           return "Reverse"
        default:                  return "Quiz"
        }
    }
}

/// Gives the content at most `span` of width - even inside a horizontal
/// ScrollView, where any text would otherwise get unlimited width
/// (max-w-[45%] truncate).
private struct LobbyWidthCap: Layout {
    let span: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return CGSize.zero }
        let w: CGFloat = min(proposal.width ?? span, span)
        return child.sizeThatFits(ProposedViewSize(width: w, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        child.place(at: CGPoint(x: bounds.minX, y: bounds.midY),
                    anchor: .leading,
                    proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

// MARK: - Open slot

/// An open slot in the grid: dashed edge white 10 %, fill white 1.5 %, pulses
/// gently (50-75 %), and a ring runs outward around the icon.
/// Tapping it opens the invite sheet.
struct OpenSlot: View {
    var numeral: Int = 0
    var frameHeight: CGFloat = 0
    @State private var pulsing = false

    /// 11 + 40 + 6 + 3 × 15 + 11 - as in the browser.
    static let frameHeight: CGFloat = 113

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let staggerDelay: Double = Double(numeral) * 0.6
        return VStack(spacing: 6) {
            symbol
            VStack(spacing: 0) {
                Text("OPEN")
                    .font(.brand(10, .bold))
                    .frame(height: 15)
                Text("SLOT")
                    .font(.brand(10, .bold))
                    .frame(height: 15)
                Text("Invite…")
                    .font(.brand(10))
                    .frame(height: 15)
            }
            .foregroundColor(Palette.subdued)
            .lineLimit(1)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: frameHeight, alignment: .top)
        .background(shape.fill(Color.white.opacity(0.015)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        .contentShape(shape)
        .opacity(pulsing ? 0.75 : 0.5)
        .animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true).delay(staggerDelay), value: pulsing)
        .onAppear { pulsing = true }
    }

    /// Circle 40 (white 4 %) with user-plus 14, behind it a ring that grows to
    /// twice the size while fading out (animate-ping, 2.4 s).
    private var symbol: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .scaleEffect(pulsing ? 2 : 1)
                .opacity(pulsing ? 0 : 1)
                .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false), value: pulsing)
            Circle()
                .fill(Color.white.opacity(0.04))
            LobbyUserPlusIcon(size: 14)
                .foregroundColor(Palette.subdued)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Chat

/// The chat card "((•)) LOBBY": header with a line, history (120-200 tall,
/// grows with the messages), and at the bottom the input and a round purple
/// send button 36. On shorter phones the history gives up height so the input
/// stays on screen (`fitHeight`).
private struct LobbyChatCard: View {
    @EnvironmentObject private var game: Game
    /// How tall the history may be so the card fits above the footer.
    /// nil = not measured yet, use the browser's height.
    var fitHeight: CGFloat? = nil
    @State private var messageText: String = ""
    @State private var contentHeight: CGFloat = 0
    /// As in the browser: at most 5 messages in 4 seconds.
    @State private var sentTimes: [Date] = []

    /// Everything but the history: edge 1 + header 37 + line 1 + line 1 +
    /// input row 56 + edge 1.
    static let chrome: CGFloat = 97
    /// The history never gets shorter than this: the "joined" line and one message.
    static let minimumHistory: CGFloat = 60

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return VStack(spacing: 0) {
            header
            Rectangle().fill(Palette.border).frame(height: 1)
            if game.chat.isEmpty {
                emptyState
            } else {
                history
            }
            Rectangle().fill(Palette.border).frame(height: 1)
            input
        }
        .padding(1)
        .background(shape.fill(Palette.card))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    /// px-4 py-2.5: radio icon 12, 8 apart, 11 pt bold with letter spacing.
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 9, weight: .medium))
                .frame(width: 12, height: 12)
            Text("LOBBY")
                .font(.brand(11, .bold))
                .tracking(1.1)
            Spacer(minLength: 0)
        }
        .foregroundColor(Palette.subdued)
        .frame(height: 17)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LobbyPalette.emptyIcon)
            Text("Waiting for players…")
                .font(.brand(11))
                .foregroundColor(Palette.subdued)
        }
        .frame(maxWidth: .infinity)
        .frame(height: fitted(120))
    }

    /// The browser's height (min 120, max 200), limited by `fitHeight`.
    private func fitted(_ natural: CGFloat) -> CGFloat {
        guard let fit = fitHeight else { return natural }
        return min(natural, max(fit, LobbyChatCard.minimumHistory))
    }

    private var visibleHeight: CGFloat {
        fitted(min(max(contentHeight, 120), 200))
    }

    private var history: some View {
        ScrollViewReader { scroller in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(game.chat) { z in
                        row(z).id(z.id)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { contentHeight = g.size.height }
                            .onChange(of: g.size.height) { latest in contentHeight = latest }
                    }
                )
            }
            .frame(height: visibleHeight)
            .onAppear {
                scrollToNewest(scroller, animated: false)
            }
            .onChange(of: game.chat.count) { _ in
                scrollToNewest(scroller, animated: true)
            }
            .onChange(of: visibleHeight) { _ in
                // the history got shorter (screen fitting) - keep the newest line in view
                scrollToNewest(scroller, animated: false)
            }
        }
    }

    private func scrollToNewest(_ scroller: ScrollViewProxy, animated: Bool) {
        guard let newest = game.chat.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                scroller.scrollTo(newest.id, anchor: .bottom)
            }
        } else {
            scroller.scrollTo(newest.id, anchor: .bottom)
        }
    }

    @ViewBuilder
    private func row(_ z: ChatLine) -> some View {
        if z.system {
            // System lines: sliders icon 10, 6 apart, 11 pt, #8d8ba4. The browser
            // drops the server's `kind`, so every system line looks like this.
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 10, height: 10)
                Text(z.text)
                    .font(.brand(11))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(Palette.subdued)
        } else {
            // Picture 20, "Name:" 12 pt bold purple, text 12 pt, 8 apart
            HStack(alignment: .top, spacing: 8) {
                LobbyAvatar(player: sender(z), name: z.nickname, dimension: 20)
                Text(z.nickname + ":")
                    .font(.brand(12, .bold))
                    .foregroundColor(Palette.accent)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minHeight: 18)
                Text(z.text)
                    .font(.brand(12))
                    .foregroundColor(Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 18)
                Spacer(minLength: 0)
            }
        }
    }

    private func sender(_ z: ChatLine) -> Player? {
        game.player.first(where: { $0.nickname == z.nickname })
    }

    /// p-2.5: field 36 tall (13 pt, px-2), send button 36 with a 14 icon.
    private var input: some View {
        HStack(spacing: 8) {
            TextField("", text: $messageText,
                      prompt: Text("Message...").foregroundColor(Palette.faint))
                .font(.brand(13))
                .foregroundColor(Palette.foreground)
                .submitLabel(.send)
                .onSubmit { transmit() }
                .padding(.horizontal, 8)
                .frame(height: 36)
                .onChange(of: messageText) { latest in
                    if latest.count > 200 {
                        messageText = String(latest.prefix(200))
                    }
                }
            Button {
                transmit()
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Palette.accent))
            }
            .buttonStyle(LobbyPressStyle(pressed: 0.92))
        }
        .padding(10)
    }

    private func transmit() {
        let cleaned: String = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let nowDate: Date = Date()
        let recent: [Date] = sentTimes.filter { nowDate.timeIntervalSince($0) < 4 }
        if recent.count >= 5 {
            sentTimes = recent
            game.notice = "Slow down a moment"
            return
        }
        sentTimes = recent + [nowDate]
        Haptics.tap()
        game.sendChat(cleaned)
        messageText = ""
    }
}

// MARK: - Invite

/// The "Invite players" sheet as in the browser: from the bottom, top corners
/// 24, rgba(24,23,39,.98), purple edge 32 %. QR code with the link to the
/// lobby, and the link to copy (and to share, as Safari offers on the iPhone).
/// The friends list needs a server call the app does not make - so guests only
/// see the note the browser shows them as well.
private struct InviteSheet: View {
    let pin: String
    let guest: Bool
    let close: () -> Void
    @State private var copied = false
    @State private var qr: UIImage? = nil

    private var link: String {
        "https://fakester.app/?pin=" + pin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 12) {
                scanCard
                linkRow
                if guest {
                    friends
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 1)
        .padding(.top, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(base)
        .onAppear {
            if qr == nil {
                qr = QRCodeImage.render(link)
            }
        }
    }

    /// The shape runs past the bottom edge - that way only the top corners
    /// stay round (UnevenRoundedRectangle only exists from iOS 17).
    private var base: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return ZStack {
            shape.fill(LobbyPalette.panel)
            shape.strokeBorder(Palette.accent.opacity(0.32), lineWidth: 1)
        }
        .padding(.bottom, -60)
        .ignoresSafeArea(edges: .bottom)
    }

    /// Icon circle 32 (purple 15 %, user-plus 15), "PIN 1234" 10 pt and
    /// "Invite players" 18 pt extra bold, close button 28 at the top right.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                LobbyUserPlusIcon(size: 15)
                    .foregroundColor(Palette.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 0) {
                    Text("PIN " + pin)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Palette.accent)
                        .lineLimit(1)
                    Text("Invite players")
                        .font(.brand(18, .heavy))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.subdued)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .contentShape(Circle())
            }
            .buttonStyle(LobbyPressStyle(pressed: 0.92))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// QR code (92, white tile with padding 8, corners 18) and next to it
    /// "Scan to join" with an explanation.
    private var scanCard: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 12) {
            qrTile
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan to join")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Palette.foreground)
                Text("Opens fakester.app and drops them straight into this lobby — no PIN to type.")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subdued)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(shape.fill(Color.white.opacity(0.03)))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    @ViewBuilder
    private var qrImage: some View {
        if let picture = qr {
            Image(uiImage: picture)
                .interpolation(.none)
                .resizable()
                .frame(width: 92, height: 92)
        } else {
            Color.clear
                .frame(width: 92, height: 92)
        }
    }

    private var qrTile: some View {
        qrImage
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Color.white))
    }

    /// Link field 40 tall (#b0aed2 12 pt on rgba(10,9,20,.6)), the purple
    /// "Copy" (icon 13, padding 12) and the share button.
    private var linkRow: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return HStack(spacing: 8) {
            Text(link)
                .font(.system(size: 12))
                .foregroundColor(LobbyPalette.buttonTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40)
                .background(shape.fill(LobbyPalette.field))
                .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))

            Button {
                copyToClipboard()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: copied ? "checkmark" : "square.on.square")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 13, height: 13)
                    Text(copied ? "Copied" : "Copy")
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(shape.fill(Palette.accent))
            }
            .buttonStyle(LobbyPressStyle())

            shareButton
        }
    }

    /// Safari on the iPhone can share (navigator.share) - the browser then shows
    /// this button next to "Copy" (40 wide, icon 14).
    @ViewBuilder
    private var shareButton: some View {
        if let url = URL(string: link) {
            let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
            ShareLink(item: url, message: Text("Join my lobby — PIN " + pin)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.foreground)
                    .frame(width: 40, height: 40)
                    .background(shape.fill(Color.white.opacity(0.04)))
                    .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(LobbyPressStyle())
        }
    }

    private var friends: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 11, height: 11)
                Text("YOUR FRIENDS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .lineLimit(1)
            }
            .foregroundColor(Palette.subdued)
            .padding(.top, 4)

            Text("No friends added yet — add someone on the Friends screen, or just send them the link above.")
                .font(.system(size: 11))
                .foregroundColor(Palette.subdued)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = link
        Haptics.correct()
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            copied = false
        }
    }
}

/// The QR code as in the browser (error correction M, #15151f on white, no
/// quiet zone of its own - the white padding around it provides that).
private enum QRCodeImage {
    static func render(_ text: String) -> UIImage? {
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(text.utf8)
        generator.correctionLevel = "M"
        guard let raw = generator.outputImage else { return nil }

        let colorize = CIFilter.falseColor()
        colorize.inputImage = raw
        colorize.color0 = CIColor(red: 0x15 / 255.0, green: 0x15 / 255.0, blue: 0x1F / 255.0)
        colorize.color1 = CIColor(red: 1, green: 1, blue: 1)
        guard let colored = colorize.outputImage else { return nil }

        let ciContext = CIContext(options: nil)
        guard let full = ciContext.createCGImage(colored, from: colored.extent) else { return nil }
        let outline: Int = quietZone(full)
        if outline > 0 {
            let cropRect = CGRect(x: outline, y: outline, width: full.width - 2 * outline, height: full.height - 2 * outline)
            if let cropped = full.cropping(to: cropRect) {
                return UIImage(cgImage: cropped)
            }
        }
        return UIImage(cgImage: full)
    }

    /// How wide the white border is that CoreImage adds: the first dark pixel
    /// is the top left corner of the finder pattern.
    private static func quietZone(_ picture: CGImage) -> Int {
        let b: Int = picture.width
        let h: Int = picture.height
        guard b > 0, h > 0,
              let ctx = CGContext(data: nil, width: b, height: h, bitsPerComponent: 8, bytesPerRow: b,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return 0 }
        ctx.draw(picture, in: CGRect(x: 0, y: 0, width: b, height: h))
        guard let bytes = ctx.data else { return 0 }
        let row: Int = ctx.bytesPerRow
        let pixels: UnsafeMutablePointer<UInt8> = bytes.bindMemory(to: UInt8.self, capacity: row * h)
        for y in 0..<h {
            for x in 0..<b where pixels[y * row + x] < 128 {
                return (x == y && x <= 8) ? x : 0
            }
        }
        return 0
    }
}

// MARK: - Building blocks for the lobby only

/// lucide "user-plus" as the browser draws it (24-unit grid, 2-unit stroke,
/// round caps and joins). SF Symbols only has person.badge.plus, whose plus
/// sits in a badge at the bottom - a visibly different icon. Takes the
/// foreground color; decorative, so hidden from VoiceOver.
private struct LobbyUserPlusIcon: View {
    let size: CGFloat

    var body: some View {
        LobbyUserPlusShape()
            .stroke(style: StrokeStyle(lineWidth: size / 12, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The paths of lucide "user-plus": head circle (9, 7, r 4), shoulders
/// M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2, and the plus at (19, 11).
private struct LobbyUserPlusShape: Shape {
    func path(in rect: CGRect) -> Path {
        let unit: CGFloat = min(rect.width, rect.height) / 24
        let originX: CGFloat = rect.minX + (rect.width - 24 * unit) / 2
        let originY: CGFloat = rect.minY + (rect.height - 24 * unit) / 2
        // control point distance for a quarter circle of radius 4
        let k: CGFloat = 4 * 0.5523

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * unit, y: originY + y * unit)
        }

        var p = Path()
        p.addEllipse(in: CGRect(x: originX + 5 * unit, y: originY + 3 * unit, width: 8 * unit, height: 8 * unit))

        p.move(to: pt(16, 21))
        p.addLine(to: pt(16, 19))
        p.addCurve(to: pt(12, 15), control1: pt(16, 19 - k), control2: pt(12 + k, 15))
        p.addLine(to: pt(6, 15))
        p.addCurve(to: pt(2, 19), control1: pt(6 - k, 15), control2: pt(2, 19 - k))
        p.addLine(to: pt(2, 21))

        p.move(to: pt(19, 8))
        p.addLine(to: pt(19, 14))
        p.move(to: pt(22, 11))
        p.addLine(to: pt(16, 11))
        return p
    }
}

/// A light press like whileTap: { scale: .97 } in the browser.
private struct LobbyPressStyle: ButtonStyle {
    var pressed: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressed : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Start Game" as in the browser: 51 tall, corners 16, flat purple, white
/// 15 pt bold, glow 0 0 28 rgba(112,0,215,.4) without offset.
private struct LobbyStartStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return configuration.label
            .font(.brand(15, .bold))
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 51)
            .background(shape.fill(Palette.accent))
            .shadow(color: Palette.accentDeep.opacity(0.4), radius: 14, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Colors that only appear in the lobby (from the browser measurements).
private enum LobbyPalette {
    /// Header: rgba(7,7,14,.82)
    static let header = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.82)
    /// Footer: rgba(7,7,14,.95)
    static let footer = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.95)
    /// Pill strip: rgba(24,23,39,.9)
    static let stripFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    /// Sheet: rgba(24,23,39,.98)
    static let panel = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)
    /// Behind the sheet: rgba(4,4,10,.72)
    static let scrim = Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.72)
    /// Link field: rgba(10,9,20,.6)
    static let field = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)
    /// "Reveal", "Copy", the link: #b0aed2
    static let buttonTextColor = Color(hex: 0xB0AED2)
    /// The faint radio icon in the empty chat: #2a2848
    static let emptyIcon = Color(hex: 0x2A2848)
}
