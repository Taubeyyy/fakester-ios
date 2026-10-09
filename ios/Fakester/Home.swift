import SwiftUI
import UIKit

/// The home screen, element by element after fakester.app in the phone format
/// (375 × 812, as a guest, October 2026):
/// - at the top a fixed bar with the profile chip and the Spots, a thin line below,
/// - in the middle, centred vertically: equalizer, wordmark, "Create Game"
///   wide next to "Join", the online row, Daily, the four coloured tiles,
///   the four quiet buttons and the level card,
/// - the footer fixed at the bottom.
///
/// "Create Game", "Join" and "Board" open their own screens or the join
/// dialog. Everywhere else guests see - as in the browser - the guest
/// dialog; with an account a notice says honestly what only the browser has.
struct HomeView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game

    @State private var pin = ""
    @State private var joinGame = false
    @State private var createGame = false
    @State private var leaderboardOpen = false
    @State private var quests = false
    /// The account screens (and Stats, which guests may open too).
    @State private var accountScreen: AccountScreen?
    @State private var guestGate = false
    @State private var dailyBonus: DailyBonus?
    @State private var live: LiveStats?

    private var dialogOpen: Bool { joinGame || guestGate }

    var body: some View {
        // In the browser the home screen fits on one screen, and that is how it
        // should feel here: everything important reachable without swiping.
        // So the view measures the height it has and gives up empty space first
        // (`Density`), on very small phones it also moves closer together, and
        // whatever is still too tall is scaled down (`FitToHeight`) - the home
        // screen never scrolls.
        ZStack {
            GeometryReader { geo in
                page(Density.fitting(geo.size, bottomInset: geo.safeAreaInsets.bottom))
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
        .fullScreenCover(item: $accountScreen) { screen in
            accountView(screen)
                .environmentObject(api)
                .environmentObject(game)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $dailyBonus) { b in
            DailyBonusSheet(bonus: b)
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            // CI screenshots (Screenshots.swift): both dialogs can be opened as
            // a scene of their own. The scene names are fixed by the workflow.
            #if DEBUG
            if ScreenshotScene.sceneName == "join" { joinGame = true }
            if ScreenshotScene.sceneName == "guest-notice" { guestGate = true }
            #endif
        }
        .task { await checkDailyBonus() }
        .task {
            // Like the browser: fresh every 30 seconds.
            while !Task.isCancelled {
                if let z: LiveStats = try? await api.fetch("/stats/live") { live = z }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    /// Where a tile leads. Guests see - as in the browser - the account
    /// dialog everywhere except on the leaderboard.
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
        } else if let screen = AccountScreen(rawValue: id), AccountScreen.built.contains(screen) {
            accountScreen = screen
        } else {
            browserOnly(name)
        }
    }

    @ViewBuilder
    private func accountView(_ screen: AccountScreen) -> some View {
        switch screen {
        case .stats: StatsView()
        default: EmptyView()
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

    /// "Yes" in the guest dialog: back to the login screen, which opens
    /// "Create account" with the guest name already filled in - so making an
    /// account keeps the name, as the dialog says.
    private func createAccount() {
        guestGate = false
        if let guest = api.identity, guest.isGuest {
            UserDefaults.standard.set(guest.username, forKey: LoginView.pendingSignupNameKey)
        }
        api.logOut()
    }

    // MARK: Layout

    private func page(_ m: Density) -> some View {
        VStack(spacing: 0) {
            header(m)
            GeometryReader { inner in
                // No scrolling: the middle always fits. If it is still taller
                // than the space (update card, very small phone), it is scaled
                // down as a whole instead of being cut off.
                FitToHeight(available: inner.size.height) {
                    middleSection(m)
                        .padding(.horizontal, 20)
                        .padding(.vertical, m.middlePadding)
                }
                .frame(width: inner.size.width, height: inner.size.height)
            }
            footer(m)
        }
    }

    /// Top bar: px 12, py 10, a line below (border-b, white 7 %).
    private func header(_ m: Density) -> some View {
        HStack(spacing: 10) {
            // As in the browser, the profile chip opens Stats - for guests too.
            Button {
                Haptics.tap()
                if AccountScreen.built.contains(.stats) { accountScreen = .stats }
            } label: {
                HeaderChip()
            }
            .buttonStyle(SoftPressStyle(pressScale: 0.97))
            .accessibilityLabel(Text("Stats"))
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

    // MARK: Hero

    /// Equalizer (20 tall, 10 below), wordmark (46, 16 below), the two
    /// buttons and 12 below them the online row.
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

    /// In the browser the two sit side by side, at most 340 wide, in a ratio of
    /// 1.45 : 1 - creating is the main way, joining the short one.
    private func gameButtons(_ m: Density) -> some View {
        let rowWidth: CGFloat = max(120, min(340, m.span - 40))
        let createWidth: CGFloat = (rowWidth - 10) * 1.45 / 2.45
        let joinWidth: CGFloat = rowWidth - 10 - createWidth
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
                    LucideGlyph(icon: .logIn, size: 14)
                    Text("Join")
                }
            }
            .buttonStyle(JoinButtonStyle(frameHeight: m.buttonHeight))
            .frame(width: joinWidth)
        }
    }

    /// In the browser the play triangle (11, filled, 1 to the right) sits in a
    /// dark circle (22, black 16 %).
    private var createLabel: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.black.opacity(0.16))
                LucideGlyph(icon: .play, size: 11, fillColor: Color.white)
                    .padding(.leading, 1)
            }
            .frame(width: 22, height: 22)
            Text("Create Game")
        }
    }

    // MARK: Tiles

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
                FlatButton(name: k.name, icon: k.icon, compact: m.veryCompact) { goal(k.id, k.name) }
            }
        }
    }

    // MARK: Footer

    /// Three pills, 36 tall, centred, 10 apart: Logout, the blue Discord pill
    /// (in the app: Feedback) and the quiet version pill.
    private func footer(_ m: Density) -> some View {
        HStack(spacing: 10) {
            FooterButton(name: "Logout", icon: .logOut) {
                api.logOut()
            }
            FooterButton(name: "Feedback", icon: .messageCircle,
                         hue: Color(hex: 0x8B95F7),
                         base: Palette.discord.opacity(0.16),
                         rim: Palette.discord.opacity(0.35),
                         iconSize: 14) {
                NotificationCenter.default.post(name: .deviceShaken, object: nil)
            }
            VersionPill()
        }
        .padding(.horizontal, 20)
        .padding(.top, m.footerTop)
        .padding(.bottom, m.footerBottom)
    }
}

