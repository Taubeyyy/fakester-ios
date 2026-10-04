import SwiftUI
import UIKit
import CoreText

/// Das Aussehen, abgeglichen mit fakester.app/fakester/style.css - damit die App
/// nicht aussieht wie ein fremdes Programm, das zufaellig dieselben Daten zeigt.
/// Die Namen in Klammern sind die CSS-Variablen im Browser.
enum Farbe {
    static let grund      = Color(hex: 0x07070C)                 // --bg
    static let grund3     = Color(hex: 0x15151F)                 // --bg3 (Eingabefelder)
    static let grund4     = Color(hex: 0x1E1E2B)                 // --bg4 (Feld mit Fokus)
    static let flaeche    = Color(hex: 0x1A1A26).opacity(0.72)   // --bg-elev (Karten, Glas)
    static let linie      = Color.white.opacity(0.06)            // --line
    static let kante      = Color.white.opacity(0.12)            // --line2
    static let akzent     = Color(hex: 0xB15CFF)                 // --green-hi (heisst im CSS noch "green")
    static let akzentTief = Color(hex: 0x8B3FD6)                 // --green
    static let akzentHell = Color(hex: 0xC77DFF)
    static let schrift    = Color(hex: 0xF4F4F7)                 // --t1
    static let gedaempft  = Color(hex: 0xA8A8B8)                 // --t2
    static let leise      = Color(hex: 0x65657A)                 // --t3
    static let gut        = Color(hex: 0x1ED760)                 // --ok
    static let schlecht   = Color(hex: 0xFF4D5E)                 // --red
    static let gold       = Color(hex: 0xF5A623)                 // --gold
    /// Schrift auf dem lila Knopf - im Browser genau so (#00220f).
    static let aufAkzent  = Color(hex: 0x00220F)

    /// --grad-primary: der grosse Knopf
    static let verlauf = LinearGradient(colors: [Color(hex: 0x7B2FBE), Color(hex: 0xB15CFF)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
    /// --grad-hero: "STER" im Schriftzug
    static let verlaufHeld = LinearGradient(colors: [Color(hex: 0x7B2FBE), Color(hex: 0xC77DFF), Color(hex: 0x7B2FBE)],
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

/// Die Schriften der Webseite: Bricolage Grotesque fuer alles, DM Mono fuer PINs
/// und Zahlen. Die Dateien holt das CI aus google/fonts (OFL) nach
/// Fakester/Schriften. Fehlen sie, faellt alles auf die Systemschrift zurueck.
enum Schrift {
    /// Je nach Datei heisst die Familie "Bricolage Grotesque" oder mit Zusatz -
    /// also danach suchen statt den Namen fest anzunehmen.
    static let familie: String = UIFont.familyNames.first(where: { $0.hasPrefix("Bricolage") }) ?? "Bricolage Grotesque"
    static let da: Bool = UIFont.familyNames.contains(familie)

    /// Bricolage ist eine variable Schrift (wght 200-800, opsz 12-96); die
    /// Achsen werden direkt gesetzt, das klappt auch unter iOS 16 sicher.
    static func ui(_ groesse: CGFloat, _ gewicht: Font.Weight) -> UIFont {
        guard da else {
            return UIFont.systemFont(ofSize: groesse, weight: uiGewicht(gewicht))
        }
        let wght: UInt32 = 0x77676874   // 'wght'
        let opsz: UInt32 = 0x6F70737A   // 'opsz'
        let achsen: [NSNumber: NSNumber] = [
            NSNumber(value: wght): NSNumber(value: Double(zahl(gewicht))),
            NSNumber(value: opsz): NSNumber(value: Double(min(max(groesse, 12), 96)))
        ]
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let attribute: [UIFontDescriptor.AttributeName: Any] = [.family: familie, variation: achsen]
        return UIFont(descriptor: UIFontDescriptor(fontAttributes: attribute), size: groesse)
    }

    static func mono(_ groesse: CGFloat, fett: Bool) -> UIFont {
        let name: String = fett ? "DMMono-Medium" : "DMMono-Regular"
        if let f = UIFont(name: name, size: groesse) { return f }
        return UIFont.monospacedSystemFont(ofSize: groesse, weight: fett ? .bold : .regular)
    }

    private static func zahl(_ g: Font.Weight) -> CGFloat {
        switch g {
        case .ultraLight, .thin: return 200
        case .light: return 300
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        case .heavy, .black: return 800
        default: return 400
        }
    }

    private static func uiGewicht(_ g: Font.Weight) -> UIFont.Weight {
        switch g {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}

extension Font {
    /// Die Spielschrift (Bricolage Grotesque).
    static func marke(_ groesse: CGFloat, _ gewicht: Font.Weight = .regular) -> Font {
        Font(Schrift.ui(groesse, gewicht) as CTFont)
    }

    /// DM Mono - fuer PIN und Punkte, wie im Browser.
    static func mono(_ groesse: CGFloat, fett: Bool = true) -> Font {
        Font(Schrift.mono(groesse, fett: fett) as CTFont)
    }
}

// MARK: - Bausteine

/// Der Hintergrund des ganzen Spiels: fast schwarz mit drei weichen Lichtflecken
/// (--grad-mesh), die langsam treiben.
struct Buehne: View {
    @State private var treiben = false

    var body: some View {
        GeometryReader { geo in
            let b: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            ZStack {
                Farbe.grund
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0x7B2FBE).opacity(0.22), .clear],
                                         center: .center, startRadius: 0, endRadius: b * 0.55))
                    .frame(width: b * 1.6, height: h * 0.7)
                    .position(x: b * 0.2, y: 0)
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0x9D6BFF).opacity(0.14), .clear],
                                         center: .center, startRadius: 0, endRadius: b * 0.45))
                    .frame(width: b * 1.2, height: h * 0.5)
                    .position(x: b * 0.8, y: h * 0.1)
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0x3ED0FF).opacity(0.08), .clear],
                                         center: .center, startRadius: 0, endRadius: b * 0.6))
                    .frame(width: b * 1.6, height: h * 0.5)
                    .position(x: b * 0.5, y: h)
            }
            .scaleEffect(treiben ? 1.05 : 1)
            .offset(y: treiben ? -h * 0.02 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) { treiben = true }
        }
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

