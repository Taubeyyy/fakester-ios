import Foundation

// Real messages, captured on 2026-10-03 from a live game on fakester.app
// (guest lobby, two songs, multiple choice over title, artist and year).
//
// Why verbatim and not hand-made: after reading server.js the model for
// `lastPointsBreakdown` was wrong - the points breakdown has a wrapper
// `{total, breakdown, ownAnswer}` that is built in a completely different
// place in the source than the values themselves. Hand-made JSON would have
// confirmed the bug instead of exposing it. So these snippets are
// deliberately unchanged, including fields the app does not even read.

enum Capture {

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

    // Captured on 2026-10-04: a guest creates a lobby via `create-game`,
    // writes in the chat, reacts with an emoji and changes the song count.
    // This revealed that `send-chat` only accepts `text` - with `message`
    // (how the app sent it until then) the server silently drops the line.

    /// `player-reacted`
    static let playerReacted = #"""
{"type":"player-reacted","payload":{"playerId":"guest-1791128959532-abcd1234","nickname":"TestBot","iconId":1,"reaction":"😂","emoji":null}}
"""#

    /// `chat-message` from a player (not system)
    static let chatPlayer = #"""
{"type":"chat-message","payload":{"playerId":"guest-1791128959532-abcd1234","nickname":"TestBot","isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"chatColor":null,"colorId":null,"text":"hallo text","ts":1791128961909}}
"""#

    /// `GET /playlist/info?url=…`
    static let playlistInfo = #"""
{"name":"Spotify Web API Testing playlist","image":"https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da848d0ce13d55f634e290f744ba","trackCount":5,"id":"3cEYpjA9oz9GiPac4AsH4n","source":"spotify"}
"""#

    /// `GET /playlists/featured`
    static let featured = #"""
{"playlists":[{"id":2,"playlist_id":"2Jc0amXy2IvLyTofJKgiYg","playlist_name":"Featured","playlist_image":null,"sort_order":0,"is_active":true,"created_at":"2026-06-23T21:41:20.600Z","stats":null}]}
"""#

    /// `GET /leaderboard?sort=xp&limit=100` (trimmed to two entries)
    static let leaderboard = #"""
{"sort":"xp","label":"XP","players":[{"rank":1,"id":1,"username":"Taubey","avatar_url":"/fakester/avatars/u1.webp?v=1786896689820","xp":29841,"wins":32,"highscore":3896,"games_played":73,"correct_answers":636,"value":29841,"is_pro":true,"is_admin":true,"equipped_icon_id":9308,"equipped_title_id":9313,"equipped_name_effect":"9401","equipped_accent_color_id":9306},{"rank":2,"id":33,"username":"Julien7saka","avatar_url":null,"xp":2304,"wins":13,"highscore":6167,"games_played":15,"correct_answers":570,"value":2304,"is_pro":false,"is_admin":false,"equipped_icon_id":1,"equipped_title_id":1,"equipped_name_effect":null,"equipped_accent_color_id":1}]}
"""#

}