/// Where the home tiles lead (ids as in the browser).
private enum AccountScreen: String, Identifiable {
    case daily, shop, path, style, friends, playlists, settings, stats
    var id: String { rawValue }

    /// The screens that exist in the app so far; the others still say
    /// "browser-only".
    static let built: Set<AccountScreen> = [.stats]
}

// MARK: - Density

/// The spacing of the home screen for the height that is available.
///
/// Level 0 has the browser's values (375 × 812). The browser centres the
/// middle and leaves at least 20 above and below it; here that space is
/// `middlePadding`, so a shorter phone first loses only empty space and keeps
/// every other gap of the website (a 13 mini fits at level 0). Only when even
/// 6 pt of padding would not fit does everything move closer together:
/// level 1 (compact) and level 2 (very compact, iPhone SE class).
private struct Density {
    let span: CGFloat
    /// 0 = the browser's values, 1 = compact, 2 = very compact
    let level: Int
    /// Space below the footer pills: the browser's 16 - or 4 above a home
    /// indicator, whose safe area already leaves room below.
    let footerBottom: CGFloat
    /// Space above and below the middle part, between 6 and the level's maximum.
    private(set) var middlePadding: CGFloat = 0
    /// Whether this level fits the height without scrolling.
    private(set) var fits: Bool = false

    private static let minimumPadding: CGFloat = 6

