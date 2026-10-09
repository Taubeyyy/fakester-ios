import SwiftUI

/// "Create Game" as on fakester.app (measured at 375×812): a header with a round
/// back button, the title and a NEW badge; card 1 Playlist, card 2 Mode, card 3
/// Settings; a fixed bar at the bottom with "Private" and "Public".
///
/// The app only knows one mode - Quiz. Timeline and Higher / Lower have their own
/// round screens that the app does not have yet; offering them would send players
/// into a round they cannot play. So their tiles stay visible but disabled.
///
/// The app also sends exactly one playlist per game (see `GameSetup`), so adding a
/// new one replaces the current one instead of building a weighted mix.
struct CreateGameView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game
    @Environment(\.dismiss) private var close

    @State private var setup = GameSetup()
    @State private var featuredPlaylists: [PlaylistEntry] = []
    /// The player's saved playlists, listed after the featured ones (as in `F3`).
    @State private var savedPlaylists: [PlaylistEntry] = []
    @State private var link = ""
    @State private var searching = false
    @State private var errorMessage: String?
    @State private var moreOptions = false
    @State private var check: PlaylistCheckState = .idle
    @State private var modeNote = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    playlistCard
                    modeCard
                    settingsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                // pb-20 in the browser: the last card ends well above the bar
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Backdrop())
        .task { await loadFeatured() }
        .onChange(of: setup.playlist) { _ in
            check = .idle
        }
    }

    // MARK: Header

    /// 65 high: 14/16 padding, back button 36 (rounded, --acc arrow 15), title
    /// 25 pt extra bold with -0.625 tracking, NEW badge on the right, rgba(7,7,14,.82)
    /// with a hairline at the bottom.
    private var header: some View {
        HStack(spacing: 12) {
            Button {
                close()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Palette.accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.04)))
                    .overlay(Circle().strokeBorder(Palette.border, lineWidth: 1))
                    .overlay(EdgeHighlight(radius: 18, intensity: 0.05))
            }
            .buttonStyle(CreatePressStyle(depth: 0.92))
            .accessibilityLabel(Text("Back"))

            Text("Create Game")
                .font(.brand(25, .heavy))
                .tracking(-0.625)
                .foregroundColor(Palette.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Text("NEW")
                .font(.brand(10, .bold))
                .foregroundColor(CreateInk.amber)
                .padding(.horizontal, 8)
                .frame(height: 21)
                .background(Capsule().fill(CreateInk.amber.opacity(0.2)))
                .overlay(Capsule().strokeBorder(CreateInk.amber.opacity(0.3), lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CreateInk.headerFill.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    // MARK: 1 Playlist

    private var playlistCard: some View {
        CreateSection(step: 1, title: "Playlist", trailing: {
            Text("REQUIRED")
                .font(.brand(10, .bold))
                .foregroundColor(Palette.bad)
                .padding(.horizontal, 6)
                .frame(height: 19)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(CreateInk.red.opacity(0.15)))
        }, content: {
            VStack(alignment: .leading, spacing: 12) {
                playlistIntro
                VStack(alignment: .leading, spacing: 10) {
                    linkRow
                    if let message = errorMessage {
                        Text(message)
                            .font(.brand(11, .semibold))
                            .foregroundColor(Palette.bad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let chosen = setup.playlist {
                        MixRow(entry: chosen,
                               status: check,
                               onCheck: { Task { await checkPlaylist() } },
                               onRemove: { removePlaylist() })
                        checkRow
                    }
                    if !featuredPlaylists.isEmpty || !savedPlaylists.isEmpty {
                        featuredList
                    }
                }
            }
        })
    }

    /// The browser says "Add one or more … playlists. With several, − and +
    /// decide how many songs come from each." The app sends a single playlist,
    /// so it only promises that.
    private var playlistIntro: some View {
        HStack(spacing: 6) {
            Text("Add a")
                .lineLimit(1)
            SpotifyLogo(dimension: 14)
            Text("Spotify or")
                .lineLimit(1)
            YouTubeLogo(dimension: 14)
            Text("YouTube playlist.")
                .lineLimit(1)
        }
        .font(.brand(11))
        .foregroundColor(Palette.subdued)
        .minimumScaleFactor(0.8)
    }

    /// Field rgba(10,9,20,.6) 36 high with 12 pt text, next to the "+ Add" pill.
    private var linkRow: some View {
        HStack(spacing: 8) {
            TextField("", text: $link,
                      prompt: Text("Paste a Spotify or YouTube link…").foregroundColor(Palette.faint))
                .font(.brand(12))
                .foregroundColor(Palette.foreground)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit { Task { await checkLink() } }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Capsule().fill(CreateInk.fieldFill))
                .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))

            Button {
                Task { await checkLink() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(searching ? "…" as String : "Add" as String)
                        .font(.brand(12, .bold))
                }
                .foregroundColor(Palette.onAccent)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Capsule().fill(Palette.accent))
                .opacity(searching ? 0.6 : 1)
            }
            .buttonStyle(CreatePressStyle())
            .disabled(searching || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(Text("Add"))
        }
    }

    /// "Check playlist": pill 31 high, 11 pt bold; the result sits next to it in
    /// green (or red when nothing was found), as in the browser.
    private var checkRow: some View {
        let busy: Bool = check == .reading
        let caption: String = busy ? "Checking…" : "Check playlist"
        return HStack(spacing: 8) {
            Button {
                Task { await checkPlaylist() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                    Text(caption)
                        .font(.brand(11, .bold))
                }
                .foregroundColor(busy ? Palette.subdued : Palette.foreground)
                .padding(.horizontal, 12)
                .frame(height: 31)
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .overlay(Capsule().strokeBorder(Palette.rim, lineWidth: 1))
                .opacity(busy ? 0.7 : 1)
            }
            .buttonStyle(CreatePressStyle())
            .disabled(busy)

            if let found = foundSongs {
                Text(foundCaption(found))
                    .font(.brand(11, .semibold))
                    .foregroundColor(found > 0 ? Palette.good : Palette.bad)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var foundSongs: Int? {
        if case .done(let count) = check { return count }
        return nil
    }

    private func foundCaption(_ count: Int) -> String {
        count == 1 ? "1 song found" : "\(count) songs found"
    }

    private var featuredList: some View {
        VStack(spacing: 6) {
            ForEach(featuredPlaylists) { entry in
                LibraryRow(entry: entry, selected: setup.playlist?.id == entry.id) {
                    toggleFeatured(entry)
                }
            }
            ForEach(savedPlaylists.filter { s in !featuredPlaylists.contains { $0.id == s.id } }) { entry in
                LibraryRow(entry: entry, selected: setup.playlist?.id == entry.id) {
                    toggleFeatured(entry)
                }
            }
        }
    }

    // MARK: 2 Mode

    private var modeCard: some View {
        CreateSection(step: 2, title: "Mode", trailing: {
            EmptyView()
        }, content: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    CreateModeTile(symbol: "questionmark.circle", title: "Quiz",
                                   detail: "Guess title, artist, year", available: true) {}
                    CreateModeTile(symbol: "calendar", title: "Timeline",
                                   detail: "Order songs by year", available: false) {
                        showModeNote()
                    }
                    CreateModeTile(symbol: "chevron.up.chevron.down", title: "Higher / Lower",
                                   detail: "Which song is more popular?", available: false) {
                        showModeNote()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                if modeNote {
                    Text("Timeline and Higher / Lower are browser-only for now.")
                        .font(.brand(11))
                        .foregroundColor(Palette.subdued)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
        })
    }

    // MARK: 3 Settings

    private var settingsCard: some View {
        CreateSection(step: 3, title: "Settings", trailing: {
            Button {
                resetSettings()
            } label: {
                Text("RESET")
                    .font(.brand(10, .bold))
                    .tracking(1)
                    .foregroundColor(Palette.subdued)
                    .padding(.horizontal, 6)
                    .frame(height: 19)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(CreatePressStyle())
            .accessibilityLabel(Text("Reset"))
        }, content: {
            VStack(alignment: .leading, spacing: 16) {
                CreateNumberRow(label: "SONGS", presets: GameSetup.songChoices, unit: "",
                                minimum: 1, maximum: nil, value: $setup.songs)
                CreateNumberRow(label: "GUESS TIME", presets: GameSetup.timeChoices, unit: "s",
                                minimum: 5, maximum: nil, value: $setup.guessSeconds)
                guessKinds
                moreButton
                if moreOptions {
                    moreSection
                        .transition(.opacity)
                }
            }
        })
    }

    private var guessKinds: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT TO GUESS?").eyebrow()
            HStack(spacing: 8) {
                CreateChip(text: "Title", on: $setup.heading)
                CreateChip(text: "Artist", on: $setup.guessArtist)
                CreateChip(text: "Year", on: $setup.guessYear)
            }
        }
    }

    /// Full width, 34 high, rgba(255,255,255,.03), 12 pt semibold; the chevron
    /// turns over when open.
    private var moreButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.25)) { moreOptions.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(moreOptions ? 180 : 0))
                Text(moreOptions ? "Fewer options" as String : "More options" as String)
                    .font(.brand(12, .semibold))
            }
            .foregroundColor(Palette.subdued)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.03)))
            .contentShape(Rectangle())
        }
        .buttonStyle(CreatePressStyle(depth: 0.98))
    }

    /// Opened by "More options": ANSWER TYPE, BREAK BETWEEN ROUNDS and the
    /// switches, 12 apart. The browser also offers Speaker Mode here, but
    /// `GameSetup` always sends `boxMode: false`, so the app leaves it out.
    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            answerKind
            CreateNumberRow(label: "BREAK BETWEEN ROUNDS", presets: GameSetup.pauseChoices, unit: "s",
                            minimum: 2, maximum: 15, value: $setup.pause)
            CreateSwitchRow(title: "Album cover",
                            hint: "show the artwork while guessing",
                            on: $setup.cover)
            CreateSwitchRow(title: "Speed bonus",
                            hint: "extra points for answering fast — only if everything was right",
                            on: $setup.speedBonusEnabled)
            CreateSwitchRow(title: "Streak bonus",
                            hint: "extra points for several fully correct answers in a row",
                            on: $setup.streakBonusEnabled)
            CreateSwitchRow(title: "Sneaky Mode",
                            hint: "no right/wrong until the very end",
                            on: $setup.sneaky)
        }
    }

    private var answerKind: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANSWER TYPE").eyebrow()
            HStack(spacing: 8) {
                CreateAnswerOption(text: "Multiple choice", on: !setup.freeText) { setup.freeText = false }
                CreateAnswerOption(text: "Free text", on: setup.freeText) { setup.freeText = true }
            }
        }
    }

    // MARK: Bottom bar

    /// rgba(7,7,14,.95) with a hairline on top, 12/16 padding. Without a playlist
    /// the hint shows and both buttons are faded (Private .4, Public .5) and inert.
    private var footer: some View {
        let ready: Bool = setup.playlist != nil
        return VStack(spacing: 8) {
            if !ready {
                Text("Add a playlist to create a lobby")
                    .font(.brand(11))
                    .foregroundColor(Palette.subdued)
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: 8) {
                Button {
                    proceed(isPublic: false)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock")
                            .font(.system(size: 14, weight: .medium))
                        Text("Private")
                    }
                }
                .buttonStyle(CreateFooterButtonStyle(isPublic: false, enabled: ready))
                .disabled(!ready)
                .accessibilityLabel(Text("Private"))

                Button {
                    proceed(isPublic: true)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 14, weight: .medium))
                        Text("Public")
                    }
                }
                .buttonStyle(CreateFooterButtonStyle(isPublic: true, enabled: ready))
                .disabled(!ready)
                .accessibilityLabel(Text("Public"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(CreateInk.footerFill.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    // MARK: Flow

    @MainActor
    private func proceed(isPublic: Bool) {
        var v: GameSetup = setup
        v.isPublic = isPublic
        guard let payloadObject = v.payloadObject(), let who = api.identity else { return }
        Haptics.lock()
        close()
        game.createGame(payloadObject, asPlayer: who)
    }

    @MainActor
    private func loadFeatured() async {
        if let e: FeaturedPlaylists = try? await api.fetch("/playlists/featured") {
            featuredPlaylists = e.entries
            if setup.playlist == nil, let firstFeatured = e.entries.first { setup.playlist = firstFeatured }
        }
        if api.isLoggedIn, let mine: SavedPlaylistList = try? await api.fetch("/profile") {
            savedPlaylists = mine.items.map { p in
                PlaylistEntry(id: p.id, name: p.name, picture: p.image, origin: p.source)
            }
        }
    }

    @MainActor
    private func checkLink() async {
        let url: String = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !searching else { return }
        searching = true
        errorMessage = nil
        defer { searching = false }
        do {
            let info: PlaylistInfo = try await api.fetch("/playlist/info", ["url": url])
            setup.playlist = info.entry
            link = ""
            Haptics.correct()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.wrong()
        }
    }

    /// The browser streams `/playlist/test` and counts playable songs. The app
    /// stays with the endpoint it already uses: `/playlist/info` reads the
    /// playlist again (a full link works, checked live) and reports its size.
    @MainActor
    private func checkPlaylist() async {
        guard let chosen = setup.playlist, check != .reading else { return }
        Haptics.tap()
        check = .reading
        let address: String = chosen.origin == "youtube"
            ? "https://www.youtube.com/playlist?list=\(chosen.id)"
            : "https://open.spotify.com/playlist/\(chosen.id)"
        do {
            let info: PlaylistInfo = try await api.fetch("/playlist/info", ["url": address])
            guard setup.playlist?.id == chosen.id else { return }
            check = .done(info.trackCount)
        } catch {
            guard setup.playlist?.id == chosen.id else { return }
            check = .failed("Could not check that playlist")
        }
    }

    private func removePlaylist() {
        Haptics.tap()
        setup.playlist = nil
    }

    /// Tapping a library row toggles it, as in the browser - with a single
    /// playlist that means: pick this one, or drop it if it is already picked.
    private func toggleFeatured(_ entry: PlaylistEntry) {
        Haptics.tap()
        if setup.playlist?.id == entry.id {
            setup.playlist = nil
        } else {
            setup.playlist = entry
        }
    }

    /// Back to the defaults, like "Reset" in the browser - the playlist stays.
    private func resetSettings() {
        Haptics.tap()
        let kept: PlaylistEntry? = setup.playlist
        var fresh = GameSetup()
        fresh.playlist = kept
        withAnimation(.easeOut(duration: 0.18)) { setup = fresh }
    }

    private func showModeNote() {
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.2)) { modeNote = true }
    }
}

