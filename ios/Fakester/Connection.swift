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
final class Game: NSObject, ObservableObject {

    enum Phase: Equatable {
        case disconnected
        case connecting
        case lobby
        case loading            // Server sucht und prueft Songs
        case activeRound
        case reveal
        case end
    }

    // MARK: Zustand

    @Published private(set) var currentPhase: Phase = .disconnected
    @Published private(set) var pin: String = ""
    @Published private(set) var hostId: String?
    @Published private(set) var player: [Player] = []
    @Published private(set) var lobbySettings: LobbySettings?
    @Published private(set) var playMode: String = "quiz"

    @Published private(set) var activeRound: NewRound?
    @Published private(set) var outcome: RoundResult?
    @Published private(set) var finalStandings: FinalStandings?
    @Published private(set) var chat: [ChatLine] = []
    /// Emoji-Reaktionen, die gerade ueber den Bildschirm schweben. Jede geht
    /// nach ein paar Sekunden von selbst.
    @Published private(set) var reactions: [Reaction] = []

    @Published private(set) var loadingText: String = ""
    @Published private(set) var loadProgress: LoadingProgress?
    @Published private(set) var countdownNumber: Int?

    /// Was gerade eingetippt bzw. angetippt ist. Gehoert der App, nicht dem
    /// Server - bis es abgeschickt wird.
    @Published var answer = Answer()
    @Published private(set) var lockedIn = false

    /// Sekunden bis Rundenende, aus der Serverzeit gerechnet.
    @Published private(set) var secondsLeft: Int = 0

    @Published var notice: String?
    @Published private(set) var kick: KickNotice?

    /// Wer ich in dieser Lobby bin.
    private(set) var ownId: String = ""

    var iAmHost: Bool { !ownId.isEmpty && ownId == hostId }
    var me: Player? { player.first { $0.id.text == ownId } }

    /// Rate-Arten dieser Runde. Der Server schickt sie pro Runde mit; die
    /// Lobby-Einstellung ist nur die Vorgabe.
    var guessKinds: [String] { activeRound?.guessTypes ?? lobbySettings?.guessTypes ?? [] }

    // MARK: Innereien

    private var wsSession: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var identity: PlayerIdentity?
    /// Wartet darauf, beim naechsten Verbinden als `create-game` rauszugehen.
    /// Danach ist sie weg - ein Neuverbinden tritt der PIN bei, statt eine
    /// zweite Lobby aufzumachen.
    private var pendingCreate: [String: Any]?
    private var wantsConnection = false        // absichtlich drin? Dann neu verbinden.
    private var attempts = 0
    private var heartbeat: Timer?
    private var clock: Timer?
    private var roundEnd: Date?

    // MARK: - Tuer auf

    func join(pin newPin: String, asPlayer who: PlayerIdentity) {
        self.pin = newPin.trimmingCharacters(in: .whitespaces)
        self.identity = who
        self.ownId = who.id
        self.wantsConnection = true
        self.attempts = 0
        connect()
    }

    /// Eigenes Spiel aufmachen. Die PIN kommt mit dem ersten `lobby-update`.
    func createGame(_ setup: [String: Any], asPlayer who: PlayerIdentity) {
        self.pin = ""
        self.identity = who
        self.ownId = who.id
        self.pendingCreate = setup
        self.wantsConnection = true
        self.attempts = 0
        currentPhase = .connecting
        connect()
    }

    func leave() {
        wantsConnection = false
        pendingCreate = nil
        emit("leave-game", [:])
        tearDown()
        currentPhase = .disconnected
        pin = ""
        player = []
        activeRound = nil
        outcome = nil
        finalStandings = nil
        chat = []
        reactions = []
        // Muss mit weg, sonst steht der Hinweis beim naechsten Mal sofort
        // wieder da - er haengt an diesem Wert, nicht an einem Knopf.
        kick = nil
        AudioPlayer.instance.stop()
    }

    private func connect() {
        tearDown()
        currentPhase = .connecting

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        let s = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        wsSession = s

        guard let url = URL(string: "wss://fakester.app/fakester/ws") else { return }
        let t = s.webSocketTask(with: url)
        socket = t
        t.resume()
        receiveNext()
    }

    private func tearDown() {
        heartbeat?.invalidate(); heartbeat = nil
        clock?.invalidate(); clock = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        wsSession?.invalidateAndCancel()
        wsSession = nil
    }

