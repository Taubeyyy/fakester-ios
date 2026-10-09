import Foundation

/// `GET /profile` with an account: `{user, ownedItems, history, friends}`.
/// The Stats screen reads the counters the short `Api.Account` does not carry
/// (correct answers) and the game history. Shape checked against the test
/// account's real answer (2026-10-05); history items as the browser reads them
/// (`QN` in the bundle). Everything optional - a guest gets nothing here.
struct ProfileDetails: Decodable {
    let correctAnswers: Int
    let history: [GameRecord]

    private enum CodingKeys: String, CodingKey { case user, history }
    private enum UserKeys: String, CodingKey { case correct_answers }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        if let u = try? c.nestedContainer(keyedBy: UserKeys.self, forKey: .user) {
            correctAnswers = (try? u.decode(LooseValue.self, forKey: .correct_answers))?.numeric ?? 0
        } else {
            correctAnswers = 0
        }
        history = (try? c.decode(LenientArray<GameRecord>.self, forKey: .history))?.items ?? []
    }
}

/// One finished game in "Recent games".
struct GameRecord: Decodable, Identifiable, Hashable {
    let id: String
    let mode: String
    /// 1, 2, 3 ... or nil when unknown ("–").
    let placement: Int?
    let playlistName: String
    let playedAt: Date?
    let totalPlayers: Int
    let score: Int
    let xpGained: Int
    let spotsGained: Int

    private enum CodingKeys: String, CodingKey {
        case id, game_mode, placement, playlist_name, played_at, total_players, score, xp_gained, spots_gained
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let rawId: String? = (try? c.decode(LooseValue.self, forKey: .id))?.text
        mode = (try? c.decode(String.self, forKey: .game_mode)) ?? "quiz"
        placement = (try? c.decode(LooseValue.self, forKey: .placement))?.numeric
        playlistName = (try? c.decode(String.self, forKey: .playlist_name)) ?? "Unknown playlist"
        let stamp: String = (try? c.decode(String.self, forKey: .played_at)) ?? ""
        playedAt = GameRecord.parseDate(stamp)
        totalPlayers = (try? c.decode(LooseValue.self, forKey: .total_players))?.numeric ?? 1
        score = (try? c.decode(LooseValue.self, forKey: .score))?.numeric ?? 0
        xpGained = (try? c.decode(LooseValue.self, forKey: .xp_gained))?.numeric ?? 0
        spotsGained = (try? c.decode(LooseValue.self, forKey: .spots_gained))?.numeric ?? 0
        id = rawId ?? "\(stamp)-\(playlistName)-\(score)"
    }

    /// ISO 8601 with or without fractional seconds, or "2026-10-05 12:00:00".
    static func parseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = precise.date(from: text) { return d }
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: text) { return d }
        let sql = DateFormatter()
        sql.locale = Locale(identifier: "en_US_POSIX")
        sql.timeZone = TimeZone(identifier: "UTC")
        sql.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return sql.date(from: text)
    }

    /// The browser's `YN`: "Today", "Yesterday", "3 days ago", else "05 Oct".
    static func relative(_ date: Date?, now: Date = Date()) -> String {
        guard let d = date else { return "" }
        let days: Int = Int(floor(now.timeIntervalSince(d) / 86_400))
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "dd MMM"
        return f.string(from: d)
    }
}

/// The Achievements row on Stats: `GET /achievements` -> `{achievements, unlocked, total}`;
/// "n to claim" counts the achievements with a `nextClaim`.
struct AchievementTally: Decodable {
    let unlocked: Int
    let total: Int
    let claimable: Int

    private enum CodingKeys: String, CodingKey { case achievements, unlocked, total }
    private struct Entry: Decodable {
        let canClaim: Bool
        private enum CodingKeys: String, CodingKey { case nextClaim }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            canClaim = (try? c.decodeNil(forKey: .nextClaim)) == false && c.contains(.nextClaim)
        }
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        unlocked = (try? c.decode(LooseValue.self, forKey: .unlocked))?.numeric ?? 0
        total = (try? c.decode(LooseValue.self, forKey: .total))?.numeric ?? 0
        let entries: [Entry] = (try? c.decode(LenientArray<Entry>.self, forKey: .achievements))?.items ?? []
        claimable = entries.filter { $0.canClaim }.count
    }
}
