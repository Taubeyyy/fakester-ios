import SwiftUI

/// Der Startbildschirm, Zug um Zug nach dem aufgebaut, was fakester.app heute
/// zeigt: Profilchip und Spots oben, grosser Schriftzug, "Create Game" breit
/// neben einem schmalen "Join", darunter Daily, die vier farbigen Kacheln, die
/// vier ruhigen Knoepfe, die Stufenkarte und der Fuss.
///
/// Die Kacheln fuehren in der App noch nirgends hin. Sie trotzdem zu zeigen ist
/// Absicht - wer die Webseite kennt, soll sich sofort zurechtfinden, und ein
/// Tipp sagt ehrlich, dass es das hier noch nicht gibt.
struct DaheimAnsicht: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var spiel: Spiel

    @State private var pin = ""
    @State private var beitreten = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                kopf
                AktualisierungsKarte()
                held
                spielknoepfe
                if beitreten { pinKarte.transition(.opacity.combined(with: .move(edge: .top))) }
                DailyKarte { nurImBrowser("Daily") }
                kacheln
                ruhigeKnoepfe
                StufenKarte()
                fuss
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func nurImBrowser(_ was: String) {
        Spuerbar.tipp()
        spiel.meldung = L("\(was) gibt's bisher nur im Browser.", "\(was) is browser-only for now.")
    }

    // MARK: Kopf

    private var kopf: some View {
        HStack(spacing: 10) {
            ProfilChip()
            Spacer(minLength: 0)
            SpotsPille()
        }
    }

    private var held: some View {
        VStack(spacing: 6) {
            Equalizer()
            Schriftzug(groesse: 52)
        }
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    // MARK: Spielen

    /// Im Browser stehen die beiden nebeneinander, und das Breitenverhaeltnis
    /// ist die halbe Aussage: erstellen ist der Hauptweg, beitreten der kurze.
    private var spielknoepfe: some View {
        HStack(spacing: 10) {
            Button {
                nurImBrowser(L("Spiel erstellen", "Creating a game"))
            } label: {
                Label(L("Spiel erstellen", "Create Game"), systemImage: "play.fill")
            }
            .buttonStyle(Hauptknopf())
            .frame(maxWidth: .infinity)

            Button {
                Spuerbar.tipp()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { beitreten.toggle() }
            } label: {
                Label(L("Beitreten", "Join"), systemImage: "arrow.right.to.line")
            }
            .buttonStyle(Nebenknopf())
            .frame(width: 128)
        }
    }

    private var pinKarte: some View {
        Karte {
            VStack(spacing: 12) {
                Text(L("LOBBY-PIN", "LOBBY PIN")).etikett()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Feld(text: $pin, platzhalter: "PIN", nurZiffern: true, mono: true)
                Button(L("Beitreten", "Join")) {
                    guard let a = api.ausweis else { return }
                    Spuerbar.tipp()
                    spiel.betreten(pin: pin, als: a)
                }
                .buttonStyle(Hauptknopf(aus: pin.count < 4))
                .disabled(pin.count < 4)
            }
        }
    }

    // MARK: Kacheln

    private var kacheln: some View {
        let spalten: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return LazyVGrid(columns: spalten, spacing: 10) {
            ForEach(Kachel.alle) { k in
                KachelKnopf(kachel: k) { nurImBrowser(k.name) }
            }
        }
    }

    private var ruhigeKnoepfe: some View {
        let spalten: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: spalten, spacing: 10) {
            ForEach(Kachel.ruhige) { k in
                FlachKnopf(name: k.name, symbol: k.symbol) { nurImBrowser(k.name) }
            }
        }
    }

    // MARK: Fuss

    private var fuss: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                FussKnopf(name: L("Abmelden", "Logout"), symbol: "rectangle.portrait.and.arrow.right") {
                    api.abmelden()
                }
                FussKnopf(name: "Feedback", symbol: "bubble.left.and.text.bubble.right", farbe: Farbe.discord) {
                    NotificationCenter.default.post(name: .geschuettelt, object: nil)
                }
                SprachKnopf()
            }
            Text(L("Tipp: Handy schütteln schickt auch Feedback.",
                   "Tip: shake your phone to send feedback too."))
                .font(.marke(11))
                .foregroundColor(Farbe.leise)
        }
        .padding(.top, 6)
    }
}

// MARK: - Bausteine des Startbildschirms

/// Die kleinen Balken ueber dem Schriftzug. Im Browser wippen sie; hier auch,
/// aber mit fest gewaehlten Hoehen statt Zufall - sonst sieht jeder Start anders
/// aus, und genau daran erkennt man eine Nachahmung.
struct Equalizer: View {
    @State private var an = false
    private let hoehen: [CGFloat] = [5, 9, 14, 8, 17, 11, 6, 13, 7]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(hoehen.enumerated()), id: \.offset) { i, h in
                Capsule()
                    .fill(Farbe.akzent.opacity(0.85))
                    .frame(width: 3, height: an ? h : h * 0.45)
                    .animation(.easeInOut(duration: 0.6 + Double(i % 4) * 0.18)
                        .repeatForever(autoreverses: true), value: an)
            }
        }
        .frame(height: 18)
        .onAppear { an = true }
    }
}

