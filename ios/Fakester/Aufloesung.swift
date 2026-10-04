import SwiftUI

/// Die Rundenauflösung, nach dem Browser nachgebaut: erst der enthuellte Song,
/// dann die eigene Zeile mit Punkten, dann pro Rateart eine Zeile
/// "deine Antwort → die richtige".
///
/// Dass die eigene Antwort dabei steht, ist der eigentliche Wert dieses
/// Bildschirms. Bei einer falschen Antwort ist genau das die Frage, die man
/// sich stellt - und der Server schickt sie ohnehin mit (`ownAnswer`).
struct AufloesungAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            kopf

            ScrollView {
                VStack(spacing: 14) {
                    if let t = spiel.ergebnis?.correctTrack {
                        EnthuelltKarte(titel: t)
                        EigeneRunde(titel: t)
                    } else if spiel.ergebnis?.sneaky == true {
                        verdeckt
                    }
                    Rangliste(spieler: spiel.spieler, eigeneId: spiel.eigeneId, hostId: spiel.hostId)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            HStack(spacing: 9) {
                Wellen(farbe: Farbe.akzent)
                Text("Next round coming up…")
                    .font(.marke(13, .semibold))
                    .foregroundColor(Farbe.leise)
            }
            .padding(.bottom, 14)
        }
        .onAppear {
            let punkte: Int = spiel.ich?.lastPointsBreakdown?.total ?? 0
            if punkte > 0 { Spuerbar.richtig() } else { Spuerbar.falsch() }
        }
    }

    private var kopf: some View {
        HStack(spacing: 8) {
            Text("ROUND")
                .font(.marke(13, .heavy)).tracking(0.8)
                .foregroundColor(Farbe.akzent)
            Text("\(spiel.runde?.round ?? 0)")
                .font(.marke(13, .black))
                .foregroundColor(Farbe.schrift)
            Text("/ \(spiel.runde?.totalRounds ?? 0) · \("Results")")
                .font(.marke(13, .heavy))
                .foregroundColor(Farbe.leise)
            Spacer(minLength: 0)
            RausKnopf { spiel.verlassen() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var verdeckt: some View {
        Karte {
            VStack(alignment: .leading, spacing: 6) {
                Text("SNEAKY MODE").etikett()
                Text("The song stays hidden. Everything drops at the end.")
                    .font(.marke(14, .medium))
                    .foregroundColor(Farbe.schrift)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// „NOW REVEALED": Cover mit Jahres-Pille, Titel gross, Interpret darunter.
struct EnthuelltKarte: View {
    let titel: Titel

    var body: some View {
        Karte(polster: 14) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottom) {
                    Cover(adresse: titel.albumArt, kante: 72)
                    if let j = titel.year {
                        Text(String(j))
                            .font(.mono(10))
                            .foregroundColor(Farbe.aufAkzent)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Farbe.akzent))
                            .offset(y: 7)
                    }
                }
                .padding(.bottom, 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text("NOW REVEALED").etikett()
                    Text(titel.title)
                        .font(.marke(21, .black))
                        .foregroundColor(Farbe.schrift)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(titel.artist)
                        .font(.marke(14, .medium))
                        .foregroundColor(Farbe.gedaempft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Die eigene Zeile: Punkte oben, darunter pro Rateart was man getippt hat und
/// was richtig gewesen waere.
struct EigeneRunde: View {
    @EnvironmentObject private var spiel: Spiel
    let titel: Titel

    var body: some View {
        if let blatt = spiel.ich?.lastPointsBreakdown, !blatt.breakdown.isEmpty {
            Karte(polster: 14) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Text("YOUR ROUND").etikett()
                        Spacer(minLength: 0)
                        Text(blatt.total > 0 ? "+\(blatt.total)" : "+0")
                            .font(.marke(15, .black))
                            .foregroundColor(blatt.total > 0 ? Farbe.gut : Farbe.leise)
                        Text("\(spiel.ich?.score ?? 0)")
                            .font(.mono(15))
                            .foregroundColor(Farbe.schrift)
                    }

                    VStack(spacing: 7) {
                        ForEach(Aufstellung.sortiert(blatt.breakdown), id: \.schluessel) { e in
                            Zeile(schluessel: e.schluessel, wert: e.wert,
                                  eigene: blatt.ownAnswer?[e.schluessel]?.text,
                                  richtig: richtigeAntwort(e.schluessel))
                        }
                    }
                }
            }
        }
    }

    private func richtigeAntwort(_ art: String) -> String? {
        switch art {
        case "title":  return titel.title
        case "artist": return titel.artist
        case "year":   return titel.year.map { String($0) }
        default:       return nil      // speed und streak haben keine Antwort
        }
    }

    @ViewBuilder
    private func Zeile(schluessel: String, wert: Bewertung, eigene: String?, richtig: String?) -> some View {
        let sass: Bool = wert.points > 0
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill((sass ? Farbe.gut : Farbe.schlecht).opacity(0.14))
                Image(systemName: sass ? "checkmark" : "xmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(sass ? Farbe.gut : Farbe.schlecht)
            }
            .frame(width: 22, height: 22)

            Text(Benennung.rateArt(schluessel))
                .font(.marke(13, .heavy))
                .foregroundColor(Farbe.gedaempft)
                .frame(width: 66, alignment: .leading)

            if let richtig, !sass {
                // Nur bei einem Fehler lohnt der Vergleich. Bei einem Treffer
                // waere "Api → Api" nur Rauschen.
                Text(eigene?.isEmpty == false ? (eigene ?? "") : "NO ANSWER")
                    .font(.marke(12, .semibold))
                    .foregroundColor(Farbe.leise)
                    .strikethrough(eigene?.isEmpty == false)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Farbe.leise)
                Text(richtig)
                    .font(.marke(13, .heavy))
                    .foregroundColor(Farbe.gut)
                    .lineLimit(1)
            } else {
                Text(wert.text)
                    .font(.marke(13, .semibold))
                    .foregroundColor(sass ? Farbe.schrift : Farbe.leise)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(sass ? "+\(wert.points)" : "0")
                .font(.mono(12))
                .foregroundColor(sass ? Farbe.gut : Farbe.leise)
        }
    }
}

/// Der laufende Stand als Liste. Erster Platz in Gold, man selbst hervorgehoben.
struct Rangliste: View {
    let spieler: [Spieler]
    let eigeneId: String
    var hostId: String?

    var body: some View {
        Karte(polster: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SCOREBOARD").etikett()
                ForEach(Array(spieler.enumerated()), id: \.element.id) { platz, s in
                    PlatzZeile(platz: platz + 1, spieler: s,
                               binIch: s.id.text == eigeneId,
                               istHost: s.id.text == hostId)
                }
            }
        }
    }
}

struct PlatzZeile: View {
    let platz: Int
    let spieler: Spieler
    var binIch = false
    var istHost = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(platz == 1 ? AnyShapeStyle(Farbe.verlaufGold)
                                         : AnyShapeStyle(Farbe.grund3))
                Text("\(platz)")
                    .font(.marke(12, .black))
                    .foregroundColor(platz == 1 ? Farbe.aufGold : Farbe.gedaempft)
            }
            .frame(width: 26, height: 26)

            Text(spieler.emoji ?? "🎵").font(.system(size: 15))

            Text(spieler.nickname)
                .font(.marke(14, binIch ? .black : .semibold))
                .foregroundColor(spieler.isEliminated ? Farbe.leise : (binIch ? Farbe.akzent : Farbe.schrift))
                .strikethrough(spieler.isEliminated)
                .lineLimit(1)

            if istHost { Marke(text: "HOST", farbe: Farbe.akzent) }
            if !spieler.isConnected { Marke(text: "AWAY", farbe: Farbe.schlecht) }

            Spacer(minLength: 4)

            Text("\(spieler.score)")
                .font(.mono(15))
                .foregroundColor(platz == 1 ? Farbe.gold : Farbe.schrift)
        }
    }
}

