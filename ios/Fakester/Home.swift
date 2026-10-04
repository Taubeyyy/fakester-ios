import SwiftUI
import UIKit

/// Der Startbildschirm, Element fuer Element nach fakester.app im Handyformat
/// (375×812, als Gast, Oktober 2026):
/// - oben eine feste Leiste mit Profilchip und Spots, darunter ein feiner Strich,
/// - in der Mitte, senkrecht zentriert: Equalizer, Schriftzug, "Create Game"
///   breit neben "Join", die Online-Zeile, Daily, die vier farbigen Kacheln,
///   die vier ruhigen Knoepfe und die Stufenkarte,
/// - unten fest die Fussleiste.
///
/// "Create Game", "Join" und "Board" fuehren in eigene Bildschirme bzw. den
/// Beitreten-Dialog. Gaeste sehen ueberall sonst - wie im Browser - den
/// Gast-Hinweis; mit Konto sagt ein Tipp ehrlich, was es nur im Browser gibt.
struct HomeView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game

    @State private var pin = ""
    @State private var joinGame = false
    @State private var createGame = false
    @State private var leaderboardOpen = false
    @State private var quests = false
    @State private var guestGate = false
    @State private var dailyBonus: DailyBonus?
    @State private var live: LiveStats?

    private var dialogOpen: Bool { joinGame || guestGate }

    var body: some View {
        // Der Startbildschirm passt im Browser auf einen Bildschirm, und genau
        // so soll er sich anfuehlen: alles Wichtige ohne Wischen erreichbar.
        // Deshalb misst die Ansicht die Hoehe, die da ist, und rueckt auf
        // kleineren Geraeten zusammen (`Dichte`: eng / sehr eng), statt unten
        // abzuschneiden. Gescrollt werden kann die Mitte trotzdem - wie im
        // Browser, wo sie ebenfalls ein eigener Scrollbereich ist.
        ZStack {
            GeometryReader { geo in
                page(Density(dimension: geo.size))
            }
            .blur(radius: dialogOpen ? 6 : 0)
            .allowsHitTesting(!dialogOpen)

            if joinGame {
                JoinDialog(pin: $pin,
                                joinGame: { joinWithPin() },
                                close: { joinGame = false })
                    .transition(.opacity)
                    .zIndex(1)
            }
            if guestGate {
                GuestNotice(onNo: { guestGate = false },
                            onYes: { createAccount() })
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.18), value: dialogOpen)
        .fullScreenCover(isPresented: $createGame) {
            CreateGameView()
                .environmentObject(api)
                .environmentObject(game)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $leaderboardOpen) {
            LeaderboardView()
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $quests) {
            QuestsView()
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $dailyBonus) { b in
            DailyBonusSheet(bonus: b)
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            // Bildschirmfotos im CI (Vorschau.swift): die beiden Dialoge
            // lassen sich als eigene Szene oeffnen.
            #if DEBUG
            if ScreenshotScene.sceneName == "beitreten" { joinGame = true }
            if ScreenshotScene.sceneName == "gastsperre" { guestGate = true }
            #endif
        }
        .task { await checkDailyBonus() }
        .task {
            // Wie der Browser: alle 30 Sekunden frisch.
            while !Task.isCancelled {
                if let z: LiveStats = try? await api.fetch("/stats/live") { live = z }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    /// Wohin eine Kachel fuehrt. Gaeste sehen - wie im Browser - ueberall ausser
    /// bei der Rangliste den Konto-Hinweis.
    private func goal(_ id: String, _ name: String) {
        Haptics.tap()
        if id == "board" {
            leaderboardOpen = true
            return
        }
        guard api.isLoggedIn else {
            guestGate = true
            return
        }
        if id == "quests" {
            quests = true
        } else {
            browserOnly(name)
        }
    }

    @MainActor
    private func checkDailyBonus() async {
        guard api.isLoggedIn, dailyBonus == nil else { return }
        if let b: DailyBonus = try? await api.fetch("/daily-checkin"), b.isClaimable {
            dailyBonus = b
        }
    }

    private func browserOnly(_ what: String) {
        game.notice = "\(what) is browser-only for now."
    }

    private func joinWithPin() {
        guard pin.count == 4, let a = api.identity else { return }
        Haptics.tap()
        game.join(pin: pin, asPlayer: a)
        joinGame = false
    }

    /// "Yes" im Gast-Hinweis: zurueck zur Anmeldung, dort laesst sich ein
    /// Konto anlegen.
    private func createAccount() {
        guestGate = false
        api.logOut()
    }

    // MARK: Aufbau

    private func page(_ m: Density) -> some View {
        VStack(spacing: 0) {
            header(m)
            GeometryReader { inner in
                ScrollView(.vertical, showsIndicators: false) {
                    middleSection(m)
                        .padding(.horizontal, 20)
                        .padding(.vertical, m.middlePadding)
                        .frame(width: inner.size.width)
                        .frame(minHeight: inner.size.height)
                }
            }
            footer(m)
        }
    }

    /// Kopfleiste: px 12, py 10, unten ein Strich (border-b, weiss 7 %).
    private func header(_ m: Density) -> some View {
        HStack(spacing: 10) {
            HeaderChip()
            Spacer(minLength: 0)
            SpotsPill()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, m.headerPadding)
        .padding(.bottom, 1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    private func middleSection(_ m: Density) -> some View {
        VStack(spacing: m.groupSpacing) {
            UpdateCard()
            hero(m)
            VStack(spacing: m.rowSpacing) {
                DailyCard(compact: m.veryCompact) { goal("daily", "Daily") }
                tiles(m)
                quietButtons(m)
            }
            LevelCard(compact: m.veryCompact)
        }
        .frame(maxWidth: 680)
    }

    // MARK: Held

    /// Equalizer (20 hoch, 10 Abstand), Schriftzug (46, 16 Abstand), die
    /// beiden Knoepfe und 12 darunter die Online-Zeile.
    private func hero(_ m: Density) -> some View {
        VStack(spacing: 0) {
            Equalizer()
                .padding(.bottom, m.eqGap)
            Wordmark(dimension: m.wordmarkSize)
                .frame(height: m.wordmarkSize)
                .padding(.bottom, m.wordmarkGap)
            gameButtons(m)
            OnlineRow(live: live)
                .padding(.top, m.onlineGap)
        }
    }

    /// Im Browser stehen die beiden nebeneinander, hoechstens 340 breit, im
    /// Verhaeltnis 1,45 : 1 - erstellen ist der Hauptweg, beitreten der kurze.
    private func gameButtons(_ m: Density) -> some View {
        let rowSpacing: CGFloat = max(120, min(340, m.span - 40))
        let createWidth: CGFloat = (rowSpacing - 10) * 1.45 / 2.45
        let joinWidth: CGFloat = rowSpacing - 10 - createWidth
        return HStack(spacing: 10) {
            Button {
                Haptics.tap()
                createGame = true
            } label: {
                createLabel
            }
            .buttonStyle(CreateButtonStyle(frameHeight: m.buttonHeight))
            .frame(width: createWidth)

            Button {
                Haptics.tap()
                pin = ""
                joinGame = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 13, weight: .medium))
                    Text("Join")
                }
            }
            .buttonStyle(JoinButtonStyle(frameHeight: m.buttonHeight))
            .frame(width: joinWidth)
        }
    }

    /// Das Abspiel-Dreieck sitzt im Browser in einem dunklen Kreis (22, schwarz 16 %).
    private var createLabel: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.black.opacity(0.16))
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .offset(x: 1)
            }
            .frame(width: 22, height: 22)
            Text("Create Game")
        }
    }

    // MARK: Kacheln

    private func tiles(_ m: Density) -> some View {
        HStack(spacing: 8) {
            ForEach(Tile.colorful) { k in
                TileButton(tile: k, compact: m.veryCompact) { goal(k.id, k.name) }
            }
        }
    }

    private func quietButtons(_ m: Density) -> some View {
        let gridColumns: [GridItem] = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: gridColumns, spacing: m.rowSpacing) {
            ForEach(Tile.quiet) { k in
                FlatButton(name: k.name, symbol: k.symbol, compact: m.veryCompact) { goal(k.id, k.name) }
            }
        }
    }

    // MARK: Fuss

    /// Drei Pillen, 36 hoch, mittig: Logout, die blaue Discord-Pille (in der
    /// App: Feedback) und die leise Versions-Pille (in der App: Sprache).
    private func footer(_ m: Density) -> some View {
        HStack(spacing: 10) {
            FooterButton(name: "Logout", symbol: "rectangle.portrait.and.arrow.right") {
                api.logOut()
            }
            FooterButton(name: "Feedback", symbol: "bubble.left.and.bubble.right",
                      hue: Color(hex: 0x8B95F7),
                      base: Palette.discord.opacity(0.16),
                      rim: Palette.discord.opacity(0.35),
                      symbolSize: 12) {
                NotificationCenter.default.post(name: .deviceShaken, object: nil)
            }
            VersionPill()
        }
        .padding(.horizontal, 20)
        .padding(.top, m.footerTop)
        .padding(.bottom, m.footerBottom)
    }
}

