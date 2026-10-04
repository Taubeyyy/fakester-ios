import Foundation

/// The REST side of fakester.app: log in, register, fetch the profile.
///
/// Everything lives under `https://fakester.app/fakester` - the Express router is
/// mounted there, not under `/api`, even if the path suggests otherwise. The game
/// itself doesn't run through here but through the WebSocket in `Connection.swift`.
@MainActor
final class Api: ObservableObject {
    static let shared = Api()

    static let baseURL = URL(string: "https://fakester.app/fakester")!

    /// Token and player name survive an app restart. Nothing else is stored -
    /// everything else comes fresh from the profile, otherwise the app would
    /// show spots and rank from the day before yesterday.
    @Published private(set) var token: String?
    @Published private(set) var me: Account?
    /// Guests have no account. The identity is built once and kept, so a
    /// restart in the same lobby doesn't show up as a second player.
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

    /// Who is at the table - account or guest. Exactly what `create-game`
    /// and `join-game` expect.
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

    // MARK: - Account

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

    /// The shape in which the server explains a refusal.
    private struct ErrorReply: Decodable { let error: String? }

    /// Level and progress, computed exactly like the server does:
    /// `levelForXp(xp) = max(1, floor((25 + sqrt(625 + 100*xp)) / 50))`.
    /// Replicated rather than estimated - a level that differs between the app
    /// and the browser is worse than none at all.
    enum Level {
        static func forXP(_ xp: Int) -> Int {
            max(1, Int((25.0 + (625.0 + 100.0 * Double(max(0, xp))).squareRoot()) / 50.0))
        }

        /// The XP at which this level starts - the inverse of the formula above.
        static func minXP(_ level: Int) -> Int {
            let g = 50.0 * Double(level) - 25.0
            return max(0, Int((g * g - 625.0) / 100.0))
        }

        /// Fraction 0…1 within the current level.
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

    // MARK: - Login

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

    /// Clears both - account AND guest. Without the latter, a guest would be
    /// back with the same name right after logging out, because the identity
    /// doesn't need a login at all.
    func logOut() {
        token = nil
        me = nil
        guest = nil
        store.removeObject(forKey: "api.token")
        store.removeObject(forKey: "api.ich")
        store.removeObject(forKey: "gast.id")
        store.removeObject(forKey: "gast.name")
    }

    /// A guest stays the same guest until they pick a different name.
    func playAsGuest(name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespaces)
        if let g = guest, g.username == cleaned { return }
        let latest = PlayerIdentity.guest(name: cleaned)
        guest = latest
        store.set(latest.id, forKey: "gast.id")
        store.set(latest.username, forKey: "gast.name")
    }

    // MARK: - Profile

    func refreshProfile() async {
        guard token != nil else { return }
        struct ProfileResponse: Decodable { let user: Account? }
        if let p: ProfileResponse = try? await perform("/profile", method: "GET", jsonBody: nil, withToken: true),
           let u = p.user {
            me = u
            store.set(try? JSONEncoder().encode(u), forKey: "api.ich")
        }
    }

    // MARK: - Reads without side effects

    /// GET with a query, e.g. `/leaderboard?sort=xp`. The token is sent if
    /// there is one - but these endpoints work for guests too.
    func fetch<T: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws -> T {
        try await perform(path, method: "GET", jsonBody: nil, withToken: token != nil, query: query)
    }

    /// POST with an account (claiming quests, daily reward).
    func transmit<T: Decodable>(_ path: String, _ jsonBody: [String: String] = [:]) async throws -> T {
        try await perform(path, method: "POST", jsonBody: jsonBody, withToken: true)
    }

    /// After claiming, the server sends the new spots balance - it should show
    /// top right immediately, not only after the next profile fetch.
    func setSpots(_ latest: Int) {
        guard var k = me else { return }
        k.spots = latest
        me = k
        store.set(try? JSONEncoder().encode(k), forKey: "api.ich")
    }

    // MARK: - Plumbing

    private func perform<T: Decodable>(_ path: String, method: String,
                                   jsonBody: [String: String]?, withToken: Bool,
                                   query: [String: String] = [:]) async throws -> T {
        var address: URL = Api.baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        if !query.isEmpty, var components = URLComponents(url: address, resolvingAgainstBaseURL: false) {
            // Encoded by hand: URLComponents leaves & and = in values as they are,
            // and a Spotify link with "?si=…" would then split into two parameters.
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
            // The server explains its refusals - the explanation is more useful
            // than a status code ("Wrong login details", the ban text including
            // the time left).
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
