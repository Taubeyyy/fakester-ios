import SwiftUI

// The pieces Shop and Style share, drawn the way the browser draws them
// (`Mf`, `O1`, `Vi`, `Z1`, `Q1`, `J1` in the web bundle). Measurements from
// the website at 375 × 812 (k-shop-*, k-style-*).

// MARK: - Colours

enum CosmeticTone {
    /// --acc-pale for the default accent, measured rgb(204,149,255).
    static var accentPale: Color { Palette.accentPale }
    /// The spots colour (`Iu` = #a78bfa) - always lilac, whatever the accent.
    static let spots = Color(hex: 0xA78BFA)
    /// The ink on a lilac "Buy" button (`k3`).
    static let buyInk = Color(hex: 0x0D0D14)
    static let cardFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.95)
    static let control = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.8)
    static let nameDim = Color(hex: 0xB0AED2)

    /// A CSS colour from the catalog; nil for gradients and junk.
    static func plain(_ hex: String?) -> Color? {
        guard let h = hex, !h.contains("gradient"), let v = CosmeticColor.rgb(h) else { return nil }
        return Color(hex: v)
    }

    /// The stand-in colour of a value (`$u`): itself or a gradient's middle stop.
    static func representative(_ hex: String?) -> Color? {
        guard let r = CosmeticColor.representative(hex), let v = CosmeticColor.rgb(r) else { return nil }
        return Color(hex: v)
    }

    /// Colours or a left-to-right gradient for a catalog value.
    static func paint(_ hex: String?) -> AnyShapeStyle? {
        guard let h = hex else { return nil }
        if h.contains("gradient") {
            let stops: [Color] = CosmeticColor.hexStops(h).compactMap { s in CosmeticColor.rgb(s).map { Color(hex: $0) } }
            guard stops.count > 1 else { return stops.first.map { AnyShapeStyle($0) } }
            let vertical: Bool = h.contains("180deg")
            return AnyShapeStyle(LinearGradient(colors: stops,
                                                startPoint: vertical ? .top : .leading,
                                                endPoint: vertical ? .bottom : .trailing))
        }
        return plain(h).map { AnyShapeStyle($0) }
    }
}

extension ItemGroup {
    /// `hs[group].text`
    var tint: Color {
        switch self {
        case .standard, .legacy: return Color(hex: 0x9CA3AF)
        case .level: return Color(hex: 0x818CF8)
        case .shop: return Palette.accent
        case .pro: return Color(hex: 0xFBBF24)
        case .beta: return Color(hex: 0x34D399)
        case .admin: return Color(hex: 0xF87171)
        case .earned: return Color(hex: 0xF472B6)
        }
    }

    /// `hs[group].border`
    var edge: Color {
        switch self {
        case .standard: return Color.white.opacity(0.07)
        case .level: return Color(hex: 0x818CF8).opacity(0.35)
        case .shop: return Palette.accent.opacity(0.35)
        case .pro: return Color(hex: 0xFBBF24).opacity(0.4)
        case .beta: return Color(hex: 0x34D399).opacity(0.4)
        case .admin: return Color(hex: 0xEF4444).opacity(0.4)
        case .legacy: return Color(hex: 0x9CA3AF).opacity(0.28)
        case .earned: return Color(hex: 0xF472B6).opacity(0.45)
        }
    }

    /// `hs[group].glow` as colour and blur radius (CSS blur / 2).
    var glow: (color: Color, radius: CGFloat) {
        switch self {
        case .standard, .legacy: return (Color.clear, 0)
        case .level: return (Color(hex: 0x818CF8).opacity(0.16), 7)
        case .shop: return (Palette.accent.opacity(0.18), 7)
        case .pro: return (Color(hex: 0xF59E0B).opacity(0.2), 8)
        case .beta: return (Color(hex: 0x34D399).opacity(0.18), 7)
        case .admin: return (Color(hex: 0xEF4444).opacity(0.16), 7)
        case .earned: return (Color(hex: 0xF472B6).opacity(0.22), 9)
        }
    }
}

