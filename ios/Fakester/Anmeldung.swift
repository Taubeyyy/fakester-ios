import SwiftUI
import UIKit

/// Anmelden oder als Gast spielen - aufgebaut wie der Anmeldebildschirm der
/// laufenden fakester.app (Handyformat 375×812, Oktober 2026): Balken,
/// Schriftzug mit ALPHA-Pille, "Guess the song. Beat the crew.", darunter die
/// grosse Karte ("Play now" bzw. Namensfeld, "or", Sign in mit Umschalter,
/// Felder, "Log in", Hinweis), die Public-alpha-Karte und der Fuss.
struct AnmeldeAnsicht: View {
    @EnvironmentObject private var api: Api

    @State private var name = ""
    @State private var passwort = ""
    @State private var wiederholung = ""
    @State private var gastname = ""
    @State private var neuesKonto = false
    /// "Play now" gedrueckt: statt des Knopfs steht das Namensfeld da.
    @State private var gastModus = false
    @State private var zeigen = false
    @State private var laeuft = false
    @State private var fehler: String?
    /// Im Browser bleibt die Karte nach dem ersten Antippen im Hover-Zustand
    /// (kraeftigerer Rand und Schein) - Safari auf dem iPhone loest beim Tippen
    /// mouseenter aus. Genau so sieht man sie dort nach "Play now".
    @State private var beruehrt = false
    @State private var live: LiveZahlen?
    @FocusState private var fokus: KontoFokus?
    @FocusState private var gastFokus: Bool

