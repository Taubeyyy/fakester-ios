import Foundation

// Shop and Style rules against the real catalog.json (trimmed to a few items
// per type, captured 2026-10-09) and the test account's real /profile.

private let catalogJSON = """
{"categories":[{"type":"title","label":"Titles","shop":true,"style":true},{"type":"icon","label":"Icons","shop
":true,"style":true},{"type":"background","label":"Backgrounds","shop":true,"style":true},{"type":"accent-colo
r","label":"Accent","shop":true,"style":true},{"type":"name-effect","label":"Name FX","shop":true,"style":true
}],"items":{"title":[{"id":1,"name":"Newbie","rarity":"common","unlockType":"level","unlockValue":1,"special":
false,"cost":null,"goldCost":null,"iconClass":null,"cssClass":null,"colorHex":null},{"rarity":"legendary","unl
ockType":"achievement","unlockValue":"games#5","special":false,"cost":null,"goldCost":null,"iconClass":null,"c
ssClass":null,"colorHex":"linear-gradient(90deg,#fde68a,#d97706,#fbbf24)","anim":null,"group":"earned","id":94
01,"name":"Jukebox"},{"rarity":"rare","unlockType":"level","unlockValue":5,"special":false,"cost":null,"goldCo
st":null,"iconClass":null,"cssClass":null,"colorHex":"#9ca3af","anim":null,"id":9301,"name":"Regular"},{"rarit
y":"rare","unlockType":"spots","unlockValue":null,"special":false,"cost":400,"goldCost":null,"iconClass":null,
"cssClass":null,"colorHex":"#60a5fa","anim":null,"id":9302,"name":"Bassline"},{"rarity":"legendary","unlockTyp
e":"special","unlockValue":null,"special":false,"cost":null,"goldCost":null,"iconClass":null,"cssClass":null,"
colorHex":"linear-gradient(90deg,#fde68a,#f59e0b,#b45309)","anim":null,"id":9312,"name":"Original","owner":"ta
ubey"},{"rarity":"epic","unlockType":"admin","unlockValue":null,"special":false,"cost":null,"goldCost":null,"i
conClass":null,"cssClass":null,"colorHex":"#f87171","anim":null,"id":9313,"name":"Staff"}],"icon":[{"id":1,"na
me":null,"rarity":"common","unlockType":"level","unlockValue":1,"special":false,"cost":null,"goldCost":null,"i
conClass":"fa-user","cssClass":null,"colorHex":null},{"rarity":"legendary","unlockType":"achievement","unlockV
alue":"wins#4","special":false,"cost":null,"goldCost":null,"iconClass":"mark:vinyl","cssClass":null,"colorHex"
:"#fbbf24","anim":"fa-spin","group":"earned","id":9401,"name":"Vinyl"},{"rarity":"rare","unlockType":"spots","
unlockValue":null,"special":false,"cost":500,"goldCost":null,"iconClass":"fa-compact-disc","cssClass":null,"co
lorHex":"#38bdf8","anim":null,"id":9302},{"rarity":"rare","unlockType":"spots","unlockValue":null,"special":fa
lse,"cost":null,"goldCost":80,"iconClass":"mark:flame","cssClass":null,"colorHex":"#f97316","anim":"fa-beat","
id":9308,"name":"Flame"}],"background":[{"id":"default","name":"Standard","rarity":"common","unlockType":"leve
l","unlockValue":1,"special":false,"cost":null,"goldCost":null,"iconClass":null,"cssClass":null,"colorHex":nul
l}],"name-effect":[{"id":"none","name":"No Effect","rarity":"common","unlockType":"free","unlockValue":null,"s
pecial":false,"cost":null,"goldCost":null,"iconClass":null,"cssClass":null,"colorHex":null},{"rarity":"epic","
unlockType":"spots","unlockValue":null,"special":false,"cost":null,"goldCost":60,"iconClass":null,"cssClass":"
nfx-x-neon","colorHex":null,"anim":null,"id":9401,"name":"Neon"}],"accent-color":[{"id":1,"name":"Fakester Pur
ple","rarity":"common","unlockType":"level","unlockValue":1,"special":false,"cost":null,"goldCost":null,"iconC
lass":null,"cssClass":null,"colorHex":"#b15cff"},{"rarity":"epic","unlockType":"spots","unlockValue":null,"spe
cial":false,"cost":1800,"goldCost":null,"iconClass":null,"cssClass":null,"colorHex":"linear-gradient(90deg,#fb
bf24,#f97316,#dc2626)","anim":null,"id":9305,"name":"Ember"}]}}
"""