// MARK: - Colors

/// Values from the create screen that the shared palette does not have.
private enum CreateInk {
    static let amber = Color(hex: 0xF59E0B)                  // NEW badge
    static let red = Color(hex: 0xEF4444)                    // REQUIRED background
    static let lilac = Color(hex: 0xB0AED2)                  // idle mode label, "…" icon
    static let dim = Color(hex: 0x6A6889)                    // mode subtitles and icons
    static let spotify = Color(hex: 0x1DB954)
    static let spotifySoft = Color(hex: 0x3EC574)            // source colour in the library rows
    static let youtube = Color(hex: 0xFF0000)
    static let youtubeSoft = Color(hex: 0xF06A6A)
    static let headerFill = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.82)
    static let footerFill = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.95)
    static let fieldFill = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)
    static let editorFill = Color(.sRGB, red: 8 / 255, green: 7 / 255, blue: 18 / 255, opacity: 0.8)
    static let privateFill = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
}

// MARK: - Building blocks

/// Result of "Check playlist".
private enum PlaylistCheckState: Equatable {
    case idle
    case reading
    case done(Int?)
    case failed(String)
}

/// Shrinks slightly while pressed (framer-motion whileTap in the browser).
private struct CreatePressStyle: ButtonStyle {
    var depth: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? depth : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A card like in the browser: rgba(24,23,39,.92), radius 16, --border edge.
/// Header row 12/16 padding with the numbered dot (20, --acc, 10 pt bold) and a
/// 15 pt bold title, a hairline below, then the body with 16 padding.
private struct CreateSection<Trailing: View, Content: View>: View {
    let step: Int
    let title: String
    let trailing: Trailing
    let content: Content

