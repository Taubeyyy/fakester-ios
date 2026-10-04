import Foundation

// Echte Nachrichten, am 2026-10-03 aus einem laufenden Spiel auf fakester.app
// mitgeschnitten (Gast-Lobby, zwei Songs, Multiple Choice ueber Titel,
// Interpret und Jahr).
//
// Warum woertlich und nicht nachgebaut: das Modell fuer `lastPointsBreakdown`
// stand nach dem Lesen von server.js falsch da - die Punkteaufstellung hat
// eine Huelle `{total, breakdown, ownAnswer}`, die im Quelltext an einer ganz
// anderen Stelle entsteht als die Werte selbst. Nachgebautes JSON haette den
// Fehler bestaetigt statt ihn zu zeigen. Diese Schnipsel sind deshalb bewusst
// unveraendert, samt Feldern, die die App gar nicht liest.

enum Mitschnitt {

    /// `lobby-update`
    static let lobbyUpdate = #"""
{"type":"lobby-update","payload":{"pin":"2572","hostId":"guest-1791031285893-probe","banner":"none","gameState":"LOBBY","players":[{"id":"guest-1791031285893-probe","nickname":"ProtokollProbe","score":0,"lives":3,"isEliminated":false,"correctAnswers":0,"bestStreak":0,"isConnected":true,"lastPointsBreakdown":null,"avatarUrl":null,"iconId":1,"colorId":null,"nameEffect":null,"titleId":1,"backgroundId":null,"accentColorId":null,"watchOnly":false,"isReady":false,"isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"emoji":null,"isBot":false,"isGuest":true}],"gameMode":"quiz","isPublic":false,"lobbyLang":null,"lobbyGenre":null,"settings":{"songCount":2,"guessTime":6,"answerType":"multiple","lives":3,"gameType":"points","survivalType":"lives","raceTarget":1000,"guessTypes":["title","artist","year"],"playlistName":"Web API Testing","playlistId":"3cEYpjA9oz9GiPac4AsH4n","showCover":true,"boxMode":false,"hostPlays":true,"sneakyMode":false,"revealTime":2,"speedBonus":true,"streakBonus":true,"playlists":null}}}
"""#

    /// `chat-message`
    static let chatMessage = #"""
{"type":"chat-message","payload":{"system":true,"kind":"join","nickname":"Lobby","text":"ProtokollProbe joined","ts":1791031285950}}
"""#

    /// `game-starting`
    static let gameStarting = #"""
{"type":"game-starting","payload":{"message":"Loading songs..."}}
"""#

    /// `loading-progress`
    static let loadingProgress = #"""
{"type":"loading-progress","payload":{"checked":5,"total":5,"playable":5,"needed":2,"cached":false}}
"""#

    /// `countdown`
    static let countdown = #"""
{"type":"countdown","payload":{"number":3}}
"""#

    /// `new-round`
    static let newRound = #"""
{"type":"new-round","payload":{"round":1,"totalRounds":2,"previewUrl":"https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/23/02/9f/23029fa2-e7a7-46cf-06df-3c56e5ce68f4/mzaf_13895145173345317358.plus.aac.p.m4a","albumArt":"https://i.scdn.co/image/ab67616d0000b27304e57d181ff062f8339d6c71","mcOptions":{"title":["You Are So Beautiful","Api","All I Want","Endpoints"],"artist":["Zucchero","Odiseo","Glenn Horiuchi","LCD Soundsystem"],"year":[2012,2007,1992,2015]},"guessTypes":["title","artist","year"],"isReverse":false,"startDelayMs":1000}}
"""#

    /// `round-result`
    static let roundResult = #"""
{"type":"round-result","payload":{"correctTrack":{"spotifyId":"2E2znCPaS8anQe21GLxcvJ","title":"You Are So Beautiful","artist":"Zucchero","year":1992,"albumArt":"https://i.scdn.co/image/ab67616d0000b27304e57d181ff062f8339d6c71","popularity":0,"previewUrl":"https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/23/02/9f/23029fa2-e7a7-46cf-06df-3c56e5ce68f4/mzaf_13895145173345317358.plus.aac.p.m4a"},"scores":[{"id":"guest-1791031285893-probe","nickname":"ProtokollProbe","score":150,"lives":3,"isEliminated":false,"correctAnswers":2,"bestStreak":0,"isConnected":true,"lastPointsBreakdown":{"total":150,"breakdown":{"title":{"points":100,"text":"Title ✓"},"artist":{"points":50,"text":"Artist ✓"},"year":{"points":0,"text":"Year ✗"}},"ownAnswer":{"title":"You Are So Beautiful","artist":"Zucchero","year":"2012"}},"avatarUrl":null,"iconId":1,"colorId":null,"nameEffect":null,"titleId":1,"backgroundId":null,"accentColorId":null,"watchOnly":false,"isReady":true,"isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"emoji":null,"isBot":false,"isGuest":true}]}}
"""#

    /// `game-over`
    static let gameOver = #"""
{"type":"game-over","payload":{"scores":[{"id":"guest-1791031285893-probe","nickname":"ProtokollProbe","score":200,"lives":3,"isEliminated":false,"correctAnswers":3,"bestStreak":0,"isConnected":true,"lastPointsBreakdown":{"total":50,"breakdown":{"title":{"points":0,"text":"Title ✗"},"artist":{"points":50,"text":"Artist ✓"},"year":{"points":0,"text":"Year ✗"}},"ownAnswer":{"title":"You Are So Beautiful","artist":"Odiseo","year":"2010"}},"avatarUrl":null,"iconId":1,"colorId":null,"nameEffect":null,"titleId":1,"backgroundId":null,"accentColorId":null,"watchOnly":false,"isReady":true,"isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"emoji":null,"isBot":false,"isGuest":true,"rewards":{"xp":28,"spots":55,"goldSpots":0}}],"songs":[{"title":"You Are So Beautiful","artist":"Zucchero","year":1992,"albumArt":"https://i.scdn.co/image/ab67616d0000b27304e57d181ff062f8339d6c71"},{"title":"Api","artist":"Odiseo","year":2011,"albumArt":"https://i.scdn.co/image/ab67616d0000b273ce6d0eef0c1ce77e5f95bbbc"}]}}
"""#

}
