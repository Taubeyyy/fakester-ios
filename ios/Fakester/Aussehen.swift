import SwiftUI
import UIKit
import CoreText

/// Das Aussehen, gemessen an der laufenden fakester.app (Handyformat 375×812,
/// `getComputedStyle`, Oktober 2026) - nicht am alten style.css.
/// Die Namen in Klammern sind die CSS-Variablen bzw. Werte im Browser.
enum Farbe {
    static let grund      = Color(hex: 0x07070E)                 // --background
    static let grund3     = Color(hex: 0x15142A)                 // --muted (Eingabefelder)
    static let grund4     = Color(hex: 0x1A1831)                 // --secondary (Feld mit Fokus)
    static let flaeche    = Color(hex: 0x0F0E1C)                 // --card
    /// Die erhabenen Karten im Browser: rgba(24, 23, 39, .92).
    static let karte      = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.92)
    static let linie      = Color.white.opacity(0.07)            // --border
    static let kante      = Color.white.opacity(0.09)
    /// --acc: haengt am ausgeruesteten Gegenstand, Vorgabe ist dieses Lila.
    static let akzent     = Color(hex: 0xB15CFF)
    static let akzentTief = Color(hex: 0x7000D7)                 // der Schein unter lila Knoepfen
    static let akzentHell = Color(hex: 0xC77DFF)
    static let schrift    = Color(hex: 0xEEEEFF)                 // --foreground
    static let gedaempft  = Color(hex: 0x8D8BA4)                 // Etiketten, "/ 5"
    static let leise      = Color(hex: 0x7877A0)                 // --muted-foreground
    static let gut        = Color(hex: 0x34D399)                 // --accent
    static let schlecht   = Color(hex: 0xF87171)                 // --destructive
    static let gold       = Color(hex: 0xFBBF24)
    /// Schrift auf dem lila Knopf - im Browser weiss.
    static let aufAkzent  = Color.white

    /// Die vier Farben der Kacheln auf dem Startbildschirm - im Browser traegt
    /// jede ihren eigenen Ton, das ist dort der halbe Wiedererkennungswert.
    static let kachelLila  = Color(hex: 0xA78BFA)
    static let kachelGold  = Color(hex: 0xFBBF24)
    static let kachelGruen = Color(hex: 0x34D399)
    static let kachelRosa  = Color(hex: 0xF472B6)
    static let discord     = Color(hex: 0x5865F2)

    /// Der grosse Knopf. Im Browser eine flache Farbe (#b15cff), kein Verlauf -
    /// der Name bleibt, damit alle Stellen weiter passen.
    static let verlauf = LinearGradient(colors: [Color(hex: 0xB15CFF), Color(hex: 0xB15CFF)],
                                        startPoint: .top, endPoint: .bottom)
    /// "STER" im Schriftzug - ebenfalls flach.
    static let verlaufHeld = LinearGradient(colors: [Color(hex: 0xB15CFF), Color(hex: 0xB15CFF)],
                                            startPoint: .leading, endPoint: .trailing)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Schrift

/// Welche Schrift die Webseite wirklich zeigt: Das Bundle fragt per Inline-Stil
/// nach "Bricolage Grotesque" und "DM Sans", liefert die Dateien aber unter den
/// Namen "Bricolage Grotesque Variable" / "DM Sans Variable" aus. Die Namen
/// passen nicht zusammen, also laedt kein Browser die Schriften (document.fonts
/// zeigt nur Font Awesome als geladen) und es greift `sans-serif`. Safari auf
/// dem iPhone nimmt dafuer Helvetica: Gewicht bis 500 normal, ab 600 fett.
/// Ein paar Stellen (Auflösungsblatt, Gast-Hinweis) laufen ueber Tailwinds
/// `system-ui` - das ist San Francisco, siehe `Font.system`.
enum Schrift {
    static func ui(_ groesse: CGFloat, _ gewicht: Font.Weight) -> UIFont {
        let name: String
        switch gewicht {
        case .ultraLight, .thin, .light: name = "Helvetica-Light"
        case .semibold, .bold, .heavy, .black: name = "Helvetica-Bold"
        default: name = "Helvetica"
        }
        if let f = UIFont(name: name, size: groesse) { return f }
        return UIFont.systemFont(ofSize: groesse, weight: name == "Helvetica-Bold" ? .bold : .regular)
    }
}

