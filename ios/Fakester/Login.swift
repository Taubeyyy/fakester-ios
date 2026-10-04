import SwiftUI
import UIKit

/// Anmelden oder als Gast spielen - aufgebaut wie der Anmeldebildschirm der
/// laufenden fakester.app (Handyformat 375×812, Oktober 2026): Balken,
/// Schriftzug mit ALPHA-Pille, "Guess the song. Beat the crew.", darunter die
/// grosse Karte ("Play now" bzw. Namensfeld, "or", Sign in mit Umschalter,
/// Felder, "Log in", Hinweis), die Public-alpha-Karte und der Fuss.
struct LoginView: View {
    @EnvironmentObject private var api: Api

    @State private var name = ""
    @State private var passwordText = ""
    @State private var passwordRepeat = ""
    @State private var guestName = ""
    @State private var creatingAccount = false
    /// "Play now" gedrueckt: statt des Knopfs steht das Namensfeld da.
    @State private var guestMode = false
    @State private var revealPassword = false
    @State private var isRunning = false
    @State private var errorMessage: String?
    /// Im Browser bleibt die Karte nach dem ersten Antippen im Hover-Zustand
    /// (kraeftigerer Rand und Schein) - Safari auf dem iPhone loest beim Tippen
    /// mouseenter aus. Genau so sieht man sie dort nach "Play now".
    @State private var touched = false
    @State private var live: LiveStats?
    @FocusState private var focus: AccountFieldID?
    @FocusState private var guestFocus: Bool

