import SwiftUI

/// A tile in the lobby's PLAYERS grid, measured on fakester.app (375×812):
/// 80×113, corners 16, padding 10. Round picture (40); for the host the gold
/// "Host" badge on the picture and "♛ CREATOR" above the name; the name 10 pt
/// bold in purple. Your own tile has a purple fill and outline, the others are
/// almost invisible. Anyone who lost the connection fades out. The host sees a
/// small red × at the top right of every other tile to kick that player.
struct PlayerTile: View {
    let player: Player
    var isHost = false
    var isMe = false
    /// Height of the grid row - in the browser all tiles in a row are equally
    /// tall (the CSS grid stretches them). 0 = as tall as the content.
    var frameHeight: CGFloat = 0
    /// Host only, on everyone else's tile: removes the player. nil = no button.
    var onKick: (() -> Void)? = nil

    /// The natural height without stretching, with the same line heights as in
    /// the browser (padding 10 + border 1, picture 40, spacing 6, name 15 ...).
    static func frameHeight(player: Player, isHost: Bool) -> CGFloat {
        var h: CGFloat = 11 + 40 + 6 + 15 + 11
        if isHost { h += 14 }
        if !player.isConnected {
            h += 15.5
        } else if player.isPro {
            h += 13
        }
        return h
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let base: Color = isMe ? Palette.accentDeep.opacity(0.15) : Color.white.opacity(0.025)
        let outline: Color = isMe ? Palette.accent.opacity(0.45) : Palette.border
        return VStack(spacing: 6) {
            picture
            caption
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: frameHeight, alignment: .top)
        .background(shape.fill(base))
        .overlay(shape.strokeBorder(outline, lineWidth: 1))
        .overlay(alignment: .topTrailing) { kickButton }
        .opacity(player.isConnected ? 1 : 0.45)
    }

    /// As in the browser: 20×20, 4 inside the edge at the top right, red 15 %
    /// (rgba(239,68,68,.15)) with lucide x 9 in #f87171. Its corners are
    /// rounded-lg (.875rem = 14) - on 20×20 that is a circle. The tap area is
    /// 32×32 around it; the label names the player.
    @ViewBuilder
    private var kickButton: some View {
        if let kick = onKick {
            Button(action: kick) {
                LucideGlyph(icon: .x, size: 9)
                    .foregroundColor(Palette.bad)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(PlayerTilePalette.kickFill))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Kick \(player.nickname)"))
            // centre of the 20 circle 15 from the top and right edge, as in the browser
            .offset(x: 1, y: -1)
        }
    }

    private var picture: some View {
        LobbyAvatar(player: player, dimension: 40)
            .overlay(alignment: .topTrailing) {
                if isHost {
                    hostBadge.offset(x: 4, y: -4)
                }
            }
    }

    private var caption: some View {
        VStack(spacing: 0) {
            if isHost {
                creator.padding(.bottom, 2)
            }
            Text(player.nickname)
                .font(.brand(10, .bold))
                .foregroundColor(Palette.accent)
                .lineLimit(1)
                .frame(height: 15)
            statusLine
        }
        .frame(maxWidth: .infinity)
    }

    /// "Host": 8 pt bold, #07070e on #f59e0b, at the picture's top right (-4/-4).
    private var hostBadge: some View {
        Text("Host")
            .font(.brand(8, .bold))
            .foregroundColor(Palette.base)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4)
            .frame(height: 12)
            .background(Capsule().fill(PlayerTilePalette.amber))
    }

    private var creator: some View {
        HStack(spacing: 2) {
            Image(systemName: "crown")
                .font(.system(size: 6, weight: .semibold))
            Text("CREATOR")
                .font(.brand(8, .bold))
                .lineLimit(1)
        }
        .foregroundColor(PlayerTilePalette.amber)
        .frame(height: 12)
    }

    @ViewBuilder
    private var statusLine: some View {
        if !player.isConnected {
            Text("RECONNECTING…")
                .font(.brand(9, .bold))
                .tracking(0.45)
                .foregroundColor(PlayerTilePalette.amber)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 13.5)
                .padding(.top, 2)
        } else if player.isPro {
            // PRO badge: crown 11, #fbbf24
            Image(systemName: "crown")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Palette.gold)
                .frame(height: 11)
                .padding(.top, 2)
        }
    }
}

