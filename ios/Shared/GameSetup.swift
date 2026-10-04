import Foundation

// Was die App neu kann: ein Spiel selbst aufmachen, im Spiel mit Emojis
// reagieren und die Bestenliste ansehen. Die Formen hier sind am 2026-10-04
// gegen den laufenden Server geprueft (siehe Tests/Mitschnitt.swift) - nicht
// nur aus dem Web-Bundle abgelesen.

// MARK: - Spiel erstellen

/// Eine Playlist im Mix. Der Browser erlaubt mehrere und gewichtet sie; die App
/// faengt mit einer an und schickt sie in derselben Form.
struct PlaylistEntry: Hashable, Identifiable {
    let id: String
    let name: String
    let picture: String?
    let origin: String      // "spotify" | "youtube"
}

/// Antwort von `GET /playlist/info?url=…`.
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

/// Antwort von `GET /playlists/featured`.
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

/// Die Einstellungen fuer `create-game`. Feldnamen genau wie im Browser
/// (`F3` im Bundle), der Server liest sie so.
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
        // Wie im Browser: nichts gewaehlt heisst Titel.
        return a.isEmpty ? ["title"] : a
    }

    /// Ohne Playlist gibt es nichts zu senden - der Knopf bleibt dann aus.
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

// MARK: - Reaktionen

/// `player-reacted` - jemand hat auf einen Emoji-Knopf gedrueckt.
struct Reaction: Decodable, Identifiable, Hashable {
    let id = UUID()
    let senderId: String
    let nickname: String
    let reaction: String

    /// Dieselben fuenf wie im Browser (`b3` im Bundle).
    static let choices: [String] = ["❤️", "🤩", "😂", "💕", "😮"]

    private enum CodingKeys: String, CodingKey { case playerId, nickname, reaction }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        senderId = ((try? c.decode(LooseValue.self, forKey: .playerId)) ?? LooseValue("")).text
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? ""
        reaction = (try? c.decode(String.self, forKey: .reaction)) ?? ""
    }
}

// MARK: - Bestenliste

/// `GET /leaderboard?sort=…&limit=100` - oeffentlich, ohne Konto lesbar.
struct Leaderboard: Decodable {
    let entries: [Entry]

    struct Entry: Decodable, Identifiable, Hashable {
        let id: String
        let rankNumber: Int
        let name: String
        let amount: Int
        let pro: Bool

        private enum CodingKeys: String, CodingKey { case id, rank, username, value, is_pro }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(LooseValue.self, forKey: .id).text
            rankNumber = (try? c.decode(LooseValue.self, forKey: .rank))?.numeric ?? 0
            name = (try? c.decode(String.self, forKey: .username)) ?? ""
            amount = (try? c.decode(LooseValue.self, forKey: .value))?.numeric ?? 0
            pro = (try? c.decode(Bool.self, forKey: .is_pro)) ?? false
        }
    }

    /// Die Reiter wie im Browser (`Km` im Bundle).
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
