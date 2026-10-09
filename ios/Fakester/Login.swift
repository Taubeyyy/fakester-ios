import SwiftUI
import UIKit

/// Sign in or play as a guest - built like the login screen of the live
/// fakester.app (phone format 375 × 812, October 2026): equalizer bars, the
/// wordmark with its ALPHA pill, "Guess the song. Beat the crew.", then the
/// big card ("Play now" or the name field, "or", Sign in with the mode switch,
/// fields, "Log in", hint), the Public alpha card and the footer.
struct LoginView: View {
    @EnvironmentObject private var api: Api

    @State private var name = ""
    @State private var passwordText = ""
    @State private var passwordRepeat = ""
    @State private var guestName = ""
    @State private var creatingAccount = false
    /// "Play now" was tapped: the name field takes the button's place.
    @State private var guestMode = false
    @State private var revealPassword = false
    @State private var isRunning = false
    @State private var errorMessage: String?
    /// In the browser the card stays in its hover state after the first tap
    /// (stronger border and glow) - Safari on the iPhone fires mouseenter on a
    /// tap. That is exactly how it looks there after "Play now".
    @State private var touched = false
    @State private var live: LiveStats?
    @FocusState private var focus: AccountFieldID?
    @FocusState private var guestFocus: Bool

    /// The "create one" link in the hint points here and stays inside the app.
    private static let linkScheme = "fakester-login"