/// Der Glas-Grund von Karten, Bubbles und dem Profil-Chip (--bg-elev).
/// Bewusst ohne iOS-Material: das legt einen grauen Schleier drueber, den es im
/// Browser nicht gibt - dort ist der Hintergrund so dunkel, dass blur nichts aufhellt.
struct Glas: View {
    var radius: CGFloat = 16
    var kante: Color = Farbe.kante
    var dicke: CGFloat = 1

    var body: some View {
        let form = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            form.fill(Farbe.flaeche)
            form.strokeBorder(kante, lineWidth: dicke)
            Lichtkante(radius: radius)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
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

/// Der grosse Knopf (.btn-primary .btn-large): Lila-Verlauf ohne Rand, dunkle
/// Schrift, lila Schein drumherum. Ein Spiel auf Zeit wird mit dem Daumen
/// bedient, also ist die Trefferflaeche bewusst gross.
/// farbe: Farbe.kante macht daraus die ruhige Glas-Variante (.btn-secondary).
struct Hauptknopf: ButtonStyle {
    var farbe: Color = Farbe.akzent
    var aus: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let lila: Bool = farbe == Farbe.akzent
        let glas: Bool = farbe == Farbe.kante
        let grund: AnyShapeStyle = lila ? AnyShapeStyle(Farbe.verlauf)
            : (glas ? AnyShapeStyle(Farbe.flaeche) : AnyShapeStyle(farbe))
        let schrift: Color = glas ? Farbe.schrift : (lila ? Farbe.aufAkzent : Color(hex: 0x00220F))
        let schein: Color = glas ? Color.black.opacity(0.35) : farbe.opacity(0.36)
        let gedrueckt: Bool = configuration.isPressed && !aus
        return configuration.label
            .font(.marke(15, .heavy))
            .tracking(0.3)
            .foregroundColor(schrift)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(form.fill(grund))
            .overlay(form.strokeBorder(glas ? Farbe.kante : Color.clear, lineWidth: 1))
            .overlay(Lichtkante(radius: 16, staerke: lila ? 0.25 : 0.08))
            // .btn-primary:hover - Schein waechst und bekommt einen Ring
            .shadow(color: aus ? .clear : schein, radius: gedrueckt ? 14 : 8, x: 0, y: gedrueckt ? 5 : 2)
            .overlay(form.stroke(farbe.opacity(gedrueckt && lila ? 0.22 : 0), lineWidth: 3).padding(-1.5))
            // .btn:disabled - blass und entsaettigt, aber dieselbe Form
            .saturation(aus ? 0.6 : 1)
            .opacity(aus ? 0.45 : 1)
            .scaleEffect(gedrueckt ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// .btn-secondary .btn-large: Glas mit Kante.
struct Nebenknopf: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return configuration.label
            .font(.marke(15, .heavy))
            .tracking(0.3)
            .foregroundColor(Farbe.schrift)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(form.fill(configuration.isPressed ? Farbe.grund4 : Farbe.flaeche))
            .overlay(form.strokeBorder(configuration.isPressed ? Color.white.opacity(0.22) : Farbe.kante, lineWidth: 1))
            .overlay(Lichtkante(radius: 16))
            .shadow(color: Color.black.opacity(0.35), radius: configuration.isPressed ? 12 : 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Kleiner Pillen-Knopf wie .btn-quit (rot) - fuer "Verlassen" oben rechts.
struct RausKnopf: View {
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                Text(L("Verlassen", "Leave")).font(.marke(12, .bold))
            }
            .foregroundColor(Farbe.schlecht)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Capsule().fill(Farbe.schlecht.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Farbe.schlecht.opacity(0.22), lineWidth: 1))
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
    /// Die Ueberschriften im Spiel (.section-title): klein, fett, gesperrt, grau.
    func etikett() -> some View {
        self.font(.marke(12, .heavy))
            .tracking(1.2)
            .foregroundColor(Farbe.leise)
    }
}

/// Der Schriftzug: FAKE weiss, STER mit schimmerndem Lila-Verlauf.
struct Schriftzug: View {
    var groesse: CGFloat = 30
    @State private var schimmer = false

    var body: some View {
        HStack(spacing: 0) {
            Text("FAKE").foregroundColor(Farbe.schrift)
            Text("STER")
                .foregroundColor(.clear)
                .overlay(
                    GeometryReader { geo in
                        Farbe.verlaufHeld
                            .frame(width: geo.size.width * 2)
                            .offset(x: schimmer ? -geo.size.width : 0)
                    }
                    .mask { Text("STER") }
                )
        }
        .font(.marke(groesse, .black))
        .tracking(-0.04 * groesse)
        .lineLimit(1)
        .shadow(color: Color(hex: 0x7B2FBE).opacity(0.3), radius: 16, x: 0, y: 8)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { schimmer = true }
        }
    }
}
