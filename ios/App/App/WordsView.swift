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
    var topic: String?
    var cardLayout: Bool?

    static let scopes = [("all", "全部"), ("favorites", "收藏"), ("needs_review", "需复习"), ("due_srs", "到期复习")]

    var scope: String { Self.scopes.contains { $0.0 == activeFilter } ? activeFilter : "all" }
    var selectedTopic: String? { topic ?? (scope == activeFilter ? nil : activeFilter) }
    var usesCards: Bool { cardLayout ?? (mode == "cards") }

    mutating func setMode(_ selected: String) {
        cardLayout = usesCards
        mode = selected == "browse" && usesCards ? "cards" : selected
    }

    mutating func setCardLayout(_ enabled: Bool) {
        cardLayout = enabled
        mode = enabled ? "cards" : "browse"
    }

    mutating func resetFilters() {
        activeFilter = "all"
        topic = nil
        initialLetter = "all"
    }
}

struct WordsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @State private var showsFilters = false
    @State private var phraseCategory = "all"
    @State private var hidePhraseTranslation = false

    var body: some View {
        StudyPage {
            StudyHeading(section: "词库", title: "把字母读成单词")
            StudySegments(title: "词库内容", options: [("browse", "单词"), ("phrases", "情景短语")],
                          selection: Binding(get: { phrasesSelected ? "phrases" : "browse" }, set: {
                var state = preferences
                state.setMode($0)
                progress.write(state, for: "alef.wordsState.v1")
            }))
            if phrasesSelected {
                phraseLibrary
            } else {
                searchField
                filters
                if !dueWords.isEmpty { dueNotice }
                wordLibrary
            }
        }
        .studyHome()
        .sheet(isPresented: $showsFilters) {
            NavigationStack {
                WordFilterSheet(content: content, preferences: preferences) { updated in
                    progress.write(updated, for: "alef.wordsState.v1")
                }
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var phrasesSelected: Bool { preferences.mode == "phrases" }
    private var preferences: WordPreferences { progress.read("alef.wordsState.v1", default: WordPreferences()) }
    private var dueWords: [StudyWord] { content.dueWords(in: progress) }

    private func setting<Value>(_ path: WritableKeyPath<WordPreferences, Value>) -> Binding<Value> {
        Binding(get: { preferences[keyPath: path] }, set: { value in
            var state = preferences
            state[keyPath: path] = value
            progress.write(state, for: "alef.wordsState.v1")
        })
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(progress.theme.mutedInk).accessibilityHidden(true)
            TextField("希伯来语、中文、音译、词根…", text: setting(\.searchQuery))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityLabel("搜索词库")
            if !preferences.searchQuery.isEmpty {
                Button {
                    setting(\.searchQuery).wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(progress.theme.mutedInk)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 45)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) { quickFilters }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 5) {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                        : AnyLayout(HStackLayout(spacing: 5))
                    layout {
                        scopeButton("全部", scope: "all")
                        scopeButton("收藏", scope: "favorites")
                        scopeButton("到期复习", scope: "due_srs")
                    }
                    filterButton
                }
            }
            if preferences.scope != "all" || preferences.selectedTopic != nil || preferences.initialLetter != "all" {
                Button {
                    var state = preferences
                    state.resetFilters()
                    progress.write(state, for: "alef.wordsState.v1")
                } label: {
                    Label("\(filterDescription) · 清除筛选", systemImage: "xmark.circle")
                        .font(.footnote)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(progress.theme.accent)
            }
            NavigationLink {
                StudyReadingLibrary(content: content, showNiqqud: setting(\.showNiqqud))
            } label: {
                Label("阅读", systemImage: "book")
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
            }
            .foregroundStyle(progress.theme.accent)
        }
    }

    @ViewBuilder private var quickFilters: some View {
        scopeButton("全部", scope: "all")
        scopeButton("收藏", scope: "favorites")
        scopeButton("到期复习", scope: "due_srs")
        filterButton
    }

    private var filterButton: some View {
        Button { showsFilters = true } label: { Label("筛选", systemImage: "line.3.horizontal.decrease") }
            .buttonStyle(StudyButtonStyle(selected: preferences.scope == "needs_review" || preferences.selectedTopic != nil))
    }

    private func scopeButton(_ title: String, scope: String) -> some View {
        Button(title) {
            var state = preferences
            state.topic = state.selectedTopic
            state.activeFilter = scope
            progress.write(state, for: "alef.wordsState.v1")
        }
        .buttonStyle(StudyButtonStyle(selected: preferences.scope == scope))
        .accessibilityAddTraits(preferences.scope == scope ? .isSelected : [])
    }

    private var dueNotice: some View {
        let count = dueWords.count
        return NavigationLink {
            WordReviewView(content: content, words: dueWords)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock").accessibilityHidden(true)
                Text("\(count) 个单词到期").font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Label("立即复习", systemImage: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            .foregroundStyle(progress.theme.reminder)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(progress.theme.reminderSurface, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var filterDescription: String {
        let settings = preferences
        var labels = [WordPreferences.scopes.first { $0.0 == settings.scope }?.1 ?? "全部"]
        if let topic = settings.selectedTopic { labels.append(content.wordCategories[topic]?.label ?? topic) }
        if settings.initialLetter != "all" { labels.append("首字母 \(settings.initialLetter)") }
        return labels.joined(separator: " · ")
    }

    private var filteredWords: [StudyWord] {
        let settings = preferences
        let favorites = Set(progress.favorites)
        let mastery = progress.wordMastery
        let schedule = progress.schedule
        let query = settings.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let unpointedQuery = withoutHebrewMarks(query)
        let scope = settings.scope
        let topic = settings.selectedTopic
        let words = content.words.filter { word in
            let include = switch scope {
            case "favorites": favorites.contains(word.id)
            case "needs_review": mastery[word.id] != .mastered
            case "due_srs": schedule[word.id]?.isDue == true
            default: true
            }
            let searchable = [word.hebrew, word.hebrewUnpointed, word.transliteration, word.meaningZh, word.root ?? "", word.ipa]
                + (word.alternateSpellings ?? [])
            return include && (topic == nil || word.category == topic)
                && (settings.initialLetter == "all" || word.hebrewUnpointed.hasPrefix(settings.initialLetter))
                && (query.isEmpty || searchable.contains { $0.localizedStandardContains(query) }
                    || (!unpointedQuery.isEmpty && word.hebrewUnpointed.localizedStandardContains(unpointedQuery)))
        }
        return settings.sortOrder == "alpha" ? words.sorted { $0.hebrewUnpointed < $1.hebrewUnpointed } : words
    }

    @ViewBuilder private var wordLibrary: some View {
        let words = filteredWords
        let favorites = Set(progress.favorites)
        let mastery = progress.wordMastery
        Text("\(words.count) 个单词")
            .font(.caption.weight(.medium))
            .foregroundStyle(progress.theme.mutedInk)
        if words.isEmpty {
            ContentUnavailableView {
                Label("没有匹配的单词", systemImage: "magnifyingglass")
            } description: {
                Text("可以更换搜索词或清除筛选。")
            } actions: {
                Button("清除搜索和筛选") {
                    var state = preferences
                    state.resetFilters()
                    state.searchQuery = ""
                    progress.write(state, for: "alef.wordsState.v1")
                }
                .buttonStyle(StudyButtonStyle())
            }
        } else if preferences.usesCards {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 280 : 152), spacing: 8)], spacing: 8) {
                ForEach(words) { word in
                    wordRow(word, favorite: favorites.contains(word.id), mastery: mastery[word.id] ?? .unlearned, stacked: true)
                }
            }
        } else {
            LazyVStack(spacing: 7) {
                ForEach(words) { word in
                    wordRow(word, favorite: favorites.contains(word.id), mastery: mastery[word.id] ?? .unlearned,
                            stacked: typeSize.isAccessibilitySize)
                }
            }
        }
    }

    private func wordRow(_ word: StudyWord, favorite: Bool, mastery: Mastery, stacked: Bool) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        return StudyCard(padding: 7) {
            layout {
                if !stacked { wordMasteryMenu(word, mastery: mastery) }
                NavigationLink {
                    WordDetailView(word: word, content: content, showNiqqud: preferences.showNiqqud,
                                   showCursive: preferences.showCursive)
                        .onAppear { setting(\.selectedWordId).wrappedValue = word.id }
                } label: {
                    let textLayout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5)) : AnyLayout(HStackLayout(spacing: 6))
                    textLayout {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(word.transliteration).font(.subheadline.weight(.semibold)).foregroundStyle(progress.theme.ink)
                            Text(word.meaningZh).font(.caption).foregroundStyle(progress.theme.mutedInk)
                        }
                        if !stacked { Spacer(minLength: 4) }
                        HebrewText(text: preferences.showNiqqud ? word.hebrew : word.hebrewUnpointed,
                                   cursive: preferences.showCursive, size: 28)
                            .lineLimit(stacked ? nil : 2)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(mastery.title)
                }
                .buttonStyle(.plain)
                HStack(spacing: 0) {
                    if stacked { wordMasteryMenu(word, mastery: mastery) }
                    PronunciationButton(hebrew: word.hebrew, iconOnly: true,
                                        title: "播放\(word.meaningZh)的发音")
                    Button { progress.toggleFavorite(word.id) } label: {
                        Image(systemName: favorite ? "bookmark.fill" : "bookmark")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(progress.theme.accent)
                    .accessibilityLabel(favorite ? "取消收藏\(word.meaningZh)" : "收藏\(word.meaningZh)")
                }
            }
        }
    }

    private func wordMasteryMenu(_ word: StudyWord, mastery: Mastery) -> some View {
        Menu {
            ForEach(Mastery.allCases) { level in
                Button(level.title, systemImage: level == mastery ? "checkmark" : level.symbol) {
                    progress.setWord(word.id, mastery: level)
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: mastery.symbol).font(.subheadline)
                Text(mastery.title).font(.caption2)
            }
            .foregroundStyle(mastery == .unlearned ? progress.theme.mutedInk : progress.theme.accent)
            .padding(.horizontal, 4)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(word.meaningZh)的掌握度")
        .accessibilityValue(mastery.title)
    }

    private var phraseLibrary: some View {
        let categories = content.phraseCategories.keys.sorted()
        let favorites: [String] = progress.read("alef.native.phraseFavorites.v1", default: [])
        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    phraseScope("全部场景", key: "all")
                    phraseScope("收藏", key: "favorites")
                    ForEach(categories, id: \.self) { key in
                        phraseScope(content.phraseCategories[key]?.label ?? key, key: key)
                    }
                }
            }
            .scrollIndicators(.hidden)
            Toggle("隐藏中文，自测释义", isOn: $hidePhraseTranslation).font(.subheadline).frame(minHeight: 44)
            Menu {
                Toggle("显示元音点", isOn: setting(\.showNiqqud))
                Toggle("手写体", isOn: setting(\.showCursive))
            } label: {
                Label("短语显示", systemImage: "textformat").frame(minHeight: 44)
            }
            .buttonStyle(StudyButtonStyle())
            let phrases = content.phrases.filter { phrase in
                phraseCategory == "all" || phrase.scenario == phraseCategory
                    || (phraseCategory == "favorites" && favorites.contains(phrase.id))
            }
            if phrases.isEmpty {
                ContentUnavailableView("还没有收藏短语", systemImage: "bookmark")
            }
            LazyVStack(spacing: 9) {
                ForEach(phrases) { phrase in
                    phraseRow(phrase, favorites: favorites)
                }
            }
        }
    }

    private func phraseScope(_ title: String, key: String) -> some View {
        Button(title) { phraseCategory = key }
            .buttonStyle(StudyButtonStyle(selected: phraseCategory == key))
            .accessibilityAddTraits(phraseCategory == key ? .isSelected : [])
    }

    private func phraseRow(_ phrase: StudyPhrase, favorites: [String]) -> some View {
        let saved = favorites.contains(phrase.id)
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
        return StudyCard {
            VStack(spacing: 5) {
                HebrewText(text: preferences.showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed,
                           cursive: preferences.showCursive, size: 38, style: .title)
                Text(phrase.transliteration).font(.subheadline.weight(.medium)).foregroundStyle(progress.theme.mutedInk)
                if !hidePhraseTranslation {
                    Text(phrase.meaningZh).font(.headline)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 34)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                Button {
                    let updated = saved ? favorites.filter { $0 != phrase.id } : favorites + [phrase.id]
                    progress.write(updated, for: "alef.native.phraseFavorites.v1")
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(progress.theme.accent)
                .accessibilityLabel(saved ? "取消收藏短语" : "收藏短语")
            }
            if !hidePhraseTranslation, let note = phrase.note {
                StudyNotice(title: note, symbol: "info.circle")
            }
            layout {
                PronunciationButton(hebrew: phrase.hebrew,
                                    title: "正常 \(progress.speechRate.formatted(.number.precision(.fractionLength(2))))×", prominent: true)
                PronunciationButton(hebrew: phrase.hebrew, rate: 0.68, title: "慢速 0.68×")
            }
        }
    }
}