    /// Der "create one"-Verweis im Hinweistext fuehrt hierhin und bleibt in der App.
    private static let linkScheme = "fakester-anmeldung"

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    UpdateCard()
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    // Wie im Browser nur, wenn wirklich jemand online ist.
                    if let z = live, z.players > 0 {
                        OnlineCapsule(live: z)
                            .padding(.top, 20)
                            .padding(.horizontal, 16)
                    }
                    mainContent
                        .frame(maxWidth: 400)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                    footer
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
                if let z: LiveStats = try? await api.fetch("/stats/live") { live = z }
                try? await Task.sleep(nanoseconds: 25_000_000_000)
            }
        }
        .onChange(of: focus) { latest in
            if latest != nil { touchCard() }
        }
        .onChange(of: guestName) { latest in
            // maxLength 20 wie im Browser
            if latest.count > 20 { guestName = String(latest.prefix(20)) }
        }
    }

    // MARK: Aufbau

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            loginCard
            AlphaCard()
                .padding(.top, 16)
        }
    }

    /// Balken, Schriftzug, ALPHA, Unterzeile. Die Pille steht im Browser neben
    /// dem Schriftzug, wenn beides in die Breite passt (ab 390 pt), sonst
    /// rutscht sie darunter (flex-wrap) - das bildet ViewThatFits nach.
    private var header: some View {
        VStack(spacing: 0) {
            LoginBars()
                .padding(.bottom, 16)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    LoginLogo()
                    AlphaPill(text: "ALPHA")
                        .padding(.top, 6)
                }
                VStack(spacing: 8) {
                    LoginLogo()
                    AlphaPill(text: "ALPHA")
                        .padding(.top, 6)
                }
            }
            .padding(.bottom, 12)
            subtitle
                .padding(.bottom, 24)
        }
    }

    private var subtitle: some View {
        let leadingText: Text = Text("Guess the song. ")
            .foregroundColor(Palette.faint)
        let trailingText: Text = Text("Beat the crew.")
            .font(.brand(17, .semibold))
            .foregroundColor(Palette.foreground)
        return (leadingText + trailingText)
            .font(.brand(17))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 26)
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if guestMode {
                guestRow
                    .transition(.opacity)
            } else {
                playButton
                    .transition(.opacity)
            }
            LabeledDivider(text: "or")
                .padding(.vertical, 16)
            accountHeader
                .padding(.bottom, 20)
            modeSwitch
                .padding(.bottom, 16)
            fields
            hint
                .padding(.top, 16)
        }
        // 20 Polster + 1 Rand
        .padding(21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoginCardBackground(isActive: touched))
    }

    // MARK: Als Gast

    private var playButton: some View {
        Button {
            Haptics.tap()
            touchCard()
            withAnimation(.easeOut(duration: 0.2)) {
                guestMode = true
                errorMessage = nil
            }
            // autoFocus wie im Browser
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guestFocus = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play")
                    .font(.system(size: 12, weight: .medium))
                Text("Play now")
            }
        }
        .buttonStyle(PurpleButtonStyle(foreground: 14, frameHeight: 49))
    }

    private var guestRow: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let ready: Bool = guestName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Palette.subdued)
                        .frame(width: 14, height: 14)
                    TextField("", text: $guestName,
                              prompt: Text("Pick a name…").foregroundColor(Palette.faint))
                        .font(.brand(14))
                        .foregroundColor(Palette.foreground)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.sentences)
                        .focused($guestFocus)
                        .submitLabel(.go)
                        .onSubmit { startAsGuest() }
                }
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity)
                .frame(height: 47)
                .background(shape.fill(LoginPalette.guestField))
                .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))

                Button {
                    startAsGuest()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white)
                        .frame(width: 55, height: 47)
                        .background(shape.fill(Palette.accent))
                }
                .buttonStyle(GentlePressStyle())
                .disabled(!ready)
                .opacity(ready ? 1 : 0.5)
            }

            Button {
                touchCard()
                withAnimation(.easeOut(duration: 0.2)) {
                    guestMode = false
                    errorMessage = nil
                }
            } label: {
                Text("Back to logging in")
                    .font(.brand(11, .medium))
                    .foregroundColor(Palette.subdued)
                    .frame(height: 17)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Mit Konto

    private var accountHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.right.to.line")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Palette.subdued)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.06)))
            VStack(alignment: .leading, spacing: 0) {
                Text(creatingAccount ? "Create account" : "Sign in")
                    .font(.brand(17, .heavy))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                    .frame(height: 21)
                Text(creatingAccount ? "keeps your XP, Spots and items"
                                : "with your fakester.app account")
                    .font(.brand(11))
                    .foregroundColor(Palette.subdued)
                    .lineLimit(1)
                    .frame(height: 17)
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            tab("Sign in", on: !creatingAccount) { displayMode(false) }
            tab("Create account", on: creatingAccount) { displayMode(true) }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    private func tab(_ heading: String, on: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(heading)
                .font(.brand(12, .bold))
                .foregroundColor(on ? Color.white : Palette.subdued)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Capsule().fill(on ? Palette.accent : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: on)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            AccountField(heading: "Username",
                      symbol: "person",
                      placeholderText: "Your username",
                      text: $name,
                      kind: .name,
                      focus: $focus,
                      contents: UITextContentType.username,
                      submit: { proceed() })
            AccountField(heading: "Password",
                      symbol: "lock",
                      placeholderText: creatingAccount ? "At least 8 characters"
                                              : "Your password",
                      text: $passwordText,
                      kind: .passwordText,
                      focus: $focus,
                      contents: creatingAccount ? UITextContentType.newPassword : UITextContentType.password,
                      concealed: !revealPassword,
                      eye: revealPassword,
                      eyeTap: { revealPassword.toggle(); touchCard() },
                      submit: { proceed() })
            if creatingAccount {
                AccountField(heading: "Repeat password",
                          symbol: "lock",
                          placeholderText: "Once more",
                          text: $passwordRepeat,
                          kind: .passwordRepeat,
                          focus: $focus,
                          contents: UITextContentType.newPassword,
                          concealed: !revealPassword,
                          submit: { proceed() })
                    .transition(.opacity)
            }
            if let f = errorMessage {
                errorBox(f)
                    .transition(.opacity)
            }
            Button {
                proceed()
            } label: {
                loginLabel
            }
            .buttonStyle(PurpleButtonStyle(foreground: 15, frameHeight: 51))
            .opacity(isRunning ? 0.65 : 1)
            .disabled(isRunning)
            .padding(.top, 4)
        }
    }

    private func errorBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .medium))
                .padding(.top, 2)
            Text(text)
                .font(.brand(12, .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(Palette.bad)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0xEF4444).opacity(0.12)))
    }

    @ViewBuilder
    private var loginLabel: some View {
        if isRunning {
            HStack(spacing: 8) {
                Spinner()
                Text("Checking…")
            }
        } else if creatingAccount {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                Text("Create account")
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 13, weight: .medium))
                Text("Log in")
            }
        }
    }

    // MARK: Hinweis

    private var hint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "headphones")
                .font(.system(size: 11, weight: .regular))
                .frame(width: 13, height: 13)
                .opacity(0.6)
                .padding(.top, 2)
            hintText
                .font(.brand(11))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == LoginView.linkScheme {
                        displayMode(true)
                        return .handled
                    }
                    return .systemAction
                })
        }
        .foregroundColor(Palette.subdued)
    }

    private var hintText: Text {
        if guestMode {
            return Text("You can play everything as a guest. XP, Spots and items need an account — and you can make one any time without losing your name.")
        }
        if creatingAccount {
            return Text("Your name is how other players see you. Pick something you want to keep — changing it later costs Spots.")
        }
        return Text(accountHint)
    }

    /// "… or create one to keep …" - "create one" ist im Browser ein Knopf in
    /// 16 pt, fett und lila, mitten im 11-pt-Text.
    private var accountHint: AttributedString {
        var full = AttributedString("No account yet? You can play as a guest right away, or ")
        var linkText = AttributedString("create one")
        linkText[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font.brand(16, .semibold)
        linkText[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Palette.accent
        linkText[AttributeScopes.FoundationAttributes.LinkAttribute.self] = URL(string: LoginView.linkScheme + "://konto")
        full.append(linkText)
        full.append(AttributedString(" to keep your XP, Spots and items."))
        return full
    }

    // MARK: Fuss

    private var footer: some View {
        let guessYear: Int = Calendar.current.component(.year, from: Date())
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return HStack(spacing: 16) {
            Text(verbatim: "© \(guessYear) Fakester")
            Rectangle()
                .fill(Palette.border)
                .frame(width: 1, height: 12)
            Text(verbatim: "ALPHA · v\(version)")
        }
        .font(.brand(11))
        .foregroundColor(Palette.faint)
        .frame(height: 17)
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
    }

    // MARK: Ablauf

    private func touchCard() {
        guard !touched else { return }
        withAnimation(.easeOut(duration: 0.3)) { touched = true }
    }

    private func displayMode(_ register: Bool) {
        Haptics.tap()
        touchCard()
        withAnimation(.easeOut(duration: 0.2)) {
            creatingAccount = register
            errorMessage = nil
        }
    }

    private func showError(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) { errorMessage = text }
    }

    /// Wie im Browser: Steuerzeichen und <> raus, Leerraum zusammenziehen,
    /// hoechstens 20 Zeichen, mindestens 2.
    private func startAsGuest() {
        let cleaned: String = LoginView.cleanName(guestName)
        guard cleaned.count >= 2 else {
            showError("At least 2 characters")
            Haptics.wrong()
            return
        }
        errorMessage = nil
        Haptics.tap()
        api.playAsGuest(name: cleaned)
    }

    private static func cleanName(_ raw: String) -> String {
        let stripped: String = raw.replacingOccurrences(of: "[\\u0000-\\u001f\\u007f\\u200b-\\u200f\\u2028\\u2029<>]",
                                                    with: "", options: .regularExpression)
        let compact: String = stripped.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let outline: String = compact.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(outline.prefix(20))
    }

    /// Dieselben Pruefungen und Meldungen wie im Browser - der Knopf ist dort
    /// nie gesperrt, sondern sagt, was fehlt.
    private func proceed() {
        guard !isRunning else { return }
        touchCard()
        let n: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !passwordText.isEmpty else {
            showError("Enter your username and password")
            Haptics.wrong()
            return
        }
        let register: Bool = creatingAccount
        if register {
            var problem: String?
            if n.count < 3 || n.count > 20 {
                problem = "Username: 3-20 characters"
            } else if n.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) == nil {
                problem = "Letters, numbers and _ only"
            } else if passwordText.count < 8 {
                problem = "Password: at least 8 characters"
            } else if passwordText != passwordRepeat {
                problem = "The two passwords do not match"
            }
            if let p = problem {
                showError(p)
                Haptics.wrong()
                return
            }
        }
        let pw: String = passwordText
        isRunning = true
        errorMessage = nil
        Task {
            do {
                if register {
                    try await api.register(name: n, passwordText: pw)
                } else {
                    try await api.logIn(name: n, passwordText: pw)
                }
                Haptics.correct()
            } catch {
                let notice: String = error.localizedDescription
                let fallback: String = register ? "Could not create the account"
                                                  : "Login failed"
                showError(notice.isEmpty ? fallback : notice)
                Haptics.wrong()
            }
            isRunning = false
        }
    }
}