    /// The roomiest level that fits.
    static func fitting(_ size: CGSize, bottomInset: CGFloat) -> Density {
        let homeIndicator: Bool = bottomInset > 0
        let browser = Density(span: size.width, level: 0, height: size.height, homeIndicator: homeIndicator)
        if browser.fits { return browser }
        let compactLevel = Density(span: size.width, level: 1, height: size.height, homeIndicator: homeIndicator)
        if compactLevel.fits { return compactLevel }
        return Density(span: size.width, level: 2, height: size.height, homeIndicator: homeIndicator)
    }

    private init(span: CGFloat, level: Int, height: CGFloat, homeIndicator: Bool) {
        self.span = span
        self.level = level
        if homeIndicator {
            footerBottom = 4
        } else {
            footerBottom = level == 0 ? 16 : (level == 1 ? 12 : 10)
        }
        let spare: CGFloat = height - fixedHeight - footerBottom
        let ceiling: CGFloat = level == 0 ? 20 : (level == 1 ? 12 : 8)
        fits = spare >= 2 * Density.minimumPadding
        middlePadding = max(Density.minimumPadding, min(ceiling, (spare / 2).rounded(.down)))
    }

    var compact: Bool { level >= 1 }
    var veryCompact: Bool { level >= 2 }

    var headerPadding: CGFloat { veryCompact ? 6 : 10 }
    var groupSpacing: CGFloat { compact ? (veryCompact ? 10 : 14) : 20 }
    var rowSpacing: CGFloat { veryCompact ? 6 : 8 }
    var eqGap: CGFloat { veryCompact ? 6 : 10 }
    /// clamp(46px, min(12vw, 16vh), 128px)
    var wordmarkSize: CGFloat { veryCompact ? 40 : max(46, min(span * 0.12, 128)) }
    var wordmarkGap: CGFloat { compact ? (veryCompact ? 10 : 14) : 16 }
    var buttonHeight: CGFloat { veryCompact ? 48 : 55 }
    var onlineGap: CGFloat { veryCompact ? 8 : 12 }
    var footerTop: CGFloat { veryCompact ? 6 : 8 }

    /// Everything except the middle padding and the space below the footer:
    /// the top bar, the middle content and the footer pills - from the sizes
    /// the views below use (keep in step when one of them changes).
    /// Level 0 at 375 pt: 67 + 572 + 44 = 683.
    var fixedHeight: CGFloat {
        // top bar: chip 46 (avatar 32 + 2 × 7) plus padding and the 1 pt line
        let header: CGFloat = 2 * headerPadding + 46 + 1
        // equalizer 20, wordmark, game buttons, online row 17
        let hero: CGFloat = 20 + eqGap + wordmarkSize + wordmarkGap + buttonHeight + onlineGap + 17
        let daily: CGFloat = veryCompact ? 60 : 64                      // DailyCard
        let tileRow: CGFloat = veryCompact ? 75 : 79                    // TileButton
        let quiet: CGFloat = 2 * (veryCompact ? 38 : 40) + rowSpacing   // two rows of FlatButton
        let group: CGFloat = daily + rowSpacing + tileRow + rowSpacing + quiet
        let levelCard: CGFloat = veryCompact ? 103 : 109                // LevelCard
        let middle: CGFloat = hero + groupSpacing + group + groupSpacing + levelCard
        let footer: CGFloat = footerTop + 36
        return header + middle + footer
    }
}

/// Lays its content out at its natural height and, if that is taller than
/// `available`, scales it down as a whole so it fits exactly - centred, never
/// scrolling, never cut off.
private struct FitToHeight<Content: View>: View {
    let available: CGFloat
    @ViewBuilder var content: Content
    @State private var natural: CGFloat = 0

    var body: some View {
        let factor: CGFloat = (natural > available && natural > 0) ? max(0.5, available / natural) : 1
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: NaturalHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(NaturalHeightKey.self) { height in natural = height }
            .scaleEffect(factor, anchor: .center)
    }
}

private struct NaturalHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Colours and helpers for this screen only

