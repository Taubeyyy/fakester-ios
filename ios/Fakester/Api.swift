import Foundation

/// REST-Teil von fakester.app: anmelden, registrieren, Profil holen.
///
/// Alles unter `https://fakester.app/fakester` - der Express-Router haengt dort,
/// nicht unter `/api`, auch wenn der Pfad das nahelegen wuerde. Das Spiel selbst
/// laeuft nicht hierueber, sondern ueber die WebSocket in `Verbindung.swift`.
@MainActor
final class Api: ObservableObject {
    static let shared = Api()

    static let basis = URL(string: "https://fakester.app/fakester")!

    /// Token und Spielername ueberleben den Appstart. Mehr wird nicht
    /// gespeichert - alles andere holt das Profil frisch, sonst zeigt die App
    /// Spots und Rang von vorgestern.
    @Published private(set) var token: String?
    @Published private(set) var ich: Konto?
    /// Gaeste haben kein Konto. Der Ausweis wird einmal gebaut und behalten,
    /// damit ein Neustart in derselben Lobby nicht als zweiter Spieler landet.
    @Published private(set) var gast: SpielerAusweis?

    private let ablage = UserDefaults.standard

    private init() {
        token = ablage.string(forKey: "api.token")
        if let d = ablage.data(forKey: "api.ich") {
            ich = try? JSONDecoder().decode(Konto.self, from: d)
        }
        if let id = ablage.string(forKey: "gast.id"), let name = ablage.string(forKey: "gast.name") {
            gast = SpielerAusweis(id: id, username: name, isGuest: true)
        }
    }

    var angemeldet: Bool { token != nil && ich != nil }

    /// Wer sitzt am Tisch - Konto oder Gast. Genau das verlangen `create-game`
    /// und `join-game`.
    var ausweis: SpielerAusweis? {
        if let k = ich {
            return SpielerAusweis(id: String(k.id.text), username: k.username, isGuest: false,
                                  is_pro: k.is_pro, is_admin: k.is_admin,
                                  equipped_icon_id: k.equipped_icon_id ?? 1,
                                  equipped_title_id: k.equipped_title_id ?? 1,
                                  avatar_url: k.avatar_url, equipped_emoji: k.equipped_emoji)
        }
        return gast
    }

    // MARK: - Konto

    struct Konto: Codable {
        let id: Lose
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
            id = try c.decode(Lose.self, forKey: .id)
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
    private struct Absage: Decodable { let error: String? }

    /// Stufe und Fortschritt, genau wie der Server rechnet:
    /// `levelForXp(xp) = max(1, floor((25 + sqrt(625 + 100*xp)) / 50))`.
    /// Nachgebaut statt geschaetzt - eine Stufe, die in der App anders steht
    /// als im Browser, ist schlimmer als gar keine.
    enum Stufe {
        static func fuerXp(_ xp: Int) -> Int {
            max(1, Int((25.0 + (625.0 + 100.0 * Double(max(0, xp))).squareRoot()) / 50.0))
        }

        /// Ab wie viel XP diese Stufe beginnt - die Umkehrung der Formel oben.
        static func xpAb(_ stufe: Int) -> Int {
            let g = 50.0 * Double(stufe) - 25.0
            return max(0, Int((g * g - 625.0) / 100.0))
        }

        /// Anteil 0…1 innerhalb der laufenden Stufe.
        static func anteil(xp: Int) -> Double {
            let l = fuerXp(xp)
            let von = xpAb(l), bis = xpAb(l + 1)
            guard bis > von else { return 0 }
            return min(1, max(0, Double(xp - von) / Double(bis - von)))
        }
    }

    enum Fehler: LocalizedError {
        case meldung(String)
        var errorDescription: String? {
            if case .meldung(let m) = self { return m }
            return nil
        }
    }

    // MARK: - Anmelden

    private struct AnmeldeAntwort: Decodable {
        let token: String?
        let user: Konto?
    }

    func anmelden(name: String, passwort: String) async throws {
        try await anmeldung("/auth/login", name: name, passwort: passwort)
    }

    func registrieren(name: String, passwort: String) async throws {
        try await anmeldung("/auth/register", name: name, passwort: passwort)
    }

    private func anmeldung(_ pfad: String, name: String, passwort: String) async throws {
        let antwort: AnmeldeAntwort = try await ruf(
            pfad, methode: "POST",
            koerper: ["username": name.trimmingCharacters(in: .whitespaces), "password": passwort],
            mitToken: false)
        guard let t = antwort.token, let u = antwort.user else {
            throw Fehler.meldung(L("Der Server hat keine Anmeldung zurückgeschickt.", "The server didn't send back a login."))
        }
        token = t
        ich = u
        ablage.set(t, forKey: "api.token")
        ablage.set(try? JSONEncoder().encode(u), forKey: "api.ich")
    }

