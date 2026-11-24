import SwiftUI

enum StudyGame: String, CaseIterable, Identifiable {
    case letters, spelling, listening, matching

    var id: Self { self }

    var title: String {
        switch self {
        case .letters: "字母侦探"
        case .spelling: "拼字工坊"
        case .listening: "听音寻宝"
        case .matching: "翻牌配对"
        }
    }

    var symbol: String {
        switch self {
        case .letters: "magnifyingglass"
        case .spelling: "square.grid.3x2"
        case .listening: "ear"
        case .matching: "rectangle.on.rectangle"
        }
    }

    var instructions: String {
        switch self {
        case .letters: "找出指定字母，也会遇到手写体配对。"
        case .spelling: "看词义或听原音，从右往左拼出单词。"
        case .listening: "听原音，找出对应的字母或单词。"
        case .matching: "翻开两张牌，配对字形或词义。"
        }
    }

    func questions(in content: StudyContent, progress: StudyProgress? = nil) -> [StudyGameQuestion] {
        let selection = StudyGameSelection(content: content, progress: progress)
        switch self {
        case .letters:
            return selection.letters(content.letters).prefix(6).enumerated().map { index, letter in
                let otherLetters = content.letters.filter { $0.id != letter.id }.shuffled()
                let similar = otherLetters.filter { letter.confusableWith.contains($0.id) }
                let remaining = otherLetters.filter { !letter.confusableWith.contains($0.id) }
                let options = ([letter] + Array((similar + remaining).prefix(3))).shuffled()
                return .letter(letter, options: options, showCursive: index >= 3)
            }
        case .spelling:
            let candidates = content.words.filter { $0.canPracticeSpelling && $0.hebrewUnpointed.count <= 5 }
            return selection.words(candidates).prefix(6).map { word in
                let answer = Array(word.hebrewUnpointed)
                let distractors = content.letters.map(\.hebrew)
                    .filter { glyph in !answer.contains { String($0) == glyph } }
                    .shuffled().prefix(2)
                return .word(word, tiles: (answer.map { String($0) } + Array(distractors)).shuffled())
            }
        case .listening:
            let letters = content.letters.filter { content.audio[$0.nameHebrew] != nil }.shuffled()
            let words = content.words.filter { selection.includesWord($0.id) && content.audio[$0.hebrew] != nil }.shuffled()
            let letterQuestions = selection.letters(letters).prefix(3).compactMap { letter -> StudyGameQuestion? in
                let options = letters.filter { $0.id != letter.id && $0.hebrew != letter.hebrew }.prefix(3)
                guard !options.isEmpty else { return nil }
                return .listening(.init(letter), options: ([letter] + Array(options)).map(StudyGameChoice.init).shuffled(),
                                  prompt: "听字母名称，选出对应字母")
            }
            let wordQuestions = selection.words(words).prefix(3).compactMap { word -> StudyGameQuestion? in
                var spellings: Set<String> = [word.hebrewUnpointed]
                var pronunciations: Set<String> = [word.ipa]
                var alternatives: [StudyWord] = []
                for candidate in words where alternatives.count < 3 {
                    guard !spellings.contains(candidate.hebrewUnpointed), !pronunciations.contains(candidate.ipa) else { continue }
                    spellings.insert(candidate.hebrewUnpointed)
                    pronunciations.insert(candidate.ipa)
                    alternatives.append(candidate)
                }
                guard !alternatives.isEmpty else { return nil }
                return .listening(.init(word), options: ([word] + alternatives).map(StudyGameChoice.init).shuffled(),
                                  prompt: "听原音，选出对应单词")
            }
            return (letterQuestions + wordQuestions).shuffled()
        case .matching:
            return []
        }
    }
}

private struct StudyGameSelection {
    let stageWordIDs: Set<String>
    let stageLetterIDs: Set<String>
    let coreWordIDs: Set<String>
    let wordSchedule: [String: ReviewSchedule]
    let letterSchedule: [String: ReviewSchedule]