// MARK: - Endstand

struct EndeAnsicht: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    ueberschrift
                    Rangliste(spieler: spiel.spieler, eigeneId: spiel.eigeneId, hostId: spiel.hostId)
                    if let lieder = spiel.endstand?.songs, !lieder.isEmpty { Songliste(lieder: lieder) }
                    if api.ausweis?.isGuest ?? true { gastHinweis }
                    if let b = eigeneBelohnung { Belohnungen(belohnung: b) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }

            VStack(spacing: 9) {
                Button {
                    Spuerbar.tipp()
                    spiel.zurueckInDieLobby()
                } label: {
                    Label("Back to lobby", systemImage: "arrow.uturn.left")
                }
                .buttonStyle(Hauptknopf())

                Button("Main menu") { spiel.verlassen() }
                    .buttonStyle(Nebenknopf())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var eigenerPlatz: Int {
        (spiel.spieler.firstIndex { $0.id.text == spiel.eigeneId } ?? 0) + 1
    }

    private var eigeneBelohnung: Belohnung? {
        spiel.spieler.first { $0.id.text == spiel.eigeneId }?.rewards
    }

    private var ueberschrift: some View {
        VStack(spacing: 6) {
            Text("GAME OVER")
                .font(.marke(38, .black))
                .tracking(-1)
                .foregroundColor(.clear)
                .overlay { Farbe.verlaufHeld.mask { Text("GAME OVER").font(.marke(38, .black)).tracking(-1) } }
                .shadow(color: Farbe.akzent.opacity(0.35), radius: 18, y: 6)

            HStack(spacing: 5) {
                Text("You finished")
                    .foregroundColor(Farbe.leise)
                Text("#\(eigenerPlatz)")
                    .foregroundColor(Farbe.akzent)
                Text("with")
                    .foregroundColor(Farbe.leise)
                Text("\(spiel.ich?.score ?? 0) pts")
                    .foregroundColor(Farbe.akzent)
            }
            .font(.marke(13, .heavy))
        }
        .padding(.bottom, 2)
    }

    private var gastHinweis: some View {
        Karte(polster: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Farbe.gold)
                    Text("Playing as a guest").etikett()
                }
                Text("This round was not saved. With an account it would have counted.")
                    .font(.marke(13, .medium))
                    .foregroundColor(Farbe.gedaempft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Farbe.gold.opacity(0.35), lineWidth: 1)
        )
    }
}

