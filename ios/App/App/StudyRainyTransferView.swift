import SwiftUI

struct RainyTransferSession {
    enum Phase {
        case askDriver, driverReply, askTransfer, chooseStop, listen, waitHere, summary

        var actIndex: Int {
            switch self {
            case .askDriver, .driverReply: 0
            case .askTransfer, .chooseStop: 1
            case .listen, .waitHere, .summary: 2
            }
        }

        var imageName: String {
            switch self {
            case .askDriver, .driverReply, .askTransfer: "RainyTransferDriver"
            case .chooseStop: "RainyTransferMap"
            case .listen, .waitHere, .summary: "RainyTransferShelter"
            }
        }
    }

    enum Stop: String, CaseIterable, Identifiable {
        case library = "A", market = "B", square = "C"

        var id: String { rawValue }

        var landmark: String {
            switch self {
            case .library: "图书馆"
            case .market: "市场"
            case .square: "广场"
            }
        }

        var symbol: String {
            switch self {
            case .library: "books.vertical"
            case .market: "storefront"
            case .square: "square.grid.2x2"
            }
        }

        var label: String { "\(rawValue) 站 · \(landmark)旁" }
    }

    struct Choice: Identifiable {
        let id: String
        let hint: String?
    }

    static let actTitles = ["问线路", "找换乘站", "听到站广播"]
    static let announcementID = "p-dir-13"
    static let closingLineID = "p-dir-14"
    static let waitOptions = [5, 10, 15]
    static let waitMinutes = 10
    static let lineChoices: [[Choice]] = [
        [
            Choice(id: "p-dir-9", hint: nil),
            Choice(id: "p-dir-1", hint: "这句问的是火车站位置。想想怎么问这班车的目的地。"),
            Choice(id: "p-dir-8", hint: "这句问的是发车时间。先确认这班车去哪里。")
        ],
        [
            Choice(id: "p-dir-11", hint: nil),
            Choice(id: "p-dir-4", hint: "这句问远近。想问换乘地点，可以听听哪一句用 איפה 开头。"),
            Choice(id: "p-dir-8", hint: "先问在哪里换车，到站后再确认下一班的时间。")
        ]
    ]

    private(set) var phase = Phase.askDriver
    private(set) var transcript: [String] = []
    private(set) var foundStop = false
    private(set) var hasReviewedAnnouncement = false
    private(set) var hint: String?
    private(set) var recapTip: String?

    var choices: [Choice] {
        switch phase {
        case .askDriver: Self.lineChoices[0]
        case .askTransfer: Self.lineChoices[1]
        default: []
        }
    }

    mutating func chooseLine(_ id: String) -> [String] {
        guard let choice = choices.first(where: { $0.id == id }) else { return [] }
        if let hint = choice.hint {
            recordMistake(hint, recap: "再练一次问线路或换乘点。")
            return []
        }

        let isFirstAct = phase == .askDriver
        let exchange = [id, isFirstAct ? "p-dir-10" : "p-dir-12"]
        transcript.append(contentsOf: exchange)
        hint = nil
        phase = isFirstAct ? .driverReply : .chooseStop
        return exchange
    }

    mutating func askWhereToTransfer() {
        guard phase == .driverReply else { return }
        phase = .askTransfer
    }

    @discardableResult
    mutating func chooseStop(_ stop: Stop) -> Bool {
        guard phase == .chooseStop, !foundStop else { return false }
        guard stop == .market else {
            recordMistake("这是\(stop.landmark)旁的站。重听司机说的地标，留意 ליד（在……旁边）。",
                          recap: "重听 ליד השוק（市场旁边）。")
            return false
        }
        foundStop = true
        hint = nil
        return true
    }

    mutating func goToStop() {
        guard phase == .chooseStop, foundStop else { return }
        phase = .listen
    }

    mutating func reviewAnnouncement() {
        guard phase == .listen, !hasReviewedAnnouncement else { return }
        transcript.append(Self.announcementID)
        hasReviewedAnnouncement = true
    }

    @discardableResult
    mutating func chooseWait(_ minutes: Int) -> Bool {
        guard phase == .listen, hasReviewedAnnouncement, Self.waitOptions.contains(minutes) else { return false }
        guard minutes == Self.waitMinutes else {
            recordMistake("重听广播，留意 עשר，意思是「十」。", recap: "重听 עשר דקות（十分钟）。")
            return false
        }
        hint = nil
        phase = .waitHere
        return true
    }

    mutating func finish() {
        guard phase == .waitHere else { return }
        transcript.append(Self.closingLineID)
        phase = .summary
    }

    private mutating func recordMistake(_ hint: String, recap: String) {
        self.hint = hint
        recapTip = recap
    }
}