    /// Der "create one"-Verweis im Hinweistext fuehrt hierhin und bleibt in der App.
    private static let verweisSchema = "fakester-anmeldung"

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    AktualisierungsKarte()
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    // Wie im Browser nur, wenn wirklich jemand online ist.
                    if let z = live, z.players > 0 {
                        OnlineKapsel(live: z)
                            .padding(.top, 20)
                            .padding(.horizontal, 16)
                    }
                    hauptteil
                        .frame(maxWidth: 400)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                    fuss
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            // Der Browser fragt alle 25 Sekunden nach.
            while !Task.isCancelled {
                if let z: LiveZahlen = try? await api.holen("/stats/live") { live = z }
                try? await Task.sleep(nanoseconds: 25_000_000_000)
            }
        }
        .onChange(of: fokus) { neu in
            if neu != nil { anfassen() }
        }
        .onChange(of: gastname) { neu in
            // maxLength 20 wie im Browser
            if neu.count > 20 { gastname = String(neu.prefix(20)) }
        }
    }

    // MARK: Aufbau

    private var hauptteil: some View {
        VStack(spacing: 0) {
            kopf
            anmeldeKarte
            AlphaKarte()
                .padding(.top, 16)
        }
    }

    /// Balken, Schriftzug, ALPHA, Unterzeile. Die Pille steht im Browser neben
    /// dem Schriftzug, wenn beides in die Breite passt (ab 390 pt), sonst
    /// rutscht sie darunter (flex-wrap) - das bildet ViewThatFits nach.
    private var kopf: some View {
        VStack(spacing: 0) {
            AnmeldeBalken()
                .padding(.bottom, 16)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    AnmeldeLogo()
                    AlphaPille(text: "ALPHA")
                        .padding(.top, 6)
                }
                VStack(spacing: 8) {
                    AnmeldeLogo()
                    AlphaPille(text: "ALPHA")
                        .padding(.top, 6)
                }
            }
            .padding(.bottom, 12)
            unterzeile
                .padding(.bottom, 24)
        }
    }

    private var unterzeile: some View {
        let vorne: Text = Text(L("Rate den Song. ", "Guess the song. "))
            .foregroundColor(Farbe.leise)
        let hinten: Text = Text(L("Schlag die Crew.", "Beat the crew."))
            .font(.marke(17, .semibold))
            .foregroundColor(Farbe.schrift)
        return (vorne + hinten)
            .font(.marke(17))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 26)
    }

    private var anmeldeKarte: some View {
        VStack(alignment: .leading, spacing: 0) {
            if gastModus {
                gastZeile
                    .transition(.opacity)
            } else {
                playKnopf
                    .transition(.opacity)
            }
            Trenner(text: L("oder", "or"))
                .padding(.vertical, 16)
            kontoKopf
                .padding(.bottom, 20)
            umschalter
                .padding(.bottom, 16)
            felder
            hinweis
                .padding(.top, 16)
        }
        // 20 Polster + 1 Rand
        .padding(21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnmeldeKartenGrund(aktiv: beruehrt))
    }

    // MARK: Als Gast

    private var playKnopf: some View {
        Button {
            Spuerbar.tipp()
            anfassen()
            withAnimation(.easeOut(duration: 0.2)) {
                gastModus = true
                fehler = nil
            }
            // autoFocus wie im Browser
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                gastFokus = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play")
                    .font(.system(size: 12, weight: .medium))
                Text(L("Jetzt spielen", "Play now"))
            }
        }
        .buttonStyle(LilaKnopf(schrift: 14, hoehe: 49))
    }

    private var gastZeile: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let bereit: Bool = gastname.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Farbe.gedaempft)
                        .frame(width: 14, height: 14)
                    TextField("", text: $gastname,
                              prompt: Text(L("Wähl einen Namen…", "Pick a name…")).foregroundColor(Farbe.leise))
                        .font(.marke(14))
                        .foregroundColor(Farbe.schrift)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.sentences)
                        .focused($gastFokus)
                        .submitLabel(.go)
                        .onSubmit { gastLos() }
                }
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity)
                .frame(height: 47)
                .background(form.fill(AnmeldeFarbe.gastFeld))
                .overlay(form.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))

                Button {
                    gastLos()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white)
                        .frame(width: 55, height: 47)
                        .background(form.fill(Farbe.akzent))
                }
                .buttonStyle(SanfterDruck())
                .disabled(!bereit)
                .opacity(bereit ? 1 : 0.5)
            }

            Button {
                anfassen()
                withAnimation(.easeOut(duration: 0.2)) {
                    gastModus = false
                    fehler = nil
                }
            } label: {
                Text(L("Zurück zur Anmeldung", "Back to logging in"))
                    .font(.marke(11, .medium))
                    .foregroundColor(Farbe.gedaempft)
                    .frame(height: 17)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Mit Konto

    private var kontoKopf: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.right.to.line")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Farbe.gedaempft)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.06)))
            VStack(alignment: .leading, spacing: 0) {
                Text(neuesKonto ? L("Konto anlegen", "Create account") : L("Anmelden", "Sign in"))
                    .font(.marke(17, .heavy))
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)
                    .frame(height: 21)
                Text(neuesKonto ? L("behält deine XP, Spots und Gegenstände", "keeps your XP, Spots and items")
                                : L("mit deinem fakester.app-Konto", "with your fakester.app account"))
                    .font(.marke(11))
                    .foregroundColor(Farbe.gedaempft)
                    .lineLimit(1)
                    .frame(height: 17)
            }
        }
    }

    private var umschalter: some View {
        HStack(spacing: 4) {
            reiter(L("Anmelden", "Sign in"), an: !neuesKonto) { modus(false) }
            reiter(L("Konto anlegen", "Create account"), an: neuesKonto) { modus(true) }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    private func reiter(_ titel: String, an: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(titel)
                .font(.marke(12, .bold))
                .foregroundColor(an ? Color.white : Farbe.gedaempft)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Capsule().fill(an ? Farbe.akzent : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: an)
    }

    private var felder: some View {
        VStack(alignment: .leading, spacing: 12) {
            KontoFeld(titel: L("Benutzername", "Username"),
                      symbol: "person",
                      platzhalter: L("Dein Benutzername", "Your username"),
                      text: $name,
                      art: .name,
                      fokus: $fokus,
                      inhalt: UITextContentType.username,
                      abschicken: { los() })
            KontoFeld(titel: L("Passwort", "Password"),
                      symbol: "lock",
                      platzhalter: neuesKonto ? L("Mindestens 8 Zeichen", "At least 8 characters")
                                              : L("Dein Passwort", "Your password"),
                      text: $passwort,
                      art: .passwort,
                      fokus: $fokus,
                      inhalt: neuesKonto ? UITextContentType.newPassword : UITextContentType.password,
                      verdeckt: !zeigen,
                      auge: zeigen,
                      augeTipp: { zeigen.toggle(); anfassen() },
                      abschicken: { los() })
            if neuesKonto {
                KontoFeld(titel: L("Passwort wiederholen", "Repeat password"),
                          symbol: "lock",
                          platzhalter: L("Noch einmal", "Once more"),
                          text: $wiederholung,
                          art: .wiederholung,
                          fokus: $fokus,
                          inhalt: UITextContentType.newPassword,
                          verdeckt: !zeigen,
                          abschicken: { los() })
                    .transition(.opacity)
            }
            if let f = fehler {
                fehlerKasten(f)
                    .transition(.opacity)
            }
            Button {
                los()
            } label: {
                loginBeschriftung
            }
            .buttonStyle(LilaKnopf(schrift: 15, hoehe: 51))
            .opacity(laeuft ? 0.65 : 1)
            .disabled(laeuft)
            .padding(.top, 4)
        }
    }

    private func fehlerKasten(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .medium))
                .padding(.top, 2)
            Text(text)
                .font(.marke(12, .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(Farbe.schlecht)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0xEF4444).opacity(0.12)))
    }

    @ViewBuilder
    private var loginBeschriftung: some View {
        if laeuft {
            HStack(spacing: 8) {
                Drehkreis()
                Text(L("Prüfe…", "Checking…"))
            }
        } else if neuesKonto {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                Text(L("Konto anlegen", "Create account"))
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 13, weight: .medium))
                Text(L("Einloggen", "Log in"))
            }
        }
    }

    // MARK: Hinweis

    private var hinweis: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "headphones")
                .font(.system(size: 11, weight: .regular))
                .frame(width: 13, height: 13)
                .opacity(0.6)
                .padding(.top, 2)
            hinweisText
                .font(.marke(11))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == AnmeldeAnsicht.verweisSchema {
                        modus(true)
                        return .handled
                    }
                    return .systemAction
                })
        }
        .foregroundColor(Farbe.gedaempft)
    }

    private var hinweisText: Text {
        if gastModus {
            return Text(L("Du kannst alles als Gast spielen. XP, Spots und Gegenstände brauchen ein Konto – und das kannst du jederzeit anlegen, ohne deinen Namen zu verlieren.",
                          "You can play everything as a guest. XP, Spots and items need an account — and you can make one any time without losing your name."))
        }
        if neuesKonto {
            return Text(L("Unter deinem Namen sehen dich die anderen. Nimm einen, den du behalten willst – ändern kostet später Spots.",
                          "Your name is how other players see you. Pick something you want to keep — changing it later costs Spots."))
        }
        return Text(kontoHinweis)
    }

    /// "… or create one to keep …" - "create one" ist im Browser ein Knopf in
    /// 16 pt, fett und lila, mitten im 11-pt-Text.
    private var kontoHinweis: AttributedString {
        var ganz = AttributedString(L("Noch kein Konto? Du kannst sofort als Gast spielen, oder ",
                                      "No account yet? You can play as a guest right away, or "))
        var verweis = AttributedString(L("leg eins an", "create one"))
        verweis[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font.marke(16, .semibold)
        verweis[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Farbe.akzent
        verweis[AttributeScopes.FoundationAttributes.LinkAttribute.self] = URL(string: AnmeldeAnsicht.verweisSchema + "://konto")
        ganz.append(verweis)
        ganz.append(AttributedString(L(" und behalte deine XP, Spots und Gegenstände.",
                                       " to keep your XP, Spots and items.")))
        return ganz
    }

    // MARK: Fuss

    private var fuss: some View {
        let jahr: Int = Calendar.current.component(.year, from: Date())
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return HStack(spacing: 16) {
            Text(verbatim: "© \(jahr) Fakester")
            Rectangle()
                .fill(Farbe.linie)
                .frame(width: 1, height: 12)
            Text(verbatim: "ALPHA · v\(version)")
        }
        .font(.marke(11))
        .foregroundColor(Farbe.leise)
        .frame(height: 17)
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
    }

    // MARK: Ablauf

    private func anfassen() {
        guard !beruehrt else { return }
        withAnimation(.easeOut(duration: 0.3)) { beruehrt = true }
    }

    private func modus(_ registrieren: Bool) {
        Spuerbar.tipp()
        anfassen()
        withAnimation(.easeOut(duration: 0.2)) {
            neuesKonto = registrieren
            fehler = nil
        }
    }

    private func zeigeFehler(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) { fehler = text }
    }

    /// Wie im Browser: Steuerzeichen und <> raus, Leerraum zusammenziehen,
    /// hoechstens 20 Zeichen, mindestens 2.
    private func gastLos() {
        let sauber: String = AnmeldeAnsicht.sauberName(gastname)
        guard sauber.count >= 2 else {
            zeigeFehler(L("Mindestens 2 Zeichen", "At least 2 characters"))
            Spuerbar.falsch()
            return
        }
        fehler = nil
        Spuerbar.tipp()
        api.alsGast(name: sauber)
    }

    private static func sauberName(_ roh: String) -> String {
        let ohne: String = roh.replacingOccurrences(of: "[\\u0000-\\u001f\\u007f\\u200b-\\u200f\\u2028\\u2029<>]",
                                                    with: "", options: .regularExpression)
        let eng: String = ohne.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let rand: String = eng.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(rand.prefix(20))
    }

    /// Dieselben Pruefungen und Meldungen wie im Browser - der Knopf ist dort
    /// nie gesperrt, sondern sagt, was fehlt.
    private func los() {
        guard !laeuft else { return }
        anfassen()
        let n: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !passwort.isEmpty else {
            zeigeFehler(L("Gib Benutzername und Passwort ein", "Enter your username and password"))
            Spuerbar.falsch()
            return
        }
        let registrieren: Bool = neuesKonto
        if registrieren {
            var problem: String?
            if n.count < 3 || n.count > 20 {
                problem = L("Benutzername: 3–20 Zeichen", "Username: 3-20 characters")
            } else if n.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) == nil {
                problem = L("Nur Buchstaben, Ziffern und _", "Letters, numbers and _ only")
            } else if passwort.count < 8 {
                problem = L("Passwort: mindestens 8 Zeichen", "Password: at least 8 characters")
            } else if passwort != wiederholung {
                problem = L("Die beiden Passwörter stimmen nicht überein", "The two passwords do not match")
            }
            if let p = problem {
                zeigeFehler(p)
                Spuerbar.falsch()
                return
            }
        }
        let pw: String = passwort
        laeuft = true
        fehler = nil
        Task {
            do {
                if registrieren {
                    try await api.registrieren(name: n, passwort: pw)
                } else {
                    try await api.anmelden(name: n, passwort: pw)
                }
                Spuerbar.richtig()
            } catch {
                let meldung: String = error.localizedDescription
                let ersatz: String = registrieren ? L("Konto konnte nicht angelegt werden", "Could not create the account")
                                                  : L("Anmeldung fehlgeschlagen", "Login failed")
                zeigeFehler(meldung.isEmpty ? ersatz : meldung)
                Spuerbar.falsch()
            }
            laeuft = false
        }
    }
}

