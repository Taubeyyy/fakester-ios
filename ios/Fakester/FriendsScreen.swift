import SwiftUI

/// "Friends" (`E3` in the web bundle): a card with the counts and "Add by
/// username", then incoming requests, the friends themselves (online dot,
/// remove) and the requests you sent. Pull down to refresh.
/// Measurements from the website at 375 × 812 (k-friends).
struct FriendsView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var list = FriendList(all: [])
    @State private var catalog: ItemCatalog?
    @State private var loading = true
    @State private var name: String = ""
    @State private var sending = false
    @State private var toast: CosmeticToast?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Friends", onBack: { close() })
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        topCard
                        if !list.requests.isEmpty { requestsSection }
                        friendsSection
                        if !list.waiting.isEmpty { waitingSection }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await load() }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .overlay(alignment: .top) { CosmeticToastView(toast: $toast) }
        .task { await start() }
    }

    @MainActor
    private func start() async {
        async let items: ItemCatalog? = try? await api.fetchAbsolute("https://fakester.app/catalog.json")
        await load()
        catalog = await items
    }

    // MARK: Top card

    private var topCard: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LucideGlyph(icon: .users, size: 20)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 16, style: .circular).fill(Palette.accent))
                    .shadow(color: Palette.accentDeep.opacity(0.4), radius: 10)
                HStack(spacing: 16) {
                    counter("\(list.friends.count)", "Friends", tint: Palette.foreground)
                    counter("\(list.onlineCount)", "Online", tint: Palette.good)
                }
            }
            HStack(spacing: 8) {
                let field = RoundedRectangle(cornerRadius: 18, style: .circular)
                HStack(spacing: 8) {
                    LucideGlyph(icon: .search, size: 13).foregroundColor(Palette.faint)
                    ZStack(alignment: .leading) {
                        if name.isEmpty {
                            Text("Add by username...").font(.brand(13)).foregroundColor(Palette.faint)
                        }
                        TextField("", text: $name)
                            .font(.brand(13))
                            .foregroundColor(Palette.foreground)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.send)
                            .focused($fieldFocused)
                            .onSubmit { Task { await sendRequest() } }
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(field.fill(Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)))
                .overlay(field.strokeBorder(Palette.border, lineWidth: 1))
                Button {
                    Task { await sendRequest() }
                } label: {
                    HStack(spacing: 6) {
                        LucideGlyph(icon: .userPlus, size: 14)
                        Text(sending ? "Sending…" : "Add")
                    }
                    .font(.brand(13, .bold))
                    .foregroundColor(Palette.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(field.fill(Palette.accent))
                    .opacity(sending ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(sending)
            }
        }
        .padding(16)
        .background(shape.fill(Palette.card).shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private func counter(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.brand(20, .heavy)).foregroundColor(tint)
            Text(label.uppercased()).font(.brand(10, .bold)).tracking(0.25).foregroundColor(Palette.subdued)
        }
    }

    // MARK: Sections

    private func heading(_ title: String, icon: LucideIcon, tint: Color, bar: Color) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(LinearGradient(colors: [bar, bar.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 2, height: 16)
            LucideGlyph(icon: icon, size: 12)
            Text(title.uppercased()).font(.brand(11, .bold)).tracking(1.1)
        }
        .foregroundColor(tint)
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Requests (\(list.requests.count))", icon: .bell, tint: Palette.gold, bar: Color(hex: 0xF59E0B))
            ForEach(list.requests) { f in
                FriendRow(friend: f, icon: icon(for: f), subtitle: "wants to be friends", style: .request) {
                    HStack(spacing: 4) {
                        squareButton(.check, tint: Palette.good, fill: Palette.good.opacity(0.12), edge: Palette.good.opacity(0.35),
                                     label: "Accept \(f.username)") { Task { await respond(f, accept: true) } }
                        squareButton(.x, tint: Palette.bad, fill: Color(hex: 0xEF4444).opacity(0.1), edge: Color(hex: 0xEF4444).opacity(0.3),
                                     label: "Decline \(f.username)") { Task { await respond(f, accept: false) } }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Friends", icon: .users, tint: Palette.subdued, bar: Palette.accentDeep)
            ForEach(list.friends) { f in
                FriendRow(friend: f, icon: icon(for: f), subtitle: nil, style: .friend) {
                    squareButton(.userMinus, tint: Palette.subdued, fill: Color.white.opacity(0.04), edge: Palette.border,
                                 label: "Remove \(f.username)") { Task { await remove(f) } }
                }
            }
            if list.friends.isEmpty {
                if loading {
                    BoardLoadingBars().frame(maxWidth: .infinity).padding(.vertical, 48)
                } else {
                    emptyState
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            LucideGlyph(icon: .users, size: 26)
                .foregroundColor(Palette.subdued)
                .frame(width: 64, height: 64)
                .background(Circle().fill(LinearGradient(colors: [Palette.accentDeep.opacity(0.15), Palette.accent.opacity(0.08)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(Circle().strokeBorder(Palette.accent.opacity(0.2), lineWidth: 1))
            VStack(spacing: 2) {
                Text("No friends yet").font(.brand(14, .semibold))
                Text("Add someone by their username, or add the people you just played with")
                    .font(.brand(11))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(Palette.subdued)
            Button {
                fieldFocused = true
            } label: {
                HStack(spacing: 8) {
                    LucideGlyph(icon: .userPlus, size: 14)
                    Text("Add a friend")
                }
                .font(.brand(13, .bold))
                .foregroundColor(Palette.onAccent)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Palette.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var waitingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Waiting", icon: .clock, tint: Palette.subdued, bar: Palette.subdued)
            ForEach(list.waiting) { f in
                FriendRow(friend: f, icon: icon(for: f), subtitle: "Request sent", style: .waiting) {
                    squareButton(.x, tint: Palette.subdued, fill: Color.white.opacity(0.04), edge: Palette.border,
                                 label: "Cancel request to \(f.username)") { Task { await remove(f) } }
                }
            }
        }
    }

    /// The 28 pt square buttons on the right of a row.
    private func squareButton(_ icon: LucideIcon, tint: Color, fill: Color, edge: Color,
                              label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LucideGlyph(icon: icon, size: 12)
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .circular).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .circular).strokeBorder(edge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private func icon(for f: FriendEntry) -> CatalogItem? {
        catalog?.item("icon", id: f.iconID)
    }

    // MARK: Data

    @MainActor
    private func load() async {
        loading = true
        do {
            list = try await api.fetch("/friends")
        } catch {
            #if DEBUG
            if let sample = ScreenshotScene.sampleFriends {
                list = sample
                loading = false
                return
            }
            #endif
            withAnimation { toast = CosmeticToast(text: "Could not load your friends", isError: true) }
        }
        loading = false
    }

    @MainActor
    private func sendRequest() async {
        let who: String = name.trimmingCharacters(in: .whitespaces)
        guard !who.isEmpty, !sending else { return }
        sending = true
        do {
            let _: Api.Ack = try await api.call("/friends/request", body: ["username": who])
            name = ""
            Haptics.correct()
            withAnimation { toast = CosmeticToast(text: "Request sent to \(who)", isError: false) }
            await load()
        } catch {
            Haptics.wrong()
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not send that request" : text, isError: true) }
        }
        sending = false
    }

    @MainActor
    private func respond(_ f: FriendEntry, accept: Bool) async {
        do {
            let payload: [String: Any] = ["friendshipId": f.friendshipValue, "accept": accept]
            let _: Api.Ack = try await api.call("/friends/respond", body: payload)
            Haptics.tap()
            await load()
        } catch {
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not answer that request" : text, isError: true) }
        }
    }

    @MainActor
    private func remove(_ f: FriendEntry) async {
        do {
            let _: Api.Ack = try await api.call("/friends/\(f.friendshipID.text)", method: "DELETE")
            Haptics.tap()
            await load()
        } catch {
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not remove that friend" : text, isError: true) }
        }
    }
}

/// One person: 40 avatar, name (+ PRO crown), a status line, buttons right.
private struct FriendRow<Actions: View>: View {
    enum Style { case request, friend, waiting }

    let friend: FriendEntry
    let icon: CatalogItem?
    let subtitle: String?
    let style: Style
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        HStack(spacing: 12) {
            PlayerAvatar(size: 40, picture: friend.avatarURL, icon: icon)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.username)
                        .font(.brand(13, .bold))
                        .foregroundColor(style == .waiting ? Palette.subdued : Palette.foreground)
                        .lineLimit(1)
                    if friend.isPro && style != .waiting {
                        LucideGlyph(icon: .crown, size: 11, weight: 2.5).foregroundColor(Palette.gold)
                            .accessibilityLabel(Text("PRO"))
                    }
                }
                if let s = subtitle {
                    Text(s).font(.brand(11)).foregroundColor(Palette.subdued)
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(friend.online ? Palette.good : Color(hex: 0x6A6889)).frame(width: 6, height: 6)
                        Text(friend.online ? "Online" : "Offline").font(.brand(11)).foregroundColor(Palette.subdued)
                    }
                }
            }
            Spacer(minLength: 0)
            actions()
        }
        .padding(12)
        .background(shape.fill(fill))
        .overlay(shape.strokeBorder(edge, lineWidth: 1))
    }

    private var fill: Color {
        switch style {
        case .request: return Color(hex: 0xF59E0B).opacity(0.07)
        case .friend: return Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.92)
        case .waiting: return Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.6)
        }
    }

    private var edge: Color {
        style == .request ? Color(hex: 0xF59E0B).opacity(0.28) : Palette.border
    }
}

/// A player's round avatar (`ct`): the picture if there is one, else their
/// equipped icon at 46 % in its colour (the person in --acc-pale by default).
struct PlayerAvatar: View {
    let size: CGFloat
    let picture: String?
    let icon: CatalogItem?

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            if let address = PlayerAvatar.url(picture) {
                AsyncImage(url: address) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        glyph
                    }
                }
            } else {
                glyph
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var glyph: some View {
        CosmeticGlyph(iconClass: icon?.iconClass ?? "fa-user", anim: icon?.anim, size: size * 0.46,
                      tint: CosmeticTone.representative(icon?.colorHex) ?? CosmeticTone.accentPale)
    }

    static func url(_ path: String?) -> URL? {
        guard let p = path, !p.isEmpty else { return nil }
        if p.hasPrefix("http") { return URL(string: p) }
        return URL(string: "https://fakester.app" + (p.hasPrefix("/") ? p : "/" + p))
    }
}
