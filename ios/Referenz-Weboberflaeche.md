# Wie fakester.app aussieht (Stand 2026-10-04, v1.1.0)

Aufgenommen durch Durchspielen im Handyformat (375×812), Farben per
`getComputedStyle` aus der laufenden Seite geholt. **Zweck:** Wer vom Handy aus
arbeitet, hat keinen Browser – hier steht, was man sonst nur durch Hinschauen
wüsste. Wenn sich die Webseite ändert, gilt die Seite, nicht diese Datei.

## Farben

Aus `:root` im ausgelieferten Bundle (`/var/www/fakester-beta/assets/index-*.css`,
welches gerade gilt sagt `grep -oE "assets/index-[A-Za-z0-9_-]+\.css" /var/www/fakester-beta/index.html`):

| Variable | Wert | in der App |
|---|---|---|
| `--background` | `#07070e` | `Farbe.grund` |
| `--card` | `#0f0e1c` | `Farbe.flaeche` |
| `--secondary` | `#1a1831` | `Farbe.grund4` |
| `--muted` | `#15142a` | `Farbe.grund3` |
| `--muted-foreground` | `#7877a0` | `Farbe.leise` |
| `--foreground` | `#eef` | `Farbe.schrift` |
| `--accent` | `#34d399` | `Farbe.gut` |
| `--destructive` | `#f87171` | `Farbe.schlecht` |
| `--border` | `#ffffff12` | `Farbe.linie` |
| `--radius` | `.875rem` (14 px) | Karten laufen mit 16 |
| `--acc` | zur Laufzeit, Vorgabe `#b15cff` | `Farbe.akzent` |

`--acc` ist **nicht** `--primary`. `--primary` (`#a78bfa`) ist der shadcn-Grundton;
die Akzentfarbe setzt die App auf den ausgerüsteten Gegenstand. Vorgabe ist das
kräftige Lila `#b15cff` – das ist das, was man sieht.

Schriften: **Bricolage Grotesque** für alles, **DM Mono** für PIN, Punkte und Zeiten.

## Anmelden

Alles in **einer** Karte: „Play now" (lila, breit) → Trenner „OR" → Zeile „Sign in"
mit Symbol im abgerundeten Quadrat → Umschalter „Sign in | Create account" →
Etiketten `USERNAME` / `PASSWORD` klein und gesperrt, Felder mit Symbol vorn →
„Log in". Darunter ein Hinweis mit dem Wort „create one" in Lila.

Auf „Play now" klappt oben im selben Rahmen ein Namensfeld mit rundem Pfeilknopf auf.

## Startbildschirm

Passt **ohne Scrollen** auf einen Bildschirm. Von oben:

1. Profilchip links (rundes Symbol mit goldener Stufenperle, Name), Spots-Pille rechts (♪ + Zahl).
2. Kleine wippende Equalizer-Balken, darunter `FAKE` weiß + `STER` im Lila-Verlauf, sehr groß.
3. **„Create Game" breit neben schmalem „Join"** – nebeneinander, nicht untereinander.
4. `● 0 online`.
5. **Daily**-Karte über die ganze Breite: Symbol im lila Quadrat, Titel, Unterzeile, Pfeil rechts.
6. **Vier bunte Kacheln** nebeneinander, jede mit eigener Farbe: Shop (lila), Path (gold),
   Quests (grün), Style (rosa). Symbol im farbigen Kreis, Wort darunter, Rahmen im selben Ton.
7. **Vier ruhige Knöpfe** als 2×2: Board, Friends, Playlists, Settings – Glas, Symbol + Wort.
8. **Stufenkarte**: großer lila Kreis mit der Zahl, `LEVEL n`, rechts „50 XP to 2",
   Fortschrittsbalken, darunter drei Zahlen `GAMES` / `WINS` / `BEST`.
9. Fuß: Logout, Discord (blau), Versionsnummer.

Stufe = `max(1, floor((25 + sqrt(625 + 100·xp)) / 50))`, nachgebaut in `Api.Stufe`.
`games_played`, `wins`, `highscore` kommen aus `/profile`.

## Lobby

Kopf: runder Zurück-Knopf, „Lobby" groß, Einstellungs-Symbol rechts.

1. **PIN-Karte**: `# GAME PIN`, die Stellen als einzelne Kästchen – **zugedeckt**,
   bis man „Reveal" drückt. Daneben „Copy" und „Invite" (lila).
2. **Pillen-Reihe**: Playlist (mit grünem Spotify-Punkt), ♪ Anzahl, ⏱ Zeit, ? Modus.
3. `PLAYERS (n)` und darunter ein **4-spaltiges Raster**. Der Gastgeber lila umrandet
   mit goldenem „Host"-Abzeichen und „⭐ CREATOR"; freie Plätze als blasse Kacheln
   „OPEN SLOT / Invite…".
