import SwiftUI

struct WordPreferences: Codable {
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
    var frequency: WordFrequency?
    var frequencyTier: String?
    var selectedPackId: String?
    var difficulty: WordDifficulty?

    static let scopes = [("all", "全部"), ("favorites", "收藏"), ("needs_review", "需复习"), ("due_srs", "到期复习")]
    static let frequencyTiers: [(String?, String)] = [(nil, "全部词库"), ("top1000", "Top 1000"), ("top2000", "Top 2000")]

    var activePackId: String? {
        if let selectedPackId { return selectedPackId }
        switch frequencyTier {
        case "top1000": return "pack_top1000"
        case "top2000": return "pack_top2000"
        default: return nil
        }
    }

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
        frequency = nil
        frequencyTier = nil
        selectedPackId = nil
        difficulty = nil
    }
}

struct WordsView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @FocusState private var searchFocused: Bool
    @State private var openedWordID: String?
    @State private var showsFilters = false
    @State private var phraseCategory = "all"
    @State private var hidePhraseTranslation = false
    @State private var shadowingPhraseId: String?
    @State private var displayLimit = 40

    private var pinnedPacks: [StudyWordPack] {
        progress.pinnedWordPackIds.compactMap { content.wordPack(id: $0) }
    }

    private var currentPack: StudyWordPack? {
        if let id = preferences.activePackId,
           let matched = pinnedPacks.first(where: { $0.id == id }) {
            return matched
        }
        return pinnedPacks.first
    }

    var body: some View {
        let activePack = currentPack
        StudyPage(keyboardDismissMode: .immediately, verticalBounce: searchFocused ? .always : .basedOnSize,
                  showsScrollToTop: true) {
            StudyHeading(title: "内容库", eyebrow: "LIBRARY")
            if activePack != nil {
                searchControls
            }
            frequencyTierBar
            if let activePack {
                switch activePack.kind {
                case .phrases:
                    phraseLibrary
                case .readings:
                    StudyReadingLibrary(content: content, showNiqqud: setting(\.showNiqqud), showCursive: setting(\.showCursive),
                                        searchQuery: preferences.searchQuery)
                case .words:
                    quickTogglesBar
                    if hasFilters { activeFilters }
                    wordLibrary
                }
            } else {
                ContentUnavailableView {
                    Label("还没有固定学习包", systemImage: "square.grid.2x2")
                } description: {
                    Text("前往包管理，点按图钉即可把常用词包、情景短语或阅读固定到这里。")
                } actions: {
                    NavigationLink("打开包管理") {
                        StudyPackManagerView(content: content,
                                             showNiqqud: setting(\.showNiqqud),
                                             showCursive: setting(\.showCursive))
                    }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                }
            }
        }
        .studyHome()
        .onChange(of: currentPack?.id) { _, _ in
            searchFocused = false
            displayLimit = 40
        }
        .onChange(of: filterSignature) { _, _ in displayLimit = 40 }
        .onDisappear { searchFocused = false }
        .navigationDestination(item: $openedWordID) { id in
            if let word = content.words.first(where: { $0.id == id }) {
                WordDetailView(word: word, content: content, showNiqqud: preferences.showNiqqud,
                               showCursive: preferences.showCursive)
            }
        }
        .sheet(isPresented: $showsFilters) {
            NavigationStack {
                WordFilterSheet(content: content, preferences: preferences) { updated in
                    progress.write(updated, for: "alef.wordsState.v1")
                }
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var preferences: WordPreferences { progress.read("alef.wordsState.v1", default: WordPreferences()) }

    private func setting<Value>(_ path: WritableKeyPath<WordPreferences, Value>) -> Binding<Value> {
        Binding(get: { preferences[keyPath: path] }, set: { value in
            var state = preferences
            state[keyPath: path] = value
            progress.write(state, for: "alef.wordsState.v1")
        })
    }

    private var searchControls: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
        let favoritesOnly = preferences.scope == "favorites"
        return layout {
            searchField
            HStack(spacing: 6) {
                Button {
                    var state = preferences
                    state.topic = state.selectedTopic
                    state.activeFilter = favoritesOnly ? "all" : "favorites"
                    progress.write(state, for: "alef.wordsState.v1")
                } label: {
                    Image(systemName: favoritesOnly ? "bookmark.fill" : "bookmark")
                        .frame(width: 44, height: 44)
                        .background(favoritesOnly ? progress.theme.highlightedSurface : progress.theme.insetSurface,
                                    in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("仅看收藏")
                .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
                Button { showsFilters = true } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .frame(width: 44, height: 44)
                        .background(hasFilters ? progress.theme.highlightedSurface : progress.theme.insetSurface,
                                    in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("筛选与排序")
            }
            .foregroundStyle(progress.theme.accent)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(progress.theme.mutedInk).accessibilityHidden(true)
            TextField(currentPack.map { "在「\($0.shortTitle)」中搜索" } ?? "搜索单词", text: setting(\.searchQuery))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { searchFocused = false }
                .accessibilityLabel("在当前学习包中搜索")
                .accessibilityHint("仅在当前显示的学习包内按希伯来语、中文、音译或词根搜索")
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
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(progress.theme.cardSurface, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(progress.theme.outline.opacity(0.8), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var filterSignature: String {
        let s = preferences
        return [
            s.searchQuery,
            s.activeFilter,
            s.selectedTopic ?? "",
            s.initialLetter,
            s.frequency?.rawValue ?? "",
            s.activePackId ?? "",
            s.difficulty?.rawValue ?? "",
            s.sortOrder,
            s.usesCards ? "cards" : "list",
        ].joined(separator: "|")
    }

    private var frequencyTierBar: some View {
        let selected = currentPack?.id
        return ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(pinnedPacks) { pack in
                    packBarPill(pack.shortTitle, symbol: pack.symbol, active: selected == pack.id) {
                        var state = preferences
                        state.selectedPackId = pack.id
                        state.frequencyTier = nil
                        progress.write(state, for: "alef.wordsState.v1")
                    }
                }
                NavigationLink {
                    StudyPackManagerView(content: content,
                                         showNiqqud: setting(\.showNiqqud),
                                         showCursive: setting(\.showCursive))
                } label: {
                    Label("包管理", systemImage: "square.grid.2x2")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(progress.theme.accent)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 36)
                        .background(progress.theme.highlightedSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func packBarPill(_ title: String, symbol: String?, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Label(title, systemImage: symbol)
                } else {
                    Text(title)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(active ? Color.white : progress.theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(active ? progress.theme.primaryButton : progress.theme.insetSurface,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var quickTogglesBar: some View {
        let favoritesOnly = preferences.scope == "favorites"
        return ScrollView(.horizontal) {
            HStack(spacing: 6) {
                quickPill(preferences.showNiqqud ? "● 元音点" : "○ 元音点", active: preferences.showNiqqud) {
                    var state = preferences
                    state.showNiqqud.toggle()
                    progress.write(state, for: "alef.wordsState.v1")
                }
                quickPill("手写体", symbol: "pencil.tip", active: preferences.showCursive) {
                    var state = preferences
                    state.showCursive.toggle()
                    progress.write(state, for: "alef.wordsState.v1")
                }
                quickPill("仅看收藏", symbol: favoritesOnly ? "bookmark.fill" : "bookmark", active: favoritesOnly) {
                    var state = preferences
                    state.topic = state.selectedTopic
                    state.activeFilter = favoritesOnly ? "all" : "favorites"
                    progress.write(state, for: "alef.wordsState.v1")
                }
                quickPill(preferences.usesCards ? "卡片布局" : "列表布局",
                          symbol: preferences.usesCards ? "square.grid.2x2" : "list.bullet",
                          active: preferences.usesCards) {
                    var state = preferences
                    state.setCardLayout(!state.usesCards)
                    progress.write(state, for: "alef.wordsState.v1")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func quickPill(_ title: String, symbol: String? = nil, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Label(title, systemImage: symbol)
                } else {
                    Text(title)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(active ? Color.white : progress.theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(active ? progress.theme.primaryButton : progress.theme.insetSurface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var hasFilters: Bool {
        let settings = preferences
        return (settings.scope != "all" && settings.scope != "favorites") || settings.selectedTopic != nil
            || settings.initialLetter != "all" || settings.frequency != nil || settings.difficulty != nil
    }

    private var activeFilters: some View {
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

    private var filterDescription: String {
        let settings = preferences
        var labels = [WordPreferences.scopes.first { $0.0 == settings.scope }?.1 ?? "全部"]
        if let packId = settings.activePackId, let pack = content.wordPack(id: packId) {
            labels.append(pack.title)
        }
        if let topic = settings.selectedTopic { labels.append(content.wordCategories[topic]?.label ?? topic) }
        if let frequency = settings.frequency { labels.append(frequency.label) }
        if let difficulty = settings.difficulty { labels.append(difficulty.label) }
        if settings.initialLetter != "all" { labels.append("首字母 \(settings.initialLetter)") }
        return labels.joined(separator: " · ")
    }

    private var filteredWords: [StudyWord] {
        guard let activePack = currentPack, activePack.kind == .words else { return [] }
        let settings = preferences
        let favorites = Set(progress.favorites)
        let schedule = progress.schedule
        let query = settings.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let unpointedQuery = withoutHebrewMarks(query)
        let scope = settings.scope
        let topic = settings.selectedTopic
        let sourceWords = content.words(inPack: activePack.id)
        let words = sourceWords.filter { word in
            let include = switch scope {
            case "favorites": favorites.contains(word.id)
            case "needs_review": progress.effectiveWordMastery(word.id) != .mastered
            case "due_srs": schedule[word.id]?.isDue == true
            default: true
            }
            let searchable = [word.hebrew, word.hebrewUnpointed, word.transliteration, word.meaningZh, word.root ?? "", word.ipa]
                + (word.alternateSpellings ?? [])
            return include && (topic == nil || word.category == topic)
                && (settings.frequency == nil || word.frequency == settings.frequency)
                && (settings.difficulty == nil || word.difficulty == settings.difficulty)
                && (settings.initialLetter == "all" || word.hebrewUnpointed.hasPrefix(settings.initialLetter))
                && (query.isEmpty || searchable.contains { $0.localizedStandardContains(query) }
                    || (!unpointedQuery.isEmpty && word.hebrewUnpointed.localizedStandardContains(unpointedQuery)))
        }
        switch settings.sortOrder {
        case "alpha":
            return words.sorted { $0.hebrewUnpointed < $1.hebrewUnpointed }
        default:
            return words.sorted {
                let lhs = ($0.frequencyRank ?? Int.max, $0.frequency.rank, $0.hebrewUnpointed)
                let rhs = ($1.frequencyRank ?? Int.max, $1.frequency.rank, $1.hebrewUnpointed)
                return lhs < rhs
            }
        }
    }

    @ViewBuilder private var wordLibrary: some View {
        let prefs = preferences
        let words = filteredWords
        let favorites = Set(progress.favorites)
        let masteredCount = words.reduce(into: 0) { count, word in
            if progress.effectiveWordMastery(word.id) == .mastered { count += 1 }
        }
        let activePack = currentPack
        let showRank = activePack != nil || prefs.sortOrder == "frequency"
        let visibleWords = Array(words.prefix(displayLimit))
        HStack(spacing: 8) {
            if let activePack {
                Text("\(activePack.title) · 共 \(words.count) 词")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.theme.accent)
            } else {
                Text("共 \(words.count) 词")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(progress.theme.mutedInk)
            }
            Spacer(minLength: 0)
            if !words.isEmpty {
                Text("已掌握 \(masteredCount)/\(words.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(progress.theme.mutedInk)
                    .monospacedDigit()
            }
        }
        if words.isEmpty {
            ContentUnavailableView {
                Label("没有匹配的单词", systemImage: "magnifyingglass")
            } description: {
                Text("当前仅在「\(activePack?.shortTitle ?? "当前包")」中检索，可更换搜索词或切换其他学习包。")
            } actions: {
                Button("清除搜索和筛选") {
                    var state = prefs
                    state.resetFilters()
                    state.searchQuery = ""
                    progress.write(state, for: "alef.wordsState.v1")
                }
                .buttonStyle(StudyButtonStyle())
            }
        } else {
            let lastVisibleId = visibleWords.last?.id
            if prefs.usesCards {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 280 : 152), spacing: 8)], spacing: 8) {
                    ForEach(visibleWords) { word in
                        wordRow(word, favorite: favorites.contains(word.id), mastery: progress.effectiveWordMastery(word.id),
                                stacked: true, showNiqqud: prefs.showNiqqud, showCursive: prefs.showCursive, showRank: showRank)
                            .onAppear {
                                if word.id == lastVisibleId, displayLimit < words.count {
                                    DispatchQueue.main.async {
                                        displayLimit = min(words.count, displayLimit + 40)
                                    }
                                }
                            }
                    }
                }
            } else {
                LazyVStack(spacing: 7) {
                    ForEach(visibleWords) { word in
                        wordRow(word, favorite: favorites.contains(word.id), mastery: progress.effectiveWordMastery(word.id),
                                stacked: typeSize.isAccessibilitySize, showNiqqud: prefs.showNiqqud, showCursive: prefs.showCursive, showRank: showRank)
                            .onAppear {
                                if word.id == lastVisibleId, displayLimit < words.count {
                                    DispatchQueue.main.async {
                                        displayLimit = min(words.count, displayLimit + 40)
                                    }
                                }
                            }
                    }
                }
            }
            if visibleWords.count < words.count {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载更多… (\(visibleWords.count)/\(words.count))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(progress.theme.mutedInk)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, minHeight: 40)
            }
        }
    }

    private func wordRow(_ word: StudyWord, favorite: Bool, mastery: Mastery, stacked: Bool, showNiqqud: Bool, showCursive: Bool, showRank: Bool) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 0))
        return StudyCard(padding: stacked ? 10 : 7) {
            layout {
                if !stacked { wordMasteryMenu(word, mastery: mastery) }
                Button {
                    searchFocused = false
                    openedWordID = word.id
                } label: {
                    let hebrew = HebrewText(text: showNiqqud ? word.hebrew : word.hebrewUnpointed,
                                            cursive: showCursive, size: stacked ? 30 : 28)
                        .lineLimit(stacked ? nil : 2)
                        .minimumScaleFactor(0.75)
                    let details = VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            if showRank, let rank = word.frequencyRank {
                                Text("#\(rank)")
                                    .font(.caption2.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(progress.theme.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(progress.theme.highlightedSurface, in: Capsule())
                            }
                            Text(word.transliteration)
                                .font(stacked ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                                .foregroundStyle(stacked ? progress.theme.accent : progress.theme.ink)
                                .lineLimit(1)
                        }
                        Text(word.meaningZh)
                            .font(stacked ? .subheadline.weight(.medium) : .caption)
                            .foregroundStyle(stacked ? progress.theme.ink : progress.theme.mutedInk)
                            .lineLimit(stacked ? 2 : 1)
                    }
                    Group {
                        if stacked {
                            let stageShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                            VStack(alignment: .leading, spacing: 8) {
                                hebrew
                                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background(progress.theme.insetSurface, in: stageShape)
                                    .overlay {
                                        stageShape.strokeBorder(progress.theme.outline.opacity(0.65), lineWidth: 1)
                                    }
                                details
                                    .padding(.horizontal, 2)
                            }
                        } else {
                            HStack(spacing: 6) {
                                details
                                Spacer(minLength: 4)
                                hebrew
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(mastery.title)
                }
                .buttonStyle(.plain)
                if stacked {
                    Rectangle()
                        .fill(progress.theme.outline.opacity(0.55))
                        .frame(height: 1)
                }
                HStack(spacing: 0) {
                    if stacked { wordMasteryMenu(word, mastery: mastery) }
                    PronunciationButton(hebrew: word.hebrew, iconOnly: true,
                                        title: "播放\(word.meaningZh)的发音")
                    if stacked { Spacer(minLength: 0) }
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
        let proficiency = progress.wordProficiency(word.id)
        let tint = proficiency > 0 ? StudyProficiencyStyle.color(for: proficiency) : progress.theme.mutedInk
        let surface = proficiency > 0 ? tint.opacity(0.14) : progress.theme.insetSurface
        return VStack(spacing: 3) {
            Image(systemName: mastery.symbol).font(.subheadline)
            Text(mastery.title).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .frame(minWidth: 46, minHeight: 46)
        .background(surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(word.meaningZh)的状态")
        .accessibilityValue(mastery.title)
    }

    private func masteryTint(_ mastery: Mastery) -> Color {
        switch mastery {
        case .mastered: progress.theme.success
        case .learning: progress.theme.learningAction
        case .unlearned: progress.theme.mutedInk
        }
    }

    private func masterySurface(_ mastery: Mastery) -> Color {
        switch mastery {
        case .mastered: progress.theme.successSurface
        case .learning: progress.theme.highlightedSurface
        case .unlearned: progress.theme.insetSurface
        }
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
            Menu {
                Toggle("隐藏中文，自测释义", isOn: $hidePhraseTranslation)
                Toggle("显示元音点", isOn: setting(\.showNiqqud))
                Toggle("手写体", isOn: setting(\.showCursive))
            } label: {
                Label("短语显示", systemImage: "textformat").frame(minHeight: 44)
            }
            .buttonStyle(StudyButtonStyle())
            let query = preferences.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let unpointedQuery = withoutHebrewMarks(query)
            let phrases = content.phrases.filter { phrase in
                let inCategory = phraseCategory == "all" || phrase.scenario == phraseCategory
                    || (phraseCategory == "favorites" && favorites.contains(phrase.id))
                let matchesQuery = query.isEmpty
                    || [phrase.hebrew, phrase.hebrewUnpointed, phrase.transliteration, phrase.meaningZh, phrase.note ?? ""]
                        .contains { $0.localizedStandardContains(query) }
                    || (!unpointedQuery.isEmpty && phrase.hebrewUnpointed.localizedStandardContains(unpointedQuery))
                return inCategory && matchesQuery
            }
            if phrases.isEmpty {
                ContentUnavailableView(query.isEmpty ? "还没有收藏短语" : "没有匹配的短语",
                                       systemImage: query.isEmpty ? "bookmark" : "magnifyingglass")
            }
            let prefs = preferences
            LazyVStack(spacing: 9) {
                ForEach(phrases) { phrase in
                    phraseRow(phrase, favorites: favorites, showNiqqud: prefs.showNiqqud, showCursive: prefs.showCursive)
                }
            }
        }
    }

    private func phraseScope(_ title: String, key: String) -> some View {
        Button(title) { phraseCategory = key }
            .buttonStyle(StudyButtonStyle(selected: phraseCategory == key))
            .accessibilityAddTraits(phraseCategory == key ? .isSelected : [])
    }

    private func phraseRow(_ phrase: StudyPhrase, favorites: [String], showNiqqud: Bool, showCursive: Bool) -> some View {
        let saved = favorites.contains(phrase.id)
        let isShadowing = shadowingPhraseId == phrase.id
        return StudyCard {
            VStack(alignment: .trailing, spacing: 4) {
                HebrewText(text: showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed,
                           cursive: showCursive, size: 34, style: .title)
                Text(phrase.transliteration).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                if !hidePhraseTranslation {
                    Text(phrase.meaningZh).font(.headline)
                }
            }
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            if !hidePhraseTranslation, let note = phrase.note {
                Text(note).font(.footnote).foregroundStyle(progress.theme.mutedInk)
            }

            HStack(spacing: 4) {
                PronunciationButton(hebrew: phrase.hebrew, iconOnly: true, title: "播放短语原音")
                Menu {
                    Button("慢速播放（0.68×）", systemImage: "tortoise") {
                        audio.speak(phrase.hebrew, rate: 0.68)
                    }
                    Button(isShadowing ? "收起跟读" : "跟读", systemImage: "mic") {
                        shadowingPhraseId = isShadowing ? nil : phrase.id
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("短语播放与跟读选项")
                Spacer(minLength: 0)
                Button {
                    let updated = saved ? favorites.filter { $0 != phrase.id } : favorites + [phrase.id]
                    progress.write(updated, for: "alef.native.phraseFavorites.v1")
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(saved ? "取消收藏短语" : "收藏短语")
            }
            .foregroundStyle(progress.theme.accent)
            if isShadowing {
                ShadowingPracticeCard(hebrew: phrase.hebrew, title: "跟读短句")
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
            StudySectionTitle("常用程度")
            StudySegments(title: "常用程度",
                          options: [(nil, "不限")] + WordFrequency.allCases.map { (Optional($0), $0.label) },
                          selection: $preferences.frequency)
            StudySectionTitle("拼读难度")
            StudySegments(title: "拼读难度",
                          options: [(nil, "不限")] + WordDifficulty.allCases.map { (Optional($0), $0.label) },
                          selection: $preferences.difficulty)
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
            StudySegments(title: "排序",
                          options: [("default", "默认"), ("frequency", "高频优先"), ("alpha", "字母")],
                          selection: $preferences.sortOrder)
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
    @Binding var showCursive: Bool
    var searchQuery: String = ""

    var body: some View {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingCategories = content.readingCategories.keys.sorted().filter { category in
            !readings(in: category, query: query).isEmpty
        }
        if matchingCategories.isEmpty {
            ContentUnavailableView("没有匹配的阅读篇目", systemImage: "magnifyingglass")
        } else {
            ForEach(matchingCategories, id: \.self) { category in
                StudySectionTitle(content.readingCategories[category] ?? category)
                StudyCard(padding: 10, spacing: 2) {
                    let items = readings(in: category, query: query)
                    ForEach(items) { reading in
                        if reading.id != items.first?.id { Divider() }
                        NavigationLink {
                            StudyReadingView(reading: reading, showNiqqud: $showNiqqud, showCursive: $showCursive)
                        } label: {
                            let details = ["\(reading.sentences.count) 句", "阅读理解"] + reading.audioStyles.map(\.title)
                            StudyRow(title: reading.title, symbol: "text.book.closed",
                                     subtitle: details.joined(separator: " · "))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func readings(in category: String, query: String) -> [StudyReading] {
        content.readings.filter { reading in
            guard reading.category == category else { return false }
            if query.isEmpty { return true }
            return reading.title.localizedStandardContains(query)
                || (reading.source?.localizedStandardContains(query) ?? false)
        }
    }
}

struct WordDetailView: View {
    @Environment(StudyProgress.self) private var progress
    let word: StudyWord
    let content: StudyContent
    @State var showNiqqud: Bool
    @State var showCursive: Bool
    @State private var isRecording = false

    init(word: StudyWord, content: StudyContent, showNiqqud: Bool = true, showCursive: Bool = false) {
        self.word = word
        self.content = content
        _showNiqqud = State(initialValue: showNiqqud)
        _showCursive = State(initialValue: showCursive)
    }

    private var displayedWord: String { showNiqqud ? word.hebrew : word.hebrewUnpointed }

    private let formLabels = [("ms", "阳性单数"), ("fs", "阴性单数"), ("mp", "阳性复数"), ("fp", "阴性复数"),
                              ("infinitive", "不定式"), ("past3ms", "过去式"), ("singular", "单数"), ("plural", "复数")]

    var body: some View {
        StudyPage {
            StudyCard {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        let tag = [content.wordCategories[word.category]?.label, word.partOfSpeech, word.grammarTag]
                            .compactMap { $0 }
                            .filter { !$0.isEmpty }
                            .joined(separator: " · ")
                        if !tag.isEmpty {
                            Text(tag)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(progress.theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(progress.theme.highlightedSurface, in: Capsule())
                        }
                        let freqText = word.frequencyRank.map { "\(word.frequency.label) #\($0)" } ?? word.frequency.label
                        Text("\(freqText) · \(word.difficulty.label)")
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                        HebrewText(text: displayedWord, cursive: showCursive,
                                   size: 56, style: .largeTitle)
                        Text("\(word.transliteration)  \(word.ipa)")
                            .font(.subheadline.weight(.medium)).foregroundStyle(progress.theme.mutedInk)
                        Text(word.meaningZh).font(.title3.weight(.bold)).foregroundStyle(progress.theme.ink)
                    }
                    Spacer(minLength: 0)
                    PronunciationButton(hebrew: word.hebrew, iconOnly: true,
                                        title: "播放单词发音")
                        .disabled(isRecording)
                }
            }
            if let sentence = word.sentence {
                StudySectionTitle("例句")
                StudyCard {
                    WordExampleRow(example: StudyExample(hebrew: sentence.hebrew, transliteration: sentence.transliteration,
                                                         meaning: sentence.meaningZh, note: nil),
                                   showNiqqud: showNiqqud, cursive: showCursive)
                        .disabled(isRecording)
                }
            }
            let wordMastery = progress.effectiveWordMastery(word.id)
            StudyProficiencyCard(
                proficiency: progress.wordProficiency(word.id),
                schedule: progress.schedule[word.id],
                mastery: wordMastery
            ) {
                progress.setWord(word.id, mastery: wordMastery == .mastered ? .learning : .mastered)
            }
            StudyCard {
                DisclosureGroup("跟读录音对比") {
                    ShadowingPracticeCard(hebrew: word.hebrew, recordingState: $isRecording)
                        .padding(.top, 6)
                }
            }
            references
        }
        .studyDetail("单词详情")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("显示选项", systemImage: "textformat") {
                    Toggle("显示元音点", isOn: $showNiqqud)
                    Toggle("使用手写体", isOn: $showCursive)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                StudyMemoryCurveEntry(schedule: progress.schedule[word.id], item: .word)
            }
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

    private var references: some View {
    StudyCard {
        DisclosureGroup("用法与词形") {
            VStack(alignment: .leading, spacing: 10) {
                StudyNotice(title: [word.partOfSpeech, word.grammarTag].filter { !$0.isEmpty }.joined(separator: " · "),
                            symbol: "info.circle")
                ForEach(word.rootKeys, id: \.self) { root in
                    let familyCount = content.words(withRoot: root).count
                    NavigationLink {
                        RootFamilyView(root: root, content: content)
                    } label: {
                        StudyCard(padding: 10) {
                            StudyRow(title: "词根 · \(root)",
                                     symbol: "point.3.connected.trianglepath.dotted",
                                     value: "\(familyCount) 词")
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !word.note.isEmpty {
                    Text(word.note).font(.subheadline)
                }
                if !letters.isEmpty {
                    StudySectionTitle("拆成字母")
                    letterLinks
                }
                let forms = content.inflections[word.id] ?? [:]
                if !forms.isEmpty {
                    StudySectionTitle("词形变化")
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
            .padding(.top, 8)
        }
    }
    }

    private var letterLinks: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(Array(letters.enumerated()), id: \.offset) { _, entry in
                    let glyph = String(entry.character)
                    let finalForm = entry.letter.sofit == glyph
                    NavigationLink {
                        LetterStudyView(letter: entry.letter, content: content, showsFinalForm: finalForm)
                    } label: {
                        Group {
                            if showCursive {
                                StudyCursiveLetter(letter: entry.letter, finalForm: finalForm, size: 25)
                            } else {
                                HebrewText(text: glyph, size: 25)
                            }
                        }
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

struct StudyReadingView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let reading: StudyReading
    private var showNiqqudBinding: Binding<Bool>?
    private var showCursiveBinding: Binding<Bool>?
    @State private var niqqudMode: ReadingNiqqudMode
    @State private var showCursive: Bool
    @State private var showTranslation = false
    @State private var answer: Int?
    @State private var celebration: StudyAnswerCelebration?
    @State private var selectedGloss: GlossSelection?
    @State private var revealedPointed: Set<Int> = []
    @State private var activeSentence: Int?
    @State private var shadowingSentence: Int?
    @State private var isRecording = false

    init(reading: StudyReading, showNiqqud: Binding<Bool>? = nil, showCursive: Binding<Bool>? = nil) {
        self.reading = reading
        self.showNiqqudBinding = showNiqqud
        self.showCursiveBinding = showCursive
        _niqqudMode = State(initialValue: (showNiqqud?.wrappedValue ?? true) ? .full : .unpointed)
        _showCursive = State(initialValue: showCursive?.wrappedValue ?? false)
    }

    private struct GlossSelection: Equatable {
        let sentence: Int
        let term: Int
    }

    var body: some View {
        StudyPage {
            if let source = reading.source {
                Text(source).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
            }
            if niqqudMode == .assisted {
                StudyNotice(title: "过渡模式：仅重点生词保留元音点", symbol: "eye",
                            note: "打开句子操作，可查看带点原文。")
            }
            StudySectionTitle("原文与音频")
            Text("点按带下划线的词查看释义。").font(.footnote).foregroundStyle(progress.theme.mutedInk)
            StudyCard {
                ForEach(Array(reading.sentences.enumerated()), id: \.offset) { index, sentence in
                    if index > 0 { Divider() }
                    sentenceRow(sentence, at: index)
                }
            }
            StudySectionTitle("阅读理解")
            StudyCard { Text(reading.question.prompt).font(.headline) }
            ForEach(Array(reading.question.choices.enumerated()), id: \.offset) { index, choice in
                StudyAnswerButton(title: choice, submitted: answer == reading.question.correctIndex,
                                  selected: answer == index, correct: index == reading.question.correctIndex,
                                  optionLabel: studyOptionLabel(index)) {
                    answer = index
                    if index == reading.question.correctIndex {
                        progress.recordStudy()
                        celebration = StudyAnswerCelebration(combo: 0)
                    }
                }
            }
            if let answer {
                let correct = answer == reading.question.correctIndex
                StudyNotice(title: correct ? "回答正确" : "再读一下原文，然后重试",
                            symbol: correct ? "checkmark.circle" : "info.circle")
            }
        }
        .studyDetail(reading.title)
        .studyAnswerCelebration(celebration)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("阅读选项", systemImage: "slider.horizontal.3") {
                    Toggle("中希对照", isOn: $showTranslation)
                    Toggle("手写体", isOn: $showCursive)
                    Picker("元音点", selection: $niqqudMode) {
                        ForEach(ReadingNiqqudMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
            }
        }
        .onChange(of: niqqudMode) { _, mode in
            selectedGloss = nil
            revealedPointed.removeAll()
            showNiqqudBinding?.wrappedValue = (mode != .unpointed)
        }
        .onChange(of: showCursive) { _, enabled in
            showCursiveBinding?.wrappedValue = enabled
        }
    }

    private func sentenceRow(_ sentence: StudyReading.Sentence, at index: Int) -> some View {
        let text = reading.displayText(for: sentence, mode: niqqudMode)
        let glosses = reading.inlineGlosses(in: text)
        let selectedTerm = selectedGloss.flatMap { $0.sentence == index ? $0.term : nil }
        let showingPointed = niqqudMode != .full && revealedPointed.contains(index)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 4))
        return VStack(alignment: .leading, spacing: 8) {
            layout {
                Text(attributedSentence(text, glosses: glosses, selectedTerm: selectedTerm))
                    .font(showCursive ? .custom("GveretLevin-Regular", size: 24, relativeTo: .title2) : .title2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == "alef-gloss", let term = Int(url.lastPathComponent), glosses.indices.contains(term) else { return .discarded }
                        let selection = GlossSelection(sentence: index, term: term)
                        selectedGloss = selectedGloss == selection ? nil : selection
                        return .handled
                    })
                HStack(spacing: 0) {
                    if sentence.audio == nil {
                        PronunciationButton(hebrew: sentence.hebrew, iconOnly: true, title: "朗读第 \(index + 1) 句")
                            .disabled(isRecording)
                    }
                    Button {
                        activeSentence = activeSentence == index ? nil : index
                        shadowingSentence = nil
                    } label: {
                        Image(systemName: activeSentence == index ? "ellipsis.circle.fill" : "ellipsis.circle")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(progress.theme.accent)
                    .disabled(isRecording)
                    .accessibilityLabel("第 \(index + 1) 句操作")
                    .accessibilityValue(activeSentence == index ? "已展开" : "已收起")
                }
            }
            if let recording = sentence.audio {
                PronunciationButton(hebrew: sentence.hebrew, title: "播放\(recording.style.title)", bundledOnly: true)
                    .disabled(isRecording)
                    .accessibilityHint("第 \(index + 1) 句")
                if let performer = recording.performer {
                    Text(performer)
                        .font(.caption)
                        .foregroundStyle(progress.theme.mutedInk)
                }
            }
            if showingPointed {
                HebrewText(text: sentence.hebrew, size: 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(8)
                    .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 8))
            }
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
            if activeSentence == index {
                let controls = Group {
                    Button {
                        shadowingSentence = shadowingSentence == index ? nil : index
                    } label: {
                        Label("跟读", systemImage: "mic")
                    }
                    .buttonStyle(StudyButtonStyle(selected: shadowingSentence == index))
                    .disabled(isRecording)
                    if niqqudMode != .full {
                        Button {
                            if revealedPointed.contains(index) { revealedPointed.remove(index) }
                            else { revealedPointed.insert(index) }
                        } label: {
                            Label(showingPointed ? "隐藏带点" : "带点对照",
                                  systemImage: showingPointed ? "eye.slash" : "eye")
                        }
                        .buttonStyle(StudyButtonStyle(selected: showingPointed))
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { controls }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 6) { controls }
                }
                if shadowingSentence == index {
                    ShadowingPracticeCard(hebrew: sentence.hebrew, title: "跟读第 \(index + 1) 句", recordingState: $isRecording,
                                          referenceTitle: sentence.audio?.style.title)
                }
            }
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
    let kind: WordQuizKind

    init(content: StudyContent, words: [StudyWord], kind: WordQuizKind = .meaning) {
        self.content = content
        self.kind = kind
        _words = State(initialValue: words)
    }

    var body: some View {
        WordQuizView(content: content, words: words, kind: kind, reviewing: true)
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
    var mistakePractice = false
    var untilMastered = false

    private var usesQueue: Bool { reviewing || mistakePractice }
    private var remainingMasteryWords: [StudyWord] {
        words.filter { progress.effectiveWordMastery($0.id) != .mastered }
    }

    @State private var target: StudyWord?
    @State private var options: [StudyWord] = []
    @State private var spelling = ""
    @State private var result: Bool?
    @State private var selectedOption: String?
    @State private var correct = 0
    @State private var answered = 0
    @State private var answerRun = StudyAnswerRun()
    @State private var reviewIndex = 0
    @State private var queue: [StudyWord] = []
    @State private var requeuedIds: Set<String> = []
    @State private var requeuedThisTurn = false
    @State private var isRetryAnswer = false
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
                        WordSpellingInput(wordId: target.id, spelling: $spelling, submitted: result != nil, onSubmit: confirm)
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
                    ContentUnavailableView(
                        untilMastered ? "本阶单词已全部记住" : (reviewing ? "没有到期的单词" : "没有可用的单词"),
                        systemImage: untilMastered ? "checkmark.seal.fill" : (reviewing ? "calendar.badge.checkmark" : "character.book.closed"),
                        description: Text(
                            untilMastered
                                ? "本阶全部 \(words.count) 个单词均已掌握，可返回查看学习进度。"
                                : (reviewing ? "在词库标记掌握度后，这里会显示到期的单词。" : "可以返回练习中心选择其他题型。")
                        )
                    )
                }
            }
            .onChange(of: target?.id) { _, _ in scroll.scrollTo("word-question", anchor: .top) }
            .onChange(of: result) { _, value in
                if value != nil { scroll.scrollTo("word-result", anchor: .bottom) }
            }
        }
        .studyDetail(reviewing ? "到期复习" : (mistakePractice ? "\(kind.title)错题练习" : (untilMastered ? "本阶单词测验" : "\(kind.title)练习")))
        .studyAnswerCelebration(answerRun.celebration)
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
            queue = words
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
            if !usesQueue && result == nil && (!untilMastered || remainingMasteryWords.count > 1) {
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
        if usesQueue {
            Text("\(reviewIndex + 1) / \(queue.count)").font(.subheadline.weight(.semibold))
            ProgressView(value: Double(reviewIndex + 1), total: Double(max(1, queue.count)))
                .tint(progress.theme.accent)
                .frame(minWidth: 38, maxWidth: 160)
                .accessibilityLabel("复习进度")
        } else if untilMastered {
            let masteredCount = max(0, words.count - remainingMasteryWords.count)
            Text("已牢记 \(masteredCount) / \(words.count)").font(.subheadline.weight(.semibold))
            ProgressView(value: Double(masteredCount), total: Double(max(1, words.count)))
                .tint(progress.theme.success)
                .frame(minWidth: 38, maxWidth: 140)
                .accessibilityLabel("本阶掌握进度")
        }
        Label("得分 \(correct) / \(answered)", systemImage: "star")
            .font(.caption.weight(.semibold)).foregroundStyle(progress.theme.mutedInk)
        if !usesQueue && !untilMastered {
            Label("连击 \(answerRun.combo)", systemImage: "bolt.fill")
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
                              explanation: "\(target.transliteration) · \(target.partOfSpeech)",
                              combo: usesQueue && !isRetryAnswer ? answerRun.combo : 0,
                              spellingComparison: kind == .spelling && !correct ? target.spellingComparison(for: spelling) : nil)
            if kind == .spelling {
                PronunciationButton(hebrew: target.hebrew, title: "听正确发音")
            }
            if reviewing && !correct && requeuedThisTurn {
                StudyNotice(title: "已加入本轮末尾再练一次", symbol: "arrow.counterclockwise", reminder: true)
            }
            if untilMastered && correct && progress.effectiveWordMastery(target.id) == .mastered {
                StudyNotice(title: "已牢记，已移出本轮测试", symbol: "checkmark.seal.fill")
            }
            if let schedule = progress.schedule[target.id] {
                if reviewing && isRetryAnswer {
                    StudyNotice(title: "已记录本轮补练", symbol: "calendar.badge.checkmark",
                                note: "下次复习 · \(schedule.displayDate)")
                } else {
                    StudyProficiencyCard(
                        proficiency: progress.wordProficiency(target.id),
                        schedule: schedule,
                        mastery: progress.effectiveWordMastery(target.id)
                    )
                }
            }
        }
    }

    @ViewBuilder private var quizAction: some View {
        if showsSummary {
            primaryButton("完成", symbol: "checkmark") { dismiss() }
        } else if target == nil {
            primaryButton("返回", symbol: "chevron.backward") { dismiss() }
        } else if result != nil {
            let finishing = (usesQueue && reviewIndex + 1 >= queue.count)
                || (untilMastered && remainingMasteryWords.isEmpty)
            primaryButton(finishing ? (untilMastered ? "查看本阶结果" : "查看本组结果") : "下一题",
                          symbol: "arrow.right", learningAction: true) {
                if finishing { showsSummary = true }
                else {
                    if usesQueue { reviewIndex += 1 }
                    next(play: true)
                }
            }
        } else {
            let isRetry = target.map { requeuedIds.contains($0.id) } ?? false
            let buttonTitle = isRetry ? "提交补练" : "提交并记录复习"
            primaryButton(reviewing ? buttonTitle : "确认答案",
                          symbol: "checkmark", learningAction: true, action: confirm)
                .disabled(kind == .spelling ? spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : selectedOption == nil)
        }
    }

    private var summary: some View {
        let nextReview = queue.compactMap { progress.schedule[$0.id] }.min { $0.nextReviewAt < $1.nextReviewAt }
        let allMastered = untilMastered && remainingMasteryWords.isEmpty
        let title = reviewing ? "完成到期复习" : (mistakePractice ? "完成错题练习" : (allMastered ? "本阶单词已全部记住" : "完成练习"))
        let message: String? = if reviewing {
            nextReview.map { "下次复习 · \($0.displayDate)" }
        } else if allMastered {
            "本阶 \(words.count) 个高频词均已牢记。"
        } else if untilMastered {
            "已牢记 \(max(0, words.count - remainingMasteryWords.count)) / \(words.count) 词，可随时继续巩固。"
        } else {
            nil
        }
        return StudyQuizSummary(title: title, correct: correct, answered: answered, message: message)
    }

    private func primaryButton(_ title: String, symbol: String, learningAction: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(prominent: !learningAction, learningAction: learningAction))
    }

    private func confirm() {
        guard let target, result == nil else { return }
        let success: Bool
        if kind == .spelling {
            guard !spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            success = target.acceptsSpelling(spelling)
        } else {
            guard let selectedOption else { return }
            success = selectedOption == target.id
        }
        result = success
        answered += 1
        if success { correct += 1 }
        if reviewing {
            isRetryAnswer = requeuedIds.contains(target.id)
            progress.completeReview(target.id, correct: success, mistakeKind: kind == .spelling ? .spelling : .meaning,
                                    isRetry: isRetryAnswer)
            if !success && requeuedIds.insert(target.id).inserted {
                queue.append(target)
                requeuedThisTurn = true
            }
        } else {
            progress.recordWordPractice(target.id, correct: success)
        }
        answerRun.record(correct: success, in: progress, isRetry: isRetryAnswer)
        audio.playFeedback(success ? .correct : .wrong)
    }

    private func next(play: Bool) {
        answerRun.clearCelebration()
        let source = usesQueue ? queue : (untilMastered ? remainingMasteryWords : words)
        let pool = switch kind {
        case .spelling: usesQueue ? source : source.filter(\.canPracticeSpelling)
        case .listening: source.filter { content.audio[$0.hebrew] != nil }
        case .meaning: source
        }
        if usesQueue {
            target = pool.indices.contains(reviewIndex) ? pool[reviewIndex] : nil
        } else {
            let others = pool.filter { $0.id != target?.id }
            let activePool = others.isEmpty ? pool : others
            target = progress.weightedRandom(from: activePool, weight: { progress.quizWeight(forWord: $0.id) })
        }
        result = nil
        selectedOption = nil
        spelling = ""
        requeuedThisTurn = false
        isRetryAnswer = false
        guard let target else { return }
        if kind != .spelling {
            options = ([target] + content.distractors(for: target, listening: kind == .listening)).shuffled()
        }
        if kind == .listening, play {
            audio.speak(target.hebrew, rate: progress.speechRate, bundledOnly: true)
        }
    }
}

struct WordSpellingInput: View {
    @Environment(StudyProgress.self) private var progress
    let wordId: String
    @Binding var spelling: String
    let submitted: Bool
    let onSubmit: () -> Void
    @FocusState private var inputFocused: Bool

    var body: some View {
        StudyCard {
            if !submitted {
                HStack(spacing: 8) {
                    TextField("输入希伯来语单词", text: $spelling)
                        .font(.title2)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($inputFocused)
                        .submitLabel(.done)
                        .onSubmit(onSubmit)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 48)
                        .environment(\.layoutDirection, .rightToLeft)
                    if !spelling.isEmpty {
                        Button {
                            spelling = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(progress.theme.mutedInk)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空输入")
                    }
                }
            } else if spelling.isEmpty {
                Text("未输入内容")
                    .foregroundStyle(progress.theme.mutedInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
            } else {
                HebrewText(text: spelling, size: 44, style: .largeTitle)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .textSelection(.enabled)
            }
        }
        .onAppear {
            if !submitted { inputFocused = true }
        }
        .onChange(of: wordId) { _, _ in
            inputFocused = !submitted
        }
        .onChange(of: submitted) { _, done in
            inputFocused = !done
        }
    }
}

private struct TopicPackDetailView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let pack: StudyWordPack
    let content: StudyContent
    @Binding var showNiqqud: Bool
    @Binding var showCursive: Bool

    @State private var searchQuery = ""
    @State private var sortByFrequency = true
    @State private var unmasteredOnly = false
    @State private var displayLimit = 40

    private var packWords: [StudyWord] {
        content.words(inPack: pack.id)
    }

    private var filteredWords: [StudyWord] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let unpointedQuery = withoutHebrewMarks(query)
        let base = packWords.filter { word in
            let matchesMastery = !unmasteredOnly || progress.effectiveWordMastery(word.id) != .mastered
            let searchable = [word.hebrew, word.hebrewUnpointed, word.transliteration, word.meaningZh, word.root ?? "", word.ipa]
                + (word.alternateSpellings ?? [])
            let matchesQuery = query.isEmpty
                || searchable.contains { $0.localizedStandardContains(query) }
                || (!unpointedQuery.isEmpty && word.hebrewUnpointed.localizedStandardContains(unpointedQuery))
            return matchesMastery && matchesQuery
        }
        if sortByFrequency {
            return base.sorted {
                let lhs = ($0.frequencyRank ?? Int.max, $0.frequency.rank, $0.hebrewUnpointed)
                let rhs = ($1.frequencyRank ?? Int.max, $1.frequency.rank, $1.hebrewUnpointed)
                return lhs < rhs
            }
        }
        return base
    }

    var body: some View {
        let allWords = packWords
        let words = filteredWords
        let masteredCount = allWords.reduce(into: 0) { count, word in
            if progress.effectiveWordMastery(word.id) == .mastered { count += 1 }
        }
        let ratio = allWords.isEmpty ? 0.0 : Double(masteredCount) / Double(allWords.count)
        let favorites = Set(progress.favorites)
        let visibleWords = Array(words.prefix(displayLimit))
        let pinned = progress.isWordPackPinned(pack.id)
        let isDailyTarget = progress.dailyVocabularyPackId == pack.id

        StudyPage(keyboardDismissMode: .immediately) {
            StudyCard(highlighted: true) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: pack.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(progress.theme.accent)
                        .frame(width: 42, height: 42)
                        .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pack.title)
                            .font(.headline)
                            .foregroundStyle(progress.theme.ink)
                        Text(pack.subtitle)
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                    Spacer(minLength: 0)
                    Text("\(masteredCount)/\(allWords.count)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(progress.theme.accent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(progress.theme.insetSurface)
                        Capsule()
                            .fill(progress.theme.accent)
                            .frame(width: max(0, geo.size.width * ratio))
                    }
                }
                .frame(height: 6)
                HStack(spacing: 8) {
                    Button {
                        progress.togglePinnedWordPack(pack.id)
                    } label: {
                        Label(pinned ? "已固定到单词页" : "固定到单词页", systemImage: pinned ? "pin.fill" : "pin")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(StudyButtonStyle(selected: pinned))
                    Button {
                        let nextPackId: String? = isDailyTarget ? nil : pack.id
                        let nextWords = content.dailyVocabularyWords(in: progress, packId: nextPackId)
                        progress.setDailyVocabularyPack(nextPackId, words: nextWords)
                    } label: {
                        Label(isDailyTarget ? "今日记词学习中" : "设为今日记词",
                              systemImage: isDailyTarget ? "calendar.badge.checkmark" : "calendar.badge.plus")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(StudyButtonStyle(selected: isDailyTarget))
                }
                if !allWords.isEmpty {
                    HStack(spacing: 8) {
                        NavigationLink {
                            WordQuizView(content: content, words: allWords, kind: .meaning)
                        } label: {
                            Label("释义测验", systemImage: "text.book.closed")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 38)
                        }
                        .buttonStyle(StudyButtonStyle(prominent: true))
                        NavigationLink {
                            WordQuizView(content: content, words: allWords, kind: .listening)
                        } label: {
                            Label("听力", systemImage: "ear")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 38)
                        }
                        .buttonStyle(StudyButtonStyle())
                        NavigationLink {
                            WordQuizView(content: content, words: allWords, kind: .spelling)
                        } label: {
                            Label("拼写", systemImage: "pencil")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 38)
                        }
                        .buttonStyle(StudyButtonStyle())
                    }
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(progress.theme.mutedInk).accessibilityHidden(true)
                TextField("在「\(pack.title)」中搜索", text: $searchQuery)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(progress.theme.mutedInk)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(progress.theme.cardSurface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(progress.theme.outline.opacity(0.8), lineWidth: 1)
                    .allowsHitTesting(false)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    togglePill(sortByFrequency ? "高频优先" : "默认顺序", symbol: "arrow.up.arrow.down", active: sortByFrequency) {
                        sortByFrequency.toggle()
                    }
                    togglePill("仅看未掌握", symbol: "circle.dashed", active: unmasteredOnly) {
                        unmasteredOnly.toggle()
                    }
                    togglePill(showNiqqud ? "● 元音点" : "○ 元音点", active: showNiqqud) {
                        showNiqqud.toggle()
                    }
                    togglePill("手写体", symbol: "pencil.tip", active: showCursive) {
                        showCursive.toggle()
                    }
                }
            }
            .scrollIndicators(.hidden)

            Text("共 \(words.count) 词")
                .font(.caption.weight(.medium))
                .foregroundStyle(progress.theme.mutedInk)

            if words.isEmpty {
                ContentUnavailableView("没有匹配的单词", systemImage: "magnifyingglass")
            } else {
                let lastVisibleId = visibleWords.last?.id
                LazyVStack(spacing: 7) {
                    ForEach(visibleWords) { word in
                        packWordRow(word, favorite: favorites.contains(word.id),
                                    mastery: progress.effectiveWordMastery(word.id))
                            .onAppear {
                                if word.id == lastVisibleId, displayLimit < words.count {
                                    DispatchQueue.main.async {
                                        displayLimit = min(words.count, displayLimit + 40)
                                    }
                                }
                            }
                    }
                }
                if visibleWords.count < words.count {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在加载更多… (\(visibleWords.count)/\(words.count))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(progress.theme.mutedInk)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
        }
        .studyDetail(pack.title)
        .onChange(of: searchQuery) { _, _ in displayLimit = 40 }
        .onChange(of: unmasteredOnly) { _, _ in displayLimit = 40 }
    }

    private func togglePill(_ label: String, symbol: String? = nil, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Label(label, systemImage: symbol)
                } else {
                    Text(label)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(active ? Color.white : progress.theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(active ? progress.theme.primaryButton : progress.theme.insetSurface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func packWordRow(_ word: StudyWord, favorite: Bool, mastery: Mastery) -> some View {
        let proficiency = progress.wordProficiency(word.id)
        let tint = proficiency > 0 ? StudyProficiencyStyle.color(for: proficiency) : progress.theme.mutedInk
        let surface = proficiency > 0 ? tint.opacity(0.14) : progress.theme.insetSurface
        return StudyCard(padding: 7) {
            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Image(systemName: mastery.symbol).font(.subheadline)
                    Text(mastery.title).font(.caption2.weight(.semibold))
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 6)
                .frame(minWidth: 46, minHeight: 46)
                .background(surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                NavigationLink {
                    WordDetailView(word: word, content: content, showNiqqud: showNiqqud, showCursive: showCursive)
                } label: {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                if sortByFrequency, let rank = word.frequencyRank {
                                    Text("#\(rank)")
                                        .font(.caption2.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(progress.theme.accent)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(progress.theme.highlightedSurface, in: Capsule())
                                }
                                Text(word.transliteration)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(progress.theme.ink)
                                    .lineLimit(1)
                            }
                            Text(word.meaningZh)
                                .font(.caption)
                                .foregroundStyle(progress.theme.mutedInk)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        HebrewText(text: showNiqqud ? word.hebrew : word.hebrewUnpointed,
                                   cursive: showCursive, size: 28)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                PronunciationButton(hebrew: word.hebrew, iconOnly: true, title: "播放\(word.meaningZh)的发音")
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

private struct StudyPackManagerView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @Binding var showNiqqud: Bool
    @Binding var showCursive: Bool

    var body: some View {
        let pinnedCount = progress.pinnedWordPackIds.count
        let activeDailyPack = progress.dailyVocabularyPackId.flatMap { content.wordPack(id: $0) }
        StudyPage {
            StudyCard(padding: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "pin.fill")
                        .font(.subheadline)
                        .foregroundStyle(progress.theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已固定 \(pinnedCount) 个学习包到内容库顶部")
                            .font(.subheadline.weight(.semibold))
                        Text("今日记词：\(activeDailyPack?.title ?? "未选择") · 点按图钉固定，点按卡片进入学习")
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                    Spacer(minLength: 0)
                }
            }
            ForEach(StudyWordPackGroup.allCases) { group in
                let packs = content.allWordPacks.filter { $0.group == group }
                StudySectionTitle(group.title)
                packGrid(packs, highlighted: group == .content || group == .featured)
            }
        }
        .studyDetail("包管理")
    }

    private func packGrid(_ packs: [StudyWordPack], highlighted: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 280 : 156), spacing: 8)], spacing: 8) {
            ForEach(packs) { pack in
                let pinned = progress.isWordPackPinned(pack.id)
                let isDailyTarget = pack.kind == .words && progress.dailyVocabularyPackId == pack.id
                StudyCard(highlighted: highlighted || isDailyTarget, padding: 12, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: pack.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(progress.theme.accent)
                            .frame(width: 32, height: 32)
                            .background(progress.theme.highlightedSurface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Spacer(minLength: 0)
                        Button {
                            progress.togglePinnedWordPack(pack.id)
                        } label: {
                            Image(systemName: pinned ? "pin.fill" : "pin")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(pinned ? Color.white : progress.theme.mutedInk)
                                .frame(width: 30, height: 30)
                                .background(pinned ? progress.theme.primaryButton : progress.theme.insetSurface, in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(pinned ? "取消固定\(pack.title)" : "固定\(pack.title)到内容库")
                    }
                    NavigationLink {
                        destinationView(for: pack)
                    } label: {
                        packCardContent(pack, isDailyTarget: isDailyTarget)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for pack: StudyWordPack) -> some View {
        switch pack.kind {
        case .phrases:
            PhrasePackDetailView(pack: pack, content: content, showNiqqud: $showNiqqud, showCursive: $showCursive)
        case .readings:
            ReadingPackDetailView(pack: pack, content: content, showNiqqud: $showNiqqud, showCursive: $showCursive)
        case .words:
            TopicPackDetailView(pack: pack, content: content, showNiqqud: $showNiqqud, showCursive: $showCursive)
        }
    }

    @ViewBuilder
    private func packCardContent(_ pack: StudyWordPack, isDailyTarget: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(pack.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(progress.theme.ink)
                        .lineLimit(1)
                    if isDailyTarget {
                        Text("今日")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(progress.theme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(progress.theme.highlightedSurface, in: Capsule())
                    }
                }
                Text(pack.subtitle)
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
                    .lineLimit(2)
            }
            switch pack.kind {
            case .phrases:
                let favorites: [String] = progress.read("alef.native.phraseFavorites.v1", default: [])
                HStack {
                    Text("\(content.phrases.count) 句")
                    Spacer(minLength: 0)
                    Text("收藏 \(favorites.count)")
                }
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(progress.theme.mutedInk)
            case .readings:
                HStack {
                    Text("\(content.readings.count) 篇短文")
                    Spacer(minLength: 0)
                    Text("含朗读与理解")
                }
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(progress.theme.mutedInk)
            case .words:
                let packWords = content.words(inPack: pack.id)
                let mastered = packWords.reduce(into: 0) { count, word in
                    if progress.effectiveWordMastery(word.id) == .mastered { count += 1 }
                }
                let ratio = packWords.isEmpty ? 0.0 : Double(mastered) / Double(packWords.count)
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(progress.theme.insetSurface)
                            Capsule()
                                .fill(progress.theme.accent)
                                .frame(width: max(0, geo.size.width * ratio))
                        }
                    }
                    .frame(height: 5)
                    HStack {
                        Text("\(packWords.count) 词")
                        Spacer(minLength: 0)
                        Text("已掌握 \(mastered)")
                    }
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(progress.theme.mutedInk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct PhrasePackDetailView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let pack: StudyWordPack
    let content: StudyContent
    @Binding var showNiqqud: Bool
    @Binding var showCursive: Bool
    @State private var phraseCategory = "all"
    @State private var hidePhraseTranslation = false
    @State private var shadowingPhraseId: String?

    var body: some View {
        let categories = content.phraseCategories.keys.sorted()
        let favorites: [String] = progress.read("alef.native.phraseFavorites.v1", default: [])
        let pinned = progress.isWordPackPinned(pack.id)
        StudyPage {
            StudyCard(highlighted: true, padding: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.title).font(.headline)
                        Text("\(content.phrases.count) 句情景表达 · \(pack.subtitle)")
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                    Spacer(minLength: 0)
                    Button {
                        progress.togglePinnedWordPack(pack.id)
                    } label: {
                        Label(pinned ? "已固定" : "固定", systemImage: pinned ? "pin.fill" : "pin")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(StudyButtonStyle(selected: pinned))
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    scopeButton("全部场景", key: "all")
                    scopeButton("收藏", key: "favorites")
                    ForEach(categories, id: \.self) { key in
                        scopeButton(content.phraseCategories[key]?.label ?? key, key: key)
                    }
                }
            }
            .scrollIndicators(.hidden)
            Menu {
                Toggle("隐藏中文，自测释义", isOn: $hidePhraseTranslation)
                Toggle("显示元音点", isOn: $showNiqqud)
                Toggle("手写体", isOn: $showCursive)
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
                    let saved = favorites.contains(phrase.id)
                    let isShadowing = shadowingPhraseId == phrase.id
                    StudyCard {
                        VStack(alignment: .trailing, spacing: 4) {
                            HebrewText(text: showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed,
                                       cursive: showCursive, size: 34, style: .title)
                            Text(phrase.transliteration).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                            if !hidePhraseTranslation {
                                Text(phrase.meaningZh).font(.headline)
                            }
                        }
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        if !hidePhraseTranslation, let note = phrase.note {
                            Text(note).font(.footnote).foregroundStyle(progress.theme.mutedInk)
                        }
                        HStack(spacing: 4) {
                            PronunciationButton(hebrew: phrase.hebrew, iconOnly: true, title: "播放短语原音")
                            Menu {
                                Button("慢速播放（0.68×）", systemImage: "tortoise") {
                                    audio.speak(phrase.hebrew, rate: 0.68)
                                }
                                Button(isShadowing ? "收起跟读" : "跟读", systemImage: "mic") {
                                    shadowingPhraseId = isShadowing ? nil : phrase.id
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("短语播放与跟读选项")
                            Spacer(minLength: 0)
                            Button {
                                let updated = saved ? favorites.filter { $0 != phrase.id } : favorites + [phrase.id]
                                progress.write(updated, for: "alef.native.phraseFavorites.v1")
                            } label: {
                                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(saved ? "取消收藏短语" : "收藏短语")
                        }
                        .foregroundStyle(progress.theme.accent)
                        if isShadowing {
                            ShadowingPracticeCard(hebrew: phrase.hebrew, title: "跟读短句")
                        }
                    }
                }
            }
        }
        .studyDetail(pack.title)
    }

    private func scopeButton(_ title: String, key: String) -> some View {
        Button(title) { phraseCategory = key }
            .buttonStyle(StudyButtonStyle(selected: phraseCategory == key))
            .accessibilityAddTraits(phraseCategory == key ? .isSelected : [])
    }
}

private struct ReadingPackDetailView: View {
    @Environment(StudyProgress.self) private var progress
    let pack: StudyWordPack
    let content: StudyContent
    @Binding var showNiqqud: Bool
    @Binding var showCursive: Bool

    var body: some View {
        let pinned = progress.isWordPackPinned(pack.id)
        StudyPage {
            StudyCard(highlighted: true, padding: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.title).font(.headline)
                        Text("\(content.readings.count) 篇短文 · \(pack.subtitle)")
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                    Spacer(minLength: 0)
                    Button {
                        progress.togglePinnedWordPack(pack.id)
                    } label: {
                        Label(pinned ? "已固定" : "固定", systemImage: pinned ? "pin.fill" : "pin")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(StudyButtonStyle(selected: pinned))
                }
            }
            StudyReadingLibrary(content: content, showNiqqud: $showNiqqud, showCursive: $showCursive)
        }
        .studyDetail(pack.title)
    }
}
