import SwiftUI

/// "Create Game" wie im Browser: 1 Playlist, 2 Modus, 3 Einstellungen, unten
/// "Privat erstellen" bzw. "Öffentlich erstellen".
///
/// Modus gibt es in der App nur einen - Quiz. Timeline und Higher/Lower haben
/// eigene Rundenbildschirme, die die App noch nicht kennt; sie anzubieten hiesse,
/// Spieler in eine Runde zu schicken, die sie nicht spielen koennen.
struct CreateGameView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game
    @Environment(\.dismiss) private var close

    @State private var setup = GameSetup()
    @State private var featuredPlaylists: [PlaylistEntry] = []
    @State private var link = ""
    @State private var searching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    playlistCard
                    modeCard
                    settingsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Palette.base.ignoresSafeArea())
        .task { await loadFeatured() }
    }

    // MARK: Kopf

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                close()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Palette.foreground)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Palette.surface))
                    .overlay(Circle().strokeBorder(Palette.rim, lineWidth: 1))
            }
            Text("Create Game")
                .font(.brand(24, .heavy))
                .foregroundColor(Palette.foreground)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: 1 Playlist

    private var playlistCard: some View {
        Card(inset: 16) {
            VStack(alignment: .leading, spacing: 12) {
                StepHeader(numeral: 1, heading: "Playlist", isRequired: true)
                Text("Add a Spotify or YouTube playlist.")
                    .font(.brand(12))
                    .foregroundColor(Palette.faint)

                HStack(spacing: 8) {
                    InputField(text: $link, placeholderText: "Paste a Spotify or YouTube link…")
                    Button {
                        Task { await checkLink() }
                    } label: {
                        Text(searching ? "…" : "Add")
                            .font(.brand(13, .heavy))
                            .foregroundColor(Palette.onAccent)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.gradient))
                    }
                    .disabled(searching || link.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let f = errorMessage {
                    Text(f)
                        .font(.brand(12, .semibold))
                        .foregroundColor(Palette.bad)
                }

                if let p = setup.playlist {
                    PlaylistRow(entry: p, selected: true) {
                        setup.playlist = nil
                    }
                }

                let others: [PlaylistEntry] = featuredPlaylists.filter { $0.id != setup.playlist?.id }
                if !others.isEmpty {
                    Text("FEATURED").eyebrow()
                    ForEach(others) { e in
                        PlaylistRow(entry: e, selected: false) {
                            Haptics.tap()
                            setup.playlist = e
                        }
                    }
                }
            }
        }
    }

    // MARK: 2 Modus

    private var modeCard: some View {
        Card(inset: 16) {
            VStack(alignment: .leading, spacing: 12) {
                StepHeader(numeral: 2, heading: "Mode", isRequired: false)
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Palette.accent)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.accent.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiz").font(.brand(14, .heavy)).foregroundColor(Palette.foreground)
                        Text("Guess title, artist, year")
                            .font(.brand(11)).foregroundColor(Palette.faint)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.accent.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.accent.opacity(0.5), lineWidth: 1))
                Text("Timeline and Higher/Lower are browser-only for now.")
                    .font(.brand(11))
                    .foregroundColor(Palette.faint)
            }
        }
    }

    // MARK: 3 Einstellungen

    private var settingsCard: some View {
        Card(inset: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    StepHeader(numeral: 3, heading: "Settings", isRequired: false)
                    Spacer(minLength: 0)
                    Button("Reset") {
                        Haptics.tap()
                        let p: PlaylistEntry? = setup.playlist
                        setup = GameSetup()
                        setup.playlist = p
                    }
                    .font(.brand(11, .heavy))
                    .foregroundColor(Palette.faint)
                }
                NumberChoice(heading: "SONGS", presets: GameSetup.songChoices, unit: "", selection: $setup.songs)
                NumberChoice(heading: "GUESS TIME", presets: GameSetup.timeChoices, unit: "s", selection: $setup.guessSeconds)
                guessKinds
                answerKind
                NumberChoice(heading: "BREAK BETWEEN ROUNDS", presets: GameSetup.pauseChoices, unit: "s", selection: $setup.pause)
                ToggleRow(heading: "Album cover",
                         hint: "show the artwork while guessing",
                         on: $setup.cover)
                ToggleRow(heading: "Speed bonus",
                         hint: "extra points for answering fast — only if everything was right",
                         on: $setup.speedBonusEnabled)
                ToggleRow(heading: "Streak bonus",
                         hint: "extra points for several fully correct answers in a row",
                         on: $setup.streakBonusEnabled)
                ToggleRow(heading: "Sneaky Mode",
                         hint: "no right/wrong until the very end",
                         on: $setup.sneaky)
            }
        }
    }

    private var guessKinds: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT TO GUESS?").eyebrow()
            HStack(spacing: 8) {
                ToggleChip(text: "Title", on: $setup.heading)
                ToggleChip(text: "Artist", on: $setup.guessArtist)
                ToggleChip(text: "Year", on: $setup.guessYear)
            }
        }
    }

    private var answerKind: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANSWER TYPE").eyebrow()
            HStack(spacing: 8) {
                ChoicePill(text: "Multiple choice", on: !setup.freeText) { setup.freeText = false }
                ChoicePill(text: "Free text", on: setup.freeText) { setup.freeText = true }
            }
        }
    }

    // MARK: Fuss

    private var footer: some View {
        VStack(spacing: 8) {
            if setup.playlist == nil {
                Text("Add a playlist to create a lobby")
                    .font(.brand(12, .semibold))
                    .foregroundColor(Palette.faint)
            }
            HStack(spacing: 10) {
                Button {
                    proceed(isPublic: false)
                } label: {
                    Label("Private", systemImage: "lock.fill")
                }
                .buttonStyle(PrimaryButtonStyle(dimmed: setup.playlist == nil))
                .disabled(setup.playlist == nil)

                Button {
                    proceed(isPublic: true)
                } label: {
                    Label("Public", systemImage: "globe")
                }
                .buttonStyle(PrimaryButtonStyle(hue: Palette.rim, dimmed: setup.playlist == nil))
                .disabled(setup.playlist == nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: Ablauf

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
    }

    @MainActor
    private func checkLink() async {
        let url: String = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
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
}

// MARK: - Bausteine

/// Die nummerierte Ueberschrift einer Karte, wie im Browser.
private struct StepHeader: View {
    let numeral: Int
    let heading: String
    let isRequired: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(numeral)")
                .font(.brand(10, .black))
                .foregroundColor(Palette.onAccent)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Palette.gradient))
            Text(heading)
                .font(.brand(15, .heavy))
                .foregroundColor(Palette.foreground)
            Spacer(minLength: 0)
            if isRequired {
                Text("REQUIRED")
                    .font(.brand(9, .black))
                    .foregroundColor(Palette.bad)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Palette.bad.opacity(0.15)))
            }
        }
    }
}

