# Fakester für iOS

Nativer Client für [fakester.app](https://fakester.app) — kein WebView-Mantel. Die App
spricht dieselbe API wie der Browser-Client: REST unter `/fakester/api` zum Anmelden und
fürs Profil, WebSocket unter `/fakester/ws` für alles im Spiel.

**Warum nativ.** Ein WebView hätte nichts gebracht, was „Zum Home-Bildschirm" nicht schon
gibt. Interessant wird eine App erst durch das, was eine Seite nicht kann: Ton, der beim
Sperrbildschirm weiterläuft, echte Haptik auf die Runde, später Widgets und Live Activities
mit dem Spielstand.

## Bauen

Kein Xcode auf dem Rechner nötig. `ios/project.yml` beschreibt das Projekt, der Mac-Runner
in `.github/workflows/ios.yml` erzeugt daraus die `.xcodeproj`, baut unsigniert und packt
eine `.ipa` für **TrollStore** (signiert nur mit `ldid` + Entitlements). Jeder Push auf
`main`, der `ios/` anfasst, legt ein Release `build-<Nummer>` an.

Vor dem Xcode-Schritt laufen die Logiktests: `ios/Shared` plus `ios/Tests/main.swift`
werden mit `swiftc` übersetzt und ausgeführt. Dort gehört alles hinein, was ohne Bildschirm
prüfbar ist — allen voran das Dekodieren der Server-Nachrichten.

## Stand

Spielbar: anmelden (Konto oder Gast), Lobby über PIN betreten, Quiz-Runde mit Multiple
Choice und Freitext, Rundenauflösung, Endstand.

Noch nicht: Lobby selbst aufmachen, Timeline / Higher-Lower / Survival / Race, Shop, Style,
Quests, Daily, Freunde, Widgets.
