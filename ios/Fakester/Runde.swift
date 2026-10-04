import SwiftUI

/// Die Rateansicht, nach dem Browser nachgebaut: oben Rundenzaehler, Uhr-Pille
/// und Verlassen, darunter ein feiner Fortschrittsstrich, dann das Cover mit
/// "NOW PLAYING", die Abspielkarte und die Antworten in zwei Spalten.
///
/// Der Knopf unten ist bewusst nicht endgueltig: der Server erlaubt beliebig oft
/// umzuwaehlen, weil der Schnelligkeitsbonus am Sperrzeitpunkt haengt und ein
/// spaeteres Umwaehlen sich dadurch von selbst bezahlt macht.
struct RundenAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            kopf
            Balken(anteil: anteil, farbe: uhrFarbe, hoehe: 3)
                .animation(.linear(duration: 0.25), value: anteil)

            ScrollView {
                VStack(spacing: 14) {
                    eigenerChip
                    GrossesCover()
                    Abspielkarte()
                    ForEach(spiel.rateArten, id: \.self) { art in
                        AntwortBlock(art: art)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            sperrknopf
        }
    }

    // MARK: Kopf

    private var kopf: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text(L("RUNDE", "ROUND"))
                    .font(.marke(13, .heavy)).tracking(0.8)
                    .foregroundColor(Farbe.akzent)
                Text("\(spiel.runde?.round ?? 0)")
                    .font(.marke(13, .black))
                    .foregroundColor(Farbe.schrift)
                Text("/ \(spiel.runde?.totalRounds ?? 0)")
                    .font(.marke(13, .heavy))
                    .foregroundColor(Farbe.leise)
            }

            HStack(spacing: 5) {
                Image(systemName: "clock").font(.system(size: 11, weight: .bold))
                Text("\(spiel.restzeit)s").font(.mono(12))
            }
            .foregroundColor(uhrFarbe)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(uhrFarbe.opacity(0.10)))
            .overlay(Capsule().strokeBorder(uhrFarbe.opacity(0.26), lineWidth: 1))

            Spacer(minLength: 0)
            RausKnopf { spiel.verlassen() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    /// Unter zehn Sekunden wechselt die Uhr im Browser auf Orange. Das ist der
    /// einzige Moment, in dem die Seite laut wird - also hier auch.
    private var uhrFarbe: Color {
        if spiel.restzeit <= 5 { return Farbe.schlecht }
        if spiel.restzeit <= 10 { return Color(hex: 0xFB923C) }
        return Farbe.akzent
    }

    private var anteil: Double {
        let gesamt: Int = spiel.einstellungen?.guessTime ?? 30
        guard gesamt > 0 else { return 0 }
        return min(1, max(0, Double(spiel.restzeit) / Double(gesamt)))
    }

    private var eigenerChip: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Farbe.akzent)
                Text(spiel.ich?.nickname ?? "")
                    .font(.marke(13, .heavy))
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)
                Text("\(spiel.ich?.score ?? 0)")
                    .font(.mono(13))
                    .foregroundColor(Farbe.leise)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Farbe.akzent.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Farbe.akzent.opacity(0.24), lineWidth: 1))
            Spacer(minLength: 0)
        }
    }

    // MARK: Sperrknopf

    /// Der Browser schreibt auf den Knopf, was noch fehlt, statt ihn nur grau zu
    /// lassen. Das ist der Unterschied zwischen "geht nicht" und "mach noch das".
    private var sperrknopf: some View {
        let fehlend: [String] = spiel.rateArten.filter { art in
            spiel.antwort[art].trimmingCharacters(in: .whitespaces).isEmpty
        }
        return Button {
            if spiel.abgegeben {
                Spuerbar.tipp()
                spiel.nochmalUeberlegen()
            } else {
                Spuerbar.sperren()
                spiel.bereitMelden()
            }
        } label: {
            Label(knopfText(fehlend), systemImage: spiel.abgegeben ? "arrow.uturn.backward" : "checkmark")
        }
        .buttonStyle(Hauptknopf(farbe: spiel.abgegeben ? Farbe.kante : Farbe.akzent,
                                aus: !spiel.abgegeben && !fehlend.isEmpty))
        .disabled(!spiel.abgegeben && !fehlend.isEmpty)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func knopfText(_ fehlend: [String]) -> String {
        if spiel.abgegeben { return L("Antwort ändern", "Change answer") }
        if fehlend.isEmpty { return L("Antwort abgeben", "Lock in answer") }
        let worte: [String] = fehlend.map { Benennung.rateArt($0).lowercased() }
        return L("Noch wählen: \(liste(worte))", "Pick \(liste(worte))")
    }

    private func liste(_ w: [String]) -> String {
        guard w.count > 1 else { return w.first ?? "" }
        let und: String = L(" und ", " & ")
        return w.dropLast().joined(separator: ", ") + und + (w.last ?? "")
    }
}

// MARK: - Cover