// MARK: - Dichte

/// Die Abstaende des Startbildschirms je nach verfuegbarer Hoehe. Stufe 0 sind
/// die Werte des Browsers (375×812); darunter rueckt alles zusammen, damit der
/// Bildschirm auch auf einem 12 mini (eng) und einem SE (sehr eng) ohne
/// Wischen ganz zu sehen ist.
private struct Density {
    let span: CGFloat
    /// 0 = wie im Browser, 1 = eng, 2 = sehr eng
    let level: Int

    init(dimension: CGSize) {
        span = dimension.width
        let h: CGFloat = dimension.height
        // Stufe 0 braucht ~740, Stufe 1 ~705, Stufe 2 ~628 Punkte.
        level = h >= 745 ? 0 : (h >= 708 ? 1 : 2)
    }

    var compact: Bool { level >= 1 }
    var veryCompact: Bool { level >= 2 }

    var headerPadding: CGFloat { veryCompact ? 6 : 10 }
    var middlePadding: CGFloat { compact ? (veryCompact ? 8 : 12) : 20 }
    var groupSpacing: CGFloat { compact ? (veryCompact ? 10 : 14) : 20 }
    var rowSpacing: CGFloat { veryCompact ? 6 : 8 }
    var eqGap: CGFloat { veryCompact ? 6 : 10 }
    /// clamp(46px, min(12vw, 16vh), 128px)
    var wordmarkSize: CGFloat { veryCompact ? 40 : max(46, min(span * 0.12, 128)) }
    var wordmarkGap: CGFloat { compact ? (veryCompact ? 10 : 14) : 16 }
    var buttonHeight: CGFloat { veryCompact ? 48 : 55 }
    var onlineGap: CGFloat { veryCompact ? 8 : 12 }
    var footerTop: CGFloat { veryCompact ? 6 : 8 }
    var footerBottom: CGFloat { compact ? (veryCompact ? 10 : 12) : 16 }
}

