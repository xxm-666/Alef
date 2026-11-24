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
    @ObservationIgnored private var pendingCapture: UUID?
    private var player: AVAudioPlayer?
    private var segmentPlayback: Task<Void, Never>?
    private(set) var playingSegment: Int?
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
        guard pendingCapture == nil else { return }
        let capture = UUID()
        pendingCapture = capture
        defer {
            if pendingCapture == capture { pendingCapture = nil }
        }
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

        guard pendingCapture == capture else { return }
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
        guard state == .recording, let recorder else { return }
        // Capture currentTime before stop() resets the recorder.
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        if duration < StudySpeechRhythm.minimumCaptureDuration {
            deleteRecordingFile()
            errorMessage = StudyRecordingIssue.tooShort.message
        }
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
        segmentPlayback?.cancel()
        segmentPlayback = nil
        playingSegment = nil
        player?.stop()
        player = nil
        if state == .playing {
            state = hasRecording ? .recorded : .idle
            releaseSession()
        }
    }

    func toggleSegment(_ index: Int, segment: StudySoundSegment, referenceURL: URL) {
        let wasPlaying = playingSegment == index
        stopPlayback()
        guard !wasPlaying, let recording = completedRecordingURL else { return }
        playingSegment = index
        state = .playing
        errorMessage = nil
        segmentPlayback = Task { [weak self] in
            guard let self else { return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                try await playClip(referenceURL, range: segment.referenceRange)
                try await Task.sleep(for: .milliseconds(250))
                try await playClip(recording, range: segment.recordingRange)
            } catch {
                if !Task.isCancelled { errorMessage = "无法播放该段音频。" }
            }
            if !Task.isCancelled { stopPlayback() }
        }
    }

    private func playClip(_ url: URL, range: Range<Double>) async throws {
        try Task.checkCancellation()
        let clip = try AVAudioPlayer(contentsOf: url)
        let start = max(0, range.lowerBound)
        let end = min(clip.duration, range.upperBound)
        guard start < end else { throw CocoaError(.fileReadCorruptFile) }
        // This player is timed by segmentPlayback. Whole-recording playback uses the delegate.
        player = clip
        clip.currentTime = start
        guard clip.play() else { throw CocoaError(.fileReadUnknown) }
        try await Task.sleep(for: .seconds(end - start))
        clip.stop()
    }

    func pauseForReferencePlayback() {
        if state == .recording {
            stopRecording()
        } else if state == .playing {
            stopPlayback()
        }
    }

    func cleanup() {
        pendingCapture = nil
        if state == .recording { stopRecording() }
        stopPlayback()
        deleteRecordingFile()
        state = .idle
    }

    func interrupt() {
        pendingCapture = nil
        if state == .recording {
            stopRecording()
            if hasRecording {
                errorMessage = "录音已中断，可回放已有片段或重录。"
            }
        } else {
            stopPlayback()
        }
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
    static let minimumCaptureDuration: TimeInterval = 0.35
    private static let minimumSpeechWindows = 6
    private static let minimumRecordedSpeechWindows = 8
    private static let minimumPauseWindows = 7

    private let windows: [Bool]
    private let spectra: [[Float]]
    private let spectrumFrames: [Int]
    private let sourceFrameCount: Int
    private let lastSpeechFrame: Int
    private let noiseRatio: Float
    private let clippingRatio: Double

    private var speechDuration: Double {
        Double(windows.filter { $0 }.count) * Self.windowDuration
    }

    private var pauseCount: Int { Self.runs(in: windows, matching: false).count }

    var duration: Double { Double(windows.count) * Self.windowDuration }

    init?(levels: [Float], spectra: [[Float]] = [], clippingRatio: Double = 0, isRecording: Bool = false) {
        let minimumWindows = isRecording ? Self.minimumRecordedSpeechWindows : Self.minimumSpeechWindows
        let orderedLevels = levels.sorted()
        guard orderedLevels.count >= minimumWindows else { return nil }
        // Use a sustained loud level so long silence or a single click cannot set the threshold.
        let loudLevel = orderedLevels[orderedLevels.count - minimumWindows]
        guard loudLevel >= 0.004 else { return nil }
        let noiseFloor = orderedLevels[orderedLevels.count / 5]
        var threshold = max(0.002, loudLevel * 0.10)
        if isRecording {
            threshold = max(threshold, max(0.008, noiseFloor * 2.2))
        }
        let active = levels.map { $0 >= threshold }

        // Trim leading and trailing silence. Ignore isolated transients when finding the boundaries.
        let speech = Self.runs(in: active, matching: true).filter { $0.count >= 3 }
        guard let first = speech.first, let last = speech.last,
              speech.reduce(0, { $0 + $1.count }) >= minimumWindows else { return nil }
        let trimmed = Array(active[first.lowerBound..<last.upperBound])
        var normalized = Array(repeating: true, count: trimmed.count)
        for pause in Self.runs(in: trimmed, matching: false) where pause.count >= Self.minimumPauseWindows {
            for index in pause { normalized[index] = false }
        }
        windows = normalized
        sourceFrameCount = levels.count
        lastSpeechFrame = last.upperBound
        self.clippingRatio = clippingRatio
        // The quieter fifth of the clip is a noise proxy, only used when enough quiet frames exist.
        noiseRatio = noiseFloor / loudLevel
        let frames = spectra.count == levels.count
            ? (first.lowerBound..<last.upperBound).filter { active[$0] && !spectra[$0].isEmpty }
            : []
        spectrumFrames = frames
        self.spectra = frames.map { spectra[$0] }
    }

    static func read(_ url: URL, isRecording: Bool = false) throws -> Self? {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let fileLength = file.length
        guard sampleRate >= 8_000, fileLength >= 0 else { return nil }
        let captureDuration = Double(fileLength) / sampleRate
        if isRecording && captureDuration < minimumCaptureDuration { throw StudyRecordingIssue.tooShort }
        guard captureDuration > 0, captureDuration <= 60,
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
        var clippedSamples = 0
        var speechSamples = 0
        while file.framePosition < fileLength {
            try Task.checkCancellation()
            try file.read(into: buffer)
            let frames = Int(buffer.frameLength)
            let channels = Int(format.channelCount)
            guard frames > 0, channels > 0, let samples = buffer.floatChannelData else { break }
            var energy: Float = 0
            var clippedFrames = 0
            for frame in 0..<frames {
                var mono: Float = 0
                for channel in 0..<channels { mono += samples[channel][frame] }
                mono /= Float(channels)
                energy += mono * mono
                if abs(mono) >= 0.995 { clippedFrames += 1 }
                tapered[frame] = mono * taper[frame]
            }
            let rms = sqrt(energy / Float(frames))
            levels.append(rms)
            if rms >= 0.004 {
                clippedSamples += clippedFrames
                speechSamples += frames
            }
            spectra.append(rms >= 0.002 ? bandProfile(tapered.prefix(frames), coefficients: coefficients) : [])
        }
        return Self(levels: levels, spectra: spectra,
                    clippingRatio: Double(clippedSamples) / Double(max(1, speechSamples)),
                    isRecording: isRecording)
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

    func qualityIssue(comparedTo reference: Self) -> StudyRecordingIssue? {
        if clippingRatio >= 0.015 { return .clipped }
        if sourceFrameCount >= 490 && sourceFrameCount - lastSpeechFrame <= 4 { return .possiblyCutOff }
        if duration >= 0.8 && noiseRatio >= 0.55 && noiseRatio > reference.noiseRatio + 0.30 {
            return .noisy
        }
        if speechDuration < reference.speechDuration * 0.55 && reference.speechDuration - speechDuration >= 0.22 {
            return .possiblyCutOff
        }
        let pauseMinimum = max(0.35, reference.duration * 0.3)
        let hasTwoAttempts = Self.runs(in: windows, matching: false).contains { pause in
            guard Double(pause.count) * Self.windowDuration >= pauseMinimum else { return false }
            let before = Double(windows[..<pause.lowerBound].filter { $0 }.count) * Self.windowDuration
            let after = Double(windows[pause.upperBound...].filter { $0 }.count) * Self.windowDuration
            let expected = reference.speechDuration
            return (0.75...1.35).contains(before / expected) && (0.75...1.35).contains(after / expected)
        }
        if hasTwoAttempts { return .possibleRepeat }
        return nil
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
        var attemptBounds = Array(repeating: (start: count, end: 0), count: 3)
        var referenceBounds = attemptBounds
        var pathSteps = 0
        while row > 0 && column > 0 {
            let segment = (column - 1) * 3 / count
            segmentTotals[segment] += soundDistance(row - 1, column - 1, count: count, reference: reference)
            segmentCounts[segment] += 1
            attemptBounds[segment].start = min(attemptBounds[segment].start, row - 1)
            attemptBounds[segment].end = max(attemptBounds[segment].end, row)
            referenceBounds[segment].start = min(referenceBounds[segment].start, column - 1)
            referenceBounds[segment].end = max(referenceBounds[segment].end, column)
            pathSteps += 1
            switch direction[row * columns + column] {
            case 1: row -= 1
            case 2: column -= 1
            default:
                row -= 1
                column -= 1
            }
        }
        let segments = segmentCounts.indices.map { index in
            StudySoundSegment(
                score: Self.similarity(for: segmentTotals[index] / Double(segmentCounts[index])),
                referenceRange: reference.clipRange(for: referenceBounds[index], count: count),
                recordingRange: clipRange(for: attemptBounds[index], count: count)
            )
        }
        let score = Self.similarity(for: alignment[alignment.count - 1] / Double(pathSteps))
        return StudySoundComparison(score: score, segments: segments)
    }

    private func clipRange(for bounds: (start: Int, end: Int), count: Int) -> Range<Double> {
        let first = spectrumFrames[bounds.start * spectra.count / count]
        let last = spectrumFrames[min(spectra.count - 1, (bounds.end * spectra.count - 1) / count)]
        return (Double(first) * Self.windowDuration)..<(Double(last + 1) * Self.windowDuration)
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

struct StudySoundSegment: Sendable {
    let score: Int
    let referenceRange: Range<Double>
    let recordingRange: Range<Double>
}

struct StudySoundComparison: Sendable {
    let score: Int
    let segments: [StudySoundSegment]
}

enum StudyRecordingIssue: Error, Equatable, Sendable {
    case noReference, unreadable, tooShort, tooQuiet, clipped, noisy, possiblyCutOff, possibleRepeat

    var message: String {
        switch self {
        case .noReference: "此内容缺少可用的内置原音，仍可回放录音。"
        case .unreadable: "无法读取这次录音，请重录后再试。"
        case .tooShort: "录音太短，未评分。请读完后再停止录音。"
        case .tooQuiet: "未检测到足够的发声，未评分。请靠近麦克风重录。"
        case .clipped: "声音过响，录音可能失真。请离麦克风远一点再录。"
        case .noisy: "这段录音可能有持续背景声。请换到安静一点的地方再试。"
        case .possiblyCutOff: "这次跟读可能没有录完整。请完整读一遍，读完再停止录音。"
        case .possibleRepeat: "录音里可能有两遍跟读。重录时请只读一遍。"
        }
    }
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

    static func analyze(recording: URL, reference: URL?) async -> Result<Self, StudyRecordingIssue> {
        let worker = Task.detached(priority: .userInitiated) { () -> Result<StudyRhythmComparison, StudyRecordingIssue> in
            do {
                guard let attempt = try StudySpeechRhythm.read(recording, isRecording: true) else { return .failure(.tooQuiet) }
                guard let reference, let original = try? StudySpeechRhythm.read(reference) else {
                    return .failure(.noReference)
                }
                if let issue = attempt.qualityIssue(comparedTo: original) { return .failure(issue) }
                return .success(attempt.compare(to: original))
            } catch let issue as StudyRecordingIssue {
                return .failure(issue)
            } catch {
                return .failure(.unreadable)
            }
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

struct ShadowingPracticeCard: View {
    private struct AIRequest: Equatable {
        let id = UUID()
        let recording: URL
        let expected: String
        let provider: StudyAIProvider
        let openRouterModel: StudyOpenRouterModel
        let gateway: String
    }

    @AppStorage(StudyAIKeychain.enabledKey) private var aiEnabled = false
    @AppStorage(StudyOpenRouterModel.preferenceKey) private var openRouterModel = StudyOpenRouterModel.whisper
    @AppStorage(StudyAIKeychain.gatewayKey) private var aiGateway = ""
    @AppStorage(StudyAIKeychain.revisionKey) private var aiSettingsRevision = 0
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    let hebrew: String
    var title = "跟读对比"
    var recordingState: Binding<Bool>? = nil
    @State private var recorder = StudyVoiceRecorder()
    @State private var comparison: (recording: URL, result: Result<StudyRhythmComparison, StudyRecordingIssue>)?
    @State private var showsComparisonDetails = false

    @State private var showsAIProviders = false
    @State private var aiRequest: AIRequest?
    @State private var aiResults: [StudyAIProvider: Result<StudyAITranscript, StudyAIError>] = [:]
    @State private var configuredProviders: [StudyAIProvider] = []

    private var referenceURL: URL? { audio.referenceRecordingURL(for: hebrew) }

    private var currentComparison: Result<StudyRhythmComparison, StudyRecordingIssue>? {
        guard let recording = recorder.completedRecordingURL, comparison?.recording == recording else { return nil }
        return comparison?.result
    }

    private var shouldRetake: Bool {
        if case .failure(let issue)? = currentComparison { return issue != .noReference }
        return !recorder.hasRecording && recorder.errorMessage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "mic")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(progress.theme.ink)
            if let statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(recorder.state == .recording ? progress.theme.error : progress.theme.mutedInk)
            }

            if recorder.permissionDenied {
                microphonePermission
            } else if let error = recorder.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(progress.theme.error)
            }
            if recorder.completedRecordingURL != nil {
                comparisonSummary
            }
            playbackControls
            recordButton
            if case .success(let result)? = currentComparison {
                comparisonDetails(result)
            }
            if let recording = recorder.completedRecordingURL, aiEnabled && canRecognize(recording) {
                aiComparisonView(recording: recording)
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
        .task(id: aiRequest) {
            guard aiEnabled, let request = aiRequest, recorder.completedRecordingURL == request.recording else { return }
            do {
                let result = try await StudyAITranscription.analyze(
                    recording: request.recording, expected: request.expected,
                    provider: request.provider, openRouterModel: request.openRouterModel, gateway: request.gateway
                )
                guard !Task.isCancelled, aiRequest == request else { return }
                aiResults[request.provider] = .success(result)
                aiRequest = nil
            } catch {
                guard !Task.isCancelled, aiRequest == request else { return }
                aiResults[request.provider] = .failure(error as? StudyAIError ?? .requestFailed)
                aiRequest = nil
            }
        }
        .onChange(of: recorder.state, initial: true) { _, state in
            recordingState?.wrappedValue = state == .recording
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { recorder.interrupt() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)) { notice in
            if notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.began.rawValue {
                recorder.interrupt()
            }
        }
        .onChange(of: recorder.completedRecordingURL) { _, _ in
            showsComparisonDetails = false
            resetAIComparison()
        }
        .onChange(of: aiEnabled, initial: true) { _, _ in reloadAIConfiguration() }
        .onChange(of: aiSettingsRevision) { _, _ in reloadAIConfiguration() }
        .onChange(of: openRouterModel) { _, _ in
            if aiRequest?.provider == .openRouter { aiRequest = nil }
            aiResults.removeValue(forKey: .openRouter)
        }
        .onChange(of: hebrew) { _, _ in
            resetAIComparison()
            recorder.cleanup()
        }
        .onDisappear {
            recordingState?.wrappedValue = false
            resetAIComparison()
            recorder.cleanup()
        }
    }

    private var microphonePermission: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("请在系统设置中允许使用麦克风。")
                .font(.subheadline)
                .foregroundStyle(progress.theme.error)
            Button("打开系统设置", systemImage: "gear") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(StudyButtonStyle(learningAction: true))
        }
    }

    private var playbackControls: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
        let playingRecording = recorder.state == .playing && recorder.playingSegment == nil
        return layout {
            Button {
                recorder.pauseForReferencePlayback()
                audio.speak(hebrew, rate: referenceURL == nil ? progress.speechRate : 1,
                            bundledOnly: referenceURL != nil)
            } label: {
                Label("原音", systemImage: "speaker.wave.2").frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(recorder.state == .recording)

            if recorder.completedRecordingURL != nil {
                Button {
                    audio.stop()
                    if recorder.playingSegment != nil { recorder.stopPlayback() }
                    recorder.togglePlayback()
                } label: {
                    Label(playingRecording ? "停止回放" : "我的录音",
                          systemImage: playingRecording ? "stop.circle" : "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(selected: playingRecording))
            }
        }
    }

    private var recordButton: some View {
        let recording = recorder.state == .recording
        let retrying = recorder.hasRecording || shouldRetake
        return Button {
            audio.stop()
            Task { await recorder.toggleRecording() }
        } label: {
            Label(recording ? "停止录音" : (retrying ? "重录" : "开始录音"),
                  systemImage: recording ? "stop.fill" : "mic.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(learningAction: !recorder.permissionDenied &&
                                    (recording || !recorder.hasRecording || shouldRetake)))
    }

    private var comparisonSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch currentComparison {
            case .success(let result)?:
                Text("节奏相似度 \(result.score) / 100")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.ink)
                Text(result.feedback)
            case .failure(let issue)?:
                Text(issue == .noReference ? "暂无对比分数" : "这次暂不评分")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(issue == .noReference ? progress.theme.ink : progress.theme.error)
                Text(issue.message)
            case nil:
                ProgressView("正在对比读音…")
            }
        }
        .font(.footnote)
        .foregroundStyle(progress.theme.mutedInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func comparisonDetails(_ result: StudyRhythmComparison) -> some View {
        DisclosureGroup("查看对比详情", isExpanded: $showsComparisonDetails) {
            VStack(alignment: .leading, spacing: 5) {
                Text("原音 \(result.referenceDuration.formatted(.number.precision(.fractionLength(2)))) 秒 · 录音 \(result.recordingDuration.formatted(.number.precision(.fractionLength(2)))) 秒")
                Text("语速 \(result.paceScore) · 停顿 \(result.pauseScore)（原音 \(result.referencePauseCount) 次，你的录音 \(result.recordingPauseCount) 次）")
                if let acoustic = result.acoustic {
                    soundComparison(acoustic)
                } else {
                    Text("有效声音片段太短，只显示节奏分。")
                }
            }
            .padding(.top, 4)
        }
        .font(.footnote)
        .foregroundStyle(progress.theme.mutedInk)
        .frame(minHeight: 44)
    }

    private func soundComparison(_ result: StudySoundComparison) -> some View {
        let names = ["开头", "中段", "结尾"]
        return VStack(alignment: .leading, spacing: 5) {
            Text("声音相似度 \(result.score) / 100")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(progress.theme.ink)
            Text("点按一段，先听原音，再听你的录音。")
            ForEach(result.segments.indices, id: \.self) { index in
                let segment = result.segments[index]
                let playing = recorder.playingSegment == index
                Button {
                    guard let referenceURL else { return }
                    audio.stop()
                    recorder.toggleSegment(index, segment: segment, referenceURL: referenceURL)
                } label: {
                    HStack(spacing: 8) {
                        ProgressView(value: Double(segment.score), total: 100) {
                            Text(names[index])
                        } currentValueLabel: {
                            Text("\(segment.score) / 100")
                        }
                        Image(systemName: playing ? "stop.circle" : "play.circle")
                            .font(.title3)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tint(progress.theme.learningAction)
                .accessibilityLabel("\(playing ? "停止" : "重听")\(names[index])，\(segment.score) 分")
            }
            if let weakest = result.segments.indices.min(by: { result.segments[$0].score < result.segments[$1].score }),
               let highest = result.segments.map(\.score).max(), highest - result.segments[weakest].score >= 12 {
                Text("可以先重听\(names[weakest])，这里和原音的差异最明显。")
            }
            Text("声音相似度也会受嗓音、麦克风和环境噪声影响，仅供跟读参考。")
        }
    }

    private func reloadAIConfiguration() {
        resetAIComparison()
        configuredProviders = aiEnabled ? StudyAIProvider.allCases.filter { provider in
            (try? provider.endpoint(gateway: aiGateway)) != nil &&
                (try? StudyAIKeychain.read(for: provider)) != nil
        } : []
    }

    private func resetAIComparison() {
        showsAIProviders = false
        aiRequest = nil
        aiResults = [:]
    }

    private func canRecognize(_ recording: URL) -> Bool {
        guard let comparison, comparison.recording == recording else { return false }
        switch comparison.result {
        case .failure(.tooShort), .failure(.tooQuiet), .failure(.unreadable): return false
        default: return true
        }
    }

    private func startAIComparison(recording: URL, provider: StudyAIProvider) {
        guard aiEnabled, recorder.completedRecordingURL == recording, canRecognize(recording),
              configuredProviders.contains(provider), aiRequest == nil else { return }
        aiResults.removeValue(forKey: provider)
        aiRequest = AIRequest(recording: recording, expected: hebrew, provider: provider,
                              openRouterModel: openRouterModel, gateway: aiGateway)
    }

    private func aiComparisonView(recording: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let provider = configuredProviders.first {
                Button {
                    if configuredProviders.count == 1 {
                        startAIComparison(recording: recording, provider: provider)
                    } else {
                        showsAIProviders = true
                    }
                } label: {
                    Label("用AI识别", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle())
                .disabled(aiRequest != nil)
                .confirmationDialog("选择识别服务", isPresented: $showsAIProviders, titleVisibility: .visible) {
                    ForEach(configuredProviders) { provider in
                        Button(provider.title) { startAIComparison(recording: recording, provider: provider) }
                    }
                } message: {
                    Text("选择后将本次录音发送至该服务。")
                }
                Text("录音将发送至所选识别服务。")
            } else {
                Text("请在「我的 → AI 功能」保存识别服务的配置。")
            }

            ForEach(configuredProviders) { provider in
                if aiRequest?.provider == provider {
                    ProgressView("正在识别录音…")
                } else if let result = aiResults[provider] {
                    if configuredProviders.count > 1 {
                        Text(provider.title).fontWeight(.semibold)
                    }
                    aiTranscriptView(result)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(progress.theme.mutedInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func aiTranscriptView(_ result: Result<StudyAITranscript, StudyAIError>) -> some View {
        switch result {
        case .success(let transcript):
            Text("原句").fontWeight(.semibold)
            Text(hebrew).textSelection(.enabled)
            Text("识别结果").fontWeight(.semibold)
            Text(transcript.text).textSelection(.enabled)
            if transcript.missingWords.isEmpty && transcript.extraWords.isEmpty {
                Text("识别结果与原句一致。")
            }
            if !transcript.missingWords.isEmpty {
                Text("疑似漏读或替换：\(transcript.missingWords.joined(separator: " · "))")
            }
            if !transcript.extraWords.isEmpty {
                Text("疑似多读或替换：\(transcript.extraWords.joined(separator: " · "))")
            }
            Text("识别可能有误，请结合原音和回放判断。")
        case .failure(let error):
            Text(error.localizedDescription).foregroundStyle(progress.theme.error)
        }
    }

    private var statusText: String? {
        switch recorder.state {
        case .idle: "最长 10 秒，仅本机暂存"
        case .recording: "正在录音…"
        case .recorded: nil
        case .playing: recorder.playingSegment == nil ? "正在播放你的录音" : "正在播放分段对比"
        }
    }
}