private let profileJSON = """
{"user":{"id":80,"username":"Claude","xp":0,"spots":100,"gold_spots":0,"games_played":0,"wins":0,"highscore":0,"correct_answers":0,"is_pro":false,"season_pass_tier":0,"season_pass_id":null,"is_admin":false,"equipped_title_id":1,"equipped_icon_id":1,"equipped_color_id":null,"equipped_background_id":"default","equipped_accent_color_id":1,"equipped_emoji":null,"avatar_url":null,"equipped_name_effect":null,"unlock_all":false,"saved_playlists":[]},"ownedItems":[],"history":[],"friends":[]}
"""

func checkCosmetics() {
    section("Cosmetics: catalog")
    let catalog: ItemCatalog? = parse(ItemCatalog.self, catalogJSON.replacingOccurrences(of: "\n", with: ""))
    expectEqual("five category tabs", catalog?.categories.count, 5)
    expectEqual("tab label", catalog?.categories.last?.label, "Name FX")
    expectEqual("six titles", catalog?.list("title").count, 6)
    expectEqual("text IDs stay text", catalog?.list("background").first?.id, "default")
    expectEqual("number IDs become text", catalog?.list("title").first?.id, "1")
    let icon = catalog?.item("icon", id: "9302")
    expectEqual("nameless icon is named after its class", icon?.displayName, "Compact Disc")
    expectEqual("the default icon reads User", catalog?.item("icon", id: "1")?.displayName, "User")
    expectEqual("achievement label", catalog?.item("title", id: "9401")?.unlockLabel, "500 games")
    expectEqual("level label", catalog?.item("title", id: "9301")?.unlockLabel, "Level 5")
    expectEqual("shop label", catalog?.item("title", id: "9302")?.unlockLabel, "Shop")
    expectEqual("explicit group wins", catalog?.item("icon", id: "9401")?.itemGroup, .earned)
    expectEqual("free is standard", catalog?.item("name-effect", id: "none")?.itemGroup, .standard)
    expectEqual("admin item", catalog?.item("title", id: "9313")?.itemGroup, .admin)

    section("Cosmetics: prices")
    let bassline = catalog?.item("title", id: "9302")
    expectEqual("weekday price", bassline?.price(onWeekend: false).amount, 400)
    expectEqual("weekend price is 20 % off", bassline?.price(onWeekend: true).amount, 320)
    expect("weekend price counts as discounted", bassline?.price(onWeekend: true).isDiscounted == true)
    let flame = catalog?.item("icon", id: "9308")
    expectEqual("gold price", flame?.price(onWeekend: true).amount, 80)
    expect("gold is never discounted", flame?.price(onWeekend: true).isGold == true
        && flame?.price(onWeekend: true).isDiscounted == false)
    var saturday = DateComponents()
    saturday.year = 2026; saturday.month = 10; saturday.day = 10; saturday.hour = 12
    var monday = saturday
    monday.day = 12
    let cal = Calendar(identifier: .gregorian)
    expect("Saturday is weekend", Pricing.isWeekend(cal.date(from: saturday)!, calendar: cal))
    expect("Monday is not", !Pricing.isWeekend(cal.date(from: monday)!, calendar: cal))

    section("Cosmetics: wardrobe")
    let me: Wardrobe? = parse(Wardrobe.self, profileJSON)
    expectEqual("username", me?.username, "Claude")
    expectEqual("spots", me?.spots, 100)
    expectEqual("equipped title as text", me?.equippedID("title"), "1")
    expectEqual("equipped background", me?.equippedID("background"), "default")
    expectEqual("no name effect means none", me?.equippedID("name-effect"), "none")
    expectEqual("null colour stays empty", me?.equippedID("color"), nil)
    expectEqual("nothing owned yet", me?.owned.count, 0)
    let owning: Wardrobe? = parse(Wardrobe.self, """
    {"user":{"username":"x","xp":"2000","spots":900,"gold_spots":100,"equipped_icon_id":9302},
     "ownedItems":[{"item_type":"icon","item_id":9302},{"item_type":"achievement","item_id":"games#5"},{"bad":1}]}
    """)
    expect("bought icon is owned", owning?.owned.contains("icon:9302") == true)
    expect("earned achievement is owned", owning?.owned.contains("achievement:games#5") == true)
    expectEqual("xp as text still counts", owning?.level, 9)

    section("Cosmetics: rules")
    if let c = catalog, let w = me, let o = owning {
        let staff = c.item("title", id: "9313")!
        let original = c.item("title", id: "9312")!
        expect("admin title hidden from players", !w.canSee(staff, type: "title"))
        expect("personal title hidden from others", !w.canSee(original, type: "title"))
        expect("personal title visible to its owner", Wardrobe(username: "Taubey").canSee(original, type: "title"))
        expect("level 1 item unlocked", w.hasUnlocked(c.item("title", id: "1")!, type: "title"))
        expect("level 5 item locked at level 1", !w.hasUnlocked(c.item("title", id: "9301")!, type: "title"))
        expect("level 5 item unlocked at level 9", o.hasUnlocked(c.item("title", id: "9301")!, type: "title"))
        expect("achievement item unlocked by the achievement", o.hasUnlocked(c.item("title", id: "9401")!, type: "title"))
        expect("unbought spots item locked", !w.hasUnlocked(c.item("icon", id: "9302")!, type: "icon"))
        expect("bought spots item unlocked", o.hasUnlocked(c.item("icon", id: "9302")!, type: "icon"))
        expect("free item unlocked", w.hasUnlocked(c.item("name-effect", id: "none")!, type: "name-effect"))

        let shopTitles = ItemSelection.shop(c, type: "title", wardrobe: w, search: "", filter: .all, onWeekend: false)
        expectEqual("shop lists only spots titles", shopTitles.shown.map { $0.id }, ["9302"])
        expectEqual("shop total", shopTitles.total, 1)
        let affordable = ItemSelection.shop(c, type: "icon", wardrobe: w, search: "", filter: .affordable, onWeekend: false)
        expectEqual("nothing affordable with 100 spots", affordable.shown.count, 0)
        let rich = ItemSelection.shop(c, type: "icon", wardrobe: o, search: "", filter: .owned, onWeekend: false)
        expectEqual("owned filter", rich.shown.map { $0.id }, ["9302"])
        let searched = ItemSelection.shop(c, type: "icon", wardrobe: w, search: "disc", filter: .all, onWeekend: false)
        expectEqual("search by derived name", searched.shown.map { $0.id }, ["9302"])

        let styleTitles = ItemSelection.style(c, type: "title", wardrobe: w, search: "", filter: .all)
        expectEqual("style hides admin and personal titles", styleTitles.count, 4)
        expectEqual("style locked filter", ItemSelection.style(c, type: "title", wardrobe: w, search: "", filter: .locked).count, 3)
        let tally = ItemSelection.tally(c, type: "title", wardrobe: w)
        expect("tab tally 1/4", tally.unlocked == 1 && tally.total == 4)
        let groups = ItemCatalog.grouped(styleTitles).map { $0.group }
        expectEqual("groups in browser order", groups, [.earned, .level, .shop])
    }

    section("Cosmetics: colours")
    expectEqual("plain colour", CosmeticColor.representative("#60a5fa"), "#60a5fa")
    expectEqual("gradient middle stop", CosmeticColor.representative("linear-gradient(90deg,#fde68a,#d97706,#fbbf24)"), "#d97706")
    expectEqual("no colour", CosmeticColor.representative(nil), nil)
    expectEqual("hex value", CosmeticColor.rgb("#b15cff"), 0xB15CFF)
    expectEqual("short hex", CosmeticColor.rgb("#abc"), 0xAABBCC)
}
