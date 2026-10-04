import Foundation

// Was die App neu kann: ein Spiel selbst aufmachen, im Spiel mit Emojis
// reagieren und die Bestenliste ansehen. Die Formen hier sind am 2026-10-04
// gegen den laufenden Server geprueft (siehe Tests/Mitschnitt.swift) - nicht
// nur aus dem Web-Bundle abgelesen.

// MARK: - Spiel erstellen

/// Eine Playlist im Mix. Der Browser erlaubt mehrere und gewichtet sie; die App
/// faengt mit einer an und schickt sie in derselben Form.
struct PlaylistEintrag: Hashable, Identifiable {
    let id: String
    let name: String
    let bild: String?
    let quelle: String      // "spotify" | "youtube"
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
        id = ((try? c.decode(Lose.self, forKey: .id)) ?? Lose("")).text
        name = (try? c.decode(String.self, forKey: .name)) ?? "Playlist"
        image = try? c.decode(String.self, forKey: .image)
        source = (try? c.decode(String.self, forKey: .source)) ?? "spotify"
        trackCount = (try? c.decode(Lose.self, forKey: .trackCount))?.zahl
    }

    var eintrag: PlaylistEintrag {
        PlaylistEintrag(id: id, name: name, bild: image, quelle: source)
    }
}

/// Antwort von `GET /playlists/featured`.
struct EmpfohleneListen: Decodable {
    let eintraege: [PlaylistEintrag]

    private struct Roh: Decodable {
        let playlist_id: String
        let playlist_name: String?
        let playlist_image: String?
        private enum CodingKeys: String, CodingKey { case playlist_id, playlist_name, playlist_image }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            playlist_id = try c.decode(Lose.self, forKey: .playlist_id).text
            playlist_name = try? c.decode(String.self, forKey: .playlist_name)
            playlist_image = try? c.decode(String.self, forKey: .playlist_image)
        }
    }

    private enum CodingKeys: String, CodingKey { case playlists }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let roh: [Roh] = (try? c.decode(Durchlaessig<Roh>.self, forKey: .playlists).liste) ?? []
        eintraege = roh.map { r in
            PlaylistEintrag(id: r.playlist_id, name: r.playlist_name ?? "Featured",
                            bild: r.playlist_image, quelle: "spotify")
        }
    }
}

/// Die Einstellungen fuer `create-game`. Feldnamen genau wie im Browser
/// (`F3` im Bundle), der Server liest sie so.
struct SpielVorgabe: Equatable {
    var playlist: PlaylistEintrag?
    var songs: Int = 10
    var rateZeit: Int = 30
    var titel = true
    var interpret = true
    var jahr = true
    var freitext = false
    var pause: Int = 5
    var cover = true
    var tempoBonus = true
    var serienBonus = true
    var sneaky = false
    var oeffentlich = false

    static let songWahl: [Int] = [5, 10, 15, 20]
    static let zeitWahl: [Int] = [20, 30, 45, 60]
    static let pausenWahl: [Int] = [3, 5, 8]

    var rateArten: [String] {
        var a: [String] = []
        if titel { a.append("title") }
        if interpret { a.append("artist") }
        if jahr { a.append("year") }
        // Wie im Browser: nichts gewaehlt heisst Titel.
        return a.isEmpty ? ["title"] : a
    }

    /// Ohne Playlist gibt es nichts zu senden - der Knopf bleibt dann aus.
    func nutzlast() -> [String: Any]? {
        guard let p = playlist else { return nil }
        return [
            "playlistId": p.id,
            "playlistName": p.name,
            "playlists": [["id": p.id, "source": p.quelle, "name": p.name, "weight": 1]],
            "gameMode": "quiz",
            "songCount": songs,
            "guessTime": rateZeit,
            "guessTypes": rateArten,
            "answerType": freitext ? "freestyle" : "multiple",
            "revealTime": pause,
            "showCover": cover,
            "speedBonus": tempoBonus,
            "streakBonus": serienBonus,
            "boxMode": false,
            "hostPlays": true,
            "sneakyMode": sneaky,
            "lobbyLang": "Mixed",
            "lobbyGenre": "Mixed",
            "isPublic": oeffentlich
        ]
    }
}

// MARK: - Reaktionen

/// `player-reacted` - jemand hat auf einen Emoji-Knopf gedrueckt.
struct Reaktion: Decodable, Identifiable, Hashable {
    let id = UUID()
    let spielerId: String
    let nickname: String
    let reaction: String

    /// Dieselben fuenf wie im Browser (`b3` im Bundle).
    static let auswahl: [String] = ["❤️", "🤩", "😂", "💕", "😮"]

    private enum CodingKeys: String, CodingKey { case playerId, nickname, reaction }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        spielerId = ((try? c.decode(Lose.self, forKey: .playerId)) ?? Lose("")).text
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? ""
        reaction = (try? c.decode(String.self, forKey: .reaction)) ?? ""
    }
}

// MARK: - Bestenliste

/// `GET /leaderboard?sort=…&limit=100` - oeffentlich, ohne Konto lesbar.
struct Bestenliste: Decodable {
    let eintraege: [Eintrag]

    struct Eintrag: Decodable, Identifiable, Hashable {
        let id: String
        let rang: Int
        let name: String
        let wert: Int
        let pro: Bool

        private enum CodingKeys: String, CodingKey { case id, rank, username, value, is_pro }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(Lose.self, forKey: .id).text
            rang = (try? c.decode(Lose.self, forKey: .rank))?.zahl ?? 0
            name = (try? c.decode(String.self, forKey: .username)) ?? ""
            wert = (try? c.decode(Lose.self, forKey: .value))?.zahl ?? 0
            pro = (try? c.decode(Bool.self, forKey: .is_pro)) ?? false
        }
    }

    /// Die Reiter wie im Browser (`Km` im Bundle).
    struct Sortierung: Identifiable, Hashable {
        let id: String
        let name: String
        let einheit: String
    }

    static let sortierungen: [Sortierung] = [
        Sortierung(id: "xp", name: "XP", einheit: "XP"),
        Sortierung(id: "wins", name: "Wins", einheit: "wins"),
        Sortierung(id: "highscore", name: "Highscore", einheit: "pts"),
        Sortierung(id: "games", name: "Games", einheit: "games"),
        Sortierung(id: "correct", name: "Correct", einheit: "correct")
    ]

    private enum CodingKeys: String, CodingKey { case players }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        eintraege = (try? c.decode(Durchlaessig<Eintrag>.self, forKey: .players).liste) ?? []
    }
}