/// "1,100" - the browser's `toLocaleString()` in English.
func groupedNumber(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

// MARK: - Icons

/// One filled shape of an icon, in its view box.
struct GlyphLayer {
    let path: String
    var evenOdd: Bool = false
    var opacity: Double = 1

    init(_ path: String, evenOdd: Bool = false, opacity: Double = 1) {
        self.path = path
        self.evenOdd = evenOdd
        self.opacity = opacity
    }
}

/// An SVG path scaled from its view box into the given rect, centred.
struct GlyphShape: Shape {
    let data: String
    let box: CGSize

    func path(in rect: CGRect) -> Path {
        let scale: CGFloat = min(rect.width / box.width, rect.height / box.height)
        let originX: CGFloat = rect.midX - box.width * scale / 2
        let originY: CGFloat = rect.midY - box.height * scale / 2
        func place(_ p: CGPoint) -> CGPoint {
            CGPoint(x: originX + p.x * scale, y: originY + p.y * scale)
        }
        var path = Path()
        for step in LucidePathReader.steps(data) {
            switch step {
            case .move(let p): path.move(to: place(p))
            case .line(let p): path.addLine(to: place(p))
            case .curve(let c1, let c2, let end): path.addCurve(to: place(end), control1: place(c1), control2: place(c2))
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}

/// The item icons: the site's own marks ("mark:vinyl", 24 grid) and the Font
/// Awesome Free 6.5.0 solid icons the catalog and the awards use (CC BY 4.0,
/// fontawesome.com - credited under Settings → About).
enum CosmeticGlyphs {
    static let marks: [String: [GlyphLayer]] = [
        "flame": [
            GlyphLayer("M12 1.4c4.6 4.8 7 7.9 7 11.5a7 7 0 11-14 0c0-3.6 2.4-6.7 7-11.5zm0 8.1c2.2 2.5 3.4 4.1 3.4 5.9a3.4 3.4 0 11-6.8 0c0-1.8 1.2-3.4 3.4-5.9z", evenOdd: true),
        ],
        "broadcast": [
            GlyphLayer("M9.7 4.6a2.3 2.3 0 1 0 4.6 0a2.3 2.3 0 1 0 -4.6 0z"),
            GlyphLayer("M12 7.6l4.6 14.8h-2.9L12 16.2l-1.7 6.2H7.4z"),
            GlyphLayer("M7.1 1.2a1.25 1.25 0 011.8 1.75 6 6 0 000 8.5 1.25 1.25 0 01-1.8 1.75 8.5 8.5 0 010-12z", evenOdd: true),
            GlyphLayer("M16.9 1.2a1.25 1.25 0 00-1.8 1.75 6 6 0 010 8.5 1.25 1.25 0 001.8 1.75 8.5 8.5 0 000-12z", evenOdd: true),
        ],
        "bolt": [
            GlyphLayer("M13.9 1.4L4.6 13.4h5.6l-1.5 9.2 9.7-12.4h-5.9z"),
        ],
        "crosshair": [
            GlyphLayer("M12 3.4a8.6 8.6 0 100 17.2 8.6 8.6 0 000-17.2zm0 2.4a6.2 6.2 0 110 12.4 6.2 6.2 0 010-12.4z", evenOdd: true),
            GlyphLayer("M9.4 12a2.6 2.6 0 1 0 5.2 0a2.6 2.6 0 1 0 -5.2 0z"),
            GlyphLayer("M12 0.4h0a1 1 0 0 1 1 1v2.2a1 1 0 0 1 -1 1h-0a1 1 0 0 1 -1 -1v-2.2a1 1 0 0 1 1 -1z"),
            GlyphLayer("M12 19.4h0a1 1 0 0 1 1 1v2.2a1 1 0 0 1 -1 1h-0a1 1 0 0 1 -1 -1v-2.2a1 1 0 0 1 1 -1z"),
            GlyphLayer("M1.4 11h2.2a1 1 0 0 1 1 1v0a1 1 0 0 1 -1 1h-2.2a1 1 0 0 1 -1 -1v-0a1 1 0 0 1 1 -1z"),
            GlyphLayer("M20.4 11h2.2a1 1 0 0 1 1 1v0a1 1 0 0 1 -1 1h-2.2a1 1 0 0 1 -1 -1v-0a1 1 0 0 1 1 -1z"),
        ],
        "star": [
            GlyphLayer("M12 2l2.53 6.52L21.51 8.91l-5.42 4.42 1.79 6.76L12 16.3l-5.88 3.79 1.79-6.76L2.49 8.91l6.98-.39z"),
        ],
        "headphones": [
            GlyphLayer("M12 2.2A9.2 9.2 0 002.8 11.4v3.4h2.6v-3.4a6.6 6.6 0 1113.2 0v3.4h2.6v-3.4A9.2 9.2 0 0012 2.2z", evenOdd: true),
            GlyphLayer("M3.8 12.9h0a2.4 2.4 0 0 1 2.4 2.4v3.9a2.4 2.4 0 0 1 -2.4 2.4h-0a2.4 2.4 0 0 1 -2.4 -2.4v-3.9a2.4 2.4 0 0 1 2.4 -2.4z"),
            GlyphLayer("M20.2 12.9h0a2.4 2.4 0 0 1 2.4 2.4v3.9a2.4 2.4 0 0 1 -2.4 2.4h-0a2.4 2.4 0 0 1 -2.4 -2.4v-3.9a2.4 2.4 0 0 1 2.4 -2.4z"),
        ],
        "mic": [
            GlyphLayer("M12 1.4h0a3 3 0 0 1 3 3v5.6a3 3 0 0 1 -3 3h-0a3 3 0 0 1 -3 -3v-5.6a3 3 0 0 1 3 -3z"),
            GlyphLayer("M6.2 9.6a1.2 1.2 0 00-2.4 0 8.2 8.2 0 007 8.1v1.9H8.2a1.2 1.2 0 000 2.4h7.6a1.2 1.2 0 000-2.4h-2.6v-1.9a8.2 8.2 0 007-8.1 1.2 1.2 0 00-2.4 0 5.8 5.8 0 01-11.6 0z", evenOdd: true),
        ],
        "vinyl": [
            GlyphLayer("M12 1a11 11 0 100 22 11 11 0 000-22zm0 2.6a8.4 8.4 0 110 16.8 8.4 8.4 0 010-16.8z", evenOdd: true),
            GlyphLayer("M12 6.4a5.6 5.6 0 100 11.2 5.6 5.6 0 000-11.2zm0 4.1a1.5 1.5 0 110 3 1.5 1.5 0 010-3z", evenOdd: true),
        ],
        "cassette": [
            GlyphLayer("M2.6 4.8h18.8a1.4 1.4 0 011.4 1.4v11.6a1.4 1.4 0 01-1.4 1.4H2.6a1.4 1.4 0 01-1.4-1.4V6.2a1.4 1.4 0 011.4-1.4zm2.9 3a1 1 0 00-1 1v5.4a1 1 0 001 1h13a1 1 0 001-1V8.8a1 1 0 00-1-1h-13z", evenOdd: true),
            GlyphLayer("M6.7 11.5a2 2 0 1 0 4 0a2 2 0 1 0 -4 0z"),
            GlyphLayer("M13.3 11.5a2 2 0 1 0 4 0a2 2 0 1 0 -4 0z"),
            GlyphLayer("M8.2 19.4h7.6a0.8 0.8 0 0 1 0.8 0.8v0a0.8 0.8 0 0 1 -0.8 0.8h-7.6a0.8 0.8 0 0 1 -0.8 -0.8v-0a0.8 0.8 0 0 1 0.8 -0.8z"),
        ],
        "fader": [
            GlyphLayer("M5 2.6h0a0.9 0.9 0 0 1 0.9 0.9v17a0.9 0.9 0 0 1 -0.9 0.9h-0a0.9 0.9 0 0 1 -0.9 -0.9v-17a0.9 0.9 0 0 1 0.9 -0.9z", opacity: 0.45),
            GlyphLayer("M12 2.6h0a0.9 0.9 0 0 1 0.9 0.9v17a0.9 0.9 0 0 1 -0.9 0.9h-0a0.9 0.9 0 0 1 -0.9 -0.9v-17a0.9 0.9 0 0 1 0.9 -0.9z", opacity: 0.45),
            GlyphLayer("M19 2.6h0a0.9 0.9 0 0 1 0.9 0.9v17a0.9 0.9 0 0 1 -0.9 0.9h-0a0.9 0.9 0 0 1 -0.9 -0.9v-17a0.9 0.9 0 0 1 0.9 -0.9z", opacity: 0.45),
            GlyphLayer("M3.3 14.4h3.4a1.7 1.7 0 0 1 1.7 1.7v0a1.7 1.7 0 0 1 -1.7 1.7h-3.4a1.7 1.7 0 0 1 -1.7 -1.7v-0a1.7 1.7 0 0 1 1.7 -1.7z"),
            GlyphLayer("M10.3 6.2h3.4a1.7 1.7 0 0 1 1.7 1.7v0a1.7 1.7 0 0 1 -1.7 1.7h-3.4a1.7 1.7 0 0 1 -1.7 -1.7v-0a1.7 1.7 0 0 1 1.7 -1.7z"),
            GlyphLayer("M17.3 11.2h3.4a1.7 1.7 0 0 1 1.7 1.7v0a1.7 1.7 0 0 1 -1.7 1.7h-3.4a1.7 1.7 0 0 1 -1.7 -1.7v-0a1.7 1.7 0 0 1 1.7 -1.7z"),
        ],
        "wave": [
            GlyphLayer("M2.7 10h0a1.3 1.3 0 0 1 1.3 1.3v1.4a1.3 1.3 0 0 1 -1.3 1.3h-0a1.3 1.3 0 0 1 -1.3 -1.3v-1.4a1.3 1.3 0 0 1 1.3 -1.3z"),
            GlyphLayer("M7 7h0a1.3 1.3 0 0 1 1.3 1.3v7.4a1.3 1.3 0 0 1 -1.3 1.3h-0a1.3 1.3 0 0 1 -1.3 -1.3v-7.4a1.3 1.3 0 0 1 1.3 -1.3z"),
            GlyphLayer("M11.3 2.6h0a1.3 1.3 0 0 1 1.3 1.3v16.2a1.3 1.3 0 0 1 -1.3 1.3h-0a1.3 1.3 0 0 1 -1.3 -1.3v-16.2a1.3 1.3 0 0 1 1.3 -1.3z"),
            GlyphLayer("M15.6 6h0a1.3 1.3 0 0 1 1.3 1.3v9.4a1.3 1.3 0 0 1 -1.3 1.3h-0a1.3 1.3 0 0 1 -1.3 -1.3v-9.4a1.3 1.3 0 0 1 1.3 -1.3z"),
            GlyphLayer("M19.9 9h0a1.3 1.3 0 0 1 1.3 1.3v3.4a1.3 1.3 0 0 1 -1.3 1.3h-0a1.3 1.3 0 0 1 -1.3 -1.3v-3.4a1.3 1.3 0 0 1 1.3 -1.3z"),
        ],
        "speaker": [
            GlyphLayer("M5 1.4h14a1.6 1.6 0 011.6 1.6v18a1.6 1.6 0 01-1.6 1.6H5a1.6 1.6 0 01-1.6-1.6V3A1.6 1.6 0 015 1.4zm7 2.8a2.1 2.1 0 100 4.2 2.1 2.1 0 000-4.2zm0 6.1a4.3 4.3 0 100 8.6 4.3 4.3 0 000-8.6zm0 2.5a1.8 1.8 0 110 3.6 1.8 1.8 0 010-3.6z", evenOdd: true),
        ],
    ]
    static let fontAwesome: [String: (width: CGFloat, path: String)] = [
        "fa-gamepad": (640, "M192 64C86 64 0 150 0 256S86 448 192 448H448c106 0 192-86 192-192s-86-192-192-192H192zM496 168a40 40 0 1 1 0 80 40 40 0 1 1 0-80zM392 304a40 40 0 1 1 80 0 40 40 0 1 1 -80 0zM168 200c0-13.3 10.7-24 24-24s24 10.7 24 24v32h32c13.3 0 24 10.7 24 24s-10.7 24-24 24H216v32c0 13.3-10.7 24-24 24s-24-10.7-24-24V280H136c-13.3 0-24-10.7-24-24s10.7-24 24-24h32V200z"),
        "fa-crown": (576, "M309 106c11.4-7 19-19.7 19-34c0-22.1-17.9-40-40-40s-40 17.9-40 40c0 14.4 7.6 27 19 34L209.7 220.6c-9.1 18.2-32.7 23.4-48.6 10.7L72 160c5-6.7 8-15 8-24c0-22.1-17.9-40-40-40S0 113.9 0 136s17.9 40 40 40c.2 0 .5 0 .7 0L86.4 427.4c5.5 30.4 32 52.6 63 52.6H426.6c30.9 0 57.4-22.1 63-52.6L535.3 176c.2 0 .5 0 .7 0c22.1 0 40-17.9 40-40s-17.9-40-40-40s-40 17.9-40 40c0 9 3 17.3 8 24l-89.1 71.3c-15.9 12.7-39.5 7.5-48.6-10.7L309 106z"),
        "fa-music": (512, "M499.1 6.3c8.1 6 12.9 15.6 12.9 25.7v72V368c0 44.2-43 80-96 80s-96-35.8-96-80s43-80 96-80c11.2 0 22 1.6 32 4.6V147L192 223.8V432c0 44.2-43 80-96 80s-96-35.8-96-80s43-80 96-80c11.2 0 22 1.6 32 4.6V200 128c0-14.1 9.3-26.6 22.8-30.7l320-96c9.7-2.9 20.2-1.1 28.3 5z"),
        "fa-star": (576, "M316.9 18C311.6 7 300.4 0 288.1 0s-23.4 7-28.8 18L195 150.3 51.4 171.5c-12 1.8-22 10.2-25.7 21.7s-.7 24.2 7.9 32.7L137.8 329 113.2 474.7c-2 12 3 24.2 12.9 31.3s23 8 33.8 2.3l128.3-68.5 128.3 68.5c10.8 5.7 23.9 4.9 33.8-2.3s14.9-19.3 12.9-31.3L438.5 329 542.7 225.9c8.6-8.5 11.7-21.2 7.9-32.7s-13.7-19.9-25.7-21.7L381.2 150.3 316.9 18z"),
        "fa-calendar-check": (448, "M128 0c17.7 0 32 14.3 32 32V64H288V32c0-17.7 14.3-32 32-32s32 14.3 32 32V64h48c26.5 0 48 21.5 48 48v48H0V112C0 85.5 21.5 64 48 64H96V32c0-17.7 14.3-32 32-32zM0 192H448V464c0 26.5-21.5 48-48 48H48c-26.5 0-48-21.5-48-48V192zM329 305c9.4-9.4 9.4-24.6 0-33.9s-24.6-9.4-33.9 0l-95 95-47-47c-9.4-9.4-24.6-9.4-33.9 0s-9.4 24.6 0 33.9l64 64c9.4 9.4 24.6 9.4 33.9 0L329 305z"),
        "fa-gift": (512, "M190.5 68.8L225.3 128H224 152c-22.1 0-40-17.9-40-40s17.9-40 40-40h2.2c14.9 0 28.8 7.9 36.3 20.8zM64 88c0 14.4 3.5 28 9.6 40H32c-17.7 0-32 14.3-32 32v64c0 17.7 14.3 32 32 32H480c17.7 0 32-14.3 32-32V160c0-17.7-14.3-32-32-32H438.4c6.1-12 9.6-25.6 9.6-40c0-48.6-39.4-88-88-88h-2.2c-31.9 0-61.5 16.9-77.7 44.4L256 85.5l-24.1-41C215.7 16.9 186.1 0 154.2 0H152C103.4 0 64 39.4 64 88zm336 0c0 22.1-17.9 40-40 40H288h-1.3l34.8-59.2C329.1 55.9 342.9 48 357.8 48H360c22.1 0 40 17.9 40 40zM32 288V464c0 26.5 21.5 48 48 48H224V288H32zM288 512H432c26.5 0 48-21.5 48-48V288H288V512z"),
        "fa-chart-line": (512, "M64 64c0-17.7-14.3-32-32-32S0 46.3 0 64V400c0 44.2 35.8 80 80 80H480c17.7 0 32-14.3 32-32s-14.3-32-32-32H80c-8.8 0-16-7.2-16-16V64zm406.6 86.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L320 210.7l-57.4-57.4c-12.5-12.5-32.8-12.5-45.3 0l-112 112c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L240 221.3l57.4 57.4c12.5 12.5 32.8 12.5 45.3 0l128-128z"),
        "fa-bolt": (448, "M349.4 44.6c5.9-13.7 1.5-29.7-10.6-38.5s-28.6-8-39.9 1.8l-256 224c-10 8.8-13.6 22.9-8.9 35.3S50.7 288 64 288H175.5L98.6 467.4c-5.9 13.7-1.5 29.7 10.6 38.5s28.6 8 39.9-1.8l256-224c10-8.8 13.6-22.9 8.9-35.3s-16.6-20.7-30-20.7H272.5L349.4 44.6z"),
        "fa-sack-dollar": (512, "M320 96H192L144.6 24.9C137.5 14.2 145.1 0 157.9 0H354.1c12.8 0 20.4 14.2 13.3 24.9L320 96zM192 128H320c3.8 2.5 8.1 5.3 13 8.4C389.7 172.7 512 250.9 512 416c0 53-43 96-96 96H96c-53 0-96-43-96-96C0 250.9 122.3 172.7 179 136.4l0 0 0 0c4.8-3.1 9.2-5.9 13-8.4zm84 88c0-11-9-20-20-20s-20 9-20 20v14c-7.6 1.7-15.2 4.4-22.2 8.5c-13.9 8.3-25.9 22.8-25.8 43.9c.1 20.3 12 33.1 24.7 40.7c11 6.6 24.7 10.8 35.6 14l1.7 .5c12.6 3.8 21.8 6.8 28 10.7c5.1 3.2 5.8 5.4 5.9 8.2c.1 5-1.8 8-5.9 10.5c-5 3.1-12.9 5-21.4 4.7c-11.1-.4-21.5-3.9-35.1-8.5c-2.3-.8-4.7-1.6-7.2-2.4c-10.5-3.5-21.8 2.2-25.3 12.6s2.2 21.8 12.6 25.3c1.9 .6 4 1.3 6.1 2.1l0 0 0 0c8.3 2.9 17.9 6.2 28.2 8.4V424c0 11 9 20 20 20s20-9 20-20V410.2c8-1.7 16-4.5 23.2-9c14.3-8.9 25.1-24.1 24.8-45c-.3-20.3-11.7-33.4-24.6-41.6c-11.5-7.2-25.9-11.6-37.1-15l0 0-.7-.2c-12.8-3.9-21.9-6.7-28.3-10.5c-5.2-3.1-5.3-4.9-5.3-6.7c0-3.7 1.4-6.5 6.2-9.3c5.4-3.2 13.6-5.1 21.5-5c9.6 .1 20.2 2.2 31.2 5.2c10.7 2.8 21.6-3.5 24.5-14.2s-3.5-21.6-14.2-24.5c-6.5-1.7-13.7-3.4-21.1-4.7V216z"),
        "fa-coins": (512, "M512 80c0 18-14.3 34.6-38.4 48c-29.1 16.1-72.5 27.5-122.3 30.9c-3.7-1.8-7.4-3.5-11.3-5C300.6 137.4 248.2 128 192 128c-8.3 0-16.4 .2-24.5 .6l-1.1-.6C142.3 114.6 128 98 128 80c0-44.2 86-80 192-80S512 35.8 512 80zM160.7 161.1c10.2-.7 20.7-1.1 31.3-1.1c62.2 0 117.4 12.3 152.5 31.4C369.3 204.9 384 221.7 384 240c0 4-.7 7.9-2.1 11.7c-4.6 13.2-17 25.3-35 35.5c0 0 0 0 0 0c-.1 .1-.3 .1-.4 .2l0 0 0 0c-.3 .2-.6 .3-.9 .5c-35 19.4-90.8 32-153.6 32c-59.6 0-112.9-11.3-148.2-29.1c-1.9-.9-3.7-1.9-5.5-2.9C14.3 274.6 0 258 0 240c0-34.8 53.4-64.5 128-75.4c10.5-1.5 21.4-2.7 32.7-3.5zM416 240c0-21.9-10.6-39.9-24.1-53.4c28.3-4.4 54.2-11.4 76.2-20.5c16.3-6.8 31.5-15.2 43.9-25.5V176c0 19.3-16.5 37.1-43.8 50.9c-14.6 7.4-32.4 13.7-52.4 18.5c.1-1.8 .2-3.5 .2-5.3zm-32 96c0 18-14.3 34.6-38.4 48c-1.8 1-3.6 1.9-5.5 2.9C304.9 404.7 251.6 416 192 416c-62.8 0-118.6-12.6-153.6-32C14.3 370.6 0 354 0 336V300.6c12.5 10.3 27.6 18.7 43.9 25.5C83.4 342.6 135.8 352 192 352s108.6-9.4 148.1-25.9c7.8-3.2 15.3-6.9 22.4-10.9c6.1-3.4 11.8-7.2 17.2-11.2c1.5-1.1 2.9-2.3 4.3-3.4V304v5.7V336zm32 0V304 278.1c19-4.2 36.5-9.5 52.1-16c16.3-6.8 31.5-15.2 43.9-25.5V272c0 10.5-5 21-14.9 30.9c-16.3 16.3-45 29.7-81.3 38.4c.1-1.7 .2-3.5 .2-5.3zM192 448c56.2 0 108.6-9.4 148.1-25.9c16.3-6.8 31.5-15.2 43.9-25.5V432c0 44.2-86 80-192 80S0 476.2 0 432V396.6c12.5 10.3 27.6 18.7 43.9 25.5C83.4 438.6 135.8 448 192 448z"),
        "fa-medal": (512, "M4.1 38.2C1.4 34.2 0 29.4 0 24.6C0 11 11 0 24.6 0H133.9c11.2 0 21.7 5.9 27.4 15.5l68.5 114.1c-48.2 6.1-91.3 28.6-123.4 61.9L4.1 38.2zm503.7 0L405.6 191.5c-32.1-33.3-75.2-55.8-123.4-61.9L350.7 15.5C356.5 5.9 366.9 0 378.1 0H487.4C501 0 512 11 512 24.6c0 4.8-1.4 9.6-4.1 13.6zM80 336a176 176 0 1 1 352 0A176 176 0 1 1 80 336zm184.4-94.9c-3.4-7-13.3-7-16.8 0l-22.4 45.4c-1.4 2.8-4 4.7-7 5.1L168 298.9c-7.7 1.1-10.7 10.5-5.2 16l36.3 35.4c2.2 2.2 3.2 5.2 2.7 8.3l-8.6 49.9c-1.3 7.6 6.7 13.5 13.6 9.9l44.8-23.6c2.7-1.4 6-1.4 8.7 0l44.8 23.6c6.9 3.6 14.9-2.2 13.6-9.9l-8.6-49.9c-.5-3 .5-6.1 2.7-8.3l36.3-35.4c5.6-5.4 2.5-14.8-5.2-16l-50.1-7.3c-3-.4-5.7-2.4-7-5.1l-22.4-45.4z"),
        "fa-bullseye": (512, "M448 256A192 192 0 1 0 64 256a192 192 0 1 0 384 0zM0 256a256 256 0 1 1 512 0A256 256 0 1 1 0 256zm256 80a80 80 0 1 0 0-160 80 80 0 1 0 0 160zm0-224a144 144 0 1 1 0 288 144 144 0 1 1 0-288zM224 256a32 32 0 1 1 64 0 32 32 0 1 1 -64 0z"),
        "fa-user": (448, "M224 256A128 128 0 1 0 224 0a128 128 0 1 0 0 256zm-45.7 48C79.8 304 0 383.8 0 482.3C0 498.7 13.3 512 29.7 512H418.3c16.4 0 29.7-13.3 29.7-29.7C448 383.8 368.2 304 269.7 304H178.3z"),
        "fa-compact-disc": (512, "M0 256a256 256 0 1 1 512 0A256 256 0 1 1 0 256zm256 32a32 32 0 1 1 0-64 32 32 0 1 1 0 64zm-96-32a96 96 0 1 0 192 0 96 96 0 1 0 -192 0zM96 240c0-35 17.5-71.1 45.2-98.8S205 96 240 96c8.8 0 16-7.2 16-16s-7.2-16-16-16c-45.4 0-89.2 22.3-121.5 54.5S64 194.6 64 240c0 8.8 7.2 16 16 16s16-7.2 16-16z"),
        "fa-guitar": (512, "M465 7c-9.4-9.4-24.6-9.4-33.9 0L383 55c-2.4 2.4-4.3 5.3-5.5 8.5l-15.4 41-77.5 77.6c-45.1-29.4-99.3-30.2-131 1.6c-11 11-18 24.6-21.4 39.6c-3.7 16.6-19.1 30.7-36.1 31.6c-25.6 1.3-49.3 10.7-67.3 28.6C-16 328.4-7.6 409.4 47.5 464.5s136.1 63.5 180.9 18.7c17.9-17.9 27.4-41.7 28.6-67.3c.9-17 15-32.3 31.6-36.1c15-3.4 28.6-10.5 39.6-21.4c31.8-31.8 31-85.9 1.6-131l77.6-77.6 41-15.4c3.2-1.2 6.1-3.1 8.5-5.5l48-48c9.4-9.4 9.4-24.6 0-33.9L465 7zM208 256a48 48 0 1 1 0 96 48 48 0 1 1 0-96z"),
        "fa-radio": (512, "M494.8 47c12.7-3.7 20-17.1 16.3-29.8S494-2.8 481.2 1L51.7 126.9c-9.4 2.7-17.9 7.3-25.1 13.2C10.5 151.7 0 170.6 0 192v4V304 448c0 35.3 28.7 64 64 64H448c35.3 0 64-28.7 64-64V192c0-35.3-28.7-64-64-64H218.5L494.8 47zM368 240a80 80 0 1 1 0 160 80 80 0 1 1 0-160zM80 256c0-8.8 7.2-16 16-16h96c8.8 0 16 7.2 16 16s-7.2 16-16 16H96c-8.8 0-16-7.2-16-16zM64 320c0-8.8 7.2-16 16-16H208c8.8 0 16 7.2 16 16s-7.2 16-16 16H80c-8.8 0-16-7.2-16-16zm16 64c0-8.8 7.2-16 16-16h96c8.8 0 16 7.2 16 16s-7.2 16-16 16H96c-8.8 0-16-7.2-16-16z"),
        "fa-drum": (512, "M501.2 76.1c11.1-7.3 14.2-22.1 6.9-33.2s-22.1-14.2-33.2-6.9L370.2 104.5C335.8 98.7 297 96 256 96C114.6 96 0 128 0 208V368c0 31.3 27.4 58.8 72 78.7V344c0-13.3 10.7-24 24-24s24 10.7 24 24V463.4c33 8.9 71.1 14.5 112 16.1V376c0-13.3 10.7-24 24-24s24 10.7 24 24V479.5c40.9-1.6 79-7.2 112-16.1V344c0-13.3 10.7-24 24-24s24 10.7 24 24V446.7c44.6-19.9 72-47.4 72-78.7V208c0-41.1-30.2-69.5-78.8-87.4l67.9-44.5zM307.4 145.6l-64.6 42.3c-11.1 7.3-14.2 22.1-6.9 33.2s22.1 14.2 33.2 6.9l111.1-72.8c14.7 3.2 27.9 7 39.4 11.5C458.4 181.8 464 197.4 464 208c0 .8-2.7 17.2-46 35.9C379.1 260.7 322 272 256 272s-123.1-11.3-162-28.1C50.7 225.2 48 208.8 48 208c0-10.6 5.6-26.2 44.4-41.3C130.6 151.9 187.8 144 256 144c18 0 35.1 .5 51.4 1.6z"),
    ]
}

/// An item icon as `O1` draws it: a mark fills a `size` square, a Font Awesome
/// glyph is `size` tall and as wide as its own proportions. Unknown classes
/// fall back to the person, like the browser's `fa-user`.
struct CosmeticGlyph: View {
    let iconClass: String?
    var anim: String? = nil
    var size: CGFloat = 38
    var tint: Color = CosmeticTone.accentPale

    var body: some View {
        if let a = anim, CosmeticMotion.isKnown(a) {
            TimelineView(.animation) { timeline in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                glyph.modifier(CosmeticMotion(kind: a, time: t))
            }
        } else {
            glyph
        }
    }

    @ViewBuilder
    private var glyph: some View {
        let key: String = iconClass ?? "fa-user"
        if key.hasPrefix("mark:"), let layers = CosmeticGlyphs.marks[String(key.dropFirst(5))] {
            ZStack {
                ForEach(0..<layers.count, id: \.self) { i in
                    GlyphShape(data: layers[i].path, box: CGSize(width: 24, height: 24))
                        .fill(tint, style: FillStyle(eoFill: layers[i].evenOdd))
                        .opacity(layers[i].opacity)
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        } else {
            let entry = CosmeticGlyphs.fontAwesome[key] ?? CosmeticGlyphs.fontAwesome["fa-user"]!
            GlyphShape(data: entry.path, box: CGSize(width: entry.width, height: 512))
                .fill(tint)
                .frame(width: size * entry.width / 512, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// Font Awesome's animation classes, frame by frame (fa-spin 2 s linear,
/// fa-beat 1 s to 1.25 at 45 %, fa-fade 1 s to 40 % at 50 %, fa-beat-fade 1 s).
struct CosmeticMotion: ViewModifier {
    let kind: String
    let time: Double

    static func isKnown(_ kind: String) -> Bool {
        ["fa-spin", "fa-beat", "fa-fade", "fa-beat-fade"].contains(kind)
    }

    func body(content: Content) -> some View {
        let phase: Double = time.truncatingRemainder(dividingBy: kind == "fa-spin" ? 2 : 1)
        var angle: Double = 0
        var scale: Double = 1
        var alpha: Double = 1
        switch kind {
        case "fa-spin":
            angle = phase / 2 * 360
        case "fa-beat":
            // 0 → 45 %: up to 1.25, 45 → 90 %: back, then rest.
            if phase < 0.45 { scale = 1 + 0.25 * ease(phase / 0.45) }
            else if phase < 0.9 { scale = 1.25 - 0.25 * ease((phase - 0.45) / 0.45) }
        case "fa-fade":
            let half: Double = phase < 0.5 ? phase / 0.5 : (1 - phase) / 0.5
            alpha = 1 - 0.6 * ease(half)
        default: // fa-beat-fade
            let half: Double = phase < 0.5 ? phase / 0.5 : (1 - phase) / 0.5
            let k: Double = ease(half)
            alpha = 0.4 + 0.6 * k
            scale = 1 + 0.125 * k
        }
        return content
            .rotationEffect(.degrees(angle))
            .scaleEffect(scale)
            .opacity(alpha)
    }

    private func ease(_ x: Double) -> Double {
        let c: Double = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }
}

/// The gold-spots coin (`ga`): ring 1.6 on a 16 grid with a 20 % fill and a dot.
struct GoldSpotsIcon: View {
    var size: CGFloat = 12

    var body: some View {
        let gold = Color(hex: 0xFBBF24)
        let unit: CGFloat = size / 16
        ZStack {
            Circle().fill(gold.opacity(0.2)).frame(width: 14 * unit, height: 14 * unit)
            Circle().stroke(gold, lineWidth: 1.6 * unit).frame(width: 14 * unit, height: 14 * unit)
            Circle().fill(gold).frame(width: 4.4 * unit, height: 4.4 * unit)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A price: coin or note, an optional struck-through full price, the amount.
struct PriceTag: View {
    let price: ItemPrice
    /// Icon size; the text follows it unless `textSize` says otherwise.
    var size: CGFloat = 10
    var showsFull: Bool = true
    var textSize: CGFloat? = nil
    /// Spots prices are lilac on cards; the buy sheet shows them in the accent.
    var spotsTint: Color = CosmeticTone.spots

    var body: some View {
        HStack(spacing: 4) {
            if price.isGold {
                GoldSpotsIcon(size: size)
            } else {
                LucideGlyph(icon: .music2, size: size)
            }
            if showsFull && price.isDiscounted {
                Text(groupedNumber(price.fullAmount))
                    .strikethrough()
                    .foregroundColor(Palette.subdued)
            }
            Text(groupedNumber(price.amount)).monospacedDigit()
        }
        .font(.brand(textSize ?? size, .bold))
        .foregroundColor(price.isGold ? Color(hex: 0xFBBF24) : spotsTint)
    }
}

// MARK: - Title pill

/// A title as `Vi` draws it: 10 pt bold capitals, padding 3/8/1, corners 12,
/// tinted 16 % with a 42 % border - or white 6 % / 14 % without a colour.
/// Gradient titles get the gradient as text fill.
struct TitlePill: View {
    let text: String
    let colorHex: String?
    var small: Bool = false

    var body: some View {
        let plain: Color? = CosmeticTone.plain(colorHex)
        let shape = RoundedRectangle(cornerRadius: 12, style: .circular)
        label
            .padding(.horizontal, small ? 6 : 8)
            .padding(.top, small ? 2 : 3)
            .padding(.bottom, small ? 0 : 1)
            .background(shape.fill(plain.map { $0.opacity(0.16) } ?? Color.white.opacity(0.06)))
            .overlay(shape.strokeBorder(plain.map { $0.opacity(0.42) } ?? Color.white.opacity(0.14), lineWidth: 1))
    }

    @ViewBuilder
    private var label: some View {
        let words = Text(text.uppercased())
            .font(.brand(small ? 9 : 10, .bold))
            .tracking(small ? 0.45 : 0.5)
        if let h = colorHex, h.contains("gradient"), let fill = CosmeticTone.paint(h) {
            words.foregroundColor(.clear)
                .overlay(Rectangle().fill(fill).mask(words))
                .lineLimit(1)
        } else {
            words.foregroundColor(CosmeticTone.plain(colorHex) ?? Palette.foreground)
                .lineLimit(1)
        }
    }
}

// MARK: - Name effects

/// A player name with a name effect (`nfx-x-*` in cosmetics.css).
struct EffectName: View {
    let text: String
    let cssClass: String?
    let size: CGFloat
    var color: Color = CosmeticTone.accentPale

    var body: some View {
        switch cssClass ?? "" {
        case "nfx-x-neon", "nfx-x-ripple", "nfx-x-static":
            TimelineView(.animation) { timeline in
                animated(timeline.date.timeIntervalSinceReferenceDate)
            }
        case "nfx-x-emboss":
            base.shadow(color: Color.white.opacity(0.45), radius: 0, x: 0, y: -1)
                .shadow(color: Color.black.opacity(0.75), radius: 0.5, x: 0, y: 1)
        case "nfx-x-frost":
            base.shadow(color: Color.white.opacity(0.9), radius: 0.5, x: 0, y: 0)
                .shadow(color: Color.black.opacity(0.95), radius: 3.5, x: 0, y: 2)
        case "nfx-x-gilded":
            let gold = LinearGradient(colors: [Color(hex: 0xFDE68A), Color(hex: 0xF59E0B), Color(hex: 0xA16207)],
                                      startPoint: .top, endPoint: .bottom)
            plainText.foregroundColor(.clear)
                .overlay(Rectangle().fill(gold).mask(plainText))
                .shadow(color: Color.black.opacity(0.55), radius: 1, x: 0, y: 1)
        case "nfx-x-drop":
            base.shadow(color: Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.85), radius: 0, x: 2, y: 2)
        default:
            base
        }
    }

    private var plainText: Text {
        Text(text).font(.brand(size, .heavy))
    }

    private var base: some View {
        plainText.foregroundColor(color).lineLimit(1)
    }

    @ViewBuilder
    private func animated(_ t: Double) -> some View {
        switch cssClass ?? "" {
        case "nfx-x-neon":
            // 2.4 s: glow 2/5 px → 1/3 px → back.
            let phase: Double = t.truncatingRemainder(dividingBy: 2.4) / 2.4
            let k: Double = 0.5 - 0.5 * cos(phase * 2 * .pi)
            base.shadow(color: color, radius: 1 - 0.5 * k, x: 0, y: 0)
                .shadow(color: color, radius: 2.5 - 1 * k, x: 0, y: 0)
        case "nfx-x-ripple":
            // A white band sweeps left to right in 3.2 s: a 300 % wide gradient
            // (white at 50 %, fading out by ±15 %) moved from position 120 % to
            // -20 %, i.e. its centre travels from -0.9 to 1.9 widths, ±0.45 wide.
            let phase: Double = t.truncatingRemainder(dividingBy: 3.2) / 3.2
            let centre: Double = -0.9 + 2.8 * phase
            let band = LinearGradient(stops: [
                .init(color: color, location: 0.35),
                .init(color: .white, location: 0.5),
                .init(color: color, location: 0.65)
            ], startPoint: .leading, endPoint: .trailing)
            plainText.foregroundColor(.clear)
                .overlay(
                    GeometryReader { g in
                        band
                            .frame(width: g.size.width * 3, height: g.size.height)
                            .offset(x: (CGFloat(centre) - 1.5) * g.size.width)
                    }
                    .mask(plainText)
                )
                .lineLimit(1)
        default:
            // nfx-x-static: 4 s of flicker in steps.
            let p: Double = t.truncatingRemainder(dividingBy: 4) / 4
            let alpha: Double = (p >= 0.08 && p < 0.09) ? 0.35 : (p >= 0.45 && p < 0.46) ? 0.55 : (p >= 0.72 && p < 0.73) ? 0.4 : 1
            base.opacity(alpha)
        }
    }
}

// MARK: - Backgrounds

/// One CSS `radial-gradient(rx% ry% at cx% cy%, colour 0%, transparent stop%)`.
private struct RadialSpot {
    let rx: CGFloat
    let ry: CGFloat
    let cx: CGFloat
    let cy: CGFloat
    let color: Color
    let stop: CGFloat
}

/// The profile backgrounds (`bg-b-*` in cosmetics.css): a vertical gradient
/// with one or two soft spots on top.
struct BackgroundSwatch: View {
    let cssClass: String?

    var body: some View {
        let recipe = BackgroundSwatch.recipe(cssClass)
        GeometryReader { geo in
            let w: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            ZStack {
                LinearGradient(colors: recipe.base, startPoint: .top, endPoint: .bottom)
                ForEach(0..<recipe.spots.count, id: \.self) { i in
                    spot(recipe.spots[i], width: w, height: h)
                }
                if recipe.dotted {
                    BackgroundDots(spacing: 14, color: Color(hex: 0x94A3B8).opacity(0.10))
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    private func spot(_ s: RadialSpot, width w: CGFloat, height h: CGFloat) -> some View {
        let rx: CGFloat = max(1, s.rx * w)
        let ry: CGFloat = max(1, s.ry * h)
        return RadialGradient(colors: [s.color, s.color.opacity(0)], center: .center,
                              startRadius: 0, endRadius: rx * s.stop)
            .frame(width: rx * 2, height: rx * 2)
            .scaleEffect(x: 1, y: ry / rx)
            .position(x: s.cx * w, y: s.cy * h)
    }

    private static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    fileprivate static func recipe(_ css: String?) -> (base: [Color], spots: [RadialSpot], dotted: Bool) {
        switch css ?? "" {
        case "bg-b-daybreak":
            return ([Color(hex: 0x0B1024), Color(hex: 0x160F22), Color(hex: 0x1C1116), Color(hex: 0x241408)],
                    [RadialSpot(rx: 1.2, ry: 0.8, cx: 0.5, cy: 1.08, color: rgba(251, 191, 36, 0.2), stop: 0.62),
                     RadialSpot(rx: 0.9, ry: 0.6, cx: 0.2, cy: 0.92, color: rgba(244, 114, 182, 0.13), stop: 0.6)], false)
        case "bg-b-graphite":
            return ([Color(hex: 0x0B0B10), Color(hex: 0x07070C)],
                    [RadialSpot(rx: 1.2, ry: 0.7, cx: 0.5, cy: -0.1, color: rgba(226, 232, 240, 0.1), stop: 0.6)], false)
        case "bg-b-undertow":
            return ([Color(hex: 0x06070D), Color(hex: 0x050810)],
                    [RadialSpot(rx: 1.3, ry: 0.75, cx: 0.5, cy: 1.12, color: rgba(45, 212, 191, 0.16), stop: 0.62),
                     RadialSpot(rx: 0.8, ry: 0.5, cx: 0.78, cy: 1.0, color: rgba(56, 189, 248, 0.09), stop: 0.58)], false)
        case "bg-b-midnight":
            return ([Color(hex: 0x05050B), Color(hex: 0x04040A)],
                    [RadialSpot(rx: 1.4, ry: 0.9, cx: 0.5, cy: -0.2, color: rgba(99, 102, 241, 0.13), stop: 0.58),
                     RadialSpot(rx: 1.0, ry: 0.6, cx: 0.5, cy: 1.18, color: rgba(30, 64, 175, 0.12), stop: 0.6)], false)
        case "bg-b-rosewood":
            return ([Color(hex: 0x0B0709), Color(hex: 0x07060A)],
                    [RadialSpot(rx: 1.1, ry: 0.7, cx: 0.12, cy: 1.05, color: rgba(244, 63, 94, 0.15), stop: 0.6),
                     RadialSpot(rx: 0.8, ry: 0.55, cx: 0.88, cy: 0, color: rgba(217, 72, 15, 0.1), stop: 0.58)], false)
        case "bg-b-static":
            return ([Color(hex: 0x08080E), Color(hex: 0x06060B)],
                    [RadialSpot(rx: 1.1, ry: 0.7, cx: 0.5, cy: 0, color: rgba(148, 163, 184, 0.08), stop: 0.6)], true)
        case "bg-b-ultraviolet":
            return ([Color(hex: 0x0A0612), Color(hex: 0x06050C)],
                    [RadialSpot(rx: 1.2, ry: 0.75, cx: 0.5, cy: -0.12, color: rgba(168, 85, 247, 0.22), stop: 0.58),
                     RadialSpot(rx: 0.7, ry: 0.45, cx: 0.15, cy: 0.08, color: rgba(217, 70, 239, 0.1), stop: 0.55)], false)
        default:
            // "Standard": the plain page colour behind the preview.
            return ([Color(hex: 0x07070C), Color(hex: 0x07070C)], [], false)
        }
    }
}

/// A dot every `spacing` points, 1 pt radius (bg-b-static).
private struct BackgroundDots: View {
    let spacing: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

// MARK: - Item preview

/// The middle of every card (`Mf`): icon, colour disc, background swatch,
/// name effect on "Taubey" (the site's own sample name) or the title pill.
struct ItemPreview: View {
    let item: CatalogItem
    let type: String
    var size: CGFloat = 38

    var body: some View {
        switch type {
        case "icon":
            CosmeticGlyph(iconClass: item.iconClass, anim: item.anim, size: size,
                          tint: CosmeticTone.representative(item.colorHex) ?? CosmeticTone.accentPale)
        case "color", "accent-color":
            colorDisc
        case "background":
            let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
            BackgroundSwatch(cssClass: item.cssClass)
                .frame(height: size * 1.9)
                .frame(maxWidth: .infinity)
                .background(Color(hex: 0x07070C))
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        case "name-effect":
            EffectName(text: "Taubey", cssClass: item.cssClass, size: size * 0.42)
                .padding(.vertical, 6)
        default:
            TitlePill(text: item.displayName, colorHex: item.colorHex)
        }
    }

    private var colorDisc: some View {
        let mid: Color? = CosmeticTone.representative(item.colorHex)
        let gradient: Bool = item.isGradient
        let fill: AnyShapeStyle = CosmeticTone.paint(item.colorHex) ?? AnyShapeStyle(Color.white.opacity(0.08))
        return VStack(spacing: 6) {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .frame(width: size * 1.5, height: size * 1.5)
                .shadow(color: (mid ?? .clear).opacity(0.33), radius: 9)
            Text(gradient ? "GRADIENT" : "SOLID")
                .font(.brand(9, .bold))
                .tracking(0.45)
                .foregroundColor(gradient && mid != nil ? mid! : Color(hex: 0x6B6A8A))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(gradient && mid != nil ? mid!.opacity(0.14) : Color.white.opacity(0.05)))
        }
    }
}

// MARK: - Controls

/// The category pills (`Z1`): 12 pt semibold, padding 8/12, the active one
/// tinted with the accent. Optional counts ("1/13") after the label.
struct CategoryTabs: View {
    let categories: [ItemCategory]
    @Binding var active: String
    var counts: [String: String] = [:]

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.type) { c in
                        pill(c).id(c.type)
                    }
                }
                .padding(.bottom, 4)
            }
            .onChange(of: active) { value in
                withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo(value, anchor: .center) }
            }
        }
    }

    private func pill(_ c: ItemCategory) -> some View {
        let on: Bool = c.type == active
        return Button {
            active = c.type
        } label: {
            HStack(spacing: 6) {
                Text(c.label).font(.brand(12, .semibold))
                if let n = counts[c.type] {
                    Text(n).font(.brand(10, .bold))
                        .foregroundColor(on ? CosmeticTone.accentPale : Palette.subdued)
                }
            }
            .foregroundColor(on ? Palette.accent : Palette.subdued)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(on ? Palette.accent.opacity(0.15) : CosmeticTone.control))
            .overlay(Capsule().strokeBorder(on ? Palette.accent.opacity(0.5) : Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// "Search items..." - 42 tall, corners 18.
struct ItemSearchField: View {
    @Binding var text: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        HStack(spacing: 8) {
            LucideGlyph(icon: .search, size: 13)
                .foregroundColor(Palette.faint)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Search items...").font(.brand(13)).foregroundColor(Palette.faint)
                }
                TextField("", text: $text)
                    .font(.brand(13))
                    .foregroundColor(Palette.foreground)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(shape.fill(CosmeticTone.control))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }
}

/// The filter dropdown (`Q1`): the chosen option in --acc-pale, chevron right.
struct ItemFilterMenu: View {
    let choices: [ItemFilter]
    @Binding var selection: ItemFilter

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        Menu {
            ForEach(choices, id: \.self) { f in
                Button {
                    selection = f
                } label: {
                    if f == selection {
                        Label(f.label, systemImage: "checkmark")
                    } else {
                        Text(f.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selection.label)
                    .font(.brand(12, .semibold))
                    .foregroundColor(CosmeticTone.accentPale)
                Spacer(minLength: 0)
                LucideGlyph(icon: .chevronDown, size: 13)
                    .foregroundColor(Palette.subdued)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(shape.fill(CosmeticTone.control))
            .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
            .contentShape(shape)
        }
    }
}

/// A group heading (`J1`): 2 × 14 bar, label in the group colour, count.
struct ItemGroupHeading: View {
    let group: ItemGroup
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(group.tint).frame(width: 2, height: 14)
            Text(group.label.uppercased())
                .font(.brand(11, .bold))
                .tracking(1.1)
                .foregroundColor(group.tint)
            Text("\(count)")
                .font(.brand(11, .semibold))
                .foregroundColor(Palette.subdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Two columns, 12 apart, cards in a row stretched to the same height - the
/// browser's `grid grid-cols-2 gap-3`.
struct TwoColumnGrid<Card: View>: View {
    let count: Int
    @ViewBuilder let card: (Int) -> Card

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<((count + 1) / 2), id: \.self) { row in
                HStack(alignment: .top, spacing: 12) {
                    card(row * 2).frame(maxWidth: .infinity, maxHeight: .infinity)
                    if row * 2 + 1 < count {
                        card(row * 2 + 1).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// "Opening the shop…" with the equalizer loader, or the empty state.
struct CosmeticNotice: View {
    let text: String
    var loading: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            if loading {
                BoardLoadingBars()
            } else {
                LucideGlyph(icon: .palette, size: 26)
                    .foregroundColor(Palette.subdued)
            }
            Text(text)
                .font(.brand(loading ? 12 : 13))
                .foregroundColor(Palette.subdued)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, loading ? 64 : 56)
    }
}

/// The red card for a load error.
struct CosmeticErrorCard: View {
    let text: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        Text(text)
            .font(.brand(13))
            .foregroundColor(Palette.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(shape.fill(Color(hex: 0xEF4444).opacity(0.08)))
            .overlay(shape.strokeBorder(Color(hex: 0xEF4444).opacity(0.3), lineWidth: 1))
    }
}

/// The short message at the top after equipping or a failed buy.
struct CosmeticToast: Equatable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct CosmeticToastView: View {
    @Binding var toast: CosmeticToast?

    var body: some View {
        if let t = toast {
            Text(t.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(t.isError ? Palette.bad : Palette.foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Palette.card))
                .overlay(Capsule().strokeBorder(t.isError ? Palette.bad.opacity(0.4) : Palette.border, lineWidth: 1))
                .padding(.top, 70)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: t.id) {
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    if toast?.id == t.id {
                        withAnimation { toast = nil }
                    }
                }
        }
    }
}

/// The round "back to top" button (`Ui`): 42, bottom right, after 320 pt.
struct BackToTopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LucideGlyph(icon: .chevronDown, size: 17)
                .rotationEffect(.degrees(180))
                .foregroundColor(Palette.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Palette.card))
                .overlay(Circle().strokeBorder(Palette.accent.opacity(0.4), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.5), radius: 13, x: 0, y: 8)
                .shadow(color: Palette.accent.opacity(0.22), radius: 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back to top"))
    }
}

/// Reports how far a scroll view has scrolled (iOS 16 has no API for it).
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
