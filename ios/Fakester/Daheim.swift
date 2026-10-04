import SwiftUI
import UIKit

/// Der Startbildschirm, Element fuer Element nach fakester.app im Handyformat
/// (375×812, als Gast, Oktober 2026):
/// - oben eine feste Leiste mit Profilchip und Spots, darunter ein feiner Strich,
/// - in der Mitte, senkrecht zentriert: Equalizer, Schriftzug, "Create Game"
///   breit neben "Join", die Online-Zeile, Daily, die vier farbigen Kacheln,
///   die vier ruhigen Knoepfe und die Stufenkarte,
/// - unten fest die Fussleiste.
///
/// "Create Game", "Join" und "Board" fuehren in eigene Bildschirme bzw. den
/// Beitreten-Dialog. Gaeste sehen ueberall sonst - wie im Browser - den
/// Gast-Hinweis; mit Konto sagt ein Tipp ehrlich, was es nur im Browser gibt.
struct DaheimAnsicht: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var spiel: Spiel

    @State private var pin = ""
    @State private var beitreten = false
    @State private var erstellen = false
    @State private var rangliste = false
    @State private var quests = false
    @State private var gastSperre = false
    @State private var tagesBonus: TagesBonus?
    @State private var live: LiveZahlen?

    private var dialogOffen: Bool { beitreten || gastSperre }

    var body: some View {
        // Der Startbildschirm passt im Browser auf einen Bildschirm, und genau
        // so soll er sich anfuehlen: alles Wichtige ohne Wischen erreichbar.
        // Deshalb misst die Ansicht die Hoehe, die da ist, und rueckt auf
        // kleineren Geraeten zusammen (`Dichte`: eng / sehr eng), statt unten
        // abzuschneiden. Gescrollt werden kann die Mitte trotzdem - wie im
        // Browser, wo sie ebenfalls ein eigener Scrollbereich ist.
        ZStack {
            GeometryReader { geo in
                seite(Dichte(groesse: geo.size))
            }
            .blur(radius: dialogOffen ? 6 : 0)
            .allowsHitTesting(!dialogOffen)

            if beitreten {
                BeitretenDialog(pin: $pin,
                                beitreten: { pinBetreten() },
                                schliessen: { beitreten = false })
                    .transition(.opacity)
                    .zIndex(1)
            }
            if gastSperre {
                GastHinweis(nein: { gastSperre = false },
                            ja: { kontoErstellen() })
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.18), value: dialogOffen)
        .fullScreenCover(isPresented: $erstellen) {
            ErstellenAnsicht()
                .environmentObject(api)
                .environmentObject(spiel)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $rangliste) {
            RanglistenAnsicht()
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $quests) {
            QuestAnsicht()
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $tagesBonus) { b in
            TagesBonusBlatt(bonus: b)
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            // Bildschirmfotos im CI (Vorschau.swift): die beiden Dialoge
            // lassen sich als eigene Szene oeffnen.
            #if DEBUG
            if Vorschau.szene == "beitreten" { beitreten = true }
            if Vorschau.szene == "gastsperre" { gastSperre = true }
            #endif
        }
        .task { await tagesBonusPruefen() }
        .task {
            // Wie der Browser: alle 30 Sekunden frisch.
            while !Task.isCancelled {
                if let z: LiveZahlen = try? await api.holen("/stats/live") { live = z }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    /// Wohin eine Kachel fuehrt. Gaeste sehen - wie im Browser - ueberall ausser
    /// bei der Rangliste den Konto-Hinweis.
    private func ziel(_ id: String, _ name: String) {
        Spuerbar.tipp()
        if id == "board" {
            rangliste = true
            return
        }
        guard api.angemeldet else {
            gastSperre = true
            return
        }
        if id == "quests" {
            quests = true
        } else {
            nurImBrowser(name)
        }
    }

    @MainActor
    private func tagesBonusPruefen() async {
        guard api.angemeldet, tagesBonus == nil else { return }
        if let b: TagesBonus = try? await api.holen("/daily-checkin"), b.abholbar {
            tagesBonus = b
        }
    }

    private func nurImBrowser(_ was: String) {
        spiel.meldung = L("\(was) gibt's bisher nur im Browser.", "\(was) is browser-only for now.")
    }

    private func pinBetreten() {
        guard pin.count == 4, let a = api.ausweis else { return }
        Spuerbar.tipp()
        spiel.betreten(pin: pin, als: a)
        beitreten = false
    }

    /// "Yes" im Gast-Hinweis: zurueck zur Anmeldung, dort laesst sich ein
    /// Konto anlegen.
    private func kontoErstellen() {
        gastSperre = false
        api.abmelden()
    }

    // MARK: Aufbau

    private func seite(_ m: Dichte) -> some View {
        VStack(spacing: 0) {
            kopf(m)
            GeometryReader { innen in
                ScrollView(.vertical, showsIndicators: false) {
                    mitte(m)
                        .padding(.horizontal, 20)
                        .padding(.vertical, m.mittePolster)
                        .frame(width: innen.size.width)
                        .frame(minHeight: innen.size.height)
                }
            }
            fuss(m)
        }
    }

    /// Kopfleiste: px 12, py 10, unten ein Strich (border-b, weiss 7 %).
    private func kopf(_ m: Dichte) -> some View {
        HStack(spacing: 10) {
            KopfChip()
            Spacer(minLength: 0)
            SpotsPille()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, m.kopfPolster)
        .padding(.bottom, 1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Farbe.linie).frame(height: 1)
        }
    }

    private func mitte(_ m: Dichte) -> some View {
        VStack(spacing: m.gruppe) {
            AktualisierungsKarte()
            held(m)
            VStack(spacing: m.reihe) {
                DailyKarte(eng: m.sehrEng) { ziel("daily", "Daily") }
                kacheln(m)
                ruhigeKnoepfe(m)
            }
            StufenKarte(eng: m.sehrEng)
        }
        .frame(maxWidth: 680)
    }

    // MARK: Held

    /// Equalizer (20 hoch, 10 Abstand), Schriftzug (46, 16 Abstand), die
    /// beiden Knoepfe und 12 darunter die Online-Zeile.
    private func held(_ m: Dichte) -> some View {
        VStack(spacing: 0) {
            Equalizer()
                .padding(.bottom, m.eqAbstand)
            Schriftzug(groesse: m.zug)
                .frame(height: m.zug)
                .padding(.bottom, m.zugAbstand)
            spielknoepfe(m)
            OnlineZeile(live: live)
                .padding(.top, m.onlineAbstand)
        }
    }

    /// Im Browser stehen die beiden nebeneinander, hoechstens 340 breit, im
    /// Verhaeltnis 1,45 : 1 - erstellen ist der Hauptweg, beitreten der kurze.
    private func spielknoepfe(_ m: Dichte) -> some View {
        let reihe: CGFloat = max(120, min(340, m.breite - 40))
        let erstellBreite: CGFloat = (reihe - 10) * 1.45 / 2.45
        let beitretenBreite: CGFloat = reihe - 10 - erstellBreite
        return HStack(spacing: 10) {
            Button {
                Spuerbar.tipp()
                erstellen = true
            } label: {
                erstellenBeschriftung
            }
            .buttonStyle(ErstellStil(hoehe: m.knopf))
            .frame(width: erstellBreite)

            Button {
                Spuerbar.tipp()
                pin = ""
                beitreten = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 13, weight: .medium))
                    Text(L("Beitreten", "Join"))
                }
            }
            .buttonStyle(BeitretenStil(hoehe: m.knopf))
            .frame(width: beitretenBreite)
        }
    }

    /// Das Abspiel-Dreieck sitzt im Browser in einem dunklen Kreis (22, schwarz 16 %).
    private var erstellenBeschriftung: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.black.opacity(0.16))
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .offset(x: 1)
            }
            .frame(width: 22, height: 22)
            Text(L("Spiel erstellen", "Create Game"))
        }
    }

    // MARK: Kacheln

    private func kacheln(_ m: Dichte) -> some View {
        HStack(spacing: 8) {
            ForEach(Kachel.alle) { k in
                KachelKnopf(kachel: k, eng: m.sehrEng) { ziel(k.id, k.name) }
            }
        }
    }

    private func ruhigeKnoepfe(_ m: Dichte) -> some View {
        let spalten: [GridItem] = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: spalten, spacing: m.reihe) {
            ForEach(Kachel.ruhige) { k in
                FlachKnopf(name: k.name, symbol: k.symbol, eng: m.sehrEng) { ziel(k.id, k.name) }
            }
        }
    }

    // MARK: Fuss

    /// Drei Pillen, 36 hoch, mittig: Logout, die blaue Discord-Pille (in der
    /// App: Feedback) und die leise Versions-Pille (in der App: Sprache).
    private func fuss(_ m: Dichte) -> some View {
        HStack(spacing: 10) {
            FussKnopf(name: L("Abmelden", "Logout"), symbol: "rectangle.portrait.and.arrow.right") {
                api.abmelden()
            }
            FussKnopf(name: "Feedback", symbol: "bubble.left.and.bubble.right",
                      farbe: Color(hex: 0x8B95F7),
                      grund: Farbe.discord.opacity(0.16),
                      kante: Farbe.discord.opacity(0.35),
                      symbolGroesse: 12) {
                NotificationCenter.default.post(name: .geschuettelt, object: nil)
            }
            SprachPille()
        }
        .padding(.horizontal, 20)
        .padding(.top, m.fussOben)
        .padding(.bottom, m.fussUnten)
    }
}

