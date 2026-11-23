import SwiftUI

enum StudyGame: String, CaseIterable, Identifiable {
    case letters, spelling

    var id: Self { self }

    var title: String {
        switch self {
        case .letters: "字母侦探"
        case .spelling: "拼字工坊"
        }
    }

    var symbol: String {
        switch self {
        case .letters: "magnifyingglass"
        case .spelling: "square.grid.3x2"
        }
    }

    var instructions: String {
        switch self {
        case .letters: "找出指定字母，也会遇到手写体配对。"
        case .spelling: "看词义或听原音，从右往左拼出单词。"
        }
    }

    func questions(in content: StudyContent) -> [StudyGameQuestion] {
        switch self {
        case .letters:
            return content.letters.shuffled().prefix(6).enumerated().map { index, letter in
                let otherLetters = content.letters.filter { $0.id != letter.id }.shuffled()
                let similar = otherLetters.filter { letter.confusableWith.contains($0.id) }
                let remaining = otherLetters.filter { !letter.confusableWith.contains($0.id) }
                let options = ([letter] + Array((similar + remaining).prefix(3))).shuffled()
                return .letter(letter, options: options, showCursive: index >= 3)
            }
        case .spelling:
            let coreIDs = Set(content.learningPath.flatMap(\.wordIds))
            let candidates = content.words.filter { $0.canPracticeSpelling && $0.hebrewUnpointed.count <= 5 }
            let coreWords = candidates.filter { coreIDs.contains($0.id) }.shuffled()
            let otherWords = candidates.filter { !coreIDs.contains($0.id) }.shuffled()
            return (coreWords + otherWords).prefix(6).map { word in
                let answer = Array(word.hebrewUnpointed)
                let distractors = content.letters.map(\.hebrew)
                    .filter { glyph in !answer.contains { String($0) == glyph } }
                    .shuffled().prefix(2)
                return .word(word, tiles: (answer.map { String($0) } + Array(distractors)).shuffled())
            }
        }
    }
}

enum StudyGameQuestion {
    case letter(StudyLetter, options: [StudyLetter], showCursive: Bool)
    case word(StudyWord, tiles: [String])
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

struct StudyGameView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let game: StudyGame
    let content: StudyContent

    @State private var round: StudyGameRound?
    @State private var selectedLetter: String?
    @State private var selectedTiles: [Int] = []

    var body: some View {
        StudyPage {
            if let round {
                if let turn = round.current {
                    header(round, retry: turn.isRetry)
                    switch turn.question {
                    case let .letter(letter, options, showCursive):
                        letterQuestion(letter, options: options, showCursive: showCursive, answer: round.answer)
                    case let .word(word, tiles):
                        spellingQuestion(word, tiles: tiles, answer: round.answer)
                    }
                } else {
                    summary(round)
                }
            }
        }
        .studyDetail(game.title)
        .onAppear {
            if round == nil { start(game.questions(in: content)) }
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
        ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
            StudyAnswerButton(title: option.hebrew, submitted: answer != nil,
                              selected: selectedLetter == option.id, correct: option.id == letter.id,
                              isHebrew: true, optionLabel: studyOptionLabel(index)) {
                selectedLetter = option.id
                submit(option.id == letter.id)
            }
        }
        if let answer {
            StudyQuizFeedback(correct: answer, solution: "\(letter.hebrew) · \(letter.studyName)")
            PronunciationButton(hebrew: letter.nameHebrew, title: "听字母名称")
            nextButton
        }
    }

    @ViewBuilder private func spellingQuestion(_ word: StudyWord, tiles: [String], answer: Bool?) -> some View {
        let spelling = selectedTiles.map { tiles[$0] }.joined()
        StudyCard {
            StudySectionTitle(word.meaningZh)
            Text("从右往左拼写 · \(selectedTiles.count) / \(word.hebrewUnpointed.count) 个字母")
                .font(.footnote).foregroundStyle(progress.theme.mutedInk)
            PronunciationButton(hebrew: word.hebrew, title: "听单词原音")
            HebrewText(text: spelling.isEmpty ? "…" : spelling, size: 35, style: .title)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .trailing)
                .padding(.horizontal, 10)
                .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(spelling.isEmpty ? "拼写区域为空" : "已拼写 \(spelling)")
        }
        if answer == nil {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 55), spacing: 8)], spacing: 8) {
                ForEach(tiles.indices, id: \.self) { index in
                    Button {
                        selectedTiles.append(index)
                    } label: {
                        HebrewText(text: tiles[index], size: 24)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle())
                    .disabled(selectedTiles.contains(index) || selectedTiles.count >= word.hebrewUnpointed.count)
                }
            }
            Button {
                _ = selectedTiles.popLast()
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
            nextButton
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
                start(game.questions(in: content))
            } label: {
                Label("再玩一局", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle(learningAction: round.mistakes.isEmpty))
        }
    }

    private func submit(_ correct: Bool) {
        guard round?.current != nil, round?.answer == nil else { return }
        round?.submit(correct: correct)
        audio.playFeedback(correct ? .correct : .wrong)
    }

    private func start(_ questions: [StudyGameQuestion]) {
        audio.stop()
        resetInput()
        round = StudyGameRound(questions: questions)
    }

    private func resetInput() {
        selectedLetter = nil
        selectedTiles = []
    }
}
