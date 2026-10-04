import SwiftUI
import UIKit

// Neue Version? Fragt beim Start das neueste GitHub-Release (build-<N>) ab und bietet die
// Installation per TrollStore an. Nur fuer die TrollStore-Fassung - im App Store ist so etwas
// verboten, dort muss das hier raus (Apple aktualisiert dann selbst).

@MainActor
final class Aktualisierung: ObservableObject {
    static let shared = Aktualisierung()

    struct Neu: Equatable {
        let build: Int
        let url: String
        let text: String
    }

    @Published private(set) var neu: Neu?
    private var zuletzt: Date?

    var eigenerBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    func pruefen() async {
        // hoechstens alle 10 Minuten (GitHub erlaubt ohne Anmeldung 60 Abfragen pro Stunde)
        if let zuletzt, Date().timeIntervalSince(zuletzt) < 600 { return }
        zuletzt = Date()

        struct Anhang: Decodable { let name: String; let browser_download_url: String }
        struct Veroeffentlichung: Decodable { let tag_name: String; let body: String?; let assets: [Anhang] }

        var anfrage = URLRequest(url: URL(string: "https://api.github.com/repos/Taubeyyy/fakester-ios/releases/latest")!)
        anfrage.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        anfrage.timeoutInterval = 15
        guard let (daten, _) = try? await URLSession.shared.data(for: anfrage),
              let v = try? JSONDecoder().decode(Veroeffentlichung.self, from: daten),
              let build = Int(v.tag_name.replacingOccurrences(of: "build-", with: "")),
              build > eigenerBuild,
              let ipa = v.assets.first(where: { $0.name.hasSuffix(".ipa") }) else { return }
        // Release-Text ist "Commit abc1234: <Nachricht>" - nur die Nachricht zeigen
        var text = v.body ?? ""
        if let doppelpunkt = text.range(of: ": "), text.hasPrefix("Commit ") { text = String(text[doppelpunkt.upperBound...]) }
        withAnimation(.easeOut(duration: 0.25)) {
            neu = Neu(build: build, url: ipa.browser_download_url, text: text)
        }
    }

    func installieren() {
        guard let neu else { return }
        let kodiert = neu.url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? neu.url
        if let troll = URL(string: "apple-magnifier://install?url=\(kodiert)") {
            UIApplication.shared.open(troll)
        }
    }
}

/// Karte auf dem Startbildschirm, wenn es eine neue Version gibt.
struct AktualisierungsKarte: View {
    @ObservedObject private var aktualisierung = Aktualisierung.shared

    var body: some View {
        if let neu = aktualisierung.neu {
            Karte {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("NEUE VERSION", "NEW VERSION")).etikett()
                    Text(L("Build \(neu.build) ist da", "Build \(neu.build) is out"))
                        .font(.marke(18, .heavy))
                        .foregroundColor(Farbe.schrift)
                    if !neu.text.isEmpty {
                        Text(neu.text)
                            .font(.marke(13))
                            .foregroundColor(Farbe.gedaempft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(L("Installieren", "Install")) {
                        Spuerbar.tipp()
                        aktualisierung.installieren()
                    }
                    .buttonStyle(Hauptknopf())
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
