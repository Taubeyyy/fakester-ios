import SwiftUI

/// Anmelden oder als Gast spielen - derselbe Weg wie im Browser.
struct AnmeldeAnsicht: View {
    @EnvironmentObject private var api: Api

    @State private var name = ""
    @State private var passwort = ""
    @State private var gastname = ""
    @State private var neuesKonto = false
    @State private var laeuft = false
    @State private var fehler: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Schriftzug().padding(.top, 48)

                AktualisierungsKarte()

                Text("Rate den Song, schlag die Runde.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Farbe.gedaempft)

                Karte {
                    VStack(spacing: 12) {
                        Text(neuesKonto ? "KONTO ANLEGEN" : "ANMELDEN").etikett()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Feld(text: $name, platzhalter: "Benutzername")
                            .textContentType(.username)
                        Feld(text: $passwort, platzhalter: "Passwort", geheim: true)
                            .textContentType(neuesKonto ? .newPassword : .password)

                        if let fehler {
                            Text(fehler)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Farbe.schlecht)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(neuesKonto ? "Konto anlegen" : "Anmelden") { los() }
                            .buttonStyle(Hauptknopf(aus: !bereit || laeuft))
                            .disabled(!bereit || laeuft)

                        Button(neuesKonto ? "Ich habe schon ein Konto" : "Noch kein Konto? Anlegen") {
                            withAnimation { neuesKonto.toggle(); fehler = nil }
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Farbe.akzentHell)
                    }
                }

                Karte {
                    VStack(spacing: 12) {
                        Text("ODER ALS GAST").etikett()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Spielen geht sofort. XP, Spots und Gegenstaende gehoeren aber zu einem Konto.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Farbe.gedaempft)
                            .fixedSize(horizontal: false, vertical: true)

                        Feld(text: $gastname, platzhalter: "Dein Name")

                        Button("Als Gast spielen") {
                            api.alsGast(name: gastname)
                            Spuerbar.tipp()
                        }
                        .buttonStyle(Nebenknopf())
                        .disabled(gastname.trimmingCharacters(in: .whitespaces).count < 2)
                        .opacity(gastname.trimmingCharacters(in: .whitespaces).count < 2 ? 0.5 : 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var bereit: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 3 && passwort.count >= 4
    }

    private func los() {
        laeuft = true
        fehler = nil
        Task {
            do {
                if neuesKonto {
                    try await api.registrieren(name: name, passwort: passwort)
                } else {
                    try await api.anmelden(name: name, passwort: passwort)
                }
                Spuerbar.richtig()
            } catch {
                fehler = error.localizedDescription
                Spuerbar.falsch()
            }
            laeuft = false
        }
    }
}

/// Ein Eingabefeld im Stil des Spiels. Die eingebauten Felder von SwiftUI
/// bringen eine helle Umrandung mit, die hier fehl am Platz waere.
struct Feld: View {
    @Binding var text: String
    let platzhalter: String
    var geheim = false
    var nurZiffern = false

    var body: some View {
        Group {
            if geheim {
                SecureField("", text: $text, prompt: wink)
            } else {
                TextField("", text: $text, prompt: wink)
            }
        }
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundColor(Farbe.schrift)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(nurZiffern ? .numberPad : .default)
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Farbe.grund, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Farbe.kante, lineWidth: 1)
        )
    }

    private var wink: Text {
        Text(platzhalter).foregroundColor(Farbe.gedaempft.opacity(0.8))
    }
}

/// Startbildschirm, sobald klar ist, wer spielt: Lobby ueber die PIN betreten.
struct DaheimAnsicht: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var spiel: Spiel

    @State private var pin = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Schriftzug().padding(.top, 48)

                if let a = api.ausweis {
                    HStack(spacing: 8) {
                        Text(a.username)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Farbe.schrift)
                        if a.isGuest {
                            Text("GAST")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(Farbe.grund)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Farbe.akzent, in: Capsule())
                        }
                    }
                }

                Karte {
                    VStack(spacing: 12) {
                        Text("LOBBY BEITRETEN").etikett()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Die PIN steht beim Gastgeber im Spiel.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Farbe.gedaempft)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Feld(text: $pin, platzhalter: "PIN", nurZiffern: true)
                            .font(.system(size: 22, weight: .black, design: .rounded))

                        Button("Beitreten") {
                            guard let a = api.ausweis else { return }
                            Spuerbar.tipp()
                            spiel.betreten(pin: pin, als: a)
                        }
                        .buttonStyle(Hauptknopf(aus: pin.count < 4))
                        .disabled(pin.count < 4)
                    }
                }

                Karte {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOCH NICHT DRIN").etikett()
                        Text("Eine eigene Lobby aufmachen, Timeline, Higher/Lower, Shop und Quests gibt es bisher nur im Browser. Kommt hier nach und nach dazu.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Farbe.gedaempft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 24) {
                    Button("Feedback") {
                        NotificationCenter.default.post(name: .geschuettelt, object: nil)
                    }
                    Button(api.angemeldet ? "Abmelden" : "Anderer Name") {
                        api.abmelden()
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Farbe.gedaempft)
                Text("Tipp: Handy schütteln schickt auch Feedback.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Farbe.gedaempft.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
