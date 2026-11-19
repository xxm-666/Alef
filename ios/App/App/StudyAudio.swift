import AVFAudio
import SwiftUI

final class StudyAudio: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    enum Feedback: String { case correct, wrong, flip }

    private let recordings: [String: String]
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var feedbackPlayer: AVAudioPlayer?
    private var utterance: AVSpeechUtterance?
    private var sessionActive = false

    @Published private(set) var playbackError: String?

    init(recordings: [String: String]) {
        self.recordings = recordings
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)),
                                               name: AVAudioSession.interruptionNotification, object: nil)
    }

    func speak(_ text: String, fallback: String? = nil, rate: Double) {
        stopPronunciation()
        playbackError = nil
        let safeRate = min(1.5, max(0.5, rate.isFinite ? rate : 1))
        do {
            try activateSession()

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
            releaseSessionIfIdle()
        }
    }

    func playFeedback(_ kind: Feedback) {
        guard let url = Bundle.main.url(forResource: kind.rawValue, withExtension: "wav", subdirectory: "StudyAssets/audio"),
              let feedback = try? AVAudioPlayer(contentsOf: url) else { return }
        do {
            try activateSession()
            feedbackPlayer?.stop()
            feedbackPlayer = nil
            feedback.delegate = self
            if feedback.play() { feedbackPlayer = feedback }
            releaseSessionIfIdle()
        } catch {
            releaseSessionIfIdle()
        }
    }

    func stop() {
        stopPronunciation()
        feedbackPlayer?.stop()
        feedbackPlayer = nil
        releaseSessionIfIdle()
    }

    private func stopPronunciation() {
        let current = player
        player = nil
        utterance = nil
        current?.stop()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    private func activateSession() throws {
        guard !sessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, options: .mixWithOthers)
        try session.setActive(true)
        sessionActive = true
    }

    private func releaseSessionIfIdle() {
        guard sessionActive, player == nil, utterance == nil, feedbackPlayer == nil else { return }
        sessionActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func dismissError() {
        playbackError = nil
    }

    @objc private func interrupted(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              type == AVAudioSession.InterruptionType.began.rawValue else { return }
        DispatchQueue.main.async { self.stop() }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if self.player === player {
                self.player = nil
                if !flag { self.playbackError = "录音播放失败。" }
            } else if self.feedbackPlayer === player {
                self.feedbackPlayer = nil
            }
            self.releaseSessionIfIdle()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        audioPlayerDidFinishPlaying(player, successfully: false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard self.utterance === utterance else { return }
            self.utterance = nil
            self.releaseSessionIfIdle()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speechSynthesizer(synthesizer, didFinish: utterance)
    }
}
