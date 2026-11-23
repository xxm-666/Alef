import SwiftUI

struct PracticeCenterView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent

    var body: some View {
        let due = content.dueWords(in: progress)
        let dueLetters = content.dueLetters(in: progress)
        StudyPage {
            StudyHeading(section: "练习", title: "把学过的，记牢")
            LearningPathEntry(content: content)
            DailyVocabularyEntry(content: content)
            dueWordsCard(due)
            if !dueLetters.isEmpty {
                dueLettersCard(dueLetters)
            }

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

            StudySectionTitle("听力辨音")
            NavigationLink {
                MinimalPairQuizView(content: content)
            } label: {
                StudyCard(padding: 10) {
                    StudyRow(title: "易混音辨析（最小对立对）", symbol: "ear",
                             subtitle: "对比 ח/ה、ב/פ、ס/שׁ、ק/ג 等高频混音",
                             value: "\(content.minimalPairs.count) 组")
                }
            }
            .buttonStyle(.plain)
        }
        .studyHome()
    }

    private func dueWordsCard(_ due: [StudyWord]) -> some View {
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
                        .foregroundStyle(due.isEmpty ? progress.theme.accent : Color.white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(due.isEmpty ? progress.theme.insetSurface : progress.theme.learningAction, in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func dueLettersCard(_ dueLetters: [StudyLetter]) -> some View {
        NavigationLink {
            LetterReviewView(letters: dueLetters, allLetters: content.letters)
        } label: {
            StudyCard(highlighted: true, padding: 10) {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    StudyRow(title: "\(dueLetters.count) 个字母到期",
                             symbol: "calendar.badge.clock", subtitle: "巩固字母字形与读音", chevron: false)
                    Label("开始复习", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(progress.theme.learningAction, in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
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

    private let scopes: [(value: String, title: String)] = [
        ("all", "全部"), ("due_srs", "到期复习"), ("needs_review", "需复习"), ("sofit", "词尾形"), ("begadkefat", "达盖什")
    ]
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
        let existing = progress.letterSchedule[current.id]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 2 : 4)
        return VStack(alignment: .leading, spacing: 6) {
            if let existing {
                Text("下次复习 · \(existing.displayDate)（间隔 \(existing.intervalDays) 天）")
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(ReviewGrade.allCases) { grade in
                    let preview = ReviewSchedule.next(from: existing, grade: grade, on: .now)
                    Button {
                        rate(grade, for: current)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: grade.symbol)
                                .font(.caption.weight(.semibold))
                            Text(grade.title)
                                .font(.caption.weight(.semibold))
                            Text("\(preview.intervalDays)天")
                                .font(.caption2)
                                .foregroundStyle(progress.theme.mutedInk)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(StudyButtonStyle(selected: grade == .good))
                }
            }
            Text("自评后自动进入下一张并安排下次复习").font(.caption).foregroundStyle(progress.theme.mutedInk)
        }
    }

    private func rate(_ grade: ReviewGrade, for current: StudyLetter) {
        let cards = deck
        let following = cards.isEmpty ? nil : cards[safe: (index + 1) % cards.count]?.id
        audio.playSelectionHaptic()
        progress.completeLetterReview(current.id, grade: grade)
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
        let filtered: [StudyLetter]
        if preferences.deckScope == "due_srs" {
            filtered = content.dueLetters(in: progress)
        } else {
            filtered = content.letters.filter { letter in
                switch preferences.deckScope {
                case "needs_review": mastery[letter.id] != .mastered
                case "sofit": letter.sofit != nil
                case "begadkefat": letter.begadkefat != nil
                default: true
                }
            }
        }
        if preferences.deckScope == "due_srs" && shuffledIDs == nil {
            return filtered
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

private struct LetterReviewView: View {
    let letters: [StudyLetter]
    let allLetters: [StudyLetter]

    var body: some View {
        FlashQuizView(letters: letters, allLetters: allLetters, kind: .blockToSound, reviewing: true)
    }
}

private struct FlashQuizView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let letters: [StudyLetter]
    let allLetters: [StudyLetter]
    @Environment(\.dismiss) private var dismiss
    let kind: LetterQuizKind
    var reviewing = false
    @State private var question: Question?
    @State private var answer: String?
    @State private var selection: String?
    @State private var showsSummary = false
    @State private var correct = 0
    @State private var total = 0
    @State private var streak = 0
    @State private var queue: [StudyLetter] = []
    @State private var reviewIndex = 0
    @State private var requeuedIds: Set<String> = []
    @State private var requeuedThisTurn = false
    @State private var preAnswerSchedule: ReviewSchedule?
    @State private var selectedGrade: ReviewGrade?
    @State private var answeredDate: Date = .now
    @State private var started = false

    init(letters: [StudyLetter], allLetters: [StudyLetter]? = nil, kind: LetterQuizKind, reviewing: Bool = false) {
        self.letters = letters
        self.allLetters = allLetters ?? letters
        self.kind = kind
        self.reviewing = reviewing
    }

    private struct Question {
        let kind: LetterQuizKind
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
                    summary
                } else if let question {
                    quizHeader
                    questionCard(question).id("flash-question")
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        StudyAnswerButton(title: choice, submitted: answer != nil,
                                          selected: selection == choice, correct: choice == question.solution,
                                          isHebrew: question.kind == .cursiveToBlock || question.kind == .sofitMatch,
                                          optionLabel: studyOptionLabel(index)) {
                            selection = choice
                        }
                    }
                    if let answer {
                        feedbackView(question, answer: answer).id("flash-result")
                    }
                } else if started {
                    ContentUnavailableView(reviewing ? "没有到期的字母" : "没有可用题目",
                                           systemImage: reviewing ? "calendar.badge.checkmark" : "rectangle.on.rectangle")
                }
            }
            .onChange(of: answer) { _, value in
                scroll.scrollTo(value == nil ? "flash-question" : "flash-result", anchor: value == nil ? .top : .bottom)
            }
        }
        .studyDetail(reviewing ? "到期字母复习" : kind.title)
        .toolbar {
            if !reviewing && total > 0 && !showsSummary {
                ToolbarItem(placement: .topBarTrailing) { Button("结束") { showsSummary = true } }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if started { bottomBar }
        }
        .task {
            guard !started else { return }
            started = true
            queue = letters
            next()
        }
        .onDisappear { audio.stop() }
    }

    private var quizHeader: some View {
        HStack(spacing: 9) {
            if reviewing {
                Text("\(reviewIndex + 1) / \(queue.count)").font(.subheadline.weight(.semibold))
                ProgressView(value: Double(reviewIndex + 1), total: Double(max(1, queue.count)))
                    .tint(progress.theme.accent)
                    .frame(minWidth: 38, maxWidth: 160)
                    .accessibilityLabel("复习进度")
            }
            Label("得分 \(correct) / \(total)", systemImage: "star")
            Spacer()
            if !reviewing {
                Label("连对 \(streak)", systemImage: "flame")
                    .foregroundStyle(progress.theme.reminder)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(progress.theme.mutedInk)
        .monospacedDigit()
    }

    private func questionCard(_ question: Question) -> some View {
        StudyCard {
            StudySectionTitle(prompt(for: question.kind))
            Group {
                if question.kind == .cursiveToBlock {
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
    }

    @ViewBuilder private func feedbackView(_ question: Question, answer: String) -> some View {
        let success = answer == question.solution
        VStack(alignment: .leading, spacing: 8) {
            StudyQuizFeedback(correct: success, solution: question.solution,
                              response: answer, explanation: question.explanation)
            if reviewing && !success && requeuedThisTurn {
                StudyNotice(title: "已加入本轮末尾再练一次", symbol: "arrow.counterclockwise", reminder: true)
            }
            if reviewing, let schedule = progress.letterSchedule[question.letter.id] {
                StudyNotice(title: "下次复习 · \(schedule.displayDate)", symbol: "calendar",
                            note: "当前间隔 \(schedule.intervalDays) 天")
                if success {
                    reviewGradeBar(for: question.letter)
                }
            }
        }
    }

    private func reviewGradeBar(for letter: StudyLetter) -> some View {
        HStack(spacing: 6) {
            ForEach([ReviewGrade.hard, .good, .easy]) { grade in
                let preview = ReviewSchedule.next(from: preAnswerSchedule, grade: grade, on: answeredDate)
                Button {
                    selectedGrade = grade
                    audio.playSelectionHaptic()
                    progress.adjustLetterReview(letter.id, base: preAnswerSchedule, grade: grade, date: answeredDate)
                } label: {
                    VStack(spacing: 2) {
                        Text(grade.title).font(.caption.weight(.semibold))
                        Text("\(preview.intervalDays)天").font(.caption2).foregroundStyle(progress.theme.mutedInk)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(StudyButtonStyle(selected: selectedGrade == grade))
            }
        }
    }

    private var summary: some View {
        let nextReview = queue.compactMap { progress.letterSchedule[$0.id] }.min { $0.nextReviewAt < $1.nextReviewAt }
        return StudyQuizSummary(title: reviewing ? "完成字母复习" : "完成字母练习", correct: correct, answered: total,
                                message: reviewing ? nextReview.map { "下次复习 · \($0.displayDate)" } : nil)
    }

    @ViewBuilder private var bottomBar: some View {
        if showsSummary {
            StudyActionBar {
                Button { dismiss() } label: { Text("完成").frame(maxWidth: .infinity) }
                    .buttonStyle(StudyButtonStyle(prominent: true))
            }
        } else if let question {
            StudyActionBar {
                if answer != nil {
                    let finishing = reviewing && reviewIndex + 1 >= queue.count
                    Button {
                        if finishing { showsSummary = true }
                        else {
                            if reviewing { reviewIndex += 1 }
                            next()
                        }
                    } label: {
                        Label(finishing ? "查看复习结果" : "下一题", systemImage: "arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(learningAction: true))
                } else {
                    Button {
                        if let selection { grade(selection, solution: question.solution) }
                    } label: {
                        Label("确认答案", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(learningAction: true))
                    .disabled(selection == nil)
                }
            }
        } else {
            StudyActionBar {
                Button { dismiss() } label: { Text("返回").frame(maxWidth: .infinity) }
                    .buttonStyle(StudyButtonStyle(prominent: true))
            }
        }
    }

    private func grade(_ choice: String, solution: String) {
        guard answer == nil, let question else { return }
        answer = choice
        total += 1
        let success = choice == solution
        if success { correct += 1 }
        streak = success ? streak + 1 : 0
        if reviewing {
            let now = Date.now
            let grade: ReviewGrade = success ? .good : .again
            preAnswerSchedule = progress.letterSchedule[question.letter.id]
            answeredDate = now
            selectedGrade = grade
            progress.completeLetterReview(question.letter.id, grade: grade, date: now)
            if !success && requeuedIds.insert(question.letter.id).inserted {
                queue.append(question.letter)
                requeuedThisTurn = true
            }
        } else {
            progress.recordStudy()
        }
        audio.playFeedback(success ? .correct : .wrong)
    }

    private func prompt(for kind: LetterQuizKind) -> String {
        switch kind {
        case .cursiveToBlock: "请选择手写体对应的印刷字母。"
        case .sofitMatch: "请选择这个字母的词尾形。"
        case .dagesh: "请选择这个字形的现代读音。"
        default: "请选择字母名称与现代读音。"
        }
    }

    private func questionKind(for letter: StudyLetter, index: Int) -> LetterQuizKind {
        guard reviewing else { return kind }
        var supported: [LetterQuizKind] = [.blockToSound, .cursiveToBlock]
        if letter.sofit != nil { supported.append(.sofitMatch) }
        if letter.begadkefat != nil { supported.append(.dagesh) }
        return supported[index % supported.count]
    }

    private func next() {
        let target: StudyLetter
        if reviewing {
            guard queue.indices.contains(reviewIndex) else {
                question = nil
                return
            }
            target = queue[reviewIndex]
        } else {
            let pool = allLetters.filter { letter in
                switch kind {
                case .sofitMatch: letter.sofit != nil
                case .dagesh: letter.begadkefat != nil
                default: true
                }
            }
            let candidates = pool.filter { $0.id != question?.letter.id }
            guard let picked = (candidates.isEmpty ? pool : candidates).randomElement() else { return }
            target = picked
        }

        let activeKind = questionKind(for: target, index: reviewIndex)
        let distractorPool = allLetters.filter { letter in
            switch activeKind {
            case .sofitMatch: letter.sofit != nil
            case .dagesh: letter.begadkefat != nil
            default: true
            }
        }

        var glyph = target.hebrew
        let solution: String
        let possible: [String]
        let explanation: String
        var modernExample: String?
        switch activeKind {
        case .sofitMatch:
            solution = target.sofit ?? target.hebrew
            possible = distractorPool.compactMap(\.sofit)
            explanation = target.sofitInfo?.rule ?? "\(target.hebrew) 的词尾形是 \(solution)。"
        case .cursiveToBlock:
            solution = target.hebrew
            possible = distractorPool.map(\.hebrew)
            explanation = target.cursiveDesc
        case .dagesh:
            guard let variants = target.begadkefat else { return }
            let variant = Bool.random() ? variants.withDagesh : variants.withoutDagesh
            solution = variant.modernIpa
            glyph = variant.glyph
            possible = distractorPool.compactMap(\.begadkefat).flatMap { [$0.withDagesh.modernIpa, $0.withoutDagesh.modernIpa] }
            explanation = "\(variant.name)：现代 \(variant.modernIpa)，古典 \(variant.biblicalIpa)。\(variants.note)"
            modernExample = variants.modernExample(for: variant)
        default:
            solution = soundLabel(target)
            possible = distractorPool.map(soundLabel)
            explanation = target.pronunciationDesc
        }
        let distractors = Set(possible).subtracting([solution]).shuffled().prefix(3)
        question = Question(kind: activeKind, letter: target, glyph: glyph, choices: ([solution] + Array(distractors)).shuffled(),
                            solution: solution, explanation: explanation, modernExample: modernExample)
        answer = nil
        selection = nil
        requeuedThisTurn = false
        preAnswerSchedule = nil
        selectedGrade = nil
    }

    private func soundLabel(_ letter: StudyLetter) -> String { "\(letter.nameEnglish) · \(letter.modernIpa)" }
}

private struct MinimalPairQuizView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dismiss) private var dismiss
    let content: StudyContent

    private struct Question {
        let pair: StudyMinimalPair
        let target: StudyWord
        let other: StudyWord
        let choices: [StudyWord]
    }

    @State private var question: Question?
    @State private var selectedId: String?
    @State private var submittedId: String?
    @State private var correct = 0
    @State private var total = 0
    @State private var streak = 0
    @State private var showsSummary = false

    private var wordsById: [String: StudyWord] {
        Dictionary(uniqueKeysWithValues: content.words.map { ($0.id, $0) })
    }

    var body: some View {
        ScrollViewReader { scroll in
            StudyPage {
                if showsSummary {
                    StudyQuizSummary(title: "完成辨音练习", correct: correct, answered: total)
                } else if let question {
                    headerStatus
                    promptCard(question).id("mp-question")
                    ForEach(Array(question.choices.enumerated()), id: \.element.id) { index, choice in
                        StudyAnswerButton(
                            title: "\(choice.hebrew) · \(choice.meaningZh)",
                            submitted: submittedId != nil,
                            selected: selectedId == choice.id,
                            correct: choice.id == question.target.id,
                            optionLabel: studyOptionLabel(index)
                        ) {
                            selectedId = choice.id
                        }
                    }
                    if let submittedId {
                        feedbackSection(question, submittedId: submittedId).id("mp-result")
                    }
                } else {
                    ContentUnavailableView("暂无可用辨音词对", systemImage: "ear")
                }
            }
            .onChange(of: submittedId) { _, value in
                scroll.scrollTo(value == nil ? "mp-question" : "mp-result", anchor: value == nil ? .top : .bottom)
            }
        }
        .studyDetail("易混音辨析")
        .toolbar {
            if total > 0 && !showsSummary {
                ToolbarItem(placement: .topBarTrailing) { Button("结束") { showsSummary = true } }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .task {
            if question == nil { next(play: false) }
        }
        .onDisappear { audio.stop() }
    }

    private var headerStatus: some View {
        HStack {
            Label("得分 \(correct) / \(total)", systemImage: "star")
            Spacer()
            Label("连对 \(streak)", systemImage: "flame")
                .foregroundStyle(progress.theme.reminder)
            if submittedId == nil {
                Button { next(play: true) } label: {
                    Image(systemName: "arrow.clockwise").frame(minWidth: 24)
                }
                .buttonStyle(StudyButtonStyle())
                .accessibilityLabel("换一组")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(progress.theme.mutedInk)
        .monospacedDigit()
    }

    private func promptCard(_ question: Question) -> some View {
        StudyCard(highlighted: true) {
            HStack {
                StudySectionTitle("听读音，选出听到的是哪一个词")
                Spacer(minLength: 4)
                Text(question.pair.contrast)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(progress.theme.cardSurface, in: Capsule())
            }
            PronunciationButton(hebrew: question.target.hebrew, title: "播放题目发音", prominent: true, bundledOnly: true)
        }
    }

    private func feedbackSection(_ question: Question, submittedId: String) -> some View {
        let success = submittedId == question.target.id
        let chosen = question.choices.first { $0.id == submittedId }
        return VStack(alignment: .leading, spacing: 8) {
            StudyQuizFeedback(
                correct: success,
                solution: "\(question.target.hebrew) · \(question.target.meaningZh)（\(question.target.ipa)）",
                response: chosen.map { "\($0.hebrew) · \($0.meaningZh)" },
                explanation: question.pair.tip
            )
            StudyCard(padding: 10) {
                StudySectionTitle("对比试听")
                comparisonRow(question.target, isTarget: true)
                Divider()
                comparisonRow(question.other, isTarget: false)
            }
        }
    }

    private func comparisonRow(_ word: StudyWord, isTarget: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    HebrewText(text: word.hebrew, size: 24)
                    Text(word.ipa).font(.caption).foregroundStyle(progress.theme.mutedInk)
                    if isTarget {
                        Text("本题读音")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(progress.theme.accent)
                    }
                }
                Text("\(word.transliteration) · \(word.meaningZh)")
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
            }
            Spacer(minLength: 0)
            PronunciationButton(hebrew: word.hebrew, iconOnly: true, bundledOnly: true)
        }
    }

    @ViewBuilder private var bottomBar: some View {
        if showsSummary {
            StudyActionBar {
                Button { dismiss() } label: { Text("完成").frame(maxWidth: .infinity) }
                    .buttonStyle(StudyButtonStyle(prominent: true))
            }
        } else if let question {
            StudyActionBar {
                if submittedId != nil {
                    Button { next(play: true) } label: {
                        Label("下一组", systemImage: "arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(learningAction: true))
                } else {
                    Button { confirm(question) } label: {
                        Label("确认答案", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(learningAction: true))
                    .disabled(selectedId == nil)
                }
            }
        }
    }

    private func confirm(_ question: Question) {
        guard submittedId == nil, let selectedId else { return }
        submittedId = selectedId
        total += 1
        let success = selectedId == question.target.id
        if success { correct += 1 }
        streak = success ? streak + 1 : 0
        progress.recordStudy()
        audio.playFeedback(success ? .correct : .wrong)
    }

    private func next(play: Bool) {
        let lookup = wordsById
        let validPairs = content.minimalPairs.filter {
            lookup[$0.firstWordId] != nil && lookup[$0.secondWordId] != nil
        }
        let candidates = validPairs.filter { $0.id != question?.pair.id }
        guard let pair = (candidates.isEmpty ? validPairs : candidates).randomElement(),
              let first = lookup[pair.firstWordId],
              let second = lookup[pair.secondWordId] else {
            question = nil
            return
        }
        let targetFirst = Bool.random()
        let target = targetFirst ? first : second
        let other = targetFirst ? second : first
        question = Question(pair: pair, target: target, other: other, choices: [target, other].shuffled())
        selectedId = nil
        submittedId = nil
        if play {
            audio.speak(target.hebrew, rate: progress.speechRate, bundledOnly: true)
        }
    }
}
