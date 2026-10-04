#if DEBUG
import SwiftUI

/// Vorschau-Modus fuer die Bildschirmfotos im CI (`.github/workflows/screens.yml`):
/// Startargument `-vorschau <szene>`. Gibt es nur in Debug-Builds - der
/// Release-Build fuer die .ipa enthaelt nichts davon.
///
/// Die Nachrichten sind ein echter Mitschnitt (fakester.app, 2026-10-04, Gast
/// erstellt eine private Lobby mit "Featured", 5 Songs). Sie laufen durch
/// `Spiel.verarbeiten`, also genau den Weg echter Nachrichten - die Fotos
/// zeigen die App so, wie sie im Spiel aussieht.
enum Vorschau {
    static var szene: String? {
        let a: [String] = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-vorschau"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    @MainActor
    static func abspielen(_ spiel: Spiel) {
        guard let s = szene else { return }
        let lobby: [String] = [Mitschnitt.lobby, Mitschnitt.chat]
        let runde: [String] = lobby + [Mitschnitt.runde]
        let aufloesung: [String] = runde + [Mitschnitt.lobbyImSpiel, Mitschnitt.ergebnis]
        switch s {
        case "lobby":
            spiel.vorfuehren(als: Mitschnitt.ich, lobby)
        case "runde":
            spiel.vorfuehren(als: Mitschnitt.ich, runde)
        case "gewaehlt", "eingeloggt":
            spiel.vorfuehren(als: Mitschnitt.ich, runde)
            spiel.antwort = Mitschnitt.antwort
            if s == "eingeloggt" { spiel.bereitMelden() }
        case "aufloesung":
            spiel.vorfuehren(als: Mitschnitt.ich, aufloesung)
        case "ende":
            spiel.vorfuehren(als: Mitschnitt.ich, aufloesung + [Mitschnitt.ende])
        default:
            break
        }
    }

    private enum Mitschnitt {
        static let ich: String = "guest-1791131740573-ope1d"
        static let antwort: Antwort = Antwort(title: "Scared to Be Lonely", artist: "Meghan Trainor", year: "1979")
        static let lobby: String = #"{"type":"lobby-update","payload":{"pin":"2684","hostId":"guest-1791131740573-ope1d","banner":"none","gameState":"LOBBY","players":[{"id":"guest-1791131740573-ope1d","nickname":"Gast9694","score":0,"lives":3,"isEliminated":false,"correctAnswers":0,"bestStreak":0,"isConnected":true,"lastPointsBreakdown":null,"avatarUrl":null,"iconId":1,"colorId":null,"nameEffect":null,"titleId":1,"backgroundId":null,"accentColorId":1,"watchOnly":false,"isReady":false,"isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"emoji":null,"isBot":false,"isGuest":true}],"gameMode":"quiz","isPublic":false,"lobbyLang":null,"lobbyGenre":null,"settings":{"songCount":5,"guessTime":20,"answerType":"multiple","lives":3,"gameType":"points","survivalType":"lives","raceTarget":1000,"guessTypes":["title","artist","year"],"playlistName":"Featured","playlistId":"2Jc0amXy2IvLyTofJKgiYg","showCover":true,"boxMode":false,"hostPlays":true,"sneakyMode":false,"revealTime":5,"speedBonus":true,"streakBonus":true,"playlists":[{"id":"2Jc0amXy2IvLyTofJKgiYg","source":"spotify","name":"Featured","weight":10}]}}}"#
        static let chat: String = #"{"type":"chat-message","payload":{"system":true,"kind":"join","nickname":"Lobby","text":"Gast9694 joined","ts":1791133699173}}"#
        static let runde: String = #"{"type":"new-round","payload":{"round":2,"totalRounds":5,"previewUrl":"https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/75/b2/02/75b20289-d953-a104-c6fb-2e19c80be614/mzaf_14266218754523211131.plus.aac.p.m4a","albumArt":"https://i.scdn.co/image/ab67616d0000b27364167a22238ce39af0f4994d","mcOptions":{"title":["Scared to Be Lonely","I Was Made For Lovin' You","Teenage Dirtbag","Young, Wild & Free (feat. Bruno Mars)"],"artist":["Becky G","Meghan Trainor","KISS","Gym Class Heroes"],"year":[1977,1983,2026,1979]},"guessTypes":["title","artist","year"],"isReverse":false,"startDelayMs":1000}}"#
        static let lobbyImSpiel: String = #"{"type":"lobby-update","payload":{"pin":"2684","hostId":"guest-1791131740573-ope1d","banner":"none","gameState":"PLAYING","players":[{"id":"guest-1791131740573-ope1d","nickname":"Gast9694","score":50,"lives":3,"isEliminated":false,"correctAnswers":1,"bestStreak":0,"isConnected":true,"lastPointsBreakdown":null,"avatarUrl":null,"iconId":1,"colorId":null,"nameEffect":null,"titleId":1,"backgroundId":null,"accentColorId":1,"watchOnly":false,"isReady":true,"isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"emoji":null,"isBot":false,"isGuest":true}],"gameMode":"quiz","isPublic":false,"lobbyLang":null,"lobbyGenre":null,"settings":{"songCount":5,"guessTime":20,"answerType":"multiple","lives":3,"gameType":"points","survivalType":"lives","raceTarget":1000,"guessTypes":["title","artist","year"],"playlistName":"Featured","playlistId":"2Jc0amXy2IvLyTofJKgiYg","showCover":true,"boxMode":false,"hostPlays":true,"sneakyMode":false,"revealTime":5,"speedBonus":true,"streakBonus":true,"playlists":[{"id":"2Jc0amXy2IvLyTofJKgiYg","source":"spotify","name":"Featured","weight":10}]}}}"#
        static let ergebnis: String = #"{"type":"round-result","payload":{"correctTrack":{"spotifyId":"6S9q9mEifNdnTNlli2xSuD","title":"I Was Made For Lovin' You","artist":"KISS","year":1979,"albumArt":"https://i.scdn.co/image/ab67616d0000b27364167a22238ce39af0f4994d","popularity":61,"_srcId":"2Jc0amXy2IvLyTofJKgiYg","_srcWeight":10,"previewUrl":"https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/75/b2/02/75b20289-d953-a104-c6fb-2e19c80be614/mzaf_14266218754523211131.plus.aac.p.m4a"},"scores":[{"id":"guest-1791131740573-ope1d","nickname":"Gast9694","score":125,"lives":3,"isEliminated":false,"correctAnswers":2,"bestStreak":0,"isConnected":true,"lastPointsBreakdown":{"total":75,"breakdown":{"title":{"points":0,"text":"Title ✗"},"artist":{"points":0,"text":"Artist ✗"},"year":{"points":75,"text":"Year ✓"}},"ownAnswer":{"title":"Scared to Be Lonely","artist":"Meghan Trainor","year":"1979"}},"avatarUrl":null,"iconId":1,"colorId":null,"nameEffect":null,"titleId":1,"backgroundId":null,"accentColorId":1,"watchOnly":false,"isReady":true,"isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"emoji":null,"isBot":false,"isGuest":true}]}}"#
        static let ende: String = #"{"type":"game-over","payload":{"scores":[{"id":"guest-1791131740573-ope1d","nickname":"Gast9694","score":375,"lives":3,"isEliminated":false,"correctAnswers":5,"bestStreak":0,"isConnected":true,"lastPointsBreakdown":{"total":75,"breakdown":{"title":{"points":0,"text":"Title ✗"},"artist":{"points":0,"text":"Artist ✗"},"year":{"points":75,"text":"Year ✓"}},"ownAnswer":{"title":"YMCA","artist":"The J. Geils Band","year":"1996"}},"avatarUrl":null,"iconId":1,"colorId":null,"nameEffect":null,"titleId":1,"backgroundId":null,"accentColorId":1,"watchOnly":false,"isReady":true,"isPro":false,"isAdmin":false,"showAdminBadge":true,"showProBadge":true,"emoji":null,"isBot":false,"isGuest":true,"rewards":{"xp":32,"spots":90,"goldSpots":5}}],"songs":[{"title":"Grace Kelly","artist":"MIKA","year":2006,"albumArt":"https://i.scdn.co/image/ab67616d0000b273eb0b41d40b300163767da4b3"},{"title":"I Was Made For Lovin' You","artist":"KISS","year":1979,"albumArt":"https://i.scdn.co/image/ab67616d0000b27364167a22238ce39af0f4994d"},{"title":"I Don't Like It, I Love It (feat. Robin Thicke & Verdine White)","artist":"Flo Rida","year":2015,"albumArt":"https://i.scdn.co/image/ab67616d0000b273cad586071b413dd952caed13"},{"title":"Seven Nation Army","artist":"The White Stripes","year":2003,"albumArt":"https://i.scdn.co/image/ab67616d0000b2737028981d09d2e5833c9c78ad"},{"title":"Wannabe","artist":"Spice Girls","year":1996,"albumArt":"https://i.scdn.co/image/ab67616d0000b27363facc42e4a35eb3aa182b59"}]}}"#
    }
}
#endif