    init(step: Int, title: String,
         @ViewBuilder trailing: () -> Trailing,
         @ViewBuilder content: () -> Content) {
        self.step = step
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: "\(step)")
                    .font(.brand(10, .bold))
                    .foregroundColor(Palette.onAccent)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Palette.accent))
                Text(title)
                    .font(.brand(15, .bold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                Spacer(minLength: 0)
                trailing
            }
            .frame(height: 23)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(Palette.border).frame(height: 1)

            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(shape.fill(Palette.card))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }
}

// MARK: Playlist pieces

/// The Spotify mark drawn by hand: a circle with three arcs (traced from the
/// SVG in the bundle). `mono` cuts the arcs out of a single colour, like
/// `mono` in the browser; otherwise green with white arcs.
private struct SpotifyLogo: View {
    let dimension: CGFloat
    var hue: Color = CreateInk.spotify
    var mono: Bool = false

    var body: some View {
        let k: CGFloat = dimension / 24
        let ink: Color = mono ? Color.black : Color.white
        return ZStack {
            Circle().fill(hue)
            ZStack {
                SpotifyArc(start: CGPoint(x: 4.83, y: 8.25), control1: CGPoint(x: 8.79, y: 7.05),
                           control2: CGPoint(x: 15.51, y: 7.29), end: CGPoint(x: 19.65, y: 9.75))
                    .stroke(ink, style: StrokeStyle(lineWidth: 2.2 * k, lineCap: .round))
                SpotifyArc(start: CGPoint(x: 5.49, y: 12.09), control1: CGPoint(x: 9.57, y: 10.83),
                           control2: CGPoint(x: 14.73, y: 11.46), end: CGPoint(x: 18.21, y: 13.59))
                    .stroke(ink, style: StrokeStyle(lineWidth: 1.8 * k, lineCap: .round))
                SpotifyArc(start: CGPoint(x: 5.76, y: 15.72), control1: CGPoint(x: 10.14, y: 14.73),
                           control2: CGPoint(x: 13.89, y: 15.12), end: CGPoint(x: 16.86, y: 16.95))
                    .stroke(ink, style: StrokeStyle(lineWidth: 1.5 * k, lineCap: .round))
            }
            .blendMode(mono ? BlendMode.destinationOut : BlendMode.normal)
        }
        .compositingGroup()
        .frame(width: dimension, height: dimension)
        .accessibilityHidden(true)
    }
}