// MARK: - Dichte

/// Die Abstaende des Startbildschirms je nach verfuegbarer Hoehe. Stufe 0 sind
/// die Werte des Browsers (375×812); darunter rueckt alles zusammen, damit der
/// Bildschirm auch auf einem 12 mini (eng) und einem SE (sehr eng) ohne
/// Wischen ganz zu sehen ist.
private struct Dichte {
    let breite: CGFloat
    /// 0 = wie im Browser, 1 = eng, 2 = sehr eng
    let stufe: Int

    init(groesse: CGSize) {
        breite = groesse.width
        let h: CGFloat = groesse.height
        // Stufe 0 braucht ~740, Stufe 1 ~705, Stufe 2 ~628 Punkte.
        stufe = h >= 745 ? 0 : (h >= 708 ? 1 : 2)
    }

    var eng: Bool { stufe >= 1 }
    var sehrEng: Bool { stufe >= 2 }

    var kopfPolster: CGFloat { sehrEng ? 6 : 10 }
    var mittePolster: CGFloat { eng ? (sehrEng ? 8 : 12) : 20 }
    var gruppe: CGFloat { eng ? (sehrEng ? 10 : 14) : 20 }
    var reihe: CGFloat { sehrEng ? 6 : 8 }
    var eqAbstand: CGFloat { sehrEng ? 6 : 10 }
    /// clamp(46px, min(12vw, 16vh), 128px)
    var zug: CGFloat { sehrEng ? 40 : max(46, min(breite * 0.12, 128)) }
    var zugAbstand: CGFloat { eng ? (sehrEng ? 10 : 14) : 16 }
    var knopf: CGFloat { sehrEng ? 48 : 55 }
    var onlineAbstand: CGFloat { sehrEng ? 8 : 12 }
    var fussOben: CGFloat { sehrEng ? 6 : 8 }
    var fussUnten: CGFloat { eng ? (sehrEng ? 10 : 12) : 16 }
}

