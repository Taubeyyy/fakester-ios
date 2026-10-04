import Foundation

/// The fakester.app game protocol, as `server.js` actually speaks it.
///
/// Everything goes through an envelope `{type, payload}` on a WebSocket at
/// `/fakester/ws`. The shapes here were read from the server, not from the
/// browser client - only its built bundle still exists, so the server is the
/// only readable source of truth.

// MARK: - Envelope

struct Envelope<Payload: Decodable>: Decodable {
    let type: String
    let payload: Payload?
}

/// Reads only the type. The payload is decoded into the matching shape
/// afterwards - two passes over the same bytes, but type-safe and without
/// dragging a catch-all JSON representation through the whole app.
struct TypeOnly: Decodable { let type: String }

// MARK: - Building blocks

struct ScoreItem: Decodable, Hashable {
    let points: Int
    let text: String
}

/// What a round earned the player.
///
/// The server does NOT send this as a dictionary of scores but with a wrapper
/// around it: `{total, breakdown, ownAnswer}`. Read straight from `server.js`
/// it looked like the inner part - only a captured real round revealed the
/// wrapper. Without it the breakdown would have silently stayed empty after
/// every round, because `total` being a number made decoding fail.
struct PointsBreakdown: Decodable, Hashable {
    let total: Int
    let breakdown: [String: ScoreItem]
    /// What the player answered. Text in quiz mode, a position as a number
    /// in timeline mode - hence `LooseValue`.
    let ownAnswer: [String: LooseValue]?

    private enum CodingKeys: String, CodingKey { case total, breakdown, ownAnswer }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        breakdown = (try? c.decode([String: ScoreItem].self, forKey: .breakdown)) ?? [:]
        ownAnswer = try? c.decode([String: LooseValue].self, forKey: .ownAnswer)
    }
}

struct Player: Decodable, Identifiable, Hashable {
    let id: LooseValue
    let nickname: String
    let score: Int
    let lives: Int?
    let isEliminated: Bool
    let isConnected: Bool
    let isReady: Bool
    let watchOnly: Bool
    let isGuest: Bool
    let isBot: Bool
    let isPro: Bool
    let isAdmin: Bool
    let correctAnswers: Int
    let bestStreak: Int
    let iconId: Int
    let titleId: Int
    let avatarUrl: String?
    let emoji: String?
    let lastPointsBreakdown: PointsBreakdown?
    /// Only filled in the final standings.
    let rewards: Reward?

    private enum CodingKeys: String, CodingKey {
        case id, nickname, score, lives, isEliminated, isConnected, isReady
        case watchOnly, isGuest, isBot, isPro, isAdmin, correctAnswers, bestStreak
        case iconId, titleId, avatarUrl, emoji, lastPointsBreakdown, rewards
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(LooseValue.self, forKey: .id)
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? "?"
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        lives = try? c.decode(Int.self, forKey: .lives)
        isEliminated = (try? c.decode(Bool.self, forKey: .isEliminated)) ?? false
        isConnected = (try? c.decode(Bool.self, forKey: .isConnected)) ?? true
        isReady = (try? c.decode(Bool.self, forKey: .isReady)) ?? false
        watchOnly = (try? c.decode(Bool.self, forKey: .watchOnly)) ?? false
        isGuest = (try? c.decode(Bool.self, forKey: .isGuest)) ?? false
        isBot = (try? c.decode(Bool.self, forKey: .isBot)) ?? false
        isPro = (try? c.decode(Bool.self, forKey: .isPro)) ?? false
        isAdmin = (try? c.decode(Bool.self, forKey: .isAdmin)) ?? false
        correctAnswers = (try? c.decode(Int.self, forKey: .correctAnswers)) ?? 0
        bestStreak = (try? c.decode(Int.self, forKey: .bestStreak)) ?? 0
        iconId = (try? c.decode(Int.self, forKey: .iconId)) ?? 1
        titleId = (try? c.decode(Int.self, forKey: .titleId)) ?? 1
        avatarUrl = try? c.decode(String.self, forKey: .avatarUrl)
        emoji = try? c.decode(String.self, forKey: .emoji)
        lastPointsBreakdown = try? c.decode(PointsBreakdown.self, forKey: .lastPointsBreakdown)
        rewards = try? c.decode(Reward.self, forKey: .rewards)
    }
}

