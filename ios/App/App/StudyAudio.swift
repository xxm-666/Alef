import AVFAudio
import SwiftUI
import UIKit

@MainActor
final class StudyAudio: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    enum Feedback: String { case correct, wrong, flip }

    // Keep delegate arguments alive until their identity is checked on the main actor.
    private struct PlaybackCallback<Object: AnyObject>: @unchecked Sendable {
        let object: Object
    }

    private let recordings: [String: String]
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var feedbackPlayer: AVAudioPlayer?
    private var utterance: AVSpeechUtterance?
    private var sessionActive = false

    @Published private(set) var playbackError: String?
    var prefersRecordings = true
    var feedbackEnabled = true
    var hapticsEnabled = true

    init(recordings: [String: String]) {
        self.recordings = recordings
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)),
                                               name: AVAudioSession.interruptionNotification, object: nil)
    }

    func speak(_ text: String, rate: Double, bundledOnly: Bool = false) {
        stopPronunciation()
        playbackError = nil
        let safeRate = min(1.5, max(0.5, rate.isFinite ? rate : 1))
        do {
            try activateSession()

            let recordingFirst = prefersRecordings || bundledOnly
            if recordingFirst, playRecording(text, rate: safeRate) { return }
            if !bundledOnly, let hebrewVoice = AVSpeechSynthesisVoice(language: "he-IL") {
                let spoken = AVSpeechUtterance(string: text)
                spoken.voice = hebrewVoice
                spoken.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate,
                    AVSpeechUtteranceDefaultSpeechRate * Float(safeRate)))
                utterance = spoken
                synthesizer.speak(spoken)
                return
            }
            if !recordingFirst, playRecording(text, rate: safeRate) { return }
            playbackError = bundledOnly
                ? "无法播放此发音的内置音频。"
                : "没有可播放的希伯来语音频。可在 iOS 的辅助功能语音设置中下载希伯来语。"
            releaseSessionIfIdle()
        } catch {
            playbackError = "暂时无法播放发音。请重试，或到「我的」查看发音设置。"
            releaseSessionIfIdle()
        }
    }

    private func playRecording(_ text: String, rate: Double) -> Bool {
        guard let asset = recordings[text.trimmingCharacters(in: .whitespacesAndNewlines)],
              let url = Bundle.main.resourceURL?.appendingPathComponent("StudyAssets", isDirectory: true)
                .appendingPathComponent(asset),
              let recording = try? AVAudioPlayer(contentsOf: url) else { return false }
        recording.enableRate = true
        recording.rate = Float(rate)
        recording.delegate = self
        guard recording.play() else { return false }
        player = recording
        return true
    }

    func playFeedback(_ kind: Feedback) {
        triggerHaptic(for: kind)
        guard feedbackEnabled, let url = Bundle.main.url(forResource: kind.rawValue, withExtension: "wav", subdirectory: "StudyAssets/audio"),
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

    func playSelectionHaptic() {
        guard hapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    func playStrokeHaptic() {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    private func triggerHaptic(for kind: Feedback) {
        guard hapticsEnabled else { return }
        switch kind {
        case .correct:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .wrong:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .flip:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

    @objc nonisolated private func interrupted(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              type == AVAudioSession.InterruptionType.began.rawValue else { return }
        DispatchQueue.main.async { self.stop() }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let completed = PlaybackCallback(object: player)
        DispatchQueue.main.async {
            if self.player === completed.object {
                self.player = nil
                if !flag { self.playbackError = "录音播放失败。" }
            } else if self.feedbackPlayer === completed.object {
                self.feedbackPlayer = nil
            }
            self.releaseSessionIfIdle()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        audioPlayerDidFinishPlaying(player, successfully: false)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let completed = PlaybackCallback(object: utterance)
        DispatchQueue.main.async {
            guard self.utterance === completed.object else { return }
            self.utterance = nil
            self.releaseSessionIfIdle()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speechSynthesizer(synthesizer, didFinish: utterance)
    }
}