struct StudyRainyTransferView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent

    @State private var session = RainyTransferSession()
    @State private var optionIDs: [String] = []
    @State private var waitOptions = RainyTransferSession.waitOptions.shuffled()
    @State private var showNiqqud = true
    @State private var showTransliteration = true
    @State private var showTranslation = false
    @State private var showBroadcastText = false
    @State private var showTranscript = false
    @State private var showFullMap = false
    @State private var queuedAudio: [String] = []
    @State private var playingID: String?
    @State private var audioCompletion: AudioCompletion?

    private enum AudioCompletion {
        case announcement, closingLine
    }

    private var isPlayingSequence: Bool { playingID != nil }

    var body: some View {
        StudyPage {
            if session.phase == .summary {
                summaryCard
                transcriptCard
                actionButton("再练一遍", symbol: "arrow.clockwise", action: restart)
                Button("结束", action: { dismiss() })
                    .buttonStyle(StudyButtonStyle())
                    .disabled(isPlayingSequence)
            } else {
                StudyHeading(title: RainyTransferSession.actTitles[session.phase.actIndex],
                             eyebrow: "雨天换乘 · 第 \(session.phase.actIndex + 1) 幕 / \(RainyTransferSession.actTitles.count) 幕")
                if session.phase == .askDriver {
                    Text("雨刚停。你想坐公交去火车站，先问问面前的司机。")
                        .font(.subheadline)
                        .foregroundStyle(progress.theme.mutedInk)
                }
                stage
                if let hint = session.hint {
                    StudyNotice(title: "再试一次", symbol: "ear", note: hint, reminder: true)
                }
                taskCard
                supportCard
            }
        }
        .studyDetail(StudyComicScenario.rainyTransfer.navTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if session.phase != .summary {
                    Button {
                        showTranscript.toggle()
                    } label: {
                        Label("对话记录", systemImage: "text.bubble")
                    }
                }
            }
        }
        .sheet(isPresented: $showTranscript) {
            NavigationStack {
                StudyPage { transcriptCard }
                    .studyDetail("对话记录")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { showTranscript = false }
                        }
                    }
            }
        }
        .onAppear { if optionIDs.isEmpty { shuffleChoices() } }
        .onChange(of: audio.playingPronunciation) { previous, current in
            if let playingID, current == nil, previous == phrase(playingID)?.hebrew {
                if scenePhase == .active {
                    playNext()
                } else {
                    cancelAudio()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelAudio() }
        }
        .onDisappear(perform: cancelAudio)
    }

    private var stage: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    let size = geometry.size
                    ZStack {
                        Image(session.phase.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .accessibilityHidden(true)
                        switch session.phase {
                        case .driverReply:
                            stageButton("确认换乘站", symbol: "signpost.right", action: openTransferQuestion)
                                .position(at: CGPoint(x: 0.45, y: 0.36), in: size)
                        case .chooseStop:
                            mapPreview
                                .frame(width: size.width * 0.29, height: size.height * 0.32)
                                .position(at: CGPoint(x: 0.78, y: 0.56), in: size)
                        case .listen:
                            stageButton("播放广播", symbol: "speaker.wave.2", action: playAnnouncement)
                                .position(at: CGPoint(x: 0.67, y: 0.17), in: size)
                        case .waitHere:
                            Text("\(RainyTransferSession.waitMinutes) דקות")
                                .font(.system(size: min(34, size.height * 0.16), weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .position(at: CGPoint(x: 0.67, y: 0.33), in: size)
                                .accessibilityHidden(true)
                        default:
                            EmptyView()
                        }
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func stageButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(progress.theme.ink)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .disabled(isPlayingSequence)
    }

    @ViewBuilder private var taskCard: some View {
        switch session.phase {
        case .askDriver, .askTransfer:
            StudyCard {
                StudySectionTitle(session.phase == .askDriver ? "问这班车到不到火车站" : "问司机在哪里换车")
                ForEach(optionIDs, id: \.self) { id in
                    if let line = phrase(id) {
                        phraseRow(line) {
                            let exchange = session.chooseLine(id)
                            if exchange.isEmpty {
                                audio.playFeedback(.wrong)
                            } else {
                                startAudio(exchange)
                            }
                        }
                    }
                }
            }
        case .driverReply:
            StudyCard {
                dialogueLine("p-dir-10", speaker: "司机")
                actionButton("确认换乘站", symbol: "signpost.right", action: openTransferQuestion)
            }
        case .chooseStop:
            StudyCard {
                dialogueLine("p-dir-12", speaker: "司机")
                if session.foundStop {
                    StudyNotice(title: "已找到 B 站", symbol: "checkmark.circle", note: "市场旁边的换乘站")
                    actionButton("去 B 站", symbol: "figure.walk") {
                        audio.stop()
                        session.goToStop()
                    }
                } else if showFullMap {
                    StudySectionTitle("选出换乘站")
                    stopMap
                    ForEach(RainyTransferSession.Stop.allCases) { stop in
                        Button {
                            selectStop(stop)
                        } label: {
                            Label(stop.label, systemImage: stop.symbol)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(StudyButtonStyle())
                        .disabled(isPlayingSequence)
                    }
                } else {
                    actionButton("打开站点图", symbol: "map") { showFullMap = true }
                }
            }
        case .listen:
            StudyCard {
                StudySectionTitle("下一班还有多久到？")
                actionButton("播放广播", symbol: "speaker.wave.2", action: playAnnouncement)
                Button(showBroadcastText ? "收起希伯来语原文" : "查看希伯来语原文") {
                    showBroadcastText.toggle()
                    if showBroadcastText, !isPlayingSequence { session.reviewAnnouncement() }
                }
                .buttonStyle(StudyButtonStyle())
                if showBroadcastText {
                    dialogueLine(RainyTransferSession.announcementID, speaker: "站台广播", canReplay: false)
                }
                if session.hasReviewedAnnouncement {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                    layout {
                        ForEach(waitOptions, id: \.self) { minutes in
                            actionButton("\(minutes) 分钟", symbol: "clock") {
                                let correct = session.chooseWait(minutes)
                                audio.playFeedback(correct ? .correct : .wrong)
                            }
                        }
                    }
                }
            }
        case .waitHere:
            StudyCard {
                StudyNotice(title: "下一班 10 分钟后到", symbol: "checkmark.circle")
                actionButton("就在这里等", symbol: "checkmark") {
                    startAudio([RainyTransferSession.closingLineID], completion: .closingLine)
                }
            }
        case .summary:
            EmptyView()
        }
    }

    private var supportCard: some View {
        StudyCard(padding: 12, spacing: 8) {
            DisclosureGroup("语言提示") {
                Toggle("显示元音点", isOn: $showNiqqud)
                Toggle("显示转写", isOn: $showTransliteration)
                Toggle("显示中文", isOn: $showTranslation)
            }
        }
    }

    private var summaryCard: some View {
        StudyHeroCard {
            Text("换乘路线已确认").font(.title3.weight(.bold))
            Text("在市场旁的 B 站换乘，下一班 10 分钟后到。")
            Text(session.recapTip ?? "你听出了 עשר דקות（十分钟）。")
                .font(.subheadline)
        }
    }

    private var transcriptCard: some View {
        StudyCard {
            StudySectionTitle("本场对话")
            if session.transcript.isEmpty {
                Text("完成第一轮问答后，对话会显示在这里。")
                    .foregroundStyle(progress.theme.mutedInk)
            }
            ForEach(session.transcript, id: \.self) { id in
                dialogueLine(id, speaker: speaker(for: id), alwaysShowTranslation: session.phase == .summary)
            }
            if session.phase == .summary {
                actionButton("重听完整对白", symbol: "speaker.wave.2") { startAudio(session.transcript) }
            }
        }
    }

    private var mapPreview: some View {
        Button {
            showFullMap = true
        } label: {
            mapDiagram(width: 22) { stop in
                VStack(spacing: 2) {
                    Image(systemName: stop.symbol)
                    Text(stop.rawValue).bold()
                }
                .font(.caption2)
                .foregroundStyle(Color(red: 0.09, green: 0.25, blue: 0.29))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.foundStop ? "已找到市场旁边的 B 站" : "打开站点图")
        .disabled(isPlayingSequence || session.foundStop)
    }

    private var stopMap: some View {
        mapDiagram(width: 44) { stop in
            Button {
                selectStop(stop)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: stop.symbol)
                    Text(stop.rawValue).bold()
                }
                .frame(width: 44, height: 44)
                .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(stop.label)
            .disabled(isPlayingSequence)
        }
        .frame(height: 146)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func mapDiagram<Marker: View>(width: CGFloat, @ViewBuilder marker: @escaping (RainyTransferSession.Stop) -> Marker) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let origin = CGPoint(x: size.width * 0.5, y: size.height - width / 2)
            let junction = CGPoint(x: size.width * 0.5, y: size.height * 0.54)
            ZStack {
                Path { path in
                    for stop in RainyTransferSession.Stop.allCases {
                        path.move(to: origin)
                        path.addLine(to: junction)
                        path.addLine(to: stopPoint(stop, in: size))
                    }
                }
                .stroke(Color(red: 0.35, green: 0.52, blue: 0.54), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                if session.foundStop {
                    Path { path in
                        path.move(to: origin)
                        path.addLine(to: junction)
                        path.addLine(to: stopPoint(.market, in: size))
                    }
                    .stroke(progress.theme.success, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                Text("你在这里")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .background(.regularMaterial, in: Capsule())
                    .position(origin)
                    .accessibilityHidden(true)
                ForEach(RainyTransferSession.Stop.allCases) { stop in
                    marker(stop).position(stopPoint(stop, in: size))
                }
            }
        }
    }

    private func stopPoint(_ stop: RainyTransferSession.Stop, in size: CGSize) -> CGPoint {
        switch stop {
        case .library: CGPoint(x: size.width * 0.18, y: size.height * 0.54)
        case .market: CGPoint(x: size.width * 0.82, y: size.height * 0.54)
        case .square: CGPoint(x: size.width * 0.50, y: size.height * 0.18)
        }
    }

    private func phraseRow(_ line: StudyPhrase, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            PronunciationButton(hebrew: line.hebrew, iconOnly: true, title: "试听台词", bundledOnly: true)
            Button(action: action) {
                phraseText(line)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
        .disabled(isPlayingSequence)
    }

    @ViewBuilder private func dialogueLine(_ id: String, speaker: String, canReplay: Bool = true,
                                           alwaysShowTranslation: Bool = false) -> some View {
        if let line = phrase(id) {
            VStack(alignment: .leading, spacing: 4) {
                Text(speaker).font(.caption.weight(.bold)).foregroundStyle(progress.theme.accent)
                HStack(spacing: 8) {
                    if canReplay {
                        PronunciationButton(hebrew: line.hebrew, iconOnly: true,
                                            title: "重听\(speaker)的台词", bundledOnly: true)
                            .disabled(isPlayingSequence)
                    }
                    phraseText(line, alwaysShowTranslation: alwaysShowTranslation)
                }
            }
            .padding(8)
            .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func phraseText(_ line: StudyPhrase, alwaysShowTranslation: Bool = false) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HebrewText(text: showNiqqud ? line.hebrew : line.hebrewUnpointed, size: 19)
            if showTransliteration {
                Text(line.transliteration).font(.caption).foregroundStyle(progress.theme.mutedInk)
            }
            if showTranslation || alwaysShowTranslation {
                Text(line.meaningZh).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(StudyButtonStyle(learningAction: true))
        .disabled(isPlayingSequence)
    }

    private func phrase(_ id: String) -> StudyPhrase? {
        content.phrases.first { $0.id == id }
    }

    private func speaker(for id: String) -> String {
        switch id {
        case "p-dir-10", "p-dir-12": "司机"
        case RainyTransferSession.announcementID: "站台广播"
        default: "你"
        }
    }

    private func shuffleChoices() {
        optionIDs = session.choices.map(\.id).shuffled()
    }

    private func openTransferQuestion() {
        session.askWhereToTransfer()
        shuffleChoices()
    }

    private func selectStop(_ stop: RainyTransferSession.Stop) {
        let correct = session.chooseStop(stop)
        audio.playFeedback(correct ? .correct : .wrong)
    }

    private func playAnnouncement() {
        startAudio([RainyTransferSession.announcementID], completion: .announcement)
    }

    private func restart() {
        cancelAudio()
        session = RainyTransferSession()
        shuffleChoices()
        waitOptions.shuffle()
        showBroadcastText = false
        showTranscript = false
        showFullMap = false
    }

    private func startAudio(_ ids: [String], completion: AudioCompletion? = nil) {
        guard !isPlayingSequence else { return }
        audio.stop()
        queuedAudio = ids
        audioCompletion = completion
        playNext()
    }

    private func playNext() {
        playingID = nil
        while !queuedAudio.isEmpty {
            let id = queuedAudio.removeFirst()
            guard let line = phrase(id) else { continue }
            audio.speak(line.hebrew, rate: progress.speechRate, bundledOnly: true)
            if audio.playingPronunciation == line.hebrew {
                playingID = id
                return
            }
        }
        switch audioCompletion {
        case .announcement:
            if audio.playbackError != nil { showBroadcastText = true }
            session.reviewAnnouncement()
        case .closingLine:
            session.finish()
        case nil:
            break
        }
        audioCompletion = nil
    }

    private func cancelAudio() {
        playingID = nil
        queuedAudio = []
        audioCompletion = nil
        audio.stop()
    }
}

private extension View {
    func position(at point: CGPoint, in size: CGSize) -> some View {
        position(x: size.width * point.x, y: size.height * point.y)
    }
}