// MARK: - Farben und Helfer nur fuer diesen Bildschirm

private enum HomePalette {
    /// #b0aed2 - Unterzeilen und die ruhigen Knoepfe
    static let softText = Color(hex: 0xB0AED2)
    /// #c9c8e0 - Text im Gast-Hinweis
    static let hint = Color(hex: 0xC9C8E0)
    /// --acc-pale fuer #b15cff (Helligkeit + 35 %), die Figur im Profilbild
    static let accentPale = Color(hex: 0xCC95FF)
    static let stripFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    static let flat = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.5)
    static let level = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.75)
    static let dialog = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)
    static let version = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.55)
}

/// color-mix(in srgb, Farbe x %, rgba(24,23,39,.8)) - so mischt der Browser
/// den Grund der farbigen Kacheln und der Daily-Karte.
private func blend(_ hue: Color, _ fraction: Double, baseAlpha: Double = 0.8) -> Color {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    _ = UIColor(hue).getRed(&r, green: &g, blue: &b, alpha: &a)
    let remaining: Double = (1 - fraction) * baseAlpha
    let coverage: Double = fraction + remaining
    let redTone: Double = (fraction * Double(r) + remaining * 24 / 255) / coverage
    let greenTone: Double = (fraction * Double(g) + remaining * 23 / 255) / coverage
    let blueTone: Double = (fraction * Double(b) + remaining * 39 / 255) / coverage
    return Color(.sRGB, red: redTone, green: greenTone, blue: blueTone, opacity: coverage)
}

private enum NumberFormats {
    static let decimalStyle: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}

