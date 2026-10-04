import SwiftUI

struct LobbyAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 0) {
            Kopfzeile(titel: "PIN \(spiel.pin)", unterzeile: untertitel) {
                spiel.verlassen()
            }

            ScrollView {
                VStack(spacing: 16) {
                    if let e = spiel.einstellungen {
                        Karte {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L("EINSTELLUNGEN", "SETTINGS")).etikett()
                                Zeile("Songs", "\(e.songCount)")
                                Zeile(L("Zeit", "Time"), "\(e.guessTime)s")
                                Zeile(L("Antwort", "Answer"), e.istMC ? "Multiple Choice" : L("Eintippen", "Type in"))
                                Zeile(L("Geraten wird", "Guessing"), e.guessTypes.map(Benennung.rateArt).joined(separator: ", "))
                                if let p = e.playlistName { Zeile("Playlist", p) }
                            }
                        }
                    }

                    Karte {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L("SPIELER (\(spiel.spieler.count))", "PLAYERS (\(spiel.spieler.count))")).etikett()
                            ForEach(spiel.spieler) { s in
                                SpielerZeile(spieler: s,
                                             istHost: s.id.text == spiel.hostId,
                                             binIch: s.id.text == spiel.eigeneId)
                            }
                        }
                    }

                    if !spiel.chat.isEmpty {
                        Karte {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("LOBBY").etikett()
                                ForEach(spiel.chat.suffix(6)) { z in
                                    Text(z.system ? z.text : "\(z.nickname): \(z.text)")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(z.system ? Farbe.gedaempft : Farbe.schrift)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            VStack(spacing: 10) {
                if spiel.binIchHost {
                    Button(L("Spiel starten", "Start game")) {
                        Spuerbar.sperren()
                        spiel.starten()
                    }
                    .buttonStyle(Hauptknopf())
                } else {
                    Text(L("Warten auf den Gastgeber…", "Waiting for the host…"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Farbe.gedaempft)
                        .frame(height: 54)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private var untertitel: String {
        let modus = Benennung.spielart(spiel.spielart)
        return spiel.binIchHost ? L("\(modus) · du bist Gastgeber", "\(modus) · you're the host") : modus
    }

    @ViewBuilder
    private func Zeile(_ links: String, _ rechts: String) -> some View {
        HStack {
            Text(links)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Farbe.gedaempft)
            Spacer()
            Text(rechts)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Farbe.schrift)
        }
    }
}

struct SpielerZeile: View {
    let spieler: Spieler
    var istHost = false
    var binIch = false
    var punkte: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Text(spieler.emoji ?? "🎵")
                .font(.system(size: 18))
                .frame(width: 30, height: 30)
                .background(Farbe.grund, in: Circle())

            Text(spieler.nickname)
                .font(.system(size: 15, weight: binIch ? .bold : .medium, design: .rounded))
                .foregroundColor(spieler.isEliminated ? Farbe.gedaempft : Farbe.schrift)
                .strikethrough(spieler.isEliminated)
                .lineLimit(1)

            if istHost { Abzeichen("HOST", Farbe.akzent) }
            if spieler.isBot { Abzeichen("BOT", Farbe.kante) }
            if !spieler.isConnected { Abzeichen(L("WEG", "AWAY"), Farbe.schlecht) }
            if spieler.watchOnly { Abzeichen(L("SCHAUT ZU", "WATCHING"), Farbe.kante) }

            Spacer(minLength: 4)

            if punkte {
                Text("\(spieler.score)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(Farbe.schrift)
                    .monospacedDigit()
            } else if spieler.isReady {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Farbe.gut)
            }
        }
    }

    @ViewBuilder
    private func Abzeichen(_ text: String, _ farbe: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundColor(farbe == Farbe.kante ? Farbe.gedaempft : Farbe.grund)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(farbe, in: Capsule())
    }
}

/// Oben auf jedem Spielbildschirm: wo bin ich, und wie komme ich hier raus.
struct Kopfzeile: View {
    let titel: String
    var unterzeile: String?
    var raus: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Farbe.schrift)
                if let u = unterzeile {
                    Text(u)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Farbe.gedaempft)
                }
            }
            Spacer()
            if let raus {
                Button(action: raus) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Farbe.gedaempft)
                        .frame(width: 36, height: 36)
                        .background(Farbe.flaeche, in: Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

/// Der Server sucht und prueft die Songs - das dauert, und ohne Anzeige sieht
/// es aus, als haenge das Spiel.
struct LadeAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 18) {
            if let z = spiel.zaehler {
                Text("\(z)")
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .foregroundColor(Farbe.akzent)
                    .transition(.scale.combined(with: .opacity))
                    .id(z)
            } else {
                ProgressView().tint(Farbe.akzent).scaleEffect(1.3)
                Text(spiel.ladetext.isEmpty ? L("Songs werden geladen…", "Loading songs…") : spiel.ladetext)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Farbe.schrift)

                if let l = spiel.ladestand, l.total > 0 {
                    VStack(spacing: 6) {
                        ProgressView(value: Double(l.checked), total: Double(l.total))
                            .tint(Farbe.akzent)
                            .frame(width: 220)
                        Text(L("\(l.playable) spielbar von \(l.checked) geprüft", "\(l.playable) playable of \(l.checked) checked"))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Farbe.gedaempft)
                            .monospacedDigit()
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: spiel.zaehler)
    }
}

enum Benennung {
    static func rateArt(_ k: String) -> String {
        switch k {
        case "title":  return L("Titel", "Title")
        case "artist": return L("Interpret", "Artist")
        case "year":   return L("Jahr", "Year")
        default:       return k
        }
    }

    static func spielart(_ k: String) -> String {
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
