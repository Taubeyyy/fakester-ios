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
            Kopfzeile(titel: titel, unterzeile: nil) { spiel.verlassen() }

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

    private var titel: String {
        guard let r = spiel.runde else { return L("Runde", "Round") }
        return L("Runde \(r.round) / \(r.totalRounds)", "Round \(r.round) / \(r.totalRounds)")
    }

    private var vollstaendig: Bool { spiel.antwort.vollstaendig(fuer: spiel.rateArten) }
    private var ratend: Int { spiel.spieler.filter { !$0.watchOnly && $0.isConnected }.count }
    private var fertig: Int { spiel.spieler.filter { !$0.watchOnly && $0.isReady }.count }

    // MARK: Bausteine

    @ViewBuilder
    private func Auswahl(art: String) -> some View {
        let moeglichkeiten = spiel.runde?.mcOptions[art] ?? []
        VStack(spacing: 8) {
            ForEach(moeglichkeiten, id: \.self) { m in
                let gewaehlt = spiel.antwort[art] == m.text
                Button {
                    Spuerbar.tipp()
                    spiel.antwort[art] = gewaehlt ? "" : m.text
                } label: {
                    HStack {
                        Text(m.text)
                            .font(.marke(15, gewaehlt ? .heavy : .semibold))
                            .foregroundColor(gewaehlt ? Farbe.aufAkzent : Farbe.schrift)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer(minLength: 6)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(gewaehlt ? AnyShapeStyle(Farbe.verlauf) : AnyShapeStyle(Farbe.grund3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(gewaehlt ? Color.white.opacity(0.12) : Farbe.linie, lineWidth: 1.5)
                    )
                    .shadow(color: gewaehlt ? Farbe.akzent.opacity(0.36) : .clear, radius: 10, x: 0, y: 2)
                }
                .buttonStyle(.plain)
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

/// Die Restzeit als Balken. Zahlen allein liest in der Hektik niemand.
struct Uhr: View {
    let rest: Int
    let gesamt: Int

    private var anteil: Double {
        guard gesamt > 0 else { return 0 }
        return max(0, min(1, Double(rest) / Double(gesamt)))
    }

    private var farbe: Color {
        rest <= 5 ? Farbe.schlecht : (rest <= 10 ? Color(hex: 0xFFB020) : Farbe.akzent)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { raum in
                ZStack(alignment: .leading) {
                    Capsule().fill(Farbe.grund3)
                    Capsule().fill(farbe).frame(width: raum.size.width * anteil)
                }
            }
            .frame(height: 8)
            .animation(.linear(duration: 0.25), value: anteil)

            Text("\(rest)s")
                .font(.mono(13))
                .foregroundColor(farbe)
                .monospacedDigit()
        }
    }
}