/// toLocaleString() wie im Browser: 1234 → "1,234" bzw. "1.234".
private func thousands(_ n: Int) -> String {
    NumberFormats.decimalStyle.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// Druckgefuehl wie framer-motion `whileTap: {scale}`.
private struct SoftPressStyle: ButtonStyle {
    var pressScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Create Game": flaches Lila, Ecken 16, 0 8px 24px Schein in --acc-deep 30 %,
/// innen oben ein heller Strich (inset 0 1px 0 weiss 18 %), 15 pt fett weiss.
private struct CreateButtonStyle: ButtonStyle {
    var frameHeight: CGFloat = 55

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return configuration.label
            .font(.brand(15, .bold))
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: frameHeight)
            .background(shape.fill(Palette.accent))
            .overlay(EdgeHighlight(radius: 16, intensity: 0.18))
            .shadow(color: Palette.accentDeep.opacity(0.3), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Join": rgba(20,18,38,.75), Kante weiss 9 %, Schrift #d8d7ee 14 pt halbfett.
private struct JoinButtonStyle: ButtonStyle {
    var frameHeight: CGFloat = 55

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let base: Color = Color(.sRGB, red: 20 / 255, green: 18 / 255, blue: 38 / 255, opacity: 0.75)
        return configuration.label
            .font(.brand(14, .semibold))
            .foregroundColor(Color(hex: 0xD8D7EE))
            .frame(maxWidth: .infinity)
            .frame(height: frameHeight)
            .background(shape.fill(base))
            .overlay(shape.strokeBorder(Palette.rim, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Kopfleiste

/// Profilchip oben links: rgba(24,23,39,.9), Kante weiss 7 %, Ecken 16,
/// Polster 6/10/6/6. Rundes Bild (32, Ring in Lila 70 %), unten rechts die
/// Stufe als orange Perle, daneben der Name in Lila (13 pt fett).
private struct HeaderChip: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let level: Int = Api.Level.forXP(api.me?.xp ?? 0)
        HStack(spacing: 8) {
            HeaderAvatar(level: level)
            Text(api.identity?.username ?? "")
                .font(.brand(13, .bold))
                .foregroundColor(Palette.accent)
                .lineLimit(1)
        }
        .padding(.leading, 7)
        .padding(.trailing, 11)
        .padding(.vertical, 7)
        .background(shape.fill(HomePalette.stripFill))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }
}

private struct HeaderAvatar: View {
    let level: Int
    @EnvironmentObject private var api: Api

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            contents
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Palette.accent.opacity(0.7), lineWidth: 2))
        .shadow(color: Palette.accent.opacity(0.3), radius: 5)
        .overlay(alignment: .bottomTrailing) {
            badge.offset(x: 2, y: 2)
        }
    }

    @ViewBuilder
    private var contents: some View {
        if let s = api.me?.avatar_url, s.hasPrefix("http"), let url = URL(string: s) {
            AsyncImage(url: url) { phase in
                if let picture = phase.image {
                    picture.resizable().scaledToFill()
                } else {
                    silhouette
                }
            }
        } else if let e = api.me?.equipped_emoji, !e.isEmpty {
            Text(e).font(.system(size: 15))
        } else {
            silhouette
        }
    }

    private var silhouette: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(HomePalette.accentPale)
    }

    /// 15 hoch, mind. 15 breit, #f59e0b, Schrift #07070e 9 pt, Rand 2 in Kartenfarbe.
    private var badge: some View {
        Text("\(level)")
            .font(.brand(9, .heavy))
            .foregroundColor(Palette.base)
            .padding(.horizontal, 5)
            .frame(minWidth: 15)
            .frame(height: 15)
            .background(Capsule().fill(Color(hex: 0xF59E0B)))
            .overlay(Capsule().strokeBorder(Color(hex: 0x181727), lineWidth: 2))
    }
}

/// Die Spots oben rechts: Pille rgba(24,23,39,.9), Note und Zahl in Lila
/// (11 pt fett). Gaeste sehen - wie im Browser - eine 0. GoldSpots kommen
/// hinter einem feinen Strich dazu, sobald es welche gibt; PRO als eigene Pille.
struct SpotsPill: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let spots: Int = api.me?.spots ?? 0
        let gold: Int = api.me?.gold_spots ?? 0
        HStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                    Text(thousands(spots))
                        .font(.brand(11, .bold))
                }
                .foregroundColor(Palette.accent)
                if gold > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 12)
                    HStack(spacing: 4) {
                        GoldCoin()
                        Text(thousands(gold))
                            .font(.brand(11, .bold))
                    }
                    .foregroundColor(Palette.gold)
                }
            }
            .modifier(HeaderPill())

            if api.me?.is_pro == true {
                Text("PRO")
                    .font(.brand(11, .bold))
                    .foregroundColor(Palette.gold)
                    .modifier(HeaderPill())
            }
        }
    }
}

/// px 10, py 6, rund, rgba(24,23,39,.9), Kante weiss 7 % → 31 hoch.
private struct HeaderPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .frame(height: 31)
            .background(Capsule().fill(HomePalette.stripFill))
            .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
    }
}

