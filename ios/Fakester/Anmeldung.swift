import SwiftUI

/// Anmelden oder als Gast spielen - aufgebaut wie #auth-screen im Browser:
/// eine grosse Glaskarte mit Logo, Unterzeile und den drei Wegen ins Spiel.
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
            VStack(spacing: 18) {
                AktualisierungsKarte()
                    .padding(.top, 20)

                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Schriftzug(groesse: 46)
                        Text(L("Rate den Song. Schlag die Crew.", "Guess the song. Beat the crew."))
                            .font(.marke(13))
                            .foregroundColor(Farbe.gedaempft)
                    }
                    kontoTeil
                    Trenner(text: L("ODER", "OR"))
                    gastTeil
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .background(Glas(radius: 32))
                .padding(.top, 28)

                Text(L("Mit dem Spielen akzeptierst du unsere Bedingungen & den Datenschutz.",
                       "By playing you accept our Terms & Privacy."))
                    .font(.marke(11))
                    .foregroundColor(Farbe.leise)
                    .multilineTextAlignment(.center)

                SprachKnopf()
                    .font(.marke(13, .semibold))
                    .foregroundColor(Farbe.gedaempft)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var kontoTeil: some View {
        VStack(spacing: 12) {
            Feld(text: $name, platzhalter: L("Benutzername", "Username"))
                .textContentType(.username)
            Feld(text: $passwort, platzhalter: L("Passwort", "Password"), geheim: true)
                .textContentType(neuesKonto ? .newPassword : .password)

            if let fehler {
                Text(fehler)
                    .font(.marke(13, .medium))
                    .foregroundColor(Farbe.schlecht)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(neuesKonto ? L("Konto anlegen", "Create account") : L("Anmelden", "Log in")) { los() }
                .buttonStyle(Hauptknopf(aus: !bereit || laeuft))
                .disabled(!bereit || laeuft)

            Button(neuesKonto ? L("Ich habe schon ein Konto", "I already have an account")
                              : L("Noch kein Konto? Anlegen", "No account yet? Create one")) {
                withAnimation { neuesKonto.toggle(); fehler = nil }
            }
            .font(.marke(13, .semibold))
            .foregroundColor(Farbe.akzent)
        }
    }

    private var gastTeil: some View {
        VStack(spacing: 12) {
            Feld(text: $gastname, platzhalter: L("Dein Name", "Your name"))

            Button(L("Als Gast spielen", "Play as guest")) {
                api.alsGast(name: gastname)
                Spuerbar.tipp()
            }
            .buttonStyle(Nebenknopf())
            .disabled(gastname.trimmingCharacters(in: .whitespaces).count < 2)
            .opacity(gastname.trimmingCharacters(in: .whitespaces).count < 2 ? 0.5 : 1)

            Text(L("XP, Spots und Gegenstände gehören zu einem Konto.",
                   "XP, Spots and items need an account."))
                .font(.marke(12))
                .foregroundColor(Farbe.leise)
                .multilineTextAlignment(.center)
        }
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

/// Linie - Wort - Linie.
struct Trenner: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Farbe.kante).frame(height: 1)
            Text(text).etikett()
            Rectangle().fill(Farbe.kante).frame(height: 1)
        }
    }
}

/// Ein Eingabefeld wie im Browser: dunkel, feine Kante, mit Fokus lila Ring.
/// Die eingebauten Felder von SwiftUI bringen eine helle Umrandung mit, die
/// hier fehl am Platz waere.
struct Feld: View {
    @Binding var text: String
    let platzhalter: String
    var geheim = false
    var nurZiffern = false
    var mono = false

    @FocusState private var fokus: Bool

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Group {
            if geheim {
                SecureField("", text: $text, prompt: wink)
            } else {
                TextField("", text: $text, prompt: wink)
            }
        }
        .focused($fokus)
        .font(mono ? .mono(22) : .marke(16, .medium))
        .tracking(mono ? 4 : 0)
        .foregroundColor(Farbe.schrift)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(nurZiffern ? .numberPad : .default)
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(form.fill(fokus ? Farbe.grund4 : Farbe.grund3))
        .overlay(form.strokeBorder(fokus ? Farbe.akzentTief : Farbe.linie, lineWidth: 1.5))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Farbe.akzent.opacity(fokus ? 0.14 : 0), lineWidth: 4)
                .padding(-3)
        )
        .animation(.easeOut(duration: 0.18), value: fokus)
    }

    private var wink: Text {
        Text(platzhalter).foregroundColor(Farbe.leise)
    }
}