private struct WordFilterSheet: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @State var preferences: WordPreferences
    let apply: (WordPreferences) -> Void

    var body: some View {
        StudyPage {
            StudySectionTitle("范围")
            StudySegments(title: "范围", options: WordPreferences.scopes,
                          selection: Binding(get: { preferences.scope }, set: {
                preferences.topic = preferences.selectedTopic
                preferences.activeFilter = $0
            }))
            StudySectionTitle("主题")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 245 : 100), spacing: 7)], spacing: 7) {
                topicButton("不限主题", key: nil)
                ForEach(content.wordCategories.keys.sorted(), id: \.self) { key in
                    topicButton(content.wordCategories[key]?.label ?? key, key: key)
                }
            }
            StudySectionTitle("首字母")
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    initialButton("全部", key: "all")
                    ForEach(content.letters) { letter in initialButton(letter.hebrew, key: letter.hebrew) }
                }
            }
            .scrollIndicators(.hidden)
            StudySectionTitle("排序与显示")
            StudySegments(title: "排序", options: [("default", "默认顺序"), ("alpha", "字母顺序")], selection: $preferences.sortOrder)
            Toggle("元音点（Niqqud）", isOn: $preferences.showNiqqud).frame(minHeight: 44)
            StudySegments(title: "字形", options: [(false, "印刷体"), (true, "手写体")], selection: $preferences.showCursive)
            Toggle("卡片布局", isOn: Binding(get: { preferences.usesCards }, set: {
                preferences.setCardLayout($0)
            }))
            .frame(minHeight: 44)
        }
        .studyDetail("筛选与排序")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("重置") {
                    preferences.resetFilters()
                    preferences.sortOrder = "default"
                    preferences.showCursive = false
                    preferences.showNiqqud = true
                    preferences.setCardLayout(false)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StudyActionBar {
                Button {
                    apply(preferences)
                    dismiss()
                } label: {
                    Text("显示筛选结果").frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(prominent: true))
            }
        }
    }

    private func topicButton(_ title: String, key: String?) -> some View {
        Button {
            preferences.activeFilter = preferences.scope
            preferences.topic = key
        } label: {
            Text(title).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(selected: preferences.selectedTopic == key))
        .accessibilityAddTraits(preferences.selectedTopic == key ? .isSelected : [])
    }

    private func initialButton(_ title: String, key: String) -> some View {
        Button {
            preferences.initialLetter = key
        } label: {
            Text(title).frame(minWidth: 24)
        }
        .buttonStyle(StudyButtonStyle(selected: preferences.initialLetter == key))
        .accessibilityAddTraits(preferences.initialLetter == key ? .isSelected : [])
    }
}