/// Die Spots oben rechts. Gaeste haben keine - dann bleibt die Stelle leer,
/// statt eine Null zu zeigen, die nach einem Fehler aussieht.
struct SpotsPille: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        if let s = api.ich?.spots {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Farbe.akzent)
                Text("\(s)")
                    .font(.mono(13))
                    .foregroundColor(Farbe.schrift)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Glas(radius: 999))
        }
    }
}

struct DailyKarte: View {
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Farbe.akzent.opacity(0.14))
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Farbe.akzent)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily")
                        .font(.marke(17, .heavy))
                        .foregroundColor(Farbe.schrift)
                    Text(L("Fünf Songs für alle. Ein Versuch.", "Same five songs for everyone. One try."))
                        .font(.marke(12, .medium))
                        .foregroundColor(Farbe.leise)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Farbe.akzent)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Glas(radius: 16))
        }
        .buttonStyle(BubbleDruck())
    }
}

/// Ein Ziel auf dem Startbildschirm.
struct Kachel: Identifiable {
    let id: String
    let name: String
    let symbol: String
    var farbe: Color = Farbe.leise

    /// Die vier bunten. Reihenfolge und Farbe wie im Browser.
    static var alle: [Kachel] {
        [
            Kachel(id: "shop", name: "Shop", symbol: "bag", farbe: Farbe.kachelLila),
            Kachel(id: "path", name: L("Pfad", "Path"), symbol: "map", farbe: Farbe.kachelGold),
            Kachel(id: "quests", name: "Quests", symbol: "checklist", farbe: Farbe.kachelGruen),
            Kachel(id: "style", name: "Style", symbol: "paintpalette", farbe: Farbe.kachelRosa)
        ]
    }

    /// Die vier ruhigen darunter.
    static var ruhige: [Kachel] {
        [
            Kachel(id: "board", name: L("Rangliste", "Board"), symbol: "chart.bar"),
            Kachel(id: "friends", name: L("Freunde", "Friends"), symbol: "person.2"),
            Kachel(id: "playlists", name: "Playlists", symbol: "bookmark"),
            Kachel(id: "settings", name: L("Einstellungen", "Settings"), symbol: "gearshape")
        ]
    }
}

struct KachelKnopf: View {
    let kachel: Kachel
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(kachel.farbe.opacity(0.14))
                    Image(systemName: kachel.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(kachel.farbe)
                }
                .frame(width: 42, height: 42)

                Text(kachel.name)
                    .font(.marke(12, .heavy))
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(kachel.farbe.opacity(0.07))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(kachel.farbe.opacity(0.28), lineWidth: 1)
                }
            )
        }
        .buttonStyle(BubbleDruck())
    }
}

struct FlachKnopf: View {
    let name: String
    let symbol: String
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Farbe.gedaempft)
                Text(name)
                    .font(.marke(14, .heavy))
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Glas(radius: 16))
        }
        .buttonStyle(BubbleDruck())
    }
}

struct FussKnopf: View {
    let name: String
    let symbol: String
    var farbe: Color = Farbe.gedaempft
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(name).font(.marke(12, .bold)).lineLimit(1)
            }
            .foregroundColor(farbe)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Glas(radius: 999))
        }
        .buttonStyle(BubbleDruck())
    }
}

/// Stufe, Fortschritt und die drei Zahlen darunter. Gaeste sehen die Karte
/// nicht: sie haben kein Konto, also auch keine Stufe - eine Karte voller
/// Nullen waere nur eine Erinnerung daran.
struct StufenKarte: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        if let k = api.ich, !(api.ausweis?.isGuest ?? true) {
            let xp: Int = k.xp ?? 0
            let stufe: Int = Api.Stufe.fuerXp(xp)
            let fehlt: Int = max(0, Api.Stufe.xpAb(stufe + 1) - xp)
            Karte(polster: 16) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Farbe.verlauf)
                            Text("\(stufe)")
                                .font(.marke(19, .black))
                                .foregroundColor(Farbe.aufAkzent)
                        }
                        .frame(width: 46, height: 46)
                        .shadow(color: Farbe.akzent.opacity(0.4), radius: 8)

                        Text(L("STUFE \(stufe)", "LEVEL \(stufe)")).etikett()

                        Spacer(minLength: 0)

                        Text(L("\(fehlt) XP bis \(stufe + 1)", "\(fehlt) XP to \(stufe + 1)"))
                            .font(.marke(12, .semibold))
                            .foregroundColor(Farbe.leise)
                    }

                    Balken(anteil: Api.Stufe.anteil(xp: xp), farbe: Farbe.akzent, hoehe: 7)

                    HStack(spacing: 0) {
                        Zahl(wert: k.games_played ?? 0, wort: L("SPIELE", "GAMES"), lage: .leading)
                        Zahl(wert: k.wins ?? 0, wort: L("SIEGE", "WINS"), lage: .center)
                        Zahl(wert: k.highscore ?? 0, wort: L("BESTE", "BEST"), lage: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func Zahl(wert: Int, wort: String, lage: Alignment) -> some View {
        let waag: HorizontalAlignment = lage == .leading ? .leading : (lage == .trailing ? .trailing : .center)
        VStack(alignment: waag, spacing: 2) {
            Text("\(wert)")
                .font(.marke(19, .black))
                .foregroundColor(Farbe.schrift)
            Text(wort).etikett()
        }
        .frame(maxWidth: .infinity, alignment: lage)
    }
}