struct Reward: Decodable, Hashable {
    let xp: Int
    let spots: Int
    let goldSpots: Int

    private enum CodingKeys: String, CodingKey { case xp, spots, goldSpots }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        spots = (try? c.decode(Int.self, forKey: .spots)) ?? 0
        goldSpots = (try? c.decode(Int.self, forKey: .goldSpots)) ?? 0
    }
}

struct LobbySettings: Decodable, Hashable {
    let songCount: Int
    let guessTime: Int
    let revealTime: Int
    let answerType: String        // "multiple" | "text"
    let guessTypes: [String]      // subset of title / artist / year
    let playlistName: String?
    let showCover: Bool
    let speedBonus: Bool
    let streakBonus: Bool
    let boxMode: Bool
    let sneakyMode: Bool
    let hostPlays: Bool
    let playlistId: String?
    /// The playlist mix as the server keeps it - passed back unchanged when the
    /// host edits the other settings.
    let playlists: [PlaylistRef]

    /// One playlist of the mix: `{id, source, name, weight, maxSongs?}`.
    struct PlaylistRef: Decodable, Hashable {
        let id: String
        let source: String
        let name: String
        let weight: Int
        let maxSongs: Int?

        private enum CodingKeys: String, CodingKey { case id, source, name, weight, maxSongs }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = ((try? c.decode(LooseValue.self, forKey: .id)) ?? LooseValue("")).text
            source = (try? c.decode(String.self, forKey: .source)) ?? "spotify"
            name = (try? c.decode(String.self, forKey: .name)) ?? "Playlist"
            weight = (try? c.decode(LooseValue.self, forKey: .weight))?.numeric ?? 1
            maxSongs = (try? c.decode(LooseValue.self, forKey: .maxSongs))?.numeric
        }

        /// Back into the shape the server expects (`q1` in the bundle).
        var payload: [String: Any] {
            var d: [String: Any] = ["id": id, "source": source, "name": name, "weight": weight]
            if let m = maxSongs { d["maxSongs"] = m }
            return d
        }
    }

    /// Multiple choice? Anything else is free text.
    var isMultipleChoice: Bool { answerType == "multiple" }

    private enum CodingKeys: String, CodingKey {
        case songCount, guessTime, revealTime, answerType, guessTypes
        case playlistName, showCover, speedBonus, streakBonus, boxMode, sneakyMode
        case hostPlays, playlistId, playlists
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        songCount = (try? c.decode(Int.self, forKey: .songCount)) ?? 10
        guessTime = (try? c.decode(Int.self, forKey: .guessTime)) ?? 30
        revealTime = (try? c.decode(Int.self, forKey: .revealTime)) ?? 5
        answerType = (try? c.decode(String.self, forKey: .answerType)) ?? "multiple"
        guessTypes = (try? c.decode([String].self, forKey: .guessTypes)) ?? ["title", "artist"]
        playlistName = try? c.decode(String.self, forKey: .playlistName)
        showCover = (try? c.decode(Bool.self, forKey: .showCover)) ?? true
        speedBonus = (try? c.decode(Bool.self, forKey: .speedBonus)) ?? true
        streakBonus = (try? c.decode(Bool.self, forKey: .streakBonus)) ?? true
        boxMode = (try? c.decode(Bool.self, forKey: .boxMode)) ?? false
        sneakyMode = (try? c.decode(Bool.self, forKey: .sneakyMode)) ?? false
        hostPlays = (try? c.decode(Bool.self, forKey: .hostPlays)) ?? true
        playlistId = (try? c.decode(LooseValue.self, forKey: .playlistId))?.text
        playlists = (try? c.decode(LenientArray<PlaylistRef>.self, forKey: .playlists))?.items ?? []
    }
}

