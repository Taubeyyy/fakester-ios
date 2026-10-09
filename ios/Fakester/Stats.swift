import SwiftUI

/// "Stats" - opened from the profile chip on the home screen, like in the
/// browser (`QN`), for guests too. Profile card (picture, name, title, level
/// bar), six counters, the achievements row and the recent games.
/// Measurements from the website at 375 × 812 (k-stats).
struct StatsView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var details: ProfileDetails?
    @State private var historyLoaded = false
    @State private var tally: AchievementTally?
    @State private var titleName: String = "Newbie"
    @State private var titleTint: Color = Palette.foreground
    @State private var awardsOpen = false

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Stats", onBack: { close() })
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileCard
                        counters
                        achievementsRow
                        recentGames
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await load() }
        .fullScreenCover(isPresented: $awardsOpen) {
            QuestsView()
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: Data

    private var xp: Int { api.me?.xp ?? 0 }
    private var games: Int { api.me?.games_played ?? 0 }
    private var wins: Int { api.me?.wins ?? 0 }
    private var winRate: Int { games > 0 ? Int((Double(wins) / Double(games) * 100).rounded()) : 0 }
    private var podiums: Int { (details?.history ?? []).filter { r in (r.placement ?? 0) >= 1 && (r.placement ?? 0) <= 3 }.count }

    @MainActor
    private func load() async {
        guard api.isLoggedIn else {
            historyLoaded = true
            return
        }
        async let profile: ProfileDetails? = try? await api.fetch("/profile")
        async let achievements: AchievementTally? = try? await api.fetch("/achievements")
        async let catalog: StatsTitleCatalog? = try? await api.fetchAbsolute("https://fakester.app/catalog.json")
        details = await profile
        historyLoaded = true
        tally = await achievements
        if let c = await catalog, let t = c.title(id: api.me?.equipped_title_id ?? 1) {
            titleName = t.name
            if let tint = t.tint { titleTint = tint }
        }
    }

    // MARK: Profile card

    /// px 16 py 16, gap 16, rgba(24,23,39,.92), border accent 22 %, corners 16.
    private var profileCard: some View {
        let level: Int = Api.Level.forXP(xp)
        let low: Int = Api.Level.minXP(level)
        let high: Int = Api.Level.minXP(level + 1)
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 16) {
            StatsAvatar(url: avatarURL)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(api.identity?.username ?? "")
                        .font(.brand(20, .heavy))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                    if api.me?.is_pro == true { proBadge }
                }
                Text(titleName.uppercased())
                    .font(.brand(10, .bold))
                    .tracking(0.5)
                    .foregroundColor(titleTint)
                    .padding(.horizontal, 8)
                    .padding(.top, 3)
                    .padding(.bottom, 1)
                    .background(RoundedRectangle(cornerRadius: 12, style: .circular).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .circular).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                HStack {
                    Text("Level \(level)").font(.system(size: 10, weight: .bold))
                    Spacer(minLength: 0)
                    Text("\(max(0, xp - low)) / \(max(1, high - low)) XP").font(.system(size: 10).monospacedDigit())
                }
                .foregroundColor(Palette.subdued)
                .padding(.bottom, 4)
                StatsBar(fraction: Api.Level.fraction(xp: xp), height: 8, fill: AnyShapeStyle(Palette.accent))
            }
        }
        .padding(16)
        .background(shape.fill(Palette.card).shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4))
        .overlay(shape.strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1))
    }

    private var avatarURL: URL? {
        guard let p = api.me?.avatar_url, !p.isEmpty else { return nil }
        if p.hasPrefix("http") { return URL(string: p) }
        return URL(string: "https://fakester.app" + (p.hasPrefix("/") ? p : "/" + p))
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .black))
            .foregroundColor(Color(hex: 0x2A1400))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFBE48), Color(hex: 0xE89211)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    // MARK: Counters

    private var counters: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                StatTile(label: "Games", value: number(games), symbol: "gamecontroller")
                StatTile(label: "Wins", value: number(wins), symbol: "crown", accent: Palette.gold)
                StatTile(label: "Win rate", value: "\(winRate)%", symbol: "chart.line.uptrend.xyaxis",
                         accent: winRate >= 50 ? Palette.good : nil)
            }
            HStack(alignment: .top, spacing: 8) {
                StatTile(label: "Podiums", value: "\(podiums)", symbol: "trophy", sub: "last 20")
                StatTile(label: "Highscore", value: number(api.me?.highscore ?? 0), symbol: "star", accent: Palette.accent)
                StatTile(label: "Correct", value: number(details?.correctAnswers ?? 0), symbol: "checkmark")
            }
        }
    }

    // MARK: Achievements

    /// 58 tall, amber icon tile, bar in an amber gradient, "unlocked / total".
    private var achievementsRow: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let claimable: Int = tally?.claimable ?? 0
        let fraction: Double = (tally?.total ?? 0) > 0 ? Double(tally?.unlocked ?? 0) / Double(tally?.total ?? 1) : 0
        let amber = Color(hex: 0xF59E0B)
        return Button {
            guard api.isLoggedIn else { return }
            Haptics.tap()
            awardsOpen = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.gold)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 12, style: .circular).fill(amber.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .circular).strokeBorder(amber.opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Achievements")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Palette.foreground)
                    StatsBar(fraction: fraction, height: 6,
                             fill: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xB45309), Palette.gold],
                                                                startPoint: .leading, endPoint: .trailing)))
                }
                if claimable > 0 {
                    Text("\(claimable) to claim")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Palette.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(amber.opacity(0.2)))
                }
                Text(tally.map { "\($0.unlocked) / \($0.total)" } ?? "—")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundColor(Palette.gold)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.subdued)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(shape.fill(Palette.card))
            .overlay(shape.strokeBorder(claimable > 0 ? amber.opacity(0.45) : Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Recent games

    private var recentGames: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1).fill(Palette.accent).frame(width: 2, height: 14)
                Text("RECENT GAMES")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(Palette.subdued)
            }
            history
        }
    }

    @ViewBuilder
    private var history: some View {
        let records: [GameRecord] = details?.history ?? []
        if !historyLoaded {
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .circular).fill(Color.white.opacity(0.04)).frame(height: 64)
                }
            }
        } else if records.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: 0x2A2848))
                Text("No games played yet.")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subdued)
                Button {
                    close()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play").font(.system(size: 12, weight: .semibold))
                        Text("Play your first game").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Palette.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(spacing: 8) {
                ForEach(records) { r in GameRecordRow(record: r) }
                Text("Your last \(records.count) games")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: 0x3A3A55))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private func number(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Pieces

/// 64 circle, white 7 %, ring 2 pt accent 70 % with a glow; the profile picture
/// if there is one, otherwise the person in --acc-pale.
private struct StatsAvatar: View {
    let url: URL?

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: 0xCC95FF))
            if let u = url {
                AsyncImage(url: u) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .clipShape(Circle())
            }
        }
        .frame(width: 64, height: 64)
        .overlay(Circle().strokeBorder(Palette.accent.opacity(0.7), lineWidth: 2))
        .shadow(color: Palette.accent.opacity(0.3), radius: 5)
    }
}

