import SwiftUI

/// "Board" from the home screen: the leaderboard as in the browser (`S3` in the
/// bundle), measured at 375×812. A header bar with a round back button, the
/// title and a refresh button; below it, in the scroll area, the sort pills
/// (XP, Wins, Highscore, Games, Correct) and the rows. Places 1-3 are taller
/// and carry a gold/silver/bronze stripe, rank circle and border; from place 4
/// on the rows are flatter with a pale purple number. Public - guests see it too.
struct LeaderboardView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var sortKey: String = "xp"
    @State private var entries: [Leaderboard.Entry] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            BoardHeader(onBack: { close() }, onRefresh: { Task { await load() } })
            ScrollView(.vertical, showsIndicators: false) {
                // px-4 pt-4 pb-10, gap-4 between pills, notices and the list
                VStack(spacing: 16) {
                    tabs
                    errorBox
                    placeholder
                    rows
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .refreshable { await load() }
        }
        .background(Backdrop())
        .task(id: sortKey) { await load() }
    }

    private var unit: String {
        Leaderboard.sortOptions.first { $0.id == sortKey }?.unit ?? ""
    }

    /// The pills scroll sideways inside the 16 pt margins, exactly like the
    /// browser (there "Correct" is cut off at the right edge). pb-1 below.
    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Leaderboard.sortOptions) { s in
                    BoardTabPill(title: s.name, isOn: s.id == sortKey) {
                        guard s.id != sortKey else { return }
                        Haptics.tap()
                        sortKey = s.id
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    /// rounded-2xl box, red 8 % with a red 30 % border, #f87171 13 pt.
    @ViewBuilder
    private var errorBox: some View {
        if let f = errorMessage {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            Text(f)
                .font(.brand(13))
                .foregroundColor(Palette.bad)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(shape.fill(BoardColors.red.opacity(0.08)))
                .overlay(shape.strokeBorder(BoardColors.red.opacity(0.3), lineWidth: 1))
        }
    }

    /// Loading (equalizer bars plus a line) and empty state, each with py-16.
    @ViewBuilder
    private var placeholder: some View {
        if loading && entries.isEmpty {
            VStack(spacing: 12) {
                BoardLoadingBars()
                Text("Loading the board…")
                    .font(.brand(12))
                    .foregroundColor(Palette.subdued)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
        } else if !loading && errorMessage == nil && entries.isEmpty {
            Text("Nobody has finished a game yet.")
                .font(.brand(13))
                .foregroundColor(Palette.subdued)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 64)
        }
    }

    private var rows: some View {
        let myId: String? = api.me?.id.text
        let unitText: String = unit
        return LazyVStack(spacing: 8) {
            ForEach(entries) { e in
                BoardRow(entry: e, unit: unitText, isMe: myId != nil && e.id == myId)
            }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        errorMessage = nil
        do {
            let b: Leaderboard = try await api.fetch("/leaderboard", ["sort": sortKey, "limit": "100"])
            entries = b.entries
        } catch {
            // Switching tabs cancels the previous request - that is not an
            // error worth showing, and the new request owns the state now.
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
            entries = []
        }
        loading = false
    }
}

// MARK: - Header

/// The bar on top (`rn` in the bundle): rgba(7,7,14,.82), 14/16 padding,
/// 1 pt bottom border white 7 %, 65 pt tall. Back button 36 pt round, white 4 %
/// with a faint top highlight and a purple arrow (lucide arrow-left 15);
/// title 25 pt extra bold, -0.625 tracking; refresh button 36 pt round,
/// rgba(24,23,39,.9), rotate-ccw 14 in #eef.
private struct BoardHeader: View {
    let onBack: () -> Void
    let onRefresh: () -> Void

    @State private var turns: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            backButton
            Text("Leaderboard")
                .font(.brand(25, .heavy))
                .tracking(-0.625)
                .foregroundColor(Palette.foreground)
                .lineLimit(1)
            Spacer(minLength: 0)
            refreshButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 15)
        .background(BoardColors.headerFill.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "arrow.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.04)))
                .overlay(Circle().strokeBorder(Palette.border, lineWidth: 1))
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.05), Color.clear],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(BoardPressStyle(pressedScale: 0.92))
        .accessibilityLabel("Back")
    }

    private var refreshButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.4)) { turns += 180 }
            onRefresh()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.foreground)
                .rotationEffect(.degrees(-turns))
                .frame(width: 36, height: 36)
                .background(Circle().fill(BoardColors.refreshFill))
                .overlay(Circle().strokeBorder(Palette.border, lineWidth: 1))
        }
        .buttonStyle(BoardPressStyle(pressedScale: 0.92))
        .accessibilityLabel("Refresh")
    }
}

// MARK: - Sort pills

