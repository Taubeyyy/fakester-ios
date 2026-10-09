import SwiftUI

/// "Settings" like the browser's settings screen (k-settings): profile card,
/// change username / password, preferences (only what the app honours: the
/// music volume), about, redeem a code, connect Discord, danger zone.
/// Request bodies as the browser sends them.
struct SettingsView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close
    @ObservedObject private var volume: ClipVolume = ClipVolume.shared

    @State private var newName: String = ""
    @State private var namePassword: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var repeatPassword: String = ""
    @State private var code: String = ""
    @State private var deletePassword: String = ""
    @State private var busy: String?
    @State private var toast: SettingsToast?
    @State private var discord: DiscordStatus?
    @State private var linkCode: LinkCodeState?
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Settings", onBack: { close() })
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        SettingsProfileCard()
                        usernameSection
                        passwordSection
                        preferencesSection
                        aboutSection
                        redeemSection
                        discordSection
                        dangerSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            if let lc = linkCode {
                DiscordCodeDialog(state: lc, close: { linkCode = nil }, regenerate: { Task { await makeLinkCode() } })
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .overlay(alignment: .top) { toastView }
        .animation(.easeOut(duration: 0.18), value: linkCode != nil)
        .task { discord = try? await api.fetch("/discord/status") }
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("This cannot be undone. Your XP, Spots, items and friends are gone for good.")
        }
    }

    // MARK: Sections

    private var usernameSection: some View {
        SettingsSection(title: "Change username", symbol: "person") {
            VStack(spacing: 10) {
                SettingsField(placeholder: "New username...", text: $newName)
                SettingsField(placeholder: "Confirm password...", text: $namePassword, secure: true)
                SettingsPrimaryButton(title: "Change", symbol: "checkmark", busy: busy == "username") {
                    Task { await changeUsername() }
                }
            }
        }
    }

    private var passwordSection: some View {
        SettingsSection(title: "Change password", symbol: "lock") {
            VStack(spacing: 10) {
                SettingsField(placeholder: "Current password...", text: $currentPassword, secure: true)
                SettingsField(placeholder: "New password...", text: $newPassword, secure: true)
                SettingsField(placeholder: "Confirm password...", text: $repeatPassword, secure: true)
                SettingsPrimaryButton(title: "Change", symbol: "checkmark", busy: busy == "password") {
                    Task { await changePassword() }
                }
            }
        }
    }

    /// Only the music volume - the same value as the slider in the round.
    private var preferencesSection: some View {
        SettingsSection(title: "Preferences", symbol: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.subdued)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Music volume").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.foreground)
                        Text("Used by every song, in a game and in the daily")
                            .font(.system(size: 10)).foregroundColor(Palette.subdued)
                    }
                    Spacer(minLength: 0)
                    Text("\(Int((volume.level * 100).rounded()))%")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundColor(Palette.accent)
                }
                Slider(value: Binding(get: { volume.level }, set: { volume.setLevel($0) }), in: 0...1)
                    .tint(Palette.accent)
            }
        }
    }

    private var aboutSection: some View {
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return SettingsSection(title: "About", symbol: "questionmark.circle") {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        (Text("Fakester ").foregroundColor(Palette.foreground) + Text("ALPHA").foregroundColor(Palette.accent))
                            .font(.brand(15, .heavy))
                        Text("Version \(version)").font(.system(size: 10, weight: .bold)).foregroundColor(Palette.subdued)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 4)
                SettingsLinkRow(title: "Discord", subtitle: "News, tournaments and support", symbol: "bubble.left",
                                tint: Palette.discord, trailing: "arrow.right") {
                    if let url = URL(string: "https://discord.gg/4s6Mdy7hjN") { UIApplication.shared.open(url) }
                }
                SettingsLinkRow(title: "Report a bug", subtitle: "Reports genuinely help", symbol: "ant",
                                tint: Palette.bad, trailing: "arrow.right") {
                    NotificationCenter.default.post(name: .deviceShaken, object: nil)
                }
                SettingsLinkRow(title: "Legal & privacy", subtitle: "No cookies, no tracking", symbol: "shield",
                                tint: Palette.subdued, trailing: "chevron.right") {
                    if let url = URL(string: "https://fakester.app/") { UIApplication.shared.open(url) }
                }
            }
        }
    }

    private var redeemSection: some View {
        SettingsSection(title: "Redeem a code", symbol: "gift") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("", text: $code, prompt: Text("CODE").foregroundColor(Palette.faint))
                        .font(.brand(16, .heavy))
                        .tracking(1.6)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundColor(Palette.foreground)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 16, style: .circular).fill(SettingsPalette.field))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .circular).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    Button {
                        Task { await redeem() }
                    } label: {
                        Text(busy == "redeem" ? "…" : "Redeem")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(code.isEmpty ? Palette.subdued : Color.white)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 16, style: .circular)
                                .fill(code.isEmpty ? Color.white.opacity(0.05) : Palette.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || busy != nil)
                }
                Text("Codes come from our Discord, giveaways and events. Each one works once per account.")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subdued)
            }
        }
    }

    private var discordSection: some View {
        let linked: Bool = discord?.linked == true
        return SettingsSection(title: "Connect Discord", symbol: "bubble.left", tint: Palette.discord) {
            VStack(alignment: .leading, spacing: 12) {
                if linked {
                    (Text("Connected as ") + Text(discord?.username ?? "Discord").bold())
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0xC9C8E0))
                } else {
                    (Text("Link your account to our Discord — stats via ") + Text("/stats").bold()
                     + Text(", a PRO role & a small reward. 🎁"))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0xC9C8E0))
                }
                Button {
                    Task { if linked { await unlinkDiscord() } else { await makeLinkCode() } }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: linked ? "xmark" : "plus").font(.system(size: 11, weight: .bold))
                        Text(linked ? "Disconnect" : "Connect").font(.system(size: 13, weight: .bold))
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(Palette.foreground)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Color.white.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .circular)
                        .strokeBorder(linked ? Palette.border : Palette.bad.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(busy == "discord")
            }
        }
    }

    private var dangerSection: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 11, weight: .bold))
                Text("DANGER ZONE").font(.system(size: 11, weight: .bold)).tracking(1.1)
            }
            .foregroundColor(Palette.bad)
            .padding(.horizontal, 16)
            .frame(height: 36, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xEF4444).opacity(0.08))
            Rectangle().fill(Color(hex: 0xEF4444).opacity(0.25)).frame(height: 1)
            VStack(alignment: .leading, spacing: 10) {
                Text("Deleting your account is permanent!")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: 0xFCA5A5))
                SettingsField(placeholder: "Password to confirm...", text: $deletePassword, secure: true)
                Button {
                    guard !deletePassword.isEmpty else {
                        show("Enter your password to confirm", error: true)
                        return
                    }
                    confirmDelete = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash").font(.system(size: 13, weight: .semibold))
                        Text("Delete account").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 16, style: .circular)
                        .fill(LinearGradient(colors: [Color(hex: 0xDC2626), Color(hex: 0xEF4444)],
                                             startPoint: .leading, endPoint: .trailing)))
                }
                .buttonStyle(.plain)
                .disabled(busy == "delete")
            }
            .padding(12)
        }
        .background(shape.fill(Color(.sRGB, red: 40 / 255, green: 12 / 255, blue: 16 / 255, opacity: 0.6)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color(hex: 0xEF4444).opacity(0.35), lineWidth: 1))
    }

    // MARK: Toast

    @ViewBuilder
    private var toastView: some View {
        if let t = toast {
            Text(t.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(t.error ? Palette.bad : Palette.foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Palette.card))
                .overlay(Capsule().strokeBorder(t.error ? Palette.bad.opacity(0.4) : Palette.border, lineWidth: 1))
                .padding(.top, 70)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: t.id) {
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    withAnimation { toast = nil }
                }
        }
    }

    private func show(_ text: String, error: Bool = false) {
        withAnimation { toast = SettingsToast(text: text, error: error) }
        if error { Haptics.wrong() } else { Haptics.correct() }
    }

    // MARK: Actions (bodies as the browser sends them)

    @MainActor
    private func changeUsername() async {
        guard busy == nil else { return }
        let name: String = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !namePassword.isEmpty else { show("Fill in both fields", error: true); return }
        busy = "username"
        defer { busy = nil }
        do {
            let answer: UsernameChange = try await api.call("/account/change-username",
                                                            body: ["username": name, "password": namePassword])
            if let t = answer.token { api.replaceToken(t) }
            newName = ""
            namePassword = ""
            show("Username changed")
            await api.refreshProfile()
        } catch {
            show(error.localizedDescription.isEmpty ? "Could not change your username" : error.localizedDescription, error: true)
        }
    }

    @MainActor
    private func changePassword() async {
        guard busy == nil else { return }
        guard !currentPassword.isEmpty, !newPassword.isEmpty else { show("Fill in every field", error: true); return }
        guard newPassword == repeatPassword else { show("The new passwords do not match", error: true); return }
        busy = "password"
        defer { busy = nil }
        do {
            let _: Api.Ack = try await api.call("/account/change-password",
                                                body: ["currentPassword": currentPassword, "newPassword": newPassword])
            currentPassword = ""
            newPassword = ""
            repeatPassword = ""
            show("Password changed")
        } catch {
            show(error.localizedDescription.isEmpty ? "Could not change your password" : error.localizedDescription, error: true)
        }
    }

    @MainActor
    private func redeem() async {
        let c: String = code.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty, busy == nil else { return }
        busy = "redeem"
        defer { busy = nil }
        do {
            let r: RedeemResult = try await api.call("/redeem", body: ["code": c])
            code = ""
            show("Redeemed — \(r.reward)")
            await api.refreshProfile()
        } catch {
            show(error.localizedDescription.isEmpty ? "That code did not work" : error.localizedDescription, error: true)
        }
    }

    @MainActor
    private func makeLinkCode() async {
        guard busy == nil else { return }
        busy = "discord"
        defer { busy = nil }
        do {
            let r: DiscordLinkCode = try await api.call("/discord/link-code")
            linkCode = LinkCodeState(code: r.code, until: Date().addingTimeInterval(900))
        } catch {
            show(error.localizedDescription.isEmpty ? "Could not create a link code" : error.localizedDescription, error: true)
        }
    }

    @MainActor
    private func unlinkDiscord() async {
        guard busy == nil else { return }
        busy = "discord"
        defer { busy = nil }
        do {
            let _: Api.Ack = try await api.call("/discord/unlink")
            discord = try? await api.fetch("/discord/status")
            show("Discord disconnected")
        } catch {
            show(error.localizedDescription.isEmpty ? "Could not disconnect Discord" : error.localizedDescription, error: true)
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard busy == nil, !deletePassword.isEmpty else { return }
        busy = "delete"
        defer { busy = nil }
        do {
            let _: Api.Ack = try await api.call("/account/delete", method: "DELETE", body: ["password": deletePassword])
            api.logOut()
            close()
        } catch {
            show(error.localizedDescription.isEmpty ? "Could not delete your account" : error.localizedDescription, error: true)
        }
    }
}