// MARK: - Farben und Helfer nur fuer diesen Bildschirm

private enum DaheimFarbe {
    /// #b0aed2 - Unterzeilen und die ruhigen Knoepfe
    static let zart = Color(hex: 0xB0AED2)
    /// #c9c8e0 - Text im Gast-Hinweis
    static let hinweis = Color(hex: 0xC9C8E0)
    /// --acc-pale fuer #b15cff (Helligkeit + 35 %), die Figur im Profilbild
    static let akzentBlass = Color(hex: 0xCC95FF)
    static let leiste = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    static let flach = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.5)
    static let stufe = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.75)
    static let dialog = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)
    static let version = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.55)
}

/// color-mix(in srgb, Farbe x %, rgba(24,23,39,.8)) - so mischt der Browser
/// den Grund der farbigen Kacheln und der Daily-Karte.
private func mischung(_ farbe: Color, _ anteil: Double, grundDeckung: Double = 0.8) -> Color {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    _ = UIColor(farbe).getRed(&r, green: &g, blue: &b, alpha: &a)
    let rest: Double = (1 - anteil) * grundDeckung
    let deckung: Double = anteil + rest
    let rot: Double = (anteil * Double(r) + rest * 24 / 255) / deckung
    let gruen: Double = (anteil * Double(g) + rest * 23 / 255) / deckung
    let blau: Double = (anteil * Double(b) + rest * 39 / 255) / deckung
    return Color(.sRGB, red: rot, green: gruen, blue: blau, opacity: deckung)
}

private enum Zahlform {
    static let dezimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}