struct Track: Decodable, Hashable {
    let title: String
    let artist: String
    let year: Int?
    let albumArt: String?

    private enum CodingKeys: String, CodingKey { case title, artist, year, albumArt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        year = (try? c.decode(LooseValue.self, forKey: .year))?.numeric
        albumArt = try? c.decode(String.self, forKey: .albumArt)
    }
}

// MARK: - Payloads

struct LobbyUpdate: Decodable {
    let pin: String
    let hostId: LooseValue?
    let gameState: String             // LOBBY | LOADING | PLAYING | FINISHED
    let gameMode: String?
    let players: [Player]
    let settings: LobbySettings?

    private enum CodingKeys: String, CodingKey {
        case pin, hostId, gameState, gameMode, players, settings
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        pin = ((try? c.decode(LooseValue.self, forKey: .pin)) ?? LooseValue("")).text
        hostId = try? c.decode(LooseValue.self, forKey: .hostId)
        gameState = (try? c.decode(String.self, forKey: .gameState)) ?? "LOBBY"
        gameMode = try? c.decode(String.self, forKey: .gameMode)
        players = (try? c.decode(LenientArray<Player>.self, forKey: .players).items) ?? []
        settings = try? c.decode(LobbySettings.self, forKey: .settings)
    }
}

struct NewRound: Decodable {
    let round: Int
    let totalRounds: Int
    let previewUrl: String?
    let albumArt: String?
    let guessTypes: [String]
    let isReverse: Bool
    /// Grace period before the clock starts - the server only counts the
    /// speed bonus from then on.
    let startDelayMs: Int
    /// Choices per guess type. The year arrives as a number, title and artist
    /// as text - in the same object. Hence `LooseValue`.
    let mcOptions: [String: [LooseValue]]

    private enum CodingKeys: String, CodingKey {
        case round, totalRounds, previewUrl, albumArt, guessTypes, isReverse, startDelayMs, mcOptions
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        round = (try? c.decode(Int.self, forKey: .round)) ?? 0
        totalRounds = (try? c.decode(Int.self, forKey: .totalRounds)) ?? 0
        previewUrl = try? c.decode(String.self, forKey: .previewUrl)
        albumArt = try? c.decode(String.self, forKey: .albumArt)
        guessTypes = (try? c.decode([String].self, forKey: .guessTypes)) ?? []
        isReverse = (try? c.decode(Bool.self, forKey: .isReverse)) ?? false
        startDelayMs = (try? c.decode(Int.self, forKey: .startDelayMs)) ?? 0
        mcOptions = (try? c.decode([String: [LooseValue]].self, forKey: .mcOptions)) ?? [:]
    }
}

struct RoundResult: Decodable {
    let correctTrack: Track?
    let scores: [Player]
    /// In sneaky mode the song stays hidden.
    let sneaky: Bool

    private enum CodingKeys: String, CodingKey { case correctTrack, scores, sneaky }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        correctTrack = try? c.decode(Track.self, forKey: .correctTrack)
        scores = (try? c.decode(LenientArray<Player>.self, forKey: .scores).items) ?? []
        sneaky = (try? c.decode(Bool.self, forKey: .sneaky)) ?? false
    }
}

struct FinalStandings: Decodable {
    let scores: [Player]
    let songs: [Track]

    private enum CodingKeys: String, CodingKey { case scores, songs }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        scores = (try? c.decode(LenientArray<Player>.self, forKey: .scores).items) ?? []
        songs = (try? c.decode(LenientArray<Track>.self, forKey: .songs).items) ?? []
    }
}

struct LoadingProgress: Decodable {
    let checked: Int
    let total: Int
    let playable: Int
    let needed: Int?

    private enum CodingKeys: String, CodingKey { case checked, total, playable, needed }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        checked = (try? c.decode(Int.self, forKey: .checked)) ?? 0
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        playable = (try? c.decode(Int.self, forKey: .playable)) ?? 0
        needed = try? c.decode(Int.self, forKey: .needed)
    }
}

