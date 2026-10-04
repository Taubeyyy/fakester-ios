import AVFoundation
import UIKit
import Combine

/// The preview clip of a round.
///
/// The clips come from Apple or Deezer and are about 30 seconds long -
/// exactly what the server sends as `previewUrl`.
///
/// Progress is tracked because the player card in the browser shows it, and
/// because that does something useful: it proves that sound is playing. Without
/// that proof, someone with a muted device sits through a round and thinks the
/// game is broken.
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
        // `.playback` is right here, not `.ambient`: in a music game the sound
        // isn't decoration, it is the question. Someone who flipped the ring/
        // silent switch should still hear what is playing.
        // Together with UIBackgroundModes:[audio] it also keeps playing while
        // someone reads a message in between.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playPreview(_ address: String?) {
        guard let address, let url = URL(string: address) else { stop(); return }
        // The same round reported again (reconnect) must not restart the song
        // from the beginning - everyone else is already further along.
        if address == previous, player?.timeControlStatus == .playing { return }
        cleanUp()
        previous = address

        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false   // rather instant than cleanly buffered
        player = p
        elapsed = 0
        length = 0
        // Four times a second is enough for a progress bar and costs almost nothing.
        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            // queue: .main - so this already runs on the main queue, exactly
            // where @Published belongs.
            guard let self else { return }
            self.elapsed = t.seconds
            if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { self.length = d }
            self.isRunning = p.timeControlStatus == .playing
        }
        p.play()
        isRunning = true
    }

    /// Pause and resume - the button in the browser can't do more either.
    /// Deliberately no rewinding: the clip runs the same for everyone, and whoever
    /// could restart it would get more listening time than the others.
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

/// Short haptic feedback in the hand. A website doesn't have this, and exactly such
/// small touches make the difference between an app and a bookmark.
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
