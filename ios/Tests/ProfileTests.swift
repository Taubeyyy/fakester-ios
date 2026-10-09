import Foundation

/// The Stats screen: `/profile` (counters + history) and the achievements tally.
func checkProfile() {
    section("Profile / Stats")
    // Real answer for the test account "Claude" (2026-10-05), no games yet.
    let fresh = parse(ProfileDetails.self, #"{"user":{"id":80,"username":"Claude","xp":0,"spots":100,"gold_spots":0,"games_played":0,"wins":0,"highscore":0,"correct_answers":0,"is_pro":false,"season_pass_tier":0,"season_pass_id":null,"is_admin":false,"equipped_title_id":1,"equipped_icon_id":1,"equipped_color_id":null,"equipped_background_id":"default","equipped_accent_color_id":1,"equipped_emoji":null,"avatar_url":null,"equipped_name_effect":null,"unlock_all":false,"saved_playlists":[]},"ownedItems":[],"history":[],"friends":[]}"#)
    expectEqual("profile: correct answers", fresh?.correctAnswers, 0)
    expectEqual("profile: empty history", fresh?.history.count, 0)

    // A history entry in the shape the browser reads (QN in the bundle).
    let played = parse(ProfileDetails.self, #"""
    {"user":{"id":80,"correct_answers":"12"},"history":[{"id":7,"game_mode":"quiz","placement":1,"playlist_name":"Featured","played_at":"2026-10-05T10:00:00.000Z","total_players":3,"score":375,"xp_gained":31,"spots_gained":89},{"placement":null,"score":0}]}
    """#)
    expectEqual("profile: correct answers as text", played?.correctAnswers, 12)
    expectEqual("profile: two games", played?.history.count, 2)
    expectEqual("profile: winner", played?.history.first?.placement, 1)
    expectEqual("profile: spots", played?.history.first?.spotsGained, 89)
    expect("profile: date read", played?.history.first?.playedAt != nil)
    expectEqual("profile: unknown placement", played?.history.last?.placement, nil)
    expectEqual("profile: unknown playlist", played?.history.last?.playlistName, "Unknown playlist")

    let now = GameRecord.parseDate("2026-10-09T12:00:00Z") ?? Date()
    expectEqual("relative: today", GameRecord.relative(GameRecord.parseDate("2026-10-09T08:00:00Z"), now: now), "Today")
    expectEqual("relative: yesterday", GameRecord.relative(GameRecord.parseDate("2026-10-08T08:00:00Z"), now: now), "Yesterday")
    expectEqual("relative: days", GameRecord.relative(GameRecord.parseDate("2026-10-05T08:00:00Z"), now: now), "4 days ago")

    // Real /achievements (first two entries), nothing unlocked or claimable yet.
    let tally = parse(AchievementTally.self, #"{"achievements":[{"id":"games","name":"Games Played","icon":"fa-gamepad","value":0,"level":0,"total":6,"maxed":false,"nextGoal":1,"progress":0,"nextClaim":null,"tiers":[{"goal":1,"reward":100,"reached":false,"claimed":false},{"goal":10,"reward":250,"reached":false,"claimed":false},{"goal":50,"reward":600,"reached":false,"claimed":false},{"goal":100,"reward":1200,"reached":false,"claimed":false},{"goal":250,"reward":2500,"reached":false,"claimed":false},{"goal":500,"reward":5000,"reached":false,"claimed":false}]},{"id":"wins","name":"Victories","icon":"fa-crown","value":0,"level":0,"total":5,"maxed":false,"nextGoal":1,"progress":0,"nextClaim":null,"tiers":[{"goal":1,"reward":200,"reached":false,"claimed":false},{"goal":10,"reward":500,"reached":false,"claimed":false},{"goal":25,"reward":1000,"reached":false,"claimed":false},{"goal":50,"reward":2000,"reached":false,"claimed":false},{"goal":100,"reward":4000,"reached":false,"claimed":false}]}],"unlocked":0,"total":63}"#)
    expectEqual("achievements: total", tally?.total, 63)
    expectEqual("achievements: unlocked", tally?.unlocked, 0)
    expectEqual("achievements: claimable", tally?.claimable, 0)
    let claim = parse(AchievementTally.self, #"{"achievements":[{"nextClaim":{"goal":1}},{"nextClaim":null},{}],"unlocked":1,"total":63}"#)
    expectEqual("achievements: one to claim", claim?.claimable, 1)
}