    /// The browser's wordmark is 261 pt wide at 52 px, iOS Helvetica draws it
    /// about 4 pt narrower. The ALPHA pill only goes next to it when the
    /// browser's 261 + 8 (gap) + 60 (pill) fit - so at 375 pt (327 pt of
    /// content) it wraps below the wordmark exactly like on the website.
    private static let sideBySideWidth: CGFloat = 329

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    UpdateCard()
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    // Like in the browser: only when somebody is actually online.
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
        .onAppear { adoptPendingSignupName() }
        .task {
            // The browser asks again every 25 seconds.
            while !Task.isCancelled {
                if let z: LiveStats = try? await api.fetch("/stats/live") { live = z }
                try? await Task.sleep(nanoseconds: 25_000_000_000)
            }
        }
        .onChange(of: focus) { latest in
            if latest != nil { touchCard() }
        }
        .onChange(of: guestName) { latest in
            // maxLength 20, as in the browser
            if latest.count > 20 { guestName = String(latest.prefix(20)) }
        }
    }

    // MARK: Layout

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            loginCard
            AlphaCard()
                .padding(.top, 16)
        }
    }

    /// Bars (16 below), wordmark with the ALPHA pill (flex-wrap, gap 8, the
    /// pill 6 lower), 12 below that the subtitle, then 24 to the card.
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
                .frame(minWidth: LoginView.sideBySideWidth)
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
        // 20 padding + 1 border
        .padding(21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoginCardBackground(isActive: touched))
    }

    // MARK: As a guest

    private var playButton: some View {
        Button {
            Haptics.tap()
            touchCard()
            withAnimation(.easeOut(duration: 0.2)) {
                guestMode = true
                errorMessage = nil
            }
            // autoFocus, as in the browser
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guestFocus = true
            }
        } label: {
            HStack(spacing: 8) {
                LucideGlyph(icon: .play, size: 15)
                Text("Play now")
            }
        }
        .buttonStyle(PurpleButtonStyle(foreground: 14, frameHeight: 49))
    }

    /// Name field (rgba(10,9,20,.6), border white 10 %, 12 padding, user icon
    /// 14 in #8d8ba4, 14 pt text) next to the purple arrow button (55 wide,
    /// half transparent until two characters are typed), 8 below the
    /// "Back to logging in" link.
    private var guestRow: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let ready: Bool = guestName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    LucideGlyph(icon: .user, size: 14)
                        .foregroundColor(Palette.subdued)
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
                    LucideGlyph(icon: .arrowRight, size: 15)
                        .foregroundColor(Color.white)
                        .frame(width: 55, height: 47)
                        .background(shape.fill(Palette.accent))
                }
                .buttonStyle(GentlePressStyle())
                .disabled(!ready)
                .opacity(ready ? 1 : 0.5)
                .accessibilityLabel("Play")
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

    // MARK: With an account

    /// Round icon box (36, white 6 %, log-in icon 16), title 17 pt extra bold
    /// (line 21), underneath 11 pt in #8d8ba4.
    private var accountHeader: some View {
        HStack(spacing: 10) {
            LucideGlyph(icon: .logIn, size: 16)
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
                         icon: .user,
                         placeholderText: "Your username",
                         text: $name,
                         kind: .name,
                         focus: $focus,
                         contents: UITextContentType.username,
                         submit: { proceed() })
            AccountField(heading: "Password",
                         icon: .lock,
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
                             icon: .lock,
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

    /// Red note: rgba(239,68,68,.12), corners 18, 8/12 padding, warning
    /// triangle 13 next to 12 pt semibold text in #f87171.
    private func errorBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            LucideGlyph(icon: .triangleAlert, size: 13)
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
                LucideGlyph(icon: .userPlus, size: 15)
                Text("Create account")
            }
        } else {
            HStack(spacing: 8) {
                LucideGlyph(icon: .logIn, size: 15)
                Text("Log in")
            }
        }
    }

    // MARK: Hint

    /// Headphones (13, 60 %) next to 11 pt text in #8d8ba4 with the browser's
    /// line height of 15.1 (leading-snug). In the sign-in hint the "create one"
    /// button sits in a 24 pt tall line box, so that block is 3 pt taller at
    /// the bottom than the plain text alone.
    private var hint: some View {
        let plainText: Bool = guestMode || creatingAccount
        return HStack(alignment: .top, spacing: 8) {
            LucideGlyph(icon: .headphones, size: 13)
                .opacity(0.6)
                .padding(.top, 2)
            hintText
                .font(.brand(11))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1.2)
                .padding(.bottom, plainText ? 1.2 : 4.3)
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

    /// "… or create one to keep …" - in the browser "create one" is a button
    /// in 16 pt, semibold and purple, in the middle of the 11 pt text.
    private var accountHint: AttributedString {
        var full = AttributedString("No account yet? You can play as a guest right away, or ")
        var linkText = AttributedString("create one")
        linkText[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font.brand(16, .semibold)
        linkText[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Palette.accent
        linkText[AttributeScopes.FoundationAttributes.LinkAttribute.self] = URL(string: LoginView.linkScheme + "://account")
        full.append(linkText)
        full.append(AttributedString(" to keep your XP, Spots and items."))
        return full
    }

    // MARK: Footer

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

    // MARK: Flow

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

    /// The guest who answered "Yes" in the home screen's "That one needs an
    /// account" dialog lands here: "Create account" is open and the name they
    /// played under is already in the username field.
    private func adoptPendingSignupName() {
        let store: UserDefaults = UserDefaults.standard
        guard let pending = store.string(forKey: LoginView.pendingSignupNameKey) else { return }
        store.removeObject(forKey: LoginView.pendingSignupNameKey)
        name = pending
        creatingAccount = true
    }

    /// As in the browser: control characters and <> removed, whitespace
    /// collapsed, at most 20 characters, at least 2.
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

    /// The same checks and messages as in the browser - the button is never
    /// disabled there, it says what is missing instead.
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

extension LoginView {
    /// UserDefaults key for the hand-over from the home screen: "Yes" in the
    /// guest dialog stores the guest name here right before logging out, and
    /// the login screen picks it up once (see `adoptPendingSignupName`).
    static let pendingSignupNameKey: String = "login.pendingSignupName"
}

// MARK: - Login building blocks

/// Browser values that `Palette` does not have.
private enum LoginPalette {
    static let card        = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.94)
    static let alphaCard   = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.72)
    static let capsuleFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.88)
    static let chip        = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    static let field       = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.72)
    static let fieldFocused = Color(.sRGB, red: 14 / 255, green: 12 / 255, blue: 28 / 255, opacity: 0.85)
    static let guestField  = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)
    /// Placeholder without its own color: the text color at half strength (Tailwind default).
    static let placeholderText = Color(.sRGB, red: 238 / 255, green: 238 / 255, blue: 1, opacity: 0.5)
    static let lightPurple = Color(hex: 0xB0AED2)
    /// --acc-pale for #b15cff
    static let pale        = Color(hex: 0xCC95FF)
    static let badge       = Color(hex: 0xF59E0B)
    static let badgeBorder = Color(hex: 0x181727)
    static let discordFill = Color(.sRGB, red: 88 / 255, green: 101 / 255, blue: 242 / 255, opacity: 0.16)
    static let discordBorder = Color(.sRGB, red: 88 / 255, green: 101 / 255, blue: 242 / 255, opacity: 0.4)
    static let discordText = Color(hex: 0xC7CCFF)
}

