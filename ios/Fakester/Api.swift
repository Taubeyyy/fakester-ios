import Foundation

/// REST-Teil von fakester.app: anmelden, registrieren, Profil holen.
///
/// Alles unter `https://fakester.app/fakester` - der Express-Router haengt dort,
/// nicht unter `/api`, auch wenn der Pfad das nahelegen wuerde. Das Spiel selbst
/// laeuft nicht hierueber, sondern ueber die WebSocket in `Verbindung.swift`.
@MainActor
final class Api: ObservableObject {
    static let shared = Api()

    static let baseURL = URL(string: "https://fakester.app/fakester")!

    /// Token und Spielername ueberleben den Appstart. Mehr wird nicht
    /// gespeichert - alles andere holt das Profil frisch, sonst zeigt die App
    /// Spots und Rang von vorgestern.
    @Published private(set) var token: String?
    @Published private(set) var me: Account?
    /// Gaeste haben kein Konto. Der Ausweis wird einmal gebaut und behalten,
    /// damit ein Neustart in derselben Lobby nicht als zweiter Spieler landet.
    @Published private(set) var guest: PlayerIdentity?

    private let store = UserDefaults.standard

    private init() {
        token = store.string(forKey: "api.token")
        if let d = store.data(forKey: "api.ich") {
            me = try? JSONDecoder().decode(Account.self, from: d)
        }
        if let id = store.string(forKey: "gast.id"), let name = store.string(forKey: "gast.name") {
            guest = PlayerIdentity(id: id, username: name, isGuest: true)
        }
    }

    var isLoggedIn: Bool { token != nil && me != nil }

    /// Wer sitzt am Tisch - Konto oder Gast. Genau das verlangen `create-game`
    /// und `join-game`.
    var identity: PlayerIdentity? {
        if let k = me {
            return PlayerIdentity(id: String(k.id.text), username: k.username, isGuest: false,
                                  is_pro: k.is_pro, is_admin: k.is_admin,
                                  equipped_icon_id: k.equipped_icon_id ?? 1,
                                  equipped_title_id: k.equipped_title_id ?? 1,
                                  avatar_url: k.avatar_url, equipped_emoji: k.equipped_emoji)
        }
        return guest
    }

    // MARK: - Konto

    struct Account: Codable {
        let id: LooseValue
        let username: String
        var xp: Int?
        var spots: Int?
        var gold_spots: Int?
        var games_played: Int?
        var wins: Int?
        var highscore: Int?
        var is_pro: Bool = false
        var is_admin: Bool = false
        var equipped_icon_id: Int?
        var equipped_title_id: Int?
        var avatar_url: String?
        var equipped_emoji: String?

        private enum CodingKeys: String, CodingKey {
            case id, username, xp, spots, gold_spots, is_pro, is_admin
            case games_played, wins, highscore
            case equipped_icon_id, equipped_title_id, avatar_url, equipped_emoji
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(LooseValue.self, forKey: .id)
            username = (try? c.decode(String.self, forKey: .username)) ?? "?"
            xp = try? c.decode(Int.self, forKey: .xp)
            spots = try? c.decode(Int.self, forKey: .spots)
            gold_spots = try? c.decode(Int.self, forKey: .gold_spots)
            games_played = try? c.decode(Int.self, forKey: .games_played)
            wins = try? c.decode(Int.self, forKey: .wins)
            highscore = try? c.decode(Int.self, forKey: .highscore)
            is_pro = (try? c.decode(Bool.self, forKey: .is_pro)) ?? false
            is_admin = (try? c.decode(Bool.self, forKey: .is_admin)) ?? false
            equipped_icon_id = try? c.decode(Int.self, forKey: .equipped_icon_id)
            equipped_title_id = try? c.decode(Int.self, forKey: .equipped_title_id)
            avatar_url = try? c.decode(String.self, forKey: .avatar_url)
            equipped_emoji = try? c.decode(String.self, forKey: .equipped_emoji)
        }
    }

    /// Die Form, in der der Server eine Absage begruendet.
    private struct ErrorReply: Decodable { let error: String? }

    /// Stufe und Fortschritt, genau wie der Server rechnet:
    /// `levelForXp(xp) = max(1, floor((25 + sqrt(625 + 100*xp)) / 50))`.
    /// Nachgebaut statt geschaetzt - eine Stufe, die in der App anders steht
    /// als im Browser, ist schlimmer als gar keine.
    enum Level {
        static func forXP(_ xp: Int) -> Int {
            max(1, Int((25.0 + (625.0 + 100.0 * Double(max(0, xp))).squareRoot()) / 50.0))
        }

        /// Ab wie viel XP diese Stufe beginnt - die Umkehrung der Formel oben.
        static func minXP(_ level: Int) -> Int {
            let g = 50.0 * Double(level) - 25.0
            return max(0, Int((g * g - 625.0) / 100.0))
        }

        /// Anteil 0…1 innerhalb der laufenden Stufe.
        static func fraction(xp: Int) -> Double {
            let l = forXP(xp)
            let lowerXP = minXP(l), upperXP = minXP(l + 1)
            guard upperXP > lowerXP else { return 0 }
            return min(1, max(0, Double(xp - lowerXP) / Double(upperXP - lowerXP)))
        }
    }