private struct PlaylistRow: View {
    let entry: PlaylistEntry
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                picture
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.brand(13, .semibold))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                    Text(entry.origin == "youtube" ? "YouTube" : "Spotify")
                        .font(.brand(10))
                        .foregroundColor(Palette.faint)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "xmark" : "plus")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(selected ? Palette.onAccent : Palette.faint)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(selected ? Palette.accent : Color.white.opacity(0.08)))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Palette.accent.opacity(0.10) : Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Palette.accent.opacity(0.4) : Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var picture: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if let a = entry.picture, let url = URL(string: a) {
            AsyncImage(url: url) { b in
                b.resizable().scaledToFill()
            } placeholder: {
                shape.fill(Palette.muted)
            }
            .frame(width: 34, height: 34)
            .clipShape(shape)
        } else {
            Image(systemName: "music.note.list")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Palette.good)
                .frame(width: 34, height: 34)
                .background(shape.fill(Palette.good.opacity(0.13)))
        }
    }
}

/// Eine Reihe fester Werte zum Antippen (SONGS 5 10 15 20).
private struct NumberChoice: View {
    let heading: String
    let presets: [Int]
    let unit: String
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading).eyebrow()
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { w in
                    ChoicePill(text: "\(w)\(unit)", on: selection == w) { selection = w }
                }
            }
        }
    }
}

private struct ChoicePill: View {
    let text: String
    let on: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            Text(text)
                .font(.brand(13, .heavy))
                .foregroundColor(on ? Palette.onAccent : Palette.subdued)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.white.opacity(0.04))))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? Color.clear : Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ToggleChip: View {
    let text: String
    @Binding var on: Bool

    var body: some View {
        ChoicePill(text: text, on: on) { on.toggle() }
    }
}

private struct ToggleRow: View {
    let heading: String
    let hint: String
    @Binding var on: Bool

    var body: some View {
        Toggle(isOn: $on) {
            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.brand(14, .semibold))
                    .foregroundColor(Palette.foreground)
                Text(hint)
                    .font(.brand(11))
                    .foregroundColor(Palette.faint)
            }
        }
        .tint(Palette.accent)
    }
}
