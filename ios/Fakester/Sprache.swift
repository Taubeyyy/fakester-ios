import SwiftUI

/// Deutsch oder Englisch. Ohne eigene Wahl gilt die Sprache des Handys:
/// Deutsch nur, wenn das Handy deutsch spricht - sonst Englisch.
enum Sprache: String {
    case de, en

    static let schluessel = "sprache"

    static var aktuell: Sprache {
        if let s = UserDefaults.standard.string(forKey: schluessel), let w = Sprache(rawValue: s) {
            return w
        }
        let erste = Locale.preferredLanguages.first ?? "en"
        return erste.hasPrefix("de") ? .de : .en
    }
}

/// Ein Text in beiden Sprachen; zurueck kommt der passende.
func L(_ de: String, _ en: String) -> String {
    Sprache.aktuell == .en ? en : de
}

/// Umschalter fuer den Startbildschirm. Die Wurzel haengt am selben Schluessel
/// und baut die Ansichten neu, sobald er sich aendert.
struct SprachKnopf: View {
    @AppStorage(Sprache.schluessel) private var sprache: String = ""

    var body: some View {
        Button {
            sprache = (Sprache.aktuell == .en ? Sprache.de : Sprache.en).rawValue
        } label: {
            Text(Sprache.aktuell == .en ? "🇩🇪 Deutsch" : "🇬🇧 English")
                .font(.marke(12, .bold))
                .foregroundColor(Farbe.gedaempft)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Glas(radius: 999))
        }
        .buttonStyle(BubbleDruck())
    }
}
