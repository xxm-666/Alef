import SwiftUI

private struct FlashcardPreferences: Codable {
    var subMode = "flip"
    var frontType = "both"
    var deckScope = "all"
    var cardIndex = 0
    var quizType = "block-to-sound"
}

struct StudyFlashcardsView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let content: StudyContent
    @State private var flipped = false
    @State private var shuffledIDs: [String]?

    var body: some View {
        Form {
            Picker("练习方式", selection: setting(\.subMode)) {
                Text("翻卡").tag("flip")
                Text("测验").tag("quiz")
            }
            .pickerStyle(.segmented)
            if preferences.subMode == "quiz" {
                Picker("题型", selection: setting(\.quizType)) {
                    Text("字形 → 发音").tag("block-to-sound")
                    Text("手写 → 印刷").tag("cursive-to-block")
                    Text("匹配词尾").tag("sofit-match")
                    Text("达盖什辨音").tag("dagesh-quiz")
                }
                FlashQuizSection(letters: content.letters, kind: preferences.quizType)
                    .id(preferences.quizType)
            } else {
                Section {
                    Picker("卡片范围", selection: setting(\.deckScope)) {
                        Text("全部").tag("all")
                        Text("需复习").tag("needs_review")
                        Text("词尾形").tag("sofit")
                        Text("达盖什").tag("begadkefat")
                    }
                    Picker("正面字形", selection: setting(\.frontType)) {
                        Text("印刷体").tag("block")
                        Text("手写体").tag("cursive")
                        Text("印刷与手写").tag("both")
                        Text("词尾形").tag("sofit")
                    }
                }
                if let current = deck[safe: index] {
                    Section("卡片 \(index + 1) / \(deck.count)") {
                        Button(action: flip) {
                            VStack(spacing: 8) {
                                flashcard(current)
                                Text(flipped ? "查看正面" : "翻到答案").font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 155)
                        }
                        .keyboardShortcut(.space, modifiers: [])
                        PronunciationButton(hebrew: current.nameHebrew, fallback: current.nameEnglish)
                        if flipped {
                            NavigationLink("完整详情与手写") { LetterStudyView(letter: current, content: content) }
                            if let example = current.examples.first { WordExampleRow(example: example) }
                            ForEach(Mastery.allCases) { level in
                                Button(level.title) {
                                    let following = deck[safe: (index + 1) % deck.count]?.id
                                    progress.setLetter(current.id, mastery: level)
                                    let next = deck.firstIndex { $0.id == following } ?? 0
                                    setting(\.cardIndex).wrappedValue = next
                                    flipped = false
                                }
                            }
                        }
                    }
                    Section {
                        Button("上一张", systemImage: "chevron.left") { move(-1) }
                            .keyboardShortcut(.leftArrow, modifiers: [])
                        Button("下一张", systemImage: "chevron.right") { move(1) }
                            .keyboardShortcut(.rightArrow, modifiers: [])
                        Button("打乱顺序", systemImage: "shuffle") {
                            shuffledIDs = deck.shuffled().map(\.id)
                            setting(\.cardIndex).wrappedValue = 0
                            flipped = false
                        }
                        if shuffledIDs != nil {
                            Button("恢复字母顺序", systemImage: "arrow.counterclockwise") {
                                shuffledIDs = nil
                                setting(\.cardIndex).wrappedValue = 0
                                flipped = false
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("这个范围没有卡片", systemImage: "rectangle.on.rectangle")
                }
            }
        }
        .navigationTitle("闪卡")
        .onChange(of: preferences.deckScope) { _, _ in
            shuffledIDs = nil
            setting(\.cardIndex).wrappedValue = 0
            flipped = false
        }
        .onChange(of: preferences.frontType) { _, _ in flipped = false }
    }

    private var preferences: FlashcardPreferences { progress.read("alef.flashcardState.v1", default: FlashcardPreferences()) }

    private func setting<Value>(_ key: WritableKeyPath<FlashcardPreferences, Value>) -> Binding<Value> {
        Binding(get: { preferences[keyPath: key] }, set: { value in
            var saved = preferences
            saved[keyPath: key] = value
            progress.write(saved, for: "alef.flashcardState.v1")
        })
    }

    private var deck: [StudyLetter] {
        let mastery = progress.letterMastery
        let filtered = content.letters.filter { letter in
            switch preferences.deckScope {
            case "needs_review": mastery[letter.id] != .mastered
            case "sofit": letter.sofit != nil
            case "begadkefat": letter.begadkefat != nil
            default: true
            }
        }
        let ordered = shuffledIDs?.compactMap { id in filtered.first { $0.id == id } } ?? []
        return ordered.count == filtered.count ? ordered : filtered
    }

    private var index: Int { min(max(0, preferences.cardIndex), max(0, deck.count - 1)) }

    private func move(_ offset: Int) {
        guard !deck.isEmpty else { return }
        setting(\.cardIndex).wrappedValue = (index + offset + deck.count) % deck.count
        flipped = false
    }

    private func flip() {
        flipped.toggle()
        audio.playFeedback(.flip)
    }

    @ViewBuilder private func flashcard(_ letter: StudyLetter) -> some View {
        if flipped {
            HebrewText(text: letter.nameHebrew, size: 43)
            Text("\(letter.nameEnglish) · \(letter.nameChinese)").font(.title3)
            Text("现代 \(letter.modernIpa) · \(letter.modernSound)")
            Text("古典 \(letter.biblicalIpa) · \(letter.biblicalDiff)")
            Text("\(letter.meaning)。\(letter.cursiveDesc)")
            Text("字母数值 \(letter.gematria) · 转写 \(letter.transliteration)").font(.footnote)
        } else {
            HStack(spacing: 20) {
                if ["block", "both", "sofit"].contains(preferences.frontType) {
                    HebrewText(text: preferences.frontType == "sofit" ? (letter.sofit ?? letter.hebrew) : letter.hebrew, size: 78)
                }
                if ["cursive", "both"].contains(preferences.frontType) {
                    HebrewText(text: letter.hebrew, cursive: true, size: 78)
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct FlashQuizSection: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let letters: [StudyLetter]
    let kind: String
    @State private var question: Question?
    @State private var answer: String?
    @State private var correct = 0
    @State private var total = 0
    @State private var streak = 0

    private struct Question {
        let letter: StudyLetter
        let glyph: String
        let choices: [String]
        let solution: String
        let explanation: String
    }

    var body: some View {
        Section("当前得分 \(correct) / \(total)") {
            LabeledContent("连续答对", value: String(streak))
            if let question {
                Text(prompt)
                HebrewText(text: question.glyph, cursive: kind == "cursive-to-block", size: 58)
                    .frame(maxWidth: .infinity)
                PronunciationButton(hebrew: question.letter.nameHebrew, fallback: question.letter.nameEnglish)
                ForEach(question.choices, id: \.self) { choice in
                    Button(choice) {
                        guard answer == nil else { return }
                        answer = choice
                        total += 1
                        let success = choice == question.solution
                        if success { correct += 1 }
                        streak = success ? streak + 1 : 0
                        audio.playFeedback(success ? .correct : .wrong)
                        progress.recordStudy()
                    }
                    .disabled(answer != nil)
                }
                if let answer {
                    Label(answer == question.solution ? "答对了" : "正确答案：\(question.solution)",
                          systemImage: answer == question.solution ? "checkmark.circle" : "info.circle")
                    Text(question.explanation).foregroundStyle(.secondary)
                    Button("下一题", action: next)
                }
            }
        }
        .task { next() }
        .task(id: answer) {
            guard let answer, answer == question?.solution else { return }
            try? await Task.sleep(for: .milliseconds(700))
            if !Task.isCancelled { next() }
        }
    }

    private var prompt: String {
        switch kind {
        case "cursive-to-block": "请选择手写体对应的印刷字母。"
        case "sofit-match": "请选择这个字母的词尾形。"
        case "dagesh-quiz": "请选择这个字形的现代读音。"
        default: "请选择字母名称与现代读音。"
        }
    }

    private func next() {
        let pool = letters.filter { letter in
            switch kind {
            case "sofit-match": letter.sofit != nil
            case "dagesh-quiz": letter.begadkefat != nil
            default: true
            }
        }
        let candidates = pool.filter { $0.id != question?.letter.id }
        guard let target = (candidates.isEmpty ? pool : candidates).randomElement() else { return }
        var glyph = target.hebrew
        let solution: String
        let possible: [String]
        let explanation: String
        switch kind {
        case "sofit-match":
            solution = target.sofit ?? target.hebrew
            possible = pool.compactMap(\.sofit)
            explanation = target.sofitInfo?.rule ?? "\(target.hebrew) 的词尾形是 \(solution)。"
        case "cursive-to-block":
            solution = target.hebrew
            possible = pool.map(\.hebrew)
            explanation = target.cursiveDesc
        case "dagesh-quiz":
            guard let variants = target.begadkefat else { return }
            let variant = Bool.random() ? variants.withDagesh : variants.withoutDagesh
            solution = variant.modernIpa
            glyph = variant.glyph
            possible = pool.compactMap(\.begadkefat).flatMap { [$0.withDagesh.modernIpa, $0.withoutDagesh.modernIpa] }
            explanation = "\(variant.name)：现代 \(variant.modernIpa)，古典 \(variant.biblicalIpa)。\(variants.note)"
        default:
            solution = soundLabel(target)
            possible = pool.map(soundLabel)
            explanation = target.pronunciationDesc
        }
        let distractors = Set(possible).subtracting([solution]).shuffled().prefix(3)
        question = Question(letter: target, glyph: glyph, choices: ([solution] + Array(distractors)).shuffled(),
                            solution: solution, explanation: explanation)
        answer = nil
    }

    private func soundLabel(_ letter: StudyLetter) -> String { "\(letter.nameEnglish) · \(letter.modernIpa)" }
}
