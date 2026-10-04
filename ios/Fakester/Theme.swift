import SwiftUI
import UIKit
import CoreText

/// Das Aussehen, gemessen an der laufenden fakester.app (Handyformat 375×812,
/// `getComputedStyle`, Oktober 2026) - nicht am alten style.css.
/// Die Namen in Klammern sind die CSS-Variablen bzw. Werte im Browser.
enum Palette {
    static let base      = Color(hex: 0x07070E)                 // --background
    static let muted     = Color(hex: 0x15142A)                 // --muted (Eingabefelder)
    static let secondary     = Color(hex: 0x1A1831)                 // --secondary (Feld mit Fokus)
    static let surface    = Color(hex: 0x0F0E1C)                 // --card
    /// Die erhabenen Karten im Browser: rgba(24, 23, 39, .92).
    static let card      = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.92)
    static let border      = Color.white.opacity(0.07)            // --border
    static let rim      = Color.white.opacity(0.09)
    /// --acc: haengt am ausgeruesteten Gegenstand, Vorgabe ist dieses Lila.
    static let accent     = Color(hex: 0xB15CFF)
    static let accentDeep = Color(hex: 0x7000D7)                 // der Schein unter lila Knoepfen
    static let accentLight = Color(hex: 0xC77DFF)
    static let foreground    = Color(hex: 0xEEEEFF)                 // --foreground
    static let subdued  = Color(hex: 0x8D8BA4)                 // Etiketten, "/ 5"
    static let faint      = Color(hex: 0x7877A0)                 // --muted-foreground
    static let good        = Color(hex: 0x34D399)                 // --accent
    static let bad   = Color(hex: 0xF87171)                 // --destructive
    static let gold       = Color(hex: 0xFBBF24)
    /// Schrift auf dem lila Knopf - im Browser weiss.
    static let onAccent  = Color.white

    /// Die vier Farben der Kacheln auf dem Startbildschirm - im Browser traegt
    /// jede ihren eigenen Ton, das ist dort der halbe Wiedererkennungswert.
    static let tilePurple  = Color(hex: 0xA78BFA)
    static let tileGold  = Color(hex: 0xFBBF24)
    static let tileGreen = Color(hex: 0x34D399)
    static let tilePink  = Color(hex: 0xF472B6)
    static let discord     = Color(hex: 0x5865F2)

    /// Der grosse Knopf. Im Browser eine flache Farbe (#b15cff), kein Verlauf -
    /// der Name bleibt, damit alle Stellen weiter passen.
    static let gradient = LinearGradient(colors: [Color(hex: 0xB15CFF), Color(hex: 0xB15CFF)],
                                        startPoint: .top, endPoint: .bottom)
    /// "STER" im Schriftzug - ebenfalls flach.
    static let gradientHero = LinearGradient(colors: [Color(hex: 0xB15CFF), Color(hex: 0xB15CFF)],
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
enum Typeface {
    static func ui(_ dimension: CGFloat, _ fontWeight: Font.Weight) -> UIFont {
        let name: String
        switch fontWeight {
        case .ultraLight, .thin, .light: name = "Helvetica-Light"
        case .semibold, .bold, .heavy, .black: name = "Helvetica-Bold"
        default: name = "Helvetica"
        }
        if let f = UIFont(name: name, size: dimension) { return f }
        return UIFont.systemFont(ofSize: dimension, weight: name == "Helvetica-Bold" ? .bold : .regular)
    }
}

extension Font {
    /// Die Schrift der Webseite (Helvetica, siehe `Schrift`).
    static func brand(_ dimension: CGFloat, _ fontWeight: Font.Weight = .regular) -> Font {
        Font(Typeface.ui(dimension, fontWeight) as CTFont)
    }

    /// Frueher DM Mono. Die Webseite zeigt PIN und Punkte in derselben Schrift
    /// wie alles andere - also Helvetica, standardmaessig fett.
    static func mono(_ dimension: CGFloat, isBold: Bool = true) -> Font {
        Font(Typeface.ui(dimension, isBold ? .bold : .regular) as CTFont)
    }
}

// MARK: - Bausteine

/// Der Hintergrund des ganzen Spiels wie im Browser: #07070e, ein Punkteraster
/// (26 px, 1 px weiss 4 %) und drei weiche Farbflecken, die langsam treiben
/// (.blob-a lila oben links, .blob-b gruen unten rechts, .blob-c magenta mittig).
struct Backdrop: View {
    @State private var drifting = false

    var body: some View {
        GeometryReader { geo in
            let b: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            ZStack(alignment: .topLeading) {
                Palette.base
                DotGrid()
                Blob(hue: Color(hex: 0x7000D7), diameter: 600, blurRadius: 90)
                    .opacity(0.28)
                    .scaleEffect(drifting ? 1.06 : 1)
                    .position(x: -96 + 300, y: (drifting ? -44 : 0) - 192 + 300)
                    .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: drifting)
                Blob(hue: Color(hex: 0x065F46), diameter: 520, blurRadius: 100)
                    .opacity(0.2)
                    .scaleEffect(drifting ? 0.94 : 1)
                    .position(x: b + 96 - 260, y: (drifting ? 32 : 0) + h + 128 - 260)
                    .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true).delay(3), value: drifting)
                Blob(hue: Color(hex: 0xA21CAF), diameter: 280, blurRadius: 70)
                    .opacity(0.12)
                    .position(x: b * 0.55 + 140 + (drifting ? -20 : 0), y: h * 0.55 + 140 + (drifting ? -24 : 0))
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(7), value: drifting)
            }
        }
        .ignoresSafeArea()
        .onAppear { drifting = true }
    }
}