// MARK: - Bausteine der Anmeldung

/// Werte aus dem Browser, die es in `Farbe` nicht gibt.
private enum LoginPalette {
    static let card      = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.94)
    static let alphaCard = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.72)
    static let capsuleFill     = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.88)
    static let chip       = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    static let field       = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.72)
    static let fieldFocused  = Color(.sRGB, red: 14 / 255, green: 12 / 255, blue: 28 / 255, opacity: 0.85)
    static let guestField   = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)
    /// Platzhalter ohne eigene Farbe: Schriftfarbe zur Haelfte (Tailwind-Vorgabe).
    static let placeholderText = Color(.sRGB, red: 238 / 255, green: 238 / 255, blue: 1, opacity: 0.5)
    static let lightPurple   = Color(hex: 0xB0AED2)
    /// --acc-pale zu #b15cff
    static let pale      = Color(hex: 0xCC95FF)
    static let badge      = Color(hex: 0xF59E0B)
    static let badgeBorder = Color(hex: 0x181727)
    static let discordFill = Color(.sRGB, red: 88 / 255, green: 101 / 255, blue: 242 / 255, opacity: 0.16)
    static let discordBorder  = Color(.sRGB, red: 88 / 255, green: 101 / 255, blue: 242 / 255, opacity: 0.4)
    static let discordText  = Color(hex: 0xC7CCFF)
}