private enum HomePalette {
    /// #b0aed2 - subtitles and the quiet buttons
    static let softText = Color(hex: 0xB0AED2)
    /// #c9c8e0 - text in the guest dialog
    static let hint = Color(hex: 0xC9C8E0)
    /// --acc-pale for #b15cff (lightness + 35 %), the figure in the avatar
    static let accentPale = Color(hex: 0xCC95FF)
    static let stripFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    static let flat = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.5)
    static let level = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.75)
    static let dialog = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)
    static let version = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.55)
}

/// color-mix(in srgb, colour x %, rgba(24,23,39,.8)) - how the browser mixes
/// the background of the coloured tiles and the Daily card.
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

/// toLocaleString() as in the browser: 1234 → "1,234" or "1.234".
private func thousands(_ n: Int) -> String {
    NumberFormats.decimalStyle.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// Press feel like framer-motion `whileTap: {scale}`.
private struct SoftPressStyle: ButtonStyle {
    var pressScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Create Game": flat purple, corners 16, 0 8px 24px glow in --acc-deep 30 %,
/// a light line inside at the top (inset 0 1px 0 white 18 %), 15 pt bold white.
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

/// "Join": rgba(20,18,38,.75), border white 9 %, text #d8d7ee 14 pt semibold.
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

// MARK: - Top bar

/// Profile chip at the top left: rgba(24,23,39,.9), border white 7 %,
/// corners 16, padding 6/10/6/6. Round picture (32, ring in purple 70 %),
/// the level as an orange bead at the bottom right, next to it the name in
/// purple (13 pt bold).
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

    /// 15 tall, at least 15 wide, #f59e0b, text #07070e 9 pt, 2 pt border in the card colour.
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

/// The Spots at the top right: pill rgba(24,23,39,.9), note (lucide music-2,
/// 11) and number in purple (11 pt bold), 6 apart. Guests see a 0, as in the
/// browser. GoldSpots join behind a thin line as soon as there are any; PRO
/// is a pill of its own.
struct SpotsPill: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let spots: Int = api.me?.spots ?? 0
        let gold: Int = api.me?.gold_spots ?? 0
        HStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    LucideGlyph(icon: .music2, size: 11)
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

/// px 10, py 6, round, rgba(24,23,39,.9), border white 7 % → 31 tall.
private struct HeaderPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .frame(height: 31)
            .background(Capsule().fill(HomePalette.stripFill))
            .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
    }
}

/// The browser's GoldSpot coin: ring #fbbf24 with a 20 % fill and a dot.
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

// MARK: - Building blocks of the middle

/// The nine bars above the wordmark: 3 wide, 3 apart, purple 55 %, bottom
/// aligned in a 20 tall box. They bob as in the browser (`eq`: scaleY
/// 1 → .22 → 1, each bar with its own duration and delay).
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

/// `● 3 online | 1 lobbies` below the game buttons, 11 pt, #7877a0, the
/// numbers #eef semibold, the dot pulses (animate-ping). Dot, number and
/// "online" are separate flex items 6 apart in the browser (the space before
/// "online" collapses there); "1 lobbies" is one inline run. The numbers come
/// from `/stats/live`; until they are there the row stays empty instead of
/// showing a made-up zero - but its height stays reserved.
struct OnlineRow: View {
    let live: LiveStats?