// MARK: - Bausteine der Anmeldung

/// Werte aus dem Browser, die es in `Farbe` nicht gibt.
private enum AnmeldeFarbe {
    static let karte      = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.94)
    static let alphaKarte = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.72)
    static let kapsel     = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.88)
    static let chip       = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    static let feld       = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.72)
    static let feldFokus  = Color(.sRGB, red: 14 / 255, green: 12 / 255, blue: 28 / 255, opacity: 0.85)
    static let gastFeld   = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)
    /// Platzhalter ohne eigene Farbe: Schriftfarbe zur Haelfte (Tailwind-Vorgabe).
    static let platzhalter = Color(.sRGB, red: 238 / 255, green: 238 / 255, blue: 1, opacity: 0.5)
    static let hellLila   = Color(hex: 0xB0AED2)
    /// --acc-pale zu #b15cff
    static let blass      = Color(hex: 0xCC95FF)
    static let perle      = Color(hex: 0xF59E0B)
    static let perlenRand = Color(hex: 0x181727)
    static let discordGrund = Color(.sRGB, red: 88 / 255, green: 101 / 255, blue: 242 / 255, opacity: 0.16)
    static let discordRand  = Color(.sRGB, red: 88 / 255, green: 101 / 255, blue: 242 / 255, opacity: 0.4)
    static let discordText  = Color(hex: 0xC7CCFF)
}

