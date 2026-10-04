import SwiftUI

/// Das Aussehen, abgeglichen mit fakester.app - damit die App nicht aussieht wie
/// ein fremdes Programm, das zufaellig dieselben Daten zeigt.
enum Farbe {
    static let grund     = Color(hex: 0x07070C)
    static let flaeche   = Color(hex: 0x12121B)
    static let kante     = Color(hex: 0x24243A)
    static let akzent    = Color(hex: 0xB15CFF)
    static let akzentHell = Color(hex: 0xC9B8FC)
    static let schrift   = Color(hex: 0xF2F0FF)
    static let gedaempft = Color(hex: 0x9A96B8)
    static let gut       = Color(hex: 0x3DD68C)
    static let schlecht  = Color(hex: 0xE8465F)
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

/// Der Hintergrund des ganzen Spiels: fast schwarz, mit einem Schimmer Violett
/// oben - wie im Browser.
struct Buehne: View {
    var body: some View {
        ZStack {
            Farbe.grund
            RadialGradient(colors: [Farbe.akzent.opacity(0.22), .clear],
                           center: .top, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

/// Eine Karte, wie sie im Spiel ueberall steht.
struct Karte<Inhalt: View>: View {
    var polster: CGFloat = 16
    @ViewBuilder var inhalt: Inhalt

    var body: some View {
        inhalt
            .padding(polster)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farbe.flaeche, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Farbe.kante, lineWidth: 1)
            )
    }
}

/// Der grosse Knopf. Ein Spiel auf Zeit wird mit dem Daumen bedient, also ist
/// die Trefferflaeche hier bewusst gross und nicht an die Schrift gebunden.
struct Hauptknopf: ButtonStyle {
    var farbe: Color = Farbe.akzent
    var aus: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(aus ? Farbe.gedaempft : Color(hex: 0x120A1E))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(aus ? Farbe.kante : farbe,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Nebenknopf: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(Farbe.schrift)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Farbe.flaeche, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Farbe.kante, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension Text {
    /// Die Ueberschriften im Spiel sind durchweg gesperrt und klein - das traegt
    /// den Wiedererkennungswert, nicht die Farbe.
    func etikett() -> some View {
        self.font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.6)
            .foregroundColor(Farbe.gedaempft)
    }
}

/// Der Schriftzug, der auf jedem Bildschirm oben steht.
struct Schriftzug: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("FAKE").foregroundColor(Farbe.schrift)
            Text("STER").foregroundColor(Farbe.akzent)
        }
        .font(.system(size: 30, weight: .black, design: .rounded))
        .tracking(-0.5)
    }
}
