import Foundation
import SwiftUI

/// Die Spielverbindung: eine WebSocket zu `wss://fakester.app/fakester/ws`.
///
/// Hier steckt der ganze Spielzustand. Die Ansichten lesen nur ab - was auf dem
/// Bildschirm passiert, entscheidet immer der Server, nicht die App. Das ist
/// nicht Bequemlichkeit, sondern Notwendigkeit: bei einem Spiel auf Zeit mit
/// mehreren Leuten ist jede lokale Annahme eine Gelegenheit, etwas anderes zu
/// zeigen als die anderen sehen.
@MainActor
final class Spiel: NSObject, ObservableObject {

    enum Lage: Equatable {
        case getrennt
        case verbinde
        case lobby
        case laedt            // Server sucht und prueft Songs
        case runde
        case aufloesung
        case ende
    }

    // MARK: Zustand

    @Published private(set) var lage: Lage = .getrennt
    @Published private(set) var pin: String = ""
    @Published private(set) var hostId: String?
    @Published private(set) var spieler: [Spieler] = []
    @Published private(set) var einstellungen: Einstellungen?
    @Published private(set) var spielart: String = "quiz"

    @Published private(set) var runde: NeueRunde?
    @Published private(set) var ergebnis: RundenErgebnis?
    @Published private(set) var endstand: Endstand?
    @Published private(set) var chat: [ChatZeile] = []

    @Published private(set) var ladetext: String = ""
    @Published private(set) var ladestand: LadeStand?
    @Published private(set) var zaehler: Int?

    /// Was gerade eingetippt bzw. angetippt ist. Gehoert der App, nicht dem
    /// Server - bis es abgeschickt wird.
    @Published var antwort = Antwort()
    @Published private(set) var abgegeben = false

    /// Sekunden bis Rundenende, aus der Serverzeit gerechnet.
    @Published private(set) var restzeit: Int = 0

    @Published var meldung: String?
    @Published private(set) var rauswurf: Rauswurf?

    /// Wer ich in dieser Lobby bin.
    private(set) var eigeneId: String = ""

    var binIchHost: Bool { !eigeneId.isEmpty && eigeneId == hostId }
    var ich: Spieler? { spieler.first { $0.id.text == eigeneId } }

    /// Rate-Arten dieser Runde. Der Server schickt sie pro Runde mit; die
    /// Lobby-Einstellung ist nur die Vorgabe.
    var rateArten: [String] { runde?.guessTypes ?? einstellungen?.guessTypes ?? [] }

    // MARK: Innereien

    private var sitzung: URLSession?
    private var draht: URLSessionWebSocketTask?
    private var ausweis: SpielerAusweis?
    private var willVerbunden = false        // absichtlich drin? Dann neu verbinden.
    private var versuche = 0
    private var klopfer: Timer?
    private var uhr: Timer?
    private var rundenEnde: Date?
    /// Schon einmal wirklich in der Lobby angekommen? Erst dann lohnt es sich,
    /// nach einem Abriss endlos neu zu verbinden - vorher heisst "kommt nicht
    /// rein" fast immer: falsche PIN oder kein Netz.
    private var warDrin = false
    private var beitrittsNummer = 0

    // MARK: - Tuer auf

    func betreten(pin neuerPin: String, als wer: SpielerAusweis) {
        self.pin = neuerPin.trimmingCharacters(in: .whitespaces)
        self.ausweis = wer
        self.eigeneId = wer.id
        self.willVerbunden = true
        self.versuche = 0
        self.warDrin = false
        verbinden()
        beitrittUeberwachen()
    }