private enum KontoFokus: Hashable {
    case name, passwort, wiederholung
}

/// Der Grund der Anmeldekarte: rgba(24,23,39,.94), Rand --acc 22 %, Ecken 24,
/// Schatten 0 24 60 schwarz .55 und lila Schein 0 0 60 --acc-deep 10 %.
/// Angetippt: Rand 38 %, Schatten 0 28 74 / .62, Schein 0 0 96 / 24 %.
private struct AnmeldeKartenGrund: View {
    let aktiv: Bool

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let schatten: Color = Color.black.opacity(aktiv ? 0.62 : 0.55)
        let schein: Color = Farbe.akzentTief.opacity(aktiv ? 0.24 : 0.1)
        ZStack {
            form.fill(AnmeldeFarbe.karte)
                .shadow(color: schatten, radius: aktiv ? 37 : 30, x: 0, y: aktiv ? 28 : 24)
                .shadow(color: schein, radius: aktiv ? 48 : 30, x: 0, y: 0)
            form.strokeBorder(Farbe.akzent.opacity(aktiv ? 0.38 : 0.22), lineWidth: 1)
            Lichtkante(radius: 24, staerke: aktiv ? 0.08 : 0.05)
        }
        .animation(.easeOut(duration: 0.3), value: aktiv)
    }
}