struct ToastMessage: Decodable {
    let message: String
    let isError: Bool
    private enum CodingKeys: String, CodingKey { case message, isError }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        message = (try? c.decode(String.self, forKey: .message)) ?? ""
        isError = (try? c.decode(Bool.self, forKey: .isError)) ?? false
    }
}

struct KickNotice: Decodable {
    let reason: String?
    let banned: Bool
    let minutesLeft: Int?
    private enum CodingKeys: String, CodingKey { case reason, banned, minutesLeft }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        reason = try? c.decode(String.self, forKey: .reason)
        banned = (try? c.decode(Bool.self, forKey: .banned)) ?? false
        minutesLeft = try? c.decode(Int.self, forKey: .minutesLeft)
    }
}

struct ChatLine: Decodable, Identifiable, Hashable {
    let id = UUID()
    let nickname: String
    let text: String
    let system: Bool

    private enum CodingKeys: String, CodingKey { case nickname, text, system }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? ""
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        system = (try? c.decode(Bool.self, forKey: .system)) ?? false
    }
}

struct StateSync: Decodable {
    let gameState: String
    let gameMode: String?
    let round: Int
    let totalRounds: Int
    let scores: [Player]

    private enum CodingKeys: String, CodingKey { case gameState, gameMode, round, totalRounds, scores }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        gameState = (try? c.decode(String.self, forKey: .gameState)) ?? "LOBBY"
        gameMode = try? c.decode(String.self, forKey: .gameMode)
        round = (try? c.decode(Int.self, forKey: .round)) ?? 0
        totalRounds = (try? c.decode(Int.self, forKey: .totalRounds)) ?? 0
        scores = (try? c.decode(LenientArray<Player>.self, forKey: .scores).items) ?? []
    }
}

struct CountdownTick: Decodable { let number: Int }

struct StartMessage: Decodable {
    let message: String?
    private enum CodingKeys: String, CodingKey { case message }
    init(from d: Decoder) throws {
        let c = try? d.container(keyedBy: CodingKeys.self)
        message = try? c?.decode(String.self, forKey: .message)
    }
}

// MARK: - What the app sends

/// The answer for a quiz round. The server expects text throughout, even for
/// the year - it reads it with `parseInt`.
struct Answer: Encodable, Equatable {
    var title: String = ""
    var artist: String = ""
    var year: String = ""

    /// Is there something filled in for every required guess type?
    func isComplete(covering kinds: [String]) -> Bool {
        kinds.allSatisfy { kind in
            switch kind {
            case "title":  return !title.trimmingCharacters(in: .whitespaces).isEmpty
            case "artist": return !artist.trimmingCharacters(in: .whitespaces).isEmpty
            case "year":   return !year.trimmingCharacters(in: .whitespaces).isEmpty
            default:       return true
            }
        }
    }

    subscript(kind: String) -> String {
        get {
            switch kind {
            case "title":  return title
            case "artist": return artist
            case "year":   return year
            default:       return ""
            }
        }
        set {
            switch kind {
            case "title":  title = newValue
            case "artist": artist = newValue
            case "year":   year = newValue
            default:       break
            }
        }
    }
}

/// The player as `create-game` and `join-game` expect it. The server builds
/// the lobby entry from it; the fields are named as in the database, hence
/// the underscores.
struct PlayerIdentity: Encodable {
    let id: String
    let username: String
    let isGuest: Bool
    var is_pro: Bool = false
    var is_admin: Bool = false
    var equipped_icon_id: Int = 1
    var equipped_title_id: Int = 1
    var avatar_url: String? = nil
    var equipped_emoji: String? = nil

    /// Guest IDs must be unique and must not collide with any account ID -
    /// the browser client builds them with the same pattern.
    static func guest(name: String) -> PlayerIdentity {
        let randomSuffix = String(UUID().uuidString.prefix(8)).lowercased()
        return PlayerIdentity(id: "guest-\(Int(Date().timeIntervalSince1970 * 1000))-\(randomSuffix)",
                              username: name, isGuest: true)
    }
}
