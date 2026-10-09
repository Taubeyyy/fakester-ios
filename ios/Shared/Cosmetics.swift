import Foundation

// Shop and Style: the item catalog and the rules the browser applies to it.
//
// Where the shapes come from:
// - `https://fakester.app/catalog.json` is public; captured 2026-10-09.
// - `/profile` (`user` + `ownedItems`) was captured with the test account.
// - The rules (who sees an item, who owns it, what it costs, which group it
//   sits in) are copied from the web bundle (`lu`, `zd`, `Cx`, `al`, `Xn`,
//   `Ou`, `ms`). They are pure functions so the tests can pin them down.

/// One category tab: `{type, label, shop, style}`.
struct ItemCategory: Decodable, Hashable {
    let type: String
    let label: String
    let inShop: Bool
    let inStyle: Bool

    private enum CodingKeys: String, CodingKey { case type, label, shop, style }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        label = (try? c.decode(String.self, forKey: .label)) ?? type
        inShop = (try? c.decode(Bool.self, forKey: .shop)) ?? false
        inStyle = (try? c.decode(Bool.self, forKey: .style)) ?? false
    }

    init(type: String, label: String, inShop: Bool, inStyle: Bool) {
        self.type = type
        self.label = label
        self.inShop = inShop
        self.inStyle = inStyle
    }
}

/// One item. IDs are numbers for most types and text for backgrounds
/// ("default") and name effects ("none") - kept as text throughout.
struct CatalogItem: Decodable, Hashable, Identifiable {
    let id: String
    let name: String?
    let rarity: String
    let unlockType: String
    let unlockValue: String?
    let special: Bool
    let cost: Int?
    let goldCost: Int?
    let iconClass: String?
    let cssClass: String?
    let colorHex: String?
    let anim: String?
    let group: String?
    let owner: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, rarity, unlockType, unlockValue, special, cost, goldCost
        case iconClass, cssClass, colorHex, anim, group, owner
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(LooseValue.self, forKey: .id).text
        name = try? c.decode(String.self, forKey: .name)
        rarity = (try? c.decode(String.self, forKey: .rarity)) ?? "common"
        unlockType = (try? c.decode(String.self, forKey: .unlockType)) ?? "special"
        unlockValue = (try? c.decode(LooseValue.self, forKey: .unlockValue))?.text
        special = (try? c.decode(Bool.self, forKey: .special)) ?? false
        cost = (try? c.decode(LooseValue.self, forKey: .cost))?.numeric
        goldCost = (try? c.decode(LooseValue.self, forKey: .goldCost))?.numeric
        iconClass = try? c.decode(String.self, forKey: .iconClass)
        cssClass = try? c.decode(String.self, forKey: .cssClass)
        colorHex = try? c.decode(String.self, forKey: .colorHex)
        anim = try? c.decode(String.self, forKey: .anim)
        group = try? c.decode(String.self, forKey: .group)
        owner = try? c.decode(String.self, forKey: .owner)
    }

    /// `ms`: the name, else the icon class turned into words
    /// ("fa-compact-disc" → "Compact Disc"), else "Item".
    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        guard let icon = iconClass, !icon.isEmpty else { return "Item" }
        var bare: String = icon
        if bare.hasPrefix("fa-") { bare.removeFirst(3) }
        if bare.hasPrefix("mark:") { bare.removeFirst(5) }
        let words: [String] = bare.split(separator: "-").map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }
        return words.joined(separator: " ")
    }

    /// `Xn`: the section the item is listed under.
    var itemGroup: ItemGroup {
        if let g = group, let known = ItemGroup(rawValue: g) { return known }
        switch unlockType {
        case "achievement": return .earned
        case "free": return .standard
        case "level": return .level
        case "spots": return .shop
        case "pro": return .pro
        default: return special ? .beta : .admin
        }
    }

    /// `Ou`: the small label on a card - "Level 5", "100 wins", "Shop".
    var unlockLabel: String {
        switch itemGroup {
        case .level: return "Level \(unlockValue ?? "1")"
        case .earned: return ItemGroup.achievementLabels[unlockValue ?? ""] ?? "Earned"
        default: return itemGroup.label
        }
    }

    /// `al`: a gold price wins over a spots price. On weekends the spots price
    /// drops by `Pricing.weekendDiscount` percent, gold prices never do.
    func price(onWeekend: Bool) -> ItemPrice {
        if let g = goldCost, g > 0 { return ItemPrice(amount: g, isGold: true, fullAmount: g) }
        let base: Int = cost ?? 0
        let amount: Int = onWeekend ? max(1, Int((Double(base * (100 - Pricing.weekendDiscount)) / 100).rounded())) : base
        return ItemPrice(amount: amount, isGold: false, fullAmount: base)
    }

    /// A gradient (`linear-gradient(…)`) instead of a plain colour.
    var isGradient: Bool { colorHex?.contains("gradient") ?? false }
}

