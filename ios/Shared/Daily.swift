import Foundation

// The Daily: five songs, one try, the same for everyone (`wN` in the web
// bundle). `GET /daily` was captured with the test account before playing
// (2026-10-09): `{day, songs, played, result, rounds: [{preview, cover,
// options}], board: {top, rank, players}}`. The test account must not play
// it (it would land on the public board), so the rest - `POST /daily/start`,
// `POST /daily/finish {answers, elapsedMs}` → `{day, correct, total,
// elapsedMs, reward: {spots, goldSpots}, board, solution: [{title, artist,
// cover, correct}], balance: {spots}}`, a played day's `result` and the board
// rows - is read from the bundle and decoded extra leniently.

struct DailyRound: Decodable {
    let preview: String?
    let cover: String?
    let options: [String]
    /// Only present once the day is played.
    let title: String
    let artist: String
    let correct: Int

    private enum CodingKeys: String, CodingKey { case preview, cover, options, title, artist, correct }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        preview = try? c.decode(String.self, forKey: .preview)
        cover = try? c.decode(String.self, forKey: .cover)
        options = ((try? c.decode(LenientArray<LooseValue>.self, forKey: .options))?.items ?? []).map { $0.text }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        correct = (try? c.decode(LooseValue.self, forKey: .correct))?.numeric ?? -1
    }
}

struct DailyBoardEntry: Decodable, Identifiable {
    let id: String
    let username: String
    let avatarURL: String?
    let iconID: String?
    let correct: Int
    let total: Int
    let elapsedMs: Int

    private enum CodingKeys: String, CodingKey { case id, username, avatar_url, equipped_icon_id, correct, total, elapsed_ms }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        username = (try? c.decode(String.self, forKey: .username)) ?? "?"
        id = (try? c.decode(LooseValue.self, forKey: .id))?.text ?? username
        avatarURL = try? c.decode(String.self, forKey: .avatar_url)
        iconID = (try? c.decode(LooseValue.self, forKey: .equipped_icon_id))?.text
        correct = (try? c.decode(LooseValue.self, forKey: .correct))?.numeric ?? 0
        total = (try? c.decode(LooseValue.self, forKey: .total))?.numeric ?? 0
        elapsedMs = (try? c.decode(LooseValue.self, forKey: .elapsed_ms))?.numeric ?? 0
    }
}

struct DailyBoard: Decodable {
    let top: [DailyBoardEntry]
    let rank: Int?
    let players: Int

    private enum CodingKeys: String, CodingKey { case top, rank, players }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        top = (try? c.decode(LenientArray<DailyBoardEntry>.self, forKey: .top))?.items ?? []
        rank = (try? c.decode(LooseValue.self, forKey: .rank))?.numeric
        players = (try? c.decode(LooseValue.self, forKey: .players))?.numeric ?? 0
    }

    init() {
        top = []
        rank = nil
        players = 0
    }
}

/// A finished day as `GET /daily` reports it (`result`).
struct DailyPastResult: Decodable {
    let answers: [Int]
    let correct: Int
    let total: Int
    let elapsedMs: Int

    private enum CodingKeys: String, CodingKey { case answers, correct, total, elapsed_ms }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        answers = ((try? c.decode(LenientArray<LooseValue>.self, forKey: .answers))?.items ?? []).map { $0.numeric ?? -1 }
        correct = (try? c.decode(LooseValue.self, forKey: .correct))?.numeric ?? 0
        total = (try? c.decode(LooseValue.self, forKey: .total))?.numeric ?? 0
        elapsedMs = (try? c.decode(LooseValue.self, forKey: .elapsed_ms))?.numeric ?? 0
    }
}

/// `GET /daily`
struct DailyToday: Decodable {
    let day: Int
    let songs: Int
    let played: Bool
    let result: DailyPastResult?
    let rounds: [DailyRound]
    let board: DailyBoard

    private enum CodingKeys: String, CodingKey { case day, songs, played, result, rounds, board }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        day = (try? c.decode(LooseValue.self, forKey: .day))?.numeric ?? 0
        rounds = (try? c.decode(LenientArray<DailyRound>.self, forKey: .rounds))?.items ?? []
        songs = (try? c.decode(LooseValue.self, forKey: .songs))?.numeric ?? rounds.count
        played = (try? c.decode(Bool.self, forKey: .played)) ?? false
        result = try? c.decode(DailyPastResult.self, forKey: .result)
        board = (try? c.decode(DailyBoard.self, forKey: .board)) ?? DailyBoard()
    }
}

/// One song in "The answers".
struct DailySolution: Decodable {
    let title: String
    let artist: String
    let cover: String?
    let correct: Int

    private enum CodingKeys: String, CodingKey { case title, artist, cover, correct }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        cover = try? c.decode(String.self, forKey: .cover)
        correct = (try? c.decode(LooseValue.self, forKey: .correct))?.numeric ?? -1
    }

    init(round: DailyRound) {
        title = round.title
        artist = round.artist
        cover = round.cover
        correct = round.correct
    }
}

/// `POST /daily/finish`
struct DailyFinish: Decodable {
    let day: Int?
    let correct: Int
    let total: Int
    let elapsedMs: Int
    let rewardSpots: Int
    let rewardGold: Int
    let board: DailyBoard?
    let solution: [DailySolution]
    let balanceSpots: Int?

    private enum CodingKeys: String, CodingKey { case day, correct, total, elapsedMs, reward, board, solution, balance }
    private enum RewardKeys: String, CodingKey { case spots, goldSpots }
    private enum BalanceKeys: String, CodingKey { case spots }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        day = (try? c.decode(LooseValue.self, forKey: .day))?.numeric
        correct = (try? c.decode(LooseValue.self, forKey: .correct))?.numeric ?? 0
        total = (try? c.decode(LooseValue.self, forKey: .total))?.numeric ?? 0
        elapsedMs = (try? c.decode(LooseValue.self, forKey: .elapsedMs))?.numeric ?? 0
        let r = try? c.nestedContainer(keyedBy: RewardKeys.self, forKey: .reward)
        rewardSpots = (try? r?.decode(LooseValue.self, forKey: .spots))??.numeric ?? 0
        rewardGold = (try? r?.decode(LooseValue.self, forKey: .goldSpots))??.numeric ?? 0
        board = try? c.decode(DailyBoard.self, forKey: .board)
        solution = (try? c.decode(LenientArray<DailySolution>.self, forKey: .solution))?.items ?? []
        let b = try? c.nestedContainer(keyedBy: BalanceKeys.self, forKey: .balance)
        balanceSpots = (try? b?.decode(LooseValue.self, forKey: .spots))??.numeric
    }
}

enum DailyRules {
    /// `ur`: seconds per song.
    static let secondsPerSong: Int = 15

    /// The text the browser shares (`ae`): "Fakester #277 · 3/5", a row of
    /// 🟩 / ⬛ and the address.
    static func shareText(day: Int, correct: Int, total: Int, answers: [Int], solution: [Int]) -> String {
        let squares: String = solution.enumerated().map { i, right in
            i < answers.count && answers[i] == right ? "🟩" : "⬛"
        }.joined()
        return "Fakester #\(day) · \(correct)/\(total)\n\(squares)\nfakester.app"
    }
}
