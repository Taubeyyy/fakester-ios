import SwiftUI

/// Die Rundenauflösung, nach dem Browser nachgebaut: erst der enthuellte Song,
/// dann die eigene Zeile mit Punkten, dann pro Rateart eine Zeile
/// "deine Antwort → die richtige".
///
/// Dass die eigene Antwort dabei steht, ist der eigentliche Wert dieses
/// Bildschirms. Bei einer falschen Antwort ist genau das die Frage, die man
/// sich stellt - und der Server schickt sie ohnehin mit (`ownAnswer`).
struct RevealView: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    if let t = game.outcome?.correctTrack {
                        RevealedTrackCard(heading: t)
                        MyRoundCard(heading: t)
                    } else if game.outcome?.sneaky == true {
                        concealed
                    }
                    Scoreboard(player: game.player, ownId: game.ownId, hostId: game.hostId)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            HStack(spacing: 9) {
                WaveBars(hue: Palette.accent)
                Text("Next round coming up…")
                    .font(.brand(13, .semibold))
                    .foregroundColor(Palette.faint)
            }
            .padding(.bottom, 14)
        }
        .onAppear {
            let pointsEarned: Int = game.me?.lastPointsBreakdown?.total ?? 0
            if pointsEarned > 0 { Haptics.correct() } else { Haptics.wrong() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("ROUND")
                .font(.brand(13, .heavy)).tracking(0.8)
                .foregroundColor(Palette.accent)
            Text("\(game.activeRound?.round ?? 0)")
                .font(.brand(13, .black))
                .foregroundColor(Palette.foreground)
            Text("/ \(game.activeRound?.totalRounds ?? 0) · \("Results")")
                .font(.brand(13, .heavy))
                .foregroundColor(Palette.faint)
            Spacer(minLength: 0)
            LeaveButton { game.leave() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var concealed: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("SNEAKY MODE").eyebrow()
                Text("The song stays hidden. Everything drops at the end.")
                    .font(.brand(14, .medium))
                    .foregroundColor(Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// „NOW REVEALED": Cover mit Jahres-Pille, Titel gross, Interpret darunter.
struct RevealedTrackCard: View {
    let heading: Track

    var body: some View {
        Card(inset: 14) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottom) {
                    Cover(address: heading.albumArt, rim: 72)
                    if let j = heading.year {
                        Text(String(j))
                            .font(.mono(10))
                            .foregroundColor(Palette.onAccent)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.accent))
                            .offset(y: 7)
                    }
                }
                .padding(.bottom, 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text("NOW REVEALED").eyebrow()
                    Text(heading.title)
                        .font(.brand(21, .black))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(heading.artist)
                        .font(.brand(14, .medium))
                        .foregroundColor(Palette.subdued)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Die eigene Zeile: Punkte oben, darunter pro Rateart was man getippt hat und
/// was richtig gewesen waere.
struct MyRoundCard: View {
    @EnvironmentObject private var game: Game
    let heading: Track

    var body: some View {
        if let panel = game.me?.lastPointsBreakdown, !panel.breakdown.isEmpty {
            Card(inset: 14) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Text("YOUR ROUND").eyebrow()
                        Spacer(minLength: 0)
                        Text(panel.total > 0 ? "+\(panel.total)" : "+0")
                            .font(.brand(15, .black))
                            .foregroundColor(panel.total > 0 ? Palette.good : Palette.faint)
                        Text("\(game.me?.score ?? 0)")
                            .font(.mono(15))
                            .foregroundColor(Palette.foreground)
                    }

                    VStack(spacing: 7) {
                        ForEach(BreakdownOrder.ordered(panel.breakdown), id: \.category) { e in
                            BreakdownRow(category: e.category, amount: e.amount,
                                  mine: panel.ownAnswer?[e.category]?.text,
                                  correct: correctAnswer(e.category))
                        }
                    }
                }
            }
        }
    }

    private func correctAnswer(_ kind: String) -> String? {
        switch kind {
        case "title":  return heading.title
        case "artist": return heading.artist
        case "year":   return heading.year.map { String($0) }
        default:       return nil      // speed und streak haben keine Antwort
        }
    }

    @ViewBuilder
    private func BreakdownRow(category: String, amount: ScoreItem, mine: String?, correct: String?) -> some View {
        let isHit: Bool = amount.points > 0
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill((isHit ? Palette.good : Palette.bad).opacity(0.14))
                Image(systemName: isHit ? "checkmark" : "xmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(isHit ? Palette.good : Palette.bad)
            }
            .frame(width: 22, height: 22)

            Text(DisplayName.guessKind(category))
                .font(.brand(13, .heavy))
                .foregroundColor(Palette.subdued)
                .frame(width: 66, alignment: .leading)

            if let correct, !isHit {
                // Nur bei einem Fehler lohnt der Vergleich. Bei einem Treffer
                // waere "Api → Api" nur Rauschen.
                Text(mine?.isEmpty == false ? (mine ?? "") : "NO ANSWER")
                    .font(.brand(12, .semibold))
                    .foregroundColor(Palette.faint)
                    .strikethrough(mine?.isEmpty == false)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Palette.faint)
                Text(correct)
                    .font(.brand(13, .heavy))
                    .foregroundColor(Palette.good)
                    .lineLimit(1)
            } else {
                Text(amount.text)
                    .font(.brand(13, .semibold))
                    .foregroundColor(isHit ? Palette.foreground : Palette.faint)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(isHit ? "+\(amount.points)" : "0")
                .font(.mono(12))
                .foregroundColor(isHit ? Palette.good : Palette.faint)
        }
    }
}