/// px-4 py-2 rounded-full, 12 pt semibold, 36 pt tall. Selected: flat
/// #b15cff (--acc-fill) with white text; otherwise rgba(24,23,39,.8),
/// border white 7 %, text #8d8ba4.
private struct BoardTabPill: View {
    let title: String
    let isOn: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.brand(12, .semibold))
                .foregroundColor(isOn ? Color.white : Palette.subdued)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 17) // 16 padding + the 1 pt CSS border
                .frame(height: 36)
                .background(Capsule().fill(isOn ? Palette.accent : BoardColors.pill))
                .overlay(Capsule().strokeBorder(isOn ? Color.clear : Palette.border, lineWidth: 1))
                .animation(.easeOut(duration: 0.2), value: isOn)
        }
        .buttonStyle(BoardPressStyle(pressedScale: 0.96))
    }
}

// MARK: - Rows

/// One row. Places 1-3: 72 pt, rgba(15,13,26,.95), border in the medal color,
/// 4 pt medal stripe on the left (as tall as the content, 85 % opacity),
/// rank circle 34, avatar 38 with a purple ring, number 18 pt #eef.
/// From place 4: 60 pt, rgba(24,23,39,.92), border white 7 %, no stripe,
/// rank circle 30 (white 5 %, #8d8ba4), avatar 32, number 15 pt #cc95ff.
/// Your own row: purple tint, purple border and glow, purple number.
private struct BoardRow: View {
    let entry: Leaderboard.Entry
    let unit: String
    let isMe: Bool

    private var podium: BoardPodium? { BoardPodium.forRank(entry.rankNumber) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let isTop: Bool = podium != nil
        return content
            .padding(.trailing, 16)
            .padding(.vertical, isTop ? 14 : 10)
            .padding(1) // the CSS border takes up room
            .background(shape.fill(rowFill).shadow(color: glow, radius: 10, x: 0, y: 0))
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
            .accessibilityElement(children: .combine)
    }

    /// Stripe, then gap 12 and pl-3: the rank circle sits 28 pt in on the
    /// podium, 12 pt in below it.
    private var content: some View {
        let isTop: Bool = podium != nil
        return HStack(spacing: 12) {
            BoardRankBadge(rank: entry.rankNumber, podium: podium)
            BoardAvatar(diameter: isTop ? 38 : 32, hasRing: isTop, hasAmberGlow: entry.rankNumber == 1, url: entry.avatarURL)
            nameLine
            score
        }
        .padding(.leading, isTop ? 28 : 12)
        .overlay(alignment: .leading) { stripe }
    }

    @ViewBuilder
    private var stripe: some View {
        if let p = podium {
            Rectangle()
                .fill(p.gradient)
                .frame(width: 4)
                .opacity(0.85)
        }
    }

    /// 14 pt bold in the accent color; the crown (lucide crown 12, #fbbf24)
    /// marks PRO players, 8 pt after the name; before it the admin shield
    /// (lucide shield, #f87171) like on the web.
    private var nameLine: some View {
        HStack(spacing: 8) {
            Text(entry.name)
                .font(.brand(14, .bold))
                .foregroundColor(Palette.accent)
                .lineLimit(1)
                .truncationMode(.tail)
            if entry.admin {
                Image(systemName: "shield")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Palette.bad)
                    .accessibilityLabel("Admin")
            }
            if entry.pro {
                Image(systemName: "crown")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Palette.gold)
                    .accessibilityLabel("PRO")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Number over unit, right aligned; line heights 27/23 and 15 as in the browser.
    private var score: some View {
        let isTop: Bool = podium != nil
        let hue: Color = isMe ? Palette.accent : (isTop ? Palette.foreground : BoardColors.accentPale)
        return VStack(alignment: .trailing, spacing: 0) {
            Text(BoardFormat.grouped(entry.amount))
                .font(Font.brand(isTop ? 18 : 15, .heavy).monospacedDigit())
                .foregroundColor(hue)
                .lineLimit(1)
                .frame(height: isTop ? 27 : 23)
            Text(unit)
                .font(.brand(10, .bold))
                .foregroundColor(Palette.subdued)
                .lineLimit(1)
                .frame(height: 15)
        }
        .fixedSize()
    }

    private var rowFill: Color {
        if isMe { return Palette.accentDeep.opacity(0.18) }
        return podium != nil ? BoardColors.podiumFill : Palette.card
    }

    private var rim: Color {
        if isMe { return Palette.accent.opacity(0.45) }
        if let p = podium { return p.border }
        return Palette.border
    }

    /// 0 0 20px: purple 15 % for your own row, amber 12 % for place 1.
    private var glow: Color {
        if isMe { return Palette.accentDeep.opacity(0.15) }
        return entry.rankNumber == 1 ? BoardColors.amber.opacity(0.12) : Color.clear
    }
}

/// Rank circle: rounded-full, min 34/30 wide, 0 9 padding, extra bold 13/12.
/// Podium: medal gradient with glow and #07070e text; otherwise white 5 %, #8d8ba4.
private struct BoardRankBadge: View {
    let rank: Int
    let podium: BoardPodium?

    var body: some View {
        let isTop: Bool = podium != nil
        let d: CGFloat = isTop ? 34 : 30
        return Text(String(rank))
            .font(Font.brand(isTop ? 13 : 12, .heavy).monospacedDigit())
            .foregroundColor(isTop ? BoardColors.ink : Palette.subdued)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(minWidth: d)
            .frame(height: d)
            .background(badgeFill)
    }

