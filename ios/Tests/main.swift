import Foundation

// Logic tests that run without a screen - on the Mac runner before the Xcode step.
//
// Mostly they check decoding: a client dies on a message it cannot read, and
// only on the device, in the middle of a round. The JSON snippets here mimic
// the shape `server.js` actually sends - including the sloppiness JavaScript
// allows.

var failures = 0
var checkCount = 0

func expect(_ what: String, _ condition: @autoclosure () -> Bool) {
    checkCount += 1
    if condition() {
        print("  ok   \(what)")
    } else {
        print("  FAIL \(what)")
        failures += 1
    }
}

func expectEqual<T: Equatable>(_ what: String, _ a: T?, _ b: T?) {
    checkCount += 1
    if a == b {
        print("  ok   \(what)")
    } else {
        print("  FAIL \(what): \(String(describing: a)) != \(String(describing: b))")
        failures += 1
    }
}

func section(_ name: String) { print("\n\(name)") }

let jsonDecoder = JSONDecoder()
func parse<T: Decodable>(_ t: T.Type, _ json: String) -> T? {
    try? jsonDecoder.decode(T.self, from: Data(json.utf8))
}

// MARK: - LooseValue: number or text

section("LooseValue")
expectEqual("account ID arrives as a number", parse(LooseValue.self, "42")?.text, "42")
expectEqual("guest ID arrives as text", parse(LooseValue.self, "\"guest-1712-ab\"")?.text, "guest-1712-ab")
expectEqual("year as float becomes an integer", parse(LooseValue.self, "1994.0")?.text, "1994")
expectEqual("numeric reads it back", parse(LooseValue.self, "\"1994\"")?.numeric, 1994)
expect("no value from an object", parse(LooseValue.self, "{}") == nil)

// MARK: - LenientArray: a broken entry only costs itself

section("LenientArray")
let mixed = """
[{"id":1,"nickname":"A","score":10},{"nickname":"ohne id"},{"id":"guest-x","nickname":"B","score":5}]
"""
let filtered = parse(LenientArray<Player>.self, mixed)
expectEqual("two of three entries survive", filtered?.items.count, 2)
expectEqual("the third one is still there", filtered?.items.last?.nickname, "B")

// The index used not to advance here - stop instead of an endless loop.
let unreadable = parse(LenientArray<Player>.self, "[{\"id\":1,\"nickname\":\"A\"},7,8]")
expect("number in the list does not hang", unreadable != nil)
expectEqual("read up to the unreadable entry", unreadable?.items.count, 1)

// MARK: - Player

section("Player")
let playerJson = """
{"id":7,"nickname":"Taubey","score":325,"lives":3,"isEliminated":false,"isConnected":true,
 "isReady":true,"watchOnly":false,"isGuest":false,"isBot":false,"isPro":true,"isAdmin":true,
 "correctAnswers":4,"bestStreak":3,"iconId":12,"titleId":5,"avatarUrl":null,"emoji":"🎧",
 "lastPointsBreakdown":{"total":121,"breakdown":{"title":{"points":100,"text":"Title ✓"},
  "speed":{"points":21,"text":"Speed +21 ⚡"}},"ownAnswer":{"title":"Bound 2"}}}
"""
let s = parse(Player.self, playerJson)
expectEqual("name", s?.nickname, "Taubey")
expectEqual("score", s?.score, 325)
expectEqual("breakdown: title", s?.lastPointsBreakdown?.breakdown["title"]?.points, 100)
expectEqual("breakdown: speed", s?.lastPointsBreakdown?.breakdown["speed"]?.text, "Speed +21 ⚡")
expectEqual("total points", s?.lastPointsBreakdown?.total, 121)
expectEqual("emoji survives", s?.emoji, "🎧")

// The server omits plenty of fields when they are empty. None of that may
// cost the entry - only the ID is required.
let sparse = parse(Player.self, "{\"id\":\"guest-9\"}")
expectEqual("sparse entry still has an ID", sparse?.id.text, "guest-9")
expectEqual("score falls back to 0", sparse?.score, 0)
expectEqual("counts as connected", sparse?.isConnected, true)
expect("no ID, no player", parse(Player.self, "{\"nickname\":\"X\"}") == nil)

// MARK: - lobby-update

