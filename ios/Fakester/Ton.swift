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
final class Ton: ObservableObject {
    static let gemeinsam = Ton()

    @Published private(set) var laeuft = false
    @Published private(set) var stelle: Double = 0
    @Published private(set) var dauer: Double = 0

    var anteil: Double {
        guard dauer > 0, dauer.isFinite else { return 0 }
        return min(1, max(0, stelle / dauer))
    }

    private var spieler: AVPlayer?
    private var zuletzt: String?
    private var beobachter: Any?

    private init() {
        // `.playback` ist hier richtig und nicht `.ambient`: in einem Musikspiel
        // ist der Ton nicht Beiwerk, sondern die Frage. Wer den Klingelton-
        // schalter umgelegt hat, soll trotzdem hoeren, was laeuft.
        // Zusammen mit UIBackgroundModes:[audio] laeuft es auch weiter, wenn
        // zwischendurch jemand eine Nachricht liest.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func spielen(_ adresse: String?) {
        guard let adresse, let url = URL(string: adresse) else { stoppen(); return }
        // Dieselbe Runde noch einmal gemeldet (Wiederverbindung) soll den Song
        // nicht von vorn anfangen lassen - die anderen sind ja weiter.
        if adresse == zuletzt, spieler?.timeControlStatus == .playing { return }
        abraeumen()
        zuletzt = adresse

        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false   // lieber sofort als sauber gepuffert
        spieler = p
        stelle = 0
        dauer = 0
        // Viermal die Sekunde reicht fuer einen Balken und kostet fast nichts.
        beobachter = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            // queue: .main - laeuft also schon auf der Hauptschlange, genau da,
            // wo @Published hingehoert.
            guard let self else { return }
            self.stelle = t.seconds
            if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { self.dauer = d }
            self.laeuft = p.timeControlStatus == .playing
        }
        p.play()
        laeuft = true
    }

    /// Anhalten und weiterlaufen lassen - mehr kann der Knopf im Browser auch nicht.
    /// Absichtlich kein Zurueckspulen: der Schnipsel laeuft fuer alle gleich, und
    /// wer ihn neu starten koennte, haette mehr Zeit zum Hinhoeren als die anderen.
    func umschalten() {
        guard let p = spieler else { return }
        if p.timeControlStatus == .playing { p.pause(); laeuft = false }
        else { p.play(); laeuft = true }
    }

    func stoppen() {
        abraeumen()
        spieler = nil
        zuletzt = nil
        laeuft = false
        stelle = 0
        dauer = 0
    }

    private func abraeumen() {
        if let b = beobachter { spieler?.removeTimeObserver(b); beobachter = nil }
        spieler?.pause()
    }
}

/// Kurze Rueckmeldung in die Hand. Auf einer Webseite gibt es das nicht, und
/// genau solche Kleinigkeiten machen den Unterschied zwischen App und Lesezeichen.
enum Spuerbar {
    static func tipp() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func sperren() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func richtig() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func falsch() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