/// Das Cover mit dem "NOW PLAYING"-Streifen. Im Reverse-Modus und wenn der
/// Gastgeber Cover abgeschaltet hat, kommt keins - dann steht hier die Welle.
struct GrossesCover: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Farbe.grund3)

            if let adresse = spiel.runde?.albumArt, let url = URL(string: adresse) {
                AsyncImage(url: url) { bild in
                    bild.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 34))
                        .foregroundColor(Farbe.leise)
                }
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(Farbe.akzent)
            }

            HStack(spacing: 8) {
                Wellen()
                Text("NOW PLAYING")
                    .font(.marke(11, .black)).tracking(1.1)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [.black.opacity(0.75), .clear],
                               startPoint: .bottom, endPoint: .top)
            )
        }
        .frame(height: 180)
        .frame(maxWidth: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Farbe.linie, lineWidth: 1)
        )
        .shadow(color: Farbe.akzent.opacity(0.22), radius: 22, y: 8)
    }
}

/// Die wippenden Balken auf dem Cover und in der Auflösung.
struct Wellen: View {
    var farbe: Color = .white
    @State private var an = false
    private let hoehen: [CGFloat] = [4, 8, 12, 6, 10]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(hoehen.enumerated()), id: \.offset) { i, h in
                Capsule()
                    .fill(farbe.opacity(0.9))
                    .frame(width: 2.5, height: an ? h : h * 0.4)
                    .animation(.easeInOut(duration: 0.5 + Double(i % 3) * 0.2)
                        .repeatForever(autoreverses: true), value: an)
            }
        }
        .frame(height: 12)
        .onAppear { an = true }
    }
}

// MARK: - Abspielkarte

/// Zeigt, dass und wie weit der Schnipsel laeuft, und laesst ihn anhalten.
/// Im Browser steht hier dieselbe Karte; sie ist der Beweis, dass Ton kommt -
/// ohne sie sitzt man bei einem stummen Geraet ratlos da.
struct Abspielkarte: View {
    @EnvironmentObject private var spiel: Spiel
    @ObservedObject private var ton = Ton.gemeinsam

    var body: some View {
        Karte(polster: 14) {
            VStack(spacing: 12) {
                HStack {
                    Text(L("Läuft gerade", "Now playing"))
                        .font(.marke(12, .heavy))
                        .foregroundColor(Farbe.akzent)
                    Spacer()
                    Text("\(zeit(ton.stelle)) / \(zeit(ton.dauer))")
                        .font(.mono(11, fett: false))
                        .foregroundColor(Farbe.leise)
                }

                HStack(spacing: 12) {
                    Button {
                        Spuerbar.tipp()
                        ton.umschalten()
                    } label: {
                        ZStack {
                            Circle().fill(Farbe.verlauf)
                            Image(systemName: ton.laeuft ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(Farbe.aufAkzent)
                        }
                        .frame(width: 40, height: 40)
                        .shadow(color: Farbe.akzent.opacity(0.4), radius: 8)
                    }
                    .buttonStyle(BubbleDruck())

                    Balken(anteil: ton.anteil, farbe: Farbe.akzent, hoehe: 6)
                }
            }
        }
    }

    private func zeit(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let g = Int(s)
        return String(format: "%d:%02d", g / 60, g % 60)
    }
}

// MARK: - Antworten

/// Eine Rateart mit ihren Moeglichkeiten. Im Browser stehen sie zu zweit
/// nebeneinander, und das Etikett bekommt ein Haekchen, sobald etwas gewaehlt
/// ist - so sieht man beim Runterscrollen, was noch offen ist.
struct AntwortBlock: View {
    @EnvironmentObject private var spiel: Spiel
    let art: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(Benennung.rateArt(art).uppercased()).etikett()
                if !spiel.antwort[art].trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Farbe.akzent)
                }
            }

            if spiel.einstellungen?.istMC ?? true {
                auswahl
            } else {
                Feld(text: Binding(get: { spiel.antwort[art] },
                                   set: { spiel.antwort[art] = $0 }),
                     platzhalter: Benennung.rateArt(art),
                     nurZiffern: art == "year")
            }
        }
    }

    private var auswahl: some View {
        let moeglich: [Lose] = spiel.runde?.mcOptions[art] ?? []
        let spalten: [GridItem] = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
        return LazyVGrid(columns: spalten, spacing: 9) {
            ForEach(moeglich, id: \.self) { m in
                WahlKnopf(text: m.text, gewaehlt: spiel.antwort[art] == m.text) {
                    Spuerbar.tipp()
                    spiel.antwort[art] = spiel.antwort[art] == m.text ? "" : m.text
                }
            }
        }
    }
}

struct WahlKnopf: View {
    let text: String
    let gewaehlt: Bool
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack {
                Text(text)
                    .font(.marke(14, gewaehlt ? .heavy : .medium))
                    .foregroundColor(Farbe.schrift)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(grund)
            .shadow(color: gewaehlt ? Farbe.akzent.opacity(0.3) : .clear, radius: 10)
            .animation(.easeOut(duration: 0.14), value: gewaehlt)
        }
        .buttonStyle(BubbleDruck())
    }

    private var grund: some View {
        let form = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            form.fill(gewaehlt ? Farbe.akzent.opacity(0.22) : Farbe.flaeche)
            form.strokeBorder(gewaehlt ? Farbe.akzent : Farbe.linie, lineWidth: gewaehlt ? 1.5 : 1)
        }
    }
}