section("lobby-update")
let lobbyJson = """
{"type":"lobby-update","payload":{"pin":"483921","hostId":7,"gameState":"LOBBY","gameMode":"quiz",
 "players":[{"id":7,"nickname":"Taubey","score":0},{"id":"guest-1","nickname":"dante","score":0}],
 "settings":{"songCount":10,"guessTime":30,"answerType":"multiple","guessTypes":["title","artist"],
             "playlistName":"Mixtape","showCover":true,"boxMode":false}}}
"""
let lobby = parse(Envelope<LobbyUpdate>.self, lobbyJson)
expectEqual("type", lobby?.type, "lobby-update")
expectEqual("PIN", lobby?.payload?.pin, "483921")
expectEqual("two players", lobby?.payload?.players.count, 2)
expectEqual("guest is included", lobby?.payload?.players.last?.id.text, "guest-1")
expectEqual("guess types", lobby?.payload?.settings?.guessTypes, ["title", "artist"])
expect("multiple choice detected", lobby?.payload?.settings?.isMultipleChoice == true)

// Depending on the path, a PIN arrives as a number.
let pinNumber = parse(Envelope<LobbyUpdate>.self,
    "{\"type\":\"lobby-update\",\"payload\":{\"pin\":483921,\"players\":[]}}")
expectEqual("PIN as number becomes text", pinNumber?.payload?.pin, "483921")

// MARK: - new-round

section("new-round")
let roundJson = """
{"type":"new-round","payload":{"round":3,"totalRounds":10,
 "previewUrl":"https://audio.example/x.m4a","albumArt":"https://art/x.jpg",
 "guessTypes":["title","year"],"isReverse":false,"startDelayMs":1500,
 "mcOptions":{"title":["Bound 2","Heroes","JU$T","Fix Up"],"year":[2013,2011,2020,2003]}}}
"""
let activeRound = parse(Envelope<NewRound>.self, roundJson)
expectEqual("round number", activeRound?.payload?.round, 3)
expectEqual("grace period", activeRound?.payload?.startDelayMs, 1500)
expectEqual("title choices: four", activeRound?.payload?.mcOptions["title"]?.count, 4)
// This is exactly where a strict [String:[String]] would have dropped the whole round.
expectEqual("year choices arrive as numbers, become text", activeRound?.payload?.mcOptions["year"]?.first?.text, "2013")
expectEqual("and convert back", activeRound?.payload?.mcOptions["year"]?.first?.numeric, 2013)

// Without a preview URL the round is silent, but not broken.
let silentRound = parse(Envelope<NewRound>.self,
    "{\"type\":\"new-round\",\"payload\":{\"round\":1,\"totalRounds\":5,\"previewUrl\":null}}")
expect("round without preview still loads", silentRound?.payload != nil)
expect("previewUrl is empty", silentRound?.payload?.previewUrl == nil)

// MARK: - round-result

section("round-result")
let resultJson = """
{"type":"round-result","payload":{
 "correctTrack":{"title":"Bound 2","artist":"Kanye West","year":2013,"albumArt":"https://a/b.jpg"},
 "scores":[{"id":7,"nickname":"Taubey","score":175,
            "lastPointsBreakdown":{"total":175,"breakdown":{
                "title":{"points":100,"text":"Title ✓"},
                "year":{"points":75,"text":"Year ✓"}},"ownAnswer":{"year":2013}}}]}}
"""
let resultMsg = parse(Envelope<RoundResult>.self, resultJson)
expectEqual("song", resultMsg?.payload?.correctTrack?.title, "Bound 2")
expectEqual("year", resultMsg?.payload?.correctTrack?.year, 2013)
expectEqual("score", resultMsg?.payload?.scores.first?.score, 175)
expect("not hidden", resultMsg?.payload?.sneaky == false)

// Sneaky mode: the song is missing on purpose.
let concealed = parse(Envelope<RoundResult>.self,
    "{\"type\":\"round-result\",\"payload\":{\"correctTrack\":null,\"sneaky\":true,\"scores\":[]}}")
expect("hidden round detected", concealed?.payload?.sneaky == true)
expect("no song", concealed?.payload?.correctTrack == nil)

// MARK: - game-over