    /// Kommt nach 12 Sekunden keine Antwort aus der Lobby, wird abgebrochen
    /// statt ewig "Verbinde…" zu zeigen.
    private func beitrittUeberwachen() {
        beitrittsNummer += 1
        let nummer = beitrittsNummer
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard nummer == self.beitrittsNummer, self.willVerbunden, !self.warDrin else { return }
            self.beitrittAbbrechen(L("Keine Antwort von der Lobby. Stimmt die PIN?",
                                     "No answer from the lobby. Is the PIN right?"))
        }
    }

    /// Zurueck auf den Startbildschirm, mit Grund.
    private func beitrittAbbrechen(_ grund: String) {
        willVerbunden = false
        beitrittsNummer += 1
        abbauen()
        lage = .getrennt
        pin = ""
        Spuerbar.falsch()
        meldung = grund
    }

    /// Die Fehler des Servers sind englisch und knapp; die haeufigen uebersetzen.
    private func beitrittsFehler(_ text: String) -> String {
        let t = text.lowercased()
        if t.contains("not found") { return L("Diese PIN gibt es nicht.", "There's no game with this PIN.") }
        if t.contains("full") { return L("Die Lobby ist voll.", "The lobby is full.") }
        if t.contains("started") || t.contains("progress") {
            return L("Das Spiel läuft schon.", "The game has already started.")
        }
        return text
    }

    func verlassen() {
        willVerbunden = false
        beitrittsNummer += 1
        schick("leave-game", [:])
        abbauen()
        lage = .getrennt
        pin = ""
        spieler = []
        runde = nil
        ergebnis = nil
        endstand = nil
        chat = []
        // Muss mit weg, sonst steht der Hinweis beim naechsten Mal sofort
        // wieder da - er haengt an diesem Wert, nicht an einem Knopf.
        rauswurf = nil
        Ton.gemeinsam.stoppen()
    }

    private func verbinden() {
        abbauen()
        lage = .verbinde

        let aufbau = URLSessionConfiguration.default
        aufbau.waitsForConnectivity = true
        let s = URLSession(configuration: aufbau, delegate: self, delegateQueue: nil)
        sitzung = s

        guard let url = URL(string: "wss://fakester.app/fakester/ws") else { return }
        let t = s.webSocketTask(with: url)
        draht = t
        t.resume()
        empfangen()
    }

    private func abbauen() {
        klopfer?.invalidate(); klopfer = nil
        uhr?.invalidate(); uhr = nil
        draht?.cancel(with: .goingAway, reason: nil)
        draht = nil
        sitzung?.invalidateAndCancel()
        sitzung = nil
    }

    /// Nach einem Abriss neu aufbauen - mit wachsendem Abstand, aber gedeckelt.
    /// Der Server kennt zurueckkehrende Spieler und schickt beim Wiedereintritt
    /// `state-sync`, also landet man dort weiter, wo man war.
    private func spaeterNochmal() {
        guard willVerbunden else { return }
        versuche += 1
        if !warDrin && versuche >= 4 {
            beitrittAbbrechen(L("Keine Verbindung zum Spiel. Bist du online?",
                                "Can't reach the game. Are you online?"))
            return
        }
        let wartezeit = min(8.0, pow(1.6, Double(min(versuche, 6))))
        lage = .verbinde
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(wartezeit * 1_000_000_000))
            guard self.willVerbunden else { return }
            self.verbinden()
        }
    }

    // MARK: - Senden

    private func schick(_ typ: String, _ nutzlast: [String: Any]) {
        guard let t = draht else { return }
        let brief: [String: Any] = ["type": typ, "payload": nutzlast]
        guard let daten = try? JSONSerialization.data(withJSONObject: brief),
              let text = String(data: daten, encoding: .utf8) else { return }
        t.send(.string(text)) { _ in }
    }

    private func schickRoh(_ text: String) {
        draht?.send(.string(text)) { _ in }
    }

    private func anmelden() {
        guard let a = ausweis else { return }
        let wer: [String: Any] = [
            "id": a.id, "username": a.username, "isGuest": a.isGuest,
            "is_pro": a.is_pro, "is_admin": a.is_admin,
            "equipped_icon_id": a.equipped_icon_id, "equipped_title_id": a.equipped_title_id,
            "avatar_url": a.avatar_url as Any, "equipped_emoji": a.equipped_emoji as Any
        ]
        if !a.isGuest {
            // Nur angemeldete Spieler sind fuer Freunde sichtbar.
            schick("register-online", ["userId": a.id, "username": a.username])
        }
        schick("join-game", ["pin": pin, "user": wer])
    }

    // MARK: Befehle aus den Ansichten

    func bereitMelden() {
        guard !rateArten.isEmpty else { return }
        schick("submit-guess", ["guess": ["title": antwort.title,
                                          "artist": antwort.artist,
                                          "year": antwort.year]])
        schick("player-ready", [:])
        abgegeben = true
    }

    /// Antwort wieder aufmachen. Der Server erlaubt das beliebig oft - es kostet
    /// von selbst etwas, weil der Schnelligkeitsbonus am Sperrzeitpunkt haengt.
    func nochmalUeberlegen() {
        schick("player-unready", [:])
        abgegeben = false
    }

    func starten() {
        guard binIchHost else { return }
        schick("start-game", [:])
    }

    func zurueckInDieLobby() {
        schick("return-to-lobby", [:])
    }

    func schreiben(_ text: String) {
        let sauber = text.trimmingCharacters(in: .whitespaces)
        guard !sauber.isEmpty else { return }
        schick("send-chat", ["message": sauber])
    }

    // MARK: - Empfangen

    private func empfangen() {
        draht?.receive { [weak self] ergebnis in
            guard let self else { return }
            switch ergebnis {
            case .failure:
                Task { @MainActor in self.spaeterNochmal() }
            case .success(let nachricht):
                Task { @MainActor in
                    switch nachricht {
                    case .string(let s): self.verarbeiten(Data(s.utf8))
                    case .data(let d):   self.verarbeiten(d)
                    @unknown default:    break
                    }
                    self.empfangen()
                }
            }
        }
    }

    private func verarbeiten(_ daten: Data) {
        let dek = JSONDecoder()
        guard let kopf = try? dek.decode(NurTyp.self, from: daten) else { return }

        func lies<T: Decodable>(_ t: T.Type) -> T? {
            (try? dek.decode(Umschlag<T>.self, from: daten))?.payload
        }

        switch kopf.type {
        case "pong":
            break

        case "lobby-update":
            guard let p = lies(LobbyUpdate.self) else { return }
            warDrin = true
            spieler = p.players
            hostId = p.hostId?.text
            einstellungen = p.settings ?? einstellungen
            if let m = p.gameMode { spielart = m }
            if !p.pin.isEmpty { pin = p.pin }
            // ⚠️ Ein lobby-update kommt AUCH mitten in der Runde - so sehen alle,
            // wer schon gesperrt hat. Wer das als "du bist jetzt in der Lobby"
            // liest, fliegt aus der laufenden Runde. Deshalb entscheidet
            // gameState, nicht der Nachrichtentyp.
            if p.gameState == "LOBBY" && lage != .ende { lage = .lobby }
            // Der Server kann die Sperre aufheben (neue Runde, Rueckkehr) -
            // dann soll der Knopf hier auch wieder aufgehen.
            if let selbst = p.players.first(where: { $0.id.text == eigeneId }) {
                abgegeben = selbst.isReady
            }

        case "state-sync":
            guard let p = lies(Zustandsabgleich.self) else { return }
            warDrin = true
            spieler = p.scores
            if let m = p.gameMode { spielart = m }
            switch p.gameState {
            case "PLAYING":  if runde != nil { lage = .runde }
            case "FINISHED": lage = .ende
            default:         lage = .lobby
            }

        case "game-starting":
            ladetext = lies(Startmeldung.self)?.message ?? L("Songs werden geladen…", "Loading songs…")
            ladestand = nil
            lage = .laedt

        case "loading-progress":
            ladestand = lies(LadeStand.self)
            lage = .laedt

        case "game-start-failed":
            meldung = lies(Hinweis.self)?.message ?? L("Das Spiel konnte nicht starten.", "The game couldn't start.")
            lage = .lobby

        case "countdown":
            zaehler = lies(Zaehler.self)?.number
            lage = .laedt

        case "new-round":
            guard let p = lies(NeueRunde.self) else { return }
            runde = p
            ergebnis = nil
            zaehler = nil
            antwort = Antwort()
            abgegeben = false
            lage = .runde
            uhrStellen(sekunden: einstellungen?.guessTime ?? 30, schonfrist: p.startDelayMs)
            Ton.gemeinsam.spielen(p.previewUrl)

        case "round-result":
            guard let p = lies(RundenErgebnis.self) else { return }
            ergebnis = p
            spieler = p.scores
            lage = .aufloesung
            uhr?.invalidate()
            restzeit = 0
            Ton.gemeinsam.stoppen()

        case "game-over":
            guard let p = lies(Endstand.self) else { return }
            endstand = p
            spieler = p.scores
            lage = .ende
            Ton.gemeinsam.stoppen()

        case "chat-message":
            if let z = lies(ChatZeile.self) {
                chat.append(z)
                if chat.count > 80 { chat.removeFirst(chat.count - 80) }
            }

        case "toast":
            guard let h = lies(Hinweis.self), !h.message.isEmpty else { return }
            // Noch nicht drin und der Server meldet einen Fehler ("Game not
            // found!") - dann wird das nichts mehr. Frueher blieb die App hier
            // fuer immer bei "Verbinde…" haengen.
            if h.isError && !warDrin && lage == .verbinde {
                beitrittAbbrechen(beitrittsFehler(h.message))
            } else {
                meldung = h.message
            }

        case "kicked":
            rauswurf = lies(Rauswurf.self)
            willVerbunden = false
            abbauen()
            lage = .getrennt

        case "lobby-closed":
            meldung = L("Die Lobby gibt es nicht mehr.", "This lobby no longer exists.")
            willVerbunden = false
            abbauen()
            lage = .getrennt

        case "host-changed":
            // Die Spielerliste kommt gleich als lobby-update hinterher; hier
            // zaehlt nur, dass der Start-Knopf sofort richtig steht.
            if let p = lies(LobbyUpdate.self) { hostId = p.hostId?.text }

        default:
            // Unbekannte Nachrichten sind kein Fehler: der Server bekommt
            // laufend neue Typen, und ein Client, der daran erstickt, ist mit
            // jedem Serverupdate kaputt.
            break
        }
    }

    // MARK: - Uhr

    /// Der Server startet die Runde erst nach einer Schonfrist und rechnet den
    /// Schnelligkeitsbonus ab da. Die Anzeige muss dasselbe tun, sonst laeuft
    /// sie der echten Runde voraus.
    private func uhrStellen(sekunden: Int, schonfrist: Int) {
        uhr?.invalidate()
        let ende = Date().addingTimeInterval(Double(schonfrist) / 1000 + Double(sekunden))
        rundenEnde = ende
        restzeit = sekunden
        uhr = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self, let ende = self.rundenEnde else { t.invalidate(); return }
                let rest = max(0, ende.timeIntervalSinceNow)
                self.restzeit = Int(rest.rounded(.up))
                if rest <= 0 { t.invalidate() }
            }
        }
    }
}

// MARK: - Verbindungsereignisse

extension Spiel: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                               didOpenWithProtocol protokoll: String?) {
        Task { @MainActor in
            self.versuche = 0
            self.anmelden()
            self.klopfenStarten()
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                               didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                               reason: Data?) {
        Task { @MainActor in
            // 4003 ist der Bann. Da hilft kein neuer Versuch.
            if closeCode.rawValue == 4003 { self.willVerbunden = false; return }
            self.spaeterNochmal()
        }
    }

    /// Ein Mobilfunknetz raeumt stille Verbindungen weg, ohne jemanden zu
    /// benachrichtigen - fuer die App sieht das aus wie eine offene Leitung,
    /// auf der nie wieder etwas passiert. Der Server antwortet auf dieses
    /// Klopfen mit `pong`.
    private func klopfenStarten() {
        klopfer?.invalidate()
        klopfer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.schickRoh("{\"type\":\"ping\"}") }
        }
    }
}
