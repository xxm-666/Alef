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

    var completedRecordingURL: URL? {
        state != .recording && hasRecording ? recordingURL : nil
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
        state = .idle
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

struct StudySpeechRhythm {
    private static let windowDuration = 0.02
    private static let minimumSpeechWindows = 6
    private static let minimumPauseWindows = 7

    private let windows: [Bool]
    private let spectra: [[Float]]

    private var speechDuration: Double {
        Double(windows.filter { $0 }.count) * Self.windowDuration
    }

    private var pauseCount: Int { Self.runs(in: windows, matching: false).count }

    var duration: Double { Double(windows.count) * Self.windowDuration }

    init?(levels: [Float], spectra: [[Float]] = []) {
        let orderedLevels = levels.sorted()
        guard orderedLevels.count >= Self.minimumSpeechWindows else { return nil }
        // Use a sustained loud level so long silence or a single click cannot set the threshold.
        let loudLevel = orderedLevels[orderedLevels.count - Self.minimumSpeechWindows]
        guard loudLevel >= 0.004 else { return nil }
        let threshold = max(0.002, loudLevel * 0.10)
        let active = levels.map { $0 >= threshold }

        // Trim leading and trailing silence. Ignore isolated transients when finding the boundaries.
        let speech = Self.runs(in: active, matching: true).filter { $0.count >= 3 }
        guard let first = speech.first, let last = speech.last,
              speech.reduce(0, { $0 + $1.count }) >= Self.minimumSpeechWindows else { return nil }
        let trimmed = Array(active[first.lowerBound..<last.upperBound])
        var normalized = Array(repeating: true, count: trimmed.count)
        for pause in Self.runs(in: trimmed, matching: false) where pause.count >= Self.minimumPauseWindows {
            for index in pause { normalized[index] = false }
        }
        windows = normalized
        if spectra.count == levels.count {
            self.spectra = (first.lowerBound..<last.upperBound).compactMap { index in
                active[index] && !spectra[index].isEmpty ? spectra[index] : nil
            }
        } else {
            self.spectra = []
        }
    }

    static func read(_ url: URL) throws -> Self? {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let fileLength = file.length
        guard sampleRate >= 8_000, fileLength > 0, Double(fileLength) / sampleRate <= 60,
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount((sampleRate * windowDuration).rounded())) else {
            return nil
        }
        let frequencies: [[Double]] = [
            [250, 350, 450], [550, 680, 810], [950, 1_120, 1_300],
            [1_500, 1_720, 1_940], [2_200, 2_450, 2_700], [3_000, 3_300, 3_650]
        ]
        let coefficients = frequencies.map { band in
            band.map { Float(2 * cos(2 * Double.pi * $0 / sampleRate)) }
        }
        let windowLength = Int(buffer.frameCapacity)
        let taper = (0..<windowLength).map { index in
            Float(0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(windowLength - 1)))
        }
        var tapered = Array(repeating: Float.zero, count: windowLength)
        var levels: [Float] = []
        var spectra: [[Float]] = []
        while file.framePosition < fileLength {
            try Task.checkCancellation()
            try file.read(into: buffer)
            let frames = Int(buffer.frameLength)
            let channels = Int(format.channelCount)
            guard frames > 0, channels > 0, let samples = buffer.floatChannelData else { break }
            var energy: Float = 0
            for frame in 0..<frames {
                var mono: Float = 0
                for channel in 0..<channels { mono += samples[channel][frame] }
                mono /= Float(channels)
                energy += mono * mono
                tapered[frame] = mono * taper[frame]
            }
            let rms = sqrt(energy / Float(frames))
            levels.append(rms)
            spectra.append(rms >= 0.002 ? bandProfile(tapered.prefix(frames), coefficients: coefficients) : [])
        }
        return Self(levels: levels, spectra: spectra)
    }

    private static func bandProfile(_ samples: ArraySlice<Float>, coefficients: [[Float]]) -> [Float] {
        // Goertzel estimates energy at representative frequencies in each broad speech band.
        let bands = coefficients.map { band in
            band.reduce(Float.zero) { energy, coefficient in
                var previous: Float = 0
                var older: Float = 0
                for sample in samples {
                    let next = sample + coefficient * previous - older
                    older = previous
                    previous = next
                }
                return energy + max(0, previous * previous + older * older - coefficient * previous * older)
            }
        }
        let total = bands.reduce(0, +)
        guard total > 0, total.isFinite else { return [] }
        return bands.map { sqrt($0 / total) }
    }

    func compare(to reference: Self) -> StudyRhythmComparison {
        let durationMatch = min(speechDuration, reference.speechDuration) / max(speechDuration, reference.speechDuration)
        let sampleCount = 100
        var mismatchedPauses = 0
        var longestExtraPause = 0
        var extraPause = 0
        for sample in 0..<sampleCount {
            let spoken = windows[sample * windows.count / sampleCount]
            let expected = reference.windows[sample * reference.windows.count / sampleCount]
            if spoken != expected { mismatchedPauses += 1 }
            extraPause = !spoken && expected ? extraPause + 1 : 0
            longestExtraPause = max(longestExtraPause, extraPause)
        }
        let pauseMatch = 1 - Double(mismatchedPauses) / Double(sampleCount)
        let score = Int((100 * (0.65 * durationMatch + 0.35 * pauseMatch)).rounded())
        let timingRatio = speechDuration / reference.speechDuration
        let feedback: String
        if pauseCount != reference.pauseCount && pauseMatch < 0.95 {
            feedback = pauseCount > reference.pauseCount
                ? "你的录音停顿更多，可以跟着原音连读。"
                : "原音停顿更多，可以跟着它的断句。"
        } else if timingRatio < 0.8 {
            feedback = "整体偏快，试着放慢一点。"
        } else if timingRatio > 1.25 {
            feedback = "整体偏慢，试着跟紧原音。"
        } else if Double(longestExtraPause) / Double(sampleCount) * duration >= 0.18 {
            feedback = "录音中有一段停顿比原音长，再听一次停顿的位置。"
        } else if pauseMatch < 0.90 {
            feedback = "停顿位置有差异，试着跟着原音的断句。"
        } else {
            feedback = "时长和停顿与原音接近。"
        }
        return StudyRhythmComparison(
            score: score, paceScore: Int((durationMatch * 100).rounded()),
            pauseScore: Int((pauseMatch * 100).rounded()),
            referenceDuration: reference.duration, recordingDuration: duration,
            referencePauseCount: reference.pauseCount, recordingPauseCount: pauseCount,
            feedback: feedback, acoustic: compareSound(to: reference)
        )
    }

    private func compareSound(to reference: Self) -> StudySoundComparison? {
        guard spectra.count >= 6, reference.spectra.count >= 6 else { return nil }
        let count = min(96, max(spectra.count, reference.spectra.count))
        let radius = max(2, count / 8)
        let columns = count + 1
        var alignment = Array(repeating: Double.infinity, count: columns * columns)
        var direction = Array(repeating: UInt8(0), count: alignment.count)
        alignment[0] = 0
        for row in 1...count {
            for column in max(1, row - radius)...min(count, row + radius) {
                let cell = row * columns + column
                let diagonal = alignment[cell - columns - 1]
                let up = alignment[cell - columns] + 0.08
                let left = alignment[cell - 1] + 0.08
                let predecessor = min(diagonal, min(up, left))
                direction[cell] = predecessor == diagonal ? 0 : (predecessor == up ? 1 : 2)
                alignment[cell] = predecessor + soundDistance(row - 1, column - 1, count: count, reference: reference)
            }
        }
        var row = count
        var column = count
        var segmentTotals = Array(repeating: 0.0, count: 3)
        var segmentCounts = Array(repeating: 0, count: 3)
        var pathSteps = 0
        while row > 0 && column > 0 {
            let segment = (column - 1) * 3 / count
            segmentTotals[segment] += soundDistance(row - 1, column - 1, count: count, reference: reference)
            segmentCounts[segment] += 1
            pathSteps += 1
            switch direction[row * columns + column] {
            case 1: row -= 1
            case 2: column -= 1
            default:
                row -= 1
                column -= 1
            }
        }
        let segments = zip(segmentTotals, segmentCounts).map { total, samples in
            Self.similarity(for: total / Double(samples))
        }
        let score = Self.similarity(for: alignment[alignment.count - 1] / Double(pathSteps))
        return StudySoundComparison(score: score, segments: segments)
    }

    private func soundDistance(_ row: Int, _ column: Int, count: Int, reference: Self) -> Double {
        let mine = spectra[row * spectra.count / count]
        let other = reference.spectra[column * reference.spectra.count / count]
        let overlap = zip(mine, other).reduce(Float.zero) { $0 + $1.0 * $1.1 }
        return sqrt(max(0, 1 - Double(overlap)))
    }

    private static func similarity(for distance: Double) -> Int {
        Int((100 * max(0, 1 - distance)).rounded())
    }

    private static func runs(in windows: [Bool], matching value: Bool) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start: Int?
        for (index, active) in windows.enumerated() {
            if active == value {
                if start == nil { start = index }
            } else if let lowerBound = start {
                ranges.append(lowerBound..<index)
                start = nil
            }
        }
        if let start { ranges.append(start..<windows.count) }
        return ranges
    }
}

