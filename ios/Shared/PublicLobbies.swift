import Foundation

/// `GET /lobbies/public` -> `{"lobbies":[...]}` - public, works without an
/// account. Item fields as the browser's lobby browser reads them (`J3` in the
/// bundle): pin, mode, playlistName, hostName, lang, genre, players, maxPlayers.
struct PublicLobbies: Decodable {
    let lobbies: [PublicLobby]

    private enum CodingKeys: String, CodingKey { case lobbies }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        lobbies = (try? c.decode(LenientArray<PublicLobby>.self, forKey: .lobbies))?.items ?? []
    }
}

struct PublicLobby: Decodable, Identifiable, Hashable {
    var id: String { pin }
    let pin: String
    /// "quiz" | "timeline" | "higherlower" | "reverse" - the app only plays quiz.
    let mode: String
    let playlistName: String?
    let hostName: String
    let lang: String?
    let genre: String?
    let players: Int
    let maxPlayers: Int

    var isFull: Bool { maxPlayers > 0 && players >= maxPlayers }
    var appCanPlay: Bool { mode == "quiz" }

    /// "Taubey · Quiz · German · Rock" - language and genre only when not "Mixed".
    var subtitle: String {
        var parts: [String] = [hostName, PublicLobby.modeLabel(mode)]
        if let l = lang, !l.isEmpty, l.lowercased() != "mixed" { parts.append(l) }
        if let g = genre, !g.isEmpty, g.lowercased() != "mixed" { parts.append(g) }
        return parts.joined(separator: " · ")
    }

    static func modeLabel(_ mode: String) -> String {
        switch mode {
        case "timeline": return "Timeline"
        case "higherlower": return "Higher / Lower"
        case "reverse": return "Reverse"
        default: return "Quiz"
        }
    }

    private enum CodingKeys: String, CodingKey { case pin, mode, playlistName, hostName, lang, genre, players, maxPlayers }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        pin = try c.decode(LooseValue.self, forKey: .pin).text
        mode = (try? c.decode(String.self, forKey: .mode)) ?? "quiz"
        playlistName = try? c.decode(String.self, forKey: .playlistName)
        hostName = (try? c.decode(String.self, forKey: .hostName)) ?? "Host"
        lang = try? c.decode(String.self, forKey: .lang)
        genre = try? c.decode(String.self, forKey: .genre)
        players = (try? c.decode(LooseValue.self, forKey: .players))?.numeric ?? 0
        maxPlayers = (try? c.decode(LooseValue.self, forKey: .maxPlayers))?.numeric ?? 0
    }
}