/// Die GoldSpot-Muenze des Browsers: Ring #fbbf24 mit 20 % Fuellung und Punkt.
private struct GoldCoin: View {
    var body: some View {
        ZStack {
            Circle().fill(Palette.gold.opacity(0.2))
            Circle().stroke(Palette.gold, lineWidth: 1.2)
            Circle().fill(Palette.gold).frame(width: 3.3, height: 3.3)
        }
        .frame(width: 10.5, height: 10.5)
        .frame(width: 12, height: 12)
    }
}

// MARK: - Bausteine der Mitte

/// Die neun Balken ueber dem Schriftzug: 3 breit, 3 Abstand, Lila 55 %, in
/// einem 20 hohen Kasten unten ausgerichtet. Sie wippen wie im Browser
/// (`eq`: scaleY 1 → .22 → 1, je Balken eigene Dauer und Verzoegerung).
struct Equalizer: View {
    @State private var on = false
    private let heights: [CGFloat] = [8, 14, 10, 18, 12, 16, 9, 13, 11]
    private let length: [Double] = [0.55, 0.40, 0.70, 0.45, 0.60, 0.50, 0.65, 0.42, 0.58]
    private let stagger: [Double] = [0.00, 0.08, 0.04, 0.12, 0.06, 0.10, 0.02, 0.14, 0.07]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<heights.count, id: \.self) { i in
                Capsule()
                    .fill(Palette.accent.opacity(0.55))
                    .frame(width: 3, height: heights[i])
                    .scaleEffect(x: 1, y: on ? 0.22 : 1, anchor: .bottom)
                    .animation(.easeInOut(duration: length[i] / 2)
                        .repeatForever(autoreverses: true)
                        .delay(stagger[i]), value: on)
            }
        }
        .frame(height: 20, alignment: .bottom)
        .onAppear { on = true }
    }
}

/// `● 3 online | 1 lobbies` unter den Spielknoepfen, 11 pt, #7877a0, die Zahl
/// #eef halbfett, der Punkt pulsiert (animate-ping). Die Zahl kommt aus
/// `/stats/live`; bis sie da ist, bleibt die Zeile leer statt eine erfundene
/// Null zu zeigen - ihre Hoehe bleibt aber reserviert.
struct OnlineRow: View {
    let live: LiveStats?

    var body: some View {
        HStack(spacing: 12) {
            if let z = live {
                HStack(spacing: 6) {
                    PulseDot()
                    (Text(thousands(z.players)).font(.brand(11, .semibold)).foregroundColor(Palette.foreground)
                     + Text(" online"))
                }
                if z.lobbies > 0 {
                    Rectangle().fill(Palette.border).frame(width: 1, height: 12)
                    (Text(thousands(z.lobbies)).font(.brand(11, .semibold)).foregroundColor(Palette.foreground)
                     + Text(" lobbies"))
                }
            }
        }
        .font(.brand(11, .medium))
        .foregroundColor(Palette.faint)
        .frame(height: 17)
    }
}

/// Der Punkt vor "online": 6 gross, darueber ein Ring, der auf das Doppelte
/// waechst und dabei verblasst (1 s, endlos).
private struct PulseDot: View {
    @State private var on = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.accent)
                .scaleEffect(on ? 2 : 1)
                .opacity(on ? 0 : 0.7)
                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: on)
            Circle().fill(Palette.accent)
        }
        .frame(width: 6, height: 6)
        .onAppear { on = true }
    }
}

/// Die Daily-Karte: 64 hoch, Ecken 16, Grund Lila 9 % in rgba(24,23,39,.8),
/// Kante Lila 30 %, runder Symbolkreis (36, Lila 18 %), "Daily" 14 pt fett,
/// Unterzeile 11 pt #b0aed2, Pfeil in Lila.
struct DailyCard: View {
    /// Nur auf sehr kleinen Geraeten: etwas weniger Polster.
    var compact: Bool = false
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Palette.accent.opacity(0.18))
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Palette.accent)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Daily")
                        .font(.brand(14, .bold))
                        .foregroundColor(Palette.foreground)
                        .frame(height: 21)
                    Text("Same five songs for everyone. One try.")
                        .font(.brand(11, .medium))
                        .foregroundColor(HomePalette.softText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(height: 17)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.accent)
            }
            // Polster 12/14 plus 1 fuer den Rand, der im Browser aussen liegt.
            .padding(.horizontal, 15)
            .padding(.vertical, compact ? 11 : 13)
            .frame(maxWidth: .infinity)
            .background(shape.fill(blend(Palette.accent, 0.09)))
            .overlay(shape.strokeBorder(Palette.accent.opacity(0.3), lineWidth: 1))
            .overlay(EdgeHighlight(radius: 16, intensity: 0.05))
        }
        .buttonStyle(SoftPressStyle(pressScale: 0.985))
    }
}