/// The round player picture as in the browser: white 7 % as the base, inside it
/// the profile picture - otherwise the player icon in light purple (--acc-pale),
/// and anyone without an icon gets the first letter of their name.
struct LobbyAvatar: View {
    let player: Player?
    var name: String = ""
    let dimension: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(imageURL == nil ? 0.07 : 0.05))
            if let url = imageURL {
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

    private var imageURL: URL? {
        guard let s = player?.avatarUrl, s.hasPrefix("http") else { return nil }
        return URL(string: s)
    }

    @ViewBuilder
    private var fallback: some View {
        if let s = player, s.iconId != 0 {
            Image(systemName: "person.fill")
                .font(.system(size: dimension * 0.44))
                .foregroundColor(PlayerTilePalette.pale)
        } else {
            Text(start)
                .font(.brand(dimension * 0.42, .bold))
                .foregroundColor(Palette.foreground)
        }
    }

    private var start: String {
        let n: String = player?.nickname ?? name
        guard let c = n.first else { return "?" }
        return String(c).uppercased()
    }
}

/// Colors that only appear here.
private enum PlayerTilePalette {
    /// #f59e0b - "Host", "CREATOR", "RECONNECTING…"
    static let amber = Color(hex: 0xF59E0B)
    /// --acc-pale for #b15cff
    static let pale = Color(hex: 0xCC95FF)
    /// The kick button: rgba(239,68,68,.15)
    static let kickFill = Color(hex: 0xEF4444).opacity(0.15)
}

/// A row in lists (.result-score-row): dark surface, rank, name, points.
struct PlayerRow: View {
    let player: Player
    var isHost = false
    var isMe = false
    var pointsEarned: Bool = false
    var standing: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let standing {
                RankCircle(standing: standing, dimension: 26)
            } else {
                Text(player.emoji ?? "🎵")
                    .font(.system(size: 14))
                    .frame(width: 26, height: 26)
                    .background(Palette.secondary, in: Circle())
            }

            Text(player.nickname)
                .font(.brand(14, isMe ? .heavy : .bold))
                .foregroundColor(player.isEliminated ? Palette.faint : Palette.foreground)
                .strikethrough(player.isEliminated)
                .lineLimit(1)

            if isHost { StatusBadge("HOST", Palette.gold) }
            if player.isBot { StatusBadge("BOT", Palette.rim) }
            if !player.isConnected { StatusBadge("AWAY", Palette.bad) }
            if player.watchOnly { StatusBadge("WATCHING", Palette.rim) }

            Spacer(minLength: 4)

            if pointsEarned {
                Text("\(player.score)")
                    .font(.mono(15))
                    .foregroundColor(Palette.accent)
            } else if player.isReady {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Palette.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.muted))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(isMe ? Palette.accentDeep.opacity(0.7) : Palette.border, lineWidth: 1))
    }

    @ViewBuilder
    private func StatusBadge(_ text: String, _ hue: Color) -> some View {
        Text(text)
            .font(.brand(9, .heavy))
            .tracking(0.6)
            .foregroundColor(hue == Palette.rim ? Palette.subdued : Palette.base)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(hue, in: Capsule())
    }
}

/// Round rank badge (.result-rank / .end-rank): first place in gold.
struct RankCircle: View {
    let standing: Int
    var dimension: CGFloat = 30

    var body: some View {
        let isFirst: Bool = standing == 1
        Text("\(standing)")
            .font(.mono(dimension * 0.44))
            .foregroundColor(isFirst ? Palette.onGold : Palette.subdued)
            .frame(width: dimension, height: dimension)
            .background(Circle().fill(isFirst ? AnyShapeStyle(Palette.gradientGold) : AnyShapeStyle(Palette.secondary)))
            .shadow(color: isFirst ? Palette.gold.opacity(0.32) : .clear, radius: 5)
    }
}