// MARK: - Pieces

private struct SettingsToast: Equatable {
    let id = UUID()
    let text: String
    let error: Bool
}

struct LinkCodeState: Equatable {
    let code: String
    let until: Date
}

private enum SettingsPalette {
    /// The browser's form fields: rgba(10,9,20,.72).
    static let field = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.72)
}

/// A settings card: header row with icon + uppercase title in purple (or the
/// given tint), a line, then the content with 12 padding.
private struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    var tint: Color = Palette.accent
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title.uppercased()).font(.system(size: 12, weight: .bold)).tracking(1.2)
            }
            .foregroundColor(tint)
            .padding(.horizontal, 16)
            .frame(height: 42, alignment: .leading)
            Rectangle().fill(Palette.border).frame(height: 1)
            content.padding(12)
        }
        .background(shape.fill(Palette.card))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }
}

/// 40 tall, corners 20, field fill, border white 8 %, 13 pt.
private struct SettingsField: View {
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false

    var body: some View {
        Group {
            if secure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Palette.faint))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Palette.faint))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 13))
        .foregroundColor(Palette.foreground)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 20, style: .circular).fill(SettingsPalette.field))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .circular).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

/// The purple "✓ Change" button: 44 tall, corners 18.
private struct SettingsPrimaryButton: View {
    let title: String
    let symbol: String
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                }
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Palette.accent))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}