/// Ein Ziel auf dem Startbildschirm.
struct Tile: Identifiable {
    let id: String
    let name: String
    let symbol: String
    var hue: Color = Palette.faint

    /// Die vier bunten. Reihenfolge und Farbe wie im Browser.
    static var colorful: [Tile] {
        [
            Tile(id: "shop", name: "Shop", symbol: "bag", hue: Palette.tilePurple),
            Tile(id: "path", name: "Path", symbol: "map", hue: Palette.tileGold),
            Tile(id: "quests", name: "Quests", symbol: "checklist", hue: Palette.tileGreen),
            Tile(id: "style", name: "Style", symbol: "paintpalette", hue: Palette.tilePink)
        ]
    }

    /// Die vier ruhigen darunter.
    static var quiet: [Tile] {
        [
            Tile(id: "board", name: "Board", symbol: "chart.bar"),
            Tile(id: "friends", name: "Friends", symbol: "person.2"),
            Tile(id: "playlists", name: "Playlists", symbol: "bookmark"),
            Tile(id: "settings", name: "Settings", symbol: "gearshape")
        ]
    }
}

/// Farbige Kachel: 79 hoch, Ecken 16, Grund Farbton 7 % in rgba(24,23,39,.8),
/// Kante Farbton 26 %, runder Symbolkreis 36 (Farbton 16 %, Kante 30 %),
/// Name 11 pt fett #eef.
struct TileButton: View {
    let tile: Tile
    /// Nur auf sehr kleinen Geraeten: etwas weniger Polster.
    var compact: Bool = false
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let tone: Color = tile.hue
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(tone.opacity(0.16))
                    Circle().strokeBorder(tone.opacity(0.3), lineWidth: 1)
                    Image(systemName: tile.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(tone)
                }
                .frame(width: 36, height: 36)

                Text(tile.name)
                    .font(.brand(11, .bold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: 11)
            }
            .padding(.vertical, compact ? 11 : 13)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .background(shape.fill(blend(tone, 0.07)))
            .overlay(shape.strokeBorder(tone.opacity(0.26), lineWidth: 1))
            .overlay(EdgeHighlight(radius: 16, intensity: 0.04))
        }
        .buttonStyle(SoftPressStyle(pressScale: 0.97))
    }
}

/// Ruhiger Knopf: 40 hoch, Ecken 18, rgba(24,23,39,.5), Kante weiss 5 %,
/// Symbol #8d8ba4, Name 12 pt halbfett #b0aed2.
struct FlatButton: View {
    let name: String
    let symbol: String
    /// Nur auf sehr kleinen Geraeten: 38 statt 40 hoch.
    var compact: Bool = false
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.subdued)
                Text(name)
                    .font(.brand(12, .semibold))
                    .foregroundColor(HomePalette.softText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 38 : 40)
            .background(shape.fill(HomePalette.flat))
            .overlay(shape.strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(pressScale: 0.97))
    }
}