    /// Nach einem Abriss neu aufbauen - mit wachsendem Abstand, aber gedeckelt.
    /// Der Server kennt zurueckkehrende Spieler und schickt beim Wiedereintritt
    /// `state-sync`, also landet man dort weiter, wo man war.
    private func retryLater() {
        guard wantsConnection else { return }
        attempts += 1
        let backoff = min(8.0, pow(1.6, Double(min(attempts, 6))))
        currentPhase = .connecting
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            guard self.wantsConnection else { return }
            self.connect()
        }
    }

    // MARK: - Senden

    private func emit(_ msgType: String, _ payloadObject: [String: Any]) {
        guard let t = socket else { return }
        let packet: [String: Any] = ["type": msgType, "payload": payloadObject]
        guard let bytes = try? JSONSerialization.data(withJSONObject: packet),
              let text = String(data: bytes, encoding: .utf8) else { return }
        t.send(.string(text)) { _ in }
    }

    private func emitRaw(_ text: String) {
        socket?.send(.string(text)) { _ in }
    }

    private func logIn() {
        guard let a = identity else { return }
        let who: [String: Any] = [
            "id": a.id, "username": a.username, "isGuest": a.isGuest,
            "is_pro": a.is_pro, "is_admin": a.is_admin,
            "equipped_icon_id": a.equipped_icon_id, "equipped_title_id": a.equipped_title_id,
            "avatar_url": a.avatar_url as Any, "equipped_emoji": a.equipped_emoji as Any
        ]
        if !a.isGuest {
            // Nur angemeldete Spieler sind fuer Freunde sichtbar.
            emit("register-online", ["userId": a.id, "username": a.username])
        }
        if var latest = pendingCreate, pin.isEmpty {
            pendingCreate = nil
            latest["user"] = who
            emit("create-game", latest)
            return
        }
        emit("join-game", ["pin": pin, "user": who])
    }

    // MARK: Befehle aus den Ansichten

    func lockIn() {
        guard !guessKinds.isEmpty else { return }
        emit("submit-guess", ["guess": ["title": answer.title,
                                          "artist": answer.artist,
                                          "year": answer.year]])
        emit("player-ready", [:])
        lockedIn = true
    }

    /// Antwort wieder aufmachen. Der Server erlaubt das beliebig oft - es kostet
    /// von selbst etwas, weil der Schnelligkeitsbonus am Sperrzeitpunkt haengt.
    func reconsider() {
        emit("player-unready", [:])
        lockedIn = false
    }

    func startGame() {
        guard iAmHost else { return }
        emit("start-game", [:])
    }

    func returnToLobby() {
        emit("return-to-lobby", [:])
    }

    func sendChat(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return }
        // ⚠️ `text`, nicht `message`: mit `message` verwirft der Server die
        // Zeile still (im Mitschnitt vom 2026-10-04 nachgeprueft).
        emit("send-chat", ["text": cleaned])
    }

    /// Emoji an alle in der Lobby/Runde.
    func react(_ emoji: String) {
        emit("send-reaction", ["reaction": emoji])
    }

    // MARK: - Empfangen

    private func receiveNext() {
        socket?.receive { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .failure:
                Task { @MainActor in self.retryLater() }
            case .success(let messageText):
                Task { @MainActor in
                    switch messageText {
                    case .string(let s): self.handleMessage(Data(s.utf8))
                    case .data(let d):   self.handleMessage(d)
                    @unknown default:    break
                    }
                    self.receiveNext()
                }
            }
        }
    }

    private func handleMessage(_ bytes: Data) {
        let dek = JSONDecoder()
        guard let header = try? dek.decode(TypeOnly.self, from: bytes) else { return }

        func parse<T: Decodable>(_ t: T.Type) -> T? {
            (try? dek.decode(Envelope<T>.self, from: bytes))?.payload
        }

        switch header.type {
        case "pong":
            break

        case "lobby-update":
            guard let p = parse(LobbyUpdate.self) else { return }
            player = p.players
            hostId = p.hostId?.text
            lobbySettings = p.settings ?? lobbySettings
            if let m = p.gameMode { playMode = m }
            if !p.pin.isEmpty { pin = p.pin }
            // ⚠️ Ein lobby-update kommt AUCH mitten in der Runde - so sehen alle,
            // wer schon gesperrt hat. Wer das als "du bist jetzt in der Lobby"
            // liest, fliegt aus der laufenden Runde. Deshalb entscheidet
            // gameState, nicht der Nachrichtentyp.
            if p.gameState == "LOBBY" && currentPhase != .end { currentPhase = .lobby }
            // Der Server kann die Sperre aufheben (neue Runde, Rueckkehr) -
            // dann soll der Knopf hier auch wieder aufgehen.
            if let myEntry = p.players.first(where: { $0.id.text == ownId }) {
                lockedIn = myEntry.isReady
            }

        case "state-sync":
            guard let p = parse(StateSync.self) else { return }
            player = p.scores
            if let m = p.gameMode { playMode = m }
            switch p.gameState {
            case "PLAYING":  if activeRound != nil { currentPhase = .activeRound }
            case "FINISHED": currentPhase = .end
            default:         currentPhase = .lobby
            }

        case "game-starting":
            loadingText = parse(StartMessage.self)?.message ?? "Loading songs…"
            loadProgress = nil
            currentPhase = .loading

        case "loading-progress":
            loadProgress = parse(LoadingProgress.self)
            currentPhase = .loading

        case "game-start-failed":
            notice = parse(ToastMessage.self)?.message ?? "The game couldn't start."
            currentPhase = .lobby

        case "countdown":
            countdownNumber = parse(CountdownTick.self)?.number
            currentPhase = .loading

        case "new-round":
            guard let p = parse(NewRound.self) else { return }
            activeRound = p
            outcome = nil
            countdownNumber = nil
            answer = Answer()
            lockedIn = false
            currentPhase = .activeRound
            startClock(roundSeconds: lobbySettings?.guessTime ?? 30, graceMs: p.startDelayMs)
            AudioPlayer.instance.playPreview(p.previewUrl)

        case "round-result":
            guard let p = parse(RoundResult.self) else { return }
            outcome = p
            player = p.scores
            currentPhase = .reveal
            clock?.invalidate()
            secondsLeft = 0
            AudioPlayer.instance.stop()

        case "game-over":
            guard let p = parse(FinalStandings.self) else { return }
            finalStandings = p
            player = p.scores
            currentPhase = .end
            AudioPlayer.instance.stop()

        case "chat-message":
            if let z = parse(ChatLine.self) {
                chat.append(z)
                if chat.count > 80 { chat.removeFirst(chat.count - 80) }
            }

        case "player-reacted":
            guard let r = parse(Reaction.self), !r.reaction.isEmpty else { return }
            reactions.append(r)
            if reactions.count > 12 { reactions.removeFirst(reactions.count - 12) }
            let goneId: UUID = r.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
                self?.reactions.removeAll { $0.id == goneId }
            }

        case "toast":
            guard let h = parse(ToastMessage.self) else { return }
            if !h.message.isEmpty { notice = h.message }
            // Ein Fehler, bevor es ueberhaupt eine PIN gibt, heisst: das
            // Erstellen ist gescheitert. Sonst haengt man ewig bei "Verbinde…".
            if h.isError && pin.isEmpty && currentPhase == .connecting {
                wantsConnection = false
                tearDown()
                currentPhase = .disconnected
            }

        case "kicked":
            kick = parse(KickNotice.self)
            wantsConnection = false
            tearDown()
            currentPhase = .disconnected

        case "lobby-closed":
            notice = "This lobby no longer exists."
            wantsConnection = false
            tearDown()
            currentPhase = .disconnected

        case "host-changed":
            // Die Spielerliste kommt gleich als lobby-update hinterher; hier
            // zaehlt nur, dass der Start-Knopf sofort richtig steht.
            if let p = parse(LobbyUpdate.self) { hostId = p.hostId?.text }

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
    private func startClock(roundSeconds: Int, graceMs: Int) {
        clock?.invalidate()
        let end = Date().addingTimeInterval(Double(graceMs) / 1000 + Double(roundSeconds))
        roundEnd = end
        secondsLeft = roundSeconds
        clock = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self, let end = self.roundEnd else { t.invalidate(); return }
                let remaining = max(0, end.timeIntervalSinceNow)
                self.secondsLeft = Int(remaining.rounded(.up))
                if remaining <= 0 { t.invalidate() }
            }
        }
    }
}

