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
            Picker("练习方式", selection: setting(\.subMode)) {
                Text("翻卡").tag("flip")
                Text("测验").tag("quiz")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)

            if isQuiz {
                Form {
                    Picker("题型", selection: setting(\.quizType)) {
                        Text("字形 → 发音").tag("block-to-sound")
                        Text("手写 → 印刷").tag("cursive-to-block")
                        Text("匹配词尾").tag("sofit-match")
                        Text("达盖什辨音").tag("dagesh-quiz")
                    }
                    FlashQuizSection(letters: content.letters, kind: preferences.quizType)
                        .id(preferences.quizType)
                }
                .contentMargins(.vertical, 12, for: .scrollContent)
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
                            masteryControls(for: current)
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
                if current != nil {
                    cardNavigation
                        .frame(maxWidth: 560)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .systemGroupedBackground))
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
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button { move(-1) } label: {
                Label("上一张", systemImage: "chevron.left").frame(maxWidth: .infinity, minHeight: 30)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            Button { move(1) } label: {
                Label("下一张", systemImage: "chevron.right").frame(maxWidth: .infinity, minHeight: 30)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(deck.count < 2)
    }

    private func masteryControls(for current: StudyLetter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标记掌握度").font(.subheadline.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(Mastery.allCases) { level in
                        masteryButton(level, for: current).fixedSize(horizontal: true, vertical: false)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Mastery.allCases) { level in masteryButton(level, for: current) }
                }
            }
        }
    }

    private func masteryButton(_ level: Mastery, for current: StudyLetter) -> some View {
        Button {
            let cards = deck
            let following = cards.isEmpty ? nil : cards[safe: (index + 1) % cards.count]?.id
            progress.setLetter(current.id, mastery: level)
            let next = deck.firstIndex { $0.id == following } ?? 0
            setting(\.cardIndex).wrappedValue = next
            flipped = false
        } label: {
            Label(level.title, systemImage: level.symbol)
        }
        .buttonStyle(.bordered)
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
