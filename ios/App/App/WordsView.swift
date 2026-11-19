import SwiftUI

private struct WordPreferences: Codable {
    var searchQuery = ""
    var activeFilter = "all"
    var initialLetter = "all"
    var sortOrder = "default"
    var showNiqqud = true
    var showCursive = false
    var mode = "browse"
    var mobileSubView: String? = nil
    var selectedWordId = "shalom"
    var cardsPage = 1
    var scrollTop: Double = 0
}

struct WordsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @State private var phraseCategory = "all"
    @State private var hidePhraseTranslation = false
    @State private var reviewWords: [StudyWord]?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if typeSize.isAccessibilitySize {
                    modePicker.pickerStyle(.menu)
                } else {
                    modePicker.pickerStyle(.segmented)
                }
                if ["browse", "cards"].contains(mode) && !dueWords.isEmpty {
                    Button(action: startReview) {
                        Label("复习到期单词（\(dueWords.count)）", systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                }
                if ["browse", "cards"].contains(mode),
                   preferences.activeFilter != "all" || preferences.initialLetter != "all" {
                    filterStatus
                }
                if mode == "phrases" { phraseControls }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            Divider()
            switch mode {
            case "phrases": phrases
            case "reading": readings
            case "quiz":
                WordQuizView(words: reviewWords ?? (isReviewing ? dueWords : filteredWords),
                             distractors: content.words, letters: content.letters, showNiqqud: preferences.showNiqqud,
                             reviewing: isReviewing, onFinishReview: finishReview)
                    .id(isReviewing)
            case "cards": cards
            default: library
            }
        }
        .background(progress.theme.canvas)
        .navigationTitle("词库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("显示元音点", isOn: setting(\.showNiqqud))
                    Toggle("手写体", isOn: setting(\.showCursive))
                    if ["browse", "cards"].contains(mode) {
                        Menu("筛选单词") {
                            Picker("词表范围", selection: setting(\.activeFilter)) {
                                Text("全部").tag("all")
                                Text("我的收藏").tag("favorites")
                                Text("需复习").tag("needs_review")
                                Text("到期复习").tag("due_srs")
                                ForEach(content.wordCategories.keys.sorted(), id: \.self) { key in
                                    Text(content.wordCategories[key]?.label ?? key).tag(key)
                                }
                            }
                        }
                        Picker("排序", selection: setting(\.sortOrder)) {
                            Text("默认").tag("default")
                            Text("字母顺序").tag("alpha")
                        }
                        Menu("首字母") {
                            Picker("首字母", selection: setting(\.initialLetter)) {
                                Text("不限").tag("all")
                                ForEach(content.letters) { letter in Text(letter.hebrew).tag(letter.hebrew) }
                            }
                        }
                    }
                } label: {
                    Label("词库选项", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var mode: String { reviewWords == nil ? preferences.mode : "quiz" }
    private var modePicker: some View {
        Picker("学习方式", selection: Binding(get: { mode }, set: { mode in
            reviewWords = nil
            setting(\.mode).wrappedValue = mode
        })) {
            Text("词表").tag("browse")
            Text("卡片").tag("cards")
            Text("短语").tag("phrases")
            Text("阅读").tag("reading")
            Text("测验").tag("quiz")
        }
    }

    private var isReviewing: Bool {
        mode == "quiz" && (reviewWords != nil || preferences.activeFilter == "due_srs")
    }

    private func startReview() {
        reviewWords = dueWords
    }

    private func finishReview() {
        var state = preferences
        if state.activeFilter == "due_srs" { state.activeFilter = "all" }
        state.mode = "browse"
        reviewWords = nil
        progress.write(state, for: "alef.wordsState.v1")
    }

    private var filterStatus: some View {
        let filter = switch preferences.activeFilter {
        case "favorites": "我的收藏"
        case "needs_review": "需复习"
        case "due_srs": "到期复习"
        case "all": "全部单词"
        default: content.wordCategories[preferences.activeFilter]?.label ?? preferences.activeFilter
        }
        let initial = preferences.initialLetter
        return HStack {
            Text(initial == "all" ? filter : "\(filter) · 首字母 \(initial)")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button("清除筛选") {
                var state = preferences
                state.activeFilter = "all"
                state.initialLetter = "all"
                progress.write(state, for: "alef.wordsState.v1")
            }
            .frame(minHeight: 44)
        }
    }

    private var preferences: WordPreferences { progress.read("alef.wordsState.v1", default: WordPreferences()) }

    private var dueWords: [StudyWord] {
        let schedule = progress.schedule
        return content.words.filter { schedule[$0.id]?.isDue == true }.sorted {
            (schedule[$0.id]?.nextReviewAt ?? 0) < (schedule[$1.id]?.nextReviewAt ?? 0)
        }
    }

    private func setting<Value>(_ path: WritableKeyPath<WordPreferences, Value>) -> Binding<Value> {
        Binding(get: { preferences[keyPath: path] }, set: { value in
            var state = preferences
            state[keyPath: path] = value
            progress.write(state, for: "alef.wordsState.v1")
        })
    }

    private var filteredWords: [StudyWord] {
        let settings = preferences
        let favorites = Set(progress.favorites)
        let mastery = progress.wordMastery
        let schedule = progress.schedule
        let query = settings.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = content.words.filter { word in
            let include = switch settings.activeFilter {
            case "all": true
            case "favorites": favorites.contains(word.id)
            case "needs_review": mastery[word.id] != .mastered
            case "due_srs": schedule[word.id]?.isDue == true
            default: word.category == settings.activeFilter
            }
            let searchable = [word.hebrew, word.hebrewUnpointed, word.transliteration, word.meaningZh, word.root ?? "", word.ipa]
            return include && (settings.initialLetter == "all" || word.hebrewUnpointed.hasPrefix(settings.initialLetter))
                && (query.isEmpty || searchable.contains { $0.localizedStandardContains(query) })
        }
        return settings.sortOrder == "alpha" ? words.sorted { $0.hebrewUnpointed < $1.hebrewUnpointed } : words
    }

    private var library: some View {
        List {
            if filteredWords.isEmpty { ContentUnavailableView.search(text: preferences.searchQuery) }
            ForEach(filteredWords) { word in
                HStack(spacing: 4) {
                    wordLink(word)
                    wordSpeaker(word)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button { progress.toggleFavorite(word.id) } label: { favoriteLabel(word) }
                        .tint(.orange)
                }
                .contextMenu { wordActions(word) }
            }
        }
        .studyGroupedBackground()
        .contentMargins(.vertical, 8, for: .scrollContent)
        .searchable(text: setting(\.searchQuery), prompt: "搜索希伯来语、音译或中文")
    }

    private var cards: some View {
        ScrollView {
            if filteredWords.isEmpty { ContentUnavailableView.search(text: preferences.searchQuery) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 144), spacing: 12)], spacing: 12) {
                ForEach(filteredWords) { word in
                    VStack(alignment: .leading, spacing: 8) {
                        wordLink(word).buttonStyle(.borderless)
                        HStack {
                            wordSpeaker(word)
                            Spacer()
                            Menu { wordActions(word) } label: {
                                Image(systemName: "ellipsis")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("单词操作")
                        }
                    }
                    .padding(12)
                    .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .searchable(text: setting(\.searchQuery), prompt: "搜索希伯来语、音译或中文")
    }

    private func wordSpeaker(_ word: StudyWord) -> some View {
        PronunciationButton(hebrew: word.hebrew, fallback: word.transliteration, iconOnly: true,
                            title: "播放\(word.meaningZh)的发音", minimumHitSize: 44)
    }

    private func favoriteLabel(_ word: StudyWord) -> some View {
        let saved = progress.favorites.contains(word.id)
        return Label(saved ? "取消收藏" : "收藏", systemImage: saved ? "star.fill" : "star")
    }

    @ViewBuilder private func wordActions(_ word: StudyWord) -> some View {
        let mastery = progress.wordMastery[word.id] ?? .unlearned
        Button { progress.toggleFavorite(word.id) } label: { favoriteLabel(word) }
        Menu("掌握度 · \(mastery.title)", systemImage: mastery.symbol) {
            ForEach(Mastery.allCases) { level in
                Button {
                    progress.setWord(word.id, mastery: level)
                } label: {
                    Label(level.title, systemImage: mastery == level ? "checkmark" : level.symbol)
                }
            }
        }
    }

    private func wordLink(_ word: StudyWord) -> some View {
        NavigationLink {
            WordDetailView(word: word, content: content, showNiqqud: preferences.showNiqqud,
                           showCursive: preferences.showCursive)
                .onAppear { setting(\.selectedWordId).wrappedValue = word.id }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HebrewText(text: preferences.showNiqqud ? word.hebrew : word.hebrewUnpointed, cursive: preferences.showCursive)
                Text(word.meaningZh).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var phraseControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("场景", selection: $phraseCategory) {
                Text("全部场景").tag("all")
                ForEach(content.phraseCategories.keys.sorted(), id: \.self) { category in
                    Text(content.phraseCategories[category]?.label ?? category).tag(category)
                }
            }
            Toggle("隐藏中文，自测释义", isOn: $hidePhraseTranslation)
                .frame(minHeight: 44)
        }
    }

    private var phrases: some View {
        List {
            ForEach(content.phraseCategories.keys.sorted().filter { phraseCategory == "all" || $0 == phraseCategory }, id: \.self) { category in
                Section(content.phraseCategories[category]?.label ?? category) {
                    ForEach(content.phrases.filter { $0.scenario == category }) { phrase in
                        phraseRow(phrase)
                    }
                }
            }
        }
        .studyGroupedBackground()
    }

    private func phraseRow(_ phrase: StudyPhrase) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HebrewText(text: preferences.showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed, cursive: preferences.showCursive)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
            Text(phrase.transliteration).font(.subheadline).foregroundStyle(.secondary)
            if !hidePhraseTranslation {
                Text(phrase.meaningZh)
                if let note = phrase.note { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { phraseAudio(phrase) }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading) { phraseAudio(phrase) }
            }
        }
    }

    @ViewBuilder private func phraseAudio(_ phrase: StudyPhrase) -> some View {
        PronunciationButton(hebrew: phrase.hebrew, fallback: phrase.transliteration, title: "朗读短语", minimumHitSize: 44)
        PronunciationButton(hebrew: phrase.hebrew, fallback: phrase.transliteration, rate: 0.68, title: "慢速朗读", minimumHitSize: 44)
    }

    private var readings: some View {
        List {
            ForEach(content.readingCategories.keys.sorted(), id: \.self) { category in
                Section(content.readingCategories[category] ?? category) {
                    ForEach(content.readings.filter { $0.category == category }) { reading in
                        NavigationLink {
                            StudyReadingView(reading: reading, showNiqqud: setting(\.showNiqqud))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reading.title).font(.headline)
                                Text("\(reading.sentences.count) 句 · 阅读理解")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .studyGroupedBackground()
    }
}

private struct WordDetailView: View {
    @Environment(StudyProgress.self) private var progress
    let word: StudyWord
    let content: StudyContent
    let showNiqqud: Bool
    let showCursive: Bool

    private let formLabels = [("ms", "阳性单数"), ("fs", "阴性单数"), ("mp", "阳性复数"), ("fp", "阴性复数"),
                              ("infinitive", "不定式"), ("past3ms", "过去式"), ("singular", "单数"), ("plural", "复数")]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HebrewText(text: showNiqqud ? word.hebrew : word.hebrewUnpointed, cursive: showCursive, size: 42, style: .largeTitle)
                    Text(word.meaningZh).font(.title3.weight(.semibold))
                    Text("\(word.transliteration) · \(word.ipa)").font(.subheadline).foregroundStyle(.secondary)
                    PronunciationButton(hebrew: word.hebrew, fallback: word.transliteration, minimumHitSize: 44)
                }
                MasteryPicker(value: Binding(get: { progress.wordMastery[word.id] ?? .unlearned }, set: {
                    progress.setWord(word.id, mastery: $0)
                }))
            }
            if let sentence = word.sentence {
                Section("例句") {
                    WordExampleRow(example: StudyExample(hebrew: sentence.hebrew, transliteration: sentence.transliteration,
                                                         meaning: sentence.meaningZh, note: nil))
                }
            }
            if !word.note.isEmpty { Section("用法") { Text(word.note) } }
            DisclosureGroup("词性与语法") {
                LabeledContent("词性", value: word.partOfSpeech)
                LabeledContent("语法", value: word.grammarTag)
                if let root = word.root { LabeledContent("词根", value: root) }
            }
            if !letters.isEmpty {
                DisclosureGroup("字母拆解") {
                    ForEach(Array(letters.enumerated()), id: \.offset) { _, entry in
                        NavigationLink {
                            LetterStudyView(letter: entry.letter, content: content)
                        } label: {
                            LabeledContent(String(entry.character), value: entry.letter.nameChinese)
                        }
                    }
                }
            }
            if let root = word.root {
                let related = content.words.filter { $0.root == root && $0.id != word.id }
                if !related.isEmpty {
                    DisclosureGroup("同词根") {
                        ForEach(related) { item in
                            NavigationLink {
                                WordDetailView(word: item, content: content, showNiqqud: showNiqqud, showCursive: showCursive)
                            } label: {
                                LabeledContent(item.hebrew, value: item.meaningZh)
                            }
                        }
                    }
                }
            }
            let forms = content.inflections[word.id] ?? [:]
            if !forms.isEmpty {
                DisclosureGroup("词形变化") {
                    ForEach(formLabels, id: \.0) { key, label in
                        if let form = forms[key] {
                            HStack {
                                LabeledContent(form.label ?? label, value: form.hebrew)
                                PronunciationButton(hebrew: form.hebrew, fallback: form.translit, iconOnly: true, minimumHitSize: 44)
                            }
                        }
                    }
                }
            }
        }
        .studyGroupedBackground()
        .navigationTitle(word.hebrewUnpointed)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                progress.toggleFavorite(word.id)
            } label: {
                let saved = progress.favorites.contains(word.id)
                Label(saved ? "取消收藏" : "收藏", systemImage: saved ? "star.fill" : "star")
            }
        }
    }

    private var letters: [(character: Character, letter: StudyLetter)] {
        word.hebrewUnpointed.compactMap { character in
            let glyph = String(character)
            guard let letter = content.letters.first(where: { $0.hebrew == glyph || $0.sofit == glyph }) else { return nil }
            return (character, letter)
        }
    }
}

