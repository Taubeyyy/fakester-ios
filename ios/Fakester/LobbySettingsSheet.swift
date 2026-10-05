import SwiftUI

/// The host's "Lobby settings" sheet, rebuilt after fakester.app (375×812).
/// The browser opens it from the sliders button in the lobby header and from
/// "Settings" next to "Invite players"; only the host sees either.
///
/// Same frame as "Invite players": rises from the bottom, top corners 24,
/// rgba(24,23,39,.98), purple edge 32 %, at most 88 % of the height. Header:
/// sliders icon in a purple circle, "HOST" above "Lobby settings", close button.
/// The body scrolls: PLAYLISTS, MODE, SONGS, GUESS TIME, BREAK BETWEEN ROUNDS,
/// ANSWER TYPE, WHAT TO GUESS? and the switches. Footer: "Cancel" and "Save".
///
/// Where it differs from the browser, because the app cannot send it:
/// - the playlists are read-only (no link field, no "Add", no library, no
///   song steppers) - Save passes the lobby's mix back unchanged
///   (`GameSetup.settingsUpdate(keeping:)`);
/// - Timeline and Higher / Lower stay visible but disabled, as on Create Game;
/// - no Speaker Mode switch - the app does not offer it, Save keeps the lobby's value.
///
/// The browser draws this sheet in the system font (San Francisco on the
/// iPhone); only the title uses the page font (Helvetica, `Font.brand`).
struct LobbySettingsSheet: View {
    /// The lobby's settings right now: shown for the playlists and passed back on Save.
    let current: LobbySettings
    let save: ([String: Any]) -> Void
    let close: () -> Void

    /// The edited copy - starts from the lobby's values each time the sheet opens.
    @State private var setup: GameSetup
    @State private var modeNote: Bool = false

    init(current: LobbySettings, save: @escaping ([String: Any]) -> Void, close: @escaping () -> Void) {
        self.current = current
        self.save = save
        self.close = close
        self._setup = State(initialValue: GameSetup(lobby: current))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                sections
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .padding(.horizontal, 1)
        .padding(.top, 1)
        .frame(maxWidth: .infinity)
        .background(base)
    }

