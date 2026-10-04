import SwiftUI

/// Was es war, und was es gebracht hat.
struct AufloesungAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            Kopfzeile(titel: "Aufloesung", unterzeile: nil) { spiel.verlassen() }

            ScrollView {
                VStack(spacing: 16) {
                    if let t = spiel.ergebnis?.correctTrack {
                        Karte {
                            HStack(spacing: 14) {
                                Cover(adresse: t.albumArt)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.title)
                                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                                        .foregroundColor(Farbe.schrift)
                                        .lineLimit(2)
                                    Text(t.artist)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(Farbe.gedaempft)
                                        .lineLimit(1)
                                    if let j = t.year {
                                        Text(String(j))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
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
                                Text("Der Song bleibt diesmal verdeckt.")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(Farbe.schrift)
                            }
                        }
                    }

                    if let blatt = spiel.ich?.lastPointsBreakdown, !blatt.breakdown.isEmpty {
                        Karte {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("DEINE RUNDE").etikett()
                                    Spacer()
                                    Text("+\(blatt.total)")
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundColor(blatt.total > 0 ? Farbe.gut : Farbe.gedaempft)
                                        .monospacedDigit()
                                }
                                ForEach(Aufstellung.sortiert(blatt.breakdown), id: \.schluessel) { eintrag in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(eintrag.wert.text)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(eintrag.wert.points > 0 ? Farbe.schrift : Farbe.gedaempft)
                                            Spacer()
                                            Text(eintrag.wert.points > 0 ? "+\(eintrag.wert.points)" : "0")
                                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                                .foregroundColor(eintrag.wert.points > 0 ? Farbe.gut : Farbe.gedaempft)
                                                .monospacedDigit()
                                        }
                                        // Der Server schickt mit, was man selbst getippt hat.
                                        // Bei einer falschen Antwort ist genau das die Frage,
                                        // die man sich stellt - und im Browser sieht man es nicht.
                                        if eintrag.wert.points == 0,
                                           let eigene = blatt.ownAnswer?[eintrag.schluessel]?.text,
                                           !eigene.isEmpty {
                                            Text("du: \(eigene)")
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundColor(Farbe.schlecht.opacity(0.9))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Karte {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("STAND").etikett()
                            ForEach(spiel.spieler) { s in
                                SpielerZeile(spieler: s,
                                             istHost: s.id.text == spiel.hostId,
                                             binIch: s.id.text == spiel.eigeneId,
                                             punkte: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            Text("Gleich geht es weiter…")
                .font(.system(size: 13, weight: .medium, design: .rounded))
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
            Kopfzeile(titel: "Endstand", unterzeile: nil) { spiel.verlassen() }

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(spiel.spieler.enumerated()), id: \.element.id) { platz, s in
                        Karte {
                            HStack(spacing: 12) {
                                Text("\(platz + 1)")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(platz == 0 ? Farbe.akzent : Farbe.gedaempft)
                                    .frame(width: 26)
                                    .monospacedDigit()

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.nickname)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(Farbe.schrift)
                                        .lineLimit(1)
                                    Text("\(s.correctAnswers) richtig · laengste Serie \(s.bestStreak)")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(Farbe.gedaempft)
                                    if let b = s.rewards, b.xp > 0 || b.spots > 0 || b.goldSpots > 0 {
                                        Text(belohnungText(b))
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(Farbe.akzentHell)
                                    }
                                }

                                Spacer(minLength: 0)

                                Text("\(s.score)")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(Farbe.schrift)
                                    .monospacedDigit()
                            }
                        }
                    }

                    if let lieder = spiel.endstand?.songs, !lieder.isEmpty {
                        Karte {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("GESPIELT").etikett()
                                ForEach(Array(lieder.enumerated()), id: \.offset) { _, t in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(t.title)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(Farbe.schrift)
                                            .lineLimit(1)
                                        Text(t.year.map { "\(t.artist) · \($0)" } ?? t.artist)
                                            .font(.system(size: 12, design: .rounded))
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
                Button("Zurueck in die Lobby") {
                    Spuerbar.tipp()
                    spiel.zurueckInDieLobby()
                }
                .buttonStyle(Hauptknopf())

                Button("Verlassen") { spiel.verlassen() }
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
