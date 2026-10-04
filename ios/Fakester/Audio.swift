import AVFoundation
import UIKit
import Combine

/// Der Vorschau-Schnipsel einer Runde.
///
/// Die Schnipsel kommen von Apple oder Deezer und sind rund 30 Sekunden lang -
/// genau das, was der Server als `previewUrl` mitschickt.
///
/// Der Fortschritt wird mitgefuehrt, weil die Abspielkarte im Browser ihn zeigt,
/// und weil sie damit etwas Nuetzliches tut: sie beweist, dass Ton kommt. Ohne
/// diesen Beweis sitzt jemand mit stummgeschaltetem Geraet vor einer Runde und
/// haelt das Spiel fuer kaputt.
final class AudioPlayer: ObservableObject {
    static let instance = AudioPlayer()

    @Published private(set) var isRunning = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var length: Double = 0

    var fraction: Double {
        guard length > 0, length.isFinite else { return 0 }
        return min(1, max(0, elapsed / length))
    }

    private var player: AVPlayer?
    private var previous: String?
    private var timeObserver: Any?

    private init() {
        // `.playback` ist hier richtig und nicht `.ambient`: in einem Musikspiel
        // ist der Ton nicht Beiwerk, sondern die Frage. Wer den Klingelton-
        // schalter umgelegt hat, soll trotzdem hoeren, was laeuft.
        // Zusammen mit UIBackgroundModes:[audio] laeuft es auch weiter, wenn
        // zwischendurch jemand eine Nachricht liest.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playPreview(_ address: String?) {
        guard let address, let url = URL(string: address) else { stop(); return }
        // Dieselbe Runde noch einmal gemeldet (Wiederverbindung) soll den Song
        // nicht von vorn anfangen lassen - die anderen sind ja weiter.
        if address == previous, player?.timeControlStatus == .playing { return }
        cleanUp()
        previous = address

        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false   // lieber sofort als sauber gepuffert
        player = p
        elapsed = 0
        length = 0
        // Viermal die Sekunde reicht fuer einen Balken und kostet fast nichts.
        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            // queue: .main - laeuft also schon auf der Hauptschlange, genau da,
            // wo @Published hingehoert.
            guard let self else { return }
            self.elapsed = t.seconds
            if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { self.length = d }
            self.isRunning = p.timeControlStatus == .playing
        }
        p.play()
        isRunning = true
    }

    /// Anhalten und weiterlaufen lassen - mehr kann der Knopf im Browser auch nicht.
    /// Absichtlich kein Zurueckspulen: der Schnipsel laeuft fuer alle gleich, und
    /// wer ihn neu starten koennte, haette mehr Zeit zum Hinhoeren als die anderen.
    func flip() {
        guard let p = player else { return }
        if p.timeControlStatus == .playing { p.pause(); isRunning = false }
        else { p.play(); isRunning = true }
    }

    func stop() {
        cleanUp()
        player = nil
        previous = nil
        isRunning = false
        elapsed = 0
        length = 0
    }

    private func cleanUp() {
        if let b = timeObserver { player?.removeTimeObserver(b); timeObserver = nil }
        player?.pause()
    }
}

/// Kurze Rueckmeldung in die Hand. Auf einer Webseite gibt es das nicht, und
/// genau solche Kleinigkeiten machen den Unterschied zwischen App und Lesezeichen.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func lock() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func correct() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func wrong() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
