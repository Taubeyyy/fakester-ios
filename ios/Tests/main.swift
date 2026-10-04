import Foundation

// Logiktests, die ohne Bildschirm laufen - auf dem Mac-Runner vor dem Xcode-Schritt.
//
// Geprueft wird vor allem das Dekodieren: ein Client stirbt an einer Nachricht,
// die er nicht lesen kann, und zwar erst auf dem Geraet, mitten in einer Runde.
// Die JSON-Schnipsel hier sind der Form nachgebildet, die `server.js`
// tatsaechlich verschickt - samt der Unsauberkeiten, die JavaScript erlaubt.

var fehler = 0
var geprueft = 0

func pruefe(_ was: String, _ bedingung: @autoclosure () -> Bool) {
    geprueft += 1
    if bedingung() {
        print("  ok   \(was)")
    } else {
        print("  FEHL \(was)")
        fehler += 1
    }
}

func gleich<T: Equatable>(_ was: String, _ a: T?, _ b: T?) {
    geprueft += 1
    if a == b {
        print("  ok   \(was)")
    } else {
        print("  FEHL \(was): \(String(describing: a)) != \(String(describing: b))")
        fehler += 1
    }
}

func abschnitt(_ name: String) { print("\n\(name)") }

let dek = JSONDecoder()
func lies<T: Decodable>(_ t: T.Type, _ json: String) -> T? {
    try? dek.decode(T.self, from: Data(json.utf8))
}

// MARK: - Lose: Zahl oder Text

abschnitt("Lose")
gleich("Konto-ID kommt als Zahl", lies(Lose.self, "42")?.text, "42")
gleich("Gast-ID kommt als Text", lies(Lose.self, "\"guest-1712-ab\"")?.text, "guest-1712-ab")
gleich("Jahr als Gleitkomma wird ganzzahlig", lies(Lose.self, "1994.0")?.text, "1994")
gleich("zahl() liest zurueck", lies(Lose.self, "\"1994\"")?.zahl, 1994)
pruefe("kein Wert aus einem Objekt", lies(Lose.self, "{}") == nil)

// MARK: - Durchlaessig: ein kaputter Eintrag kostet nur sich selbst

abschnitt("Durchlaessig")
let gemischt = """
[{"id":1,"nickname":"A","score":10},{"nickname":"ohne id"},{"id":"guest-x","nickname":"B","score":5}]
"""
let durch = lies(Durchlaessig<Spieler>.self, gemischt)
gleich("zwei von drei Eintraegen ueberlebt", durch?.liste.count, 2)
gleich("der dritte ist noch da", durch?.liste.last?.nickname, "B")

// Hier ging frueher der Index nicht vor - Abbruch statt Endlosschleife.
let unlesbar = lies(Durchlaessig<Spieler>.self, "[{\"id\":1,\"nickname\":\"A\"},7,8]")
pruefe("Zahl in der Liste haengt nicht", unlesbar != nil)
gleich("bis zum unlesbaren Eintrag gelesen", unlesbar?.liste.count, 1)

// MARK: - Spieler

abschnitt("Spieler")
let spielerJson = """
{"id":7,"nickname":"Taubey","score":325,"lives":3,"isEliminated":false,"isConnected":true,
 "isReady":true,"watchOnly":false,"isGuest":false,"isBot":false,"isPro":true,"isAdmin":true,
 "correctAnswers":4,"bestStreak":3,"iconId":12,"titleId":5,"avatarUrl":null,"emoji":"🎧",
 "lastPointsBreakdown":{"total":121,"breakdown":{"title":{"points":100,"text":"Title ✓"},
  "speed":{"points":21,"text":"Speed +21 ⚡"}},"ownAnswer":{"title":"Bound 2"}}}
"""
let s = lies(Spieler.self, spielerJson)
gleich("Name", s?.nickname, "Taubey")
gleich("Punkte", s?.score, 325)
gleich("Aufstellung: Titel", s?.lastPointsBreakdown?.breakdown["title"]?.points, 100)
gleich("Aufstellung: Schnelligkeit", s?.lastPointsBreakdown?.breakdown["speed"]?.text, "Speed +21 ⚡")
gleich("Gesamtpunkte", s?.lastPointsBreakdown?.total, 121)
gleich("Emoji ueberlebt", s?.emoji, "🎧")