/// "Play now" / "Log in": flaches --acc, weiss fett, Ecken 16,
/// Schein 0 0 28 --acc-deep 35 %, heller Strich oben.
private struct LilaKnopf: ButtonStyle {
    var schrift: CGFloat = 14
    var hoehe: CGFloat = 49

    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return configuration.label
            .font(.marke(schrift, .bold))
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: hoehe)
            .background(
                form.fill(Farbe.akzent)
                    .shadow(color: Farbe.akzentTief.opacity(0.35), radius: 14, x: 0, y: 0)
            )
            .overlay(Lichtkante(radius: 16, staerke: 0.15))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// whileTap scale .97
private struct SanfterDruck: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Rahmen der Eingabefelder wie im Browser: rgba(10,9,20,.72), Rand weiss 8 %,
/// Ecken 16, 14 Polster; mit Fokus dunkler, Rand --acc 55 % und ein 3-pt-Ring
/// --acc 12 % aussen herum.
private struct WebFeldRahmen: ViewModifier {
    let aktiv: Bool

    func body(content: Content) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let grund: Color = aktiv ? AnmeldeFarbe.feldFokus : AnmeldeFarbe.feld
        let rand: Color = aktiv ? Farbe.akzent.opacity(0.55) : Color.white.opacity(0.08)
        return content
            .padding(.horizontal, 14)
            .frame(height: 49)
            .background(form.fill(grund))
            .overlay(form.strokeBorder(rand, lineWidth: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 17.5, style: .continuous)
                    .stroke(Farbe.akzent.opacity(aktiv ? 0.12 : 0), lineWidth: 3)
                    .padding(-1.5)
                    .allowsHitTesting(false)
            )
            .animation(.easeOut(duration: 0.18), value: aktiv)
    }
}

