import Foundation

// What the app can do now: host a game itself, react with emojis during a
// game and view the leaderboard. The shapes here were checked against the
// live server on 2026-10-04 (see Tests/Capture.swift) - not just read from
// the web bundle.

// MARK: - Create game

/// One playlist in the mix. The browser allows several and weights them; the app
/// starts with one and sends it in the same shape.
struct PlaylistEntry: Hashable, Identifiable {
    let id: String
    let name: String
    let picture: String?
    let origin: String      // "spotify" | "youtube"
}

/// Response of `GET /playlist/info?url=…`.
struct PlaylistInfo: Decodable {
    let id: String
    let name: String
    let image: String?
    let source: String
    let trackCount: Int?

    private enum CodingKeys: String, CodingKey { case id, name, image, source, trackCount }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = ((try? c.decode(LooseValue.self, forKey: .id)) ?? LooseValue("")).text
        name = (try? c.decode(String.self, forKey: .name)) ?? "Playlist"
        image = try? c.decode(String.self, forKey: .image)
        source = (try? c.decode(String.self, forKey: .source)) ?? "spotify"
        trackCount = (try? c.decode(LooseValue.self, forKey: .trackCount))?.numeric
    }

    var entry: PlaylistEntry {
        PlaylistEntry(id: id, name: name, picture: image, origin: source)
    }
}

/// Response of `GET /playlists/featured`.
struct FeaturedPlaylists: Decodable {
    let entries: [PlaylistEntry]

    private struct RawEntry: Decodable {
        let playlist_id: String
        let playlist_name: String?
        let playlist_image: String?
        private enum CodingKeys: String, CodingKey { case playlist_id, playlist_name, playlist_image }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            playlist_id = try c.decode(LooseValue.self, forKey: .playlist_id).text
            playlist_name = try? c.decode(String.self, forKey: .playlist_name)
            playlist_image = try? c.decode(String.self, forKey: .playlist_image)
        }
    }

    private enum CodingKeys: String, CodingKey { case playlists }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let raw: [RawEntry] = (try? c.decode(LenientArray<RawEntry>.self, forKey: .playlists).items) ?? []
        entries = raw.map { r in
            PlaylistEntry(id: r.playlist_id, name: r.playlist_name ?? "Featured",
                            picture: r.playlist_image, origin: "spotify")
        }
    }
}

/// The settings for `create-game`. Field names exactly as in the browser
/// (`F3` in the bundle), since that is how the server reads them.
struct GameSetup: Equatable {
    var playlist: PlaylistEntry?
    var songs: Int = 10
    var guessSeconds: Int = 30
    var heading = true
    var guessArtist = true
    var guessYear = true
    var freeText = false
    var pause: Int = 5
    var cover = true
    var speedBonusEnabled = true
    var streakBonusEnabled = true
    var sneaky = false
    var isPublic = false

    static let songChoices: [Int] = [5, 10, 15, 20]
    static let timeChoices: [Int] = [20, 30, 45, 60]
    static let pauseChoices: [Int] = [3, 5, 8]

    var guessKinds: [String] {
        var a: [String] = []
        if heading { a.append("title") }
        if guessArtist { a.append("artist") }
        if guessYear { a.append("year") }
        // As in the browser: nothing selected means title.
        return a.isEmpty ? ["title"] : a
    }

    init() {}

    /// The lobby's current settings as the starting point of the host's
    /// "Lobby settings" sheet.
    init(lobby s: LobbySettings) {
        songs = s.songCount
        guessSeconds = s.guessTime
        pause = s.revealTime
        freeText = !s.isMultipleChoice
        heading = s.guessTypes.contains("title")
        guessArtist = s.guessTypes.contains("artist")
        guessYear = s.guessTypes.contains("year")
        cover = s.showCover
        speedBonusEnabled = s.speedBonus
        streakBonusEnabled = s.streakBonus
        sneaky = s.sneakyMode
        if let first = s.playlists.first {
            playlist = PlaylistEntry(id: first.id, name: first.name, picture: nil, origin: first.source)
        }
    }