    var body: some View {
        HStack(spacing: 12) {
            if let z = live {
                HStack(spacing: 6) {
                    PulseDot()
                    Text(thousands(z.players))
                        .font(.brand(11, .semibold))
                        .foregroundColor(Palette.foreground)
                    Text("online")
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

/// The dot before "online": 6 wide, with a ring on top that grows to twice
/// its size while it fades (1 s, endless).
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

/// The Daily card: 64 tall, corners 16, background purple 9 % in
/// rgba(24,23,39,.8), border purple 30 %, round icon circle (36, purple 18 %,
/// calendar-days 17), "Daily" 14 pt bold, subtitle 11 pt #b0aed2, chevron 15
/// in purple.
struct DailyCard: View {
    /// Only on very small phones: a little less padding.
    var compact: Bool = false
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        Button(action: onTap) {
            HStack(spacing: 12) {
                LucideGlyph(icon: .calendarDays, size: 17)
                    .foregroundColor(Palette.accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Palette.accent.opacity(0.18)))

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

                LucideGlyph(icon: .chevronRight, size: 15)
                    .foregroundColor(Palette.accent)
            }
            // padding 12/14 plus 1 for the border, which lies outside in the browser
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

/// A destination on the home screen.
struct Tile: Identifiable {
    let id: String
    let name: String
    let icon: LucideIcon
    var hue: Color = Palette.faint

    /// The four coloured ones. Order, icon and colour as in the browser.
    static var colorful: [Tile] {
        [
            Tile(id: "shop", name: "Shop", icon: .shoppingBag, hue: Palette.tilePurple),
            Tile(id: "path", name: "Path", icon: .map, hue: Palette.tileGold),
            Tile(id: "quests", name: "Quests", icon: .listChecks, hue: Palette.tileGreen),
            Tile(id: "style", name: "Style", icon: .palette, hue: Palette.tilePink)
        ]
    }

    /// The four quiet ones below.
    static var quiet: [Tile] {
        [
            Tile(id: "board", name: "Board", icon: .chartColumn),
            Tile(id: "friends", name: "Friends", icon: .users),
            Tile(id: "playlists", name: "Playlists", icon: .bookmark),
            Tile(id: "settings", name: "Settings", icon: .settings)
        ]
    }
}

/// Coloured tile: 79 tall, corners 16, background tone 7 % in
/// rgba(24,23,39,.8), border tone 26 %, round icon circle 36 (tone 16 %,
/// border 30 %) with the icon at 19, 6 below the name, 11 pt bold #eef in a
/// line box of 11 (leading-none).
struct TileButton: View {
    let tile: Tile
    /// Only on very small phones: a little less padding.
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
                    LucideGlyph(icon: tile.icon, size: 19)
                        .foregroundColor(tone)
                }
                .frame(width: 36, height: 36)

                // The text keeps its natural height (no shrinking to fit) and
                // only takes 11 in the layout, like the browser's leading-none.
                Text(tile.name)
                    .font(.brand(11, .bold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
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

/// Quiet button: 40 tall, corners 18, rgba(24,23,39,.5), border white 5 %,
/// icon 15 in #8d8ba4, 8 to the name, 12 pt semibold #b0aed2.
struct FlatButton: View {
    let name: String
    let icon: LucideIcon
    /// Only on very small phones: 38 instead of 40 tall.
    var compact: Bool = false
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        Button(action: onTap) {
            HStack(spacing: 8) {
                LucideGlyph(icon: icon, size: 15)
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

/// A pill in the footer, 36 tall. The defaults are "Logout": rgba(24,23,39,.7),
/// border white 7 %, text #7877a0 12 pt semibold, icon 13, padding 14, gap 8.
struct FooterButton: View {
    let name: String
    let icon: LucideIcon
    var hue: Color = Palette.faint
    var base: Color = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.7)
    var rim: Color = Palette.border
    var iconSize: CGFloat = 13
    var foreground: CGFloat = 12
    var inset: CGFloat = 14
    var gap: CGFloat = 8
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: gap) {
                LucideGlyph(icon: icon, size: iconSize)
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
/// (rgba(24,23,39,.55), #5c5b7d, 11 pt): sparkles 11 + "v<app version>".
private struct VersionPill: View {
    var body: some View {
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        FooterButton(name: "v" + version, icon: .sparkles,
                     hue: Color(hex: 0x5C5B7D),
                     base: HomePalette.version,
                     rim: Color.white.opacity(0.06),
                     iconSize: 11, foreground: 11, inset: 12, gap: 6) {}
    }
}

/// Level, progress and the three numbers below - in the browser for guests
/// too (then level 1, "50 XP to 2", three times 0).
/// 109 tall, corners 16, rgba(24,23,39,.75), border white 7 %, padding 12/14.
struct LevelCard: View {
    /// Only on very small phones: a little less padding.
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

    /// Number 14 pt extra bold, the label 4 below.
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

/// h-1.5: 6 tall, white 7 % as the track, purple as the fill.
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

// MARK: - Guest dialog

/// "That one needs an account" - the browser's confirm dialog:
/// veil rgba(4,4,10,.72), card at most 360 wide, 16 from the edge,
/// rgba(24,23,39,.98), border purple 40 %, corners 24, shadow 0 24px 60px.
/// At the top lock 13 + "GUEST MODE" (10 pt, letter-spaced, purple), title
/// 18 pt extra bold (line 22.5), text 13 pt #c9c8e0 (line 21.1), at the
/// bottom "No" (quiet) and "Yes" (purple).
private struct GuestNotice: View {
    let onNo: () -> Void
    let onYes: () -> Void

    /// 16 padding plus 1 for the border.
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
            // Helvetica bold 18 has a 20.7 line, leading-tight makes it 22.5.
            Text("That one needs an account")
                .font(.brand(18, .heavy))
                .foregroundColor(Palette.foreground)
                .lineSpacing(1.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 0.9)
                .padding(.horizontal, inner)
                .padding(.top, 8)
                .padding(.bottom, 4)
            // SF 13 has a 15.5 line, leading-relaxed makes it 21.1: 5.6
            // between the lines and half of that above and below.
            Text(messageText)
                .font(.system(size: 13))
                .lineSpacing(5.6)
                .foregroundColor(HomePalette.hint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2.8)
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
            LucideGlyph(icon: .lock, size: 13)
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

    /// Word for word as in the browser. "Making one keeps the name" holds in
    /// the app too: "Yes" opens "Create account" with the guest name filled in.
    private var messageText: String {
        "Guests can play everything — every mode, every lobby, and the leaderboard.\n\nXP, Spots, items and friends belong to an account, so they sit behind a sign-up. Making one keeps the name you are playing under right now."
    }
}

// MARK: - Join

/// "Join game" as in the browser: veil black 75 %, card 320 wide,
/// rgba(24,23,39,.98), border white 7 %, corners 24, padding 24, gap 20.
/// Four PIN boxes (56, corners 16), below them a 3 × 4 keypad (57 tall,
/// corners 18) with ×, 0 and "Join", at the very bottom "Cancel".
/// "Browse public lobbies" is left out on purpose - the app cannot list
/// public lobbies yet.
private struct JoinDialog: View {
    @Binding var pin: String
    let joinGame: () -> Void
    let close: () -> Void
    /// "Browse public lobbies" swaps the keypad for the list, as in the browser.
    @State private var browsing = false

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
            if browsing {
                PublicLobbyList(join: { chosen in
                    pin = chosen
                    joinGame()
                })
                switchButton(title: "Enter a PIN instead", symbol: "number") { browsing = false }
            } else {
                digitBox
                keypad
                switchButton(title: "Browse public lobbies", symbol: "globe") { browsing = true }
            }
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
        // 24 padding plus 1 for the border.
        .padding(25)
        .background(shape.fill(HomePalette.dialog).shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 0))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    /// "Browse public lobbies" / "Enter a PIN instead": full width, 46 tall,
    /// corners 16, outline white 9 %, icon + 13 pt bold.
    private func switchButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.18)) { action() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(Palette.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(shape.fill(Color.white.opacity(0.02)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(pressScale: 0.97))
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
                    LucideGlyph(icon: .x, size: 18)
                        .foregroundColor(Palette.foreground)
                }
                .accessibilityLabel("Delete")
                KeypadKey(onTap: { typeDigit("0") }) {
                    Text("0")
                        .font(.brand(18, .bold))
                        .foregroundColor(Palette.foreground)
                }
                joinKey
            }
        }
    }

    /// Disabled: --acc-deep 20 % with quiet text; with four digits purple/white.
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

/// A PIN box: 56 × 56, white 4 %, border white 10 % (filled: purple 60 %),
/// digit 22 pt extra bold, empty a dash in #8d8ba4.
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

/// A keypad key: 57 tall, corners 18, white 4 %, border white 7 %.
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