struct Belohnungen: View {
    let belohnung: Belohnung

    var body: some View {
        HStack(spacing: 10) {
            Kachelchen(wert: belohnung.xp, wort: "XP", symbol: "star", farbe: Farbe.akzent)
            Kachelchen(wert: belohnung.spots, wort: "SPOTS", symbol: "music.note", farbe: Farbe.gut)
            Kachelchen(wert: belohnung.goldSpots, wort: "GS", symbol: "trophy", farbe: Farbe.gold)
        }
    }

    @ViewBuilder
    private func Kachelchen(wert: Int, wort: String, symbol: String, farbe: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(farbe)
            Text("+\(wert)")
                .font(.marke(19, .black))
                .foregroundColor(farbe)
            Text(wort).etikett()
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Glas(radius: 16))
    }
}

struct Songliste: View {
    let lieder: [Titel]

    var body: some View {
        Karte(polster: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "eye")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Farbe.akzent)
                    Text("WHAT WAS PLAYING").etikett()
                }
                ForEach(Array(lieder.enumerated()), id: \.offset) { i, t in
                    HStack(spacing: 10) {
                        Text("\(i + 1)")
                            .font(.mono(11, fett: false))
                            .foregroundColor(Farbe.leise)
                            .frame(width: 14, alignment: .leading)
                        Cover(adresse: t.albumArt, kante: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.title)
                                .font(.marke(13, .heavy))
                                .foregroundColor(Farbe.schrift)
                                .lineLimit(1)
                            Text(t.artist)
                                .font(.marke(11, .medium))
                                .foregroundColor(Farbe.leise)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let j = t.year {
                            Text(String(j))
                                .font(.mono(11))
                                .foregroundColor(Farbe.gedaempft)
                        }
                    }
                }
            }
        }
    }
}

/// Kleines Cover fuer Listen und die Auflösung.
struct Cover: View {
    let adresse: String?
    var kante: CGFloat = 72

    var body: some View {
        Group {
            if let adresse, let url = URL(string: adresse) {
                AsyncImage(url: url) { bild in
                    bild.resizable().scaledToFill()
                } placeholder: {
                    Farbe.grund3
                }
            } else {
                ZStack {
                    Farbe.grund3
                    Image(systemName: "music.note")
                        .font(.system(size: kante * 0.3))
                        .foregroundColor(Farbe.leise)
                }
            }
        }
        .frame(width: kante, height: kante)
        .clipShape(RoundedRectangle(cornerRadius: kante * 0.17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: kante * 0.17, style: .continuous)
                .strokeBorder(Farbe.linie, lineWidth: 1)
        )
    }
}

/// Die Aufstellung kommt als Woerterbuch - ohne feste Reihenfolge springt sie
/// sonst bei jeder Runde um.
enum Aufstellung {
    struct Eintrag { let schluessel: String; let wert: Bewertung }

    private static let reihenfolge = ["title", "artist", "year", "speed", "streak"]

    static func sortiert(_ bd: [String: Bewertung]) -> [Eintrag] {
        bd.map { Eintrag(schluessel: $0.key, wert: $0.value) }
          .sorted { a, b in
              let ia = reihenfolge.firstIndex(of: a.schluessel) ?? reihenfolge.count
              let ib = reihenfolge.firstIndex(of: b.schluessel) ?? reihenfolge.count
              return ia == ib ? a.schluessel < b.schluessel : ia < ib
          }
    }
}
