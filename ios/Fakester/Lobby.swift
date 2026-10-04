import SwiftUI

/// Eine Kachel im PLAYERS-Raster der Lobby, gemessen an fakester.app (375×812):
/// 80×113, Ecken 16, Polster 10. Rundes Bild (40), beim Gastgeber das goldene
/// „Host"-Abzeichen am Bild und „♛ CREATOR" ueber dem Namen; der Name 10 pt
/// fett in Lila. Die eigene Kachel ist lila hinterlegt und umrandet, die
/// anderen fast unsichtbar. Wer die Verbindung verloren hat, wird blass.
struct SpielerKarte: View {
    let spieler: Spieler
    var istHost = false
    var binIch = false
    /// Hoehe der Rasterzeile - im Browser sind alle Kacheln einer Zeile gleich
    /// hoch (CSS-Grid streckt sie). 0 = so hoch wie der Inhalt.
    var hoehe: CGFloat = 0

    /// Die natuerliche Hoehe ohne Streckung, mit denselben Zeilenhoehen wie im
    /// Browser (Polster 10 + Rand 1, Bild 40, Abstand 6, Name 15 ...).
    static func hoehe(spieler: Spieler, istHost: Bool) -> CGFloat {
        var h: CGFloat = 11 + 40 + 6 + 15 + 11
        if istHost { h += 14 }
        if !spieler.isConnected {
            h += 15.5
        } else if spieler.isPro {
            h += 13
        }
        return h
    }

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        let grund: Color = binIch ? Farbe.akzentTief.opacity(0.15) : Color.white.opacity(0.025)
        let rand: Color = binIch ? Farbe.akzent.opacity(0.45) : Farbe.linie
        return VStack(spacing: 6) {
            bild
            beschriftung
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: hoehe, alignment: .top)
        .background(form.fill(grund))
        .overlay(form.strokeBorder(rand, lineWidth: 1))
        .opacity(spieler.isConnected ? 1 : 0.45)
    }

    private var bild: some View {
        LobbyAvatar(spieler: spieler, groesse: 40)
            .overlay(alignment: .topTrailing) {
                if istHost {
                    hostMarke.offset(x: 4, y: -4)
                }
            }
    }

    private var beschriftung: some View {
        VStack(spacing: 0) {
            if istHost {
                creator.padding(.bottom, 2)
            }
            Text(spieler.nickname)
                .font(.marke(10, .bold))
                .foregroundColor(Farbe.akzent)
                .lineLimit(1)
                .frame(height: 15)
            zusatz
        }
        .frame(maxWidth: .infinity)
    }

    /// "Host": 8 pt fett, #07070e auf #f59e0b, am Bild oben rechts (-4/-4).
    private var hostMarke: some View {
        Text("Host")
            .font(.marke(8, .bold))
            .foregroundColor(Farbe.grund)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4)
            .frame(height: 12)
            .background(Capsule().fill(KartenFarbe.bernstein))
    }

    private var creator: some View {
        HStack(spacing: 2) {
            Image(systemName: "crown")
                .font(.system(size: 6, weight: .semibold))
            Text(L("ERSTELLER", "CREATOR"))
                .font(.marke(8, .bold))
                .lineLimit(1)
        }
        .foregroundColor(KartenFarbe.bernstein)
        .frame(height: 12)
    }

    @ViewBuilder
    private var zusatz: some View {
        if !spieler.isConnected {
            Text(L("VERBINDET NEU…", "RECONNECTING…"))
                .font(.marke(9, .bold))
                .tracking(0.45)
                .foregroundColor(KartenFarbe.bernstein)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 13.5)
                .padding(.top, 2)
        } else if spieler.isPro {
            // PRO-Abzeichen: Krone 11, #fbbf24
            Image(systemName: "crown")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Farbe.gold)
                .frame(height: 11)
                .padding(.top, 2)
        }
    }
}

/// Das runde Spielerbild wie im Browser: weiss 7 % als Grund, darin das
/// Profilbild - sonst das Spielersymbol in hellem Lila (--acc-pale), und wer
/// gar kein Symbol hat, bekommt den ersten Buchstaben.
struct LobbyAvatar: View {
    let spieler: Spieler?
    var name: String = ""
    let groesse: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(bildAdresse == nil ? 0.07 : 0.05))
            if let url = bildAdresse {
                AsyncImage(url: url) { phase in
                    if let geladen = phase.image {
                        geladen.resizable().scaledToFill()
                    } else {
                        ersatz
                    }
                }
                .frame(width: groesse, height: groesse)
                .clipShape(Circle())
            } else {
                ersatz
            }
        }
        .frame(width: groesse, height: groesse)
    }

    private var bildAdresse: URL? {
        guard let s = spieler?.avatarUrl, s.hasPrefix("http") else { return nil }
        return URL(string: s)
    }

    @ViewBuilder
    private var ersatz: some View {
        if let s = spieler, s.iconId != 0 {
            Image(systemName: "person.fill")
                .font(.system(size: groesse * 0.44))
                .foregroundColor(KartenFarbe.blass)
        } else {
            Text(anfang)
                .font(.marke(groesse * 0.42, .bold))
                .foregroundColor(Farbe.schrift)
        }
    }

    private var anfang: String {
        let n: String = spieler?.nickname ?? name
        guard let c = n.first else { return "?" }
        return String(c).uppercased()
    }
}

/// Farben, die nur hier vorkommen.
private enum KartenFarbe {
    /// #f59e0b - "Host", "CREATOR", "RECONNECTING…"
    static let bernstein = Color(hex: 0xF59E0B)
    /// --acc-pale zu #b15cff
    static let blass = Color(hex: 0xCC95FF)
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
