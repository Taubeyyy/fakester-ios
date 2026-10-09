import Foundation

// Home screen numbers, quests and the daily reward.
//
// Where the shapes come from:
// - `/stats/live` is public and was queried live on 2026-10-04.
// - `/quests`, `/quests/claim` and `/daily-checkin` require an account. Their
//   shapes come from the shipped web bundle (which fields the browser reads),
//   NOT from a capture - so they are decoded extra leniently here: a missing
//   field yields a fallback value instead of an error.

/// `GET /stats/live` → `{"players":0,"lobbies":0}`
struct LiveStats: Decodable, Equatable {
    let players: Int
    let lobbies: Int

    private enum CodingKeys: String, CodingKey { case players, lobbies }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        players = (try? c.decode(LooseValue.self, forKey: .players))?.numeric ?? 0
        lobbies = (try? c.decode(LooseValue.self, forKey: .lobbies))?.numeric ?? 0
    }
}

// MARK: - Quests

struct QuestItem: Identifiable, Hashable {
    let id: String
    let goal: Int
    let tally: Int
    let finished: Bool
    let isClaimed: Bool
    let prize: Int

    var fraction: Double { goal > 0 ? min(1, Double(tally) / Double(goal)) : 0 }

    /// The names are not in the response but in the browser (`g3`).
    static let names: [(id: String, en: String)] = [
        ("d_play3", "Play 3 games"),
        ("d_correct10", "Answer 10 correctly"),
        ("d_win1", "Win a game"),
        ("w_play20", "Play 20 games"),
        ("w_win5", "Win 5 games"),
        ("w_correct100", "Answer 100 correctly"),
        ("first_icon", "Buy your first icon"),
        ("first_title", "Buy your first title"),
        ("first_bg", "Buy your first background"),
        ("play_5", "Play 5 games"),
        ("play_25", "Play 25 games"),
        ("win_1", "Win a game"),
        ("win_10", "Win 10 games"),
        ("correct_50", "Guess 50 correct answers"),
        ("streak_3", "Reach a 3-day login streak"),
        ("collector_10", "Own 10 items")
    ]

    static func rankNumber(_ id: String) -> Int {
        names.firstIndex { $0.id == id } ?? names.count
    }
}

/// A quest group arrives as an object `{questId: {target, progress, done, claimed, reward}}`.
struct QuestGroup: Decodable {
    let entries: [QuestItem]

    private struct DynamicKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    private struct RawEntry: Decodable {
        let target: Int?
        let progress: Int?
        let done: Bool
        let claimed: Bool
        let reward: Int
        private enum CodingKeys: String, CodingKey { case target, progress, done, claimed, reward }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            target = (try? c.decode(LooseValue.self, forKey: .target))?.numeric
            progress = (try? c.decode(LooseValue.self, forKey: .progress))?.numeric
            done = (try? c.decode(Bool.self, forKey: .done)) ?? false
            claimed = (try? c.decode(Bool.self, forKey: .claimed)) ?? false
            reward = (try? c.decode(LooseValue.self, forKey: .reward))?.numeric ?? 0
        }
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: DynamicKey.self)
        var items: [QuestItem] = []
        for k in c.allKeys {
            guard let r = try? c.decode(RawEntry.self, forKey: k) else { continue }
            // As in the browser: a missing target counts as 1; a missing progress follows `done` (full or zero).
            let goal: Int = max(1, r.target ?? 1)
            let tally: Int = min(r.progress ?? (r.done ? goal : 0), goal)
            items.append(QuestItem(id: k.stringValue, goal: goal, tally: tally,
                                      finished: r.done, isClaimed: r.claimed, prize: r.reward))
        }
        // JSON objects have no reliable order - so impose a fixed one.
        entries = items.sorted { a, b in
            let ra: Int = QuestItem.rankNumber(a.id), rb: Int = QuestItem.rankNumber(b.id)
            return ra != rb ? ra < rb : a.id < b.id
        }
    }
}

/// `GET /quests` → `{daily: {…}, weekly: {…}, quests: {…}}`
struct QuestOverview: Decodable {
    let dailyQuests: [QuestItem]
    let weeklyQuests: [QuestItem]
    let milestones: [QuestItem]

