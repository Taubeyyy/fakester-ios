import Foundation

/// Das Spielprotokoll von fakester.app, so wie `server.js` es tatsaechlich spricht.
///
/// Alles laeuft ueber einen Umschlag `{type, payload}` auf einer WebSocket unter
/// `/fakester/ws`. Die Formen hier sind aus dem Server abgelesen, nicht aus dem
/// Browser-Client - von dem existiert nur noch das gebaute Bundle, der Server
/// ist die einzige lesbare Wahrheit.

// MARK: - Umschlag

struct Umschlag<Nutzlast: Decodable>: Decodable {
    let type: String
    let payload: Nutzlast?
}

/// Liest nur den Typ. Die Nutzlast wird erst danach in die passende Form
/// dekodiert - zweimal durch dieselben Bytes, aber dafuer typsicher und ohne
/// eine Allerwelts-JSON-Darstellung durch die ganze App zu schleifen.
struct NurTyp: Decodable { let type: String }

// MARK: - Bausteine

struct Bewertung: Decodable, Hashable {
    let points: Int
    let text: String
}

/// Was eine Runde dem Spieler gebracht hat.
///
/// Der Server schickt das NICHT als Woerterbuch aus Bewertungen, sondern mit
/// einer Huelle darum: `{total, breakdown, ownAnswer}`. Direkt aus `server.js`
/// gelesen sah es wie das Innere aus - erst eine mitgeschnittene echte Runde
/// hat die Huelle gezeigt. Ohne sie waere die Aufstellung nach jeder Runde
/// stumm leer geblieben, weil `total` als Zahl das Dekodieren hat scheitern
/// lassen.
struct Punkteblatt: Decodable, Hashable {
    let total: Int
    let breakdown: [String: Bewertung]
    /// Was man selbst geantwortet hat. Beim Quiz Text, bei Timeline eine
    /// Position als Zahl - deshalb `Lose`.
    let ownAnswer: [String: Lose]?

    private enum CodingKeys: String, CodingKey { case total, breakdown, ownAnswer }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        breakdown = (try? c.decode([String: Bewertung].self, forKey: .breakdown)) ?? [:]
        ownAnswer = try? c.decode([String: Lose].self, forKey: .ownAnswer)
    }
}

struct Spieler: Decodable, Identifiable, Hashable {
    let id: Lose
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
    let lastPointsBreakdown: Punkteblatt?
    /// Nur im Endstand gefuellt.
    let rewards: Belohnung?

    private enum CodingKeys: String, CodingKey {
        case id, nickname, score, lives, isEliminated, isConnected, isReady
        case watchOnly, isGuest, isBot, isPro, isAdmin, correctAnswers, bestStreak
        case iconId, titleId, avatarUrl, emoji, lastPointsBreakdown, rewards
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Lose.self, forKey: .id)
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
        lastPointsBreakdown = try? c.decode(Punkteblatt.self, forKey: .lastPointsBreakdown)
        rewards = try? c.decode(Belohnung.self, forKey: .rewards)
    }
}

struct Belohnung: Decodable, Hashable {
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

struct Einstellungen: Decodable, Hashable {
    let songCount: Int
    let guessTime: Int
    let revealTime: Int
    let answerType: String        // "multiple" | "text"
    let guessTypes: [String]      // Teilmenge von title / artist / year
    let playlistName: String?
    let showCover: Bool
    let speedBonus: Bool
    let streakBonus: Bool
    let boxMode: Bool
    let sneakyMode: Bool

    /// Multiple Choice? Alles andere ist Freitext.
    var istMC: Bool { answerType == "multiple" }

    private enum CodingKeys: String, CodingKey {
        case songCount, guessTime, revealTime, answerType, guessTypes
        case playlistName, showCover, speedBonus, streakBonus, boxMode, sneakyMode
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
    }
}

struct Titel: Decodable, Hashable {
    let title: String
    let artist: String
    let year: Int?
    let albumArt: String?

    private enum CodingKeys: String, CodingKey { case title, artist, year, albumArt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        year = (try? c.decode(Lose.self, forKey: .year))?.zahl
        albumArt = try? c.decode(String.self, forKey: .albumArt)
    }
}

// MARK: - Nutzlasten

struct LobbyUpdate: Decodable {
    let pin: String
    let hostId: Lose?
    let gameState: String             // LOBBY | LOADING | PLAYING | FINISHED
    let gameMode: String?
    let players: [Spieler]
    let settings: Einstellungen?

    private enum CodingKeys: String, CodingKey {
        case pin, hostId, gameState, gameMode, players, settings
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        pin = ((try? c.decode(Lose.self, forKey: .pin)) ?? Lose("")).text
        hostId = try? c.decode(Lose.self, forKey: .hostId)
        gameState = (try? c.decode(String.self, forKey: .gameState)) ?? "LOBBY"
        gameMode = try? c.decode(String.self, forKey: .gameMode)
        players = (try? c.decode(Durchlaessig<Spieler>.self, forKey: .players).liste) ?? []
        settings = try? c.decode(Einstellungen.self, forKey: .settings)
    }
}

struct NeueRunde: Decodable {
    let round: Int
    let totalRounds: Int
    let previewUrl: String?
    let albumArt: String?
    let guessTypes: [String]
    let isReverse: Bool
    /// Schonfrist, bevor die Uhr laeuft - der Server rechnet den
    /// Schnelligkeitsbonus erst ab danach.
    let startDelayMs: Int
    /// Auswahlmoeglichkeiten je Rateart. Das Jahr kommt als Zahl, Titel und
    /// Interpret als Text - im selben Objekt. Deshalb `Lose`.
    let mcOptions: [String: [Lose]]

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
        mcOptions = (try? c.decode([String: [Lose]].self, forKey: .mcOptions)) ?? [:]
    }
}