/// toLocaleString() wie im Browser: 1234 → "1,234" bzw. "1.234".
private func tausender(_ n: Int) -> String {
    Zahlform.dezimal.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// Druckgefuehl wie framer-motion `whileTap: {scale}`.
private struct SanftDruck: ButtonStyle {
    var skala: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? skala : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Create Game": flaches Lila, Ecken 16, 0 8px 24px Schein in --acc-deep 30 %,
/// innen oben ein heller Strich (inset 0 1px 0 weiss 18 %), 15 pt fett weiss.
private struct ErstellStil: ButtonStyle {
    var hoehe: CGFloat = 55

    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return configuration.label
            .font(.marke(15, .bold))
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: hoehe)
            .background(form.fill(Farbe.akzent))
            .overlay(Lichtkante(radius: 16, staerke: 0.18))
            .shadow(color: Farbe.akzentTief.opacity(0.3), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Join": rgba(20,18,38,.75), Kante weiss 9 %, Schrift #d8d7ee 14 pt halbfett.
private struct BeitretenStil: ButtonStyle {
    var hoehe: CGFloat = 55

    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let grund: Color = Color(.sRGB, red: 20 / 255, green: 18 / 255, blue: 38 / 255, opacity: 0.75)
        return configuration.label
            .font(.marke(14, .semibold))
            .foregroundColor(Color(hex: 0xD8D7EE))
            .frame(maxWidth: .infinity)
            .frame(height: hoehe)
            .background(form.fill(grund))
            .overlay(form.strokeBorder(Farbe.kante, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Kopfleiste

/// Profilchip oben links: rgba(24,23,39,.9), Kante weiss 7 %, Ecken 16,
/// Polster 6/10/6/6. Rundes Bild (32, Ring in Lila 70 %), unten rechts die
/// Stufe als orange Perle, daneben der Name in Lila (13 pt fett).
private struct KopfChip: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        let stufe: Int = Api.Stufe.fuerXp(api.ich?.xp ?? 0)
        HStack(spacing: 8) {
            KopfBild(stufe: stufe)
            Text(api.ausweis?.username ?? "")
                .font(.marke(13, .bold))
                .foregroundColor(Farbe.akzent)
                .lineLimit(1)
        }
        .padding(.leading, 7)
        .padding(.trailing, 11)
        .padding(.vertical, 7)
        .background(form.fill(DaheimFarbe.leiste))
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }
}

private struct KopfBild: View {
    let stufe: Int
    @EnvironmentObject private var api: Api

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            inhalt
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Farbe.akzent.opacity(0.7), lineWidth: 2))
        .shadow(color: Farbe.akzent.opacity(0.3), radius: 5)
        .overlay(alignment: .bottomTrailing) {
            perle.offset(x: 2, y: 2)
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let s = api.ich?.avatar_url, s.hasPrefix("http"), let url = URL(string: s) {
            AsyncImage(url: url) { phase in
                if let bild = phase.image {
                    bild.resizable().scaledToFill()
                } else {
                    figur
                }
            }
        } else if let e = api.ich?.equipped_emoji, !e.isEmpty {
            Text(e).font(.system(size: 15))
        } else {
            figur
        }
    }

    private var figur: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(DaheimFarbe.akzentBlass)
    }

    /// 15 hoch, mind. 15 breit, #f59e0b, Schrift #07070e 9 pt, Rand 2 in Kartenfarbe.
    private var perle: some View {
        Text("\(stufe)")
            .font(.marke(9, .heavy))
            .foregroundColor(Farbe.grund)
            .padding(.horizontal, 5)
            .frame(minWidth: 15)
            .frame(height: 15)
            .background(Capsule().fill(Color(hex: 0xF59E0B)))
            .overlay(Capsule().strokeBorder(Color(hex: 0x181727), lineWidth: 2))
    }
}

/// Die Spots oben rechts: Pille rgba(24,23,39,.9), Note und Zahl in Lila
/// (11 pt fett). Gaeste sehen - wie im Browser - eine 0. GoldSpots kommen
/// hinter einem feinen Strich dazu, sobald es welche gibt; PRO als eigene Pille.
struct SpotsPille: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let spots: Int = api.ich?.spots ?? 0
        let gold: Int = api.ich?.gold_spots ?? 0
        HStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                    Text(tausender(spots))
                        .font(.marke(11, .bold))
                }
                .foregroundColor(Farbe.akzent)
                if gold > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 12)
                    HStack(spacing: 4) {
                        GoldMuenze()
                        Text(tausender(gold))
                            .font(.marke(11, .bold))
                    }
                    .foregroundColor(Farbe.gold)
                }
            }
            .modifier(LeistenPille())

            if api.ich?.is_pro == true {
                Text("PRO")
                    .font(.marke(11, .bold))
                    .foregroundColor(Farbe.gold)
                    .modifier(LeistenPille())
            }
        }
    }
}

/// px 10, py 6, rund, rgba(24,23,39,.9), Kante weiss 7 % → 31 hoch.
private struct LeistenPille: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .frame(height: 31)
            .background(Capsule().fill(DaheimFarbe.leiste))
            .overlay(Capsule().strokeBorder(Farbe.linie, lineWidth: 1))
    }
}

/// Die GoldSpot-Muenze des Browsers: Ring #fbbf24 mit 20 % Fuellung und Punkt.
private struct GoldMuenze: View {
    var body: some View {
        ZStack {
            Circle().fill(Farbe.gold.opacity(0.2))
            Circle().stroke(Farbe.gold, lineWidth: 1.2)
            Circle().fill(Farbe.gold).frame(width: 3.3, height: 3.3)
        }
        .frame(width: 10.5, height: 10.5)
        .frame(width: 12, height: 12)
    }
}

// MARK: - Bausteine der Mitte