section("game-over")
let gameOverJson = """
{"type":"game-over","payload":{
 "scores":[{"id":7,"nickname":"Taubey","score":980,"correctAnswers":8,"bestStreak":5,
            "rewards":{"xp":120,"spots":40,"goldSpots":1}}],
 "songs":[{"title":"Heroes","artist":"David Bowie","year":1977}]}}
"""
let end = parse(Envelope<FinalStandings>.self, gameOverJson)
expectEqual("winner", end?.payload?.scores.first?.nickname, "Taubey")
expectEqual("XP", end?.payload?.scores.first?.rewards?.xp, 120)
expectEqual("gold spots", end?.payload?.scores.first?.rewards?.goldSpots, 1)
expectEqual("song list", end?.payload?.songs.first?.title, "Heroes")

// MARK: - Small stuff that still hurts

section("Misc")
expectEqual("toast", parse(Envelope<ToastMessage>.self,
    "{\"type\":\"toast\",\"payload\":{\"message\":\"Game not found!\",\"isError\":true}}")?.payload?.message,
    "Game not found!")
expectEqual("countdown", parse(Envelope<CountdownTick>.self,
    "{\"type\":\"countdown\",\"payload\":{\"number\":3}}")?.payload?.number, 3)
expectEqual("kicked with ban", parse(Envelope<KickNotice>.self,
    "{\"type\":\"kicked\",\"payload\":{\"banned\":true,\"reason\":\"spam\",\"minutesLeft\":30}}")?.payload?.minutesLeft, 30)
expectEqual("loading-progress", parse(Envelope<LoadingProgress>.self,
    "{\"type\":\"loading-progress\",\"payload\":{\"checked\":40,\"total\":60,\"playable\":31,\"needed\":10}}")?.payload?.playable, 31)
// game-starting also arrives without text - the server then only sends a phase.
expect("game-starting without message", parse(Envelope<StartMessage>.self,
    "{\"type\":\"game-starting\",\"payload\":{\"phase\":\"checking\"}}")?.payload != nil)
expectEqual("system line in chat", parse(Envelope<ChatLine>.self,
    "{\"type\":\"chat-message\",\"payload\":{\"system\":true,\"nickname\":\"Lobby\",\"text\":\"dante joined\"}}")?.payload?.system, true)

// Read only the type without touching the payload - this is how the app sorts
// incoming messages before it knows which shape is behind them.
expectEqual("TypeOnly picks out the type", parse(TypeOnly.self,
    "{\"type\":\"new-round\",\"payload\":{\"was\":[1,2,{\"tief\":true}]}}")?.type, "new-round")

// MARK: - Answer

section("Answer")
var a = Answer()
a["title"] = "Bound 2"
expectEqual("subscript writes", a.title, "Bound 2")
expectEqual("subscript reads", a["title"], "Bound 2")
expect("incomplete while the artist is missing", !a.isComplete(covering: ["title", "artist"]))
a["artist"] = "Kanye West"
expect("complete", a.isComplete(covering: ["title", "artist"]))
a["year"] = "   "
expect("spaces do not count", !a.isComplete(covering: ["year"]))

let identity = PlayerIdentity.guest(name: "dante")
expect("guest ID carries the prefix", identity.id.hasPrefix("guest-"))
expect("guest is flagged as guest", identity.isGuest)
expect("two guests do not collide", PlayerIdentity.guest(name: "a").id != PlayerIdentity.guest(name: "a").id)

// MARK: - Against a real capture

// The snippets above are hand-made, and hand-made JSON only confirms what you
// believed anyway. These come verbatim from a game that was actually played -
// they test the model against the server instead of against me.
section("Capture from 2026-10-03")

let mLobby = parse(Envelope<LobbyUpdate>.self, Capture.lobbyUpdate)
expectEqual("real PIN", mLobby?.payload?.pin, "2572")
expectEqual("real guest in the list", mLobby?.payload?.players.first?.id.text, "guest-1791031285893-probe")
expectEqual("host detected", mLobby?.payload?.hostId?.text, mLobby?.payload?.players.first?.id.text)
expectEqual("three guess types", mLobby?.payload?.settings?.guessTypes.count, 3)

let mRound = parse(Envelope<NewRound>.self, Capture.newRound)
expectEqual("real game has two rounds", mRound?.payload?.totalRounds, 2)
expect("preview is an Apple URL",
       mRound?.payload?.previewUrl?.contains("itunes.apple.com") == true)
