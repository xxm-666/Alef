import AVFAudio
import Capacitor
import UIKit

@objc(AlefPronunciationPlugin)
final class AlefPronunciationPlugin: CAPPlugin, CAPBridgedPlugin, AVAudioPlayerDelegate {
    let identifier = "AlefPronunciationPlugin"
    let jsName = "AlefPronunciation"
    let pluginMethods = [
        CAPPluginMethod(name: "play", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise)
    ]

    private var player: AVAudioPlayer?
    private var playbackCall: CAPPluginCall?

    override func load() {
        super.load()
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounded(_:)),
                                               name: UIScene.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)),
                                               name: AVAudioSession.interruptionNotification, object: nil)
    }

    @objc func play(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.finishPlayback()
            guard UIApplication.shared.applicationState != .background else {
                call.resolve()
                return
            }
            guard let filename = call.getString("filename"),
                  filename.range(of: #"\Ahe_[0-9a-f]{12}\.mp3\z"#, options: .regularExpression) != nil,
                  let url = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "public/audio") else {
                call.reject("Pronunciation recording not found")
                return
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                let rate = call.getDouble("rate", 0.9)
                player.enableRate = true
                player.rate = Float(min(1.5, max(0.5, rate.isFinite ? rate : 0.9)))
                player.delegate = self

                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, options: .mixWithOthers)
                try session.setActive(true)
                self.player = player
                self.playbackCall = call
                if !player.play() {
                    self.finishPlayback(error: "Could not start pronunciation playback")
                }
            } catch {
                call.reject("Could not open pronunciation recording", nil, error)
            }
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.finishPlayback()
            call.resolve()
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard self.player === player else { return }
            self.finishPlayback(error: flag ? nil : "Pronunciation playback failed")
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            guard self.player === player else { return }
            self.finishPlayback(error: "Could not decode pronunciation recording")
        }
    }

    @objc private func backgrounded(_ notification: Notification) {
        finishPlayback()
    }

    @objc private func interrupted(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              type == AVAudioSession.InterruptionType.began.rawValue else { return }
        DispatchQueue.main.async { self.finishPlayback() }
    }

    private func finishPlayback(error: String? = nil) {
        guard let player, let call = playbackCall else { return }
        self.player = nil
        playbackCall = nil
        player.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let error {
            call.reject(error)
        } else {
            call.resolve()
        }
    }
}