/// One arc of the Spotify mark, in the 24×24 space of the original SVG.
private struct SpotifyArc: Shape {
    let start: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        let k: CGFloat = min(rect.width, rect.height) / 24
        let x0: CGFloat = rect.minX
        let y0: CGFloat = rect.minY
        func place(_ p: CGPoint) -> CGPoint {
            CGPoint(x: x0 + p.x * k, y: y0 + p.y * k)
        }
        var path = Path()
        path.move(to: place(start))
        path.addCurve(to: place(end), control1: place(control1), control2: place(control2))
        return path
    }
}

/// The YouTube mark: red rounded rectangle with a white play triangle;
/// `mono` cuts the triangle out instead.
private struct YouTubeLogo: View {
    let dimension: CGFloat
    var hue: Color = CreateInk.youtube
    var mono: Bool = false

    var body: some View {
        let k: CGFloat = dimension / 24
        return ZStack {
            RoundedRectangle(cornerRadius: 4.5 * k, style: .continuous)
                .fill(hue)
                .frame(width: dimension, height: 16.9 * k)
            YouTubePlay()
                .fill(mono ? Color.black : Color.white)
                .blendMode(mono ? BlendMode.destinationOut : BlendMode.normal)
        }
        .compositingGroup()
        .frame(width: dimension, height: dimension)
        .accessibilityHidden(true)
    }
}