private enum AccountFieldID: Hashable {
    case name, passwordText, passwordRepeat
}

/// The background of the login card: rgba(24,23,39,.94), border --acc 22 %,
/// corners 24, shadow 0 24 60 black .55 and a purple glow 0 0 60 --acc-deep 10 %.
/// Touched: border 38 %, shadow 0 28 74 / .62, glow 0 0 96 / 24 %.
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

/// "Play now" / "Log in": flat --acc, white bold text, corners 16,
/// glow 0 0 28 --acc-deep 35 %, a light line along the top edge.
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

/// The input field frame as in the browser: rgba(10,9,20,.72), border white
/// 8 %, corners 16, 14 padding; focused it gets darker, the border turns
/// --acc 55 % and a 3 pt ring of --acc 12 % goes around it.
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

/// A field with its label above (USERNAME / PASSWORD, 6 apart), the icon on
/// the left (15, 10 to the text) and, for the password, the eye on the right.
/// Label and icon turn purple while focused.
private struct AccountField: View {
    let heading: String
    let icon: LucideIcon
    let placeholderText: String
    @Binding var text: String
    let kind: AccountFieldID
    var focus: FocusState<AccountFieldID?>.Binding
    var contents: UITextContentType? = nil
    var concealed: Bool = false
    /// nil: no eye. Otherwise: whether the password is visible right now.
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
                LucideGlyph(icon: icon, size: 15)
                    .foregroundColor(isActive ? Palette.accent : Palette.subdued)
                input
                if let isOpen = eye {
                    Button(action: eyeTap) {
                        LucideGlyph(icon: isOpen ? .eyeOff : .eye, size: 15)
                            .foregroundColor(Palette.subdued)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, -7.5)
                    .accessibilityLabel(isOpen ? "Hide password" : "Show password")
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

/// The nine bars above the wordmark (size 1.4): 4.2 pt wide each, 3 pt apart,
/// --acc 55 %, each bobbing with its own duration between full height and
/// 22 % (@keyframes eq).
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

/// FAKESTER in 52 pt (800), -0.045 em: FAKE #f4f3ff with a white glow,
/// STER --acc with a purple glow (text-shadow 0 0 60px).
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

/// ALPHA / PUBLIC ALPHA: 10 pt bold, 1.5 pt letter spacing, --acc on
/// --acc 10 %, border --acc 30 %, pill 21 tall.
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

/// The small card below the login: PUBLIC ALPHA, text, Discord.
private struct AlphaCard: View {
    @Environment(\.openURL) private var openLink

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            AlphaPill(text: "Public alpha")
                .padding(.bottom, 6)
            // 12 pt with the browser's 16.5 line height (leading-snug): 2.7
            // between the lines plus half of that above and below.
            Text("Songs go missing, rounds break, things move around. That is what an alpha is. If something feels wrong, tell us — that is how it gets fixed.")
                .font(.brand(12))
                .foregroundColor(LoginPalette.lightPurple)
                .lineSpacing(2.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 1.35)
                .padding(.bottom, 12)
            discordButton
        }
        // 16 padding + 1 border
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
                LucideGlyph(icon: .messageCircle, size: 14)
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

/// "● 3 online | 1 lobbies" at the very top, only when somebody is online:
/// pill rgba(24,23,39,.88), border --border, 12 pt, numbers semibold and
/// bright. Dot, number and "online" are separate flex items 8 apart (the
/// space before "online" collapses); "1 lobbies" is one inline run.
private struct OnlineCapsule: View {
    let live: LiveStats

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                PingDot()
                Text(verbatim: live.players.formatted())
                    .font(.brand(12, .semibold))
                    .foregroundColor(Palette.foreground)
                Text("online")
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

/// The dot with animate-ping: a second dot grows to twice its size and fades.
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

/// The spinner on "Checking…": 14 pt, 2 pt ring, open at the top, 0.7 s per turn.
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

// MARK: - Shared building blocks

/// Line - word - line (like "or" in the browser: 10 pt bold, letter-spaced,
/// #8d8ba4, lines in --border, 12 pt apart).
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

/// An input field as in the browser: rgba(10,9,20,.72), border white 8 %,
/// corners 16, 49 tall, 15 pt; focused, the border turns --acc 55 % with a
/// purple ring. SwiftUI's built-in field styles bring a light outline that
/// would be out of place here.
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

/// The profile chip at the top left of the home screen, as in the browser:
/// rgba(24,23,39,.9), border --border, corners 16, padding 6/10/6/6;
/// avatar 32 with an --acc 70 % ring and glow, a golden level bead at the
/// bottom right, name 13 pt bold in --acc. (The browser only shows title and
/// PRO from tablet width on - not on a phone.)
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
        // 6/10/6/6 padding + 1 border
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

    /// Like `<img src>` in the browser: relative paths start at fakester.app.
    private var pictureURL: URL? {
        guard let s = api.identity?.avatar_url, !s.isEmpty else { return nil }
        return URL(string: s, relativeTo: URL(string: "https://fakester.app/"))?.absoluteURL
    }

    /// The level from the XP - guests have none and, as in the browser, show 1.
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

/// Small badge (PRO, GUEST ...).
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

// MARK: - Lucide icons

/// A lucide icon the way the website draws it (lucide-react): `size` is the
/// icon box in points, the stroke is 2 on the 24 grid and scales with the size,
/// with round caps and joins. Next to the website, SF Symbols look clearly
/// different (heavier, other shapes), so the screens copied from it use these.
/// Purely decorative: hidden from VoiceOver, so button labels stay plain text.
struct LucideGlyph: View {
    let icon: LucideIcon
    var size: CGFloat = 15
    /// lucide's `fill` prop - the play triangle on "Create Game" is filled.
    /// The colour is passed explicitly: a bare `fill()` can be ambiguous on
    /// newer SDKs.
    var fillColor: Color? = nil
    /// lucide's `strokeWidth` on the 24 grid (2 unless a screen says otherwise).
    var weight: CGFloat = 2

    var body: some View {
        let style = StrokeStyle(lineWidth: size * weight / 24, lineCap: .round, lineJoin: .round)
        ZStack {
            if let tone = fillColor {
                LucideShape(icon: icon).fill(tone)
            }
            LucideShape(icon: icon).stroke(style: style)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The icon's outline, scaled from the 24 × 24 grid into the given square.
struct LucideShape: Shape {
    let icon: LucideIcon

    func path(in rect: CGRect) -> Path {
        let side: CGFloat = min(rect.width, rect.height)
        let unit: CGFloat = side / 24
        let originX: CGFloat = rect.midX - side / 2
        let originY: CGFloat = rect.midY - side / 2

        func place(_ p: CGPoint) -> CGPoint {
            CGPoint(x: originX + p.x * unit, y: originY + p.y * unit)
        }

        var path = Path()
        for data in icon.pathData {
            for step in LucidePathReader.steps(data) {
                switch step {
                case .move(let p):
                    path.move(to: place(p))
                case .line(let p):
                    path.addLine(to: place(p))
                case .curve(let c1, let c2, let end):
                    path.addCurve(to: place(end), control1: place(c1), control2: place(c2))
                case .close:
                    path.closeSubpath()
                }
            }
        }
        return path
    }
}

/// The lucide icons used by the screens copied from the website.
enum LucideIcon {
    case logIn, logOut, play, lock, eye, eyeOff, user, userPlus, users, arrowRight, headphones,
         messageCircle, triangleAlert, chevronRight, calendarDays, chartColumn, listChecks,
         shoppingBag, map, palette, bookmark, settings, sparkles, music2, x, search, check, chevronDown, type, smile, image, star,
         gamepad2, crown, layers, target, bell, flame, trophy, clock, userMinus, disc, plus, trash2,
         pause, volumeX, volume2, share2, circleCheck, circleAlert

    /// The SVG path data from the web bundle. rect, circle, line, polyline and
    /// polygon elements are written out as the equivalent paths.
    var pathData: [String] {
        switch self {
        case .logIn:
            return ["M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4", "M10 17 15 12 10 7", "M15 12H3"]
        case .logOut:
            return ["M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4", "M16 17 21 12 16 7", "M21 12H9"]
        case .play:
            return ["M6 3 20 12 6 21 6 3z"]
        case .lock:
            return ["M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z",
                    "M7 11V7a5 5 0 0 1 10 0v4"]
        case .eye:
            return ["M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0",
                    "M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0"]
        case .eyeOff:
            return ["M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49",
                    "M14.084 14.158a3 3 0 0 1-4.242-4.242",
                    "M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143",
                    "m2 2 20 20"]
        case .user:
            return ["M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2", "M8 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0"]
        case .userPlus:
            return ["M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M5 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0",
                    "M19 8v6", "M22 11h-6"]
        case .users:
            return ["M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M5 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0",
                    "M22 21v-2a4 4 0 0 0-3-3.87", "M16 3.13a4 4 0 0 1 0 7.75"]
        case .arrowRight:
            return ["M5 12h14", "m12 5 7 7-7 7"]
        case .headphones:
            return ["M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"]
        case .messageCircle:
            return ["M7.9 20A9 9 0 1 0 4 16.1L2 22Z"]
        case .triangleAlert:
            return ["m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3", "M12 9v4", "M12 17h.01"]
        case .chevronRight:
            return ["m9 18 6-6-6-6"]
        case .calendarDays:
            return ["M8 2v4", "M16 2v4",
                    "M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z",
                    "M3 10h18", "M8 14h.01", "M12 14h.01", "M16 14h.01", "M8 18h.01", "M12 18h.01", "M16 18h.01"]
        case .chartColumn:
            return ["M3 3v16a2 2 0 0 0 2 2h16", "M18 17V9", "M13 17V5", "M8 17v-3"]
        case .listChecks:
            return ["m3 17 2 2 4-4", "m3 7 2 2 4-4", "M13 6h8", "M13 12h8", "M13 18h8"]
        case .shoppingBag:
            return ["M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z", "M3 6h18", "M16 10a4 4 0 0 1-8 0"]
        case .map:
            return ["M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z",
                    "M15 5.764v15", "M9 3.236v15"]
        case .palette:
            return ["M13 6.5a.5 .5 0 1 0 1 0a.5 .5 0 1 0-1 0", "M17 10.5a.5 .5 0 1 0 1 0a.5 .5 0 1 0-1 0",
                    "M8 7.5a.5 .5 0 1 0 1 0a.5 .5 0 1 0-1 0", "M6 12.5a.5 .5 0 1 0 1 0a.5 .5 0 1 0-1 0",
                    "M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"]
        case .bookmark:
            return ["m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"]
        case .settings:
            return ["M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z",
                    "M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0"]
        case .sparkles:
            return ["M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z",
                    "M20 3v4", "M22 5h-4", "M4 17v2", "M5 18H3"]
        case .music2:
            return ["M4 18a4 4 0 1 0 8 0a4 4 0 1 0-8 0", "M12 18V2l7 4"]
        case .x:
            return ["M18 6 6 18", "m6 6 12 12"]
        case .search:
            return ["M3 11a8 8 0 1 0 16 0a8 8 0 1 0-16 0", "m21 21-4.3-4.3"]
        case .check:
            return ["M20 6 9 17l-5-5"]
        case .chevronDown:
            return ["m6 9 6 6 6-6"]
        case .type:
            return ["M4 7 4 4 20 4 20 7", "M9 20h6", "M12 4v16"]
        case .smile:
            return ["M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0", "M8 14s1.5 2 4 2 4-2 4-2", "M9 9h.01", "M15 9h.01"]
        case .image:
            return ["M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z",
                    "M7 9a2 2 0 1 0 4 0a2 2 0 1 0-4 0", "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"]
        case .gamepad2:
            return ["M6 11h4", "M8 9v4", "M15 12h.01", "M18 10h.01",
                    "M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z"]
        case .crown:
            return ["M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H5.81a1 1 0 0 1-.957-.734L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z",
                    "M5 21h14"]
        case .layers:
            return ["M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z",
                    "M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12",
                    "M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17"]
        case .target:
            return ["M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0", "M6 12a6 6 0 1 0 12 0a6 6 0 1 0-12 0",
                    "M10 12a2 2 0 1 0 4 0a2 2 0 1 0-4 0"]
        case .bell:
            return ["M10.268 21a2 2 0 0 0 3.464 0",
                    "M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"]
        case .flame:
            return ["M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"]
        case .trophy:
            return ["M6 9H4.5a2.5 2.5 0 0 1 0-5H6", "M18 9h1.5a2.5 2.5 0 0 0 0-5H18", "M4 22h16",
                    "M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22",
                    "M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22",
                    "M18 2H6v7a6 6 0 0 0 12 0V2Z"]
        case .pause:
            return ["M15 4h2a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z",
                    "M7 4h2a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z"]
        case .volumeX:
            return ["M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z",
                    "M22 9 16 15", "M16 9 22 15"]
        case .volume2:
            return ["M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z",
                    "M16 9a5 5 0 0 1 0 6", "M19.364 18.364a9 9 0 0 0 0-12.728"]
        case .share2:
            return ["M15 5a3 3 0 1 0 6 0a3 3 0 1 0-6 0", "M3 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0",
                    "M15 19a3 3 0 1 0 6 0a3 3 0 1 0-6 0", "M8.59 13.51 15.42 17.49", "M15.41 6.51 8.59 10.49"]
        case .circleCheck:
            return ["M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0", "m9 12 2 2 4-4"]
        case .circleAlert:
            return ["M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0", "M12 8v4", "M12 16h.01"]
        case .disc:
            return ["M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0", "M10 12a2 2 0 1 0 4 0a2 2 0 1 0-4 0"]
        case .plus:
            return ["M5 12h14", "M12 5v14"]
        case .trash2:
            return ["M3 6h18", "M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6", "M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2",
                    "M10 11v6", "M14 11v6"]
        case .userMinus:
            return ["M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M5 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0", "M22 11h-6"]
        case .clock:
            return ["M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0", "M12 6 12 12 16 14"]
        case .star:
            return ["M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"]
        }
    }
}

/// One drawing step of an icon path, in absolute grid coordinates.
enum LucideStep {
    case move(CGPoint)
    case line(CGPoint)
    /// control 1, control 2, end
    case curve(CGPoint, CGPoint, CGPoint)
    case close
}

/// Reads the part of the SVG path syntax that lucide uses (M L H V C S A Z,
/// absolute and relative, implicit repeats); arcs become cubic curves.
/// Anything it does not understand ends the path instead of guessing.
struct LucidePathReader {
    private let bytes: [UInt8]
    private var index: Int = 0
    private var failed: Bool = false

    private init(_ data: String) {
        bytes = Array(data.utf8)
    }

    static func steps(_ data: String) -> [LucideStep] {
        var reader = LucidePathReader(data)
        return reader.readAll()
    }

    private mutating func readAll() -> [LucideStep] {
        var steps: [LucideStep] = []
        var current: CGPoint = .zero
        var subpathStart: CGPoint = .zero
        // Second control point of the previous C/S, mirrored by S.
        var lastControl: CGPoint?
        var command: UInt8 = 0
        while !failed {
            skipSeparators()
            if index >= bytes.count { break }
            let byte: UInt8 = bytes[index]
            if LucidePathReader.isCommand(byte) {
                command = byte
                index += 1
            } else if command == 0 {
                break
            }
            let relative: Bool = command >= 97
            let base: CGPoint = relative ? current : .zero
            switch command | 0x20 {
            case 109: // m
                let p: CGPoint = point(from: base)
                steps.append(.move(p))
                current = p
                subpathStart = p
                lastControl = nil
                // Further coordinate pairs after a move are lines.
                command = relative ? 108 : 76
            case 108: // l
                let p: CGPoint = point(from: base)
                steps.append(.line(p))
                current = p
                lastControl = nil
            case 104: // h
                let value: CGFloat = number()
                let p = CGPoint(x: relative ? current.x + value : value, y: current.y)
                steps.append(.line(p))
                current = p
                lastControl = nil
            case 118: // v
                let value: CGFloat = number()
                let p = CGPoint(x: current.x, y: relative ? current.y + value : value)
                steps.append(.line(p))
                current = p
                lastControl = nil
            case 99: // c
                let c1: CGPoint = point(from: base)
                let c2: CGPoint = point(from: base)
                let end: CGPoint = point(from: base)
                steps.append(.curve(c1, c2, end))
                current = end
                lastControl = c2
            case 115: // s
                var c1: CGPoint = current
                if let previous = lastControl {
                    c1 = CGPoint(x: 2 * current.x - previous.x, y: 2 * current.y - previous.y)
                }
                let c2: CGPoint = point(from: base)
                let end: CGPoint = point(from: base)
                steps.append(.curve(c1, c2, end))
                current = end
                lastControl = c2
            case 97: // a
                let rx: CGFloat = number()
                let ry: CGFloat = number()
                let rotation: CGFloat = number()
                let large: Bool = flag()
                let sweep: Bool = flag()
                let end: CGPoint = point(from: base)
                if failed { break }
                steps.append(contentsOf: LucidePathReader.arc(from: current, to: end, rx: rx, ry: ry,
                                                              rotation: rotation, large: large, sweep: sweep))
                current = end
                lastControl = nil
            case 122: // z
                steps.append(.close)
                current = subpathStart
                lastControl = nil
                // Z takes no numbers - stray numbers after it end the path.
                command = 0
            default:
                failed = true
            }
        }
        return steps
    }

    private static func isCommand(_ byte: UInt8) -> Bool {
        switch byte | 0x20 {
        case 109, 108, 104, 118, 99, 115, 97, 122: return byte >= 65
        default: return false
        }
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= 48 && byte <= 57
    }

    private mutating func skipSeparators() {
        while index < bytes.count {
            let byte: UInt8 = bytes[index]
            if byte == 32 || byte == 44 || byte == 9 || byte == 10 || byte == 13 {
                index += 1
            } else {
                break
            }
        }
    }

    private mutating func point(from base: CGPoint) -> CGPoint {
        let x: CGFloat = number()
        let y: CGFloat = number()
        return CGPoint(x: base.x + x, y: base.y + y)
    }

    /// A number like "12", "-.696" or "1.4e-3"; "0-.5" and ".5.5" are two numbers each.
    private mutating func number() -> CGFloat {
        skipSeparators()
        let begin: Int = index
        if index < bytes.count, bytes[index] == 43 || bytes[index] == 45 {
            index += 1
        }
        var digits: Int = 0
        while index < bytes.count, LucidePathReader.isDigit(bytes[index]) {
            index += 1
            digits += 1
        }
        if index < bytes.count, bytes[index] == 46 {
            index += 1
            while index < bytes.count, LucidePathReader.isDigit(bytes[index]) {
                index += 1
                digits += 1
            }
        }
        if digits > 0, index < bytes.count, bytes[index] == 101 || bytes[index] == 69 {
            var probe: Int = index + 1
            if probe < bytes.count, bytes[probe] == 43 || bytes[probe] == 45 {
                probe += 1
            }
            if probe < bytes.count, LucidePathReader.isDigit(bytes[probe]) {
                index = probe
                while index < bytes.count, LucidePathReader.isDigit(bytes[index]) {
                    index += 1
                }
            }
        }
        let text: String = String(decoding: bytes[begin..<index], as: UTF8.self)
        guard digits > 0, let value = Double(text) else {
            failed = true
            index = bytes.count
            return 0
        }
        return CGFloat(value)
    }

    /// Arc flags are a single 0 or 1 and may be written without separators.
    private mutating func flag() -> Bool {
        skipSeparators()
        guard index < bytes.count, bytes[index] == 48 || bytes[index] == 49 else {
            failed = true
            index = bytes.count
            return false
        }
        let isSet: Bool = bytes[index] == 49
        index += 1
        return isSet
    }

    /// An SVG elliptical arc as cubic curves (SVG spec, appendix F.6.5), at
    /// most a quarter turn per curve.
    private static func arc(from start: CGPoint, to end: CGPoint, rx: CGFloat, ry: CGFloat,
                            rotation: CGFloat, large: Bool, sweep: Bool) -> [LucideStep] {
        if start == end { return [] }
        var radiusX: Double = abs(Double(rx))
        var radiusY: Double = abs(Double(ry))
        if radiusX == 0 || radiusY == 0 { return [.line(end)] }
        let phi: Double = Double(rotation) * Double.pi / 180
        let cosPhi: Double = cos(phi)
        let sinPhi: Double = sin(phi)
        let halfDX: Double = Double(start.x - end.x) / 2
        let halfDY: Double = Double(start.y - end.y) / 2
        let x1: Double = cosPhi * halfDX + sinPhi * halfDY
        let y1: Double = -sinPhi * halfDX + cosPhi * halfDY
        let lambda: Double = (x1 * x1) / (radiusX * radiusX) + (y1 * y1) / (radiusY * radiusY)
        if lambda > 1 {
            radiusX *= lambda.squareRoot()
            radiusY *= lambda.squareRoot()
        }
        let rx2: Double = radiusX * radiusX
        let ry2: Double = radiusY * radiusY
        let numerator: Double = rx2 * ry2 - rx2 * y1 * y1 - ry2 * x1 * x1
        let denominator: Double = rx2 * y1 * y1 + ry2 * x1 * x1
        var coefficient: Double = denominator == 0 ? 0 : max(0, numerator / denominator).squareRoot()
        if large == sweep { coefficient = -coefficient }
        let centerX1: Double = coefficient * radiusX * y1 / radiusY
        let centerY1: Double = -coefficient * radiusY * x1 / radiusX
        let centerX: Double = cosPhi * centerX1 - sinPhi * centerY1 + Double(start.x + end.x) / 2
        let centerY: Double = sinPhi * centerX1 + cosPhi * centerY1 + Double(start.y + end.y) / 2
        let ux: Double = (x1 - centerX1) / radiusX
        let uy: Double = (y1 - centerY1) / radiusY
        let vx: Double = (-x1 - centerX1) / radiusX
        let vy: Double = (-y1 - centerY1) / radiusY
        let startAngle: Double = atan2(uy, ux)
        var sweepAngle: Double = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        if !sweep && sweepAngle > 0 {
            sweepAngle -= 2 * Double.pi
        } else if sweep && sweepAngle < 0 {
            sweepAngle += 2 * Double.pi
        }
        let pieces: Int = max(1, Int((abs(sweepAngle) / (Double.pi / 2)).rounded(.up)))
        let piece: Double = sweepAngle / Double(pieces)
        let handle: Double = 4.0 / 3.0 * tan(piece / 4)

        func onEllipse(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: centerX + radiusX * cosPhi * x - radiusY * sinPhi * y,
                    y: centerY + radiusX * sinPhi * x + radiusY * cosPhi * y)
        }

        var steps: [LucideStep] = []
        var angle: Double = startAngle
        for pieceIndex in 0..<pieces {
            let next: Double = angle + piece
            let c1: CGPoint = onEllipse(cos(angle) - handle * sin(angle), sin(angle) + handle * cos(angle))
            let c2: CGPoint = onEllipse(cos(next) + handle * sin(next), sin(next) - handle * cos(next))
            // The last piece ends exactly on the target, without rounding drift.
            let target: CGPoint = pieceIndex == pieces - 1 ? end : onEllipse(cos(next), sin(next))
            steps.append(.curve(c1, c2, target))
            angle = next
        }
        return steps
    }
}