// Der Server laesst reichlich Felder weg, wenn sie leer sind. Nichts davon
// darf den Eintrag kosten - nur die ID ist Pflicht.
let duenn = lies(Spieler.self, "{\"id\":\"guest-9\"}")
gleich("duenner Eintrag hat trotzdem eine ID", duenn?.id.text, "guest-9")
gleich("Punkte fallen auf 0", duenn?.score, 0)
gleich("gilt als verbunden", duenn?.isConnected, true)
pruefe("ohne ID kein Spieler", lies(Spieler.self, "{\"nickname\":\"X\"}") == nil)

// MARK: - lobby-update

abschnitt("lobby-update")
let lobbyJson = """
{"type":"lobby-update","payload":{"pin":"483921","hostId":7,"gameState":"LOBBY","gameMode":"quiz",
 "players":[{"id":7,"nickname":"Taubey","score":0},{"id":"guest-1","nickname":"dante","score":0}],
 "settings":{"songCount":10,"guessTime":30,"answerType":"multiple","guessTypes":["title","artist"],
             "playlistName":"Mixtape","showCover":true,"boxMode":false}}}
"""
let lobby = lies(Umschlag<LobbyUpdate>.self, lobbyJson)
gleich("Typ", lobby?.type, "lobby-update")
gleich("PIN", lobby?.payload?.pin, "483921")
gleich("zwei Spieler", lobby?.payload?.players.count, 2)
gleich("Gast ist dabei", lobby?.payload?.players.last?.id.text, "guest-1")
gleich("Rate-Arten", lobby?.payload?.settings?.guessTypes, ["title", "artist"])
pruefe("Multiple Choice erkannt", lobby?.payload?.settings?.istMC == true)

// Eine PIN kommt je nach Weg als Zahl herein.
let pinZahl = lies(Umschlag<LobbyUpdate>.self,
    "{\"type\":\"lobby-update\",\"payload\":{\"pin\":483921,\"players\":[]}}")
gleich("PIN als Zahl wird Text", pinZahl?.payload?.pin, "483921")

// MARK: - new-round

abschnitt("new-round")
let rundeJson = """
{"type":"new-round","payload":{"round":3,"totalRounds":10,
 "previewUrl":"https://audio.example/x.m4a","albumArt":"https://art/x.jpg",
 "guessTypes":["title","year"],"isReverse":false,"startDelayMs":1500,
 "mcOptions":{"title":["Bound 2","Heroes","JU$T","Fix Up"],"year":[2013,2011,2020,2003]}}}
"""
let runde = lies(Umschlag<NeueRunde>.self, rundeJson)
gleich("Rundennummer", runde?.payload?.round, 3)
gleich("Schonfrist", runde?.payload?.startDelayMs, 1500)
gleich("Titel-Auswahl: vier", runde?.payload?.mcOptions["title"]?.count, 4)
// Genau hier haette ein strenges [String:[String]] die ganze Runde verworfen.
gleich("Jahr-Auswahl kommt als Zahl, wird Text", runde?.payload?.mcOptions["year"]?.first?.text, "2013")
gleich("und laesst sich zurueckrechnen", runde?.payload?.mcOptions["year"]?.first?.zahl, 2013)

// Ohne Vorschau-URL ist die Runde stumm, aber nicht kaputt.
let stumm = lies(Umschlag<NeueRunde>.self,
    "{\"type\":\"new-round\",\"payload\":{\"round\":1,\"totalRounds\":5,\"previewUrl\":null}}")
pruefe("Runde ohne Vorschau laedt trotzdem", stumm?.payload != nil)
pruefe("previewUrl ist leer", stumm?.payload?.previewUrl == nil)

// MARK: - round-result

abschnitt("round-result")
let ergebnisJson = """
{"type":"round-result","payload":{
 "correctTrack":{"title":"Bound 2","artist":"Kanye West","year":2013,"albumArt":"https://a/b.jpg"},
 "scores":[{"id":7,"nickname":"Taubey","score":175,
            "lastPointsBreakdown":{"total":175,"breakdown":{
                "title":{"points":100,"text":"Title ✓"},
                "year":{"points":75,"text":"Year ✓"}},"ownAnswer":{"year":2013}}}]}}
"""
let erg = lies(Umschlag<RundenErgebnis>.self, ergebnisJson)
gleich("Song", erg?.payload?.correctTrack?.title, "Bound 2")
gleich("Jahr", erg?.payload?.correctTrack?.year, 2013)
gleich("Punkte", erg?.payload?.scores.first?.score, 175)
pruefe("nicht verdeckt", erg?.payload?.sneaky == false)