/// Feld mit Etikett darueber (USERNAME / PASSWORD), Symbol links und beim
/// Passwort dem Auge rechts. Etikett und Symbol werden mit Fokus lila.
private struct KontoFeld: View {
    let titel: String
    let symbol: String
    let platzhalter: String
    @Binding var text: String
    let art: KontoFokus
    var fokus: FocusState<KontoFokus?>.Binding
    var inhalt: UITextContentType? = nil
    var verdeckt: Bool = false
    /// nil: kein Auge. Sonst: ob das Passwort gerade sichtbar ist.
    var auge: Bool? = nil
    var augeTipp: () -> Void = {}
    var abschicken: () -> Void = {}

    var body: some View {
        let aktiv: Bool = fokus.wrappedValue == art
        VStack(alignment: .leading, spacing: 6) {
            Text(titel.uppercased())
                .font(.marke(10, .bold))
                .tracking(1)
                .foregroundColor(aktiv ? Farbe.akzent : Farbe.gedaempft)
                .lineLimit(1)
                .frame(height: 15)
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(aktiv ? Farbe.akzent : Farbe.gedaempft)
                    .frame(width: 15, height: 15)
                eingabe
                if let offen = auge {
                    Button(action: augeTipp) {
                        Image(systemName: offen ? "eye.slash" : "eye")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Farbe.gedaempft)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, -7.5)
                    .accessibilityLabel(offen ? L("Passwort verbergen", "Hide password")
                                              : L("Passwort zeigen", "Show password"))
                }
            }
            .modifier(WebFeldRahmen(aktiv: aktiv))
            .animation(.easeOut(duration: 0.18), value: aktiv)
        }
    }

    private var eingabe: some View {
        Group {
            if verdeckt {
                SecureField("", text: $text, prompt: wink)
            } else {
                TextField("", text: $text, prompt: wink)
            }
        }
        .font(.marke(15))
        .foregroundColor(Farbe.schrift)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .textContentType(inhalt)
        .focused(fokus, equals: art)
        .submitLabel(.go)
        .onSubmit { abschicken() }
        .frame(maxWidth: .infinity)
    }

    private var wink: Text {
        Text(platzhalter).foregroundColor(AnmeldeFarbe.platzhalter)
    }
}

/// Die neun Balken ueber dem Schriftzug (Groesse 1.4): je 4,2 pt breit,
/// 3 pt Abstand, --acc 55 %, wippen mit eigener Dauer zwischen voller Hoehe
/// und 22 % (@keyframes eq).
private struct AnmeldeBalken: View {
    @State private var an = false
    private let hoehen: [CGFloat] = [8, 14, 10, 18, 12, 16, 9, 13, 11]
    private let dauern: [Double] = [0.55, 0.40, 0.70, 0.45, 0.60, 0.50, 0.65, 0.42, 0.58]
    private let verzuege: [Double] = [0.00, 0.08, 0.04, 0.12, 0.06, 0.10, 0.02, 0.14, 0.07]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<9, id: \.self) { i in
                balken(i)
            }
        }
        .frame(height: 28, alignment: .bottom)
        .onAppear { an = true }
    }

    private func balken(_ i: Int) -> some View {
        let h: CGFloat = hoehen[i] * 1.4
        let halbe: Double = dauern[i] / 2
        return Capsule()
            .fill(Farbe.akzent.opacity(0.55))
            .frame(width: 4.2, height: h)
            .scaleEffect(x: 1, y: an ? 0.22 : 1, anchor: .bottom)
            .animation(.easeInOut(duration: halbe).repeatForever(autoreverses: true).delay(verzuege[i]), value: an)
    }
}

/// FAKESTER in 52 pt (800), -0,045 em: FAKE #f4f3ff mit weissem Schein,
/// STER --acc mit lila Schein (text-shadow 0 0 60px).
private struct AnmeldeLogo: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("FAKE")
                .foregroundColor(Color(hex: 0xF4F3FF))
                .shadow(color: Color.white.opacity(0.18), radius: 30)
            Text("STER")
                .foregroundColor(Farbe.akzent)
                .shadow(color: Farbe.akzent.opacity(0.55), radius: 30)
        }
        .font(.marke(52, .heavy))
        .tracking(-2.34)
        .lineLimit(1)
        .fixedSize()
        .frame(height: 52)
    }
}

