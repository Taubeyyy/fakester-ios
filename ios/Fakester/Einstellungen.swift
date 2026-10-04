import SwiftUI

/// Was die App selbst einstellen kann. Konto-Dinge (Name, Passwort, Farben)
/// gehoeren dem Server und kommen erst, wenn es dafuer eine belegte Vorlage
/// aus dem Browser gibt.
enum Vorgabe {
    static let lautstaerke = "lautstaerke"
    static let vibration = "vibration"

    /// 0...1, ohne Eintrag volle Lautstaerke.
    static var lautstaerkeWert: Float {
        let d = UserDefaults.standard
        return d.object(forKey: lautstaerke) == nil ? 1 : Float(d.double(forKey: lautstaerke))
    }

    /// Ohne Eintrag an.
    static var vibrationAn: Bool {
        let d = UserDefaults.standard
        return d.object(forKey: vibration) == nil ? true : d.bool(forKey: vibration)
    }
}

struct EinstellungsBlatt: View {
    @Environment(\.dismiss) private var schliessen
    @AppStorage(Sprache.schluessel) private var sprache: String = ""
    @AppStorage(Vorgabe.lautstaerke) private var lautstaerke: Double = 1
    @AppStorage(Vorgabe.vibration) private var vibration: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sprachKarte
                    tonKarte
                    infoKarte
                }
                .padding(20)
            }
            .background(Farbe.grund.ignoresSafeArea())
            .navigationTitle(L("Einstellungen", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Fertig", "Done")) { schliessen() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Sprache

    private var sprachKarte: some View {
        Karte {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("SPRACHE", "LANGUAGE")).etikett()
                HStack(spacing: 8) {
                    SprachWahl(titel: L("Automatisch", "Automatic"), wert: "", gewaehlt: $sprache)
                    SprachWahl(titel: "Deutsch", wert: "de", gewaehlt: $sprache)
                    SprachWahl(titel: "English", wert: "en", gewaehlt: $sprache)
                }
            }
        }
    }

    // MARK: Ton & Vibration

    private var tonKarte: some View {
        Karte {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("TON", "SOUND")).etikett()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L("Lautstärke der Songs", "Song volume"))
                            .font(.marke(14, .semibold))
                            .foregroundColor(Farbe.schrift)
                        Spacer()
                        Text("\(Int((lautstaerke * 100).rounded())) %")
                            .font(.mono(13))
                            .foregroundColor(Farbe.gedaempft)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Farbe.leise)
                        Slider(value: $lautstaerke, in: 0...1)
                            .tint(Farbe.akzent)
                            .onChange(of: lautstaerke) { neu in
                                Ton.gemeinsam.lautstaerkeSetzen(Float(neu))
                            }
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Farbe.leise)
                    }
                }
                Toggle(isOn: $vibration) {
                    Text(L("Vibration", "Haptics"))
                        .font(.marke(14, .semibold))
                        .foregroundColor(Farbe.schrift)
                }
                .tint(Farbe.akzent)
            }
        }
    }

    // MARK: Info

    private var infoKarte: some View {
        Karte {
            VStack(alignment: .leading, spacing: 10) {
                Text("APP").etikett()
                HStack {
                    Text("Version")
                        .font(.marke(14, .semibold))
                        .foregroundColor(Farbe.schrift)
                    Spacer()
                    Text(versionText)
                        .font(.mono(13, fett: false))
                        .foregroundColor(Farbe.gedaempft)
                }
                Text(L("Mehr Einstellungen kommen nach und nach.", "More settings are on their way."))
                    .font(.marke(12))
                    .foregroundColor(Farbe.leise)
            }
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

/// Eine Pille in der Sprachauswahl.
struct SprachWahl: View {
    let titel: String
    let wert: String
    @Binding var gewaehlt: String

    var body: some View {
        let an: Bool = gewaehlt == wert
        Button {
            Spuerbar.tipp()
            gewaehlt = wert
        } label: {
            Text(titel)
                .font(.marke(13, .bold))
                .foregroundColor(an ? Farbe.akzent : Farbe.gedaempft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Capsule().fill(an ? Farbe.akzent.opacity(0.14) : Farbe.grund3))
                .overlay(Capsule().strokeBorder(an ? Farbe.akzent : Farbe.kante, lineWidth: 1))
        }
        .buttonStyle(BubbleDruck())
    }
}