private enum AccountFieldID: Hashable {
    case name, passwordText, passwordRepeat
}

/// Der Grund der Anmeldekarte: rgba(24,23,39,.94), Rand --acc 22 %, Ecken 24,
/// Schatten 0 24 60 schwarz .55 und lila Schein 0 0 60 --acc-deep 10 %.
/// Angetippt: Rand 38 %, Schatten 0 28 74 / .62, Schein 0 0 96 / 24 %.
private struct LoginCardBackground: View {
    let isActive: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let shadowColor: Color = Color.black.opacity(isActive ? 0.62 : 0.55)
        let glow: Color = Palette.accentDeep.opacity(isActive ? 0.24 : 0.1)
        ZStack {
            shape.fill(LoginPalette.card)
                .shadow(color: shadowColor, radius: isActive ? 37 : 30, x: 0, y: isActive ? 28 : 24)
                .shadow(color: glow, radius: isActive ? 48 : 30, x: 0, y: 0)
            shape.strokeBorder(Palette.accent.opacity(isActive ? 0.38 : 0.22), lineWidth: 1)
            EdgeHighlight(radius: 24, intensity: isActive ? 0.08 : 0.05)
        }
        .animation(.easeOut(duration: 0.3), value: isActive)
    }
}

/// "Play now" / "Log in": flaches --acc, weiss fett, Ecken 16,
/// Schein 0 0 28 --acc-deep 35 %, heller Strich oben.
private struct PurpleButtonStyle: ButtonStyle {
    var foreground: CGFloat = 14
    var frameHeight: CGFloat = 49

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return configuration.label
            .font(.brand(foreground, .bold))
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: frameHeight)
            .background(
                shape.fill(Palette.accent)
                    .shadow(color: Palette.accentDeep.opacity(0.35), radius: 14, x: 0, y: 0)
            )
            .overlay(EdgeHighlight(radius: 16, intensity: 0.15))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// whileTap scale .97