// MARK: - Verbindungsereignisse

extension Game: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                               didOpenWithProtocol subprotocol: String?) {
        Task { @MainActor in
            self.attempts = 0
            self.logIn()
            self.startHeartbeat()
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                               didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                               reason: Data?) {
        Task { @MainActor in
            // 4003 ist der Bann. Da hilft kein neuer Versuch.
            if closeCode.rawValue == 4003 { self.wantsConnection = false; return }
            self.retryLater()
        }
    }

    /// Ein Mobilfunknetz raeumt stille Verbindungen weg, ohne jemanden zu
    /// benachrichtigen - fuer die App sieht das aus wie eine offene Leitung,
    /// auf der nie wieder etwas passiert. Der Server antwortet auf dieses
    /// Klopfen mit `pong`.
    private func startHeartbeat() {
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.emitRaw("{\"type\":\"ping\"}") }
        }
    }
}

#if DEBUG
extension Game {
    /// Nur fuer die Bildschirmfotos im CI (`-vorschau`, siehe Vorschau.swift):
    /// spielt mitgeschnittene Server-Nachrichten ab - ohne Verbindung, durch
    /// genau denselben Weg wie echte Nachrichten.
    func replay(asPlayer id: String, _ messages: [String]) {
        ownId = id
        for n in messages { handleMessage(Data(n.utf8)) }
    }
}
#endif