private struct StudyReadingLibrary: View {
    let content: StudyContent
    @Binding var showNiqqud: Bool

    var body: some View {
        StudyPage {
            ForEach(content.readingCategories.keys.sorted(), id: \.self) { category in
                StudySectionTitle(content.readingCategories[category] ?? category)
                ForEach(content.readings.filter { $0.category == category }) { reading in
                    NavigationLink {
                        StudyReadingView(reading: reading, showNiqqud: $showNiqqud)
                    } label: {
                        StudyCard(padding: 10) {
                            StudyRow(title: reading.title, symbol: "text.book.closed",
                                     subtitle: "\(reading.sentences.count) 句 · 阅读理解")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .studyDetail("阅读练习")
    }
}

private struct WordDetailView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let word: StudyWord
    let content: StudyContent
    @State var showNiqqud: Bool
    @State var showCursive: Bool

    private var displayedWord: String { showNiqqud ? word.hebrew : word.hebrewUnpointed }

    private let formLabels = [("ms", "阳性单数"), ("fs", "阴性单数"), ("mp", "阳性复数"), ("fp", "阴性复数"),
                              ("infinitive", "不定式"), ("past3ms", "过去式"), ("singular", "单数"), ("plural", "复数")]

    var body: some View {
        StudyPage {
            StudyCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HebrewText(text: displayedWord, cursive: showCursive,
                                   size: 56, style: .largeTitle)
                        Text("\(word.transliteration)  \(word.ipa)")
                            .font(.subheadline.weight(.medium)).foregroundStyle(progress.theme.mutedInk)
                        Text(word.meaningZh).font(.title3.weight(.semibold)).foregroundStyle(progress.theme.ink)
                    }
                    Spacer(minLength: 0)
                    PronunciationButton(hebrew: word.hebrew, iconOnly: true,
                                        title: "播放单词发音")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { displayControls }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 6) { displayControls }
                }
            }
            MasteryPicker(value: Binding(get: { progress.wordMastery[word.id] ?? .unlearned }, set: {
                progress.setWord(word.id, mastery: $0)
            }))
            if let schedule = progress.schedule[word.id] {
                StudyNotice(title: "下次复习 · \(schedule.displayDate)", symbol: "calendar",
                            reminder: schedule.isDue)
            }
            if let sentence = word.sentence {
                StudySectionTitle("例句")
                StudyCard {
                    WordExampleRow(example: StudyExample(hebrew: sentence.hebrew, transliteration: sentence.transliteration,
                                                         meaning: sentence.meaningZh, note: nil),
                                   showNiqqud: showNiqqud, cursive: showCursive)
                }
            }
            StudyNotice(title: [word.partOfSpeech, word.grammarTag].filter { !$0.isEmpty }.joined(separator: " · "),
                        symbol: "info.circle", note: word.root.map { "词根 · \($0)" })
            if !word.note.isEmpty {
                StudyCard { DisclosureGroup("用法") { Text(word.note).padding(.top, 6) } }
            }
            if !letters.isEmpty {
                StudySectionTitle("拆成字母")
                letterLinks
            }
            let forms = content.inflections[word.id] ?? [:]
            if !forms.isEmpty {
                StudySectionTitle("词形变化")
                StudyCard {
                    ForEach(formLabels, id: \.0) { key, label in
                        if let form = forms[key] {
                            HStack {
                                HebrewText(text: showNiqqud ? form.hebrew : withoutHebrewMarks(form.hebrew),
                                           cursive: showCursive, size: 29)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(form.translit).font(.subheadline.weight(.medium))
                                    Text(form.label ?? label).font(.caption).foregroundStyle(progress.theme.mutedInk)
                                }
                                Spacer(minLength: 0)
                                PronunciationButton(hebrew: form.hebrew, iconOnly: true,
                                                    title: "播放\(form.label ?? label)")
                            }
                        }
                    }
                }
            }
            if let root = word.root {
                let related = content.words.filter { $0.root == root && $0.id != word.id }
                if !related.isEmpty {
                    StudyCard {
                        DisclosureGroup("同词根关联词") {
                            ForEach(related) { item in
                                NavigationLink {
                                    WordDetailView(word: item, content: content, showNiqqud: showNiqqud, showCursive: showCursive)
                                } label: {
                                    StudyRow(title: item.hebrew, symbol: "link", subtitle: item.meaningZh)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .studyDetail("单词详情")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    progress.toggleFavorite(word.id)
                } label: {
                    let saved = progress.favorites.contains(word.id)
                    Label(saved ? "取消收藏" : "收藏", systemImage: saved ? "bookmark.fill" : "bookmark")
                }
            }
        }
    }

    @ViewBuilder private var displayControls: some View {
        Button { showNiqqud.toggle() } label: {
            Label("元音点：\(showNiqqud ? "开" : "关")", systemImage: "ellipsis")
        }
        .buttonStyle(StudyButtonStyle(selected: showNiqqud))
        Button { showCursive.toggle() } label: {
            Label(showCursive ? "手写体" : "印刷体", systemImage: "textformat")
        }
        .buttonStyle(StudyButtonStyle())
        .accessibilityHint("轻点切换字形")
    }

    private var letterLinks: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(Array(letters.enumerated()), id: \.offset) { _, entry in
                    NavigationLink {
                        LetterStudyView(letter: entry.letter, content: content, showsFinalForm: entry.letter.sofit == String(entry.character))
                    } label: {
                        HebrewText(text: String(entry.character), cursive: showCursive, size: 25)
                            .frame(minWidth: 48, minHeight: 44)
                            .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entry.letter.nameChinese)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .scrollIndicators(.hidden)
    }

    private var letters: [(character: Character, letter: StudyLetter)] {
        withoutHebrewMarks(displayedWord).compactMap { character in
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
        StudyPage {
            if let source = reading.source {
                Text(source).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
            }
            StudySegments(title: "阅读方式", options: [(false, "原文"), (true, "中希对照")], selection: $showTranslation)
            StudySectionTitle("原文与朗读")
            StudyNotice(title: "点按标记的词查看释义", symbol: "hand.tap")
            ForEach(Array(reading.sentences.enumerated()), id: \.offset) { index, sentence in
                StudyCard { sentenceRow(sentence, at: index) }
            }
            StudySectionTitle("阅读理解")
            StudyCard { Text(reading.question.prompt).font(.headline) }
            ForEach(Array(reading.question.choices.enumerated()), id: \.offset) { index, choice in
                StudyAnswerButton(title: choice, submitted: answer == reading.question.correctIndex,
                                  selected: answer == index, correct: index == reading.question.correctIndex,
                                  optionLabel: studyOptionLabel(index)) {
                    answer = index
                    if index == reading.question.correctIndex { progress.recordStudy() }
                }
            }
            if let answer {
                let correct = answer == reading.question.correctIndex
                StudyNotice(title: correct ? "回答正确" : "再读一下原文，然后重试",
                            symbol: correct ? "checkmark.circle" : "info.circle")
            }
        }
        .studyDetail(reading.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("显示元音点", isOn: $showNiqqud)
                } label: {
                    Label("阅读选项", systemImage: "slider.horizontal.3")
                }
            }
        }
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
            if showTranslation {
                Text(sentence.chinese)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PronunciationButton(hebrew: sentence.hebrew,
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

enum WordQuizKind: String, CaseIterable, Identifiable {
    case meaning, listening, spelling

    var id: Self { self }
    var title: String {
        switch self {
        case .meaning: "词义"
        case .listening: "听力"
        case .spelling: "拼写"
        }
    }
    var symbol: String {
        switch self {
        case .meaning: "book"
        case .listening: "headphones"
        case .spelling: "keyboard"
        }
    }
}

struct WordReviewView: View {
    let content: StudyContent
    @State private var words: [StudyWord]

    init(content: StudyContent, words: [StudyWord]) {
        self.content = content
        _words = State(initialValue: words)
    }

    var body: some View {
        WordQuizView(content: content, words: words, kind: .meaning, reviewing: true)
    }
}

struct WordQuizView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dismiss) private var dismiss
    let content: StudyContent
    let words: [StudyWord]
    let kind: WordQuizKind
    var reviewing = false

    @State private var target: StudyWord?
    @State private var options: [StudyWord] = []
    @State private var spelling = ""
    @State private var result: Bool?
    @State private var selectedOption: String?
    @State private var systemInput = false
    @FocusState private var inputFocused: Bool
    @State private var correct = 0
    @State private var answered = 0
    @State private var streak = 0
    @State private var reviewIndex = 0
    @State private var showsSummary = false
    @State private var started = false

    private var showNiqqud: Bool {
        progress.read("alef.wordsState.v1", default: WordPreferences()).showNiqqud
    }

    var body: some View {
        ScrollViewReader { scroll in
            StudyPage {
                if showsSummary {
                    summary
                } else if let target {
                    quizHeader
                    questionPrompt(target).id("word-question")
                    if kind == .spelling {
                        spellingInput
                    } else {
                        ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                            StudyAnswerButton(title: option.meaningZh, submitted: result != nil,
                                              selected: selectedOption == option.id, correct: option.id == target.id,
                                              optionLabel: studyOptionLabel(index)) {
                                selectedOption = option.id
                            }
                        }
                    }
                    if let result {
                        feedback(target, correct: result).id("word-result")
                    }
                } else if started {
                    ContentUnavailableView(reviewing ? "没有到期的单词" : "没有可用的单词",
                                           systemImage: reviewing ? "calendar.badge.checkmark" : "character.book.closed",
                                           description: Text(reviewing ? "在词库标记掌握度后，这里会显示到期的单词。" : "可以返回练习中心选择其他题型。"))
                }
            }
            .onChange(of: target?.id) { _, _ in scroll.scrollTo("word-question", anchor: .top) }
            .onChange(of: result) { _, value in
                if value != nil { scroll.scrollTo("word-result", anchor: .bottom) }
            }
        }
        .studyDetail(reviewing ? "到期复习" : "\(kind.title)练习")
        .toolbar {
            if !reviewing && answered > 0 && !showsSummary {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("结束") { showsSummary = true }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if started { StudyActionBar { quizAction } }
        }
        .task {
            guard !started else { return }
            started = true
            next(play: false)
        }
        .onDisappear { audio.stop() }
    }

    private var quizHeader: some View {
        HStack(spacing: 9) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { quizStatus }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 5) { quizStatus }
            }
            Spacer(minLength: 0)
            if !reviewing && result == nil {
                Button { next(play: true) } label: {
                    Image(systemName: "arrow.clockwise").frame(minWidth: 24)
                }
                .buttonStyle(StudyButtonStyle())
                .accessibilityLabel("换一题")
            }
        }
        .monospacedDigit()
    }

    @ViewBuilder private var quizStatus: some View {
        if reviewing {
            Text("\(reviewIndex + 1) / \(words.count)").font(.subheadline.weight(.semibold))
            ProgressView(value: Double(reviewIndex + 1), total: Double(max(1, words.count)))
                .tint(progress.theme.accent)
                .frame(minWidth: 38, maxWidth: 160)
                .accessibilityLabel("复习进度")
        }
        Label("得分 \(correct) / \(answered)", systemImage: "star")
            .font(.caption.weight(.semibold)).foregroundStyle(progress.theme.mutedInk)
        if !reviewing {
            Label("连对 \(streak)", systemImage: "flame")
                .font(.caption.weight(.semibold)).foregroundStyle(progress.theme.reminder)
        }
    }

    private func questionPrompt(_ target: StudyWord) -> some View {
        StudyCard(highlighted: kind != .meaning) {
            switch kind {
            case .listening:
                StudySectionTitle("听发音，选择词义")
                PronunciationButton(hebrew: target.hebrew,
                                    title: "播放题目", prominent: true, bundledOnly: true)
            case .spelling:
                Label("写出「\(target.meaningZh)」", systemImage: "pencil").font(.headline)
                Text("提示 · \(target.transliteration)").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                Text("可输入带点写法或无点全拼").font(.caption).foregroundStyle(progress.theme.mutedInk)
            case .meaning:
                StudySectionTitle("这个单词是什么意思？")
                HStack {
                    Spacer(minLength: 0)
                    HebrewText(text: content.meaningPrompt(for: target, showNiqqud: showNiqqud), size: 52, style: .largeTitle)
                    Spacer(minLength: 0)
                    PronunciationButton(hebrew: target.hebrew, iconOnly: true)
                }
            }
        }
    }

    private func feedback(_ target: StudyWord, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StudyQuizFeedback(correct: correct,
                              solution: kind == .spelling ? "\(target.hebrew) · \(target.hebrewUnpointed)" : "\(target.hebrew) · \(target.meaningZh)",
                              response: kind == .spelling ? spelling : options.first { $0.id == selectedOption }?.meaningZh,
                              explanation: "\(target.transliteration) · \(target.partOfSpeech)")
            if kind == .spelling {
                PronunciationButton(hebrew: target.hebrew, title: "听正确发音")
            }
            if reviewing, let schedule = progress.schedule[target.id] {
                StudyNotice(title: "下次复习 · \(schedule.displayDate)", symbol: "calendar")
            }
        }
    }

