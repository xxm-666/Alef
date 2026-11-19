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
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @State private var flipped = false
    @State private var shuffledIDs: [String]?

    private let scopes = [("all", "全部"), ("needs_review", "需复习"), ("sofit", "词尾形"), ("begadkefat", "达盖什")]
    private let frontStyles = [("block", "印刷体"), ("cursive", "手写体"), ("both", "印刷与手写"), ("sofit", "词尾形")]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if typeSize.isAccessibilitySize { modePicker.pickerStyle(.menu) }
                else { modePicker.pickerStyle(.segmented) }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)

            if isQuiz {
                quizOptions
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 44)
                FlashQuizView(letters: content.letters, kind: preferences.quizType)
                    .id(preferences.quizType)
            } else {
                deckView
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("闪卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isQuiz {
                ToolbarItem(placement: .topBarTrailing) {
                    deckOptions
                }
            }
        }
        .onChange(of: preferences.deckScope) { _, _ in
            shuffledIDs = nil
            setting(\.cardIndex).wrappedValue = 0
            flipped = false
        }
        .onChange(of: preferences.frontType) { _, _ in flipped = false }
    }

    private var isQuiz: Bool { preferences.subMode == "quiz" }

    private var modePicker: some View {
        Picker("练习方式", selection: setting(\.subMode)) {
            Text("翻卡").tag("flip")
            Text("测验").tag("quiz")
        }
    }

    private var quizOptions: some View {
        Picker("题型", selection: setting(\.quizType)) {
            Text("字形 → 发音").tag("block-to-sound")
            Text("手写 → 印刷").tag("cursive-to-block")
            Text("匹配词尾").tag("sofit-match")
            Text("达盖什辨音").tag("dagesh-quiz")
        }
        .pickerStyle(.menu)
    }

    private var deckOptions: some View {
        Menu {
            Picker("卡片范围", selection: setting(\.deckScope)) {
                ForEach(scopes, id: \.0) { key, title in Text(title).tag(key) }
            }
            Picker("正面字形", selection: setting(\.frontType)) {
                ForEach(frontStyles, id: \.0) { key, title in Text(title).tag(key) }
            }
            Section {
                Button("打乱顺序", systemImage: "shuffle") {
                    shuffledIDs = deck.shuffled().map(\.id)
                    setting(\.cardIndex).wrappedValue = 0
                    flipped = false
                }
                .disabled(deck.count < 2)
                if shuffledIDs != nil {
                    Button("恢复字母顺序", systemImage: "arrow.counterclockwise") {
                        shuffledIDs = nil
                        setting(\.cardIndex).wrappedValue = 0
                        flipped = false
                    }
                }
            }
        } label: {
            Label("闪卡选项", systemImage: "slider.horizontal.3")
        }
    }

    private var deckView: some View {
        let cards = deck
        let current = cards[safe: index]
        return ScrollViewReader { scroll in
            ScrollView {
                if let current {
                    VStack(alignment: .leading, spacing: 16) {
                        cardProgress(count: cards.count)
                        studyCard(current)
                        if flipped {
                            cardDetails(current)
                        }
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .id("flashcard-top")
                } else {
                    ContentUnavailableView("这个范围没有卡片", systemImage: "rectangle.on.rectangle",
                                           description: Text("可以在右上角切换卡片范围。"))
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .contentMargins(.vertical, 12, for: .scrollContent)
            .onChange(of: current?.id) { _, _ in scroll.scrollTo("flashcard-top", anchor: .top) }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let current {
                    StudyActionBar {
                        VStack(spacing: 8) {
                            if flipped { masteryControls(for: current) }
                            cardNavigation
                        }
                    }
                }
            }
        }
    }

    private func cardProgress(count: Int) -> some View {
        let countText = Text("卡片 \(index + 1) / \(count)").font(.subheadline.weight(.semibold)).monospacedDigit()
        let scope = scopes.first { $0.0 == preferences.deckScope }?.1 ?? "全部"
        let front = frontStyles.first { $0.0 == preferences.frontType }?.1 ?? "印刷与手写"
        let optionsText = Text("\(scope) · \(front)").font(.caption).foregroundColor(.secondary)
        return VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    countText.fixedSize()
                    Spacer()
                    optionsText.fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    countText
                    optionsText
                }
            }
            ProgressView(value: Double(index + 1), total: Double(count)).accessibilityHidden(true)
        }
    }

    private func studyCard(_ current: StudyLetter) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22)
        return VStack(spacing: 0) {
            Button(action: flip) {
                VStack(spacing: 12) {
                    flashcard(current)
                    Label(flipped ? "查看正面" : "翻到答案", systemImage: "arrow.left.arrow.right")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 176)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            Divider().padding(.horizontal, 16)
            PronunciationButton(hebrew: current.nameHebrew, fallback: current.nameEnglish, minimumHitSize: 44)
                .padding(.vertical, 4)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
        .overlay { shape.strokeBorder(Color(uiColor: .separator).opacity(0.4), lineWidth: 1).allowsHitTesting(false) }
    }

    private var cardNavigation: some View {
        HStack(spacing: 12) {
            navigationButton("上一张", symbol: "chevron.left", offset: -1)
            navigationButton("下一张", symbol: "chevron.right", offset: 1)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(deck.count < 2)
    }

    private func navigationButton(_ title: String, symbol: String, offset: Int) -> some View {
        Button { move(offset) } label: {
            HStack {
                Image(systemName: symbol)
                if !typeSize.isAccessibilitySize { Text(title) }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .accessibilityLabel(title)
        .keyboardShortcut(offset < 0 ? .leftArrow : .rightArrow, modifiers: [])
    }

    private func masteryControls(for current: StudyLetter) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(Mastery.allCases) { level in
                    Button {
                        rate(level, for: current)
                    } label: {
                        Text(level.title).frame(minHeight: 32)
                    }
                    .accessibilityLabel("标记为\(level.title)")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .fixedSize(horizontal: true, vertical: false)
            Menu {
                ForEach(Mastery.allCases) { level in
                    Button(level.title, systemImage: level.symbol) { rate(level, for: current) }
                }
            } label: {
                Label("标记掌握度", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func rate(_ level: Mastery, for current: StudyLetter) {
        let cards = deck
        let following = cards.isEmpty ? nil : cards[safe: (index + 1) % cards.count]?.id
        progress.setLetter(current.id, mastery: level)
        let next = deck.firstIndex { $0.id == following } ?? 0
        setting(\.cardIndex).wrappedValue = next
        flipped = false
    }

    private func cardDetails(_ current: StudyLetter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("古典读音", value: current.biblicalIpa)
            Text(current.biblicalDiff).foregroundStyle(.secondary)
            Text("\(current.meaning)。\(current.cursiveDesc)")
            Text("字母数值 \(current.gematria) · 转写 \(current.transliteration)").font(.footnote).foregroundStyle(.secondary)
            if let example = current.examples.first {
                Divider()
                WordExampleRow(example: example)
            }
            NavigationLink {
                LetterStudyView(letter: current, content: content)
            } label: {
                Label("完整详情与手写", systemImage: "pencil.and.outline")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
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
            HebrewText(text: letter.nameHebrew, size: 48).foregroundStyle(.tint)
            Text("\(letter.nameChinese) · \(letter.nameEnglish)").font(.headline)
            Text("\(letter.modernIpa) · \(letter.modernSound)").font(.subheadline).foregroundStyle(.secondary)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                if ["block", "both", "sofit"].contains(preferences.frontType) {
                    HebrewText(text: preferences.frontType == "sofit" ? (letter.sofit ?? letter.hebrew) : letter.hebrew, size: 84)
                        .foregroundStyle(.tint)
                }
                if ["cursive", "both"].contains(preferences.frontType) {
                    HebrewText(text: letter.hebrew, cursive: true, size: 76)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct FlashQuizView: View {
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
        VStack(spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("得分 \(correct) / \(total)").fixedSize()
                    Spacer()
                    Text("连续答对 \(streak)").fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("得分 \(correct) / \(total)")
                    Text("连续答对 \(streak)")
                }
            }
            .font(.subheadline)
            .monospacedDigit()
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)

            ScrollViewReader { scroll in
                List {
                    if let question {
                        Section {
                            VStack(spacing: 8) {
                                Text(prompt).font(.headline).multilineTextAlignment(.center)
                                HebrewText(text: question.glyph, cursive: kind == "cursive-to-block", size: 58, style: .largeTitle)
                                    .foregroundStyle(.tint)
                                PronunciationButton(hebrew: question.letter.nameHebrew, fallback: question.letter.nameEnglish,
                                                    minimumHitSize: 44)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .id("flash-question")

                            ForEach(question.choices, id: \.self) { choice in
                                StudyAnswerButton(title: choice, submitted: answer != nil,
                                                  selected: answer == choice, correct: choice == question.solution) {
                                    grade(choice, solution: question.solution)
                                }
                            }
                        }
                        if let answer {
                            Section("答题结果") {
                                Label(answer == question.solution ? "答对了" : "正确答案 · \(question.solution)",
                                      systemImage: answer == question.solution ? "checkmark.circle" : "info.circle")
                                Text(question.explanation).foregroundStyle(.secondary)
                            }
                            .id("flash-result")
                        }
                    } else {
                        ContentUnavailableView("没有可用题目", systemImage: "rectangle.on.rectangle")
                    }
                }
                .contentMargins(.vertical, 8, for: .scrollContent)
                .onChange(of: question?.letter.id) { _, _ in scroll.scrollTo("flash-question", anchor: .top) }
                .onChange(of: answer) { _, value in
                    if value != nil { scroll.scrollTo("flash-result", anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if answer != nil {
                StudyActionBar {
                    Button(action: next) {
                        Label("下一题", systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .task { if question == nil { next() } }
    }

    private func grade(_ choice: String, solution: String) {
        guard answer == nil else { return }
        answer = choice
        total += 1
        let success = choice == solution
        if success { correct += 1 }
        streak = success ? streak + 1 : 0
        audio.playFeedback(success ? .correct : .wrong)
        progress.recordStudy()
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
