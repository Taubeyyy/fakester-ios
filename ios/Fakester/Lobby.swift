import SwiftUI

/// Die Lobby wie im Browser: Infoleiste mit PIN, Spielerkarten im Raster,
/// unten der Startknopf.
struct LobbyAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    private let spalten: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            Kopfzeile(titel: Benennung.spielart(spiel.spielart), unterzeile: untertitel, pin: spiel.pin) {
                spiel.verlassen()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let e = spiel.einstellungen {
                        infoleiste(e)
                    }

                    Text(L("SPIELER (\(spiel.spieler.count))", "PLAYERS (\(spiel.spieler.count))")).etikett()
                        .padding(.top, 4)

                    LazyVGrid(columns: spalten, spacing: 10) {
                        ForEach(spiel.spieler) { s in
                            SpielerKarte(spieler: s,
                                         istHost: s.id.text == spiel.hostId,
                                         binIch: s.id.text == spiel.eigeneId)
                        }
                    }
                    .padding(.top, 6)

                    if !spiel.chat.isEmpty {
                        Karte {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CHAT").etikett()
                                ForEach(spiel.chat.suffix(6)) { z in
                                    Text(z.system ? z.text : "\(z.nickname): \(z.text)")
                                        .font(.marke(13))
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
                    Button {
                        Spuerbar.sperren()
                        spiel.starten()
                    } label: {
                        Label(L("Spiel starten", "Start game"), systemImage: "play.fill")
                    }
                    .buttonStyle(Hauptknopf())
                } else {
                    Text(L("Warten auf den Gastgeber…", "Waiting for the host…"))
                        .font(.marke(14, .semibold))
                        .foregroundColor(Farbe.gedaempft)
                        .frame(height: 54)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private var untertitel: String? {
        spiel.binIchHost ? L("Du bist Gastgeber", "You're the host") : nil
    }

    /// .lobby-info-bar: die Einstellungen als kleine Stichpunkte in einer Leiste.
    private func infoleiste(_ e: Einstellungen) -> some View {
        var teile: [String] = ["\(e.songCount) Songs", "\(e.guessTime)s",
                               e.istMC ? "Multiple Choice" : L("Eintippen", "Type in"),
                               e.guessTypes.map(Benennung.rateArt).joined(separator: " · ")]
        if let p = e.playlistName { teile.append(p) }
        return Text(teile.joined(separator: "   ·   "))
            .font(.marke(12, .semibold))
            .foregroundColor(Farbe.gedaempft)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Glas(radius: 16))
    }
}

/// .player-card: rundes Symbol, Name, kleine Zeile drunter. Host in Gold,
/// bereit mit lila Haken oben rechts.
struct SpielerKarte: View {
    let spieler: Spieler
    var istHost = false
    var binIch = false

    var body: some View {
        VStack(spacing: 8) {
            symbol
            Text(spieler.nickname)
                .font(.marke(13, .heavy))
                .foregroundColor(spieler.isEliminated ? Farbe.leise : Farbe.schrift)
                .strikethrough(spieler.isEliminated)
                .lineLimit(1)
            Text(zusatz)
                .font(.marke(10, .bold))
                .tracking(0.6)
                .foregroundColor(spieler.isConnected ? Farbe.leise : Farbe.schlecht)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(grund)
        .overlay(alignment: .topTrailing) {
            if spieler.isReady {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Farbe.aufAkzent)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Farbe.akzentTief))
                    .shadow(color: Farbe.akzent.opacity(0.36), radius: 6)
                    .padding(8)
            }
        }
        .overlay(alignment: .top) {
            if istHost {
                Text("HOST")
                    .font(.marke(9, .black))
                    .tracking(0.9)
                    .foregroundColor(Farbe.aufGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Farbe.verlaufGold))
                    .shadow(color: Farbe.gold.opacity(0.32), radius: 5)
                    .offset(y: -9)
            }
        }
        .opacity(spieler.isConnected ? 1 : 0.6)
    }

    private var symbol: some View {
        let verlauf: LinearGradient = istHost ? Farbe.verlaufGold : Farbe.verlauf
        let schein: Color = istHost ? Farbe.gold.opacity(0.32) : Farbe.akzent.opacity(0.36)
        return ZStack {
            Circle().fill(verlauf)
            if let e = spieler.emoji, !e.isEmpty {
                Text(e).font(.system(size: 24))
            } else {
                Image(systemName: spieler.isBot ? "cpu" : "person.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(istHost ? Farbe.aufGold : Farbe.aufAkzent)
            }
        }
        .frame(width: 54, height: 54)
        .shadow(color: schein, radius: 8)
    }

    @ViewBuilder
    private var grund: some View {
        if istHost {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Farbe.gold.opacity(0.14), Farbe.flaeche],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Farbe.gold, lineWidth: 1.5)
            }
            .shadow(color: Farbe.gold.opacity(0.15), radius: 3)
        } else {
            Glas(radius: 16, kante: binIch ? Farbe.akzentTief : Farbe.kante, dicke: 1.5)
        }
    }

    private var zusatz: String {
        if !spieler.isConnected { return L("WEG", "AWAY") }
        if spieler.watchOnly { return L("SCHAUT ZU", "WATCHING") }
        if spieler.isBot { return "BOT" }
        if binIch { return L("DU", "YOU") }
        return spieler.isReady ? L("BEREIT", "READY") : L("SPIELER", "PLAYER")
    }
}