    /// The shape runs past the bottom edge, so only the top corners stay round
    /// (UnevenRoundedRectangle only exists from iOS 17). Shadow 0 24 60 black 60 %.
    private var base: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return ZStack {
            shape.fill(SettingsInk.panel)
            shape.strokeBorder(Palette.accent.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 24)
        .padding(.bottom, -60)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Header

    /// px-4 pt-4 pb-3: icon circle 32 (purple 15 %, sliders 15), "HOST" 10 pt
    /// bold with letter spacing in purple, "Lobby settings" 18 pt extra bold,
    /// close button 28 (white 6 %, x 12 in #8d8ba4) at the top right.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                LobbyLucideGlyph(paths: LobbyLucidePaths.sliders, size: 15)
                    .foregroundColor(Palette.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 0) {
                    Text("HOST")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Palette.accent)
                        .lineLimit(1)
                        .frame(height: 15)
                    Text("Lobby settings")
                        .font(.brand(18, .heavy))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                        .frame(height: 23)
                }
            }
            Spacer(minLength: 0)
            Button(action: close) {
                LucideGlyph(icon: .x, size: 12)
                    .foregroundColor(Palette.subdued)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .contentShape(Circle())
            }
            .buttonStyle(SettingsPressStyle(depth: 0.92))
            .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Body

    /// px-4 pb-4, the sections 16 apart (gap-4).
    private var sections: some View {
        VStack(alignment: .leading, spacing: 16) {
            playlistsSection
            modeSection
            SettingsNumberRow(label: "SONGS", presets: GameSetup.songChoices, unit: "",
                              minimum: 1, maximum: nil, value: $setup.songs)
            SettingsNumberRow(label: "GUESS TIME", presets: GameSetup.timeChoices, unit: "s",
                              minimum: 5, maximum: nil, value: $setup.guessSeconds)
            SettingsNumberRow(label: "BREAK BETWEEN ROUNDS", presets: GameSetup.pauseChoices, unit: "s",
                              minimum: 2, maximum: 15, value: $setup.pause)
            answerSection
            guessSection
            switchesSection
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Playlists

    /// "PLAYLISTS" (plus "n mixed together" for a mix), the colour bar of the
    /// mix when there are several, then one row per playlist, 6 apart.
    private var playlistsSection: some View {
        let entries: [SettingsMixEntry] = mixEntries
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("PLAYLISTS").settingsLabel()
                if entries.count > 1 {
                    Text("\(entries.count) mixed together")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Palette.subdued)
                        .lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if entries.count > 1 {
                    SettingsMixBar(weights: entries.map { $0.weight })
                }
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        SettingsPlaylistRow(entry: entry, mixed: entries.count > 1)
                    }
                }
            }
        }
    }

    /// The lobby's mix; older lobbies without one only have a name.
    private var mixEntries: [SettingsMixEntry] {
        let mix: [LobbySettings.PlaylistRef] = current.playlists
        if mix.isEmpty {
            guard current.playlistId != nil || current.playlistName != nil else { return [] }
            let single = SettingsMixEntry(id: 0, name: current.playlistName ?? "Playlist", source: "spotify",
                                          weight: 1, share: 100, maxSongs: nil)
            return [single]
        }
        // As in the browser: a missing weight counts as 1, the share is rounded.
        let weights: [Int] = mix.map { $0.weight > 0 ? $0.weight : 1 }
        let total: Int = max(weights.reduce(0, +), 1)
        var result: [SettingsMixEntry] = []
        for (index, ref) in mix.enumerated() {
            let w: Int = weights[index]
            let share: Int = Int((Double(w) / Double(total) * 100).rounded())
            var cap: Int? = nil
            if let m = ref.maxSongs, m > 0, m < 9999 { cap = m }
            result.append(SettingsMixEntry(id: index, name: ref.name, source: ref.source,
                                           weight: w, share: share, maxSongs: cap))
        }
        return result
    }

    // MARK: Mode

    /// Three equal tiles, 8 apart. Only Quiz can be played in the app.
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODE").settingsLabel()
            HStack(spacing: 8) {
                SettingsModeTile(paths: LobbyLucidePaths.circleHelp, title: "Quiz", available: true) {}
                SettingsModeTile(paths: LobbyLucidePaths.calendarDays, title: "Timeline", available: false) {
                    showModeNote()
                }
                SettingsModeTile(paths: LobbyLucidePaths.chevronsUpDown, title: "Higher / Lower", available: false) {
                    showModeNote()
                }
            }
            if modeNote {
                Text("Timeline and Higher / Lower are browser-only for now.")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
    }

    private func showModeNote() {
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.2)) { modeNote = true }
    }

    // MARK: Answers

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANSWER TYPE").settingsLabel()
            HStack(spacing: 8) {
                SettingsAnswerOption(text: "Multiple choice", on: !setup.freeText) { setup.freeText = false }
                SettingsAnswerOption(text: "Free text", on: setup.freeText) { setup.freeText = true }
            }
        }
    }

    private var guessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT TO GUESS?").settingsLabel()
            HStack(spacing: 8) {
                SettingsChip(text: "Title", on: $setup.heading)
                SettingsChip(text: "Artist", on: $setup.guessArtist)
                SettingsChip(text: "Year", on: $setup.guessYear)
            }
        }
    }

    /// The switches, 8 apart (Speaker Mode left out, see the type comment).
    private var switchesSection: some View {
        VStack(spacing: 8) {
            SettingsSwitchRow(title: "Album cover",
                              hint: "show the artwork while guessing",
                              on: $setup.cover)
            SettingsSwitchRow(title: "Speed bonus",
                              hint: "extra points for answering fast — only if everything was right",
                              on: $setup.speedBonusEnabled)
            SettingsSwitchRow(title: "Streak bonus",
                              hint: "extra points for several fully correct answers in a row",
                              on: $setup.streakBonusEnabled)
            SettingsSwitchRow(title: "Sneaky Mode",
                              hint: "no right/wrong until the very end",
                              on: $setup.sneaky)
        }
    }

    // MARK: Footer

    /// px-4 py-3 on rgba(7,7,14,.6) with a line on top: "Cancel" (white 4 %,
    /// edge white 8 %) and "Save" (purple, check 14), both 42 tall, corners 18,
    /// 13 pt bold, 8 apart.
    private var footer: some View {
        HStack(spacing: 8) {
            cancelButton
            saveButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SettingsInk.footer.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    private var cancelButton: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return Button(action: close) {
            Text("Cancel")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Palette.foreground)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(shape.fill(Color.white.opacity(0.04)))
                .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(SettingsPressStyle(depth: 0.98))
    }

    /// The label stays plain "Save" - the check icon is hidden from VoiceOver.
    private var saveButton: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return Button {
            commit()
        } label: {
            HStack(spacing: 8) {
                LobbyLucideGlyph(paths: LobbyLucidePaths.check, size: 14)
                Text("Save")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(shape.fill(Palette.accent))
            .contentShape(shape)
        }
        .buttonStyle(SettingsPressStyle())
    }

    /// As in the browser: send everything, the playlist mix unchanged, then
    /// close. The server answers with a lobby-update carrying the new values.
    private func commit() {
        Haptics.lock()
        save(setup.settingsUpdate(keeping: current))
        close()
    }
}