    private var spellingInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            StudyCard {
                if systemInput && result == nil {
                    TextField("输入希伯来语单词", text: $spelling)
                        .font(.title2)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($inputFocused)
                        .submitLabel(.done)
                        .onSubmit(confirm)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 44)
                        .environment(\.layoutDirection, .rightToLeft)
                } else if spelling.isEmpty {
                    Text("在下方选择希伯来字母")
                        .foregroundStyle(progress.theme.mutedInk)
                        .frame(maxWidth: .infinity, minHeight: 52)
                } else {
                    HebrewText(text: spelling, size: 44, style: .largeTitle)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .textSelection(.enabled)
                }
            }
            if result == nil {
                if !systemInput { spellingKeyboard }
                Button {
                    systemInput.toggle()
                    inputFocused = systemInput
                } label: {
                    Label(systemInput ? "使用屏内键盘" : "使用系统键盘", systemImage: "globe")
                }
                .buttonStyle(StudyButtonStyle())
            }
        }
    }

    @ViewBuilder private var quizAction: some View {
        if showsSummary {
            primaryButton("完成", symbol: "checkmark") { dismiss() }
        } else if target == nil {
            primaryButton("返回", symbol: "chevron.backward") { dismiss() }
        } else if result != nil {
            let finishing = reviewing && reviewIndex + 1 >= words.count
            primaryButton(finishing ? "查看复习结果" : "下一题", symbol: "arrow.right") {
                if finishing { showsSummary = true }
                else {
                    if reviewing { reviewIndex += 1 }
                    next(play: true)
                }
            }
        } else {
            primaryButton("确认答案", symbol: "checkmark", action: confirm)
                .disabled(kind == .spelling ? spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : selectedOption == nil)
        }
    }

    private var summary: some View {
        let nextReview = words.compactMap { progress.schedule[$0.id] }.min { $0.nextReviewAt < $1.nextReviewAt }
        return StudyQuizSummary(title: reviewing ? "完成到期复习" : "完成练习", correct: correct, answered: answered,
                                message: reviewing ? nextReview.map { "下次复习 · \($0.displayDate)" } : nil)
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(prominent: true))
    }

    private func confirm() {
        guard let target, result == nil else { return }
        let success: Bool
        if kind == .spelling {
            guard !spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            inputFocused = false
            success = target.acceptsSpelling(spelling)
        } else {
            guard let selectedOption else { return }
            success = selectedOption == target.id
        }
        result = success
        answered += 1
        if success { correct += 1 }
        streak = success ? streak + 1 : 0
        if reviewing { progress.completeReview(target.id, correct: success) }
        else { progress.recordStudy() }
        audio.playFeedback(success ? .correct : .wrong)
    }

    private var spellingKeyboard: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 5)], spacing: 5) {
                ForEach(content.letters.map(\.hebrew) + content.letters.compactMap(\.sofit), id: \.self) { character in
                    Button { spelling += character } label: {
                        HebrewText(text: character, size: 23)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            HStack {
                Button("退格", systemImage: "delete.left") { if !spelling.isEmpty { spelling.removeLast() } }
                Button("清空", systemImage: "eraser") { spelling = "" }
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(spelling.isEmpty)
        }
        .padding(8)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func next(play: Bool) {
        let pool = switch kind {
        case .spelling: words.filter(\.canPracticeSpelling)
        case .listening: words.filter { content.audio[$0.hebrew] != nil }
        case .meaning: words
        }
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
        if kind != .spelling {
            options = ([target] + content.distractors(for: target, listening: kind == .listening)).shuffled()
        }
        if kind == .listening, play {
            audio.speak(target.hebrew, rate: progress.speechRate, bundledOnly: true)
        }
    }
}
