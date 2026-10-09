import SwiftUI

/// "Playlists" (`T3` in the web bundle): keep up to five Spotify or YouTube
/// playlists (ten with PRO) to pick quickly when creating a game. A card
/// with the counts and the link field, then one row per playlist.
/// Measurements from the website at 375 × 812 (k-playlists).
struct PlaylistsView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var saved: [SavedPlaylist] = []
    /// Nothing is written before the real list has arrived - a PUT built from
    /// an empty list that merely failed to load would wipe the saved ones.
    @State private var loaded = false
    @State private var busy = false
    @State private var link: String = ""
    @State private var checking = false
    @State private var toast: CosmeticToast?
    @FocusState private var fieldFocused: Bool

    private var slots: Int { SavedPlaylist.slots(isPro: api.me?.is_pro ?? false) }

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Playlists", onBack: { close() }) { slotPill }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        topCard
                        VStack(spacing: 12) {
                            ForEach(saved) { p in
                                SavedPlaylistRow(playlist: p) { Task { await remove(p) } }
                            }
                        }
                        if saved.isEmpty && loaded { emptyState }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .overlay(alignment: .top) { CosmeticToastView(toast: $toast) }
        .task { await load() }
    }

    /// "0/5" in amber.
    private var slotPill: some View {
        Text("\(saved.count)/\(slots)")
            .font(.brand(11, .bold))
            .foregroundColor(Color(hex: 0xF59E0B))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(hex: 0xF59E0B).opacity(0.15)))
            .overlay(Capsule().strokeBorder(Color(hex: 0xF59E0B).opacity(0.3), lineWidth: 1))
    }

    private var topCard: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let field = RoundedRectangle(cornerRadius: 18, style: .circular)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LucideGlyph(icon: .disc, size: 20)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 16, style: .circular).fill(Palette.accent))
                    .shadow(color: Palette.accentDeep.opacity(0.4), radius: 10)
                HStack(spacing: 16) {
                    counter("\(saved.count)", "Saved", tint: Palette.foreground)
                    counter("\(max(0, slots - saved.count))", "Slots left", tint: Palette.good)
                }
            }
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if link.isEmpty {
                        Text("Spotify or YouTube playlist link...")
                            .font(.brand(13))
                            .foregroundColor(Palette.faint)
                            .lineLimit(1)
                    }
                    TextField("", text: $link)
                        .font(.brand(13))
                        .foregroundColor(Palette.foreground)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .submitLabel(.done)
                        .focused($fieldFocused)
                        .onSubmit { Task { await add() } }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(field.fill(Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)))
                .overlay(field.strokeBorder(Palette.border, lineWidth: 1))
                Button {
                    Task { await add() }
                } label: {
                    HStack(spacing: 6) {
                        LucideGlyph(icon: .plus, size: 14)
                        Text(checking ? "Checking…" : "Save")
                    }
                    .font(.brand(13, .bold))
                    .foregroundColor(Palette.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(field.fill(Palette.accent))
                    .opacity(checking ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(checking)
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            LucideGlyph(icon: .disc, size: 26)
                .foregroundColor(Palette.subdued)
                .frame(width: 64, height: 64)
                .background(Circle().fill(LinearGradient(colors: [Palette.accentDeep.opacity(0.15), Palette.accent.opacity(0.08)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(Circle().strokeBorder(Palette.accent.opacity(0.2), lineWidth: 1))
            VStack(spacing: 2) {
                Text("No playlists saved").font(.brand(14, .semibold))
                Text("Keep a Spotify or YouTube playlist here and it is one tap away in every game")
                    .font(.brand(11))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(Palette.subdued)
            Button {
                fieldFocused = true
            } label: {
                HStack(spacing: 8) {
                    LucideGlyph(icon: .bookmark, size: 14)
                    Text("Add a playlist")
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

    // MARK: Data

    @MainActor
    private func load() async {
        do {
            let list: SavedPlaylistList = try await api.fetch("/profile")
            saved = list.items
            loaded = true
        } catch {
            show("Could not load your playlists", error: true)
        }
    }

    @MainActor
    private func store(_ next: [SavedPlaylist]) async throws {
        let answer: SavedPlaylistList = try await api.call("/playlists/saved", method: "PUT",
                                                          body: ["playlists": next.map { $0.body }])
        saved = answer.items
    }

    @MainActor
    private func add() async {
        let address: String = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !checking, !busy else { return }
        guard loaded else {
            show("Your playlists are still loading.", error: true)
            await load()
            return
        }
        guard saved.count < slots else {
            show("All your playlist slots are full.", error: true)
            return
        }
        checking = true
        busy = true
        defer {
            checking = false
            busy = false
        }
        do {
            let info: PlaylistInfo = try await api.fetch("/playlist/info", ["url": address])
            if saved.contains(where: { $0.id == info.id }) {
                show("That playlist is already saved.", error: true)
                return
            }
            let entry = SavedPlaylist(id: info.id, name: info.name, image: info.image, source: info.source)
            try await store(saved + [entry])
            link = ""
            Haptics.correct()
            show("Saved \"\(info.name)\"", error: false)
        } catch {
            Haptics.wrong()
            let text: String = error.localizedDescription
            show(text.isEmpty ? "Could not add that playlist" : text, error: true)
        }
    }

    @MainActor
    private func remove(_ p: SavedPlaylist) async {
        guard loaded, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await store(saved.filter { $0.id != p.id })
            Haptics.tap()
        } catch {
            let text: String = error.localizedDescription
            show(text.isEmpty ? "Could not remove that playlist" : text, error: true)
        }
    }

    private func show(_ text: String, error: Bool) {
        withAnimation { toast = CosmeticToast(text: text, isError: error) }
    }
}

/// One saved playlist: 56 cover (picture or a hashed gradient with a note),
/// name, source mark + "SPOTIFY" / "YOUTUBE", and the bin.
private struct SavedPlaylistRow: View {
    let playlist: SavedPlaylist
    let onRemove: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        HStack(spacing: 12) {
            cover
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.brand(13, .semibold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    PlaylistSourceMark(source: playlist.source, size: 11)
                    Text(playlist.source == "youtube" ? "YOUTUBE" : "SPOTIFY")
                        .font(.brand(10, .bold))
                        .tracking(0.25)
                        .foregroundColor(Palette.subdued)
                }
            }
            Spacer(minLength: 0)
            Button(action: onRemove) {
                LucideGlyph(icon: .trash2, size: 12)
                    .foregroundColor(Palette.subdued)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8, style: .circular).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .circular).strokeBorder(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove \(playlist.name)"))
        }
        .padding(12)
        .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.92)))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private var cover: some View {
        let box = RoundedRectangle(cornerRadius: 18, style: .circular)
        return ZStack {
            box.fill(PlaylistCoverPalette.fill(playlist.paletteIndex))
            if let address = playlist.image, let url = URL(string: address) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            } else {
                LucideGlyph(icon: .music2, size: 18).foregroundColor(Color.white.opacity(0.4))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(box)
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 4)
    }
}

/// `Ym`: the eight cover gradients (135°).
enum PlaylistCoverPalette {
    static func fill(_ index: Int) -> AnyShapeStyle {
        let pairs: [(UInt32, UInt32)] = [
            (0xEF4444, 0xF97316), (0xEC4899, 0xA855F7), (0x374151, 0x6B7280), (0xF472B6, 0xFDA4AF),
            (CosmeticLook.shared.accent, CosmeticLook.shared.accent), (0x0EA5E9, 0x22D3EE), (0x10B981, 0x84CC16), (0xF59E0B, 0xFBBF24)
        ]
        let p = pairs[max(0, min(pairs.count - 1, index))]
        return AnyShapeStyle(LinearGradient(colors: [Color(hex: p.0), Color(hex: p.1)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

/// The Spotify (green disc) and YouTube (red play button) marks (`V1`, `H1`).
struct PlaylistSourceMark: View {
    let source: String
    var size: CGFloat = 14

    var body: some View {
        let box = CGSize(width: 24, height: 24)
        ZStack {
            if source == "youtube" {
                GlyphShape(data: PlaylistSourceMark.youtube, box: box).fill(Color(hex: 0xFF0000))
                GlyphShape(data: "M9.545 15.568V8.432L15.818 12l-6.273 3.568z", box: box).fill(Color.white)
            } else {
                GlyphShape(data: "M1 12a11 11 0 1 0 22 0a11 11 0 1 0-22 0z", box: box).fill(Color.white)
                GlyphShape(data: PlaylistSourceMark.spotify, box: box).fill(Color(hex: 0x1DB954), style: FillStyle(eoFill: true))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(source == "youtube" ? "YouTube" : "Spotify"))
    }

    static let spotify: String = "M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.601.301.96zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"

    static let youtube: String = "M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814z"
}