// Sneaky Mode: der Song fehlt absichtlich.
let verdeckt = lies(Umschlag<RundenErgebnis>.self,
    "{\"type\":\"round-result\",\"payload\":{\"correctTrack\":null,\"sneaky\":true,\"scores\":[]}}")
pruefe("verdeckte Runde erkannt", verdeckt?.payload?.sneaky == true)
pruefe("ohne Song", verdeckt?.payload?.correctTrack == nil)

// MARK: - game-over

abschnitt("game-over")
let endeJson = """
{"type":"game-over","payload":{
 "scores":[{"id":7,"nickname":"Taubey","score":980,"correctAnswers":8,"bestStreak":5,
            "rewards":{"xp":120,"spots":40,"goldSpots":1}}],
 "songs":[{"title":"Heroes","artist":"David Bowie","year":1977}]}}
"""
let ende = lies(Umschlag<Endstand>.self, endeJson)
gleich("Sieger", ende?.payload?.scores.first?.nickname, "Taubey")
gleich("XP", ende?.payload?.scores.first?.rewards?.xp, 120)
gleich("Goldene Spots", ende?.payload?.scores.first?.rewards?.goldSpots, 1)
gleich("Songliste", ende?.payload?.songs.first?.title, "Heroes")

// MARK: - Kleinkram, der trotzdem weh tut

abschnitt("Rest")
gleich("toast", lies(Umschlag<Hinweis>.self,
    "{\"type\":\"toast\",\"payload\":{\"message\":\"Game not found!\",\"isError\":true}}")?.payload?.message,
    "Game not found!")
gleich("countdown", lies(Umschlag<Zaehler>.self,
    "{\"type\":\"countdown\",\"payload\":{\"number\":3}}")?.payload?.number, 3)
gleich("kicked mit Bann", lies(Umschlag<Rauswurf>.self,
    "{\"type\":\"kicked\",\"payload\":{\"banned\":true,\"reason\":\"spam\",\"minutesLeft\":30}}")?.payload?.minutesLeft, 30)
gleich("loading-progress", lies(Umschlag<LadeStand>.self,
    "{\"type\":\"loading-progress\",\"payload\":{\"checked\":40,\"total\":60,\"playable\":31,\"needed\":10}}")?.payload?.playable, 31)
// game-starting kommt auch ohne Text - der Server schickt dann nur eine Phase.
pruefe("game-starting ohne message", lies(Umschlag<Startmeldung>.self,
    "{\"type\":\"game-starting\",\"payload\":{\"phase\":\"checking\"}}")?.payload != nil)
gleich("Systemzeile im Chat", lies(Umschlag<ChatZeile>.self,
    "{\"type\":\"chat-message\",\"payload\":{\"system\":true,\"nickname\":\"Lobby\",\"text\":\"dante joined\"}}")?.payload?.system, true)

// Nur den Typ lesen, ohne die Nutzlast anzufassen - so sortiert die App
// eingehende Nachrichten, bevor sie weiss, welche Form dahinter steckt.
gleich("NurTyp pflueckt den Typ heraus", lies(NurTyp.self,
    "{\"type\":\"new-round\",\"payload\":{\"was\":[1,2,{\"tief\":true}]}}")?.type, "new-round")

// MARK: - Antwort

abschnitt("Antwort")
var a = Antwort()
a["title"] = "Bound 2"
gleich("Index schreibt", a.title, "Bound 2")
gleich("Index liest", a["title"], "Bound 2")
pruefe("unvollstaendig solange der Interpret fehlt", !a.vollstaendig(fuer: ["title", "artist"]))
a["artist"] = "Kanye West"
pruefe("vollstaendig", a.vollstaendig(fuer: ["title", "artist"]))
a["year"] = "   "
pruefe("Leerzeichen zaehlen nicht", !a.vollstaendig(fuer: ["year"]))

let ausweis = SpielerAusweis.gast(name: "dante")
pruefe("Gast-ID traegt das Praefix", ausweis.id.hasPrefix("guest-"))
pruefe("Gast ist als Gast markiert", ausweis.isGuest)
pruefe("zwei Gaeste kollidieren nicht", SpielerAusweis.gast(name: "a").id != SpielerAusweis.gast(name: "a").id)

