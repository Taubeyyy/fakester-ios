import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Die Lobby, nachgebaut nach fakester.app im Handyformat (375×812, Oktober 2026):
/// Kopf mit rundem Zurueck-Pfeil und grossem „Lobby", die PIN-Karte (zugedeckt,
/// bis man sie aufdeckt), die Pillen-Reihe, das PLAYERS-Raster mit vier Spalten
/// und freien Plaetzen, die Chat-Karte und unten „Invite players" + „Start Game".
/// „Invite" oeffnet wie im Browser ein Blatt mit QR-Code und Link.
struct LobbyView: View {
    @EnvironmentObject private var game: Game
    @State private var pinRevealed = false
    @State private var invite = false
    /// Gastgeber mit Mitspielern muss zweimal tippen - wie im Browser.
    @State private var leaveWarned = false

    /// Vier Spalten, Abstand 8 - wie im Browser.
    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
                .blur(radius: invite ? 3 : 0)

            if invite {
                LobbyPalette.scrim
                    .ignoresSafeArea()
                    .onTapGesture { closeInvite() }
                    .transition(.opacity)
                    .zIndex(1)
                InviteSheet(pin: game.pin, guest: iAmGuest, close: { closeInvite() })
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            LobbyHeaderBar(goBack: { goBack() })

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    PinCard(pin: game.pin, isOpen: $pinRevealed, invite: { openInvite() })
                    if let e = game.lobbySettings {
                        Chips(lobbySettings: e, playMode: game.playMode)
                    }
                    playersBlock
                    LobbyChatCard()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)

            footerBar
        }
    }

    private var iAmGuest: Bool {
        let me: Player? = game.player.first(where: { $0.id.text == game.ownId })
        return me?.isGuest ?? true
    }

    // MARK: Zurueck

    /// Wie im Browser: Ist man Gastgeber und sind schon andere da, schliesst
    /// Gehen die Lobby fuer alle - also erst warnen, beim zweiten Tippen gehen.
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

    // MARK: Spieler

    /// "PLAYERS (n)": duenner lila Strich, Personen-Symbol, 11 pt fett gesperrt.
    private var playersBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(LinearGradient(colors: [Palette.accentDeep, Palette.accentDeep.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 2, height: 16)
                Image(systemName: "person.2")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Palette.subdued)
                Text("PLAYERS (\(game.player.count))")
                    .font(.brand(11, .bold))
                    .tracking(1.1)
                    .foregroundColor(Palette.subdued)
                    .lineLimit(1)
            }
            .frame(height: 17)

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
    }

    /// Der Browser fuellt nur die erste Reihe mit freien Plaetzen auf
    /// (max(0, 4 - Spieler)). Kommen mehr Leute, gibt es keine Luecken.
    private var openSlots: Int {
        max(0, 4 - game.player.count)
    }

    /// Im CSS-Grid ist jede Kachel so hoch wie die hoechste ihrer Reihe.
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

    // MARK: Unten

    /// rgba(7,7,14,.95) mit Strich oben, Polster 12/16, Abstand 8.
    private var footerBar: some View {
        VStack(spacing: 8) {
            inviteButton
            if game.iAmHost {
                startButton
            } else {
                waitingRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LobbyPalette.footer.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    /// "Invite players": 42 hoch, nur Rand, 13 pt fett.
    private var inviteButton: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return Button {
            openInvite()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 12, weight: .medium))
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

    private var startButton: some View {
        Button {
            Haptics.lock()
            game.startGame()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                Text("Start Game")
                    .lineLimit(1)
            }
        }
        .buttonStyle(LobbyStartStyle())
    }

    /// Fuer Mitspieler statt des Startknopfs.
    private var waitingRow: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))
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

    // MARK: Einladen

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

// MARK: - Kopf

/// Der Kopf wie im Browser: rgba(7,7,14,.82), Strich unten, Polster 14/16.
/// Runder Zurueck-Knopf 36 (weiss 4 %, Kante 7 %, lila Pfeil 15) und
/// "Lobby" 25 pt sehr fett, eng gesetzt.
private struct LobbyHeaderBar: View {
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

                Text("Lobby")
                    .font(.brand(25, .heavy))
                    .tracking(-0.625)
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle().fill(Palette.border).frame(height: 1)
        }
        .background(LobbyPalette.header.ignoresSafeArea(edges: .top))
    }
}

// MARK: - PIN

