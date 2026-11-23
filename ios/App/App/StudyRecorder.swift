import AVFAudio
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class StudyVoiceRecorder: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle, recording, recorded, playing
    }

    private struct CallbackBox<Object: AnyObject>: @unchecked Sendable {
        let object: Object
    }

    private(set) var state: State = .idle
    private(set) var permissionDenied = false
    private(set) var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingURL: URL?

    var hasRecording: Bool {
        guard let recordingURL else { return false }
        return FileManager.default.fileExists(atPath: recordingURL.path)
    }

    func toggleRecording() async {
        if state == .recording {
            stopRecording()
        } else {
            await startRecording()
        }
    }

    func startRecording() async {
        stopPlayback()
        errorMessage = nil

        let granted: Bool
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            granted = true
        case .denied:
            granted = false
        case .undetermined:
            granted = await AVAudioApplication.requestRecordPermission()
        @unknown default:
            granted = false
        }

        permissionDenied = !granted
        guard granted else { return }

        deleteRecordingFile()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("alef-shadow-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder.delegate = self
            guard audioRecorder.record(forDuration: 10) else {
                errorMessage = "无法开始录音，请重试。"
                releaseSession()
                return
            }
            recorder = audioRecorder
            recordingURL = url
            state = .recording
        } catch {
            errorMessage = "麦克风暂时不可用，请重试。"
            releaseSession()
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        recorder?.stop()
        recorder = nil
        state = hasRecording ? .recorded : .idle
        releaseSession()
    }

    func togglePlayback() {
        if state == .playing {
            stopPlayback()
        } else {
            playRecording()
        }
    }

    func playRecording() {
        guard state != .recording, let recordingURL, hasRecording else { return }
        errorMessage = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer.delegate = self
            guard audioPlayer.play() else {
                errorMessage = "无法播放跟读录音。"
                releaseSession()
                return
            }
            player = audioPlayer
            state = .playing
        } catch {
            errorMessage = "无法播放跟读录音。"
            releaseSession()
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        if state == .playing {
            state = hasRecording ? .recorded : .idle
            releaseSession()
        }
    }

    func pauseForReferencePlayback() {
        if state == .recording {
            stopRecording()
        } else if state == .playing {
            stopPlayback()
        }
    }

    func cleanup() {
        recorder?.stop()
        recorder = nil
        player?.stop()
        player = nil
        deleteRecordingFile()
        state = .idle
        releaseSession()
    }

    private func deleteRecordingFile() {
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    private func releaseSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let box = CallbackBox(object: recorder)
        Task { @MainActor in
            guard self.recorder === box.object else { return }
            self.recorder = nil
            if !flag {
                self.deleteRecordingFile()
                self.state = .idle
                self.errorMessage = "录音未能完整保存。"
            } else {
                self.state = self.hasRecording ? .recorded : .idle
            }
            self.releaseSession()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let box = CallbackBox(object: player)
        Task { @MainActor in
            guard self.player === box.object else { return }
            self.player = nil
            self.state = self.hasRecording ? .recorded : .idle
            if !flag { self.errorMessage = "跟读录音播放失败。" }
            self.releaseSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        audioPlayerDidFinishPlaying(player, successfully: false)
    }
}

struct ShadowingPracticeCard: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL
    let hebrew: String
    var title = "跟读对比"
    @State private var recorder = StudyVoiceRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: "mic")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.ink)
                Spacer(minLength: 0)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(recorder.state == .recording ? progress.theme.error : progress.theme.mutedInk)
            }

            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 6))
                : AnyLayout(HStackLayout(spacing: 6))
            layout {
                Button {
                    recorder.pauseForReferencePlayback()
                    audio.speak(hebrew, rate: progress.speechRate)
                } label: {
                    Label("听示范", systemImage: "speaker.wave.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle())

                Button {
                    audio.stop()
                    audio.playStrokeHaptic()
                    Task { await recorder.toggleRecording() }
                } label: {
                    Label(recorder.state == .recording ? "停止" : "录音",
                          systemImage: recorder.state == .recording ? "stop.fill" : "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(selected: recorder.state == .recording))

                Button {
                    audio.stop()
                    recorder.togglePlayback()
                } label: {
                    Label(recorder.state == .playing ? "停止" : "听自己",
                          systemImage: recorder.state == .playing ? "stop.circle" : "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(selected: recorder.state == .playing))
                .disabled(!recorder.hasRecording || recorder.state == .recording)
            }

            if recorder.permissionDenied {
                HStack(spacing: 8) {
                    Text("请在系统设置中允许使用麦克风。")
                        .font(.caption)
                        .foregroundStyle(progress.theme.error)
                    Spacer(minLength: 0)
                    Button("去设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.caption.weight(.semibold))
                }
            } else if let error = recorder.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(progress.theme.error)
            }
        }
        .padding(10)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: hebrew) { _, _ in recorder.cleanup() }
        .onDisappear { recorder.cleanup() }
    }

    private var statusText: String {
        switch recorder.state {
        case .idle: "最长 10 秒，仅本机暂存"
        case .recording: "正在录音…"
        case .recorded: "已录制，可回放对比"
        case .playing: "正在播放你的录音"
        }
    }
}