/// Die neun Balken ueber dem Schriftzug: 3 breit, 3 Abstand, Lila 55 %, in
/// einem 20 hohen Kasten unten ausgerichtet. Sie wippen wie im Browser
/// (`eq`: scaleY 1 → .22 → 1, je Balken eigene Dauer und Verzoegerung).
struct Equalizer: View {
    @State private var an = false
    private let hoehen: [CGFloat] = [8, 14, 10, 18, 12, 16, 9, 13, 11]
    private let dauer: [Double] = [0.55, 0.40, 0.70, 0.45, 0.60, 0.50, 0.65, 0.42, 0.58]
    private let verzug: [Double] = [0.00, 0.08, 0.04, 0.12, 0.06, 0.10, 0.02, 0.14, 0.07]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<hoehen.count, id: \.self) { i in
                Capsule()
                    .fill(Farbe.akzent.opacity(0.55))
                    .frame(width: 3, height: hoehen[i])
                    .scaleEffect(x: 1, y: an ? 0.22 : 1, anchor: .bottom)
                    .animation(.easeInOut(duration: dauer[i] / 2)
                        .repeatForever(autoreverses: true)
                        .delay(verzug[i]), value: an)
            }
        }
        .frame(height: 20, alignment: .bottom)
        .onAppear { an = true }
    }
}

/// `● 3 online | 1 lobbies` unter den Spielknoepfen, 11 pt, #7877a0, die Zahl
/// #eef halbfett, der Punkt pulsiert (animate-ping). Die Zahl kommt aus
/// `/stats/live`; bis sie da ist, bleibt die Zeile leer statt eine erfundene
/// Null zu zeigen - ihre Hoehe bleibt aber reserviert.
struct OnlineZeile: View {
    let live: LiveZahlen?

    var body: some View {
        HStack(spacing: 12) {
            if let z = live {
                HStack(spacing: 6) {
                    PulsPunkt()
                    (Text(tausender(z.players)).font(.marke(11, .semibold)).foregroundColor(Farbe.schrift)
                     + Text(" online"))
                }
                if z.lobbies > 0 {
                    Rectangle().fill(Farbe.linie).frame(width: 1, height: 12)
                    (Text(tausender(z.lobbies)).font(.marke(11, .semibold)).foregroundColor(Farbe.schrift)
                     + Text(L(" Lobbys", " lobbies")))
                }
            }
        }
        .font(.marke(11, .medium))
        .foregroundColor(Farbe.leise)
        .frame(height: 17)
    }
}

/// Der Punkt vor "online": 6 gross, darueber ein Ring, der auf das Doppelte
/// waechst und dabei verblasst (1 s, endlos).
private struct PulsPunkt: View {
    @State private var an = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Farbe.akzent)
                .scaleEffect(an ? 2 : 1)
                .opacity(an ? 0 : 0.7)
                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: an)
            Circle().fill(Farbe.akzent)
        }
        .frame(width: 6, height: 6)
        .onAppear { an = true }
    }
}

/// Die Daily-Karte: 64 hoch, Ecken 16, Grund Lila 9 % in rgba(24,23,39,.8),
/// Kante Lila 30 %, runder Symbolkreis (36, Lila 18 %), "Daily" 14 pt fett,
/// Unterzeile 11 pt #b0aed2, Pfeil in Lila.
struct DailyKarte: View {
    /// Nur auf sehr kleinen Geraeten: etwas weniger Polster.
    var eng: Bool = false
    let aktion: () -> Void

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        Button(action: aktion) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Farbe.akzent.opacity(0.18))
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Farbe.akzent)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Daily")
                        .font(.marke(14, .bold))
                        .foregroundColor(Farbe.schrift)
                        .frame(height: 21)
                    Text(L("Fünf Songs für alle. Ein Versuch.", "Same five songs for everyone. One try."))
                        .font(.marke(11, .medium))
                        .foregroundColor(DaheimFarbe.zart)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(height: 17)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Farbe.akzent)
            }
            // Polster 12/14 plus 1 fuer den Rand, der im Browser aussen liegt.
            .padding(.horizontal, 15)
            .padding(.vertical, eng ? 11 : 13)
            .frame(maxWidth: .infinity)
            .background(form.fill(mischung(Farbe.akzent, 0.09)))
            .overlay(form.strokeBorder(Farbe.akzent.opacity(0.3), lineWidth: 1))
            .overlay(Lichtkante(radius: 16, staerke: 0.05))
        }
        .buttonStyle(SanftDruck(skala: 0.985))
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