    init(content: StudyContent, progress: StudyProgress?) {
        let stage = progress.flatMap { content.recommendedStage(in: $0) }
        stageWordIDs = Set(stage?.wordIds ?? [])
        stageLetterIDs = Set(stage?.letterIds ?? [])
        coreWordIDs = Set(content.learningPath.flatMap(\.wordIds))
        wordSchedule = progress?.schedule ?? [:]
        letterSchedule = progress?.letterSchedule ?? [:]
    }

    func includesWord(_ id: String) -> Bool {
        coreWordIDs.contains(id) || (wordSchedule[id]?.lapses ?? 0) > 0
    }

    func letters(_ items: [StudyLetter]) -> [StudyLetter] {
        items.shuffled().sorted {
            rank($0.id, stageIDs: stageLetterIDs, schedule: letterSchedule)
                > rank($1.id, stageIDs: stageLetterIDs, schedule: letterSchedule)
        }
    }

    func words(_ items: [StudyWord]) -> [StudyWord] {
        items.shuffled().sorted {
            let first = rank($0.id, stageIDs: stageWordIDs, schedule: wordSchedule)
            let second = rank($1.id, stageIDs: stageWordIDs, schedule: wordSchedule)
            if first != second { return first > second }
            return coreWordIDs.contains($0.id) && !coreWordIDs.contains($1.id)
        }
    }

    private func rank(_ id: String, stageIDs: Set<String>, schedule: [String: ReviewSchedule]) -> (Int, Int) {
        (schedule[id]?.lapses ?? 0, stageIDs.contains(id) ? 1 : 0)
    }
}

enum StudyGameQuestion {
    case letter(StudyLetter, options: [StudyLetter], showCursive: Bool)
    case word(StudyWord, tiles: [String])
    case listening(StudyGameChoice, options: [StudyGameChoice], prompt: String)
}

struct StudyGameChoice: Identifiable {
    let id: String
    let hebrew: String
    let audio: String
    let hint: String

    init(_ letter: StudyLetter) {
        id = letter.id
        hebrew = letter.hebrew
        audio = letter.nameHebrew
        hint = letter.studyName
    }

    init(_ word: StudyWord) {
        id = word.id
        hebrew = word.hebrew
        audio = word.hebrew
        hint = word.meaningZh
    }
}

struct StudyGameRound {
    struct Turn {
        let question: StudyGameQuestion
        var isRetry = false
    }

    let total: Int
    private var turns: [Turn]
    private(set) var index = 0
    private(set) var answered = 0
    private(set) var correct = 0
    private(set) var streak = 0
    private(set) var score = 0
    private(set) var mistakes: [StudyGameQuestion] = []
    private(set) var answer: Bool?

    init(questions: [StudyGameQuestion]) {
        total = questions.count
        turns = questions.map { Turn(question: $0) }
    }

    var current: Turn? { turns.indices.contains(index) ? turns[index] : nil }

    mutating func submit(correct isCorrect: Bool) {
        guard answer == nil, let current else { return }
        answer = isCorrect
        guard !current.isRetry else { return }
        answered += 1
        if isCorrect {
            correct += 1
            streak += 1
            score += 10 + min(streak - 1, 3) * 2
        } else {
            streak = 0
            mistakes.append(current.question)
            turns.insert(Turn(question: current.question, isRetry: true), at: min(index + 3, turns.endIndex))
        }
    }

    mutating func advance() {
        guard answer != nil else { return }
        index += 1
        answer = nil
    }
}

struct StudyComicMotion<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: value)
    }
}