private struct YouTubePlay: Shape {
    func path(in rect: CGRect) -> Path {
        let k: CGFloat = min(rect.width, rect.height) / 24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 9.545 * k, y: rect.minY + 8.432 * k))
        path.addLine(to: CGPoint(x: rect.minX + 15.818 * k, y: rect.minY + 12 * k))
        path.addLine(to: CGPoint(x: rect.minX + 9.545 * k, y: rect.minY + 15.568 * k))
        path.closeSubpath()
        return path
    }
}

/// The 32×32 picture of a playlist (radius 14): the cover if there is one,
/// otherwise the source mark in one colour.
private struct PlaylistCover: View {
    let entry: PlaylistEntry
    let glyphSize: CGFloat
    let tint: Color
    let fill: Color
    var rim: Color = Color.clear

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(pictureURL == nil ? fill : Palette.muted)
            if let url = pictureURL {
                AsyncImage(url: url) { phase in
                    if let picture = phase.image {
                        picture.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            } else if entry.origin == "youtube" {
                YouTubeLogo(dimension: glyphSize, hue: tint, mono: true)
            } else {
                SpotifyLogo(dimension: glyphSize, hue: tint, mono: true)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(shape)
        .overlay(shape.strokeBorder(rim, lineWidth: 1))
    }

    private var pictureURL: URL? {
        guard let s = entry.picture, !s.isEmpty else { return nil }
        return URL(string: s)
    }
}

/// The picked playlist (the "mix" in the browser): rgba(255,255,255,.03), edge
/// white 8 %, radius 18, 10/12 padding; name 12 pt semibold, source 10 pt
/// below, and the "…" options button (28, radius 14).
private struct MixRow: View {
    let entry: PlaylistEntry
    let status: PlaylistCheckState
    let onCheck: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return HStack(spacing: 10) {
            PlaylistCover(entry: entry, glyphSize: 14, tint: Palette.foreground,
                          fill: Color.white.opacity(0.05), rim: Palette.border)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.name)
                    .font(.brand(12, .semibold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                    .frame(height: 18)
                statusLine
                    .font(.brand(10))
                    .lineLimit(1)
                    .frame(height: 15)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            optionsMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(shape.fill(Color.white.opacity(0.03)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var sourceName: String {
        entry.origin == "youtube" ? "YouTube" : "Spotify"
    }

    private var statusLine: Text {
        switch status {
        case .idle:
            return Text(sourceName).foregroundColor(Palette.subdued)
        case .reading:
            return Text("reading…").foregroundColor(Palette.subdued)
        case .done(let count):
            if let n = count {
                let words: String = n == 1 ? "1 song" : "\(n) songs"
                return Text(sourceName + " · " + words).foregroundColor(Palette.subdued)
            }
            return Text(sourceName).foregroundColor(Palette.subdued)
        case .failed(let message):
            return Text(message).foregroundColor(Palette.bad)
        }
    }

    /// The browser opens a sheet with "Check songs" and "Remove" (and a song
    /// cap the app cannot send); here it is a menu with the two that work.
    private var optionsMenu: some View {
        Menu {
            Button {
                onCheck()
            } label: {
                Label("Check songs", systemImage: "magnifyingglass")
            }
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CreateInk.lilac)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.border, lineWidth: 1))
        }
        .accessibilityLabel(Text("Options for \(entry.name)"))
    }
}

/// A playlist from the library (Featured): 54 high, radius 18, 10/12 padding;
/// picture tinted in the source colour at 13 %, name 13 pt semibold, the small
/// source mark and a 20 dot - "+" in white 8 %, or a check on --acc when picked.
private struct LibraryRow: View {
    let entry: PlaylistEntry
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let soft: Color = entry.origin == "youtube" ? CreateInk.youtubeSoft : CreateInk.spotifySoft
        return Button(action: onTap) {
            HStack(spacing: 12) {
                PlaylistCover(entry: entry, glyphSize: 15, tint: soft, fill: soft.opacity(0.13))
                Text(entry.name)
                    .font(.brand(13, .semibold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                sourceMark
                ZStack {
                    Circle().fill(selected ? Palette.accent : Color.white.opacity(0.08))
                    Image(systemName: selected ? "checkmark" : "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(selected ? Palette.onAccent : Palette.subdued)
                }
                .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(shape.fill(selected ? Palette.accent.opacity(0.10) : Color.white.opacity(0.03)))
            .overlay(shape.strokeBorder(selected ? Palette.accent.opacity(0.4) : Palette.border, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(CreatePressStyle(depth: 0.98))
        .accessibilityLabel(Text(entry.name))
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }

    @ViewBuilder
    private var sourceMark: some View {
        if entry.origin == "youtube" {
            YouTubeLogo(dimension: 12)
        } else {
            SpotifyLogo(dimension: 12)
        }
    }
}

// MARK: Mode pieces

/// A mode tile: 16/8 padding, radius 16, icon box 40 (radius 18), name 11 pt
/// bold, description 10 pt. Picked: rgba(112,0,215,.22), edge --acc 60 %,
/// purple glow; otherwise white 2 % with a white 7 % edge. Modes the app cannot
/// play are faded and only explain themselves when tapped.
private struct CreateModeTile: View {
    let symbol: String
    let title: String
    let detail: String
    let available: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            tile
        }
        .buttonStyle(CreatePressStyle())
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(available ? "Selected" as String : "Not available in the app yet" as String))
        .accessibilityAddTraits(available ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let deep: Color = Palette.accentDeep
        return VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(available ? Palette.accent : CreateInk.dim)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(available ? deep.opacity(0.3) : Color.white.opacity(0.05)))
            Text(title)
                .font(.brand(11, .bold))
                .foregroundColor(available ? Palette.foreground : CreateInk.lilac)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.brand(10))
                .foregroundColor(CreateInk.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(shape.fill(available ? deep.opacity(0.22) : Color.white.opacity(0.02)))
        .overlay(shape.strokeBorder(available ? Palette.accent.opacity(0.6) : Palette.border, lineWidth: 1))
        .overlay(EdgeHighlight(radius: 16, intensity: available ? 0.08 : 0.03))
        .shadow(color: available ? deep.opacity(0.25) : Color.clear, radius: 12)
        .opacity(available ? 1 : 0.5)
    }
}

// MARK: Settings pieces

/// A round choice like "10" or "30s": 12/6 padding, 12 pt bold, capsule.
/// Picked: --acc at 18 % with a 55 % edge and --acc text; otherwise white 4 %,
/// edge white 8 %, #8d8ba4 text. The label stays the plain value - the UI test
/// taps these by "5", "20s" etc.
private struct CreatePill: View {
    let text: String
    let on: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            Text(text)
                .font(.brand(12, .bold))
                .foregroundColor(on ? Palette.accent : Palette.subdued)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(on ? Palette.accent.opacity(0.18) : Color.white.opacity(0.04)))
                .overlay(Capsule().strokeBorder(on ? Palette.accent.opacity(0.55) : Color.white.opacity(0.08),
                                                lineWidth: 1))
        }
        .buttonStyle(CreatePressStyle())
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

/// A row of fixed values plus the "set your own" pill (a wand, 25 high). Once a
/// custom value is set, that pill shows it in the picked look. Tapping it opens
/// a small number field (64 wide, placeholder "1+" or "2–15"); the value is
/// clamped like in the browser.
private struct CreateNumberRow: View {
    let label: String
    let presets: [Int]
    let unit: String
    let minimum: Int
    let maximum: Int?
    @Binding var value: Int

    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).eyebrow()
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { n in
                    CreatePill(text: "\(n)\(unit)", on: value == n) {
                        editing = false
                        value = n
                    }
                }
                if editing {
                    editor
                } else {
                    customPill
                }
            }
        }
    }

    private var isCustom: Bool { !presets.contains(value) }

    private var placeholder: String {
        if let top = maximum { return "\(minimum)–\(top)" }
        return "\(minimum)+"
    }

    private var customPill: some View {
        let on: Bool = isCustom
        return Button {
            Haptics.tap()
            draft = String(value)
            editing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        } label: {
            Group {
                if on {
                    Text(verbatim: "\(value)\(unit)")
                        .font(.brand(12, .bold))
                        .lineLimit(1)
                        .fixedSize()
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(on ? Palette.accent : Palette.subdued)
            .padding(.horizontal, 12)
            .frame(height: on ? 32 : 25)
            .background(Capsule().fill(on ? Palette.accent.opacity(0.18) : Color.white.opacity(0.04)))
            .overlay(Capsule().strokeBorder(on ? Palette.accent.opacity(0.55) : Color.white.opacity(0.08),
                                            lineWidth: 1))
        }
        .buttonStyle(CreatePressStyle())
        .accessibilityLabel(on ? Text(verbatim: "\(value)\(unit)") : Text("Set your own"))
    }

    /// The number pad has no return key, so a small check button confirms.
    private var editor: some View {
        HStack(spacing: 4) {
            TextField("", text: $draft, prompt: Text(placeholder).foregroundColor(Palette.faint))
                .font(.brand(12, .bold))
                .foregroundColor(Palette.accent)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .focused($focused)
                .onSubmit { commit() }
                .onChange(of: draft) { newValue in
                    let digits: String = newValue.filter { "0123456789".contains($0) }
                    if digits != newValue { draft = digits }
                }
                .onChange(of: focused) { isFocused in
                    if !isFocused && editing { commit() }
                }
                .padding(.horizontal, 8)
                .frame(width: 64, height: 32)
                .background(Capsule().fill(CreateInk.editorFill))
                .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.55), lineWidth: 1))

            Button {
                commit()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Palette.onAccent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Palette.accent))
            }
            .buttonStyle(CreatePressStyle())
            .accessibilityLabel(Text("Done"))
        }
    }

    private func commit() {
        if let typed = Int(draft) {
            var v: Int = max(minimum, typed)
            if let top = maximum { v = min(top, v) }
            value = v
        }
        editing = false
        draft = ""
        focused = false
    }
}

