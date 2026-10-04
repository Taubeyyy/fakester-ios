import Foundation

// Startbildschirm-Zahlen, Quests und die taegliche Belohnung.
//
// Herkunft der Formen:
// - `/stats/live` ist oeffentlich und am 2026-10-04 live abgefragt.
// - `/quests`, `/quests/claim` und `/daily-checkin` gehen nur mit Konto. Ihre
//   Formen stammen aus dem ausgelieferten Web-Bundle (welche Felder der
//   Browser liest), NICHT aus einem Mitschnitt - deshalb hier besonders
//   nachsichtig: fehlt ein Feld, gibt es einen Ersatzwert statt eines Fehlers.

/// `GET /stats/live` → `{"players":0,"lobbies":0}`
struct LiveZahlen: Decodable, Equatable {
    let players: Int
    let lobbies: Int

    private enum CodingKeys: String, CodingKey { case players, lobbies }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        players = (try? c.decode(Lose.self, forKey: .players))?.zahl ?? 0
        lobbies = (try? c.decode(Lose.self, forKey: .lobbies))?.zahl ?? 0
    }
}

// MARK: - Quests

struct QuestEintrag: Identifiable, Hashable {
    let id: String
    let ziel: Int
    let stand: Int
    let fertig: Bool
    let abgeholt: Bool
    let belohnung: Int

    var anteil: Double { ziel > 0 ? min(1, Double(stand) / Double(ziel)) : 0 }

    /// Die Namen stehen nicht in der Antwort, sondern im Browser (`g3`).
    static let namen: [(id: String, de: String, en: String)] = [
        ("d_play3", "3 Spiele spielen", "Play 3 games"),
        ("d_correct10", "10 richtig beantworten", "Answer 10 correctly"),
        ("d_win1", "Ein Spiel gewinnen", "Win a game"),
        ("w_play20", "20 Spiele spielen", "Play 20 games"),
        ("w_win5", "5 Spiele gewinnen", "Win 5 games"),
        ("w_correct100", "100 richtig beantworten", "Answer 100 correctly"),
        ("first_icon", "Dein erstes Symbol kaufen", "Buy your first icon"),
        ("first_title", "Deinen ersten Titel kaufen", "Buy your first title"),
        ("first_bg", "Deinen ersten Hintergrund kaufen", "Buy your first background"),
        ("play_5", "5 Spiele spielen", "Play 5 games"),
        ("play_25", "25 Spiele spielen", "Play 25 games"),
        ("win_1", "Ein Spiel gewinnen", "Win a game"),
        ("win_10", "10 Spiele gewinnen", "Win 10 games"),
        ("correct_50", "50 richtige Antworten", "Guess 50 correct answers"),
        ("streak_3", "3 Tage am Stück einloggen", "Reach a 3-day login streak"),
        ("collector_10", "10 Gegenstände besitzen", "Own 10 items")
    ]

    static func rang(_ id: String) -> Int {
        namen.firstIndex { $0.id == id } ?? namen.count
    }
}

/// Eine Quest-Gruppe kommt als Objekt `{questId: {target, progress, done, claimed, reward}}`.
struct QuestGruppe: Decodable {
    let eintraege: [QuestEintrag]

    private struct Schluessel: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    private struct Roh: Decodable {
        let target: Int?
        let progress: Int?
        let done: Bool
        let claimed: Bool
        let reward: Int
        private enum CodingKeys: String, CodingKey { case target, progress, done, claimed, reward }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            target = (try? c.decode(Lose.self, forKey: .target))?.zahl
            progress = (try? c.decode(Lose.self, forKey: .progress))?.zahl
            done = (try? c.decode(Bool.self, forKey: .done)) ?? false
            claimed = (try? c.decode(Bool.self, forKey: .claimed)) ?? false
            reward = (try? c.decode(Lose.self, forKey: .reward))?.zahl ?? 0
        }
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: Schluessel.self)
        var liste: [QuestEintrag] = []
        for k in c.allKeys {
            guard let r = try? c.decode(Roh.self, forKey: k) else { continue }
            // Wie im Browser: ohne Ziel ist es 1, ohne Stand zaehlt "fertig".
            let ziel: Int = max(1, r.target ?? 1)
            let stand: Int = min(r.progress ?? (r.done ? ziel : 0), ziel)
            liste.append(QuestEintrag(id: k.stringValue, ziel: ziel, stand: stand,
                                      fertig: r.done, abgeholt: r.claimed, belohnung: r.reward))
        }
        // JSON-Objekte haben keine verlaessliche Reihenfolge - also feste.
        eintraege = liste.sorted { a, b in
            let ra: Int = QuestEintrag.rang(a.id), rb: Int = QuestEintrag.rang(b.id)
            return ra != rb ? ra < rb : a.id < b.id
        }
    }
}