/// "Discord / Report a bug / Legal & privacy": icon, title 12 bold, sub 10, arrow.
private struct SettingsLinkRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let trailing: String
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .circular)
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 14)).foregroundColor(tint).frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(Palette.foreground)
                    Text(subtitle).font(.system(size: 10)).foregroundColor(Palette.subdued)
                }
                Spacer(minLength: 0)
                Image(systemName: trailing).font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.subdued)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(shape.fill(Color.white.opacity(0.03)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Avatar with level badge, title, name, GAMES / WINS and the XP bar.
private struct SettingsProfileCard: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        let xp: Int = api.me?.xp ?? 0
        let level: Int = Api.Level.forXP(xp)
        let low: Int = Api.Level.minXP(level)
        let high: Int = Api.Level.minXP(level + 1)
        let fraction: Double = Api.Level.fraction(xp: xp)
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: 0xCC95FF))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().strokeBorder(Palette.accent.opacity(0.7), lineWidth: 2))
                    Text("\(level)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(hex: 0x07070E))
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Circle().fill(Color(hex: 0xF59E0B)))
                        .overlay(Circle().strokeBorder(Color(hex: 0x181727), lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "crown").font(.system(size: 8, weight: .bold))
                        Text("NEWBIE").font(.system(size: 10, weight: .bold)).tracking(1)
                    }
                    .foregroundColor(Color(hex: 0xF59E0B))
                    Text(api.me?.username ?? "")
                        .font(.brand(22, .heavy))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                counter(api.me?.games_played ?? 0, "GAMES")
                Rectangle().fill(Palette.border).frame(width: 1, height: 30)
                counter(api.me?.wins ?? 0, "WINS")
            }
            HStack {
                Text("\(max(0, xp - low)) / \(max(1, high - low)) XP to Lv.\(level + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Palette.subdued)
                Spacer(minLength: 0)
                Text(String(format: "%.1f%%", fraction * 100))
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundColor(Palette.accent)
            }
            GeometryReader { box in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(Palette.accent).frame(width: box.size.width * CGFloat(min(1, max(0, fraction))))
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(shape.fill(LinearGradient(colors: [Palette.accentDeep.opacity(0.18), Palette.card],
                                              startPoint: .top, endPoint: .bottom)))
        .overlay(shape.strokeBorder(Palette.accent.opacity(0.35), lineWidth: 1))
    }

    private func counter(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.brand(18, .heavy)).foregroundColor(Palette.foreground)
            Text(label).font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(Palette.subdued)
        }
    }
}