// MARK: - Gegen echten Mitschnitt

// Die Schnipsel oben sind nachgebaut, und nachgebautes JSON bestaetigt nur, was
// man ohnehin geglaubt hat. Diese hier kommen woertlich aus einem gespielten
// Spiel - sie pruefen das Modell gegen den Server statt gegen mich.
abschnitt("Mitschnitt vom 2026-10-03")

let mLobby = lies(Umschlag<LobbyUpdate>.self, Mitschnitt.lobbyUpdate)
gleich("echte PIN", mLobby?.payload?.pin, "2572")
gleich("echter Gast in der Liste", mLobby?.payload?.players.first?.id.text, "guest-1791031285893-probe")
gleich("Gastgeber erkannt", mLobby?.payload?.hostId?.text, mLobby?.payload?.players.first?.id.text)
gleich("drei Rate-Arten", mLobby?.payload?.settings?.guessTypes.count, 3)

let mRunde = lies(Umschlag<NeueRunde>.self, Mitschnitt.newRound)
gleich("echte Runde von zweien", mRunde?.payload?.totalRounds, 2)
pruefe("Vorschau ist eine Apple-Adresse",
       mRunde?.payload?.previewUrl?.contains("itunes.apple.com") == true)
gleich("vier Titel zur Auswahl", mRunde?.payload?.mcOptions["title"]?.count, 4)
gleich("vier Jahre, als Zahlen geschickt", mRunde?.payload?.mcOptions["year"]?.count, 4)
gleich("erstes Jahr", mRunde?.payload?.mcOptions["year"]?.first?.zahl, 2012)
gleich("Schonfrist aus echtem Spiel", mRunde?.payload?.startDelayMs, 1000)

let mErgebnis = lies(Umschlag<RundenErgebnis>.self, Mitschnitt.roundResult)
gleich("aufgeloester Song", mErgebnis?.payload?.correctTrack?.title, "You Are So Beautiful")
gleich("Interpret", mErgebnis?.payload?.correctTrack?.artist, "Zucchero")
gleich("Jahr", mErgebnis?.payload?.correctTrack?.year, 1992)

// Genau hier lag der Fehler: die Aufstellung steckt in einer Huelle
// {total, breakdown, ownAnswer}. Ein Modell ohne sie liefert still nil, und
// die Auswertung bleibt nach jeder Runde leer, ohne dass irgendwo etwas bricht.
let blatt = mErgebnis?.payload?.scores.first?.lastPointsBreakdown
pruefe("Punkteblatt ueberhaupt gelesen", blatt != nil)
gleich("Gesamtpunkte der Runde", blatt?.total, 150)
gleich("Titel sass", blatt?.breakdown["title"]?.points, 100)
gleich("Interpret sass", blatt?.breakdown["artist"]?.points, 50)
gleich("Jahr daneben", blatt?.breakdown["year"]?.points, 0)
gleich("eigene Antwort kommt mit", blatt?.ownAnswer?["year"]?.text, "2012")

let mEnde = lies(Umschlag<Endstand>.self, Mitschnitt.gameOver)
gleich("Endpunkte", mEnde?.payload?.scores.first?.score, 200)
gleich("XP verdient", mEnde?.payload?.scores.first?.rewards?.xp, 28)
gleich("Spots verdient", mEnde?.payload?.scores.first?.rewards?.spots, 55)
gleich("gespielte Songs", mEnde?.payload?.songs.count, 2)

gleich("Ladefortschritt", lies(Umschlag<LadeStand>.self, Mitschnitt.loadingProgress)?.payload?.playable, 5)
gleich("Startzaehler", lies(Umschlag<Zaehler>.self, Mitschnitt.countdown)?.payload?.number, 3)
gleich("Startmeldung", lies(Umschlag<Startmeldung>.self, Mitschnitt.gameStarting)?.payload?.message, "Loading songs...")
gleich("Beitrittszeile", lies(Umschlag<ChatZeile>.self, Mitschnitt.chatMessage)?.payload?.text, "ProtokollProbe joined")

// MARK: -

print("\n\(geprueft) geprueft, \(fehler) fehlgeschlagen")
exit(fehler == 0 ? 0 : 1)