4. **Chat-Karte** `((•)) LOBBY` mit Systemzeilen und **Eingabefeld + rundem Sendeknopf**.
5. Unten „Invite players" + „Settings", darunter „▶ Start Game" lila über die ganze Breite.

## Runde

1. Kopf: `ROUND 1 / 5`, Uhr-Pille `⏱ 27s`, rechts rotes „× Leave".
2. **Dünner Fortschrittsstrich** direkt darunter, läuft leer. **Unter 10 Sekunden orange.**
3. Eigener Chip links: Symbol, Name, Punktzahl.
4. **Cover** als abgerundetes Quadrat (~180 pt) mit dunklem Streifen unten:
   wippende Balken + `NOW PLAYING`.
5. **Abspielkarte**: „Now playing" lila links, `0:02 / 0:29` rechts, runder lila
   Pause-Knopf, Fortschrittsbalken, darunter Lautstärke mit Prozentzahl.
6. Je Rateart ein Etikett (`TITLE`, `ARTIST`, `YEAR`) und darunter die Antworten im
   **2-Spalten-Raster**. Gewählt = lila gefüllt mit Rand und Schein; das Etikett
   bekommt dann ein `✓`.
7. Unten ein Knopf, der sagt **was noch fehlt** („Pick year", „Pick title, artist & year")
   und erst bei vollständiger Antwort zu „✓ Lock in answer" wird.
8. Ganz unten eine schwebende Leiste mit fünf runden Emoji-Knöpfen (Reaktionen).

## Auflösung

Schiebt sich als Blatt über die abgeblendete Runde, dauert nur `revealTime` (5 s).

1. Kopf `ROUND 2 / 5 · Results` + „× Leave".
2. **NOW REVEALED**: Cover mit lila Jahres-Pille am unteren Rand, Etikett, Titel groß, Interpret.
3. **Eigene Zeile**: goldener Platz-Kreis, Name, `+0` und Gesamtpunktzahl rechts.
   Darunter Chips `Title ×` `Artist ×` `Year ×`, dann je eine Zeile:
   `×  Title  — NO ANSWER →  Api` – die eigene Antwort durchgestrichen, die richtige grün.
4. Fuß: Equalizer + „Next round coming up…".

## Endstand

1. `GAME OVER` riesig im Lila-Verlauf, darunter „You finished **#1** with **100 pts**".
2. Sieger-Zeile gold umrandet: goldener Kreis mit Platz, Symbol, Name lila, Punkte gold.
3. **WHAT WAS PLAYING**: nummerierte Liste mit Cover-Miniatur, Titel + Interpret, Jahr rechts.
4. Bei Gästen eine bernsteinfarbene Karte „diese Runde wurde nicht gespeichert"
   mit Knopf „Create an account".
5. Drei Belohnungskacheln: `+28 XP` (lila Stern), `+35 SPOTS` (grüne Note), `+5 GS` (goldener Pokal).
6. Knöpfe untereinander: „⚡ Rematch — same crew" (lila), „Back to lobby", „Share result", „Main menu".

## Was es im Browser gibt und in der App nicht

Timeline, Higher/Lower, Survival, Race, Shop, Path, Quests, Style, Friends,
Playlists, Settings, Daily, mehrere Playlists gemischt beim Erstellen,
Lobby-Einstellungen nachträglich ändern, „Share result" als Bild.

Seit 2026-10-04 in der App: **Create Game** (eine Playlist, nur Quiz-Modus),
**Board** (Rangliste) und die **Emoji-Reaktionen** in der Runde.

## Nachrichten, die der Browser schickt (aus dem Bundle, 2026-10-04)

`create-game {…Einstellungen, isPublic, user}`, `join-game {pin, user}`, `start-game`,
`leave-game`, `submit-guess {guess}`, `submit-timeline-guess {guess:{position}}`,
`submit-hl-guess {direction}`, `player-ready`, `player-unready`, `return-to-lobby`,
`send-chat {text}` (**nicht** `message` – das verwirft der Server still),
`update-lobby-settings {…}`, `invite-friend {friendId, friendName}`,
`suggest-playlist {url}`, `answer-suggestion {…, accept}`, `kick-player {targetId}`,
`send-reaction {reaction}` → alle bekommen `player-reacted {playerId, nickname, reaction}`.

REST (alles unter `/fakester`): `/playlists/featured`, `/playlist/info?url=`,
`/playlist/test?url=` (Zeilen-JSON, gestreamt), `/leaderboard?sort=xp|wins|highscore|games|correct&limit=100`,
`/daily`, `/daily/start`, `/daily/finish`, `/daily-checkin`, `/quests`, `/quests/claim`,
`/shop/buy`, `/profile/equip`, `/friends`, `/friends/request`, `/friends/respond`,
`/playlists/saved`, `/stats`, `/stats/live`. Der Gegenstandskatalog liegt unter `/catalog.json`.