/// At the top of every game screen (.game-header-top): on the left where you
/// are, on the right the red leave button.
struct GameHeader: View {
    let heading: String
    var subtitle: String?
    var pin: String? = nil
    var kept: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(heading.uppercased())
                    .font(.brand(15, .heavy))
                    .tracking(0.6)
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let pin, !pin.isEmpty { PinBadge(pin: pin) }
                    if let u = subtitle {
                        Text(u)
                            .font(.brand(12, .semibold))
                            .foregroundColor(Palette.subdued)
                    }
                }
            }
            Spacer()
            if let kept { LeaveButton(onTap: kept) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

/// .lobby-pin-badge: "PIN 1234" in DM Mono, purple border and ring.
struct PinBadge: View {
    let pin: String

    var body: some View {
        HStack(spacing: 6) {
            Text("PIN")
                .font(.mono(12))
                .tracking(1.2)
                .foregroundColor(Palette.accentDeep)
            Text(pin)
                .font(.mono(14))
                .tracking(2.1)
                .foregroundColor(Palette.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Palette.accentDim))
        .overlay(Capsule().strokeBorder(Palette.accentDeep, lineWidth: 1))
        .overlay(Capsule().stroke(Palette.accent.opacity(0.22), lineWidth: 3).padding(-2))
    }
}

/// The server picks and checks the songs - that takes a while, and without
/// anything on screen it looks as if the game were stuck.
struct LoadingView: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        VStack(spacing: 18) {
            if let z = game.countdownNumber {
                // .countdown-number: huge, purple gradient, glowing
                Text("\(z)")
                    .font(.brand(150, .black))
                    .tracking(-7)
                    .foregroundColor(.clear)
                    .overlay(Palette.gradient.mask { Text("\(z)").font(.brand(150, .black)).tracking(-7) })
                    .shadow(color: Palette.accent.opacity(0.36), radius: 24)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .id(z)
            } else {
                ProgressView().tint(Palette.accent).scaleEffect(1.3)
                Text(game.loadingText.isEmpty ? "Loading songs…" : game.loadingText)
                    .font(.brand(15, .semibold))
                    .foregroundColor(Palette.foreground)

                if let l = game.loadProgress, l.total > 0 {
                    VStack(spacing: 6) {
                        ProgressBar(fraction: Double(l.checked) / Double(l.total))
                            .frame(width: 220)
                        Text("\(l.playable) playable of \(l.checked) checked")
                            .font(.mono(12, isBold: false))
                            .foregroundColor(Palette.subdued)
                    }
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: game.countdownNumber)
    }
}

/// .timer-wrap / .timer-bar: thin bar with a purple gradient and glow.
struct ProgressBar: View {
    let fraction: Double
    var hue: Color? = nil
    /// The round line at the top is thinner than the bar inside a card.
    var frameHeight: CGFloat = 6

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.muted)
                Capsule()
                    .fill(hue.map { AnyShapeStyle($0) } ?? AnyShapeStyle(Palette.gradientHero))
                    .frame(width: box.size.width * CGFloat(max(0, min(1, fraction))))
                    .shadow(color: (hue ?? Palette.accent).opacity(0.4), radius: 5)
            }
        }
        .frame(height: frameHeight)
    }
}

enum DisplayName {
    static func guessKind(_ k: String) -> String {
        switch k {
        case "title":  return "Title"
        case "artist": return "Artist"
        case "year":   return "Year"
        default:       return k
        }
    }

    static func playMode(_ k: String) -> String {
        switch k {
        case "quiz":     return "Quiz"
        case "survival": return "Survival"
        case "race":     return "Race"
        case "timeline": return "Timeline"
        case "hl":       return "Higher / Lower"
        case "reverse":  return "Reverse"
        default:         return k.capitalized
        }
    }
}