struct ItemPrice: Equatable {
    let amount: Int
    let isGold: Bool
    /// The price before the weekend sale - shown struck through when it differs.
    let fullAmount: Int
    var isDiscounted: Bool { !isGold && amount < fullAmount }
}

enum Pricing {
    /// `Ei` in the bundle: 20 % off everything on Saturdays and Sundays.
    static let weekendDiscount: Int = 20

    /// `Ti`: the browser's local weekday, Sunday or Saturday.
    static func isWeekend(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let day: Int = calendar.component(.weekday, from: date)
        return day == 1 || day == 7
    }
}

/// The groups (`hs`) in the order the browser lists them (`C0`).
enum ItemGroup: String, CaseIterable {
    case earned, standard, level, shop, beta, pro, admin, legacy

    var label: String {
        switch self {
        case .earned: return "Earned"
        case .standard: return "Standard"
        case .level: return "Level"
        case .shop: return "Shop"
        case .beta: return "Beta"
        case .pro: return "PRO"
        case .admin: return "Admin"
        case .legacy: return "Classic"
        }
    }

    /// `b2`: achievement keys to readable goals.
    static let achievementLabels: [String: String] = [
        "games#5": "500 games", "wins#4": "100 wins", "correct#5": "5000 correct",
        "score#4": "2000 highscore", "streak#5": "100-day streak", "collect#4": "100 items owned",
        "level#4": "Level 75", "xp#4": "40k XP", "score#3": "1200 highscore",
        "sharp#1": "250 correct", "correct#3": "1000 correct", "veteran#2": "150 games"
    ]
}

/// What the player has: built from `/profile` (`user` + `ownedItems`).
struct Wardrobe: Decodable {
    let username: String
    let xp: Int
    let spots: Int
    let goldSpots: Int
    let isPro: Bool
    let isAdmin: Bool
    let unlockAll: Bool
    /// "type:id" for every bought item and "achievement:key" for earned ones.
    let owned: Set<String>
    /// Equipped item per type ("title", "icon", …), as text. Missing = nothing.
    let equipped: [String: String]
    let avatarURL: String?

    /// `ru`: which profile field holds the equipped item of a type.
    static let equipField: [String: String] = [
        "title": "equipped_title_id", "icon": "equipped_icon_id",
        "background": "equipped_background_id", "color": "equipped_color_id",
        "accent-color": "equipped_accent_color_id", "name-effect": "equipped_name_effect"
    ]