/// Pille in der Fussleiste, 36 hoch. Vorgabe ist "Logout": rgba(24,23,39,.7),
/// Kante weiss 7 %, Schrift #7877a0 12 pt halbfett, Polster 14, Abstand 8.
struct FooterButton: View {
    let name: String
    let symbol: String
    var hue: Color = Palette.faint
    var base: Color = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.7)
    var rim: Color = Palette.border
    var symbolSize: CGFloat = 12
    var foreground: CGFloat = 12
    var inset: CGFloat = 14
    var gap: CGFloat = 8
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: gap) {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .medium))
                Text(name)
                    .font(.brand(foreground, .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(hue)
            .padding(.horizontal, inset + 1)
            .frame(height: 36)
            .background(Capsule().fill(base))
            .overlay(Capsule().strokeBorder(rim, lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(pressScale: 0.96))
    }
}

/// The quiet version pill at the end of the footer, like the browser's
/// (rgba(24,23,39,.55), #5c5b7d, 11 pt): sparkles + "v<app version>".
private struct VersionPill: View {
    var body: some View {
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        FooterButton(name: "v" + version, symbol: "sparkles",
                  hue: Color(hex: 0x5C5B7D),
                  base: HomePalette.version,
                  rim: Color.white.opacity(0.06),
                  symbolSize: 10, foreground: 11, inset: 12, gap: 6) {}
    }
}

/// Stufe, Fortschritt und die drei Zahlen darunter - im Browser auch fuer
/// Gaeste (dann Stufe 1, "50 XP to 2", dreimal 0).
/// 109 hoch, Ecken 16, rgba(24,23,39,.75), Kante weiss 7 %, Polster 12/14.
struct LevelCard: View {
    /// Nur auf sehr kleinen Geraeten: etwas weniger Polster.
    var compact: Bool = false
    @EnvironmentObject private var api: Api

    var body: some View {
        let k: Api.Account? = api.me
        let xp: Int = k?.xp ?? 0
        let level: Int = Api.Level.forXP(xp)
        let xpToGo: Int = max(0, Api.Level.minXP(level + 1) - xp)
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 12) {
                Text("\(level)")
                    .font(.brand(15, .heavy))
                    .foregroundColor(Color.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Palette.accent))

                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Text("LEVEL \(level)").eyebrow()
                        Spacer(minLength: 0)
                        Text("\(thousands(xpToGo)) XP to \(level + 1)")
                            .font(.brand(10, .medium))
                            .foregroundColor(Palette.subdued)
                            .lineLimit(1)
                    }
                    .frame(height: 15)
                    LevelBar(fraction: Api.Level.fraction(xp: xp))
                }
            }

            HStack(alignment: .top, spacing: 0) {
                numeric(k?.games_played ?? 0, "GAMES")
                Spacer(minLength: 16)
                numeric(k?.wins ?? 0, "WINS")
                Spacer(minLength: 16)
                numeric(k?.highscore ?? 0, "BEST")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, compact ? 11 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(HomePalette.level))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    /// Zahl 14 pt sehr fett, darunter (4 Abstand) das Etikett.
    private func numeric(_ amount: Int, _ word: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thousands(amount))
                .font(.brand(14, .heavy))
                .foregroundColor(Palette.foreground)
                .frame(height: 14)
            Text(word).eyebrow()
                .frame(height: 15)
        }
    }
}

/// h-1.5: 6 hoch, weiss 7 % als Bahn, Lila als Fuellung.
private struct LevelBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.border)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: box.size.width * CGFloat(max(0, min(1, fraction))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Gast-Hinweis

/// "That one needs an account" - der Bestaetigungsdialog des Browsers:
/// Schleier rgba(4,4,10,.72), Karte hoechstens 360 breit, 16 vom Rand,
/// rgba(24,23,39,.98), Kante Lila 40 %, Ecken 24, Schatten 0 24px 60px.
/// Oben Schloss + "GUEST MODE" (10 pt, gesperrt, Lila), Titel 18 pt sehr fett,
/// Text 13 pt #c9c8e0, unten "No" (ruhig) und "Yes" (Lila).
private struct GuestNotice: View {
    let onNo: () -> Void
    let onYes: () -> Void

    /// 16 Polster plus 1 fuer den Rand.
    private let inner: CGFloat = 17

    var body: some View {
        ZStack {
            Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.72)
                .ignoresSafeArea()
                .onTapGesture { onNo() }
            card
                .frame(maxWidth: 360)
                .padding(16)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return VStack(alignment: .leading, spacing: 0) {
            headerLine
            Text("That one needs an account")
                .font(.brand(18, .heavy))
                .foregroundColor(Palette.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, inner)
                .padding(.top, 8)
                .padding(.bottom, 4)
            Text(messageText)
                .font(.system(size: 13))
                .lineSpacing(5)
                .foregroundColor(HomePalette.hint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, inner)
                .padding(.top, 4)
                .padding(.bottom, 16)
            actionButtons
                .padding(.horizontal, inner)
                .padding(.bottom, inner)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(HomePalette.dialog).shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 24))
        .overlay(shape.strokeBorder(Palette.accent.opacity(0.4), lineWidth: 1))
    }

    private var headerLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 11, weight: .semibold))
            Text("GUEST MODE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
        }
        .foregroundColor(Palette.accent)
        .frame(height: 15)
        .padding(.horizontal, inner)
        .padding(.top, inner)
    }

    private var actionButtons: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 8) {
            Button(action: onNo) {
                Text("No")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HomePalette.hint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(shape.fill(Color.white.opacity(0.04)))
                    .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(SoftPressStyle(pressScale: 0.97))

            Button(action: onYes) {
                Text("Yes")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(shape.fill(Palette.accent))
            }
            .buttonStyle(SoftPressStyle(pressScale: 0.97))
        }
    }

    /// Wortgleich mit dem Browser bis auf dessen letzten Satz ("Making one keeps
    /// the name you are playing under right now.") - das stimmt in der App
    /// nicht, hier fuehrt "Yes" zur Anmeldung, und der Gastname bleibt nicht.
    private var messageText: String {
        "Guests can play everything — every mode, every lobby, and the leaderboard.\n\nXP, Spots, items and friends belong to an account, so they sit behind a sign-up."
    }
}