// MARK: - Lucide icons the lobby needs

/// A lucide icon from raw SVG path data, drawn like `LucideGlyph` (stroke 2 on
/// the 24 grid, scaled with the size, round caps and joins) - for the icons
/// `LucideIcon` does not have. Takes the foreground color; decorative, so
/// hidden from VoiceOver.
struct LobbyLucideGlyph: View {
    let paths: [String]
    var size: CGFloat = 15

    var body: some View {
        LobbyLucideShape(paths: paths)
            .stroke(style: StrokeStyle(lineWidth: size / 12, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The path data scaled from the 24 × 24 grid into the given square.
private struct LobbyLucideShape: Shape {
    let paths: [String]

    func path(in rect: CGRect) -> Path {
        let side: CGFloat = min(rect.width, rect.height)
        let unit: CGFloat = side / 24
        let originX: CGFloat = rect.midX - side / 2
        let originY: CGFloat = rect.midY - side / 2

        func place(_ p: CGPoint) -> CGPoint {
            CGPoint(x: originX + p.x * unit, y: originY + p.y * unit)
        }

        var path = Path()
        for data in paths {
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

/// Path data from the web bundle (lucide-react 0.487); line, circle and rect
/// elements written out as paths.
enum LobbyLucidePaths {
    /// sliders-horizontal: the host's settings buttons and the sheet's icon.
    static let sliders: [String] = ["M21 4h-7", "M10 4H3", "M21 12h-9", "M8 12H3", "M21 20h-5", "M12 20H3",
                                    "M14 2v4", "M8 10v4", "M16 18v4"]
    /// check: "Save" and the picked "What to guess?" chips.
    static let check: [String] = ["M20 6 9 17l-5-5"]
    /// circle-help: the Quiz tile.
    static let circleHelp: [String] = ["M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0",
                                       "M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3", "M12 17h.01"]
    /// calendar-days: the Timeline tile.
    static let calendarDays: [String] = ["M8 2v4", "M16 2v4",
                                         "M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z",
                                         "M3 10h18", "M8 14h.01", "M12 14h.01", "M16 14h.01",
                                         "M8 18h.01", "M12 18h.01", "M16 18h.01"]
    /// chevrons-up-down: the Higher / Lower tile.
    static let chevronsUpDown: [String] = ["m7 15 5 5 5-5", "m7 9 5-5 5 5"]
    /// wand-sparkles: the "set your own" pill.
    static let wandSparkles: [String] = [
        "m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72",
        "m14 7 3 3", "M5 6v4", "M19 14v4", "M10 2v2", "M7 8H3", "M21 16h-4", "M11 3H9"
    ]
}

// MARK: - Colors

/// Values from the settings sheet that the shared palette does not have.
private enum SettingsInk {
    /// Sheet: rgba(24,23,39,.98)
    static let panel = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)
    /// Footer: rgba(7,7,14,.6)
    static let footer = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.6)
    /// The number field of "set your own": rgba(8,7,18,.8)
    static let editorFill = Color(.sRGB, red: 8 / 255, green: 7 / 255, blue: 18 / 255, opacity: 0.8)
    /// Idle mode label: #b0aed2
    static let lilac = Color(hex: 0xB0AED2)
    /// Idle mode icon: #6a6889
    static let dim = Color(hex: 0x6A6889)
    static let spotify = Color(hex: 0x1DB954)
    static let youtube = Color(hex: 0xFF0000)
    /// The mix bar, in order: --acc, green, gold, pink, blue, red.
    static let mixColors: [Color] = [Color(hex: 0xB15CFF), Color(hex: 0x34D399), Color(hex: 0xFBBF24),
                                     Color(hex: 0xF472B6), Color(hex: 0x60A5FA), Color(hex: 0xF87171)]
}

private extension Text {
    /// The section labels: 10 pt bold, letter spacing 1, #8d8ba4, 15 tall.
    func settingsLabel() -> some View {
        self.font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundColor(Palette.subdued)
            .lineLimit(1)
            .frame(height: 15)
    }
}

// MARK: - Building blocks

/// Shrinks slightly while pressed (framer-motion whileTap in the browser).
private struct SettingsPressStyle: ButtonStyle {
    var depth: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? depth : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// One playlist of the lobby's mix, ready to show.
private struct SettingsMixEntry: Identifiable {
    let id: Int
    let name: String
    let source: String
    let weight: Int
    /// Share of the mix in percent.
    let share: Int
    /// The song cap set in the browser, if any.
    let maxSongs: Int?
}

/// The mix as a bar 10 tall: one coloured segment per playlist, as wide as its
/// weight, on white 6 %.
private struct SettingsMixBar: View {
    let weights: [Int]

    var body: some View {
        GeometryReader { box in
            HStack(spacing: 0) {
                ForEach(Array(weights.enumerated()), id: \.offset) { index, weight in
                    Rectangle()
                        .fill(SettingsInk.mixColors[index % SettingsInk.mixColors.count])
                        .frame(width: segmentWidth(weight, of: box.size.width))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 10)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func segmentWidth(_ weight: Int, of width: CGFloat) -> CGFloat {
        let total: Int = max(weights.reduce(0, +), 1)
        return width * CGFloat(weight) / CGFloat(total)
    }
}

/// A playlist of the mix, read-only: white 3 %, edge white 8 %, corners 18,
/// padding 10/12; cover 32 (corners 14, white 5 %, the source mark 14 in one
/// colour), name 12 pt semibold, below it the source (and its share of a mix)
/// 10 pt in #8d8ba4, and "MAX n SONGS" when the browser set a cap.
private struct SettingsPlaylistRow: View {
    let entry: SettingsMixEntry
    let mixed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                cover
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                        .frame(height: 18)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(Palette.subdued)
                        .lineLimit(1)
                        .frame(height: 15)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let cap = entry.maxSongs {
                Text("MAX \(cap) SONGS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Palette.subdued)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Color.white.opacity(0.03)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let source: String = entry.source == "youtube" ? "YouTube" : "Spotify"
        return mixed ? source + " · \(entry.share)% of the mix" : source
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .circular)
        return ZStack {
            shape.fill(Color.white.opacity(0.05))
            sourceMark
        }
        .frame(width: 32, height: 32)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    @ViewBuilder
    private var sourceMark: some View {
        if entry.source == "youtube" {
            SettingsYouTubeMark(dimension: 14, hue: Palette.foreground, mono: true)
        } else {
            SettingsSpotifyMark(dimension: 14, hue: Palette.foreground, mono: true)
        }
    }
}

/// The Spotify mark drawn by hand: a circle with three arcs (traced from the
/// SVG in the bundle). `mono` cuts the arcs out of a single colour, like
/// `mono` in the browser; otherwise green with white arcs.
private struct SettingsSpotifyMark: View {
    let dimension: CGFloat
    var hue: Color = SettingsInk.spotify
    var mono: Bool = false

    var body: some View {
        let k: CGFloat = dimension / 24
        let ink: Color = mono ? Color.black : Color.white
        return ZStack {
            Circle().fill(hue)
            ZStack {
                SettingsSpotifyArc(start: CGPoint(x: 4.83, y: 8.25), control1: CGPoint(x: 8.79, y: 7.05),
                                   control2: CGPoint(x: 15.51, y: 7.29), end: CGPoint(x: 19.65, y: 9.75))
                    .stroke(ink, style: StrokeStyle(lineWidth: 2.2 * k, lineCap: .round))
                SettingsSpotifyArc(start: CGPoint(x: 5.49, y: 12.09), control1: CGPoint(x: 9.57, y: 10.83),
                                   control2: CGPoint(x: 14.73, y: 11.46), end: CGPoint(x: 18.21, y: 13.59))
                    .stroke(ink, style: StrokeStyle(lineWidth: 1.8 * k, lineCap: .round))
                SettingsSpotifyArc(start: CGPoint(x: 5.76, y: 15.72), control1: CGPoint(x: 10.14, y: 14.73),
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
private struct SettingsSpotifyArc: Shape {
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
private struct SettingsYouTubeMark: View {
    let dimension: CGFloat
    var hue: Color = SettingsInk.youtube
    var mono: Bool = false

    var body: some View {
        let k: CGFloat = dimension / 24
        return ZStack {
            RoundedRectangle(cornerRadius: 4.5 * k, style: .continuous)
                .fill(hue)
                .frame(width: dimension, height: 16.9 * k)
            SettingsYouTubePlay()
                .fill(mono ? Color.black : Color.white)
                .blendMode(mono ? BlendMode.destinationOut : BlendMode.normal)
        }
        .compositingGroup()
        .frame(width: dimension, height: dimension)
        .accessibilityHidden(true)
    }
}

private struct SettingsYouTubePlay: Shape {
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

/// A mode tile: 57 tall, padding 10/4, corners 18, icon 16, name 10 pt bold,
/// 6 apart. Picked: rgba(112,0,215,.22) with a --acc 55 % edge, purple icon
/// and #eef name; otherwise white 3 %, edge white 7 %, icon #6a6889, name
/// #b0aed2. Modes the app cannot play are faded and only explain themselves
/// when tapped.
private struct SettingsModeTile: View {
    let paths: [String]
    let title: String
    let available: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            tile
        }
        .buttonStyle(SettingsPressStyle())
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(available ? "Selected" as String : "Not available in the app yet" as String))
        .accessibilityAddTraits(available ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        let fill: Color = available ? Palette.accentDeep.opacity(0.22) : Color.white.opacity(0.03)
        let edge: Color = available ? Palette.accent.opacity(0.55) : Palette.border
        return VStack(spacing: 6) {
            LobbyLucideGlyph(paths: paths, size: 16)
                .foregroundColor(available ? Palette.accent : SettingsInk.dim)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(available ? Palette.foreground : SettingsInk.lilac)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 13)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(shape.fill(fill))
        .overlay(shape.strokeBorder(edge, lineWidth: 1))
        .contentShape(shape)
        .opacity(available ? 1 : 0.5)
    }
}

/// A round choice like "10" or "30s": 12/6 padding, 12 pt bold, capsule.
/// Picked: --acc at 18 % with a 55 % edge and --acc text; otherwise white 4 %,
/// edge white 8 %, #8d8ba4 text.
private struct SettingsPill: View {
    let text: String
    let on: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(on ? Palette.accent : Palette.subdued)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(on ? Palette.accent.opacity(0.18) : Color.white.opacity(0.04)))
                .overlay(Capsule().strokeBorder(on ? Palette.accent.opacity(0.55) : Color.white.opacity(0.08),
                                                lineWidth: 1))
        }
        .buttonStyle(SettingsPressStyle())
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

/// A row of fixed values, 6 apart, plus the "set your own" pill (a wand, 25
/// tall). Once a custom value is set, that pill shows it in the picked look.
/// Tapping it opens a small number field (64 wide, placeholder "1+" or
/// "2–15"); the value is clamped like in the browser.
private struct SettingsNumberRow: View {
    let label: String
    let presets: [Int]
    let unit: String
    let minimum: Int
    let maximum: Int?
    @Binding var value: Int

    @State private var editing: Bool = false
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).settingsLabel()
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { n in
                    SettingsPill(text: "\(n)\(unit)", on: value == n) {
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
            customFace(on)
                .foregroundColor(on ? Palette.accent : Palette.subdued)
                .padding(.horizontal, 12)
                .frame(height: on ? 32 : 25)
                .background(Capsule().fill(on ? Palette.accent.opacity(0.18) : Color.white.opacity(0.04)))
                .overlay(Capsule().strokeBorder(on ? Palette.accent.opacity(0.55) : Color.white.opacity(0.08),
                                                lineWidth: 1))
        }
        .buttonStyle(SettingsPressStyle())
        .accessibilityLabel(on ? Text(verbatim: "\(value)\(unit)") : Text("Set your own"))
    }

    @ViewBuilder
    private func customFace(_ on: Bool) -> some View {
        if on {
            Text(verbatim: "\(value)\(unit)")
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .fixedSize()
        } else {
            LobbyLucideGlyph(paths: LobbyLucidePaths.wandSparkles, size: 11)
        }
    }

    /// The number pad has no return key, so a small check button confirms.
    private var editor: some View {
        HStack(spacing: 4) {
            TextField("", text: $draft, prompt: Text(placeholder).foregroundColor(Palette.faint))
                .font(.system(size: 12, weight: .bold))
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
                .background(Capsule().fill(SettingsInk.editorFill))
                .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.55), lineWidth: 1))

            Button {
                commit()
            } label: {
                LobbyLucideGlyph(paths: LobbyLucidePaths.check, size: 12)
                    .foregroundColor(Palette.onAccent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Palette.accent))
            }
            .buttonStyle(SettingsPressStyle())
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

/// "What to guess?" chip: like a pill, with a check 10 while picked
/// (15 % fill, 50 % edge), icon and text 6 apart.
private struct SettingsChip: View {
    let text: String
    @Binding var on: Bool

    var body: some View {
        Button {
            Haptics.tap()
            on.toggle()
        } label: {
            HStack(spacing: 6) {
                if on {
                    LobbyLucideGlyph(paths: LobbyLucidePaths.check, size: 10)
                }
                Text(text)
                    .font(.system(size: 12, weight: .bold))
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
        .buttonStyle(SettingsPressStyle())
        .accessibilityLabel(Text(text))
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

/// "Answer type": two equal buttons, 36 tall, corners 18, 12 pt bold.
private struct SettingsAnswerOption: View {
    let text: String
    let on: Bool
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return Button {
            Haptics.tap()
            onTap()
        } label: {
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(on ? Palette.accent : Palette.subdued)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(shape.fill(on ? Palette.accent.opacity(0.15) : Color.white.opacity(0.04)))
                .overlay(shape.strokeBorder(on ? Palette.accent.opacity(0.5) : Color.white.opacity(0.08),
                                            lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(SettingsPressStyle(depth: 0.98))
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

/// A switch row: white 3 %, corners 18, padding 10/12; name 13 pt semibold
/// (20 tall), hint 10 pt in #8d8ba4 below it.
private struct SettingsSwitchRow: View {
    let title: String
    let hint: String
    @Binding var on: Bool

    var body: some View {
        Toggle(isOn: $on) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.foreground)
                    .frame(minHeight: 20)
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.subdued)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(SettingsSwitchStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Color.white.opacity(0.03)))
    }
}

/// The browser's switch: 48×26; on = #7000d7 with a purple glow and the white
/// 20 knob on the right, off = white 10 % with the knob on the left. The whole
/// row toggles, not only the switch (as on Create Game).
private struct SettingsSwitchStyle: ToggleStyle {
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
