import Foundation

// Logiktests, die ohne Bildschirm laufen - auf dem Mac-Runner vor dem Xcode-Schritt.
//
// Geprueft wird vor allem das Dekodieren: ein Client stirbt an einer Nachricht,
// die er nicht lesen kann, und zwar erst auf dem Geraet, mitten in einer Runde.
// Die JSON-Schnipsel hier sind der Form nachgebildet, die `server.js`
// tatsaechlich verschickt - samt der Unsauberkeiten, die JavaScript erlaubt.

var failures = 0
var checkCount = 0

func expect(_ what: String, _ condition: @autoclosure () -> Bool) {
    checkCount += 1
    if condition() {
        print("  ok   \(what)")
    } else {
        print("  FEHL \(what)")
        failures += 1
    }
}

func expectEqual<T: Equatable>(_ what: String, _ a: T?, _ b: T?) {
    checkCount += 1
    if a == b {
        print("  ok   \(what)")
    } else {
        print("  FEHL \(what): \(String(describing: a)) != \(String(describing: b))")
        failures += 1
    }
}

func section(_ name: String) { print("\n\(name)") }

let dek = JSONDecoder()
func parse<T: Decodable>(_ t: T.Type, _ json: String) -> T? {
    try? dek.decode(T.self, from: Data(json.utf8))
}

// MARK: - Lose: Zahl oder Text

section("Lose")
expectEqual("Konto-ID kommt als Zahl", parse(LooseValue.self, "42")?.text, "42")
expectEqual("Gast-ID kommt als Text", parse(LooseValue.self, "\"guest-1712-ab\"")?.text, "guest-1712-ab")
expectEqual("Jahr als Gleitkomma wird ganzzahlig", parse(LooseValue.self, "1994.0")?.text, "1994")
expectEqual("zahl() liest zurueck", parse(LooseValue.self, "\"1994\"")?.numeric, 1994)
expect("kein Wert aus einem Objekt", parse(LooseValue.self, "{}") == nil)

// MARK: - Durchlaessig: ein kaputter Eintrag kostet nur sich selbst

section("Durchlaessig")
let mixed = """
[{"id":1,"nickname":"A","score":10},{"nickname":"ohne id"},{"id":"guest-x","nickname":"B","score":5}]
"""
let filtered = parse(LenientArray<Player>.self, mixed)
expectEqual("zwei von drei Eintraegen ueberlebt", filtered?.items.count, 2)
expectEqual("der dritte ist noch da", filtered?.items.last?.nickname, "B")

// Hier ging frueher der Index nicht vor - Abbruch statt Endlosschleife.
let unreadable = parse(LenientArray<Player>.self, "[{\"id\":1,\"nickname\":\"A\"},7,8]")
expect("Zahl in der Liste haengt nicht", unreadable != nil)
expectEqual("bis zum unlesbaren Eintrag gelesen", unreadable?.items.count, 1)

// MARK: - Spieler

section("Spieler")
let playerJson = """
{"id":7,"nickname":"Taubey","score":325,"lives":3,"isEliminated":false,"isConnected":true,
 "isReady":true,"watchOnly":false,"isGuest":false,"isBot":false,"isPro":true,"isAdmin":true,
 "correctAnswers":4,"bestStreak":3,"iconId":12,"titleId":5,"avatarUrl":null,"emoji":"🎧",
 "lastPointsBreakdown":{"total":121,"breakdown":{"title":{"points":100,"text":"Title ✓"},
  "speed":{"points":21,"text":"Speed +21 ⚡"}},"ownAnswer":{"title":"Bound 2"}}}
"""
let s = parse(Player.self, playerJson)
expectEqual("Name", s?.nickname, "Taubey")
expectEqual("Punkte", s?.score, 325)
expectEqual("Aufstellung: Titel", s?.lastPointsBreakdown?.breakdown["title"]?.points, 100)
expectEqual("Aufstellung: Schnelligkeit", s?.lastPointsBreakdown?.breakdown["speed"]?.text, "Speed +21 ⚡")
expectEqual("Gesamtpunkte", s?.lastPointsBreakdown?.total, 121)
expectEqual("Emoji ueberlebt", s?.emoji, "🎧")

