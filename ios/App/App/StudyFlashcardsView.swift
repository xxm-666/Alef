import SwiftUI

struct PracticeCenterView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent

    var body: some View {
        let due = content.dueWords(in: progress)
        StudyPage {
            StudyHeading(section: "练习", title: "把学过的，记牢")
            NavigationLink {
                WordReviewView(content: content, words: due)
            } label: {
                StudyCard(highlighted: true, padding: 10) {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
                    layout {
                        StudyRow(title: due.isEmpty ? "暂无到期单词" : "\(due.count) 个单词到期",
                                 symbol: "calendar", subtitle: due.isEmpty ? "查看复习队列" : "按计划巩固词义", chevron: false)
                        Label(due.isEmpty ? "查看队列" : "开始复习", systemImage: due.isEmpty ? "chevron.right" : "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(progress.theme.primaryButton, in: Capsule())
                    }
                }
            }
            .buttonStyle(.plain)

            StudySectionTitle("字母练习")
            NavigationLink {
                StudyFlashcardsView(content: content)
            } label: {
                StudyCard(highlighted: true, padding: 10) {
                    StudyRow(title: "字母闪卡", symbol: "rectangle.on.rectangle",
                             subtitle: "强化记忆：字形、发音与例词")
                }
            }
            .buttonStyle(.plain)
            VStack(spacing: 7) {
                ForEach(LetterQuizKind.allCases) { kind in
                    NavigationLink {
                        FlashQuizView(letters: content.letters, kind: kind)
                    } label: {
                        StudyCard(padding: 8) {
                            StudyRow(title: kind.title, symbol: kind.symbol, subtitle: kind.subtitle)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            StudySectionTitle("单词练习")
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(WordQuizKind.allCases) { kind in
                    NavigationLink {
                        WordQuizView(content: content, words: content.words, kind: kind)
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(progress.theme.accent)
                            .frame(maxWidth: .infinity, minHeight: 49)
                            .background(progress.theme.highlightedSurface, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .studyHome()
    }
}

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
    @State private var showsOptions = false

    private let scopes: [(value: String, title: String)] = [("all", "全部"), ("needs_review", "需复习"), ("sofit", "词尾形"), ("begadkefat", "达盖什")]
    private let frontStyles: [(value: String, title: String)] = [("block", "印刷体"), ("cursive", "手写体"), ("both", "印刷与手写"), ("sofit", "词尾形")]

    var body: some View {
        let cards = deck
        ScrollViewReader { scroll in
            StudyPage {
                if let current = cards[safe: index] {
                    cardProgress(count: cards.count).id("flashcard-top")
                    quickControls
                    studyCard(current)
                    if flipped {
                        cardDetails(current)
                        masteryControls(for: current)
                    }
                    cardNavigation
                } else {
                    quickControls
                    ContentUnavailableView("这个范围没有卡片", systemImage: "rectangle.on.rectangle",
                                           description: Text("可以打开闪卡选项切换范围。"))
                }
            }
            .onChange(of: cards[safe: index]?.id) { _, _ in scroll.scrollTo("flashcard-top", anchor: .top) }
        }
        .studyDetail("字母闪卡")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("闪卡选项", systemImage: "slider.horizontal.3") { showsOptions = true }
            }
        }
        .sheet(isPresented: $showsOptions) {
            NavigationStack {
                deckOptions
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("完成") { showsOptions = false } }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .onChange(of: preferences.deckScope) { _, _ in resetDeck(shuffle: false) }
        .onChange(of: preferences.frontType) { _, _ in flipped = false }
        .onDisappear { audio.stop() }
    }

    private var deckOptions: some View {
        StudyPage {
            StudySectionTitle("卡片范围")
            StudySegments(title: "卡片范围", options: scopes, selection: setting(\.deckScope))
            StudySectionTitle("正面字形")
            StudySegments(title: "正面字形", options: frontStyles, selection: setting(\.frontType))
            Button(shuffledIDs == nil ? "打乱顺序" : "恢复字母顺序",
                   systemImage: shuffledIDs == nil ? "shuffle" : "arrow.counterclockwise") {
                resetDeck(shuffle: shuffledIDs == nil)
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(deck.count < 2 && shuffledIDs == nil)
        }
        .studyDetail("闪卡选项")
    }

    private var quickControls: some View {
        let scope = scopes.first { $0.value == preferences.deckScope }?.title ?? "全部"
        let front = frontStyles.first { $0.value == preferences.frontType }?.title ?? "印刷与手写"
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            Menu {
                Picker("卡片范围", selection: setting(\.deckScope)) {
                    ForEach(scopes, id: \.value) { item in Text(item.title).tag(item.value) }
                }
            } label: {
                Text(scope).frame(minWidth: 50)
            }
            .buttonStyle(StudyButtonStyle(selected: true))
            .accessibilityLabel("卡片范围")
            .accessibilityValue(scope)
            Menu {
                Picker("正面字形", selection: setting(\.frontType)) {
                    ForEach(frontStyles, id: \.value) { item in Text(item.title).tag(item.value) }
                }
            } label: {
                Text(front).frame(minWidth: 60)
            }
            .buttonStyle(StudyButtonStyle())
            .accessibilityLabel("正面字形")
            .accessibilityValue(front)
            Button {
                resetDeck(shuffle: shuffledIDs == nil)
            } label: {
                Image(systemName: shuffledIDs == nil ? "shuffle" : "arrow.counterclockwise").frame(minWidth: 24)
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(deck.count < 2 && shuffledIDs == nil)
            .accessibilityLabel(shuffledIDs == nil ? "打乱顺序" : "恢复字母顺序")
        }
    }

    private func cardProgress(count: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1) / \(count)").font(.subheadline.weight(.semibold)).monospacedDigit()
            ProgressView(value: Double(index + 1), total: Double(count))
                .tint(progress.theme.accent)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("卡片 \(index + 1)，共 \(count) 张")
    }

    private func studyCard(_ current: StudyLetter) -> some View {
        StudyCard {
            Button(action: flip) {
                VStack(spacing: 14) {
                    flashcard(current)
                    Label(flipped ? "查看正面" : "点按翻面", systemImage: "hand.tap")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(progress.theme.mutedInk)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 180)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .padding(.horizontal, 26)
            .overlay(alignment: .topTrailing) {
                PronunciationButton(hebrew: current.nameHebrew, iconOnly: true, title: "朗读字母名")
            }
        }
    }

    private var cardNavigation: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            navigationButton("上一张", symbol: "chevron.left", offset: -1)
            navigationButton("下一张", symbol: "chevron.right", offset: 1)
        }
        .disabled(deck.count < 2)
    }

    private func navigationButton(_ title: String, symbol: String, offset: Int) -> some View {
        Button { move(offset) } label: {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle())
        .keyboardShortcut(offset < 0 ? .leftArrow : .rightArrow, modifiers: [])
    }

    private func masteryControls(for current: StudyLetter) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            MasteryPicker(value: Binding(get: { progress.letterMastery[current.id] ?? .unlearned }, set: {
                rate($0, for: current)
            }))
            Text("标记后进入下一张").font(.caption).foregroundStyle(progress.theme.mutedInk)
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
        StudyCard {
            LabeledContent("Gematria 数值", value: String(current.gematria)).font(.subheadline)
            if let example = current.examples.first { WordExampleRow(example: example) }
            DisclosureGroup("古典读音与字形") {
                LabeledContent("古典读音", value: current.biblicalIpa)
                Text(current.biblicalDiff)
                Text("\(current.meaning)。\(current.cursiveDesc)")
                Text("转写 · \(current.transliteration)")
            }
            NavigationLink {
                LetterStudyView(letter: current, content: content)
            } label: {
                StudyRow(title: "完整详情与手写", symbol: "info.circle")
            }
            .buttonStyle(.plain)
        }
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

    private func resetDeck(shuffle: Bool) {
        shuffledIDs = shuffle ? deck.shuffled().map(\.id) : nil
        setting(\.cardIndex).wrappedValue = 0
        flipped = false
    }

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
            HebrewText(text: letter.hebrew, size: 72, style: .largeTitle)
            Text("\(letter.studyName)  \(letter.modernIpa)").font(.headline).foregroundStyle(progress.theme.ink)
            Text("\(letter.nameChinese) · \(letter.nameHebrew)").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
        } else {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 20))
            layout {
                if preferences.frontType != "cursive" {
                    HebrewText(text: preferences.frontType == "sofit" ? (letter.sofit ?? letter.hebrew) : letter.hebrew,
                               size: 80, style: .largeTitle)
                }
                if ["cursive", "both"].contains(preferences.frontType) {
                    StudyCursiveLetter(letter: letter, size: 70)
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private enum LetterQuizKind: String, CaseIterable, Identifiable {
    case blockToSound, cursiveToBlock, sofitMatch, dagesh

    var id: Self { self }
    var title: String {
        switch self {
        case .blockToSound: "字形 → 发音"
        case .cursiveToBlock: "手写 → 印刷"
        case .sofitMatch: "匹配词尾"
        case .dagesh: "达盖什辨音"
        }
    }
    var subtitle: String {
        switch self {
        case .blockToSound: "看字母，选读音"
        case .cursiveToBlock: "识别手写体对应的印刷体"
        case .sofitMatch: "找出字母的词尾形式"
        case .dagesh: "区分带点和不带点的读音"
        }
    }
    var symbol: String {
        switch self {
        case .blockToSound: "speaker.wave.2"
        case .cursiveToBlock: "pencil"
        case .sofitMatch: "link"
        case .dagesh: "ellipsis"
        }
    }
}

private struct FlashQuizView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let letters: [StudyLetter]
    @Environment(\.dismiss) private var dismiss
    let kind: LetterQuizKind
    @State private var question: Question?
    @State private var answer: String?
    @State private var selection: String?
    @State private var showsSummary = false
    @State private var correct = 0
    @State private var total = 0
    @State private var streak = 0

    private struct Question {
        let letter: StudyLetter
        let glyph: String
        let choices: [String]
        let solution: String
        let explanation: String
        let modernExample: String?
    }

    var body: some View {
        ScrollViewReader { scroll in
            StudyPage {
                if showsSummary {
                    StudyQuizSummary(title: "完成字母练习", correct: correct, answered: total)
                } else if let question {
                    HStack {
                        Label("得分 \(correct) / \(total)", systemImage: "star")
                        Spacer()
                        Label("连对 \(streak)", systemImage: "flame")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.mutedInk)
                    .monospacedDigit()
                    StudyCard {
                        StudySectionTitle(prompt)
                        Group {
                            if kind == .cursiveToBlock {
                                StudyCursiveLetter(letter: question.letter, size: 70)
                            } else {
                                HebrewText(text: question.glyph, size: 70, style: .largeTitle)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        if answer != nil {
                            if let sample = question.modernExample {
                                PronunciationButton(hebrew: sample, title: "听现代音节 \(sample)", bundledOnly: true)
                            } else {
                                PronunciationButton(hebrew: question.letter.nameHebrew, title: "朗读字母名")
                            }
                        }
                    }
                    .id("flash-question")
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        StudyAnswerButton(title: choice, submitted: answer != nil,
                                          selected: selection == choice, correct: choice == question.solution,
                                          isHebrew: kind == .cursiveToBlock || kind == .sofitMatch,
                                          optionLabel: studyOptionLabel(index)) {
                            selection = choice
                        }
                    }
                    if let answer {
                        StudyQuizFeedback(correct: answer == question.solution, solution: question.solution,
                                          response: answer, explanation: question.explanation)
                            .id("flash-result")
                    }
                } else {
                    ContentUnavailableView("没有可用题目", systemImage: "rectangle.on.rectangle")
                }
            }
            .onChange(of: answer) { _, value in
                scroll.scrollTo(value == nil ? "flash-question" : "flash-result", anchor: value == nil ? .top : .bottom)
            }
        }
        .studyDetail(kind.title)
        .toolbar {
            if total > 0 && !showsSummary {
                ToolbarItem(placement: .topBarTrailing) { Button("结束") { showsSummary = true } }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsSummary {
                StudyActionBar {
                    Button { dismiss() } label: { Text("完成").frame(maxWidth: .infinity) }
                        .buttonStyle(StudyButtonStyle(prominent: true))
                }
            } else if let question {
                StudyActionBar {
                    if answer != nil {
                        Button(action: next) {
                            Label("下一题", systemImage: "arrow.right").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudyButtonStyle(prominent: true))
                    } else {
                        Button {
                            if let selection { grade(selection, solution: question.solution) }
                        } label: {
                            Label("确认答案", systemImage: "checkmark").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudyButtonStyle(prominent: true))
                        .disabled(selection == nil)
                    }
                }
            }
        }
        .task { if question == nil { next() } }
        .onDisappear { audio.stop() }
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
        case .cursiveToBlock: "请选择手写体对应的印刷字母。"
        case .sofitMatch: "请选择这个字母的词尾形。"
        case .dagesh: "请选择这个字形的现代读音。"
        default: "请选择字母名称与现代读音。"
        }
    }

    private func next() {
        let pool = letters.filter { letter in
            switch kind {
            case .sofitMatch: letter.sofit != nil
            case .dagesh: letter.begadkefat != nil
            default: true
            }
        }
        let candidates = pool.filter { $0.id != question?.letter.id }
        guard let target = (candidates.isEmpty ? pool : candidates).randomElement() else { return }
        var glyph = target.hebrew
        let solution: String
        let possible: [String]
        let explanation: String
        var modernExample: String?
        switch kind {
        case .sofitMatch:
            solution = target.sofit ?? target.hebrew
            possible = pool.compactMap(\.sofit)
            explanation = target.sofitInfo?.rule ?? "\(target.hebrew) 的词尾形是 \(solution)。"
        case .cursiveToBlock:
            solution = target.hebrew
            possible = pool.map(\.hebrew)
            explanation = target.cursiveDesc
        case .dagesh:
            guard let variants = target.begadkefat else { return }
            let variant = Bool.random() ? variants.withDagesh : variants.withoutDagesh
            solution = variant.modernIpa
            glyph = variant.glyph
            possible = pool.compactMap(\.begadkefat).flatMap { [$0.withDagesh.modernIpa, $0.withoutDagesh.modernIpa] }
            explanation = "\(variant.name)：现代 \(variant.modernIpa)，古典 \(variant.biblicalIpa)。\(variants.note)"
            modernExample = variants.modernExample(for: variant)
        default:
            solution = soundLabel(target)
            possible = pool.map(soundLabel)
            explanation = target.pronunciationDesc
        }
        let distractors = Set(possible).subtracting([solution]).shuffled().prefix(3)
        question = Question(letter: target, glyph: glyph, choices: ([solution] + Array(distractors)).shuffled(),
                            solution: solution, explanation: explanation, modernExample: modernExample)
        answer = nil
        selection = nil
    }

    private func soundLabel(_ letter: StudyLetter) -> String { "\(letter.nameEnglish) · \(letter.modernIpa)" }
}