/// The Discord link code dialog (`w8`): code big and spaced, copy button,
/// the three steps, "valid for mm:ss", and "This code expired." + "New code".
private struct DiscordCodeDialog: View {
    let state: LinkCodeState
    let close: () -> Void
    let regenerate: () -> Void
    @State private var copied = false

    var body: some View {
        ZStack {
            Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.75)
                .ignoresSafeArea()
                .onTapGesture { close() }
            TimelineView(.periodic(from: Date(), by: 0.5)) { context in
                card(remaining: max(0, state.until.timeIntervalSince(context.date)))
            }
            .frame(maxWidth: 380)
            .padding(16)
        }
    }

    private func card(remaining: TimeInterval) -> some View {
        let expired: Bool = remaining <= 0
        let minutes: Int = Int(remaining) / 60
        let seconds: Int = Int(remaining) % 60
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("CONNECT DISCORD", systemImage: "bubble.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Palette.discord)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(Palette.subdued)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            HStack(spacing: 8) {
                Text(state.code)
                    .font(.brand(24, .heavy))
                    .tracking(5.8)
                    .strikethrough(expired)
                    .foregroundColor(expired ? Palette.subdued : Palette.foreground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .circular).fill(Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.8)))
                Button {
                    UIPasteboard.general.string = state.code
                    copied = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12))
                        Text(copied ? "Copied" : "Copy").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(copied ? Palette.good : Color(hex: 0xC9C8E0))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .circular).fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .disabled(expired)
            }
            if expired {
                HStack {
                    Text("This code expired.").font(.system(size: 12)).foregroundColor(Palette.subdued)
                    Spacer()
                    Button("New code", action: regenerate)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Palette.discord)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    step(1, Text("Copy the code"))
                    step(2, Text("Open the Fakester Discord"))
                    step(3, Text("Run ") + Text("/link").bold().foregroundColor(Palette.foreground) + Text(" and paste it"))
                }
                Text(String(format: "Valid for %d:%02d", minutes, seconds))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(Palette.subdued)
                Button {
                    if let url = URL(string: "https://discord.gg/4s6Mdy7hjN") { UIApplication.shared.open(url) }
                } label: {
                    Text("Open Discord")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 16, style: .circular).fill(Palette.discord))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)))
        .overlay(shape.strokeBorder(Palette.discord.opacity(0.45), lineWidth: 1))
    }

    private func step(_ n: Int, _ text: Text) -> some View {
        HStack(spacing: 8) {
            Text("\(n)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Palette.discord)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Palette.discord.opacity(0.15)))
            text.font(.system(size: 12)).foregroundColor(Palette.subdued)
        }
    }
}
