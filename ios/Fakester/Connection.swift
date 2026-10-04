import Foundation
import SwiftUI

/// The game connection: a WebSocket to `wss://fakester.app/fakester/ws`.
///
/// All game state lives here. The views only read it - what happens on screen
/// is always decided by the server, never by the app. That is not convenience
/// but necessity: in a timed game with several people, every local assumption
/// is a chance to show something different from what everyone else sees.
@MainActor
final class Game: NSObject, ObservableObject {

    enum Phase: Equatable {
        case disconnected
        case connecting
        case lobby
        case loading            // server is picking and checking songs
        case activeRound
        case reveal
        case end
    }

    // MARK: State

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
    /// Emoji reactions currently floating across the screen. Each one goes
    /// away by itself after a few seconds.
    @Published private(set) var reactions: [Reaction] = []

    @Published private(set) var loadingText: String = ""
    @Published private(set) var loadProgress: LoadingProgress?
    @Published private(set) var countdownNumber: Int?

    /// What is currently typed or tapped. Belongs to the app, not the
    /// server - until it is submitted.
    @Published var answer = Answer()
    @Published private(set) var lockedIn = false

    /// Seconds until the round ends, computed from server time.
    @Published private(set) var secondsLeft: Int = 0

    @Published var notice: String?
    @Published private(set) var kick: KickNotice?

    /// Who I am in this lobby.
    private(set) var ownId: String = ""

    var iAmHost: Bool { !ownId.isEmpty && ownId == hostId }
    var me: Player? { player.first { $0.id.text == ownId } }

    /// Guess types for this round. The server sends them with every round;
    /// the lobby setting is only the default.
    var guessKinds: [String] { activeRound?.guessTypes ?? lobbySettings?.guessTypes ?? [] }

    // MARK: Internals

    private var wsSession: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var identity: PlayerIdentity?
    /// Waits to go out as `create-game` on the next connect. After that it is
    /// gone - a reconnect joins the PIN instead of opening a second lobby.
    private var pendingCreate: [String: Any]?
    private var wantsConnection = false        // in on purpose? Then reconnect.
    private var attempts = 0
    /// Set by "Back to lobby" / "Rematch" on the game-over screen: the next
    /// LOBBY update is then allowed to leave that screen (see lobby-update).
    private var wantsLobby = false
    private var heartbeat: Timer?
    private var clock: Timer?
    private var roundEnd: Date?

    // MARK: - Entering

    func join(pin newPin: String, asPlayer who: PlayerIdentity) {
        self.pin = newPin.trimmingCharacters(in: .whitespaces)
        self.identity = who
        self.ownId = who.id
        self.wantsConnection = true
        self.attempts = 0
        connect()
    }

    /// Open our own game. The PIN arrives with the first `lobby-update`.
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
        wantsLobby = false
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
        // Must be cleared too, otherwise the notice reappears right away next
        // time - it is bound to this value, not to a button.
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

    /// Rebuild after a drop - with growing delay, but capped. The server
    /// recognises returning players and sends `state-sync` on rejoin, so you
    /// land right back where you were.
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

    // MARK: - Sending

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
            // Only logged-in players are visible to friends.
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

    // MARK: Commands from the views

    func lockIn() {
        guard !guessKinds.isEmpty else { return }
        emit("submit-guess", ["guess": ["title": answer.title,
                                          "artist": answer.artist,
                                          "year": answer.year]])
        emit("player-ready", [:])
        lockedIn = true
    }

    /// Reopen the answer. The server allows this any number of times - it has
    /// a built-in cost, because the speed bonus depends on the lock-in time.
    func reconsider() {
        emit("player-unready", [:])
        lockedIn = false
    }

    func startGame() {
        guard iAmHost else { return }
        emit("start-game", [:])
    }

    /// Host only: change the lobby's settings (the browser's "Lobby settings"
    /// sheet). The server answers with a lobby-update carrying the new values.
    func updateLobbySettings(_ settings: [String: Any]) {
        guard iAmHost else { return }
        emit("update-lobby-settings", settings)
    }

    /// Host only: remove a player from the lobby (`kick-player {targetId}`).
    /// IDs are numbers for accounts and text for guests - sent the same way.
    func kick(_ playerId: String) {
        guard iAmHost, playerId != ownId else { return }
        let target: Any = Int(playerId).map { $0 as Any } ?? playerId
        emit("kick-player", ["targetId": target])
    }

    func returnToLobby() {
        wantsLobby = true
        emit("return-to-lobby", [:])
    }

    func sendChat(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return }
        // ⚠️ `text`, not `message`: with `message` the server silently drops
        // the line (verified in the capture from 2026-10-04).
        emit("send-chat", ["text": cleaned])
    }

    /// Emoji to everyone in the lobby/round.
    func react(_ emoji: String) {
        emit("send-reaction", ["reaction": emoji])
    }

    // MARK: - Receiving

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
            // ⚠️ A lobby-update ALSO arrives in the middle of a round - that is
            // how everyone sees who has already locked in. Reading it as "you are
            // in the lobby now" kicks you out of the running round. So gameState
            // decides, not the message type.
            // On the game-over screen only an explicit "Back to lobby" may leave
            // it; otherwise a stray update would yank everyone off the scores.
            if p.gameState == "LOBBY" && (currentPhase != .end || wantsLobby) {
                currentPhase = .lobby
                wantsLobby = false
            }
            // The server can lift the lock (new round, return to lobby) -
            // then the button here should reopen as well.
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
            // An error before there is even a PIN means creating the game
            // failed. Otherwise you'd hang forever on "Connecting…".
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
            // The player list follows shortly as a lobby-update; all that
            // matters here is that the Start button is right immediately.
            if let p = parse(LobbyUpdate.self) { hostId = p.hostId?.text }

        default:
            // Unknown messages are not an error: the server keeps gaining new
            // types, and a client that chokes on them breaks with every
            // server update.
            break
        }
    }

    // MARK: - Clock

    /// The server only starts the round after a grace period and computes the
    /// speed bonus from then on. The display must do the same, otherwise it
    /// runs ahead of the real round.
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

// MARK: - Connection events

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
            // 4003 is the ban. No retry will help there.
            if closeCode.rawValue == 4003 { self.wantsConnection = false; return }
            self.retryLater()
        }
    }

    /// A cellular network clears out idle connections without telling anyone -
    /// to the app that looks like an open line on which nothing ever happens
    /// again. The server answers this knock with `pong`.
    private func startHeartbeat() {
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.emitRaw("{\"type\":\"ping\"}") }
        }
    }
}

#if DEBUG
extension Game {
    /// Only for the CI screenshots (`-vorschau`, see Screenshots.swift):
    /// replays captured server messages - without a connection, through
    /// exactly the same path as real messages.
    func replay(asPlayer id: String, _ messages: [String]) {
        ownId = id
        for n in messages { handleMessage(Data(n.utf8)) }
    }
}
#endif