/// Startbildschirm, sobald klar ist, wer spielt - wie .home im Browser:
/// Profil oben, grosses Logo, zwei Spielknoepfe, darunter die Bubbles.
struct DaheimAnsicht: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var spiel: Spiel

    @State private var pin = ""
    @State private var beitreten = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                kopf
                    .padding(.bottom, 12)

                AktualisierungsKarte()

                VStack(spacing: 36) {
                    Schriftzug(groesse: 56)
                        .padding(.top, 24)
                    spielknoepfe
                    bubbles
                }
                .padding(.vertical, 20)

                fuss
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Kopf (.home-header)

    private var kopf: some View {
        HStack(spacing: 10) {
            ProfilChip()
            Spacer(minLength: 0)
            if let s = api.ich?.spots {
                HStack(spacing: 5) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Farbe.gold)
                    Text("\(s)")
                        .font(.mono(13))
                        .foregroundColor(Farbe.schrift)
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Glas(radius: 999))
            }
        }
    }

    // MARK: Spielknoepfe (.home-play-btns)

    private var spielknoepfe: some View {
        VStack(spacing: 10) {
            Button {
                Spuerbar.tipp()
                spiel.meldung = L("Spiel erstellen gibt's bisher nur im Browser.", "Creating a game is browser-only for now.")
            } label: {
                Label(L("Spiel erstellen", "Create game"), systemImage: "plus")
            }
            .buttonStyle(Hauptknopf())

            Button {
                Spuerbar.tipp()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { beitreten.toggle() }
            } label: {
                Label(L("Spiel beitreten", "Join game"), systemImage: "arrow.right.circle")
            }
            .buttonStyle(Nebenknopf())

            if beitreten {
                pinKarte
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 6)
    }

    private var pinKarte: some View {
        Karte {
            VStack(spacing: 12) {
                Text(L("LOBBY-PIN", "LOBBY PIN")).etikett()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Feld(text: $pin, platzhalter: "PIN", nurZiffern: true, mono: true)
                Button(L("Beitreten", "Join")) {
                    guard let a = api.ausweis else { return }
                    Spuerbar.tipp()
                    spiel.betreten(pin: pin, als: a)
                }
                .buttonStyle(Hauptknopf(aus: pin.count < 4))
                .disabled(pin.count < 4)
            }
        }
    }

    // MARK: Bubbles (.home-nav-bubbles)

    private var bubbles: some View {
        let spalten: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return LazyVGrid(columns: spalten, spacing: 10) {
            ForEach(HeimZiel.alle) { ziel in
                Bubble(ziel: ziel) {
                    Spuerbar.tipp()
                    spiel.meldung = L("\(ziel.name) gibt's bisher nur im Browser.", "\(ziel.name) is browser-only for now.")
                }
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: Fuss

    private var fuss: some View {
        VStack(spacing: 10) {
            HStack(spacing: 24) {
                Button("Feedback") {
                    NotificationCenter.default.post(name: .geschuettelt, object: nil)
                }
                Button(api.angemeldet ? L("Abmelden", "Log out") : L("Anderer Name", "Change name")) {
                    api.abmelden()
                }
                SprachKnopf()
            }
            .font(.marke(13, .semibold))
            .foregroundColor(Farbe.gedaempft)
            Text(L("Tipp: Handy schütteln schickt auch Feedback.", "Tip: shake your phone to send feedback too."))
                .font(.marke(11))
                .foregroundColor(Farbe.leise)
        }
        .padding(.top, 12)
    }
}

/// .profile-chip: rundes Lila-Symbol, Name, darunter XP oder "Gast".
struct ProfilChip: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Farbe.akzentTief, Color(hex: 0x5A298B)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                if let e = api.ich?.equipped_emoji, !e.isEmpty {
                    Text(e).font(.system(size: 16))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Farbe.aufAkzent)
                }
            }
            .frame(width: 34, height: 34)
            .shadow(color: Farbe.akzent.opacity(0.36), radius: 6)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(api.ausweis?.username ?? "")
                        .font(.marke(14, .heavy))
                        .foregroundColor(Farbe.schrift)
                        .lineLimit(1)
                    if api.ich?.is_pro == true { Marke(text: "PRO", farbe: Farbe.gold) }
                }
                Text(unterzeile)
                    .font(.marke(11, .semibold))
                    .foregroundColor(Farbe.gedaempft)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .background(Glas(radius: 999))
    }

    private var unterzeile: String {
        if api.ausweis?.isGuest ?? true { return L("Gast", "Guest") }
        if let xp = api.ich?.xp { return "\(xp) XP" }
        return L("Konto", "Account")
    }
}

/// Kleines Abzeichen (PRO, GAST ...).
struct Marke: View {
    let text: String
    var farbe: Color = Farbe.akzent

    var body: some View {
        Text(text)
            .font(.marke(9, .heavy))
            .tracking(0.6)
            .foregroundColor(Farbe.grund)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(farbe, in: Capsule())
    }
}

/// Ein Ziel auf dem Startbildschirm. Wie im Browser - die meisten fuehren in
/// der App noch nirgends hin.
struct HeimZiel: Identifiable {
    let id: String
    let name: String
    let symbol: String

    static var alle: [HeimZiel] {
        [
            HeimZiel(id: "shop", name: "Shop", symbol: "bag.fill"),
            HeimZiel(id: "style", name: "Style", symbol: "paintpalette.fill"),
            HeimZiel(id: "path", name: L("Pfad", "Path"), symbol: "map.fill"),
            HeimZiel(id: "board", name: L("Rangliste", "Leaderboard"), symbol: "trophy.fill"),
            HeimZiel(id: "friends", name: L("Freunde", "Friends"), symbol: "person.2.fill"),
            HeimZiel(id: "playlists", name: "Playlists", symbol: "music.note.list"),
            HeimZiel(id: "quests", name: "Quests", symbol: "scroll.fill"),
            HeimZiel(id: "awards", name: L("Erfolge", "Awards"), symbol: "rosette")
        ]
    }
}

/// .nav-bubble: quadratisch, Glas, Symbol ueber kleinem Wort.
struct Bubble: View {
    let ziel: HeimZiel
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            VStack(spacing: 6) {
                Image(systemName: ziel.symbol)
                    .font(.system(size: 20))
                    .foregroundColor(Farbe.gedaempft)
                Text(ziel.name)
                    .font(.marke(11, .bold))
                    .foregroundColor(Farbe.gedaempft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Glas(radius: 16))
        }
        .buttonStyle(BubbleDruck())
    }
}

struct BubbleDruck: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