    private enum TopKeys: String, CodingKey { case user, ownedItems }
    private struct FieldKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    private struct OwnedRow: Decodable {
        let key: String
        private enum CodingKeys: String, CodingKey { case item_type, item_id }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            let type: String = try c.decode(String.self, forKey: .item_type)
            let id: String = try c.decode(LooseValue.self, forKey: .item_id).text
            key = "\(type):\(id)"
        }
    }

    init(from d: Decoder) throws {
        let top = try d.container(keyedBy: TopKeys.self)
        let u = try top.nestedContainer(keyedBy: FieldKey.self, forKey: .user)
        func number(_ k: String) -> Int { (try? u.decode(LooseValue.self, forKey: FieldKey(k)))?.numeric ?? 0 }
        func truth(_ k: String) -> Bool { (try? u.decode(Bool.self, forKey: FieldKey(k))) ?? false }
        username = (try? u.decode(String.self, forKey: FieldKey("username"))) ?? ""
        xp = number("xp")
        spots = number("spots")
        goldSpots = number("gold_spots")
        isPro = truth("is_pro")
        isAdmin = truth("is_admin")
        unlockAll = truth("unlock_all")
        avatarURL = try? u.decode(String.self, forKey: FieldKey("avatar_url"))
        var worn: [String: String] = [:]
        for (type, field) in Wardrobe.equipField {
            if let v = try? u.decode(LooseValue.self, forKey: FieldKey(field)) { worn[type] = v.text }
        }
        equipped = worn
        let rows: [OwnedRow] = (try? top.decode(LenientArray<OwnedRow>.self, forKey: .ownedItems))?.items ?? []
        owned = Set(rows.map { $0.key })
    }

    init(username: String, xp: Int = 0, spots: Int = 0, goldSpots: Int = 0, isPro: Bool = false,
         isAdmin: Bool = false, unlockAll: Bool = false, owned: Set<String> = [],
         equipped: [String: String] = [:], avatarURL: String? = nil) {
        self.username = username
        self.xp = xp
        self.spots = spots
        self.goldSpots = goldSpots
        self.isPro = isPro
        self.isAdmin = isAdmin
        self.unlockAll = unlockAll
        self.owned = owned
        self.equipped = equipped
        self.avatarURL = avatarURL
    }

    var level: Int { max(1, Int((25.0 + (625.0 + 100.0 * Double(max(0, xp))).squareRoot()) / 50.0)) }

    /// The equipped item of a type as the browser reads it: name effects fall
    /// back to "none", everything else to nothing.
    func equippedID(_ type: String) -> String? {
        equipped[type] ?? (type == "name-effect" ? "none" : nil)
    }

    /// `Cx`: bought (the shop's "Owned").
    func hasBought(_ item: CatalogItem, type: String) -> Bool {
        owned.contains("\(type):\(item.id)")
    }

    /// `lu`: listed at all. Personal items only for their owner, admin items
    /// only for admins or whoever has one.
    func canSee(_ item: CatalogItem, type: String) -> Bool {
        if let o = item.owner { return o.lowercased() == username.lowercased() }
        if item.itemGroup != .admin { return true }
        return isAdmin || hasBought(item, type: type)
    }

    /// `zd`: may be equipped.
    func hasUnlocked(_ item: CatalogItem, type: String) -> Bool {
        if let o = item.owner { return o.lowercased() == username.lowercased() }
        if unlockAll || item.unlockType == "free" { return true }
        switch item.unlockType {
        case "pro": return isPro
        case "achievement": return owned.contains("achievement:\(item.unlockValue ?? "")")
        case "level": return level >= (Int(item.unlockValue ?? "1") ?? 1)
        case "spots": return hasBought(item, type: type)
        case "admin": return isAdmin
        case "special": return item.special && hasBought(item, type: type)
        default: return false
        }
    }

    /// The balance an item is paid from.
    func balance(for price: ItemPrice) -> Int { price.isGold ? goldSpots : spots }
}

/// `catalog.json`.
struct ItemCatalog: Decodable {
    let categories: [ItemCategory]
    let items: [String: [CatalogItem]]

    private enum CodingKeys: String, CodingKey { case categories, items }
    private struct TypeKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        categories = (try? c.decode(LenientArray<ItemCategory>.self, forKey: .categories))?.items ?? []
        var all: [String: [CatalogItem]] = [:]
        if let byType = try? c.nestedContainer(keyedBy: TypeKey.self, forKey: .items) {
            for key in byType.allKeys {
                all[key.stringValue] = (try? byType.decode(LenientArray<CatalogItem>.self, forKey: key))?.items ?? []
            }
        }
        items = all
    }

    init(categories: [ItemCategory], items: [String: [CatalogItem]]) {
        self.categories = categories
        self.items = items
    }

    func list(_ type: String) -> [CatalogItem] { items[type] ?? [] }

    func item(_ type: String, id: String?) -> CatalogItem? {
        guard let id = id else { return nil }
        return list(type).first { $0.id == id }
    }

    /// `ey`: items split into groups, in the browser's order, empty groups left out.
    static func grouped(_ list: [CatalogItem]) -> [(group: ItemGroup, items: [CatalogItem])] {
        var byGroup: [ItemGroup: [CatalogItem]] = [:]
        for item in list { byGroup[item.itemGroup, default: []].append(item) }
        return ItemGroup.allCases.compactMap { g in
            guard let entries = byGroup[g], !entries.isEmpty else { return nil }
            return (group: g, items: entries)
        }
    }
}