/// Farbige Kachel: 79 hoch, Ecken 16, Grund Farbton 7 % in rgba(24,23,39,.8),
/// Kante Farbton 26 %, runder Symbolkreis 36 (Farbton 16 %, Kante 30 %),
/// Name 11 pt fett #eef.
struct KachelKnopf: View {
    let kachel: Kachel
    /// Nur auf sehr kleinen Geraeten: etwas weniger Polster.
    var eng: Bool = false
    let aktion: () -> Void

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        let ton: Color = kachel.farbe
        Button(action: aktion) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(ton.opacity(0.16))
                    Circle().strokeBorder(ton.opacity(0.3), lineWidth: 1)
                    Image(systemName: kachel.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ton)
                }
                .frame(width: 36, height: 36)

                Text(kachel.name)
                    .font(.marke(11, .bold))
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: 11)
            }
            .padding(.vertical, eng ? 11 : 13)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .background(form.fill(mischung(ton, 0.07)))
            .overlay(form.strokeBorder(ton.opacity(0.26), lineWidth: 1))
            .overlay(Lichtkante(radius: 16, staerke: 0.04))
        }
        .buttonStyle(SanftDruck(skala: 0.97))
    }
}

/// Ruhiger Knopf: 40 hoch, Ecken 18, rgba(24,23,39,.5), Kante weiss 5 %,
/// Symbol #8d8ba4, Name 12 pt halbfett #b0aed2.
struct FlachKnopf: View {
    let name: String
    let symbol: String
    /// Nur auf sehr kleinen Geraeten: 38 statt 40 hoch.
    var eng: Bool = false
    let aktion: () -> Void

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 18, style: .circular)
        Button(action: aktion) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Farbe.gedaempft)
                Text(name)
                    .font(.marke(12, .semibold))
                    .foregroundColor(DaheimFarbe.zart)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity)
            .frame(height: eng ? 38 : 40)
            .background(form.fill(DaheimFarbe.flach))
            .overlay(form.strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(SanftDruck(skala: 0.97))
    }
}

/// Pille in der Fussleiste, 36 hoch. Vorgabe ist "Logout": rgba(24,23,39,.7),
/// Kante weiss 7 %, Schrift #7877a0 12 pt halbfett, Polster 14, Abstand 8.
struct FussKnopf: View {
    let name: String
    let symbol: String
    var farbe: Color = Farbe.leise
    var grund: Color = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.7)
    var kante: Color = Farbe.linie
    var symbolGroesse: CGFloat = 12
    var schrift: CGFloat = 12
    var polster: CGFloat = 14
    var abstand: CGFloat = 8
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: abstand) {
                Image(systemName: symbol)
                    .font(.system(size: symbolGroesse, weight: .medium))
                Text(name)
                    .font(.marke(schrift, .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(farbe)
            .padding(.horizontal, polster + 1)
            .frame(height: 36)
            .background(Capsule().fill(grund))
            .overlay(Capsule().strokeBorder(kante, lineWidth: 1))
        }
        .buttonStyle(SanftDruck(skala: 0.96))
    }
}

/// Die dritte Pille im Fuss sieht aus wie die Versions-Pille des Browsers
/// (rgba(24,23,39,.55), #5c5b7d, 11 pt) und schaltet die Sprache um.
private struct SprachPille: View {
    @AppStorage(Sprache.schluessel) private var sprache: String = ""

    var body: some View {
        let englisch: Bool = Sprache.aktuell == .en
        FussKnopf(name: englisch ? "Deutsch" : "English", symbol: "globe",
                  farbe: Color(hex: 0x5C5B7D),
                  grund: DaheimFarbe.version,
                  kante: Color.white.opacity(0.06),
                  symbolGroesse: 10, schrift: 11, polster: 12, abstand: 6) {
            sprache = (englisch ? Sprache.de : Sprache.en).rawValue
        }
    }
}

/// Stufe, Fortschritt und die drei Zahlen darunter - im Browser auch fuer
/// Gaeste (dann Stufe 1, "50 XP to 2", dreimal 0).
/// 109 hoch, Ecken 16, rgba(24,23,39,.75), Kante weiss 7 %, Polster 12/14.
struct StufenKarte: View {
    /// Nur auf sehr kleinen Geraeten: etwas weniger Polster.
    var eng: Bool = false
    @EnvironmentObject private var api: Api