/// Der laufende Stand als Liste. Erster Platz in Gold, man selbst hervorgehoben.
struct Scoreboard: View {
    let player: [Player]
    let ownId: String
    var hostId: String?

    var body: some View {
        Card(inset: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SCOREBOARD").eyebrow()
                ForEach(Array(player.enumerated()), id: \.element.id) { standing, s in
                    StandingRow(standing: standing + 1, player: s,
                               isMe: s.id.text == ownId,
                               isHost: s.id.text == hostId)
                }
            }
        }
    }
}

struct StandingRow: View {
    let standing: Int
    let player: Player
    var isMe = false
    var isHost = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(standing == 1 ? AnyShapeStyle(Palette.gradientGold)
                                         : AnyShapeStyle(Palette.muted))
                Text("\(standing)")
                    .font(.brand(12, .black))
                    .foregroundColor(standing == 1 ? Palette.onGold : Palette.subdued)
            }
            .frame(width: 26, height: 26)

            Text(player.emoji ?? "🎵").font(.system(size: 15))

            Text(player.nickname)
                .font(.brand(14, isMe ? .black : .semibold))
                .foregroundColor(player.isEliminated ? Palette.faint : (isMe ? Palette.accent : Palette.foreground))
                .strikethrough(player.isEliminated)
                .lineLimit(1)

            if isHost { MiniBadge(text: "HOST", hue: Palette.accent) }
            if !player.isConnected { MiniBadge(text: "AWAY", hue: Palette.bad) }

            Spacer(minLength: 4)

            Text("\(player.score)")
                .font(.mono(15))
                .foregroundColor(standing == 1 ? Palette.gold : Palette.foreground)
        }
    }
}

// MARK: - Endstand