private struct StudyReadingView: View {
    @Environment(StudyProgress.self) private var progress
    let reading: StudyReading
    @Binding var showNiqqud: Bool
    @State private var showTranslation = false
    @State private var answer: Int?
    @State private var selectedGloss: GlossSelection?

    private struct GlossSelection: Equatable {
        let sentence: Int
        let term: Int
    }

    var body: some View {
        List {
            if let source = reading.source { Text(source).foregroundStyle(.secondary) }
            Toggle("显示元音点", isOn: $showNiqqud)
            Section("朗读") {
                Text("点按标记的词查看释义。")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(reading.sentences.enumerated()), id: \.offset) { index, sentence in
                    sentenceRow(sentence, at: index)
                }
            }
            DisclosureGroup("中文译文", isExpanded: $showTranslation) {
                ForEach(Array(reading.sentences.enumerated()), id: \.offset) { _, sentence in
                    Text(sentence.chinese)
                }
            }
            Section("阅读理解") {
                Text(reading.question.prompt)
                ForEach(Array(reading.question.choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        guard answer != reading.question.correctIndex else { return }
                        answer = index
                        if index == reading.question.correctIndex { progress.recordStudy() }
                    } label: {
                        HStack {
                            Text(choice).foregroundStyle(.primary)
                            Spacer()
                            if answer == index {
                                let correct = index == reading.question.correctIndex
                                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(correct ? Color.green : Color.red)
                                    .accessibilityLabel(correct ? "正确答案" : "答案有误")
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(answer == reading.question.correctIndex)
                    .accessibilityAddTraits(answer == index ? .isSelected : [])
                }
                if let answer {
                    let correct = answer == reading.question.correctIndex
                    Label(correct ? "回答正确。" : "再读一下原文，然后重试。",
                          systemImage: correct ? "checkmark.circle" : "info.circle")
                }
            }
        }
        .studyGroupedBackground()
        .navigationTitle(reading.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showNiqqud) { _, _ in selectedGloss = nil }
    }

    private func sentenceRow(_ sentence: StudyReading.Sentence, at index: Int) -> some View {
        let text = showNiqqud ? sentence.hebrew : sentence.unpointed
        let glosses = reading.inlineGlosses(in: text)
        let selectedTerm = selectedGloss.flatMap { $0.sentence == index ? $0.term : nil }
        return VStack(alignment: .leading, spacing: 8) {
            Text(attributedSentence(text, glosses: glosses, selectedTerm: selectedTerm))
                .font(.title2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "alef-gloss", let term = Int(url.lastPathComponent), glosses.indices.contains(term) else { return .discarded }
                    let selection = GlossSelection(sentence: index, term: term)
                    selectedGloss = selectedGloss == selection ? nil : selection
                    return .handled
                })
            if let selectedTerm, glosses.indices.contains(selectedTerm) {
                let gloss = glosses[selectedTerm]
                Text("\(String(text[gloss.range])) · \(gloss.definition)")
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(progress.theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
            PronunciationButton(hebrew: sentence.hebrew, fallback: sentence.transliteration,
                                title: "朗读第 \(index + 1) 句", minimumHitSize: 44)
        }
    }

    private func attributedSentence(_ text: String, glosses: [StudyReading.Gloss], selectedTerm: Int?) -> AttributedString {
        var contents = AttributedString()
        var next = text.startIndex
        for (index, gloss) in glosses.enumerated() {
            contents += AttributedString(String(text[next..<gloss.range.lowerBound]))
            var term = AttributedString(String(text[gloss.range]))
            term.link = URL(string: "alef-gloss://term/\(index)")
            term.underlineStyle = .single
            if index == selectedTerm { term.backgroundColor = progress.theme.accent.opacity(0.16) }
            contents += term
            next = gloss.range.upperBound
        }
        contents += AttributedString(String(text[next...]))
        return contents
    }
}

private struct WordQuizView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
    let words: [StudyWord]
    let distractors: [StudyWord]
    let letters: [StudyLetter]
    let showNiqqud: Bool
    let reviewing: Bool
    let onFinishReview: () -> Void
    @State private var kind = "meaning"
    @State private var target: StudyWord?
    @State private var options: [StudyWord] = []
    @State private var spelling = ""
    @State private var result: Bool?
    @State private var selectedOption: String?
    @State private var systemInput = false
    @FocusState private var inputFocused: Bool
    @State private var correct = 0
    @State private var answered = 0
    @State private var reviewQueue: [StudyWord]?
    @State private var reviewIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            quizHeader
            ScrollViewReader { scroll in
                List {
                    if let target {
                        Section {
                            questionPrompt(target)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("word-question")
                            if kind == "spelling" {
                                spellingInput
                            } else {
                                ForEach(options) { option in
                                    StudyAnswerButton(title: option.meaningZh, submitted: result != nil,
                                                      selected: selectedOption == option.id, correct: option.id == target.id) {
                                        selectedOption = option.id
                                        grade(option.id == target.id)
                                    }
                                }
                            }
                        }
                        if let result {
                            Section("答题结果") {
                                Label(result ? "答对了" : "正确答案 · \(target.hebrew) · \(target.meaningZh)",
                                      systemImage: result ? "checkmark.circle" : "info.circle")
                                if kind == "spelling" { LabeledContent("无点拼写", value: target.hebrewUnpointed) }
                            }
                            .id("word-result")
                        }
                    } else {
                        ContentUnavailableView(reviewing && answered > 0 ? "已完成到期复习" : "没有可用单词",
                                               systemImage: reviewing && answered > 0 ? "checkmark.circle" : "character.book.closed",
                                               description: reviewing && answered > 0 ? Text("答对 \(correct) / \(answered) 个单词") : nil)
                    }
                }
                .studyGroupedBackground()
                .contentMargins(.vertical, 8, for: .scrollContent)
                .onChange(of: target?.id) { _, _ in scroll.scrollTo("word-question", anchor: .top) }
                .onChange(of: result) { _, value in
                    if value != nil { scroll.scrollTo("word-result", anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if target != nil || reviewing {
                StudyActionBar { quizAction }
            }
        }
        .task {
            if reviewing && reviewQueue == nil { reviewQueue = words }
            if target == nil { next(play: false) }
        }
        .onChange(of: kind) { _, _ in next(play: true) }
    }

    private var kindPicker: some View {
        Picker("题型", selection: $kind) {
            Text("词义").tag("meaning")
            Text("听力").tag("listening")
            Text("拼写").tag("spelling")
        }
    }

    private var quizHeader: some View {
        VStack(spacing: 8) {
            if !reviewing {
                if typeSize.isAccessibilitySize { kindPicker.pickerStyle(.menu) }
                else { kindPicker.pickerStyle(.segmented) }
            }
            LabeledContent("当前得分", value: "\(correct) / \(answered)")
            if let reviewQueue, !reviewQueue.isEmpty, target != nil {
                LabeledContent("复习进度", value: "\(reviewIndex + 1) / \(reviewQueue.count)")
            }
        }
        .font(.subheadline)
        .monospacedDigit()
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func questionPrompt(_ target: StudyWord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch kind {
            case "listening":
                Text("听发音，选择词义").font(.headline)
            case "spelling":
                Text(target.meaningZh).font(.title3)
                LabeledContent("提示转写", value: target.transliteration)
            default:
                HebrewText(text: showNiqqud ? target.hebrew : target.hebrewUnpointed, size: 44, style: .largeTitle)
            }
            PronunciationButton(hebrew: target.hebrew, fallback: target.transliteration, minimumHitSize: 44)
        }
    }

    private var spellingInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            if systemInput {
                TextField("输入希伯来语单词", text: $spelling)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit(confirmSpelling)
                    .environment(\.layoutDirection, .rightToLeft)
            } else {
                Text(spelling.isEmpty ? "在下方选择希伯来字母" : spelling)
                    .font(.title3)
                    .foregroundStyle(spelling.isEmpty ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .environment(\.layoutDirection, spelling.isEmpty ? .leftToRight : .rightToLeft)
                    .textSelection(.enabled)
            }
            if result == nil {
                Button {
                    systemInput.toggle()
                    inputFocused = false
                } label: {
                    Label(systemInput ? "使用屏内字母键盘" : "使用系统键盘或粘贴", systemImage: "keyboard")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
                if !systemInput { spellingKeyboard }
            }
        }
        .disabled(result != nil)
        .onChange(of: systemInput) { _, enabled in inputFocused = enabled }
    }

    @ViewBuilder private var quizAction: some View {
        if target != nil {
            if result != nil {
                let finishing = reviewing && reviewIndex + 1 == reviewQueue?.count
                primaryButton(finishing ? "查看复习结果" : "下一题", symbol: "arrow.right") {
                    if reviewing { reviewIndex += 1 }
                    next(play: true)
                }
            } else if kind == "spelling" {
                ViewThatFits(in: .horizontal) {
                    HStack { skipButton.fixedSize(); confirmButton }
                    VStack { confirmButton; skipButton }
                }
            } else if !reviewing {
                skipButton
            } else {
                Text("选择一个答案以继续").font(.footnote).foregroundStyle(.secondary)
            }
        } else if reviewing {
            primaryButton("返回词表", symbol: "list.bullet", action: onFinishReview)
        }
    }

    private var skipButton: some View {
        Button("换一题", systemImage: "arrow.clockwise") { next(play: true) }
            .frame(minHeight: 44)
            .buttonStyle(.borderless)
    }

    private var confirmButton: some View {
        primaryButton("确认答案", symbol: "checkmark", action: confirmSpelling)
            .disabled(spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func confirmSpelling() {
        guard let target else { return }
        let normalized = withoutHebrewMarks(spelling).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        inputFocused = false
        grade(normalized == target.hebrewUnpointed)
    }

    private var spellingKeyboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                ForEach(letters.map(\.hebrew) + letters.compactMap(\.sofit), id: \.self) { character in
                    Button { spelling += character } label: {
                        HebrewText(text: character, size: 22)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            HStack {
                Button("退格", systemImage: "delete.left") { if !spelling.isEmpty { spelling.removeLast() } }
                Button("清空", systemImage: "eraser") { spelling = "" }
            }
            .frame(minHeight: 44)
            .buttonStyle(.borderless)
            .disabled(spelling.isEmpty)
        }
        .disabled(result != nil)
    }

    private func next(play: Bool) {
        let pool = kind == "spelling" ? words.filter {
            (2...8).contains($0.hebrewUnpointed.count) && $0.hebrewUnpointed.allSatisfy { "אבגדהוזחטיכלמנסעפצקרשתךםןףץ".contains($0) }
        } : reviewQueue ?? words
        if reviewing {
            target = pool.indices.contains(reviewIndex) ? pool[reviewIndex] : nil
        } else {
            let others = pool.filter { $0.id != target?.id }
            target = (others.isEmpty ? pool : others).randomElement()
        }
        result = nil
        selectedOption = nil
        inputFocused = false
        spelling = ""
        guard let target else { return }
        var meanings: Set<String> = [target.meaningZh]
        let choices = distractors.shuffled().filter { meanings.insert($0.meaningZh).inserted }
        options = ([target] + Array(choices.prefix(3))).shuffled()
        if kind == "listening", play { audio.speak(target.hebrew, fallback: target.transliteration, rate: progress.speechRate) }
    }

    private func grade(_ success: Bool) {
        guard let target, result == nil else { return }
        result = success
        answered += 1
        if success { correct += 1 }
        if reviewing { progress.setWord(target.id, mastery: success ? .mastered : .learning) }
        else { progress.recordStudy() }
        audio.playFeedback(success ? .correct : .wrong)
    }
}
