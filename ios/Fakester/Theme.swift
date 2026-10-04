import SwiftUI
import UIKit
import CoreText

/// The look, measured on the live fakester.app (phone format 375×812,
/// `getComputedStyle`, October 2026) - not on the old style.css.
/// The trailing comments name the CSS variables or values in the browser.
enum Palette {
    static let base      = Color(hex: 0x07070E)                 // --background
    static let muted     = Color(hex: 0x15142A)                 // --muted (input fields)
    static let secondary     = Color(hex: 0x1A1831)                 // --secondary (focused field)
    static let surface    = Color(hex: 0x0F0E1C)                 // --card
    /// The raised cards in the browser: rgba(24, 23, 39, .92).
    static let card      = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.92)
    static let border      = Color.white.opacity(0.07)            // --border
    static let rim      = Color.white.opacity(0.09)
    /// --acc: follows the equipped item; this purple is the default.
    static let accent     = Color(hex: 0xB15CFF)
    static let accentDeep = Color(hex: 0x7000D7)                 // the glow under purple buttons
    static let accentLight = Color(hex: 0xC77DFF)
    static let foreground    = Color(hex: 0xEEEEFF)                 // --foreground
    static let subdued  = Color(hex: 0x8D8BA4)                 // labels, "/ 5"
    static let faint      = Color(hex: 0x7877A0)                 // --muted-foreground
    static let good        = Color(hex: 0x34D399)                 // --accent
    static let bad   = Color(hex: 0xF87171)                 // --destructive
    static let gold       = Color(hex: 0xFBBF24)
    /// Text on the purple button - white in the browser.
    static let onAccent  = Color.white

    /// The four tile colours on the home screen - in the browser each tile has
    /// its own hue, which is half of what makes the screen recognisable.
    static let tilePurple  = Color(hex: 0xA78BFA)
    static let tileGold  = Color(hex: 0xFBBF24)
    static let tileGreen = Color(hex: 0x34D399)
    static let tilePink  = Color(hex: 0xF472B6)
    static let discord     = Color(hex: 0x5865F2)

    /// The big button. A flat colour in the browser (#b15cff), no gradient -
    /// the name stays so every call site keeps working.
    static let gradient = LinearGradient(colors: [Color(hex: 0xB15CFF), Color(hex: 0xB15CFF)],
                                        startPoint: .top, endPoint: .bottom)
    /// "STER" in the wordmark - flat as well.
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

// MARK: - Fonts

/// The font the website really shows: the bundle asks for "Bricolage Grotesque"
/// and "DM Sans" via inline styles, but ships the files under the names
/// "Bricolage Grotesque Variable" / "DM Sans Variable". The names don't match,
/// so no browser loads the fonts (document.fonts lists only Font Awesome as
/// loaded) and `sans-serif` kicks in. Safari on the iPhone uses Helvetica for
/// that: weights up to 500 regular, from 600 bold.
/// A few places (reveal sheet, guest notice) use Tailwind's `system-ui` -
/// that is San Francisco, see `Font.system`.
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
    /// The website's font (Helvetica, see `Typeface`).
    static func brand(_ dimension: CGFloat, _ fontWeight: Font.Weight = .regular) -> Font {
        Font(Typeface.ui(dimension, fontWeight) as CTFont)
    }

    /// Formerly DM Mono. The website shows PIN and points in the same font as
    /// everything else - so Helvetica, bold by default.
    static func mono(_ dimension: CGFloat, isBold: Bool = true) -> Font {
        Font(Typeface.ui(dimension, isBold ? .bold : .regular) as CTFont)
    }
}

// MARK: - Building blocks

/// The background of the whole game as in the browser: #07070e, a dot grid
/// (26 px, 1 px white at 4 %) and three soft colour blobs that drift slowly
/// (.blob-a purple top left, .blob-b green bottom right, .blob-c magenta centre).
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

/// radial-gradient(circle, colour, transparent 65%) with filter: blur().
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

/// The fine dot grid across the whole background.
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

/// A card like .section-card: glass, fine border, shadow.
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

/// The card surface (rounded-2xl border, rgba(24,23,39,.92)): fine border,
/// soft shadow, a touch of light at the top. Deliberately no iOS material.
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

/// --sh-inset: a touch of light along the top edge (inset 0 1px 0 rgba(255,255,255,.06)).
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

/// The big button like "Play now" / "Create Game": flat purple (#b15cff),
/// white bold text, corner radius 16, a purple glow underneath
/// (0 8px 24px rgba(112,0,215,.3)) and a bright line along the top edge.
/// hue: Palette.rim turns it into the quiet glass variant.
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
            // disabled: faded purple with subdued text, like "Pick title, artist & year"
            .opacity(dimmed ? 0.5 : 1)
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// The quiet button next to it ("Join"): rgba(20,18,38,.75), white border at 9 %,
/// text #d8d7ee.
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

/// "× Leave" top right: red pill, rgba(239,68,68,.1) with a .3 border,
/// text #f87171 11 pt bold, 6/12 padding.
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
    /// The small labels in the game (TITLE, ARTIST …): 10 pt bold, 1 pt tracking, #8d8ba4.
    func eyebrow() -> some View {
        self.font(.brand(10, .bold))
            .tracking(1)
            .foregroundColor(Palette.subdued)
    }
}

/// The wordmark: FAKE #eef, STER #b15cff, both with a soft glow
/// (text-shadow 0 0 70px), letter spacing -0.045 em, very heavy.
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