// Der Server laesst reichlich Felder weg, wenn sie leer sind. Nichts davon
// darf den Eintrag kosten - nur die ID ist Pflicht.
let sparse = parse(Player.self, "{\"id\":\"guest-9\"}")
expectEqual("duenner Eintrag hat trotzdem eine ID", sparse?.id.text, "guest-9")
expectEqual("Punkte fallen auf 0", sparse?.score, 0)
expectEqual("gilt als verbunden", sparse?.isConnected, true)
expect("ohne ID kein Spieler", parse(Player.self, "{\"nickname\":\"X\"}") == nil)

// MARK: - lobby-update

section("lobby-update")
let lobbyJson = """
{"type":"lobby-update","payload":{"pin":"483921","hostId":7,"gameState":"LOBBY","gameMode":"quiz",
 "players":[{"id":7,"nickname":"Taubey","score":0},{"id":"guest-1","nickname":"dante","score":0}],
 "settings":{"songCount":10,"guessTime":30,"answerType":"multiple","guessTypes":["title","artist"],
             "playlistName":"Mixtape","showCover":true,"boxMode":false}}}
"""
let lobby = parse(Envelope<LobbyUpdate>.self, lobbyJson)
expectEqual("Typ", lobby?.type, "lobby-update")
expectEqual("PIN", lobby?.payload?.pin, "483921")
expectEqual("zwei Spieler", lobby?.payload?.players.count, 2)
expectEqual("Gast ist dabei", lobby?.payload?.players.last?.id.text, "guest-1")
expectEqual("Rate-Arten", lobby?.payload?.settings?.guessTypes, ["title", "artist"])
expect("Multiple Choice erkannt", lobby?.payload?.settings?.isMultipleChoice == true)

// Eine PIN kommt je nach Weg als Zahl herein.
let pinNumber = parse(Envelope<LobbyUpdate>.self,
    "{\"type\":\"lobby-update\",\"payload\":{\"pin\":483921,\"players\":[]}}")
expectEqual("PIN als Zahl wird Text", pinNumber?.payload?.pin, "483921")

// MARK: - new-round

section("new-round")
let roundJson = """
{"type":"new-round","payload":{"round":3,"totalRounds":10,
 "previewUrl":"https://audio.example/x.m4a","albumArt":"https://art/x.jpg",
 "guessTypes":["title","year"],"isReverse":false,"startDelayMs":1500,
 "mcOptions":{"title":["Bound 2","Heroes","JU$T","Fix Up"],"year":[2013,2011,2020,2003]}}}
"""
let activeRound = parse(Envelope<NewRound>.self, roundJson)
expectEqual("Rundennummer", activeRound?.payload?.round, 3)
expectEqual("Schonfrist", activeRound?.payload?.startDelayMs, 1500)
expectEqual("Titel-Auswahl: vier", activeRound?.payload?.mcOptions["title"]?.count, 4)
// Genau hier haette ein strenges [String:[String]] die ganze Runde verworfen.
expectEqual("Jahr-Auswahl kommt als Zahl, wird Text", activeRound?.payload?.mcOptions["year"]?.first?.text, "2013")
expectEqual("und laesst sich zurueckrechnen", activeRound?.payload?.mcOptions["year"]?.first?.numeric, 2013)

// Ohne Vorschau-URL ist die Runde stumm, aber nicht kaputt.
let silentRound = parse(Envelope<NewRound>.self,
    "{\"type\":\"new-round\",\"payload\":{\"round\":1,\"totalRounds\":5,\"previewUrl\":null}}")
expect("Runde ohne Vorschau laedt trotzdem", silentRound?.payload != nil)
expect("previewUrl ist leer", silentRound?.payload?.previewUrl == nil)

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
expectEqual("Song", resultMsg?.payload?.correctTrack?.title, "Bound 2")
expectEqual("Jahr", resultMsg?.payload?.correctTrack?.year, 2013)
expectEqual("Punkte", resultMsg?.payload?.scores.first?.score, 175)
expect("nicht verdeckt", resultMsg?.payload?.sneaky == false)

// Sneaky Mode: der Song fehlt absichtlich.
let concealed = parse(Envelope<RoundResult>.self,
    "{\"type\":\"round-result\",\"payload\":{\"correctTrack\":null,\"sneaky\":true,\"scores\":[]}}")