/// Die PIN-Karte: Kaestchen 46×52, zugedeckt mit "•", bis man sie aufdeckt -
/// die PIN haengt oft an einem Bildschirm, den mehr Leute sehen als mitspielen
/// sollen. Darunter "Reveal", "Copy" und das lila "Invite".
struct PinCard: View {
    let pin: String
    @Binding var isOpen: Bool
    var invite: () -> Void = {}
    @State private var copied = false
    @State private var bounce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            digitBoxRow
            buttonRow
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(base)
    }

    /// rgba(24,23,39,.92), Kante lila 25 %, Schatten 0 4 24 schwarz 30 %
    /// und ein lila Schein 0 0 40.
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

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 10, weight: .semibold))
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

    /// Der Server vergibt vier Stellen; sollte er je laenger werden, kommen
    /// Kaestchen dazu, statt die PIN abzuschneiden.
    private var chars: [Character] {
        Array(pin.isEmpty ? "----" : pin)
    }

    /// 22 pt sehr fett, Grund lila 7 %. Zugedeckt Kante weiss 9 %, aufgedeckt
    /// Kante lila 45 % mit Schein 0 0 14 lila 18 %.
    private func digitBox(_ c: Character, _ ordinal: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        let outline: Color = isOpen ? Palette.accent.opacity(0.45) : Color.white.opacity(0.09)
        let glow: Color = isOpen ? Palette.accent.opacity(0.18) : Color.clear
        let staggerDelay: Double = Double(ordinal) * 0.05
        return Text(isOpen ? String(c) : "•")
            .font(.brand(22, .heavy))
            .foregroundColor(Palette.foreground)
            .frame(width: 46, height: 52)
            .background(shape.fill(Palette.accent.opacity(0.07)))
            .overlay(shape.strokeBorder(outline, lineWidth: 1))
            .shadow(color: glow, radius: 7)
            .scaleEffect(bounce ? 1.1 : 1)
            .animation(.easeOut(duration: 0.125).delay(staggerDelay), value: bounce)
    }

    /// "Reveal" / "Copy": 35 hoch, weiss 4 % mit Kante 8 %, Schrift #b0aed2
    /// 11 pt fett. "Copied" kurz gruen.
    private func smallButton(_ text: String, _ symbol: String, greenTone: Bool,
                              _ onTap: @escaping () -> Void) -> some View {
        let foreground: Color = greenTone ? Palette.good : LobbyPalette.buttonTextColor
        let base: Color = greenTone ? Palette.good.opacity(0.12) : Color.white.opacity(0.04)
        let outline: Color = greenTone ? Palette.good.opacity(0.3) : Color.white.opacity(0.08)
        return Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
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
        // kurzes Aufhuepfen der Kaestchen nacheinander, wie im Browser
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

// MARK: - Pillen

/// Die Einstellungen als Pillen in einer eigenen Leiste: rgba(24,23,39,.9),
/// Kante 7 %, Polster 10/12, waagrecht wischbar. Die Playlist in Lila (hoechstens
/// 45 % breit), dann ♪ Songs, ⏱ Zeit, ? Modus - und Sneaky/Speaker, wenn an.
struct Chips: View {
    let lobbySettings: LobbySettings
    let playMode: String

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
            .padding(.vertical, 11)
        }
        .background(shape.fill(LobbyPalette.stripFill))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
        .clipShape(shape)
    }

    private var playlistPill: some View {
        let name: String = (lobbySettings.playlistName ?? "").isEmpty ? "Playlist" : (lobbySettings.playlistName ?? "")
        return HStack(spacing: 6) {
            Image(systemName: "record.circle")
                .font(.system(size: 9, weight: .medium))
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

    private func pill(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .medium))
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

    /// Die Namen wie im Browser; was er nicht kennt, heisst dort "Quiz".
    private var displayMode: String {
        switch playMode {
        case "timeline":          return "Timeline"
        case "higherlower", "hl": return "Higher / Lower"
        case "reverse":           return "Reverse"
        default:                  return "Quiz"
        }
    }
}

/// Gibt dem Inhalt hoechstens `breite` Platz - auch in einer waagrechten
/// ScrollView, wo sonst jeder Text unbegrenzt breit wird (max-w-[45%] truncate).
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

// MARK: - Freier Platz

/// Ein freier Platz im Raster: gestrichelte Kante weiss 10 %, Grund weiss 1,5 %,
/// pulsiert sanft (50-75 %), um das Symbol laeuft ein Ring nach aussen.
/// Antippen oeffnet die Einladung.
struct OpenSlot: View {
    var numeral: Int = 0
    var frameHeight: CGFloat = 0
    @State private var pulsing = false

    /// 11 + 40 + 6 + 3 × 15 + 11 - wie im Browser.
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