/// Eine Zeile in Listen (.result-score-row): dunkle Flaeche, Platz, Name, Punkte.
struct SpielerZeile: View {
    let spieler: Spieler
    var istHost = false
    var binIch = false
    var punkte: Bool = false
    var platz: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let platz {
                Rang(platz: platz, groesse: 26)
            } else {
                Text(spieler.emoji ?? "🎵")
                    .font(.system(size: 14))
                    .frame(width: 26, height: 26)
                    .background(Farbe.grund4, in: Circle())
            }

            Text(spieler.nickname)
                .font(.marke(14, binIch ? .heavy : .bold))
                .foregroundColor(spieler.isEliminated ? Farbe.leise : Farbe.schrift)
                .strikethrough(spieler.isEliminated)
                .lineLimit(1)

            if istHost { Abzeichen("HOST", Farbe.gold) }
            if spieler.isBot { Abzeichen("BOT", Farbe.kante) }
            if !spieler.isConnected { Abzeichen(L("WEG", "AWAY"), Farbe.schlecht) }
            if spieler.watchOnly { Abzeichen(L("SCHAUT ZU", "WATCHING"), Farbe.kante) }

            Spacer(minLength: 4)

            if punkte {
                Text("\(spieler.score)")
                    .font(.mono(15))
                    .foregroundColor(Farbe.akzent)
            } else if spieler.isReady {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Farbe.akzent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Farbe.grund3))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(binIch ? Farbe.akzentTief.opacity(0.7) : Farbe.linie, lineWidth: 1))
    }

    @ViewBuilder
    private func Abzeichen(_ text: String, _ farbe: Color) -> some View {
        Text(text)
            .font(.marke(9, .heavy))
            .tracking(0.6)
            .foregroundColor(farbe == Farbe.kante ? Farbe.gedaempft : Farbe.grund)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(farbe, in: Capsule())
    }
}

/// Runder Platz (.result-rank / .end-rank): Platz 1 in Gold.
struct Rang: View {
    let platz: Int
    var groesse: CGFloat = 30

    var body: some View {
        let erster: Bool = platz == 1
        Text("\(platz)")
            .font(.mono(groesse * 0.44))
            .foregroundColor(erster ? Farbe.aufGold : Farbe.gedaempft)
            .frame(width: groesse, height: groesse)
            .background(Circle().fill(erster ? AnyShapeStyle(Farbe.verlaufGold) : AnyShapeStyle(Farbe.grund4)))
            .shadow(color: erster ? Farbe.gold.opacity(0.32) : .clear, radius: 5)
    }
}