    enum RequestError: LocalizedError {
        case notice(String)
        var errorDescription: String? {
            if case .notice(let m) = self { return m }
            return nil
        }
    }

    // MARK: - Anmelden

    private struct LoginResponse: Decodable {
        let token: String?
        let user: Account?
    }

    func logIn(name: String, passwordText: String) async throws {
        try await authenticate("/auth/login", name: name, passwordText: passwordText)
    }

    func register(name: String, passwordText: String) async throws {
        try await authenticate("/auth/register", name: name, passwordText: passwordText)
    }

    private func authenticate(_ path: String, name: String, passwordText: String) async throws {
        let answer: LoginResponse = try await perform(
            path, method: "POST",
            jsonBody: ["username": name.trimmingCharacters(in: .whitespaces), "password": passwordText],
            withToken: false)
        guard let t = answer.token, let u = answer.user else {
            throw RequestError.notice("The server didn't send back a login.")
        }
        token = t
        me = u
        store.set(t, forKey: "api.token")
        store.set(try? JSONEncoder().encode(u), forKey: "api.ich")
    }

    /// Raeumt beides ab - Konto UND Gast. Ohne das Zweite stuende ein Gast nach
    /// dem Abmelden sofort wieder mit demselben Namen da, weil der Ausweis die
    /// Anmeldung gar nicht braucht.
    func logOut() {
        token = nil
        me = nil
        guest = nil
        store.removeObject(forKey: "api.token")
        store.removeObject(forKey: "api.ich")
        store.removeObject(forKey: "gast.id")
        store.removeObject(forKey: "gast.name")
    }

    /// Gast bleibt Gast, bis er einen anderen Namen waehlt.
    func playAsGuest(name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespaces)
        if let g = guest, g.username == cleaned { return }
        let latest = PlayerIdentity.guest(name: cleaned)
        guest = latest
        store.set(latest.id, forKey: "gast.id")
        store.set(latest.username, forKey: "gast.name")
    }

    // MARK: - Profil

    func refreshProfile() async {
        guard token != nil else { return }
        struct ProfileResponse: Decodable { let user: Account? }
        if let p: ProfileResponse = try? await perform("/profile", method: "GET", jsonBody: nil, withToken: true),
           let u = p.user {
            me = u
            store.set(try? JSONEncoder().encode(u), forKey: "api.ich")
        }
    }

    // MARK: - Lesen ohne Seiteneffekt

    /// GET mit Abfrage, z. B. `/leaderboard?sort=xp`. Das Token geht mit, wenn
    /// es eins gibt - die Endpunkte hier gehen aber auch fuer Gaeste.
    func fetch<T: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws -> T {
        try await perform(path, method: "GET", jsonBody: nil, withToken: token != nil, query: query)
    }

    /// POST mit Konto (Quests abholen, taegliche Belohnung).
    func transmit<T: Decodable>(_ path: String, _ jsonBody: [String: String] = [:]) async throws -> T {
        try await perform(path, method: "POST", jsonBody: jsonBody, withToken: true)
    }

    /// Nach dem Abholen schickt der Server den neuen Spots-Stand mit - der soll
    /// sofort oben rechts stehen, nicht erst nach dem naechsten Profilabruf.
    func setSpots(_ latest: Int) {
        guard var k = me else { return }
        k.spots = latest
        me = k
        store.set(try? JSONEncoder().encode(k), forKey: "api.ich")
    }

    // MARK: - Unterbau

    private func perform<T: Decodable>(_ path: String, method: String,
                                   jsonBody: [String: String]?, withToken: Bool,
                                   query: [String: String] = [:]) async throws -> T {
        var address: URL = Api.baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        if !query.isEmpty, var components = URLComponents(url: address, resolvingAgainstBaseURL: false) {
            // Selbst kodiert: URLComponents laesst & und = in Werten stehen, und
            // ein Spotify-Link mit "?si=…" zerfiele dann in zwei Parameter.
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let pairs: [String] = query.keys.sorted().map { k in
                let v: String = query[k] ?? ""
                return k + "=" + (v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v)
            }
            components.percentEncodedQuery = pairs.joined(separator: "&")
            if let u = components.url { address = u }
        }
        var request = URLRequest(url: address)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if withToken, let t = token {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        if let k = jsonBody {
            request.httpBody = try JSONSerialization.data(withJSONObject: k)
        }

        let (bytes, answer): (Data, URLResponse)
        do {
            (bytes, answer) = try await URLSession.shared.data(for: request)
        } catch {
            throw RequestError.notice("No connection to the server.")
        }

        let code = (answer as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) {
            // Der Server begruendet seine Absagen - die Begruendung ist
            // brauchbarer als ein Statuscode ("Wrong login details", der
            // Bann-Text mitsamt Restzeit).
            let base = (try? JSONDecoder().decode(ErrorReply.self, from: bytes))?.error
            throw RequestError.notice(base ?? "The server refused (\(code)).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: bytes)
        } catch {
            throw RequestError.notice("Couldn't read the server's response.")
        }
    }
}