expect("verdeckte Runde erkannt", concealed?.payload?.sneaky == true)
expect("ohne Song", concealed?.payload?.correctTrack == nil)

// MARK: - game-over

section("game-over")
let gameOverJson = """
{"type":"game-over","payload":{
 "scores":[{"id":7,"nickname":"Taubey","score":980,"correctAnswers":8,"bestStreak":5,
            "rewards":{"xp":120,"spots":40,"goldSpots":1}}],
 "songs":[{"title":"Heroes","artist":"David Bowie","year":1977}]}}
"""
let end = parse(Envelope<FinalStandings>.self, gameOverJson)
expectEqual("Sieger", end?.payload?.scores.first?.nickname, "Taubey")
expectEqual("XP", end?.payload?.scores.first?.rewards?.xp, 120)
expectEqual("Goldene Spots", end?.payload?.scores.first?.rewards?.goldSpots, 1)
expectEqual("Songliste", end?.payload?.songs.first?.title, "Heroes")

// MARK: - Kleinkram, der trotzdem weh tut

section("Rest")
expectEqual("toast", parse(Envelope<ToastMessage>.self,
    "{\"type\":\"toast\",\"payload\":{\"message\":\"Game not found!\",\"isError\":true}}")?.payload?.message,
    "Game not found!")
expectEqual("countdown", parse(Envelope<CountdownTick>.self,
    "{\"type\":\"countdown\",\"payload\":{\"number\":3}}")?.payload?.number, 3)
expectEqual("kicked mit Bann", parse(Envelope<KickNotice>.self,
    "{\"type\":\"kicked\",\"payload\":{\"banned\":true,\"reason\":\"spam\",\"minutesLeft\":30}}")?.payload?.minutesLeft, 30)
expectEqual("loading-progress", parse(Envelope<LoadingProgress>.self,
    "{\"type\":\"loading-progress\",\"payload\":{\"checked\":40,\"total\":60,\"playable\":31,\"needed\":10}}")?.payload?.playable, 31)
// game-starting kommt auch ohne Text - der Server schickt dann nur eine Phase.
expect("game-starting ohne message", parse(Envelope<StartMessage>.self,
    "{\"type\":\"game-starting\",\"payload\":{\"phase\":\"checking\"}}")?.payload != nil)
expectEqual("Systemzeile im Chat", parse(Envelope<ChatLine>.self,
    "{\"type\":\"chat-message\",\"payload\":{\"system\":true,\"nickname\":\"Lobby\",\"text\":\"dante joined\"}}")?.payload?.system, true)

// Nur den Typ lesen, ohne die Nutzlast anzufassen - so sortiert die App
// eingehende Nachrichten, bevor sie weiss, welche Form dahinter steckt.
expectEqual("NurTyp pflueckt den Typ heraus", parse(TypeOnly.self,
    "{\"type\":\"new-round\",\"payload\":{\"was\":[1,2,{\"tief\":true}]}}")?.type, "new-round")

// MARK: - Antwort

section("Antwort")
var a = Answer()
a["title"] = "Bound 2"
expectEqual("Index schreibt", a.title, "Bound 2")
expectEqual("Index liest", a["title"], "Bound 2")
expect("unvollstaendig solange der Interpret fehlt", !a.isComplete(covering: ["title", "artist"]))
a["artist"] = "Kanye West"
expect("vollstaendig", a.isComplete(covering: ["title", "artist"]))
a["year"] = "   "
expect("Leerzeichen zaehlen nicht", !a.isComplete(covering: ["year"]))

let identity = PlayerIdentity.guest(name: "dante")
expect("Gast-ID traegt das Praefix", identity.id.hasPrefix("guest-"))
expect("Gast ist als Gast markiert", identity.isGuest)
expect("zwei Gaeste kollidieren nicht", PlayerIdentity.guest(name: "a").id != PlayerIdentity.guest(name: "a").id)

// MARK: - Gegen echten Mitschnitt

// Die Schnipsel oben sind nachgebaut, und nachgebautes JSON bestaetigt nur, was
// man ohnehin geglaubt hat. Diese hier kommen woertlich aus einem gespielten
// Spiel - sie pruefen das Modell gegen den Server statt gegen mich.
section("Mitschnitt vom 2026-10-03")