struct StudySoundComparison: Sendable {
    let score: Int
    let segments: [Int]
}

struct StudyRhythmComparison: Sendable {
    let score: Int
    let paceScore: Int
    let pauseScore: Int
    let referenceDuration: Double
    let recordingDuration: Double
    let referencePauseCount: Int
    let recordingPauseCount: Int
    let feedback: String
    let acoustic: StudySoundComparison?

    static func analyze(recording: URL, reference: URL?) async -> Self? {
        guard let reference else { return nil }
        let worker = Task.detached(priority: .userInitiated) { () throws -> StudyRhythmComparison? in
            guard let original = try StudySpeechRhythm.read(reference),
                  let attempt = try StudySpeechRhythm.read(recording) else { return nil }
            return attempt.compare(to: original)
        }
        return await withTaskCancellationHandler {
            try? await worker.value
        } onCancel: {
            worker.cancel()
        }
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
    @State private var comparison: (recording: URL, result: StudyRhythmComparison?)?

    private var referenceURL: URL? { audio.referenceRecordingURL(for: hebrew) }

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
                    audio.speak(hebrew, rate: referenceURL == nil ? progress.speechRate : 1,
                                bundledOnly: referenceURL != nil)
                } label: {
                    Label("原音", systemImage: "speaker.wave.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle())
                .disabled(recorder.state == .recording)

                Button {
                    audio.stop()
                    recorder.togglePlayback()
                } label: {
                    Label(recorder.state == .playing ? "停止回放" : "我的录音",
                          systemImage: recorder.state == .playing ? "stop.circle" : "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(selected: recorder.state == .playing))
                .disabled(!recorder.hasRecording || recorder.state == .recording)
            }

            Button {
                audio.stop()
                audio.playStrokeHaptic()
                Task { await recorder.toggleRecording() }
            } label: {
                Label(recorder.state == .recording ? "停止录音" : (recorder.hasRecording ? "重录" : "录音"),
                      systemImage: recorder.state == .recording ? "stop.fill" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle(selected: recorder.state == .recording))

            if let recording = recorder.completedRecordingURL {
                comparisonView(for: recording)
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
        .task(id: recorder.completedRecordingURL) {
            guard let recording = recorder.completedRecordingURL else { return }
            let result = await StudyRhythmComparison.analyze(recording: recording, reference: referenceURL)
            guard !Task.isCancelled, recorder.completedRecordingURL == recording else { return }
            comparison = (recording, result)
        }
        .onChange(of: hebrew) { _, _ in recorder.cleanup() }
        .onDisappear { recorder.cleanup() }
    }

    @ViewBuilder private func comparisonView(for recording: URL) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if comparison?.recording != recording {
                ProgressView("正在对比读音…")
            } else if let result = comparison?.result {
                Text("节奏相似度 \(result.score) / 100")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.ink)
                Text("原音 \(result.referenceDuration.formatted(.number.precision(.fractionLength(2)))) 秒 · 录音 \(result.recordingDuration.formatted(.number.precision(.fractionLength(2)))) 秒")
                Text("语速 \(result.paceScore) · 停顿 \(result.pauseScore)（原音 \(result.referencePauseCount) 次，你的录音 \(result.recordingPauseCount) 次）")
                Text(result.feedback)
                if let acoustic = result.acoustic {
                    soundComparison(acoustic)
                } else {
                    Text("有效声音片段太短，只显示节奏分。")
                }
            } else if referenceURL == nil {
                Text("此内容缺少内置原音，可手动回放对比。")
            } else {
                Text("无法估算节奏。请靠近麦克风，清楚地跟读后再试。")
            }
        }
        .font(.caption)
        .foregroundStyle(progress.theme.mutedInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func soundComparison(_ result: StudySoundComparison) -> some View {
        let names = ["开头", "中段", "结尾"]
        return VStack(alignment: .leading, spacing: 5) {
            Text("声音相似度 \(result.score) / 100")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(progress.theme.ink)
            ForEach(result.segments.indices, id: \.self) { index in
                ProgressView(value: Double(result.segments[index]), total: 100) {
                    Text(names[index])
                } currentValueLabel: {
                    Text("\(result.segments[index]) / 100")
                }
                .tint(progress.theme.learningAction)
            }
            if let weakest = result.segments.indices.min(by: { result.segments[$0] < result.segments[$1] }),
               let highest = result.segments.max(), highest - result.segments[weakest] >= 12 {
                Text("可以先重听\(names[weakest])，这里和原音的差异最明显。")
            }
            Text("声音相似度也会受嗓音、麦克风和环境噪声影响，仅供跟读参考。")
        }
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