extension Font {
    /// Die Schrift der Webseite (Helvetica, siehe `Schrift`).
    static func marke(_ groesse: CGFloat, _ gewicht: Font.Weight = .regular) -> Font {
        Font(Schrift.ui(groesse, gewicht) as CTFont)
    }

    /// Frueher DM Mono. Die Webseite zeigt PIN und Punkte in derselben Schrift
    /// wie alles andere - also Helvetica, standardmaessig fett.
    static func mono(_ groesse: CGFloat, fett: Bool = true) -> Font {
        Font(Schrift.ui(groesse, fett ? .bold : .regular) as CTFont)
    }
}

// MARK: - Bausteine

/// Der Hintergrund des ganzen Spiels wie im Browser: #07070e, ein Punkteraster
/// (26 px, 1 px weiss 4 %) und drei weiche Farbflecken, die langsam treiben
/// (.blob-a lila oben links, .blob-b gruen unten rechts, .blob-c magenta mittig).
struct Buehne: View {
    @State private var treiben = false

    var body: some View {
        GeometryReader { geo in
            let b: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            ZStack(alignment: .topLeading) {
                Farbe.grund
                Punkteraster()
                Fleck(farbe: Color(hex: 0x7000D7), durchmesser: 600, unschaerfe: 90)
                    .opacity(0.28)
                    .scaleEffect(treiben ? 1.06 : 1)
                    .position(x: -96 + 300, y: (treiben ? -44 : 0) - 192 + 300)
                    .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: treiben)
                Fleck(farbe: Color(hex: 0x065F46), durchmesser: 520, unschaerfe: 100)
                    .opacity(0.2)
                    .scaleEffect(treiben ? 0.94 : 1)
                    .position(x: b + 96 - 260, y: (treiben ? 32 : 0) + h + 128 - 260)
                    .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true).delay(3), value: treiben)
                Fleck(farbe: Color(hex: 0xA21CAF), durchmesser: 280, unschaerfe: 70)
                    .opacity(0.12)
                    .position(x: b * 0.55 + 140 + (treiben ? -20 : 0), y: h * 0.55 + 140 + (treiben ? -24 : 0))
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(7), value: treiben)
            }
        }
        .ignoresSafeArea()
        .onAppear { treiben = true }
    }
}

/// radial-gradient(circle, Farbe, transparent 65%) mit filter: blur().
private struct Fleck: View {
    let farbe: Color
    let durchmesser: CGFloat
    let unschaerfe: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [farbe, farbe.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: durchmesser * 0.65 / 2))
            .frame(width: durchmesser, height: durchmesser)
            .blur(radius: unschaerfe / 2)
            .allowsHitTesting(false)
    }
}

/// Das feine Punkteraster ueber dem ganzen Hintergrund.
private struct Punkteraster: View {
    var body: some View {
        Canvas { ctx, groesse in
            let schritt: CGFloat = 26
            var y: CGFloat = schritt / 2
            while y < groesse.height {
                var x: CGFloat = schritt / 2
                while x < groesse.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                             with: .color(Color.white.opacity(0.04)))
                    x += schritt
                }
                y += schritt
            }
        }
        .allowsHitTesting(false)
    }
}

/// Eine Karte wie .section-card: Glas, feine Kante, Schatten.
struct Karte<Inhalt: View>: View {
    var polster: CGFloat = 18
    @ViewBuilder var inhalt: Inhalt

    var body: some View {
        inhalt
            .padding(polster)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Glas(radius: 16))
    }
}

/// Der Grund von Karten (rounded-2xl border, rgba(24,23,39,.92)): feine Kante,
/// weicher Schatten, ein Hauch Licht oben. Bewusst ohne iOS-Material.
struct Glas: View {
    var radius: CGFloat = 16
    var kante: Color = Farbe.linie
    var dicke: CGFloat = 1