let mLobby = parse(Envelope<LobbyUpdate>.self, Capture.lobbyUpdate)
expectEqual("echte PIN", mLobby?.payload?.pin, "2572")
expectEqual("echter Gast in der Liste", mLobby?.payload?.players.first?.id.text, "guest-1791031285893-probe")
expectEqual("Gastgeber erkannt", mLobby?.payload?.hostId?.text, mLobby?.payload?.players.first?.id.text)
expectEqual("drei Rate-Arten", mLobby?.payload?.settings?.guessTypes.count, 3)

let mRound = parse(Envelope<NewRound>.self, Capture.newRound)
expectEqual("echte Runde von zweien", mRound?.payload?.totalRounds, 2)
expect("Vorschau ist eine Apple-Adresse",
       mRound?.payload?.previewUrl?.contains("itunes.apple.com") == true)
expectEqual("vier Titel zur Auswahl", mRound?.payload?.mcOptions["title"]?.count, 4)
expectEqual("vier Jahre, als Zahlen geschickt", mRound?.payload?.mcOptions["year"]?.count, 4)
expectEqual("erstes Jahr", mRound?.payload?.mcOptions["year"]?.first?.numeric, 2012)
expectEqual("Schonfrist aus echtem Spiel", mRound?.payload?.startDelayMs, 1000)

let mResult = parse(Envelope<RoundResult>.self, Capture.roundResult)
expectEqual("aufgeloester Song", mResult?.payload?.correctTrack?.title, "You Are So Beautiful")
expectEqual("Interpret", mResult?.payload?.correctTrack?.artist, "Zucchero")
expectEqual("Jahr", mResult?.payload?.correctTrack?.year, 1992)

// Genau hier lag der Fehler: die Aufstellung steckt in einer Huelle
// {total, breakdown, ownAnswer}. Ein Modell ohne sie liefert still nil, und
// die Auswertung bleibt nach jeder Runde leer, ohne dass irgendwo etwas bricht.
let panel = mResult?.payload?.scores.first?.lastPointsBreakdown
expect("Punkteblatt ueberhaupt gelesen", panel != nil)
expectEqual("Gesamtpunkte der Runde", panel?.total, 150)
expectEqual("Titel sass", panel?.breakdown["title"]?.points, 100)
expectEqual("Interpret sass", panel?.breakdown["artist"]?.points, 50)
expectEqual("Jahr daneben", panel?.breakdown["year"]?.points, 0)
expectEqual("eigene Antwort kommt mit", panel?.ownAnswer?["year"]?.text, "2012")

let mEnd = parse(Envelope<FinalStandings>.self, Capture.gameOver)
expectEqual("Endpunkte", mEnd?.payload?.scores.first?.score, 200)
expectEqual("XP verdient", mEnd?.payload?.scores.first?.rewards?.xp, 28)
expectEqual("Spots verdient", mEnd?.payload?.scores.first?.rewards?.spots, 55)
expectEqual("gespielte Songs", mEnd?.payload?.songs.count, 2)

expectEqual("Ladefortschritt", parse(Envelope<LoadingProgress>.self, Capture.loadingProgress)?.payload?.playable, 5)
expectEqual("Startzaehler", parse(Envelope<CountdownTick>.self, Capture.countdown)?.payload?.number, 3)
expectEqual("Startmeldung", parse(Envelope<StartMessage>.self, Capture.gameStarting)?.payload?.message, "Loading songs...")
expectEqual("Beitrittszeile", parse(Envelope<ChatLine>.self, Capture.chatMessage)?.payload?.text, "ProtokollProbe joined")


// MARK: - Neu: Spiel erstellen, Reaktionen, Bestenliste