    /// `update-lobby-settings` - the fields the browser's settings sheet sends
    /// (`t0` in the bundle). The lobby's playlist mix is passed back unchanged,
    /// boxMode/hostPlays as well: the app does not offer Speaker Mode.
    func settingsUpdate(keeping s: LobbySettings) -> [String: Any] {
        var d: [String: Any] = [
            "gameMode": "quiz",
            "songCount": songs,
            "guessTime": guessSeconds,
            "revealTime": pause,
            "answerType": freeText ? "freestyle" : "multiple",
            "guessTypes": guessKinds,
            "showCover": cover,
            "speedBonus": speedBonusEnabled,
            "streakBonus": streakBonusEnabled,
            "boxMode": s.boxMode,
            "sneakyMode": sneaky,
            "hostPlays": s.boxMode ? s.hostPlays : true
        ]
        if !s.playlists.isEmpty {
            d["playlistId"] = s.playlists[0].id
            d["playlistName"] = s.playlists.count > 1 ? s.playlists.map { $0.name }.joined(separator: " + ") : s.playlists[0].name
            d["playlists"] = s.playlists.map { $0.payload }
        } else if let id = s.playlistId {
            d["playlistId"] = id
            d["playlistName"] = s.playlistName ?? "Playlist"
        }
        return d
    }

    /// Without a playlist there is nothing to send - the button stays disabled.
    func payloadObject() -> [String: Any]? {
        guard let p = playlist else { return nil }
        return [
            "playlistId": p.id,
            "playlistName": p.name,
            "playlists": [["id": p.id, "source": p.origin, "name": p.name, "weight": 1]],
            "gameMode": "quiz",
            "songCount": songs,
            "guessTime": guessSeconds,
            "guessTypes": guessKinds,
            "answerType": freeText ? "freestyle" : "multiple",
            "revealTime": pause,
            "showCover": cover,
            "speedBonus": speedBonusEnabled,
            "streakBonus": streakBonusEnabled,
            "boxMode": false,
            "hostPlays": true,
            "sneakyMode": sneaky,
            "lobbyLang": "Mixed",
            "lobbyGenre": "Mixed",
            "isPublic": isPublic
        ]
    }
}

// MARK: - Reactions

/// `player-reacted` - someone tapped an emoji button.
struct Reaction: Decodable, Identifiable, Hashable {
    let id = UUID()
    let senderId: String
    let nickname: String
    let reaction: String

    /// The same five as in the browser (`b3` in the bundle).
    static let choices: [String] = ["❤️", "🤩", "😂", "💕", "😮"]

    private enum CodingKeys: String, CodingKey { case playerId, nickname, reaction }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        senderId = ((try? c.decode(LooseValue.self, forKey: .playerId)) ?? LooseValue("")).text
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? ""
        reaction = (try? c.decode(String.self, forKey: .reaction)) ?? ""
    }
}

// MARK: - Leaderboard

/// `GET /leaderboard?sort=…&limit=100` - public, readable without an account.
struct Leaderboard: Decodable {
    let entries: [Entry]

    struct Entry: Decodable, Identifiable, Hashable {
        let id: String
        let rankNumber: Int
        let name: String
        let amount: Int
        let pro: Bool
        let admin: Bool
        /// Relative to the site ("/fakester/avatars/u1.webp?v=…") or absolute.
        let avatarPath: String?

        private enum CodingKeys: String, CodingKey { case id, rank, username, value, is_pro, is_admin, avatar_url }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(LooseValue.self, forKey: .id).text
            rankNumber = (try? c.decode(LooseValue.self, forKey: .rank))?.numeric ?? 0
            name = (try? c.decode(String.self, forKey: .username)) ?? ""
            amount = (try? c.decode(LooseValue.self, forKey: .value))?.numeric ?? 0
            pro = (try? c.decode(Bool.self, forKey: .is_pro)) ?? false
            admin = (try? c.decode(Bool.self, forKey: .is_admin)) ?? false
            avatarPath = try? c.decode(String.self, forKey: .avatar_url)
        }

        /// Full URL of the profile picture, if the player has one.
        var avatarURL: URL? {
            guard let p = avatarPath, !p.isEmpty else { return nil }
            if p.hasPrefix("http://") || p.hasPrefix("https://") { return URL(string: p) }
            return URL(string: "https://fakester.app" + (p.hasPrefix("/") ? p : "/" + p))
        }
    }

    /// The tabs as in the browser (`Km` in the bundle).
    struct SortOption: Identifiable, Hashable {
        let id: String
        let name: String
        let unit: String
    }

    static let sortOptions: [SortOption] = [
        SortOption(id: "xp", name: "XP", unit: "XP"),
        SortOption(id: "wins", name: "Wins", unit: "wins"),
        SortOption(id: "highscore", name: "Highscore", unit: "pts"),
        SortOption(id: "games", name: "Games", unit: "games"),
        SortOption(id: "correct", name: "Correct", unit: "correct")
    ]

    private enum CodingKeys: String, CodingKey { case players }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        entries = (try? c.decode(LenientArray<Entry>.self, forKey: .players).items) ?? []
    }
}