struct StudyGameView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var spellingTiles
    let game: StudyGame
    let content: StudyContent

    @State private var round: StudyGameRound?
    @State private var selectedChoice: String?
    @State private var selectedTiles: [Int] = []

    var body: some View {
        ScrollViewReader { scroll in
            StudyPage {
                if let round {
                    if let turn = round.current {
                        header(round, retry: turn.isRetry).id("game-top")
                        switch turn.question {
                        case let .letter(letter, options, showCursive):
                            letterQuestion(letter, options: options, showCursive: showCursive, answer: round.answer)
                        case let .word(word, tiles):
                            spellingQuestion(word, tiles: tiles, answer: round.answer)
                        case let .listening(solution, options, prompt):
                            listeningPrompt(solution, prompt: prompt, answered: round.answer != nil)
                            audioChoices(solution: solution, options: options, answer: round.answer)
                        }
                    } else {
                        summary(round).id("game-top")
                    }
                }
            }
            .onChange(of: round?.index) { _, _ in scroll.scrollTo("game-top", anchor: .top) }
        }
        .studyDetail(game.title)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if round?.answer != nil {
                StudyActionBar { nextButton }
            }
        }
        .onAppear {
            if round == nil { start(game.questions(in: content, progress: progress)) }
        }
        .onDisappear { audio.stop() }
    }

    private func header(_ round: StudyGameRound, retry: Bool) -> some View {
        StudyCard(padding: 10) {
            ProgressView(value: Double(round.answered), total: Double(round.total)) {
                Text(retry ? "错题重练" : "已完成 \(round.answered) / \(round.total) 题")
            }
            .tint(progress.theme.learningAction)
            ViewThatFits(in: .horizontal) {
                HStack { scoreLabel(round); Spacer(minLength: 12); streakLabel(round) }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 4) { scoreLabel(round); streakLabel(round) }
            }
            .font(.subheadline.monospacedDigit())
        }
    }

    private func scoreLabel(_ round: StudyGameRound) -> some View {
        Label("\(round.score) 分", systemImage: "star.fill")
            .foregroundStyle(progress.theme.reminder)
    }

    private func streakLabel(_ round: StudyGameRound) -> some View {
        Label("连对 \(round.streak) 题", systemImage: "bolt.fill")
            .foregroundStyle(progress.theme.mutedInk)
    }

    @ViewBuilder private func letterQuestion(_ letter: StudyLetter, options: [StudyLetter],
                                              showCursive: Bool, answer: Bool?) -> some View {
        StudyCard {
            if showCursive {
                StudySectionTitle("选出对应的印刷体字母")
                StudyCursiveLetter(letter: letter, size: 56).frame(maxWidth: .infinity)
            } else {
                StudySectionTitle("找出 \(letter.studyName)（\(letter.nameChinese)）")
            }
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                 count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
            ForEach(options) { option in
                let opened = answer != nil && option.id == letter.id
                let missed = answer == false && option.id == selectedChoice
                Button {
                    selectedChoice = option.id
                    submit(option.id == letter.id)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: opened ? "door.left.hand.open" : "door.left.hand.closed")
                            .font(.headline)
                            .foregroundStyle(opened ? progress.theme.success : progress.theme.mutedInk)
                            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                        HebrewText(text: option.hebrew, size: 34)
                        if opened || missed {
                            Image(systemName: opened ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(opened ? progress.theme.success : progress.theme.error)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(opened ? progress.theme.successSurface :
                                    (missed ? progress.theme.errorSurface : progress.theme.cardSurface),
                                in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(answer != nil)
                .accessibilityLabel(option.hebrew)
                .accessibilityValue(opened ? "正确答案" : (missed ? "答案有误" : ""))
            }
        }
        .modifier(StudyComicMotion(value: answer))
        if let answer {
            StudyQuizFeedback(correct: answer, solution: "\(letter.hebrew) · \(letter.studyName)")
            if !answer, let selected = options.first(where: { $0.id == selectedChoice }) {
                HStack(spacing: 8) {
                    letterComparison(selected, title: "我的选项")
                    letterComparison(letter, title: "正确字母")
                }
            }
            PronunciationButton(hebrew: letter.nameHebrew, title: "听字母名称")
        }
    }

    private func letterComparison(_ letter: StudyLetter, title: String) -> some View {
        StudyCard(padding: 8) {
            Text(title).font(.caption).foregroundStyle(progress.theme.mutedInk)
            HebrewText(text: letter.hebrew, size: 34).frame(maxWidth: .infinity)
        }
    }

    private func listeningPrompt(_ solution: StudyGameChoice, prompt: String, answered: Bool) -> some View {
        let playing = !answered && audio.playingPronunciation == solution.audio
        return StudyCard {
            StudySectionTitle(prompt)
            if !answered {
                PronunciationButton(hebrew: solution.audio, title: playing ? "播放中，点按重听" : "听题目原音", bundledOnly: true)
            }
        }
    }

    @ViewBuilder private func audioChoices(solution: StudyGameChoice, options: [StudyGameChoice], answer: Bool?) -> some View {
        ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
            let playing = answer != nil && audio.playingPronunciation == option.audio
            StudyAnswerButton(title: option.hebrew, submitted: answer != nil,
                              selected: selectedChoice == option.id, correct: option.id == solution.id,
                              isHebrew: true, optionLabel: studyOptionLabel(index), playing: playing) {
                selectedChoice = option.id
                submit(option.id == solution.id)
            }
        }
        if let answer {
            let selected = options.first { $0.id == selectedChoice }
            StudyQuizFeedback(correct: answer, solution: solution.hebrew, response: selected?.hebrew, explanation: solution.hint)
            if !answer, let selected {
                PronunciationButton(hebrew: selected.audio, title: "重听我的选项", bundledOnly: true)
            }
            PronunciationButton(hebrew: solution.audio, title: "重听正确答案", bundledOnly: true)
        }
    }

    @ViewBuilder private func spellingQuestion(_ word: StudyWord, tiles: [String], answer: Bool?) -> some View {
        let spelling = selectedTiles.map { tiles[$0] }.joined()
        StudyCard {
            StudySectionTitle(word.meaningZh)
            Text("从右往左拼写 · \(selectedTiles.count) / \(word.hebrewUnpointed.count) 个字母")
                .font(.footnote).foregroundStyle(progress.theme.mutedInk)
            PronunciationButton(hebrew: word.hebrew, title: "听单词原音")
            Group {
                if answer != nil || typeSize.isAccessibilitySize {
                    HebrewText(text: spelling.isEmpty ? "…" : spelling, size: 30, style: .title)
                } else {
                    HStack(spacing: 4) {
                        ForEach(0..<word.hebrewUnpointed.count, id: \.self) { slot in
                            if selectedTiles.indices.contains(slot) {
                                let index = selectedTiles[slot]
                                HebrewText(text: tiles[index], size: 24)
                                    .matchedGeometryEffect(id: index, in: spellingTiles)
                                    .frame(minWidth: 32, minHeight: 44)
                            } else {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(progress.theme.outline, style: StrokeStyle(dash: [3, 2]))
                                    .frame(width: 32, height: 44)
                            }
                        }
                    }
                    .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .trailing)
            .padding(.horizontal, 10)
            .background(answer == true ? progress.theme.successSurface : progress.theme.insetSurface,
                        in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spelling.isEmpty ? "拼写区域为空" : "已拼写 \(spelling)")
        }
        if answer == nil {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 55), spacing: 8)], spacing: 8) {
                ForEach(tiles.indices, id: \.self) { index in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                            selectedTiles.append(index)
                        }
                    } label: {
                        Group {
                            if selectedTiles.contains(index) {
                                Color.clear
                            } else {
                                HebrewText(text: tiles[index], size: 24)
                                    .matchedGeometryEffect(id: index, in: spellingTiles)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(StudyButtonStyle())
                    .disabled(selectedTiles.contains(index) || selectedTiles.count >= word.hebrewUnpointed.count)
                    .accessibilityHidden(selectedTiles.contains(index))
                }
            }
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                    _ = selectedTiles.popLast()
                }
            } label: {
                Label("撤销上一个字母", systemImage: "delete.left")
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(selectedTiles.isEmpty)
            Button {
                submit(word.acceptsSpelling(spelling))
            } label: {
                Label("确认拼写", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle(learningAction: true))
            .disabled(selectedTiles.count != word.hebrewUnpointed.count)
        } else if let answer {
            StudyQuizFeedback(correct: answer, solution: word.hebrewUnpointed, response: spelling,
                              explanation: word.transliteration)
            if answer {
                PronunciationButton(hebrew: word.hebrew, title: "听拼好的单词")
            }
        }
    }

    private var nextButton: some View {
        Button {
            audio.stop()
            resetInput()
            round?.advance()
        } label: {
            Label("继续", systemImage: "arrow.right").frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(learningAction: true))
    }

    private func summary(_ round: StudyGameRound) -> some View {
        VStack(spacing: 8) {
            if round.total > 0 {
                StudyQuizSummary(title: "本局完成", correct: round.correct, answered: round.total)
                Text("首次作答 \(round.score) 分").font(.headline).foregroundStyle(progress.theme.ink)
                if !round.mistakes.isEmpty {
                    Button {
                        start(round.mistakes)
                    } label: {
                        Label("重练错题", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(learningAction: true))
                }
            } else {
                ContentUnavailableView("暂无可用题目", systemImage: game.symbol)
            }

            Button {
                start(game.questions(in: content, progress: progress))
            } label: {
                Label("再玩一局", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle(learningAction: round.mistakes.isEmpty))
        }
    }

    private func submit(_ correct: Bool) {
        guard round?.current != nil, round?.answer == nil else { return }
        round?.submit(correct: correct)
        audio.stop()
        audio.playFeedback(correct ? .correct : .wrong)
    }

    private func start(_ questions: [StudyGameQuestion]) {
        audio.stop()
        resetInput()
        round = StudyGameRound(questions: questions)
    }

    private func resetInput() {
        selectedChoice = nil
        selectedTiles = []
    }
}

enum StudyMatchingDeck: String {
    case letters, words

    func cards(in content: StudyContent, progress: StudyProgress? = nil) -> [StudyMatchingCard] {
        let selection = StudyGameSelection(content: content, progress: progress)
        let pairs: [(StudyMatchingCard.Face, StudyMatchingCard.Face)]
        switch self {
        case .letters:
            pairs = selection.letters(content.letters).prefix(4).map { (.hebrew($0.hebrew), .cursive($0)) }
        case .words:
            let words = selection.words(content.words.filter { selection.includesWord($0.id) })
            var hebrew: Set<String> = []
            var meanings: Set<String> = []
            var selected: [StudyWord] = []
            for word in words where selected.count < 4 {
                guard !hebrew.contains(word.hebrew), !meanings.contains(word.meaningZh) else { continue }
                hebrew.insert(word.hebrew)
                meanings.insert(word.meaningZh)
                selected.append(word)
            }
            pairs = selected.map { (.hebrew($0.hebrew), .translation($0.meaningZh)) }
        }
        return pairs.enumerated().flatMap { index, pair in
            [
                StudyMatchingCard(id: index * 2, pair: index, face: pair.0),
                StudyMatchingCard(id: index * 2 + 1, pair: index, face: pair.1)
            ]
        }.shuffled()
    }
}

struct StudyMatchingCard: Identifiable {
    enum Face {
        case hebrew(String), cursive(StudyLetter), translation(String)

        var accessibilityText: String {
            switch self {
            case .hebrew(let text), .translation(let text): text
            case .cursive(let letter): "手写体 \(letter.hebrew)"
            }
        }
    }

    let id: Int
    let pair: Int
    let face: Face
}

struct StudyMatchingRound {
    let cards: [StudyMatchingCard]
    private(set) var revealedIDs: [Int] = []
    private(set) var matched: Set<Int> = []
    private(set) var attempts = 0

    var complete: Bool { !cards.isEmpty && matched.count == cards.count }
    var hasMismatch: Bool { revealedIDs.count == 2 }

    mutating func flip(_ card: StudyMatchingCard) -> Bool? {
        guard !hasMismatch, !matched.contains(card.id), !revealedIDs.contains(card.id) else { return nil }
        revealedIDs.append(card.id)
        guard revealedIDs.count == 2 else { return nil }
        attempts += 1
        guard cards.first(where: { $0.id == revealedIDs[0] })?.pair == card.pair else { return false }
        matched.formUnion(revealedIDs)
        revealedIDs.removeAll()
        return true
    }

    mutating func coverMismatch() {
        guard hasMismatch else { return }
        revealedIDs.removeAll()
    }
}

struct StudyMatchingGameView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var audio: StudyAudio
    let content: StudyContent
    @State private var deck = StudyMatchingDeck.letters
    @State private var round = StudyMatchingRound(cards: [])
    @State private var started = false

    var body: some View {
        StudyPage {
            StudySegments(title: "配对内容", options: [(.letters, "字形"), (.words, "词义")], selection: $deck)
            if !round.cards.isEmpty {
                StudyCard(padding: 10) {
                    StudySectionTitle("已配对 \(round.matched.count / 2) / \(round.cards.count / 2) 对")
                    Text("尝试 \(round.attempts) 次")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(progress.theme.mutedInk)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 2),
                          spacing: 8) {
                    ForEach(Array(round.cards.enumerated()), id: \.element.id) { position, card in
                        tile(card, position: position)
                    }
                }
                if round.complete {
                    StudyNotice(title: "全部配对成功", symbol: "trophy")
                }
            } else if started {
                ContentUnavailableView("暂无可配对的卡片", systemImage: "rectangle.on.rectangle")
            }

            if started {
                Button {
                    start()
                } label: {
                    Label(round.complete ? "再玩一局" : "重新发牌", systemImage: "shuffle").frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(learningAction: round.complete))
            }
        }
        .studyDetail(StudyGame.matching.title)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if round.hasMismatch {
                StudyActionBar {
                    Button {
                        round.coverMismatch()
                    } label: {
                        Label("盖回这两张", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(learningAction: true))
                }
            }
        }
        .onChange(of: deck, initial: true) { _, _ in start() }
        .onDisappear { audio.stop() }
    }

    private func tile(_ card: StudyMatchingCard, position: Int) -> some View {
        let matched = round.matched.contains(card.id)
        let revealed = matched || round.revealedIDs.contains(card.id)
        return Button {
            let result = round.flip(card)
            audio.playFeedback(result.map { $0 ? .correct : .wrong } ?? .flip)
        } label: {
            ZStack {
                if revealed {
                    face(card.face)
                        .modifier(StudyMatchingTileSurface(matched: matched, revealed: true))
                        .transition(.modifier(active: StudyMatchingFlip(angle: 90),
                                              identity: StudyMatchingFlip(angle: 0)))
                } else {
                    Image(systemName: "rectangle.portrait")
                        .font(.title2)
                        .foregroundStyle(progress.theme.accent)
                        .modifier(StudyMatchingTileSurface(matched: false, revealed: false))
                        .transition(.modifier(active: StudyMatchingFlip(angle: -90),
                                              identity: StudyMatchingFlip(angle: 0)))
                }
            }
            .overlay(alignment: .topTrailing) {
                if matched {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(progress.theme.success)
                        .padding(6)
                        .accessibilityHidden(true)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .modifier(StudyComicMotion(value: revealed))
        .modifier(StudyComicMotion(value: matched))
        .disabled(revealed || round.hasMismatch)
        .accessibilityLabel(revealed ? card.face.accessibilityText : "翻开第 \(position + 1) 张卡片")
        .accessibilityValue(matched ? "已配对" : (revealed ? "已翻开" : "未翻开"))
    }

    @ViewBuilder private func face(_ face: StudyMatchingCard.Face) -> some View {
        switch face {
        case .hebrew(let text):
            HebrewText(text: text, size: 28)
        case .cursive(let letter):
            StudyCursiveLetter(letter: letter, size: 42)
        case .translation(let text):
            Text(text).font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(progress.theme.ink)
        }
    }

    private func start() {
        audio.stop()
        round = StudyMatchingRound(cards: deck.cards(in: content, progress: progress))
        started = true
    }
}

private struct StudyMatchingFlip: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            .opacity(angle == 0 ? 1 : 0)
    }
}

private struct StudyMatchingTileSurface: ViewModifier {
    @Environment(StudyProgress.self) private var progress
    let matched: Bool
    let revealed: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        content
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(matched ? progress.theme.successSurface :
                            (revealed ? progress.theme.highlightedSurface : progress.theme.cardSurface),
                        in: shape)
            .overlay {
                shape.strokeBorder(matched ? progress.theme.success : progress.theme.outline, lineWidth: 1)
            }
    }
}