struct RundenErgebnis: Decodable {
    let correctTrack: Titel?
    let scores: [Spieler]
    /// Im Sneaky Mode bleibt der Song verdeckt.
    let sneaky: Bool

    private enum CodingKeys: String, CodingKey { case correctTrack, scores, sneaky }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        correctTrack = try? c.decode(Titel.self, forKey: .correctTrack)
        scores = (try? c.decode(Durchlaessig<Spieler>.self, forKey: .scores).liste) ?? []
        sneaky = (try? c.decode(Bool.self, forKey: .sneaky)) ?? false
    }
}

struct Endstand: Decodable {
    let scores: [Spieler]
    let songs: [Titel]

    private enum CodingKeys: String, CodingKey { case scores, songs }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        scores = (try? c.decode(Durchlaessig<Spieler>.self, forKey: .scores).liste) ?? []
        songs = (try? c.decode(Durchlaessig<Titel>.self, forKey: .songs).liste) ?? []
    }
}

struct LadeStand: Decodable {
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

struct Hinweis: Decodable {
    let message: String
    let isError: Bool
    private enum CodingKeys: String, CodingKey { case message, isError }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        message = (try? c.decode(String.self, forKey: .message)) ?? ""
        isError = (try? c.decode(Bool.self, forKey: .isError)) ?? false
    }
}

struct Rauswurf: Decodable {
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

struct ChatZeile: Decodable, Identifiable, Hashable {
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

struct Zustandsabgleich: Decodable {
    let gameState: String
    let gameMode: String?
    let round: Int
    let totalRounds: Int
    let scores: [Spieler]

    private enum CodingKeys: String, CodingKey { case gameState, gameMode, round, totalRounds, scores }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        gameState = (try? c.decode(String.self, forKey: .gameState)) ?? "LOBBY"
        gameMode = try? c.decode(String.self, forKey: .gameMode)
        round = (try? c.decode(Int.self, forKey: .round)) ?? 0
        totalRounds = (try? c.decode(Int.self, forKey: .totalRounds)) ?? 0
        scores = (try? c.decode(Durchlaessig<Spieler>.self, forKey: .scores).liste) ?? []
    }
}

struct Zaehler: Decodable { let number: Int }

struct Startmeldung: Decodable {
    let message: String?
    private enum CodingKeys: String, CodingKey { case message }
    init(from d: Decoder) throws {
        let c = try? d.container(keyedBy: CodingKeys.self)
        message = try? c?.decode(String.self, forKey: .message)
    }
}

// MARK: - Was die App schickt

/// Die Antwort einer Quiz-Runde. Der Server erwartet durchweg Text, auch beim
/// Jahr - er liest es mit `parseInt`.
struct Antwort: Encodable, Equatable {
    var title: String = ""
    var artist: String = ""
    var year: String = ""

    /// Steht zu jeder verlangten Rateart etwas da?
    func vollstaendig(fuer arten: [String]) -> Bool {
        arten.allSatisfy { art in
            switch art {
            case "title":  return !title.trimmingCharacters(in: .whitespaces).isEmpty
            case "artist": return !artist.trimmingCharacters(in: .whitespaces).isEmpty
            case "year":   return !year.trimmingCharacters(in: .whitespaces).isEmpty
            default:       return true
            }
        }
    }

    subscript(art: String) -> String {
        get {
            switch art {
            case "title":  return title
            case "artist": return artist
            case "year":   return year
            default:       return ""
            }
        }
        set {
            switch art {
            case "title":  title = newValue
            case "artist": artist = newValue
            case "year":   year = newValue
            default:       break
            }
        }
    }
}

/// Der Spieler, so wie ihn `create-game` und `join-game` erwarten. Der Server
/// legt daraus den Lobby-Eintrag an; die Felder heissen dort wie in der
/// Datenbank, daher die Unterstriche.
struct SpielerAusweis: Encodable {
    let id: String
    let username: String
    let isGuest: Bool
    var is_pro: Bool = false
    var is_admin: Bool = false
    var equipped_icon_id: Int = 1
    var equipped_title_id: Int = 1
    var avatar_url: String? = nil
    var equipped_emoji: String? = nil

    /// Gast-IDs muessen eindeutig sein und duerfen mit keiner Konto-ID
    /// kollidieren - der Browser-Client baut sie nach demselben Muster.
    static func gast(name: String) -> SpielerAusweis {
        let zufall = String(UUID().uuidString.prefix(8)).lowercased()
        return SpielerAusweis(id: "guest-\(Int(Date().timeIntervalSince1970 * 1000))-\(zufall)",
                              username: name, isGuest: true)
    }
}