    @ViewBuilder
    private var badgeFill: some View {
        if let p = podium {
            Capsule()
                .fill(p.gradient)
                .shadow(color: p.glow, radius: p.glowRadius, x: 0, y: 0)
        } else {
            Capsule().fill(Color.white.opacity(0.05))
        }
    }
}

/// Avatar circle (`ct` in the bundle) without a picture: white 7 % with the
/// default person icon (46 % of the size) in --acc-pale. On the podium a 2 pt
/// ring in the accent at 70 % with a soft glow; place 1 also glows amber.
/// Profile pictures and equipped icons are not in the entry model.
private struct BoardAvatar: View {
    let diameter: CGFloat
    let hasRing: Bool
    let hasAmberGlow: Bool
    var url: URL? = nil

    var body: some View {
        placeholder
            .overlay(picture)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(Color.white.opacity(0.07)))
            .overlay(ring)
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: diameter * 0.46))
            .foregroundColor(BoardColors.accentPale)
            .frame(width: diameter, height: diameter)
    }

    /// The profile picture, if the player has one - WebP loads natively on iOS 14+.
    @ViewBuilder
    private var picture: some View {
        if let u = url {
            AsyncImage(url: u) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var ring: some View {
        if hasRing {
            Circle()
                .strokeBorder(Palette.accent.opacity(0.7), lineWidth: 2)
                .shadow(color: Palette.accent.opacity(0.3), radius: 5, x: 0, y: 0)
                .shadow(color: hasAmberGlow ? BoardColors.amber.opacity(0.35) : Color.clear, radius: 6, x: 0, y: 0)
        }
    }
}

// MARK: - Building blocks

/// Medal colors for places 1-3 (`x3` in the bundle): 135° gradient, glow, border.
private struct BoardPodium {
    let gradient: LinearGradient
    let glow: Color
    let glowRadius: CGFloat
    let border: Color

    static func forRank(_ rank: Int) -> BoardPodium? {
        switch rank {
        case 1:
            return BoardPodium(gradient: diagonal(0xF59E0B, 0xFBBF24),
                               glow: Color(hex: 0xF59E0B).opacity(0.55), glowRadius: 7,
                               border: Color(hex: 0xF59E0B).opacity(0.55))
        case 2:
            return BoardPodium(gradient: diagonal(0x9CA3AF, 0xD1D5DB),
                               glow: Color(hex: 0x9CA3AF).opacity(0.3), glowRadius: 4,
                               border: Color(hex: 0x9CA3AF).opacity(0.35))
        case 3:
            return BoardPodium(gradient: diagonal(0xB45309, 0xD97706),
                               glow: Color(hex: 0xB45309).opacity(0.3), glowRadius: 4,
                               border: Color(hex: 0xB45309).opacity(0.4))
        default:
            return nil
        }
    }

    private static func diagonal(_ from: UInt32, _ to: UInt32) -> LinearGradient {
        LinearGradient(colors: [Color(hex: from), Color(hex: to)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Values used only on this screen.
private enum BoardColors {
    static let headerFill = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.82)
    static let refreshFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    static let pill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.8)
    static let podiumFill = Color(.sRGB, red: 15 / 255, green: 13 / 255, blue: 26 / 255, opacity: 0.95)
    /// --acc-pale for the default accent, measured rgb(204,149,255).
    static var accentPale: Color { Palette.accentPale }
    static let amber = Color(hex: 0xF59E0B)
    static let ink = Color(hex: 0x07070E)
    static let red = Color(hex: 0xEF4444)
}

/// toLocaleString() in the browser: "29,841".
private enum BoardFormat {
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    static func grouped(_ value: Int) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// whileTap scale as in the browser.
private struct BoardPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// The browser's loader (`Ft`): nine 3 pt bars, 3 pt apart, accent at 55 %,
/// bottom aligned in a 20 pt box, each bobbing with its own duration and delay.
struct BoardLoadingBars: View {
    @State private var bouncing = false

    private let heights: [CGFloat] = [8, 14, 10, 18, 12, 16, 9, 13, 11]
    private let durations: [Double] = [0.55, 0.40, 0.70, 0.45, 0.60, 0.50, 0.65, 0.42, 0.58]
    private let delays: [Double] = [0.00, 0.08, 0.04, 0.12, 0.06, 0.10, 0.02, 0.14, 0.07]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<heights.count, id: \.self) { i in
                bar(i)
            }
        }
        .frame(height: 20, alignment: .bottom)
        .onAppear { bouncing = true }
    }

    private func bar(_ i: Int) -> some View {
        let motion: Animation = Animation.easeInOut(duration: durations[i] / 2)
            .repeatForever(autoreverses: true)
            .delay(delays[i])
        return Capsule()
            .fill(Palette.accent.opacity(0.55))
            .frame(width: 3, height: heights[i])
            .scaleEffect(x: 1, y: bouncing ? 0.22 : 1, anchor: .bottom)
            .animation(motion, value: bouncing)
    }
}
