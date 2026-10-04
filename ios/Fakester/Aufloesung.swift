import SwiftUI

/// Was es war, und was es gebracht hat.
struct AufloesungAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            Kopfzeile(titel: L("Auflösung", "Reveal"), unterzeile: nil) { spiel.verlassen() }

            ScrollView {
                VStack(spacing: 16) {
                    if let t = spiel.ergebnis?.correctTrack {
                        Karte {
                            HStack(spacing: 14) {
                                Cover(adresse: t.albumArt)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.title)
                                        .font(.marke(17, .heavy))
                                        .foregroundColor(Farbe.schrift)
                                        .lineLimit(2)
                                    Text(t.artist)
                                        .font(.marke(14, .medium))
                                        .foregroundColor(Farbe.gedaempft)
                                        .lineLimit(1)
                                    if let j = t.year {
                                        Text(String(j))
                                            .font(.mono(13))
                                            .foregroundColor(Farbe.akzentHell)
                                            .monospacedDigit()
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    } else if spiel.ergebnis?.sneaky == true {
                        Karte {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SNEAKY MODE").etikett()
                                Text(L("Der Song bleibt diesmal verdeckt.", "The song stays hidden this time."))
                                    .font(.marke(14))
                                    .foregroundColor(Farbe.schrift)
                            }
                        }
                    }

                    if let blatt = spiel.ich?.lastPointsBreakdown, !blatt.breakdown.isEmpty {
                        Karte {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(L("DEINE RUNDE", "YOUR ROUND")).etikett()
                                    Spacer()
                                    Text("+\(blatt.total)")
                                        .font(.marke(14, .heavy))
                                        .foregroundColor(blatt.total > 0 ? Farbe.gut : Farbe.gedaempft)
                                        .monospacedDigit()
                                }
                                ForEach(Aufstellung.sortiert(blatt.breakdown), id: \.schluessel) { eintrag in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(eintrag.wert.text)
                                                .font(.marke(14, .medium))
                                                .foregroundColor(eintrag.wert.points > 0 ? Farbe.schrift : Farbe.gedaempft)
                                            Spacer()
                                            Text(eintrag.wert.points > 0 ? "+\(eintrag.wert.points)" : "0")
                                                .font(.marke(14, .heavy))
                                                .foregroundColor(eintrag.wert.points > 0 ? Farbe.gut : Farbe.gedaempft)
                                                .monospacedDigit()
                                        }
                                        // Der Server schickt mit, was man selbst getippt hat.
                                        // Bei einer falschen Antwort ist genau das die Frage,
                                        // die man sich stellt - und im Browser sieht man es nicht.
                                        if eintrag.wert.points == 0,
                                           let eigene = blatt.ownAnswer?[eintrag.schluessel]?.text,
                                           !eigene.isEmpty {
                                            Text(L("du: \(eigene)", "you: \(eigene)"))
                                                .font(.marke(12))
                                                .foregroundColor(Farbe.schlecht.opacity(0.9))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Karte {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(L("STAND", "STANDINGS")).etikett()
                                .padding(.bottom, 3)
                            ForEach(Array(spiel.spieler.enumerated()), id: \.element.id) { i, s in
                                SpielerZeile(spieler: s,
                                             istHost: s.id.text == spiel.hostId,
                                             binIch: s.id.text == spiel.eigeneId,
                                             punkte: true,
                                             platz: i + 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            Text(L("Gleich geht es weiter…", "Next round coming up…"))
                .font(.marke(13, .medium))
                .foregroundColor(Farbe.gedaempft)
                .padding(.bottom, 16)
        }
        .onAppear {
            // Erst hier, nicht im Modell: die Rueckmeldung gehoert an den
            // Moment, in dem man die Aufloesung sieht.
            let punkte = spiel.ich?.lastPointsBreakdown?.total ?? 0
            if punkte > 0 { Spuerbar.richtig() } else { Spuerbar.falsch() }
        }
    }
}

/// Der Endstand samt Belohnung.
struct EndeAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            Kopfzeile(titel: L("Endstand", "Final standings"), unterzeile: nil) { spiel.verlassen() }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(spiel.spieler.enumerated()), id: \.element.id) { platz, s in
                        EndZeile(spieler: s, platz: platz + 1, belohnung: s.rewards.map { belohnungText($0) })
                    }

                    if let lieder = spiel.endstand?.songs, !lieder.isEmpty {
                        Karte {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("GESPIELT", "PLAYED")).etikett()
                                ForEach(Array(lieder.enumerated()), id: \.offset) { _, t in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(t.title)
                                            .font(.marke(14, .semibold))
                                            .foregroundColor(Farbe.schrift)
                                            .lineLimit(1)
                                        Text(t.year.map { "\(t.artist) · \($0)" } ?? t.artist)
                                            .font(.marke(12))
                                            .foregroundColor(Farbe.gedaempft)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            VStack(spacing: 10) {
                Button(L("Zurück in die Lobby", "Back to lobby")) {
                    Spuerbar.tipp()
                    spiel.zurueckInDieLobby()
                }
                .buttonStyle(Hauptknopf())

                Button(L("Verlassen", "Leave")) { spiel.verlassen() }
                    .buttonStyle(Nebenknopf())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private func belohnungText(_ b: Belohnung) -> String {
        var teile: [String] = []
        if b.xp > 0 { teile.append("+\(b.xp) XP") }
        if b.spots > 0 { teile.append("+\(b.spots) Spots") }
        if b.goldSpots > 0 { teile.append("+\(b.goldSpots) Gold") }
        return teile.joined(separator: " · ")
    }
}

/// .end-player: Zeile im Endstand, der Sieger in Gold und leicht pulsierend.
struct EndZeile: View {
    let spieler: Spieler
    let platz: Int
    let belohnung: String?
    @State private var glimmt = false

    var body: some View {
        let sieger: Bool = platz == 1
        let form = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 12) {
            Rang(platz: platz, groesse: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(spieler.nickname)
                    .font(.marke(15, .heavy))
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)
                Text(L("\(spieler.correctAnswers) richtig · längste Serie \(spieler.bestStreak)",
                       "\(spieler.correctAnswers) correct · best streak \(spieler.bestStreak)"))
                    .font(.marke(12))
                    .foregroundColor(Farbe.gedaempft)
                if let b = belohnung, !b.isEmpty {
                    Text(b)
                        .font(.marke(12, .bold))
                        .foregroundColor(Farbe.gold)
                }
            }

            Spacer(minLength: 0)

            Text("\(spieler.score)")
                .font(.mono(16))
                .foregroundColor(Farbe.akzent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(form.fill(sieger
            ? AnyShapeStyle(LinearGradient(colors: [Farbe.gold.opacity(0.14), Farbe.grund3],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Farbe.grund3)))
        .overlay(form.strokeBorder(sieger ? Farbe.gold : Farbe.linie, lineWidth: 1))
        .overlay(form.stroke(Farbe.gold.opacity(sieger ? (glimmt ? 0.4 : 0.15) : 0), lineWidth: 2).padding(-1.5))
        .shadow(color: Farbe.gold.opacity(sieger && glimmt ? 0.28 : 0), radius: 13)
        .onAppear {
            guard sieger else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glimmt = true }
        }
    }
}

struct Cover: View {
    let adresse: String?

    var body: some View {
        Group {
            if let adresse, let url = URL(string: adresse) {
                AsyncImage(url: url) { bild in
                    bild.resizable().scaledToFill()
                } placeholder: {
                    Farbe.grund
                }
            } else {
                ZStack {
                    Farbe.grund
                    Image(systemName: "music.note").foregroundColor(Farbe.gedaempft)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Die Aufstellung kommt als Woerterbuch - ohne feste Reihenfolge sprigt sie
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