// MARK: - Beitreten

/// "Join game" wie im Browser: Schleier schwarz 75 %, Karte 320 breit,
/// rgba(24,23,39,.98), Kante weiss 7 %, Ecken 24, Polster 24, Abstand 20.
/// Vier PIN-Kaestchen (56, Ecken 16), darunter ein Ziffernblock 3 × 4
/// (57 hoch, Ecken 18) mit ×, 0 und "Join", ganz unten "Cancel".
/// "Browse public lobbies" fehlt bewusst - oeffentliche Lobbys kann die App
/// noch nicht auflisten.
private struct JoinDialog: View {
    @Binding var pin: String
    let joinGame: () -> Void
    let close: () -> Void

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { close() }
            card
                .frame(maxWidth: 320)
                .padding(.horizontal, 16)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return VStack(alignment: .leading, spacing: 20) {
            Text("Join game")
                .font(.brand(20, .bold))
                .foregroundColor(Palette.foreground)
                .frame(height: 30)
            digitBox
            keypad
            Button(action: close) {
                Text("Cancel")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.subdued)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle(pressScale: 0.97))
        }
        // 24 Polster plus 1 fuer den Rand.
        .padding(25)
        .background(shape.fill(HomePalette.dialog).shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 0))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private var digitBox: some View {
        let digits: [Character] = Array(pin)
        return HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                PinBox(digit: i < digits.count ? String(digits[i]) : nil)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(rows[r], id: \.self) { z in
                        KeypadKey(onTap: { typeDigit(z) }) {
                            Text(z)
                                .font(.brand(18, .bold))
                                .foregroundColor(Palette.foreground)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                KeypadKey(onTap: { deleteDigit() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Palette.foreground)
                }
                KeypadKey(onTap: { typeDigit("0") }) {
                    Text("0")
                        .font(.brand(18, .bold))
                        .foregroundColor(Palette.foreground)
                }
                joinKey
            }
        }
    }

    /// Gesperrt: --acc-deep 20 % mit leiser Schrift; mit vier Ziffern Lila/weiss.
    private var joinKey: some View {
        let ready: Bool = pin.count == 4
        let base: Color = ready ? Palette.accent : Palette.accentDeep.opacity(0.2)
        return KeypadKey(base: base, onTap: { if ready { joinGame() } }) {
            Text("Join")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ready ? Color.white : Palette.subdued)
        }
    }

    private func typeDigit(_ z: String) {
        guard pin.count < 4 else { return }
        Haptics.tap()
        pin += z
    }

    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        Haptics.tap()
        pin.removeLast()
    }
}

/// Ein PIN-Kaestchen: 56 × 56, weiss 4 %, Kante weiss 10 % (belegt: Lila 60 %),
/// Ziffer 22 pt sehr fett, leer ein Strich in #8d8ba4.
private struct PinBox: View {
    let digit: String?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let rim: Color = digit == nil ? Color.white.opacity(0.1) : Palette.accent.opacity(0.6)
        ZStack {
            shape.fill(Color.white.opacity(0.04))
            shape.strokeBorder(rim, lineWidth: 1)
            if let z = digit {
                Text(z)
                    .font(.brand(22, .heavy))
                    .foregroundColor(Palette.foreground)
            } else {
                Text("—")
                    .font(.brand(22, .heavy))
                    .foregroundColor(Palette.subdued)
            }
        }
        .frame(width: 56, height: 56)
    }
}

/// Eine Taste des Ziffernblocks: 57 hoch, Ecken 18, weiss 4 %, Kante weiss 7 %.
private struct KeypadKey<Content: View>: View {
    var base: Color = Color.white.opacity(0.04)
    let onTap: () -> Void
    @ViewBuilder var contents: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        Button(action: onTap) {
            contents
                .frame(maxWidth: .infinity)
                .frame(height: 57)
                .background(shape.fill(base))
                .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(pressScale: 0.93))
    }
}