/// `GET /quests` → `{daily: {…}, weekly: {…}, quests: {…}}`
struct QuestStand: Decodable {
    let taeglich: [QuestEintrag]
    let woechentlich: [QuestEintrag]
    let meilensteine: [QuestEintrag]

    private enum CodingKeys: String, CodingKey { case daily, weekly, quests }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        taeglich = (try? c.decode(QuestGruppe.self, forKey: .daily))?.eintraege ?? []
        woechentlich = (try? c.decode(QuestGruppe.self, forKey: .weekly))?.eintraege ?? []
        meilensteine = (try? c.decode(QuestGruppe.self, forKey: .quests))?.eintraege ?? []
    }
}

/// Antwort von `POST /quests/claim` → `{reward, newSpots}`
struct Abholung: Decodable {
    let reward: Int
    let newSpots: Int?

    private enum CodingKeys: String, CodingKey { case reward, newSpots }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        reward = (try? c.decode(Lose.self, forKey: .reward))?.zahl ?? 0
        newSpots = (try? c.decode(Lose.self, forKey: .newSpots))?.zahl
    }
}

// MARK: - Taegliche Belohnung

/// `GET /daily-checkin` → `{claimable, current, today: {day, spots, gold, xp}, …}`
struct TagesBonus: Decodable, Identifiable {
    var id: Int { tag }
    let abholbar: Bool
    let tag: Int
    let spots: Int
    let gold: Int
    let xp: Int

    private enum CodingKeys: String, CodingKey { case claimable, current, today }
    private enum HeuteKeys: String, CodingKey { case day, spots, gold, xp }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        abholbar = (try? c.decode(Bool.self, forKey: .claimable)) ?? false
        let laufend: Int = (try? c.decode(Lose.self, forKey: .current))?.zahl ?? 0
        if let h = try? c.nestedContainer(keyedBy: HeuteKeys.self, forKey: .today) {
            tag = (try? h.decode(Lose.self, forKey: .day))?.zahl ?? (laufend + 1)
            spots = (try? h.decode(Lose.self, forKey: .spots))?.zahl ?? 0
            gold = (try? h.decode(Lose.self, forKey: .gold))?.zahl ?? 0
            xp = (try? h.decode(Lose.self, forKey: .xp))?.zahl ?? 0
        } else {
            tag = laufend + 1
            spots = 0
            gold = 0
            xp = 0
        }
    }
}

/// Antwort von `POST /daily-checkin` → `{claimed, streak, reward, goldReward, xpReward}`
struct TagesBonusAntwort: Decodable {
    let abgeholt: Bool
    let serie: Int
    let spots: Int
    let gold: Int
    let xp: Int

    private enum CodingKeys: String, CodingKey { case claimed, streak, reward, goldReward, xpReward }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        abgeholt = (try? c.decode(Bool.self, forKey: .claimed)) ?? false
        serie = (try? c.decode(Lose.self, forKey: .streak))?.zahl ?? 0
        spots = (try? c.decode(Lose.self, forKey: .reward))?.zahl ?? 0
        gold = (try? c.decode(Lose.self, forKey: .goldReward))?.zahl ?? 0
        xp = (try? c.decode(Lose.self, forKey: .xpReward))?.zahl ?? 0
    }
}