struct GameOverView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    headline
                    Scoreboard(player: game.player, ownId: game.ownId, hostId: game.hostId)
                    if let tracks = game.finalStandings?.songs, !tracks.isEmpty { SongList(tracks: tracks) }
                    if api.identity?.isGuest ?? true { guestNotice }
                    if let b = myReward { RewardTiles(prize: b) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }

            VStack(spacing: 9) {
                Button {
                    Haptics.tap()
                    game.returnToLobby()
                } label: {
                    Label("Back to lobby", systemImage: "arrow.uturn.left")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Main menu") { game.leave() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var myRank: Int {
        (game.player.firstIndex { $0.id.text == game.ownId } ?? 0) + 1
    }

    private var myReward: Reward? {
        game.player.first { $0.id.text == game.ownId }?.rewards
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text("GAME OVER")
                .font(.brand(38, .black))
                .tracking(-1)
                .foregroundColor(.clear)
                .overlay { Palette.gradientHero.mask { Text("GAME OVER").font(.brand(38, .black)).tracking(-1) } }
                .shadow(color: Palette.accent.opacity(0.35), radius: 18, y: 6)

            HStack(spacing: 5) {
                Text("You finished")
                    .foregroundColor(Palette.faint)
                Text("#\(myRank)")
                    .foregroundColor(Palette.accent)
                Text("with")
                    .foregroundColor(Palette.faint)
                Text("\(game.me?.score ?? 0) pts")
                    .foregroundColor(Palette.accent)
            }
            .font(.brand(13, .heavy))
        }
        .padding(.bottom, 2)
    }

    private var guestNotice: some View {
        Card(inset: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Palette.gold)
                    Text("Playing as a guest").eyebrow()
                }
                Text("This round was not saved. With an account it would have counted.")
                    .font(.brand(13, .medium))
                    .foregroundColor(Palette.subdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.gold.opacity(0.35), lineWidth: 1)
        )
    }
}

struct RewardTiles: View {
    let prize: Reward

    var body: some View {
        HStack(spacing: 10) {
            MiniTile(amount: prize.xp, word: "XP", symbol: "star", hue: Palette.accent)
            MiniTile(amount: prize.spots, word: "SPOTS", symbol: "music.note", hue: Palette.good)
            MiniTile(amount: prize.goldSpots, word: "GS", symbol: "trophy", hue: Palette.gold)
        }
    }

    @ViewBuilder
    private func MiniTile(amount: Int, word: String, symbol: String, hue: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(hue)
            Text("+\(amount)")
                .font(.brand(19, .black))
                .foregroundColor(hue)
            Text(word).eyebrow()
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(GlassPanel(radius: 16))
    }
}

struct SongList: View {
    let tracks: [Track]

    var body: some View {
        Card(inset: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "eye")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Palette.accent)
                    Text("WHAT WAS PLAYING").eyebrow()
                }
                ForEach(Array(tracks.enumerated()), id: \.offset) { i, t in
                    HStack(spacing: 10) {
                        Text("\(i + 1)")
                            .font(.mono(11, isBold: false))
                            .foregroundColor(Palette.faint)
                            .frame(width: 14, alignment: .leading)
                        Cover(address: t.albumArt, rim: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.title)
                                .font(.brand(13, .heavy))
                                .foregroundColor(Palette.foreground)
                                .lineLimit(1)
                            Text(t.artist)
                                .font(.brand(11, .medium))
                                .foregroundColor(Palette.faint)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let j = t.year {
                            Text(String(j))
                                .font(.mono(11))
                                .foregroundColor(Palette.subdued)
                        }
                    }
                }
            }
        }
    }
}

/// Kleines Cover fuer Listen und die Auflösung.
struct Cover: View {
    let address: String?
    var rim: CGFloat = 72

    var body: some View {
        Group {
            if let address, let url = URL(string: address) {
                AsyncImage(url: url) { picture in
                    picture.resizable().scaledToFill()
                } placeholder: {
                    Palette.muted
                }
            } else {
                ZStack {
                    Palette.muted
                    Image(systemName: "music.note")
                        .font(.system(size: rim * 0.3))
                        .foregroundColor(Palette.faint)
                }
            }
        }
        .frame(width: rim, height: rim)
        .clipShape(RoundedRectangle(cornerRadius: rim * 0.17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: rim * 0.17, style: .continuous)
                .strokeBorder(Palette.border, lineWidth: 1)
        )
    }
}

/// Die Aufstellung kommt als Woerterbuch - ohne feste Reihenfolge springt sie
/// sonst bei jeder Runde um.
enum BreakdownOrder {
    struct Entry { let category: String; let amount: ScoreItem }

    private static let order = ["title", "artist", "year", "speed", "streak"]

    static func ordered(_ bd: [String: ScoreItem]) -> [Entry] {
        bd.map { Entry(category: $0.key, amount: $0.value) }
          .sorted { a, b in
              let ia = order.firstIndex(of: a.category) ?? order.count
              let ib = order.firstIndex(of: b.category) ?? order.count
              return ia == ib ? a.category < b.category : ia < ib
          }
    }
}