private struct GentlePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Rahmen der Eingabefelder wie im Browser: rgba(10,9,20,.72), Rand weiss 8 %,
/// Ecken 16, 14 Polster; mit Fokus dunkler, Rand --acc 55 % und ein 3-pt-Ring
/// --acc 12 % aussen herum.
private struct WebFieldFrame: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let base: Color = isActive ? LoginPalette.fieldFocused : LoginPalette.field
        let outline: Color = isActive ? Palette.accent.opacity(0.55) : Color.white.opacity(0.08)
        return content
            .padding(.horizontal, 14)
            .frame(height: 49)
            .background(shape.fill(base))
            .overlay(shape.strokeBorder(outline, lineWidth: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 17.5, style: .continuous)
                    .stroke(Palette.accent.opacity(isActive ? 0.12 : 0), lineWidth: 3)
                    .padding(-1.5)
                    .allowsHitTesting(false)
            )
            .animation(.easeOut(duration: 0.18), value: isActive)
    }
}

/// Feld mit Etikett darueber (USERNAME / PASSWORD), Symbol links und beim
/// Passwort dem Auge rechts. Etikett und Symbol werden mit Fokus lila.
private struct AccountField: View {
    let heading: String
    let symbol: String
    let placeholderText: String
    @Binding var text: String
    let kind: AccountFieldID
    var focus: FocusState<AccountFieldID?>.Binding
    var contents: UITextContentType? = nil
    var concealed: Bool = false
    /// nil: kein Auge. Sonst: ob das Passwort gerade sichtbar ist.
    var eye: Bool? = nil
    var eyeTap: () -> Void = {}
    var submit: () -> Void = {}

    var body: some View {
        let isActive: Bool = focus.wrappedValue == kind
        VStack(alignment: .leading, spacing: 6) {
            Text(heading.uppercased())
                .font(.brand(10, .bold))
                .tracking(1)
                .foregroundColor(isActive ? Palette.accent : Palette.subdued)
                .lineLimit(1)
                .frame(height: 15)
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isActive ? Palette.accent : Palette.subdued)
                    .frame(width: 15, height: 15)
                input
                if let isOpen = eye {
                    Button(action: eyeTap) {
                        Image(systemName: isOpen ? "eye.slash" : "eye")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Palette.subdued)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, -7.5)
                    .accessibilityLabel(isOpen ? "Hide password"
                                              : "Show password")
                }
            }
            .modifier(WebFieldFrame(isActive: isActive))
            .animation(.easeOut(duration: 0.18), value: isActive)
        }
    }

    private var input: some View {
        Group {
            if concealed {
                SecureField("", text: $text, prompt: hintLabel)
            } else {
                TextField("", text: $text, prompt: hintLabel)
            }
        }
        .font(.brand(15))
        .foregroundColor(Palette.foreground)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .textContentType(contents)
        .focused(focus, equals: kind)
        .submitLabel(.go)
        .onSubmit { submit() }
        .frame(maxWidth: .infinity)
    }

    private var hintLabel: Text {
        Text(placeholderText).foregroundColor(LoginPalette.placeholderText)
    }
}

/// Die neun Balken ueber dem Schriftzug (Groesse 1.4): je 4,2 pt breit,
/// 3 pt Abstand, --acc 55 %, wippen mit eigener Dauer zwischen voller Hoehe
/// und 22 % (@keyframes eq).
private struct LoginBars: View {
    @State private var on = false
    private let heights: [CGFloat] = [8, 14, 10, 18, 12, 16, 9, 13, 11]
    private let lengths: [Double] = [0.55, 0.40, 0.70, 0.45, 0.60, 0.50, 0.65, 0.42, 0.58]
    private let delays: [Double] = [0.00, 0.08, 0.04, 0.12, 0.06, 0.10, 0.02, 0.14, 0.07]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<9, id: \.self) { i in
                bar(i)
            }
        }
        .frame(height: 28, alignment: .bottom)
        .onAppear { on = true }
    }

    private func bar(_ i: Int) -> some View {
        let h: CGFloat = heights[i] * 1.4
        let halfDuration: Double = lengths[i] / 2
        return Capsule()
            .fill(Palette.accent.opacity(0.55))
            .frame(width: 4.2, height: h)
            .scaleEffect(x: 1, y: on ? 0.22 : 1, anchor: .bottom)
            .animation(.easeInOut(duration: halfDuration).repeatForever(autoreverses: true).delay(delays[i]), value: on)
    }
}

