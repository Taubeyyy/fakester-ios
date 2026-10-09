import Foundation

// Awards against the test account's real /achievements (first two entries,
// captured 2026-10-09). The second one is given a claimable first tier the
// way the bundle reads it (nextClaim.index / .reward) - the capture had none.

private let awardsJSON = #"{"achievements":[{"id":"games","name":"Games Played","icon":"fa-gamepad","value":0,"level":0,"total":6,"maxed":false,"nextGoal":1,"progress":0,"nextClaim":null,"tiers":[{"goal":1,"reward":100,"reached":false,"claimed":false},{"goal":10,"reward":250,"reached":false,"claimed":false},{"goal":50,"reward":600,"reached":false,"claimed":false},{"goal":100,"reward":1200,"reached":false,"claimed":false},{"goal":250,"reward":2500,"reached":false,"claimed":false},{"goal":500,"reward":5000,"reached":false,"claimed":false}]},{"id":"wins","name":"Victories","icon":"fa-crown","value":1,"level":0,"total":5,"maxed":false,"nextGoal":1,"progress":0,"nextClaim":{"index":0,"reward":200},"tiers":[{"goal":1,"reward":200,"reached":true,"claimed":false},{"goal":10,"reward":500,"reached":false,"claimed":false},{"goal":25,"reward":1000,"reached":false,"claimed":false},{"goal":50,"reward":2000,"reached":false,"claimed":false},{"goal":100,"reward":4000,"reached":false,"claimed":false}]}],"unlocked":0,"total":63}"#

func checkAwards() {
    section("Awards")
    let board: AchievementBoard? = parse(AchievementBoard.self, awardsJSON)
    expectEqual("two awards", board?.achievements.count, 2)
    expectEqual("tiers unlocked", board?.unlocked, 0)
    expectEqual("tiers total", board?.total, 63)
    let games = board?.achievements.first
    expectEqual("name", games?.name, "Games Played")
    expectEqual("Font Awesome icon", games?.icon, "fa-gamepad")
    expectEqual("six tiers", games?.tiers.count, 6)
    expectEqual("next goal", games?.nextGoal, 1)
    expectEqual("next reward is tier 1's", games?.nextReward, 100)
    expect("nothing to claim", games?.nextClaim == nil)
    let wins = board?.achievements.last
    expectEqual("claimable tier", wins?.nextClaim?.index, 0)
    expectEqual("claimable reward", wins?.nextClaim?.reward, 200)
    expect("reached tier", wins?.tiers.first?.reached == true)
    expectEqual("broken entries are skipped",
                parse(AchievementBoard.self, #"{"achievements":[7,{"id":"x","tiers":[]}],"unlocked":"1","total":2}"#)?.achievements.count, 1)

    section("Quest reset")
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    var parts = DateComponents()
    parts.year = 2026; parts.month = 10; parts.day = 9; parts.hour = 8; parts.minute = 14
    let friday: Date = utc.date(from: parts)!
    expectEqual("daily: to midnight UTC", QuestReset.text(weekly: false, now: friday), "Resets in 15h 46m")
    expectEqual("weekly: to Monday 00:00 UTC", QuestReset.text(weekly: true, now: friday), "Resets in 2d 15h")
    parts.day = 12; parts.hour = 0; parts.minute = 30
    expectEqual("Monday counts to the next Monday", QuestReset.text(weekly: true, now: utc.date(from: parts)!), "Resets in 6d 23h")
    parts.day = 9; parts.hour = 23; parts.minute = 50
    expectEqual("under an hour: minutes only", QuestReset.text(weekly: false, now: utc.date(from: parts)!), "Resets in 10m")
}
