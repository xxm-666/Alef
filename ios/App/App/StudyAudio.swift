import AVFAudio
import SwiftUI

final class StudyAudio: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private let recordings: [String: String]
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var utterance: AVSpeechUtterance?
    private var sessionActive = false

    @Published private(set) var playbackError: String?

    init(recordings: [String: String]) {
        self.recordings = recordings
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
    }

    func speak(_ text: String, fallback: String? = nil, rate: Double) {
        stop()
        playbackError = nil
        let safeRate = min(1.5, max(0.5, rate.isFinite ? rate : 1))
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
            sessionActive = true

            if let asset = recordings[text.trimmingCharacters(in: .whitespacesAndNewlines)],
               let folder = Bundle.main.resourceURL?.appendingPathComponent("StudyAssets", isDirectory: true),
               let recording = try? AVAudioPlayer(contentsOf: folder.appendingPathComponent(asset)) {
                recording.enableRate = true
                recording.rate = Float(safeRate)
                recording.delegate = self
                if recording.play() {
                    player = recording
                    return
                }
            }

            let hebrewVoice = AVSpeechSynthesisVoice(language: "he-IL")
            let spoken = AVSpeechUtterance(string: hebrewVoice == nil ? (fallback ?? text) : text)
            spoken.voice = hebrewVoice ?? AVSpeechSynthesisVoice(language: "en-US")
            spoken.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate,
                AVSpeechUtteranceDefaultSpeechRate * Float(safeRate)))
            utterance = spoken
            synthesizer.speak(spoken)
        } catch {
            playbackError = "暂时无法播放发音。"
            stop()
        }
    }

    func stop() {
        let current = player
        player = nil
        utterance = nil
        current?.stop()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        if sessionActive {
            sessionActive = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func dismissError() {
        playbackError = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard self.player === player else { return }
            if !flag { self.playbackError = "录音播放失败。" }
            self.stop()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        audioPlayerDidFinishPlaying(player, successfully: false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard self.utterance === utterance else { return }
            self.stop()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speechSynthesizer(synthesizer, didFinish: utterance)
    }
}