/// ALPHA / PUBLIC ALPHA: 10 pt fett, 1,5 pt gesperrt, --acc auf --acc 10 %,
/// Rand --acc 30 %, Pille 21 hoch.
private struct AlphaPille: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.marke(10, .bold))
            .tracking(1.5)
            .foregroundColor(Farbe.akzent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(height: 21)
            .background(Capsule().fill(Farbe.akzent.opacity(0.1)))
            .overlay(Capsule().strokeBorder(Farbe.akzent.opacity(0.3), lineWidth: 1))
    }
}

/// Die kleine Karte unter der Anmeldung: PUBLIC ALPHA, Text, Discord.
private struct AlphaKarte: View {
    @Environment(\.openURL) private var oeffnen

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            AlphaPille(text: L("Öffentliche Alpha", "Public alpha"))
                .padding(.bottom, 6)
            Text(L("Songs fehlen, Runden brechen ab, Dinge wandern herum. So ist eine Alpha eben. Wenn sich etwas falsch anfühlt, sag es uns – so wird es repariert.",
                   "Songs go missing, rounds break, things move around. That is what an alpha is. If something feels wrong, tell us — that is how it gets fixed."))
                .font(.marke(12))
                .foregroundColor(AnmeldeFarbe.hellLila)
                .lineSpacing(2.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
            discordKnopf
        }
        // 16 Polster + 1 Rand
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(form.fill(AnmeldeFarbe.alphaKarte))
        .overlay(form.strokeBorder(Farbe.kante, lineWidth: 1))
    }

    private var discordKnopf: some View {
        let form = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button {
            Spuerbar.tipp()
            if let url = URL(string: "https://discord.gg/4s6Mdy7hjN") { oeffnen(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "message")
                    .font(.system(size: 12, weight: .medium))
                Text(L("Zum Discord", "Join the Discord"))
                    .font(.marke(13, .bold))
            }
            .foregroundColor(AnmeldeFarbe.discordText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(form.fill(AnmeldeFarbe.discordGrund))
            .overlay(form.strokeBorder(AnmeldeFarbe.discordRand, lineWidth: 1))
        }
        .buttonStyle(SanfterDruck())
    }
}

/// "● 3 online | 1 lobbies" ganz oben, nur wenn jemand online ist:
/// Pille rgba(24,23,39,.88), Rand --border, 12 pt, Zahlen fett und hell.
private struct OnlineKapsel: View {
    let live: LiveZahlen

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                PingPunkt()
                (Text(verbatim: live.players.formatted())
                    .font(.marke(12, .semibold))
                    .foregroundColor(Farbe.schrift)
                 + Text(verbatim: " online"))
            }
            if live.lobbies > 0 {
                Rectangle()
                    .fill(Farbe.linie)
                    .frame(width: 1, height: 12)
                (Text(verbatim: live.lobbies.formatted())
                    .font(.marke(12, .semibold))
                    .foregroundColor(Farbe.schrift)
                 + Text(L(" Lobbys", " lobbies")))
            }
        }
        .font(.marke(12, .medium))
        .foregroundColor(Farbe.leise)
        .lineLimit(1)
        .padding(.horizontal, 21)
        .frame(height: 40)
        .background(
            Capsule()
                .fill(AnmeldeFarbe.kapsel)
                .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 4)
        )
        .overlay(Capsule().strokeBorder(Farbe.linie, lineWidth: 1))
        .overlay(Lichtkante(radius: 20, staerke: 0.05))
    }
}

/// Der Punkt mit animate-ping: ein zweiter Punkt waechst auf das Doppelte und verblasst.
private struct PingPunkt: View {
    @State private var an = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Farbe.akzent)
                .scaleEffect(an ? 2 : 1)
                .opacity(an ? 0 : 0.7)
                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: an)
            Circle()
                .fill(Farbe.akzent)
        }
        .frame(width: 6, height: 6)
        .onAppear { an = true }
    }
}

