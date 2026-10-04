import SwiftUI

/// Die Rateansicht. Oben die Uhr, in der Mitte die Antwort, unten der Knopf.
///
/// Der Knopf ist bewusst nicht endgueltig: der Server erlaubt beliebig oft
/// umzuwaehlen, weil der Schnelligkeitsbonus am Sperrzeitpunkt haengt und ein
/// spaeteres Umwaehlen sich dadurch von selbst bezahlt macht. Ein Fehltipp
/// darf keine Runde kosten.
struct RundenAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            RundenKopf(runde: spiel.runde?.round, gesamt: spiel.runde?.totalRounds,
                       rest: spiel.restzeit) { spiel.verlassen() }

            Uhr(rest: spiel.restzeit, gesamt: spiel.einstellungen?.guessTime ?? 30)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 16) {
                    Plattenteller()

                    ForEach(spiel.rateArten, id: \.self) { art in
                        Karte {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(Benennung.rateArt(art).uppercased()).etikett()
                                if spiel.einstellungen?.istMC ?? true {
                                    Auswahl(art: art)
                                } else {
                                    Eintippen(art: art)
                                }
                            }
                        }
                    }

                    if !spiel.spieler.isEmpty {
                        Karte {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("FERTIG: \(fertig) / \(ratend)", "DONE: \(fertig) / \(ratend)")).etikett()
                                ForEach(spiel.spieler.filter { !$0.watchOnly }) { s in
                                    SpielerZeile(spieler: s, binIch: s.id.text == spiel.eigeneId)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(spiel.abgegeben ? L("Antwort ändern", "Change answer") : L("Antwort abgeben", "Submit answer")) {
                if spiel.abgegeben {
                    Spuerbar.tipp()
                    spiel.nochmalUeberlegen()
                } else {
                    Spuerbar.sperren()
                    spiel.bereitMelden()
                }
            }
            .buttonStyle(Hauptknopf(farbe: spiel.abgegeben ? Farbe.kante : Farbe.akzent,
                                    aus: !spiel.abgegeben && !vollstaendig))
            .disabled(!spiel.abgegeben && !vollstaendig)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private var vollstaendig: Bool { spiel.antwort.vollstaendig(fuer: spiel.rateArten) }
    private var ratend: Int { spiel.spieler.filter { !$0.watchOnly && $0.isConnected }.count }
    private var fertig: Int { spiel.spieler.filter { !$0.watchOnly && $0.isReady }.count }

    // MARK: Bausteine

    @ViewBuilder
    private func Auswahl(art: String) -> some View {
        let moeglichkeiten = spiel.runde?.mcOptions[art] ?? []
        let spalten: [GridItem] = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        LazyVGrid(columns: spalten, spacing: 8) {
            ForEach(moeglichkeiten, id: \.self) { m in
                let gewaehlt = spiel.antwort[art] == m.text
                Button {
                    Spuerbar.tipp()
                    spiel.antwort[art] = gewaehlt ? "" : m.text
                } label: {
                    AntwortFeld(text: m.text, gewaehlt: gewaehlt,
                                gesperrt: spiel.abgegeben && !gewaehlt)
                }
                .buttonStyle(BubbleDruck())
            }
        }
    }

    @ViewBuilder
    private func Eintippen(art: String) -> some View {
        Feld(text: Binding(get: { spiel.antwort[art] },
                           set: { spiel.antwort[art] = $0 }),
             platzhalter: Benennung.rateArt(art),
             nurZiffern: art == "year")
    }
}

/// Zeigt, dass Musik laeuft - und das Cover, falls der Gastgeber es zulaesst.
struct Plattenteller: View {
    @EnvironmentObject private var spiel: Spiel
    @State private var dreht = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Farbe.flaeche)
                    .overlay(Circle().strokeBorder(Farbe.kante, lineWidth: 1))

                if let adresse = spiel.runde?.albumArt, let url = URL(string: adresse) {
                    AsyncImage(url: url) { bild in
                        bild.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "music.note").font(.system(size: 34)).foregroundColor(Farbe.gedaempft)
                    }
                    .frame(width: 136, height: 136)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(Farbe.akzent)
                }

                Circle().fill(Farbe.grund).frame(width: 26, height: 26)
            }
            .frame(width: 140, height: 140)
            .rotationEffect(.degrees(dreht ? 360 : 0))
            .animation(.linear(duration: 9).repeatForever(autoreverses: false), value: dreht)
            .onAppear { dreht = true }

            if spiel.runde?.previewUrl == nil {
                Text(L("Für diesen Song gibt es keine Vorschau.", "No preview for this song."))
                    .font(.marke(12))
                    .foregroundColor(Farbe.gedaempft)
            }
        }
        .padding(.top, 4)
    }
}

/// .mc-btn: dunkle Kachel, links ein schmaler Streifen, gewaehlt lila umrandet.
struct AntwortFeld: View {
    let text: String
    let gewaehlt: Bool
    var gesperrt: Bool = false

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 0) {
            Text(text)
                .font(.marke(14, .bold))
                .foregroundColor(gewaehlt ? Farbe.akzent : Farbe.schrift)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(form.fill(gewaehlt ? Farbe.akzentDim : Farbe.grund3))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(gewaehlt ? Farbe.akzentTief : Color.clear)
                .frame(width: 3)
        }
        .clipShape(form)
        .overlay(form.strokeBorder(gewaehlt ? Farbe.akzentTief : Farbe.kante, lineWidth: 1.5))
        .overlay(form.stroke(Farbe.akzent.opacity(gewaehlt ? 0.22 : 0), lineWidth: 3).padding(-1.5))
        .overlay(Lichtkante(radius: 10, staerke: 0.06))
        .opacity(gesperrt ? 0.4 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: gewaehlt)
    }
}

/// Die Restzeit als Balken. Zahlen allein liest in der Hektik niemand.
struct Uhr: View {
    let rest: Int
    let gesamt: Int

    private var anteil: Double {
        guard gesamt > 0 else { return 0 }
        return max(0, min(1, Double(rest) / Double(gesamt)))
    }

    /// Im Browser bleibt der Balken lila und flackert nur; auf dem Handy hilft
    /// das letzte Rot, weil man oft nicht so genau hinschaut.
    private var farbe: Color? {
        rest <= 5 ? Farbe.schlecht : nil
    }

    var body: some View {
        Balken(anteil: anteil, farbe: farbe)
            .animation(.linear(duration: 0.25), value: anteil)
    }
}

/// .game-header-top: "RUNDE 3 / 10" (Zahlen lila in DM Mono), Sekunden,
/// rechts der Verlassen-Knopf.
struct RundenKopf: View {
    let runde: Int?
    let gesamt: Int?
    let rest: Int
    let raus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(L("RUNDE", "ROUND"))
                    .font(.marke(13, .heavy))
                    .tracking(0.5)
                    .foregroundColor(Farbe.gedaempft)
                if let runde, let gesamt {
                    Text("\(runde)/\(gesamt)")
                        .font(.mono(13))
                        .foregroundColor(Farbe.akzentTief)
                }
            }
            Text("\(rest)s")
                .font(.mono(13))
                .foregroundColor(rest <= 5 ? Farbe.schlecht : Farbe.schrift)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(Farbe.grund3))
            Spacer()
            RausKnopf(aktion: raus)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}