    var body: some View {
        let k: Api.Konto? = api.ich
        let xp: Int = k?.xp ?? 0
        let stufe: Int = Api.Stufe.fuerXp(xp)
        let fehlt: Int = max(0, Api.Stufe.xpAb(stufe + 1) - xp)
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(alignment: .leading, spacing: eng ? 8 : 10) {
            HStack(spacing: 12) {
                Text("\(stufe)")
                    .font(.marke(15, .heavy))
                    .foregroundColor(Color.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Farbe.akzent))

                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Text(L("STUFE \(stufe)", "LEVEL \(stufe)")).etikett()
                        Spacer(minLength: 0)
                        Text(L("\(tausender(fehlt)) XP bis \(stufe + 1)", "\(tausender(fehlt)) XP to \(stufe + 1)"))
                            .font(.marke(10, .medium))
                            .foregroundColor(Farbe.gedaempft)
                            .lineLimit(1)
                    }
                    .frame(height: 15)
                    StufenBalken(anteil: Api.Stufe.anteil(xp: xp))
                }
            }

            HStack(alignment: .top, spacing: 0) {
                zahl(k?.games_played ?? 0, L("SPIELE", "GAMES"))
                Spacer(minLength: 16)
                zahl(k?.wins ?? 0, L("SIEGE", "WINS"))
                Spacer(minLength: 16)
                zahl(k?.highscore ?? 0, L("BESTE", "BEST"))
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, eng ? 11 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(form.fill(DaheimFarbe.stufe))
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }

    /// Zahl 14 pt sehr fett, darunter (4 Abstand) das Etikett.
    private func zahl(_ wert: Int, _ wort: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tausender(wert))
                .font(.marke(14, .heavy))
                .foregroundColor(Farbe.schrift)
                .frame(height: 14)
            Text(wort).etikett()
                .frame(height: 15)
        }
    }
}

/// h-1.5: 6 hoch, weiss 7 % als Bahn, Lila als Fuellung.
private struct StufenBalken: View {
    let anteil: Double

    var body: some View {
        GeometryReader { raum in
            ZStack(alignment: .leading) {
                Capsule().fill(Farbe.linie)
                Capsule()
                    .fill(Farbe.akzent)
                    .frame(width: raum.size.width * CGFloat(max(0, min(1, anteil))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Gast-Hinweis

/// "That one needs an account" - der Bestaetigungsdialog des Browsers:
/// Schleier rgba(4,4,10,.72), Karte hoechstens 360 breit, 16 vom Rand,
/// rgba(24,23,39,.98), Kante Lila 40 %, Ecken 24, Schatten 0 24px 60px.
/// Oben Schloss + "GUEST MODE" (10 pt, gesperrt, Lila), Titel 18 pt sehr fett,
/// Text 13 pt #c9c8e0, unten "No" (ruhig) und "Yes" (Lila).
private struct GastHinweis: View {
    let nein: () -> Void
    let ja: () -> Void

    /// 16 Polster plus 1 fuer den Rand.
    private let innen: CGFloat = 17

    var body: some View {
        ZStack {
            Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.72)
                .ignoresSafeArea()
                .onTapGesture { nein() }
            karte
                .frame(maxWidth: 360)
                .padding(16)
        }
    }

    private var karte: some View {
        let form = RoundedRectangle(cornerRadius: 24, style: .circular)
        return VStack(alignment: .leading, spacing: 0) {
            kopfzeile
            Text(L("Dafür brauchst du ein Konto", "That one needs an account"))
                .font(.marke(18, .heavy))
                .foregroundColor(Farbe.schrift)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, innen)
                .padding(.top, 8)
                .padding(.bottom, 4)
            Text(nachricht)
                .font(.system(size: 13))
                .lineSpacing(5)
                .foregroundColor(DaheimFarbe.hinweis)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, innen)
                .padding(.top, 4)
                .padding(.bottom, 16)
            knoepfe
                .padding(.horizontal, innen)
                .padding(.bottom, innen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(form.fill(DaheimFarbe.dialog).shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 24))
        .overlay(form.strokeBorder(Farbe.akzent.opacity(0.4), lineWidth: 1))
    }

    private var kopfzeile: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 11, weight: .semibold))
            Text(L("GASTMODUS", "GUEST MODE"))
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
        }
        .foregroundColor(Farbe.akzent)
        .frame(height: 15)
        .padding(.horizontal, innen)
        .padding(.top, innen)
    }

