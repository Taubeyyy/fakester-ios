import Foundation

// The Level Path: every level that unlocks something, with the items from
// the catalog and the spots bonuses at milestone levels (`v2` and `oN` in the
// web bundle). `GET /level/rewards` was captured with the test account
// (2026-10-09): `{"bonuses":{"2":150,…},"claimed":[]}`; `POST /level/claim
// {level}` answers `{reward}` per the bundle.

/// `GET /level/rewards`
struct LevelRewards: Decodable {
    /// Level → spots, keys arrive as text.
    let bonuses: [Int: Int]
    let claimed: [Int]

    private enum CodingKeys: String, CodingKey { case bonuses, claimed }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let raw: [String: LooseValue] = (try? c.decode([String: LooseValue].self, forKey: .bonuses)) ?? [:]
        var parsed: [Int: Int] = [:]
        for (k, v) in raw {
            if let level = Int(k), let amount = v.numeric { parsed[level] = amount }
        }
        bonuses = parsed
        claimed = ((try? c.decode(LenientArray<LooseValue>.self, forKey: .claimed))?.items ?? []).compactMap { $0.numeric }
    }

    init(bonuses: [Int: Int], claimed: [Int]) {
        self.bonuses = bonuses
        self.claimed = claimed
    }
}

/// `POST /level/claim` → `{reward}`
struct LevelClaim: Decodable {
    let reward: Int

    private enum CodingKeys: String, CodingKey { case reward }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        reward = (try? c.decode(LooseValue.self, forKey: .reward))?.numeric ?? 0
    }
}

/// One thing a level gives.
enum PathReward: Equatable {
    case item(type: String, item: CatalogItem)
    case spots(Int)

    var label: String {
        switch self {
        case .item(_, let item): return item.displayName
        case .spots(let n): return "+\(n)"
        }
    }
}

struct PathStep: Equatable, Identifiable {
    var id: Int { level }
    let level: Int
    let rewards: [PathReward]
    /// A level with a spots bonus.
    let milestone: Bool
}

enum LevelPath {
    /// `au` in the bundle - the same numbers `/level/rewards` sends.
    static let bonuses: [Int: Int] = [2: 150, 5: 300, 10: 500, 15: 700, 20: 1000, 25: 1500, 30: 2000, 40: 3000, 50: 5000]

    /// The catalog's types in the order catalog.json lists them - the order
    /// the browser shows a level's rewards in.
    static let typeOrder: [String] = ["title", "icon", "background", "color", "accent-color", "name-effect"]

    /// `v2`: level-unlocked items and the bonuses, merged per level, ascending.
    static func steps(_ catalog: ItemCatalog, bonuses: [Int: Int] = LevelPath.bonuses) -> [PathStep] {
        var byLevel: [Int: [PathReward]] = [:]
        let extra: [String] = catalog.items.keys.filter { !typeOrder.contains($0) }.sorted()
        for type in typeOrder + extra {
            for item in catalog.list(type) where item.unlockType == "level" {
                guard let v = item.unlockValue, let level = Int(v), level > 0 else { continue }
                byLevel[level, default: []].append(.item(type: type, item: item))
            }
        }
        for (level, amount) in bonuses {
            byLevel[level, default: []].append(.spots(amount))
        }
        return byLevel.keys.sorted().map { level in
            PathStep(level: level, rewards: byLevel[level] ?? [], milestone: bonuses[level] != nil)
        }
    }

    /// The step the list scrolls to: the highest one already reached.
    static func anchor(_ steps: [PathStep], level: Int) -> Int? {
        steps.filter { $0.level <= level }.last?.level ?? steps.first?.level
    }

    /// A bonus can be claimed once its level is reached and it isn't claimed yet.
    static func canClaim(_ step: PathStep, level: Int, claimed: [Int], bonuses: [Int: Int] = LevelPath.bonuses) -> Bool {
        bonuses[step.level] != nil && step.level <= level && !claimed.contains(step.level)
    }
}

/// The XP numbers in the hero card (`es`, `Hs` in the bundle).
struct LevelProgress: Equatable {
    let level: Int
    let xp: Int
    /// XP where the current level starts and where the next one starts.
    let floor: Int
    let ceiling: Int

    init(xp: Int) {
        let l: Int = max(1, Int((25.0 + (625.0 + 100.0 * Double(max(0, xp))).squareRoot()) / 50.0))
        level = l
        self.xp = xp
        floor = LevelProgress.start(of: l)
        ceiling = LevelProgress.start(of: l + 1)
    }

    static func start(of level: Int) -> Int {
        let g: Double = 50.0 * Double(max(1, level)) - 25.0
        return max(0, Int((g * g - 625.0) / 100.0))
    }

    /// 0…100, as the bar and the "0.0%" show it.
    var percent: Double {
        guard ceiling > floor else { return 0 }
        return min(100, max(0, Double(xp - floor) / Double(ceiling - floor) * 100))
    }

    var toNext: Int { max(0, ceiling - xp) }
}