/// FAKESTER in 52 pt (800), -0,045 em: FAKE #f4f3ff mit weissem Schein,
/// STER --acc mit lila Schein (text-shadow 0 0 60px).
private struct LoginLogo: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("FAKE")
                .foregroundColor(Color(hex: 0xF4F3FF))
                .shadow(color: Color.white.opacity(0.18), radius: 30)
            Text("STER")
                .foregroundColor(Palette.accent)
                .shadow(color: Palette.accent.opacity(0.55), radius: 30)
        }
        .font(.brand(52, .heavy))
        .tracking(-2.34)
        .lineLimit(1)
        .fixedSize()
        .frame(height: 52)
    }
}

/// ALPHA / PUBLIC ALPHA: 10 pt fett, 1,5 pt gesperrt, --acc auf --acc 10 %,
/// Rand --acc 30 %, Pille 21 hoch.
private struct AlphaPill: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.brand(10, .bold))
            .tracking(1.5)
            .foregroundColor(Palette.accent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(height: 21)
            .background(Capsule().fill(Palette.accent.opacity(0.1)))
            .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.3), lineWidth: 1))
    }
}

/// Die kleine Karte unter der Anmeldung: PUBLIC ALPHA, Text, Discord.
private struct AlphaCard: View {
    @Environment(\.openURL) private var openLink

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            AlphaPill(text: "Public alpha")
                .padding(.bottom, 6)
            Text("Songs go missing, rounds break, things move around. That is what an alpha is. If something feels wrong, tell us — that is how it gets fixed.")
                .font(.brand(12))
                .foregroundColor(LoginPalette.lightPurple)
                .lineSpacing(2.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
            discordButton
        }
        // 16 Polster + 1 Rand
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(LoginPalette.alphaCard))
        .overlay(shape.strokeBorder(Palette.rim, lineWidth: 1))
    }

    private var discordButton: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button {
            Haptics.tap()
            if let url = URL(string: "https://discord.gg/4s6Mdy7hjN") { openLink(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "message")
                    .font(.system(size: 12, weight: .medium))
                Text("Join the Discord")
                    .font(.brand(13, .bold))
            }
            .foregroundColor(LoginPalette.discordText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(shape.fill(LoginPalette.discordFill))
            .overlay(shape.strokeBorder(LoginPalette.discordBorder, lineWidth: 1))
        }
        .buttonStyle(GentlePressStyle())
    }
}

/// "● 3 online | 1 lobbies" ganz oben, nur wenn jemand online ist:
/// Pille rgba(24,23,39,.88), Rand --border, 12 pt, Zahlen fett und hell.
private struct OnlineCapsule: View {
    let live: LiveStats

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                PingDot()
                (Text(verbatim: live.players.formatted())
                    .font(.brand(12, .semibold))
                    .foregroundColor(Palette.foreground)
                 + Text(verbatim: " online"))
            }
            if live.lobbies > 0 {
                Rectangle()
                    .fill(Palette.border)
                    .frame(width: 1, height: 12)
                (Text(verbatim: live.lobbies.formatted())
                    .font(.brand(12, .semibold))
                    .foregroundColor(Palette.foreground)
                 + Text(" lobbies"))
            }
        }
        .font(.brand(12, .medium))
        .foregroundColor(Palette.faint)
        .lineLimit(1)
        .padding(.horizontal, 21)
        .frame(height: 40)
        .background(
            Capsule()
                .fill(LoginPalette.capsuleFill)
                .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 4)
        )
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
        .overlay(EdgeHighlight(radius: 20, intensity: 0.05))
    }
}

/// Der Punkt mit animate-ping: ein zweiter Punkt waechst auf das Doppelte und verblasst.
private struct PingDot: View {
    @State private var on = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.accent)
                .scaleEffect(on ? 2 : 1)
                .opacity(on ? 0 : 0.7)
                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: on)
            Circle()
                .fill(Palette.accent)
        }
        .frame(width: 6, height: 6)
        .onAppear { on = true }
    }
}

/// Der Kreisel auf "Checking…": 14 pt, 2 pt Rand, oben offen, 0,7 s je Umdrehung.
private struct Spinner: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.7).repeatForever(autoreverses: false), value: spinning)
            .frame(width: 14, height: 14)
            .onAppear { spinning = true }
    }
}