    private enum CodingKeys: String, CodingKey { case daily, weekly, quests }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        dailyQuests = (try? c.decode(QuestGroup.self, forKey: .daily))?.entries ?? []
        weeklyQuests = (try? c.decode(QuestGroup.self, forKey: .weekly))?.entries ?? []
        milestones = (try? c.decode(QuestGroup.self, forKey: .quests))?.entries ?? []
    }
}

/// Response of `POST /quests/claim` → `{reward, newSpots}`
struct ClaimResult: Decodable {
    let reward: Int
    let newSpots: Int?

    private enum CodingKeys: String, CodingKey { case reward, newSpots }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        reward = (try? c.decode(LooseValue.self, forKey: .reward))?.numeric ?? 0
        newSpots = (try? c.decode(LooseValue.self, forKey: .newSpots))?.numeric
    }
}

// MARK: - Daily reward

/// `GET /daily-checkin` → `{claimable, current, today: {day, spots, gold, xp}, …}`
/// One step on the 10-day ladder: `{day, spots, gold, xp, label}`.
struct BonusDay: Decodable, Equatable {
    let day: Int
    let spots: Int
    let gold: Int
    let xp: Int
    /// "One Week!" on day 7 - shown instead of the title.
    let label: String?

    private enum CodingKeys: String, CodingKey { case day, spots, gold, xp, label }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        day = (try? c.decode(LooseValue.self, forKey: .day))?.numeric ?? 1
        spots = (try? c.decode(LooseValue.self, forKey: .spots))?.numeric ?? 0
        gold = (try? c.decode(LooseValue.self, forKey: .gold))?.numeric ?? 0
        xp = (try? c.decode(LooseValue.self, forKey: .xp))?.numeric ?? 0
        let text: String? = try? c.decode(String.self, forKey: .label)
        label = (text?.isEmpty ?? true) ? nil : text
    }

    init(day: Int, spots: Int, gold: Int, xp: Int, label: String?) {
        self.day = day
        self.spots = spots
        self.gold = gold
        self.xp = xp
        self.label = label
    }
}

/// `GET /daily-checkin` → `{streak, claimable, today, current, ladder}`
/// (captured with the test account, 2026-10-09).
struct DailyBonus: Decodable, Identifiable {
    var id: Int { dayNumber }
    let isClaimable: Bool
    let dayNumber: Int
    let spots: Int
    let gold: Int
    let xp: Int
    let label: String?
    let streak: Int
    /// The ladder position of today.
    let current: Int
    let ladder: [BonusDay]

    private enum CodingKeys: String, CodingKey { case claimable, current, today, streak, ladder }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        isClaimable = (try? c.decode(Bool.self, forKey: .claimable)) ?? false
        let currentStreak: Int = (try? c.decode(LooseValue.self, forKey: .current))?.numeric ?? 0
        current = currentStreak
        streak = (try? c.decode(LooseValue.self, forKey: .streak))?.numeric ?? 0
        ladder = (try? c.decode(LenientArray<BonusDay>.self, forKey: .ladder))?.items ?? []
        if let t = try? c.decode(BonusDay.self, forKey: .today) {
            dayNumber = t.day
            spots = t.spots
            gold = t.gold
            xp = t.xp
            label = t.label
        } else {
            dayNumber = currentStreak + 1
            spots = 0
            gold = 0
            xp = 0
            label = nil
        }
    }

    var today: BonusDay { BonusDay(day: dayNumber, spots: spots, gold: gold, xp: xp, label: label) }
}

/// Response of `POST /daily-checkin` → `{claimed, streak, reward, goldReward, xpReward}`
struct DailyBonusClaim: Decodable {
    let isClaimed: Bool
    let streakDay: Int
    let spots: Int
    let gold: Int
    let xp: Int

    private enum CodingKeys: String, CodingKey { case claimed, streak, reward, goldReward, xpReward }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        isClaimed = (try? c.decode(Bool.self, forKey: .claimed)) ?? false
        streakDay = (try? c.decode(LooseValue.self, forKey: .streak))?.numeric ?? 0
        spots = (try? c.decode(LooseValue.self, forKey: .reward))?.numeric ?? 0
        gold = (try? c.decode(LooseValue.self, forKey: .goldReward))?.numeric ?? 0
        xp = (try? c.decode(LooseValue.self, forKey: .xpReward))?.numeric ?? 0
    }
}