expectEqual("four title choices", mRound?.payload?.mcOptions["title"]?.count, 4)
expectEqual("four years, sent as numbers", mRound?.payload?.mcOptions["year"]?.count, 4)
expectEqual("first year", mRound?.payload?.mcOptions["year"]?.first?.numeric, 2012)
expectEqual("grace period from a real game", mRound?.payload?.startDelayMs, 1000)

let mResult = parse(Envelope<RoundResult>.self, Capture.roundResult)
expectEqual("revealed song", mResult?.payload?.correctTrack?.title, "You Are So Beautiful")
expectEqual("artist", mResult?.payload?.correctTrack?.artist, "Zucchero")
expectEqual("year", mResult?.payload?.correctTrack?.year, 1992)

// This is exactly where the bug was: the breakdown sits inside a wrapper
// {total, breakdown, ownAnswer}. A model without it silently yields nil, and
// the results stay empty after every round without anything visibly breaking.
let panel = mResult?.payload?.scores.first?.lastPointsBreakdown
expect("points breakdown read at all", panel != nil)
expectEqual("round total", panel?.total, 150)
expectEqual("title correct", panel?.breakdown["title"]?.points, 100)
expectEqual("artist correct", panel?.breakdown["artist"]?.points, 50)
expectEqual("year wrong", panel?.breakdown["year"]?.points, 0)
expectEqual("own answer included", panel?.ownAnswer?["year"]?.text, "2012")

let mEnd = parse(Envelope<FinalStandings>.self, Capture.gameOver)
expectEqual("final score", mEnd?.payload?.scores.first?.score, 200)
expectEqual("XP earned", mEnd?.payload?.scores.first?.rewards?.xp, 28)
expectEqual("spots earned", mEnd?.payload?.scores.first?.rewards?.spots, 55)
expectEqual("songs played", mEnd?.payload?.songs.count, 2)

expectEqual("loading progress", parse(Envelope<LoadingProgress>.self, Capture.loadingProgress)?.payload?.playable, 5)
expectEqual("start countdown", parse(Envelope<CountdownTick>.self, Capture.countdown)?.payload?.number, 3)
expectEqual("start message", parse(Envelope<StartMessage>.self, Capture.gameStarting)?.payload?.message, "Loading songs...")
expectEqual("join line", parse(Envelope<ChatLine>.self, Capture.chatMessage)?.payload?.text, "ProtokollProbe joined")


// MARK: - New: create game, reactions, leaderboard

section("Create game & co. (capture 2026-10-04)")
let gotReaction = parse(Envelope<Reaction>.self, Capture.playerReacted)?.payload
expectEqual("reaction: emoji", gotReaction?.reaction, "😂")
expectEqual("reaction: who", gotReaction?.nickname, "TestBot")
expectEqual("player chat line", parse(Envelope<ChatLine>.self, Capture.chatPlayer)?.payload?.text, "hallo text")
let info = parse(PlaylistInfo.self, Capture.playlistInfo)
expectEqual("playlist ID", info?.id, "3cEYpjA9oz9GiPac4AsH4n")
expectEqual("playlist source", info?.source, "spotify")
expectEqual("playlist songs", info?.trackCount, 5)
let featuredList = parse(FeaturedPlaylists.self, Capture.featured)
expectEqual("featured playlist", featuredList?.entries.first?.id, "2Jc0amXy2IvLyTofJKgiYg")
let board = parse(Leaderboard.self, Capture.leaderboard)
expectEqual("leaderboard: entries", board?.entries.count, 2)
expectEqual("leaderboard: rank 1", board?.entries.first?.name, "Taubey")
expectEqual("leaderboard: value", board?.entries.first?.amount, 29841)
expectEqual("leaderboard: account ID as number", board?.entries.last?.id, "33")
expectEqual("leaderboard: admin shield", board?.entries.first?.admin, true)
expectEqual("leaderboard: no admin", board?.entries.last?.admin, false)
expectEqual("leaderboard: avatar made absolute", board?.entries.first?.avatarURL?.absoluteString, "https://fakester.app/fakester/avatars/u1.webp?v=1786896689820")
expectEqual("leaderboard: no avatar", board?.entries.last?.avatarURL, nil)