    /// Raeumt beides ab - Konto UND Gast. Ohne das Zweite stuende ein Gast nach
    /// dem Abmelden sofort wieder mit demselben Namen da, weil der Ausweis die
    /// Anmeldung gar nicht braucht.
    func abmelden() {
        token = nil
        ich = nil
        gast = nil
        ablage.removeObject(forKey: "api.token")
        ablage.removeObject(forKey: "api.ich")
        ablage.removeObject(forKey: "gast.id")
        ablage.removeObject(forKey: "gast.name")
    }

    /// Gast bleibt Gast, bis er einen anderen Namen waehlt.
    func alsGast(name: String) {
        let sauber = name.trimmingCharacters(in: .whitespaces)
        if let g = gast, g.username == sauber { return }
        let neu = SpielerAusweis.gast(name: sauber)
        gast = neu
        ablage.set(neu.id, forKey: "gast.id")
        ablage.set(neu.username, forKey: "gast.name")
    }

    // MARK: - Profil

    func profilAuffrischen() async {
        guard token != nil else { return }
        struct Profil: Decodable { let user: Konto? }
        if let p: Profil = try? await ruf("/profile", methode: "GET", koerper: nil, mitToken: true),
           let u = p.user {
            ich = u
            ablage.set(try? JSONEncoder().encode(u), forKey: "api.ich")
        }
    }

    // MARK: - Lesen ohne Seiteneffekt

    /// GET mit Abfrage, z. B. `/leaderboard?sort=xp`. Das Token geht mit, wenn
    /// es eins gibt - die Endpunkte hier gehen aber auch fuer Gaeste.
    func holen<T: Decodable>(_ pfad: String, _ abfrage: [String: String] = [:]) async throws -> T {
        try await ruf(pfad, methode: "GET", koerper: nil, mitToken: token != nil, abfrage: abfrage)
    }

    /// POST mit Konto (Quests abholen, taegliche Belohnung).
    func senden<T: Decodable>(_ pfad: String, _ koerper: [String: String] = [:]) async throws -> T {
        try await ruf(pfad, methode: "POST", koerper: koerper, mitToken: true)
    }

    /// Nach dem Abholen schickt der Server den neuen Spots-Stand mit - der soll
    /// sofort oben rechts stehen, nicht erst nach dem naechsten Profilabruf.
    func spotsSetzen(_ neu: Int) {
        guard var k = ich else { return }
        k.spots = neu
        ich = k
        ablage.set(try? JSONEncoder().encode(k), forKey: "api.ich")
    }

    // MARK: - Unterbau

    private func ruf<T: Decodable>(_ pfad: String, methode: String,
                                   koerper: [String: String]?, mitToken: Bool,
                                   abfrage: [String: String] = [:]) async throws -> T {
        var adresse: URL = Api.basis.appendingPathComponent(pfad.hasPrefix("/") ? String(pfad.dropFirst()) : pfad)
        if !abfrage.isEmpty, var teile = URLComponents(url: adresse, resolvingAgainstBaseURL: false) {
            // Selbst kodiert: URLComponents laesst & und = in Werten stehen, und
            // ein Spotify-Link mit "?si=…" zerfiele dann in zwei Parameter.
            var erlaubt = CharacterSet.alphanumerics
            erlaubt.insert(charactersIn: "-._~")
            let paare: [String] = abfrage.keys.sorted().map { k in
                let v: String = abfrage[k] ?? ""
                return k + "=" + (v.addingPercentEncoding(withAllowedCharacters: erlaubt) ?? v)
            }
            teile.percentEncodedQuery = paare.joined(separator: "&")
            if let u = teile.url { adresse = u }
        }
        var anfrage = URLRequest(url: adresse)
        anfrage.httpMethod = methode
        anfrage.timeoutInterval = 20
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if mitToken, let t = token {
            anfrage.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        if let k = koerper {
            anfrage.httpBody = try JSONSerialization.data(withJSONObject: k)
        }

        let (daten, antwort): (Data, URLResponse)
        do {
            (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        } catch {
            throw Fehler.meldung(L("Keine Verbindung zum Server.", "No connection to the server."))
        }

        let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) {
            // Der Server begruendet seine Absagen - die Begruendung ist
            // brauchbarer als ein Statuscode ("Wrong login details", der
            // Bann-Text mitsamt Restzeit).
            let grund = (try? JSONDecoder().decode(Absage.self, from: daten))?.error
            throw Fehler.meldung(grund ?? L("Der Server hat abgelehnt (\(code)).", "The server refused (\(code))."))
        }
        do {
            return try JSONDecoder().decode(T.self, from: daten)
        } catch {
            throw Fehler.meldung(L("Antwort des Servers nicht lesbar.", "Couldn't read the server's response."))
        }
    }
}