    /// Kreis 40 (weiss 4 %) mit Person+, darunter ein Ring, der auf das
    /// Doppelte waechst und dabei verblasst (animate-ping, 2,4 s).
    private var symbol: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .scaleEffect(pulsing ? 2 : 1)
                .opacity(pulsing ? 0 : 1)
                .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false), value: pulsing)
            Circle()
                .fill(Color.white.opacity(0.04))
            Image(systemName: "person.badge.plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Palette.subdued)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Chat

/// Die Chat-Karte "((•)) LOBBY": Kopf mit Strich, Verlauf (120-200 hoch,
/// scrollt mit), unten Eingabe und runder lila Sendeknopf 36.
private struct LobbyChatCard: View {
    @EnvironmentObject private var game: Game
    @State private var messageText: String = ""
    @State private var contentHeight: CGFloat = 0
    /// Wie im Browser: hoechstens 5 Nachrichten in 4 Sekunden.
    @State private var sentTimes: [Date] = []

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return VStack(spacing: 0) {
            header
            Rectangle().fill(Palette.border).frame(height: 1)
            if game.chat.isEmpty {
                emptyState
            } else {
                gradient
            }
            Rectangle().fill(Palette.border).frame(height: 1)
            input
        }
        .padding(1)
        .background(shape.fill(Palette.card))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 10, weight: .medium))
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
        .frame(height: 120)
    }

    private var visibleHeight: CGFloat {
        min(max(contentHeight, 120), 200)
    }

    private var gradient: some View {
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
                if let newest = game.chat.last {
                    scroller.scrollTo(newest.id, anchor: .bottom)
                }
            }
            .onChange(of: game.chat.count) { _ in
                if let newest = game.chat.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        scroller.scrollTo(newest.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ z: ChatLine) -> some View {
        if z.system {
            // Systemzeilen: Regler-Symbol 10, 11 pt, #8d8ba4
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9, weight: .medium))
                Text(z.text)
                    .font(.brand(11))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(Palette.subdued)
        } else {
            // Bild 20, "Name:" 12 pt fett lila, Text 12 pt
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

// MARK: - Einladen

/// Das Blatt "Invite players" wie im Browser: von unten, Ecken oben 24,
/// rgba(24,23,39,.98), Kante lila 32 %. QR-Code mit dem Link zur Lobby,
/// der Link zum Kopieren (und Teilen, wie Safari es auf dem iPhone anbietet).
/// Die Freundesliste braucht einen Server-Aufruf, den die App nicht macht -
/// Gaeste sehen deshalb nur den Hinweis, den der Browser ihnen auch zeigt.
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

    /// Unten laeuft die Form ueber den Rand hinaus - so bleiben nur die
    /// oberen Ecken rund (UnevenRoundedRectangle gibt es erst ab iOS 17).
    private var base: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return ZStack {
            shape.fill(LobbyPalette.panel)
            shape.strokeBorder(Palette.accent.opacity(0.32), lineWidth: 1)
        }
        .padding(.bottom, -60)
        .ignoresSafeArea(edges: .bottom)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 13, weight: .medium))
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

    /// QR-Code (92, weisse Flaeche mit Polster 8, Ecken 18) und daneben
    /// "Scan to join" mit Erklaerung.
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

    /// Safari auf dem iPhone kann teilen (navigator.share) - der Browser zeigt
    /// dann diesen Knopf neben "Copy".
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

/// Der QR-Code wie im Browser (Fehlerkorrektur M, #15151f auf weiss, ohne
/// eigene Ruhezone - die macht das weisse Polster drumherum).
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

    /// Wie breit der weisse Rand ist, den CoreImage mitliefert: Das erste
    /// dunkle Pixel ist die linke obere Ecke des Suchmusters.
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

// MARK: - Bausteine nur fuer die Lobby

/// Leichtes Eindruecken wie whileTap: { scale: .97 } im Browser.
private struct LobbyPressStyle: ButtonStyle {
    var pressed: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressed : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Start Game" wie im Browser: 51 hoch, Ecken 16, flaches Lila, weisse
/// 15 pt fett, Schein 0 0 28 rgba(112,0,215,.4) ohne Versatz.
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

/// Farben, die nur in der Lobby vorkommen (aus den Messwerten im Browser).
private enum LobbyPalette {
    /// Kopf: rgba(7,7,14,.82)
    static let header = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.82)
    /// Fuss: rgba(7,7,14,.95)
    static let footer = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.95)
    /// Pillen-Leiste: rgba(24,23,39,.9)
    static let stripFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    /// Blatt: rgba(24,23,39,.98)
    static let panel = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)
    /// Hinter dem Blatt: rgba(4,4,10,.72)
    static let scrim = Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.72)
    /// Link-Feld: rgba(10,9,20,.6)
    static let field = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)
    /// "Reveal", "Copy", der Link: #b0aed2
    static let buttonTextColor = Color(hex: 0xB0AED2)
    /// Das blasse Funk-Symbol im leeren Chat: #2a2848
    static let emptyIcon = Color(hex: 0x2A2848)
}
