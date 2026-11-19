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
    let content: StudyContent
    @State private var phraseCategory = "all"
    @State private var hidePhraseTranslation = false

    var body: some View {
        Group {
            switch preferences.mode {
            case "phrases": phrases
            case "reading": readings
            case "quiz":
                WordQuizView(words: preferences.activeFilter == "due_srs" ? dueWords : filteredWords,
                             distractors: content.words, letters: content.letters, showNiqqud: preferences.showNiqqud,
                             reviewing: preferences.activeFilter == "due_srs", onFinishReview: { setting(\.mode).wrappedValue = "browse" })
                    .id(preferences.activeFilter)
            case "cards": cards
            default: library
            }
        }
        .navigationTitle("希伯来语词库")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("学习方式", selection: setting(\.mode)) {
                        Text("词表").tag("browse")
                        Text("单词卡片").tag("cards")
                        Text("情景短语").tag("phrases")
                        Text("阅读练习").tag("reading")
                        Text("单词测验").tag("quiz")
                    }
                    Toggle("显示元音点", isOn: setting(\.showNiqqud))
                    Toggle("手写体", isOn: setting(\.showCursive))
                    Button("复习到期单词（\(dueWords.count)）", systemImage: "calendar.badge.clock") {
                        var state = preferences
                        state.activeFilter = "due_srs"
                        state.mode = "quiz"
                        progress.write(state, for: "alef.wordsState.v1")
                    }
                    .disabled(dueWords.isEmpty || (preferences.mode == "quiz" && preferences.activeFilter == "due_srs"))
                    if ["browse", "cards"].contains(preferences.mode) {
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
                HStack(spacing: 14) {
                    wordLink(word)
                    wordActions(word)
                }
            }
        }
        .searchable(text: setting(\.searchQuery), prompt: "搜索希伯来语、音译或中文")
    }

    private var cards: some View {
        ScrollView {
            if filteredWords.isEmpty { ContentUnavailableView.search(text: preferences.searchQuery) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(filteredWords) { word in
                    VStack(alignment: .leading, spacing: 8) {
                        wordLink(word).buttonStyle(.borderless)
                        wordActions(word)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .searchable(text: setting(\.searchQuery), prompt: "搜索单词")
    }

    private func wordActions(_ word: StudyWord) -> some View {
        let favorite = progress.favorites.contains(word.id)
        let mastery = progress.wordMastery[word.id] ?? .unlearned
        return HStack(spacing: 12) {
            PronunciationButton(hebrew: word.hebrew, fallback: word.transliteration, iconOnly: true)
            Button {
                progress.toggleFavorite(word.id)
            } label: {
                Image(systemName: favorite ? "star.fill" : "star")
            }
            .accessibilityLabel(favorite ? "取消收藏" : "收藏")
            Button {
                progress.setWord(word.id, mastery: mastery.next)
            } label: {
                Image(systemName: mastery.symbol)
            }
            .accessibilityLabel("掌握度：\(mastery.title)")
            .accessibilityHint("切换为\(mastery.next.title)")
        }
        .buttonStyle(.borderless)
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

    private var phrases: some View {
        List {
            Section {
                Picker("场景", selection: $phraseCategory) {
                    Text("全部场景").tag("all")
                    ForEach(content.phraseCategories.keys.sorted(), id: \.self) { category in
                        Text(content.phraseCategories[category]?.label ?? category).tag(category)
                    }
                }
                Toggle("隐藏中文，自测释义", isOn: $hidePhraseTranslation)
            }
            ForEach(content.phraseCategories.keys.sorted().filter { phraseCategory == "all" || $0 == phraseCategory }, id: \.self) { category in
                Section(content.phraseCategories[category]?.label ?? category) {
                    ForEach(content.phrases.filter { $0.scenario == category }) { phrase in
                        phraseRow(phrase)
                    }
                }
            }
        }
    }

    private func phraseRow(_ phrase: StudyPhrase) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HebrewText(text: preferences.showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed, cursive: preferences.showCursive)
            Text(phrase.transliteration).font(.subheadline).foregroundStyle(.secondary)
            if !hidePhraseTranslation {
                Text(phrase.meaningZh)
                if let note = phrase.note { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }
            HStack(spacing: 20) {
                PronunciationButton(hebrew: phrase.hebrew, fallback: phrase.transliteration, rate: 0.68, title: "慢速朗读")
                PronunciationButton(hebrew: phrase.hebrew, fallback: phrase.transliteration, title: "朗读短语")
            }
        }
    }

    private var readings: some View {
        List {
            ForEach(content.readingCategories.keys.sorted(), id: \.self) { category in
                Section(content.readingCategories[category] ?? category) {
                    ForEach(content.readings.filter { $0.category == category }) { reading in
                        NavigationLink(reading.title) { StudyReadingView(reading: reading, showNiqqud: setting(\.showNiqqud)) }
                    }
                }
            }
        }
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
                HStack {
                    HebrewText(text: showNiqqud ? word.hebrew : word.hebrewUnpointed, cursive: showCursive, size: 42)
                    Spacer()
                    PronunciationButton(hebrew: word.hebrew, fallback: word.transliteration, iconOnly: true)
                }
                Text(word.meaningZh).font(.title3)
                LabeledContent("音译", value: word.transliteration)
                LabeledContent("国际音标", value: word.ipa)
                LabeledContent("词性", value: word.partOfSpeech)
                LabeledContent("语法", value: word.grammarTag)
                if let root = word.root { LabeledContent("词根", value: root) }
                MasteryPicker(value: Binding(get: { progress.wordMastery[word.id] ?? .unlearned }, set: {
                    progress.setWord(word.id, mastery: $0)
                }))
            }
            if !word.note.isEmpty { Section("用法") { Text(word.note) } }
            if !letters.isEmpty {
                Section("字母拆解") {
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
                    Section("同词根") {
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
                Section("词形变化") {
                    ForEach(formLabels, id: \.0) { key, label in
                        if let form = forms[key] {
                            HStack {
                                LabeledContent(form.label ?? label, value: form.hebrew)
                                PronunciationButton(hebrew: form.hebrew, fallback: form.translit, iconOnly: true)
                            }
                        }
                    }
                }
            }
            if let sentence = word.sentence {
                Section("例句") {
                    WordExampleRow(example: StudyExample(hebrew: sentence.hebrew, transliteration: sentence.transliteration,
                                                         meaning: sentence.meaningZh, note: nil))
                }
            }
        }
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
                    Button(choice) {
                        guard answer != reading.question.correctIndex else { return }
                        answer = index
                        if index == reading.question.correctIndex { progress.recordStudy() }
                    }
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
        .navigationTitle(reading.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showNiqqud) { _, _ in selectedGloss = nil }
    }

    private func sentenceRow(_ sentence: StudyReading.Sentence, at index: Int) -> some View {
        let text = showNiqqud ? sentence.hebrew : sentence.unpointed
        let glosses = reading.inlineGlosses(in: text)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                PronunciationButton(hebrew: sentence.hebrew, fallback: sentence.transliteration, iconOnly: true,
                                    title: "朗读第 \(index + 1) 句")
                Text(attributedSentence(text, glosses: glosses))
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == "alef-gloss", let term = Int(url.lastPathComponent), glosses.indices.contains(term) else { return .discarded }
                        let selection = GlossSelection(sentence: index, term: term)
                        selectedGloss = selectedGloss == selection ? nil : selection
                        return .handled
                    })
            }
            if let selection = selectedGloss, selection.sentence == index, glosses.indices.contains(selection.term) {
                let gloss = glosses[selection.term]
                Text("\(String(text[gloss.range])) · \(gloss.definition)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func attributedSentence(_ text: String, glosses: [StudyReading.Gloss]) -> AttributedString {
        var contents = AttributedString()
        var next = text.startIndex
        for (index, gloss) in glosses.enumerated() {
            contents += AttributedString(String(text[next..<gloss.range.lowerBound]))
            var term = AttributedString(String(text[gloss.range]))
            term.link = URL(string: "alef-gloss://term/\(index)")
            term.underlineStyle = .single
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
    @State private var correct = 0
    @State private var answered = 0
    @State private var reviewQueue: [StudyWord]?
    @State private var reviewIndex = 0

    var body: some View {
        List {
            if !reviewing {
                Picker("题型", selection: $kind) {
                    Text("词义").tag("meaning")
                    Text("听力").tag("listening")
                    Text("拼写").tag("spelling")
                }
                .pickerStyle(.segmented)
            }
            LabeledContent("当前得分", value: "\(correct) / \(answered)")
            if let reviewQueue, !reviewQueue.isEmpty {
                LabeledContent("复习进度", value: "\(min(reviewIndex + 1, reviewQueue.count)) / \(reviewQueue.count)")
            }
            if let target {
                Section {
                    switch kind {
                    case "listening": PronunciationButton(hebrew: target.hebrew, fallback: target.transliteration)
                    case "spelling":
                        Text(target.meaningZh).font(.title3)
                        LabeledContent("提示转写", value: target.transliteration)
                        PronunciationButton(hebrew: target.hebrew, fallback: target.transliteration)
                    default:
                        HebrewText(text: showNiqqud ? target.hebrew : target.hebrewUnpointed, size: 44)
                        PronunciationButton(hebrew: target.hebrew, fallback: target.transliteration)
                    }
                    if kind == "spelling" {
                        TextField("输入希伯来语单词", text: $spelling)
                            .autocorrectionDisabled()
                            .environment(\.layoutDirection, .rightToLeft)
                            .disabled(result != nil)
                        spellingKeyboard
                        Button("确认答案") {
                            let normalized = withoutHebrewMarks(spelling)
                            grade(normalized.trimmingCharacters(in: .whitespacesAndNewlines) == target.hebrewUnpointed)
                        }
                        .disabled(result != nil || spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        ForEach(options) { option in
                            Button(option.meaningZh) { grade(option.id == target.id) }
                                .disabled(result != nil)
                        }
                    }
                    if let result {
                        Label(result ? "答对了" : "正确答案：\(target.hebrew) · \(target.meaningZh)",
                              systemImage: result ? "checkmark.circle" : "info.circle")
                        if kind == "spelling" {
                            LabeledContent("无点拼写", value: target.hebrewUnpointed)
                        }
                        Button("下一题", systemImage: "arrow.right") {
                            if reviewing { reviewIndex += 1 }
                            next(play: true)
                        }
                    } else if !reviewing {
                        Button("换一题", systemImage: "arrow.right") { next(play: true) }
                    }
                }
            } else {
                ContentUnavailableView(reviewing && answered > 0 ? "已完成到期复习" : "没有可用单词",
                                       systemImage: reviewing && answered > 0 ? "checkmark.circle" : "character.book.closed")
                if reviewing { Button("返回词表", action: onFinishReview) }
            }
        }
        .task {
            if reviewing && reviewQueue == nil { reviewQueue = words }
            if target == nil { next(play: false) }
        }
        .onChange(of: kind) { _, _ in next(play: true) }
    }

    private var spellingKeyboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
                ForEach(letters.map(\.hebrew) + letters.compactMap(\.sofit), id: \.self) { character in
                    Button { spelling += character } label: {
                        HebrewText(text: character, size: 22).frame(minWidth: 24, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            HStack {
                Button("退格", systemImage: "delete.left") { if !spelling.isEmpty { spelling.removeLast() } }
                Button("清空", systemImage: "eraser") { spelling = "" }
            }
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