section("Spiel erstellen & Co. (Mitschnitt 2026-10-04)")
let gotReaction = parse(Envelope<Reaction>.self, Capture.playerReacted)?.payload
expectEqual("Reaktion: Emoji", gotReaction?.reaction, "😂")
expectEqual("Reaktion: wer", gotReaction?.nickname, "TestBot")
expectEqual("Spieler-Chatzeile", parse(Envelope<ChatLine>.self, Capture.chatPlayer)?.payload?.text, "hallo text")
let info = parse(PlaylistInfo.self, Capture.playlistInfo)
expectEqual("Playlist-ID", info?.id, "3cEYpjA9oz9GiPac4AsH4n")
expectEqual("Playlist-Quelle", info?.source, "spotify")
expectEqual("Playlist-Songs", info?.trackCount, 5)
let featuredList = parse(FeaturedPlaylists.self, Capture.featured)
expectEqual("empfohlene Playlist", featuredList?.entries.first?.id, "2Jc0amXy2IvLyTofJKgiYg")
let board = parse(Leaderboard.self, Capture.leaderboard)
expectEqual("Bestenliste: Eintraege", board?.entries.count, 2)
expectEqual("Bestenliste: Platz 1", board?.entries.first?.name, "Taubey")
expectEqual("Bestenliste: Wert", board?.entries.first?.amount, 29841)
expectEqual("Bestenliste: Konto-ID als Zahl", board?.entries.last?.id, "33")

var setup = GameSetup()
expect("ohne Playlist nichts zu senden", setup.payloadObject() == nil)
setup.playlist = info?.entry
setup.heading = false; setup.guessArtist = false; setup.guessYear = false
expectEqual("nichts gewaehlt heisst Titel", setup.guessKinds, ["title"])
setup.freeText = true
let last = setup.payloadObject()
expectEqual("Freitext heisst freestyle", last?["answerType"] as? String, "freestyle")
expectEqual("Playlist-ID in der Nutzlast", last?["playlistId"] as? String, "3cEYpjA9oz9GiPac4AsH4n")
expect("Nutzlast ist gueltiges JSON", last.map { JSONSerialization.isValidJSONObject($0) } ?? false)

// MARK: - Startbildschirm, Quests, taegliche Belohnung

section("Live-Zahlen (Mitschnitt) und Konto-Antworten (aus dem Web-Bundle)")
expectEqual("online", parse(LiveStats.self, #"{"players":7,"lobbies":2}"#)?.players, 7)
expectEqual("Lobbys", parse(LiveStats.self, #"{"players":0,"lobbies":0}"#)?.lobbies, 0)

let quests = parse(QuestOverview.self, #"""
{"daily":{"d_win1":{"target":1,"progress":0,"done":false,"claimed":false,"reward":40},"d_play3":{"target":3,"progress":3,"done":true,"claimed":false,"reward":30}},
 "weekly":{"w_play20":{"target":20,"progress":"4","reward":150}},
 "quests":{"win_1":{"done":true,"claimed":true,"reward":50},"kaputt":7}}
"""#)
expectEqual("taeglich: zwei", quests?.dailyQuests.count, 2)
expectEqual("feste Reihenfolge", quests?.dailyQuests.first?.id, "d_play3")
expect("fertig, nicht abgeholt", quests?.dailyQuests.first?.finished == true && quests?.dailyQuests.first?.isClaimed == false)
expectEqual("Stand als Text", quests?.weeklyQuests.first?.tally, 4)
expectEqual("ohne Ziel und Stand: fertig heisst voll", quests?.milestones.first?.tally, 1)
expectEqual("kaputter Eintrag faellt raus", quests?.milestones.count, 1)
expectEqual("Abholung", parse(ClaimResult.self, #"{"reward":30,"newSpots":530}"#)?.newSpots, 530)

let bonus = parse(DailyBonus.self, #"{"claimable":true,"current":2,"today":{"day":3,"spots":40,"gold":0,"xp":10,"label":null},"ladder":[]}"#)
expect("Bonus abholbar", bonus?.isClaimable == true)
expectEqual("Bonus Tag", bonus?.dayNumber, 3)
expectEqual("Bonus Spots", bonus?.spots, 40)
expectEqual("Bonus ohne today", parse(DailyBonus.self, #"{"claimable":false,"current":5}"#)?.dayNumber, 6)
expectEqual("Bonus abgeholt", parse(DailyBonusClaim.self, #"{"claimed":true,"streak":3,"reward":40,"goldReward":0,"xpReward":10}"#)?.streakDay, 3)

// MARK: -

print("\n\(checkCount) geprueft, \(failures) fehlgeschlagen")
exit(failures == 0 ? 0 : 1)