    private var knoepfe: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 8) {
            Button(action: nein) {
                Text(L("Nein", "No"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DaheimFarbe.hinweis)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(form.fill(Color.white.opacity(0.04)))
                    .overlay(form.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(SanftDruck(skala: 0.97))

            Button(action: ja) {
                Text(L("Ja", "Yes"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(form.fill(Farbe.akzent))
            }
            .buttonStyle(SanftDruck(skala: 0.97))
        }
    }

    /// Wortgleich mit dem Browser bis auf dessen letzten Satz ("Making one keeps
    /// the name you are playing under right now.") - das stimmt in der App
    /// nicht, hier fuehrt "Yes" zur Anmeldung, und der Gastname bleibt nicht.
    private var nachricht: String {
        L("Gäste können alles spielen – jeden Modus, jede Lobby und die Rangliste.\n\nXP, Spots, Gegenstände und Freunde gehören zu einem Konto, deshalb liegen sie hinter einer Anmeldung.",
          "Guests can play everything — every mode, every lobby, and the leaderboard.\n\nXP, Spots, items and friends belong to an account, so they sit behind a sign-up.")
    }
}

// MARK: - Beitreten

/// "Join game" wie im Browser: Schleier schwarz 75 %, Karte 320 breit,
/// rgba(24,23,39,.98), Kante weiss 7 %, Ecken 24, Polster 24, Abstand 20.
/// Vier PIN-Kaestchen (56, Ecken 16), darunter ein Ziffernblock 3 × 4
/// (57 hoch, Ecken 18) mit ×, 0 und "Join", ganz unten "Cancel".
/// "Browse public lobbies" fehlt bewusst - oeffentliche Lobbys kann die App
/// noch nicht auflisten.
private struct BeitretenDialog: View {
    @Binding var pin: String
    let beitreten: () -> Void
    let schliessen: () -> Void

    private let reihen: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { schliessen() }
            karte
                .frame(maxWidth: 320)
                .padding(.horizontal, 16)
        }
    }

    private var karte: some View {
        let form = RoundedRectangle(cornerRadius: 24, style: .circular)
        return VStack(alignment: .leading, spacing: 20) {
            Text(L("Spiel beitreten", "Join game"))
                .font(.marke(20, .bold))
                .foregroundColor(Farbe.schrift)
                .frame(height: 30)
            kaestchen
            ziffernblock
            Button(action: schliessen) {
                Text(L("Abbrechen", "Cancel"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Farbe.gedaempft)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SanftDruck(skala: 0.97))
        }
        // 24 Polster plus 1 fuer den Rand.
        .padding(25)
        .background(form.fill(DaheimFarbe.dialog).shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 0))
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }

    private var kaestchen: some View {
        let ziffern: [Character] = Array(pin)
        return HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                PinKasten(ziffer: i < ziffern.count ? String(ziffern[i]) : nil)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var ziffernblock: some View {
        VStack(spacing: 8) {
            ForEach(0..<reihen.count, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(reihen[r], id: \.self) { z in
                        Taste(aktion: { tippe(z) }) {
                            Text(z)
                                .font(.marke(18, .bold))
                                .foregroundColor(Farbe.schrift)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Taste(aktion: { loeschen() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Farbe.schrift)
                }
                Taste(aktion: { tippe("0") }) {
                    Text("0")
                        .font(.marke(18, .bold))
                        .foregroundColor(Farbe.schrift)
                }
                joinTaste
            }
        }
    }

    /// Gesperrt: --acc-deep 20 % mit leiser Schrift; mit vier Ziffern Lila/weiss.
    private var joinTaste: some View {
        let bereit: Bool = pin.count == 4
        let grund: Color = bereit ? Farbe.akzent : Farbe.akzentTief.opacity(0.2)
        return Taste(grund: grund, aktion: { if bereit { beitreten() } }) {
            Text(L("Beitreten", "Join"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(bereit ? Color.white : Farbe.gedaempft)
        }
    }

    private func tippe(_ z: String) {
        guard pin.count < 4 else { return }
        Spuerbar.tipp()
        pin += z
    }

    private func loeschen() {
        guard !pin.isEmpty else { return }
        Spuerbar.tipp()
        pin.removeLast()
    }
}

/// Ein PIN-Kaestchen: 56 × 56, weiss 4 %, Kante weiss 10 % (belegt: Lila 60 %),
/// Ziffer 22 pt sehr fett, leer ein Strich in #8d8ba4.
private struct PinKasten: View {
    let ziffer: String?

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        let kante: Color = ziffer == nil ? Color.white.opacity(0.1) : Farbe.akzent.opacity(0.6)
        ZStack {
            form.fill(Color.white.opacity(0.04))
            form.strokeBorder(kante, lineWidth: 1)
            if let z = ziffer {
                Text(z)
                    .font(.marke(22, .heavy))
                    .foregroundColor(Farbe.schrift)
            } else {
                Text("—")
                    .font(.marke(22, .heavy))
                    .foregroundColor(Farbe.gedaempft)
            }
        }
        .frame(width: 56, height: 56)
    }
}

/// Eine Taste des Ziffernblocks: 57 hoch, Ecken 18, weiss 4 %, Kante weiss 7 %.
private struct Taste<Inhalt: View>: View {
    var grund: Color = Color.white.opacity(0.04)
    let aktion: () -> Void
    @ViewBuilder var inhalt: Inhalt

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 18, style: .circular)
        Button(action: aktion) {
            inhalt
                .frame(maxWidth: .infinity)
                .frame(height: 57)
                .background(form.fill(grund))
                .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
        }
        .buttonStyle(SanftDruck(skala: 0.93))
    }
}