/// "What to guess?" chip: like a pill, with a small check while picked
/// (15 % fill, 50 % edge).
private struct CreateChip: View {
    let text: String
    @Binding var on: Bool

    var body: some View {
        Button {
            Haptics.tap()
            on.toggle()
        } label: {
            HStack(spacing: 6) {
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(text)
                    .font(.brand(12, .bold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(on ? Palette.accent : Palette.subdued)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(on ? Palette.accent.opacity(0.15) : Color.white.opacity(0.04)))
            .overlay(Capsule().strokeBorder(on ? Palette.accent.opacity(0.5) : Color.white.opacity(0.08),
                                            lineWidth: 1))
        }
        .buttonStyle(CreatePressStyle())
        .accessibilityLabel(Text(text))
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

/// "Answer type": two equal buttons, 36 high, radius 18, 12 pt bold.
private struct CreateAnswerOption: View {
    let text: String
    let on: Bool
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button {
            Haptics.tap()
            onTap()
        } label: {
            Text(text)
                .font(.brand(12, .bold))
                .foregroundColor(on ? Palette.accent : Palette.subdued)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(shape.fill(on ? Palette.accent.opacity(0.15) : Color.white.opacity(0.04)))
                .overlay(shape.strokeBorder(on ? Palette.accent.opacity(0.5) : Color.white.opacity(0.08),
                                            lineWidth: 1))
        }
        .buttonStyle(CreatePressStyle(depth: 0.98))
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

/// A switch row: rgba(255,255,255,.03), radius 18, 10/12 padding; name 13 pt
/// semibold, hint 10 pt in #8d8ba4.
private struct CreateSwitchRow: View {
    let title: String
    let hint: String
    @Binding var on: Bool

    var body: some View {
        Toggle(isOn: $on) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.brand(13, .semibold))
                    .foregroundColor(Palette.foreground)
                Text(hint)
                    .font(.brand(10))
                    .foregroundColor(Palette.subdued)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(CreateSwitchStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.03)))
    }
}

/// The browser's switch: 48×26; on = #7000d7 with a purple glow and the white
/// 20 knob on the right, off = white 10 % with the knob on the left. The whole
/// row toggles, not only the switch.
private struct CreateSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isOn: Bool = configuration.isOn
        return HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 0)
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Palette.accentDeep : Color.white.opacity(0.1))
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .padding(3)
            }
            .frame(width: 48, height: 26)
            .shadow(color: isOn ? Palette.accentDeep.opacity(0.4) : Color.clear, radius: 6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.18)) { configuration.isOn.toggle() }
        }
    }
}

// MARK: Bottom bar pieces

/// "Private": rgba(24,23,39,.9) with a --border edge, #eef text. "Public": --acc
/// with white text. Both 47 high, radius 16, 14 pt bold; inert ones are faded
/// (Private .4, Public on a dark purple at .5).
private struct CreateFooterButtonStyle: ButtonStyle {
    let isPublic: Bool
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let fill: Color = isPublic
            ? (enabled ? Palette.accent : Palette.accentDeep.opacity(0.3))
            : CreateInk.privateFill
        let edge: Color = isPublic ? Color.clear : Palette.border
        let faded: Double = isPublic ? 0.5 : 0.4
        let pressed: Bool = configuration.isPressed && enabled
        return configuration.label
            .font(.brand(14, .bold))
            .foregroundColor(isPublic ? Color.white : Palette.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 47)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(edge, lineWidth: 1))
            .opacity(enabled ? 1 : faded)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