/// A rounded bar on white 7 %.
private struct StatsBar: View {
    let fraction: Double
    let height: CGFloat
    let fill: AnyShapeStyle

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule().fill(fill)
                    .frame(width: box.size.width * CGFloat(min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
    }
}

/// `Qr`: icon 11, value 20 extra bold, label 10 bold uppercase spaced, optional sub.
private struct StatTile: View {
    let label: String
    let value: String
    let symbol: String
    var sub: String? = nil
    var accent: Color? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor((accent ?? Palette.subdued).opacity(0.9))
            Text(value)
                .font(.brand(20, .heavy))
                .foregroundColor(accent ?? Palette.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(Palette.subdued)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let s = sub {
                Text(s).font(.system(size: 10)).foregroundColor(Palette.subdued)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(shape.fill(Palette.card))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }
}

/// A finished game: placement circle (medal gradient for 1-3), playlist,
/// "Quiz · Today · 3 players", score with "+31 XP" and "+89 ♪". A win gets
/// the amber card.
private struct GameRecordRow: View {
    let record: GameRecord

    var body: some View {
        let win: Bool = record.placement == 1
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        HStack(spacing: 12) {
            placementCircle
            VStack(alignment: .leading, spacing: 2) {
                Text(record.playlistName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.subdued)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.score)")
                    .font(.brand(14, .heavy))
                    .foregroundColor(Palette.foreground)
                HStack(spacing: 8) {
                    Text("+\(record.xpGained) XP").foregroundColor(Palette.accent)
                    if record.spotsGained > 0 {
                        Text("+\(record.spotsGained) ♪").foregroundColor(Palette.good)
                    }
                }
                .font(.system(size: 10, weight: .bold).monospacedDigit())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(shape.fill(win ? Color(.sRGB, red: 30 / 255, green: 22 / 255, blue: 6 / 255, opacity: 0.75)
                                   : Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
        .overlay(shape.strokeBorder(win ? Color(hex: 0xF59E0B).opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1))
    }

    private var subtitle: String {
        let mode: String = PublicLobby.modeLabel(record.mode)
        let players: String = "\(record.totalPlayers) " + (record.totalPlayers == 1 ? "player" : "players")
        let when: String = GameRecord.relative(record.playedAt)
        return [mode, when, players].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    @ViewBuilder
    private var placementCircle: some View {
        let label: String = record.placement.map { "\($0)" } ?? "–"
        let medal: [Color]? = StatsMedals.colors(record.placement)
        Text(label)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(medal == nil ? Palette.subdued : Color(hex: 0x07070E))
            .frame(width: 32, height: 32)
            .background(
                Circle().fill(medal.map { AnyShapeStyle(LinearGradient(colors: $0, startPoint: .topLeading, endPoint: .bottomTrailing)) }
                              ?? AnyShapeStyle(Color.white.opacity(0.06)))
            )
    }
}

private enum StatsMedals {
    /// `XN` in the bundle: gold, silver, bronze.
    static func colors(_ place: Int?) -> [Color]? {
        switch place {
        case 1: return [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)]
        case 2: return [Color(hex: 0x9CA3AF), Color(hex: 0xD1D5DB)]
        case 3: return [Color(hex: 0xB45309), Color(hex: 0xD97706)]
        default: return nil
        }
    }
}

/// Just the titles of catalog.json - for the title pill on the profile card.
private struct StatsTitleCatalog: Decodable {
    struct Title: Decodable {
        let id: String
        let name: String
        let colorHex: String?

        private enum CodingKeys: String, CodingKey { case id, name, colorHex }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(LooseValue.self, forKey: .id).text
            name = (try? c.decode(String.self, forKey: .name)) ?? ""
            colorHex = try? c.decode(String.self, forKey: .colorHex)
        }

        /// A plain "#rrggbb" colour; gradients keep the default text colour.
        var tint: Color? {
            guard let h = colorHex, h.hasPrefix("#"), h.count == 7, let v = UInt32(h.dropFirst(), radix: 16) else { return nil }
            return Color(hex: v)
        }
    }
    private struct Items: Decodable {
        let title: [Title]
        private enum CodingKeys: String, CodingKey { case title }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            title = (try? c.decode(LenientArray<Title>.self, forKey: .title))?.items ?? []
        }
    }
    private let items: Items

    func title(id: Int) -> Title? { items.title.first { $0.id == "\(id)" } }
}
