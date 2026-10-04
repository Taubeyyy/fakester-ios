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
        var is_pro: Bool = false
        var is_admin: Bool = false
        var equipped_icon_id: Int?
        var equipped_title_id: Int?
        var avatar_url: String?
        var equipped_emoji: String?

        private enum CodingKeys: String, CodingKey {
            case id, username, xp, spots, gold_spots, is_pro, is_admin
            case equipped_icon_id, equipped_title_id, avatar_url, equipped_emoji
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(Lose.self, forKey: .id)
            username = (try? c.decode(String.self, forKey: .username)) ?? "?"
            xp = try? c.decode(Int.self, forKey: .xp)
            spots = try? c.decode(Int.self, forKey: .spots)
            gold_spots = try? c.decode(Int.self, forKey: .gold_spots)
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
            throw Fehler.meldung("Der Server hat keine Anmeldung zurueckgeschickt.")
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

    // MARK: - Unterbau

    private func ruf<T: Decodable>(_ pfad: String, methode: String,
                                   koerper: [String: String]?, mitToken: Bool) async throws -> T {
        var anfrage = URLRequest(url: Api.basis.appendingPathComponent(pfad.hasPrefix("/") ? String(pfad.dropFirst()) : pfad))
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
            throw Fehler.meldung("Keine Verbindung zum Server.")
        }

        let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) {
            // Der Server begruendet seine Absagen - die Begruendung ist
            // brauchbarer als ein Statuscode ("Wrong login details", der
            // Bann-Text mitsamt Restzeit).
            let grund = (try? JSONDecoder().decode(Absage.self, from: daten))?.error
            throw Fehler.meldung(grund ?? "Der Server hat abgelehnt (\(code)).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: daten)
        } catch {
            throw Fehler.meldung("Antwort des Servers nicht lesbar.")
        }
    }
}