var setup = GameSetup()
expect("nothing to send without a playlist", setup.payloadObject() == nil)
setup.playlist = info?.entry
setup.heading = false; setup.guessArtist = false; setup.guessYear = false
expectEqual("nothing selected means title", setup.guessKinds, ["title"])
setup.freeText = true
let last = setup.payloadObject()
expectEqual("free text means freestyle", last?["answerType"] as? String, "freestyle")
expectEqual("playlist ID in the payload", last?["playlistId"] as? String, "3cEYpjA9oz9GiPac4AsH4n")
expect("payload is valid JSON", last.map { JSONSerialization.isValidJSONObject($0) } ?? false)

// MARK: - Home screen, quests, daily reward

section("Live numbers (capture) and account responses (from the web bundle)")
expectEqual("online", parse(LiveStats.self, #"{"players":7,"lobbies":2}"#)?.players, 7)
expectEqual("lobbies", parse(LiveStats.self, #"{"players":0,"lobbies":0}"#)?.lobbies, 0)

let quests = parse(QuestOverview.self, #"""
{"daily":{"d_win1":{"target":1,"progress":0,"done":false,"claimed":false,"reward":40},"d_play3":{"target":3,"progress":3,"done":true,"claimed":false,"reward":30}},
 "weekly":{"w_play20":{"target":20,"progress":"4","reward":150}},
 "quests":{"win_1":{"done":true,"claimed":true,"reward":50},"kaputt":7}}
"""#)
expectEqual("daily: two", quests?.dailyQuests.count, 2)
expectEqual("fixed order", quests?.dailyQuests.first?.id, "d_play3")
expect("done, not claimed", quests?.dailyQuests.first?.finished == true && quests?.dailyQuests.first?.isClaimed == false)
expectEqual("progress as text", quests?.weeklyQuests.first?.tally, 4)
expectEqual("no target or progress: done means full", quests?.milestones.first?.tally, 1)
expectEqual("broken entry is dropped", quests?.milestones.count, 1)
expectEqual("claim", parse(ClaimResult.self, #"{"reward":30,"newSpots":530}"#)?.newSpots, 530)

let bonus = parse(DailyBonus.self, #"{"claimable":true,"current":2,"today":{"day":3,"spots":40,"gold":0,"xp":10,"label":null},"ladder":[]}"#)
expect("bonus claimable", bonus?.isClaimable == true)
expectEqual("bonus day", bonus?.dayNumber, 3)
expectEqual("bonus spots", bonus?.spots, 40)
expectEqual("bonus without today", parse(DailyBonus.self, #"{"claimable":false,"current":5}"#)?.dayNumber, 6)
expectEqual("bonus claimed", parse(DailyBonusClaim.self, #"{"claimed":true,"streak":3,"reward":40,"goldReward":0,"xpReward":10}"#)?.streakDay, 3)

// MARK: -

// MARK: - Lobby settings (host edits them in the lobby)

section("Lobby settings")
let lobbyJSON = #"""
{"songCount":5,"guessTime":20,"answerType":"multiple","guessTypes":["title","artist","year"],"playlistName":"Featured","playlistId":"2Jc0amXy2IvLyTofJKgiYg","showCover":true,"boxMode":false,"hostPlays":true,"sneakyMode":false,"revealTime":5,"speedBonus":true,"streakBonus":true,"playlists":[{"id":"2Jc0amXy2IvLyTofJKgiYg","source":"spotify","name":"Featured","weight":10}]}
"""#
let lobbySettings = parse(LobbySettings.self, lobbyJSON)
expectEqual("lobby settings: playlist mix read", lobbySettings?.playlists.count, 1)
expectEqual("lobby settings: weight kept", lobbySettings?.playlists.first?.weight, 10)
if let ls = lobbySettings {
    var edit = GameSetup(lobby: ls)
    expectEqual("lobby settings: songs taken over", edit.songs, 5)
    expect("lobby settings: all three guess types", edit.heading && edit.guessArtist && edit.guessYear)
    edit.songs = 15
    edit.freeText = true
    let update = edit.settingsUpdate(keeping: ls)
    expectEqual("update: songCount", update["songCount"] as? Int, 15)
    expectEqual("update: free text", update["answerType"] as? String, "freestyle")
    expectEqual("update: playlist id kept", update["playlistId"] as? String, "2Jc0amXy2IvLyTofJKgiYg")
    let mix = update["playlists"] as? [[String: Any]]
    expectEqual("update: weight passed back", mix?.first?["weight"] as? Int, 10)
    expect("update: valid JSON", JSONSerialization.isValidJSONObject(update))
}

print("\n\(checkCount) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