    var body: some View {
        let form = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            form.fill(Farbe.karte)
            form.strokeBorder(kante, lineWidth: dicke)
            Lichtkante(radius: radius, staerke: 0.05)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

/// --sh-inset: ein Hauch Licht an der Oberkante (inset 0 1px 0 rgba(255,255,255,.06)).
struct Lichtkante: View {
    var radius: CGFloat = 16
    var staerke: Double = 0.08

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(colors: [Color.white.opacity(staerke), .clear],
                               startPoint: .top, endPoint: .center),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

/// Der grosse Knopf wie "Play now" / "Create Game": flaches Lila (#b15cff),
/// weisse fette Schrift, Ecken 16, lila Schein darunter
/// (0 8px 24px rgba(112,0,215,.3)) und ein heller Strich an der Oberkante.
/// farbe: Farbe.kante macht daraus die ruhige Glas-Variante.
struct Hauptknopf: ButtonStyle {
    var farbe: Color = Farbe.akzent
    var aus: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let lila: Bool = farbe == Farbe.akzent
        let glas: Bool = farbe == Farbe.kante
        let grund: Color = glas ? Color(.sRGB, red: 20 / 255, green: 18 / 255, blue: 38 / 255, opacity: 0.75) : farbe
        let schrift: Color = glas ? Color(hex: 0xD8D7EE) : (lila ? Color.white : Color(hex: 0x00220F))
        let schein: Color = glas ? Color.clear : (lila ? Farbe.akzentTief.opacity(0.3) : farbe.opacity(0.3))
        let gedrueckt: Bool = configuration.isPressed && !aus
        return configuration.label
            .font(.marke(15, .bold))
            .foregroundColor(schrift)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(form.fill(grund))
            .overlay(form.strokeBorder(glas ? Farbe.kante : Color.clear, lineWidth: 1))
            .overlay(Lichtkante(radius: 16, staerke: glas ? 0.05 : 0.18))
            .shadow(color: aus ? .clear : schein, radius: 12, x: 0, y: 8)
            // gesperrt: blasses Lila mit leiser Schrift, wie "Pick title, artist & year"
            .opacity(aus ? 0.5 : 1)
            .scaleEffect(gedrueckt ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Der ruhige Knopf daneben ("Join"): rgba(20,18,38,.75), Kante weiss 9 %,
/// Schrift #d8d7ee.
struct Nebenknopf: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let grund: Color = Color(.sRGB, red: 20 / 255, green: 18 / 255, blue: 38 / 255, opacity: 0.75)
        return configuration.label
            .font(.marke(14, .semibold))
            .foregroundColor(Color(hex: 0xD8D7EE))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(form.fill(configuration.isPressed ? Farbe.grund4 : grund))
            .overlay(form.strokeBorder(configuration.isPressed ? Color.white.opacity(0.18) : Farbe.kante, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// "× Leave" oben rechts: rote Pille, rgba(239,68,68,.1) mit Kante .3,
/// Schrift #f87171 11 pt fett, 6/12 Polster.
struct RausKnopf: View {
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                Text(L("Verlassen", "Leave")).font(.marke(11, .bold))
            }
            .foregroundColor(Farbe.schlecht)
            .padding(.horizontal, 12)
            .frame(height: 31)
            .background(Capsule().fill(Color(hex: 0xEF4444).opacity(0.1)))
            .overlay(Capsule().strokeBorder(Color(hex: 0xEF4444).opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(BubbleDruck())
    }
}

/// --grad-gold
extension Farbe {
    static let verlaufGold = LinearGradient(colors: [Color(hex: 0xFFBE48), Color(hex: 0xE89211)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
    static let aufGold = Color(hex: 0x2A1400)
    static let akzentDim = Color(hex: 0xB15CFF).opacity(0.14)   // --green-dim
}

extension Text {
    /// Die kleinen Etiketten im Spiel (TITLE, ARTIST …): 10 pt fett, 1 pt gesperrt, #8d8ba4.
    func etikett() -> some View {
        self.font(.marke(10, .bold))
            .tracking(1)
            .foregroundColor(Farbe.gedaempft)
    }
}

/// Der Schriftzug: FAKE #eef, STER #b15cff, beide mit weichem Schein
/// (text-shadow 0 0 70px), Buchstabenabstand -0,045 em, sehr fett.
struct Schriftzug: View {
    var groesse: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            Text("FAKE")
                .foregroundColor(Farbe.schrift)
                .shadow(color: Farbe.schrift.opacity(0.15), radius: 35)
            Text("STER")
                .foregroundColor(Farbe.akzent)
                .shadow(color: Farbe.akzent.opacity(0.4), radius: 35)
        }
        .font(.marke(groesse, .black))
        .tracking(-0.045 * groesse)
        .lineLimit(1)
    }
}