/// Oben auf jedem Spielbildschirm (.game-header-top): links wo man ist,
/// rechts der rote Verlassen-Knopf.
struct Kopfzeile: View {
    let titel: String
    var unterzeile: String?
    var pin: String? = nil
    var raus: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(titel.uppercased())
                    .font(.marke(15, .heavy))
                    .tracking(0.6)
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let pin, !pin.isEmpty { PinMarke(pin: pin) }
                    if let u = unterzeile {
                        Text(u)
                            .font(.marke(12, .semibold))
                            .foregroundColor(Farbe.gedaempft)
                    }
                }
            }
            Spacer()
            if let raus { RausKnopf(aktion: raus) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

/// .lobby-pin-badge: "PIN 1234" in DM Mono, lila Rand und Ring.
struct PinMarke: View {
    let pin: String

    var body: some View {
        HStack(spacing: 6) {
            Text("PIN")
                .font(.mono(12))
                .tracking(1.2)
                .foregroundColor(Farbe.akzentTief)
            Text(pin)
                .font(.mono(14))
                .tracking(2.1)
                .foregroundColor(Farbe.akzent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Farbe.akzentDim))
        .overlay(Capsule().strokeBorder(Farbe.akzentTief, lineWidth: 1))
        .overlay(Capsule().stroke(Farbe.akzent.opacity(0.22), lineWidth: 3).padding(-2))
    }
}

/// Der Server sucht und prueft die Songs - das dauert, und ohne Anzeige sieht
/// es aus, als haenge das Spiel.
struct LadeAnsicht: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        VStack(spacing: 18) {
            if let z = spiel.zaehler {
                // .countdown-number: riesig, Lila-Verlauf, leuchtend
                Text("\(z)")
                    .font(.marke(150, .black))
                    .tracking(-7)
                    .foregroundColor(.clear)
                    .overlay(Farbe.verlauf.mask { Text("\(z)").font(.marke(150, .black)).tracking(-7) })
                    .shadow(color: Farbe.akzent.opacity(0.36), radius: 24)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .id(z)
            } else {
                ProgressView().tint(Farbe.akzent).scaleEffect(1.3)
                Text(spiel.ladetext.isEmpty ? L("Songs werden geladen…", "Loading songs…") : spiel.ladetext)
                    .font(.marke(15, .semibold))
                    .foregroundColor(Farbe.schrift)

                if let l = spiel.ladestand, l.total > 0 {
                    VStack(spacing: 6) {
                        Balken(anteil: Double(l.checked) / Double(l.total))
                            .frame(width: 220)
                        Text(L("\(l.playable) spielbar von \(l.checked) geprüft", "\(l.playable) playable of \(l.checked) checked"))
                            .font(.mono(12, fett: false))
                            .foregroundColor(Farbe.gedaempft)
                    }
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: spiel.zaehler)
    }
}

/// .timer-wrap / .timer-bar: duenner Balken mit Lila-Verlauf und Schein.
struct Balken: View {
    let anteil: Double
    var farbe: Color? = nil
    /// Der Rundenstrich oben ist duenner als der Balken in einer Karte.
    var hoehe: CGFloat = 6

    var body: some View {
        GeometryReader { raum in
            ZStack(alignment: .leading) {
                Capsule().fill(Farbe.grund3)
                Capsule()
                    .fill(farbe.map { AnyShapeStyle($0) } ?? AnyShapeStyle(Farbe.verlaufHeld))
                    .frame(width: raum.size.width * CGFloat(max(0, min(1, anteil))))
                    .shadow(color: (farbe ?? Farbe.akzent).opacity(0.4), radius: 5)
            }
        }
        .frame(height: hoehe)
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
