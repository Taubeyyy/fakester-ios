import AVFoundation
import UIKit

/// Der Vorschau-Schnipsel einer Runde.
///
/// Die Schnipsel kommen von Apple oder Deezer und sind rund 30 Sekunden lang -
/// genau das, was der Server als `previewUrl` mitschickt.
@MainActor
final class Ton {
    static let gemeinsam = Ton()

    private var spieler: AVPlayer?
    private var zuletzt: String?

    private init() {
        // `.playback` ist hier richtig und nicht `.ambient`: in einem Musikspiel
        // ist der Ton nicht Beiwerk, sondern die Frage. Wer den Klingelton-
        // schalter umgelegt hat, soll trotzdem hoeren, was laeuft - sonst sitzt
        // er vor einer stummen Runde und weiss nicht, warum.
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
        zuletzt = adresse

        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false   // lieber sofort als sauber gepuffert
        spieler = p
        p.play()
    }

    func stoppen() {
        spieler?.pause()
        spieler = nil
        zuletzt = nil
    }

    var laeuft: Bool { spieler?.timeControlStatus == .playing }
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