/// radial-gradient(circle, Farbe, transparent 65%) mit filter: blur().
private struct Blob: View {
    let hue: Color
    let diameter: CGFloat
    let blurRadius: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [hue, hue.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: diameter * 0.65 / 2))
            .frame(width: diameter, height: diameter)
            .blur(radius: blurRadius / 2)
            .allowsHitTesting(false)
    }
}

/// Das feine Punkteraster ueber dem ganzen Hintergrund.
private struct DotGrid: View {
    var body: some View {
        Canvas { ctx, dimension in
            let step: CGFloat = 26
            var y: CGFloat = step / 2
            while y < dimension.height {
                var x: CGFloat = step / 2
                while x < dimension.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                             with: .color(Color.white.opacity(0.04)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

/// Eine Karte wie .section-card: Glas, feine Kante, Schatten.
struct Card<Content: View>: View {
    var inset: CGFloat = 18
    @ViewBuilder var contents: Content

    var body: some View {
        contents
            .padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassPanel(radius: 16))
    }
}

/// Der Grund von Karten (rounded-2xl border, rgba(24,23,39,.92)): feine Kante,
/// weicher Schatten, ein Hauch Licht oben. Bewusst ohne iOS-Material.
struct GlassPanel: View {
    var radius: CGFloat = 16
    var rim: Color = Palette.border
    var borderWidth: CGFloat = 1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(Palette.card)
            shape.strokeBorder(rim, lineWidth: borderWidth)
            EdgeHighlight(radius: radius, intensity: 0.05)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

/// --sh-inset: ein Hauch Licht an der Oberkante (inset 0 1px 0 rgba(255,255,255,.06)).
struct EdgeHighlight: View {
    var radius: CGFloat = 16
    var intensity: Double = 0.08

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(colors: [Color.white.opacity(intensity), .clear],
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
struct PrimaryButtonStyle: ButtonStyle {
    var hue: Color = Palette.accent
    var dimmed: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let isPurple: Bool = hue == Palette.accent
        let isGlass: Bool = hue == Palette.rim
        let base: Color = isGlass ? Color(.sRGB, red: 20 / 255, green: 18 / 255, blue: 38 / 255, opacity: 0.75) : hue
        let foreground: Color = isGlass ? Color(hex: 0xD8D7EE) : (isPurple ? Color.white : Color(hex: 0x00220F))
        let glow: Color = isGlass ? Color.clear : (isPurple ? Palette.accentDeep.opacity(0.3) : hue.opacity(0.3))
        let pressed: Bool = configuration.isPressed && !dimmed
        return configuration.label
            .font(.brand(15, .bold))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(shape.fill(base))
            .overlay(shape.strokeBorder(isGlass ? Palette.rim : Color.clear, lineWidth: 1))
            .overlay(EdgeHighlight(radius: 16, intensity: isGlass ? 0.05 : 0.18))
            .shadow(color: dimmed ? .clear : glow, radius: 12, x: 0, y: 8)
            // gesperrt: blasses Lila mit leiser Schrift, wie "Pick title, artist & year"
            .opacity(dimmed ? 0.5 : 1)
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Der ruhige Knopf daneben ("Join"): rgba(20,18,38,.75), Kante weiss 9 %,
/// Schrift #d8d7ee.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let base: Color = Color(.sRGB, red: 20 / 255, green: 18 / 255, blue: 38 / 255, opacity: 0.75)
        return configuration.label
            .font(.brand(14, .semibold))
            .foregroundColor(Color(hex: 0xD8D7EE))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(shape.fill(configuration.isPressed ? Palette.secondary : base))
            .overlay(shape.strokeBorder(configuration.isPressed ? Color.white.opacity(0.18) : Palette.rim, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// "× Leave" oben rechts: rote Pille, rgba(239,68,68,.1) mit Kante .3,
/// Schrift #f87171 11 pt fett, 6/12 Polster.
struct LeaveButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                Text("Leave").font(.brand(11, .bold))
            }
            .foregroundColor(Palette.bad)
            .padding(.horizontal, 12)
            .frame(height: 31)
            .background(Capsule().fill(Color(hex: 0xEF4444).opacity(0.1)))
            .overlay(Capsule().strokeBorder(Color(hex: 0xEF4444).opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(BubblePressStyle())
    }
}

/// --grad-gold
extension Palette {
    static let gradientGold = LinearGradient(colors: [Color(hex: 0xFFBE48), Color(hex: 0xE89211)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
    static let onGold = Color(hex: 0x2A1400)
    static let accentDim = Color(hex: 0xB15CFF).opacity(0.14)   // --green-dim
}

extension Text {
    /// Die kleinen Etiketten im Spiel (TITLE, ARTIST …): 10 pt fett, 1 pt gesperrt, #8d8ba4.
    func eyebrow() -> some View {
        self.font(.brand(10, .bold))
            .tracking(1)
            .foregroundColor(Palette.subdued)
    }
}

/// Der Schriftzug: FAKE #eef, STER #b15cff, beide mit weichem Schein
/// (text-shadow 0 0 70px), Buchstabenabstand -0,045 em, sehr fett.
struct Wordmark: View {
    var dimension: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            Text("FAKE")
                .foregroundColor(Palette.foreground)
                .shadow(color: Palette.foreground.opacity(0.15), radius: 35)
            Text("STER")
                .foregroundColor(Palette.accent)
                .shadow(color: Palette.accent.opacity(0.4), radius: 35)
        }
        .font(.brand(dimension, .black))
        .tracking(-0.045 * dimension)
        .lineLimit(1)
    }
}
