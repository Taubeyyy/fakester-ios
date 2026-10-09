import Foundation

// Awards (the fourth Quests tab) and the quest reset countdown.
//
// `GET /achievements` was captured with the test account (2026-10-09):
// `{achievements: [{id, name, icon, value, level, total, maxed, nextGoal,
// progress, nextClaim, tiers: [{goal, reward, reached, claimed}]}], unlocked,
// total}`. `nextClaim` was null in the capture; the bundle reads
// `nextClaim.index` and `nextClaim.reward`. `POST /achievements/claim
// {id, tier}` answers `{reward, newSpots}` per the bundle.

struct AchievementTier: Decodable, Equatable {
    let goal: Int
    let reward: Int
    let reached: Bool
    let claimed: Bool

    private enum CodingKeys: String, CodingKey { case goal, reward, reached, claimed }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        goal = (try? c.decode(LooseValue.self, forKey: .goal))?.numeric ?? 0
        reward = (try? c.decode(LooseValue.self, forKey: .reward))?.numeric ?? 0
        reached = (try? c.decode(Bool.self, forKey: .reached)) ?? false
        claimed = (try? c.decode(Bool.self, forKey: .claimed)) ?? false
    }
}

/// The tier waiting to be claimed.
struct AchievementClaim: Decodable, Equatable {
    let index: Int
    let reward: Int

    private enum CodingKeys: String, CodingKey { case index, reward }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        index = try c.decode(LooseValue.self, forKey: .index).numeric ?? 0
        reward = (try? c.decode(LooseValue.self, forKey: .reward))?.numeric ?? 0
    }
}

struct Achievement: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    /// A Font Awesome class ("fa-gamepad").
    let icon: String
    let value: Int
    /// Tiers reached so far.
    let level: Int
    let total: Int
    let maxed: Bool
    let nextGoal: Int
    /// 0…100 towards the next tier.
    let progress: Double
    let nextClaim: AchievementClaim?
    let tiers: [AchievementTier]

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, value, level, total, maxed, nextGoal, progress, nextClaim, tiers
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(LooseValue.self, forKey: .id).text
        name = (try? c.decode(String.self, forKey: .name)) ?? id
        icon = (try? c.decode(String.self, forKey: .icon)) ?? "fa-star"
        value = (try? c.decode(LooseValue.self, forKey: .value))?.numeric ?? 0
        level = (try? c.decode(LooseValue.self, forKey: .level))?.numeric ?? 0
        tiers = (try? c.decode(LenientArray<AchievementTier>.self, forKey: .tiers))?.items ?? []
        total = (try? c.decode(LooseValue.self, forKey: .total))?.numeric ?? tiers.count
        maxed = (try? c.decode(Bool.self, forKey: .maxed)) ?? false
        nextGoal = (try? c.decode(LooseValue.self, forKey: .nextGoal))?.numeric ?? 0
        progress = Double((try? c.decode(LooseValue.self, forKey: .progress))?.text ?? "0") ?? 0
        nextClaim = try? c.decode(AchievementClaim.self, forKey: .nextClaim)
    }

    /// The reward of the next tier - the amber pill while nothing is claimable.
    var nextReward: Int {
        level >= 0 && level < tiers.count ? tiers[level].reward : 0
    }
}

/// `GET /achievements`
struct AchievementBoard: Decodable {
    let achievements: [Achievement]
    let unlocked: Int
    let total: Int

    private enum CodingKeys: String, CodingKey { case achievements, unlocked, total }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        achievements = (try? c.decode(LenientArray<Achievement>.self, forKey: .achievements))?.items ?? []
        unlocked = (try? c.decode(LooseValue.self, forKey: .unlocked))?.numeric ?? 0
        total = (try? c.decode(LooseValue.self, forKey: .total))?.numeric ?? 0
    }
}

/// "Resets in 15h 46m" / "Resets in 3d 7h" (`y3`): daily quests reset at
/// midnight UTC, weekly ones on Monday 00:00 UTC.
enum QuestReset {
    static func text(weekly: Bool, now: Date = Date()) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let today: Date = utc.startOfDay(for: now)
        if !weekly {
            let midnight: Date = utc.date(byAdding: .day, value: 1, to: today) ?? now
            let seconds: Double = midnight.timeIntervalSince(now)
            let hours: Int = Int(seconds / 3600)
            let minutes: Int = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
            return hours > 0 ? "Resets in \(hours)h \(minutes)m" : "Resets in \(minutes)m"
        }
        // getUTCDay: Sunday 0 … Saturday 6; Calendar: Sunday 1 … Saturday 7.
        let jsDay: Int = utc.component(.weekday, from: now) - 1
        let isoDay: Int = jsDay == 0 ? 7 : jsDay
        var ahead: Int = (8 - isoDay) % 7
        if ahead == 0 { ahead = 7 }
        let monday: Date = utc.date(byAdding: .day, value: ahead, to: today) ?? now
        let hours: Int = Int(monday.timeIntervalSince(now) / 3600)
        return "Resets in \(hours / 24)d \(hours % 24)h"
    }
}