/// Der Kreisel auf "Checking…": 14 pt, 2 pt Rand, oben offen, 0,7 s je Umdrehung.
private struct Drehkreis: View {
    @State private var dreht = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(dreht ? 360 : 0))
            .animation(.linear(duration: 0.7).repeatForever(autoreverses: false), value: dreht)
            .frame(width: 14, height: 14)
            .onAppear { dreht = true }
    }
}

// MARK: - Geteilte Bausteine

/// Linie - Wort - Linie (wie "or" im Browser: 10 pt fett, gesperrt, #8d8ba4,
/// Linien in --border, 12 pt Abstand).
struct Trenner: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Farbe.linie).frame(height: 1)
            Text(text.uppercased())
                .etikett()
                .lineLimit(1)
                .fixedSize()
            Rectangle().fill(Farbe.linie).frame(height: 1)
        }
        .frame(height: 15)
    }
}

/// Ein Eingabefeld wie im Browser: rgba(10,9,20,.72), Rand weiss 8 %, Ecken 16,
/// 49 hoch, 15 pt; mit Fokus Rand --acc 55 % und lila Ring.
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
        Group {
            if geheim {
                SecureField("", text: $text, prompt: wink)
            } else {
                TextField("", text: $text, prompt: wink)
            }
        }
        .focused($fokus)
        .font(mono ? .mono(22) : .marke(15))
        .tracking(mono ? 4 : 0)
        .foregroundColor(Farbe.schrift)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(nurZiffern ? .numberPad : .default)
        .modifier(WebFeldRahmen(aktiv: fokus))
    }

    private var wink: Text {
        Text(platzhalter).foregroundColor(AnmeldeFarbe.platzhalter)
    }
}

/// Der Profil-Chip oben links auf dem Startbildschirm wie im Browser:
/// rgba(24,23,39,.9), Rand --border, Ecken 16, Polster 6/10/6/6;
/// Avatar 32 mit Rand --acc 70 % und Schein, goldene Stufenperle unten rechts,
/// Name 13 pt fett in --acc. (Titel und PRO zeigt der Browser erst ab
/// Tablet-Breite - auf dem Handy nicht.)
struct ProfilChip: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 8) {
            avatar
                .overlay(alignment: .bottomTrailing) {
                    stufenPerle
                        .offset(x: 2, y: 2)
                }
            Text(api.ausweis?.username ?? "")
                .font(.marke(13, .bold))
                .foregroundColor(Farbe.akzent)
                .lineLimit(1)
        }
        // 6/10/6/6 Polster + 1 Rand
        .padding(.leading, 7)
        .padding(.trailing, 11)
        .padding(.vertical, 7)
        .background(form.fill(AnmeldeFarbe.chip))
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            if let url = bildURL {
                AsyncImage(url: url) { phase in
                    if let bild = phase.image {
                        bild.resizable().scaledToFill()
                    } else {
                        symbol
                    }
                }
            } else {
                symbol
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Farbe.akzent.opacity(0.7), lineWidth: 2)
                .shadow(color: Farbe.akzent.opacity(0.3), radius: 5)
        )
    }

    private var symbol: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(AnmeldeFarbe.blass)
    }

    /// Wie `<img src>` im Browser: relative Pfade gelten ab fakester.app.
    private var bildURL: URL? {
        guard let s = api.ausweis?.avatar_url, !s.isEmpty else { return nil }
        return URL(string: s, relativeTo: URL(string: "https://fakester.app/"))?.absoluteURL
    }

    /// Stufe aus den XP - Gaeste haben keine und stehen wie im Browser auf 1.
    private var stufenPerle: some View {
        Text(verbatim: "\(Api.Stufe.fuerXp(api.ich?.xp ?? 0))")
            .font(.marke(9, .heavy))
            .foregroundColor(Farbe.grund)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .frame(minWidth: 15)
            .frame(height: 15)
            .background(Capsule().fill(AnmeldeFarbe.perle))
            .overlay(Capsule().strokeBorder(AnmeldeFarbe.perlenRand, lineWidth: 2))
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


struct BubbleDruck: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