// MARK: - Geteilte Bausteine

/// Linie - Wort - Linie (wie "or" im Browser: 10 pt fett, gesperrt, #8d8ba4,
/// Linien in --border, 12 pt Abstand).
struct LabeledDivider: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text(text.uppercased())
                .eyebrow()
                .lineLimit(1)
                .fixedSize()
            Rectangle().fill(Palette.border).frame(height: 1)
        }
        .frame(height: 15)
    }
}

/// Ein Eingabefeld wie im Browser: rgba(10,9,20,.72), Rand weiss 8 %, Ecken 16,
/// 49 hoch, 15 pt; mit Fokus Rand --acc 55 % und lila Ring.
/// Die eingebauten Felder von SwiftUI bringen eine helle Umrandung mit, die
/// hier fehl am Platz waere.
struct InputField: View {
    @Binding var text: String
    let placeholderText: String
    var secure = false
    var digitsOnly = false
    var mono = false

    @FocusState private var focus: Bool

    var body: some View {
        Group {
            if secure {
                SecureField("", text: $text, prompt: hintLabel)
            } else {
                TextField("", text: $text, prompt: hintLabel)
            }
        }
        .focused($focus)
        .font(mono ? .mono(22) : .brand(15))
        .tracking(mono ? 4 : 0)
        .foregroundColor(Palette.foreground)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(digitsOnly ? .numberPad : .default)
        .modifier(WebFieldFrame(isActive: focus))
    }

    private var hintLabel: Text {
        Text(placeholderText).foregroundColor(LoginPalette.placeholderText)
    }
}

/// Der Profil-Chip oben links auf dem Startbildschirm wie im Browser:
/// rgba(24,23,39,.9), Rand --border, Ecken 16, Polster 6/10/6/6;
/// Avatar 32 mit Rand --acc 70 % und Schein, goldene Stufenperle unten rechts,
/// Name 13 pt fett in --acc. (Titel und PRO zeigt der Browser erst ab
/// Tablet-Breite - auf dem Handy nicht.)
struct ProfileChip: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 8) {
            avatar
                .overlay(alignment: .bottomTrailing) {
                    levelBadge
                        .offset(x: 2, y: 2)
                }
            Text(api.identity?.username ?? "")
                .font(.brand(13, .bold))
                .foregroundColor(Palette.accent)
                .lineLimit(1)
        }
        // 6/10/6/6 Polster + 1 Rand
        .padding(.leading, 7)
        .padding(.trailing, 11)
        .padding(.vertical, 7)
        .background(shape.fill(LoginPalette.chip))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            if let url = pictureURL {
                AsyncImage(url: url) { phase in
                    if let picture = phase.image {
                        picture.resizable().scaledToFill()
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
                .strokeBorder(Palette.accent.opacity(0.7), lineWidth: 2)
                .shadow(color: Palette.accent.opacity(0.3), radius: 5)
        )
    }

    private var symbol: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(LoginPalette.pale)
    }

    /// Wie `<img src>` im Browser: relative Pfade gelten ab fakester.app.
    private var pictureURL: URL? {
        guard let s = api.identity?.avatar_url, !s.isEmpty else { return nil }
        return URL(string: s, relativeTo: URL(string: "https://fakester.app/"))?.absoluteURL
    }

    /// Stufe aus den XP - Gaeste haben keine und stehen wie im Browser auf 1.
    private var levelBadge: some View {
        Text(verbatim: "\(Api.Level.forXP(api.me?.xp ?? 0))")
            .font(.brand(9, .heavy))
            .foregroundColor(Palette.base)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .frame(minWidth: 15)
            .frame(height: 15)
            .background(Capsule().fill(LoginPalette.badge))
            .overlay(Capsule().strokeBorder(LoginPalette.badgeBorder, lineWidth: 2))
    }
}

/// Kleines Abzeichen (PRO, GAST ...).
struct MiniBadge: View {
    let text: String
    var hue: Color = Palette.accent

    var body: some View {
        Text(text)
            .font(.brand(9, .heavy))
            .tracking(0.6)
            .foregroundColor(Palette.base)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(hue, in: Capsule())
    }
}


struct BubblePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