/// The filter menu under the search box. Shop and Style share "All" and the
/// groups; each adds two of its own.
enum ItemFilter: Hashable {
    case all, affordable, owned, unlocked, locked
    case group(ItemGroup)

    var label: String {
        switch self {
        case .all: return "All"
        case .affordable: return "Affordable"
        case .owned: return "Owned"
        case .unlocked: return "Unlocked"
        case .locked: return "Locked"
        case .group(let g): return g.label
        }
    }

    static let shopChoices: [ItemFilter] = [.all, .affordable, .owned] + ItemGroup.allCases.map { .group($0) }
    static let styleChoices: [ItemFilter] = [.all, .unlocked, .locked] + ItemGroup.allCases.map { .group($0) }
}

enum ItemSelection {
    /// The shop lists only spots items the player may see, then applies
    /// search and filter (`nN`).
    static func shop(_ catalog: ItemCatalog, type: String, wardrobe: Wardrobe,
                     search: String, filter: ItemFilter, onWeekend: Bool) -> (shown: [CatalogItem], total: Int) {
        let offered: [CatalogItem] = catalog.list(type).filter { $0.unlockType == "spots" && wardrobe.canSee($0, type: type) }
        let needle: String = search.trimmingCharacters(in: .whitespaces).lowercased()
        let shown: [CatalogItem] = offered.filter { item in
            if !needle.isEmpty && !item.displayName.lowercased().contains(needle) { return false }
            let bought: Bool = wardrobe.hasBought(item, type: type)
            switch filter {
            case .owned: return bought
            case .affordable:
                let p: ItemPrice = item.price(onWeekend: onWeekend)
                return !bought && p.amount <= wardrobe.balance(for: p)
            case .all: return true
            case .group(let g): return item.itemGroup == g
            case .unlocked, .locked: return true
            }
        }
        return (shown, offered.count)
    }

    /// Style lists everything the player may see (`rN`).
    static func style(_ catalog: ItemCatalog, type: String, wardrobe: Wardrobe,
                      search: String, filter: ItemFilter) -> [CatalogItem] {
        let visible: [CatalogItem] = catalog.list(type).filter { wardrobe.canSee($0, type: type) }
        let needle: String = search.trimmingCharacters(in: .whitespaces).lowercased()
        return visible.filter { item in
            if !needle.isEmpty && !item.displayName.lowercased().contains(needle) { return false }
            let isOpen: Bool = wardrobe.hasUnlocked(item, type: type)
            switch filter {
            case .unlocked: return isOpen
            case .locked: return !isOpen
            case .all: return true
            case .group(let g): return item.itemGroup == g
            case .affordable, .owned: return true
            }
        }
    }

    /// The "1/13" on a Style tab: unlocked of visible.
    static func tally(_ catalog: ItemCatalog, type: String, wardrobe: Wardrobe) -> (unlocked: Int, total: Int) {
        let visible: [CatalogItem] = catalog.list(type).filter { wardrobe.canSee($0, type: type) }
        return (visible.filter { wardrobe.hasUnlocked($0, type: type) }.count, visible.count)
    }
}

/// `$u`: the colour that stands for a value - itself, or the middle stop of a gradient.
enum CosmeticColor {
    static func representative(_ value: String?) -> String? {
        guard let v = value, !v.isEmpty else { return nil }
        guard v.contains("gradient") else { return v }
        let stops: [String] = hexStops(v)
        return stops.isEmpty ? nil : stops[stops.count / 2]
    }

    /// All #rrggbb (or #rgb) colours in a CSS value, in order.
    static func hexStops(_ value: String) -> [String] {
        var found: [String] = []
        let chars: [Character] = Array(value)
        var i: Int = 0
        while i < chars.count {
            if chars[i] == "#" {
                var j: Int = i + 1
                while j < chars.count, chars[j].isHexDigit { j += 1 }
                let length: Int = j - i - 1
                if length == 3 || length == 6 || length == 8 { found.append(String(chars[i..<j])) }
                i = j
            } else {
                i += 1
            }
        }
        return found
    }

    /// "#b15cff" → 0xB15CFF; "#abc" → 0xAABBCC.
    static func rgb(_ hex: String) -> UInt32? {
        var digits: String = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        if digits.count == 8 { digits = String(digits.prefix(6)) }
        guard digits.count == 6 else { return nil }
        return UInt32(digits, radix: 16)
    }
}
