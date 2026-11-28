import Foundation

struct StudyContent: Decodable {
    let letters: [StudyLetter]
    var words: [StudyWord] { isFreeEdition ? beginnerWords : allWords }
    private(set) var isFreeEdition = false
    private let allWords: [StudyWord]
    private let beginnerWords: [StudyWord]
    let wordCategories: [String: StudyCategory]
    let phrases: [StudyPhrase]
    let phraseCategories: [String: StudyCategory]
    let readings: [StudyReading]
    let readingCategories: [String: String]
    let niqqud: [StudyNiqqud]
    let confusables: [StudyComparison]
    let inflections: [String: [String: StudyInflection]]
    let audio: [String: String]
    let consonants: [StudyConsonant]
    let vowels: [StudyVowel]
    let defaultDisplay: [String: Bool]
    let displayPresets: [StudyDisplayPreset]
    let grammarAffixes: [StudyGrammarAffix]
    let grammarBinyanim: [StudyGrammarBinyan]
    let minimalPairs: [StudyMinimalPair]
    let learningPath: [StudyPathStage]
    private let ambiguousSpellings: Set<String>
    private let wordsByRoot: [String: [StudyWord]]
    private let beginnerWordsByRoot: [String: [StudyWord]]

    enum CodingKeys: CodingKey {
        case letters, words, wordCategories, phrases, phraseCategories, readings, readingCategories
        case niqqud, confusables, inflections, audio, consonants, vowels, defaultDisplay, displayPresets
        case grammarAffixes, grammarBinyanim, minimalPairs, learningPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        letters = try container.decode([StudyLetter].self, forKey: .letters)
        let allWords = try container.decode([StudyWord].self, forKey: .words)
        let path = try container.decode([StudyPathStage].self, forKey: .learningPath)
        let pathWordIDs = Set(path.flatMap(\.wordIds))
        let beginnerWords = allWords.filter { $0.difficulty == .beginner || pathWordIDs.contains($0.id) }
        self.allWords = allWords
        self.beginnerWords = beginnerWords
        learningPath = path
        wordsByRoot = Self.indexWordsByRoot(allWords)
        beginnerWordsByRoot = Self.indexWordsByRoot(beginnerWords)
        let entriesBySpelling = Dictionary(grouping: allWords, by: \.hebrewUnpointed)
        ambiguousSpellings = Set(entriesBySpelling.compactMap { spelling, entries in
            Set(entries.map(\.meaningZh)).count > 1 ? spelling : nil
        })
        wordCategories = try container.decode([String: StudyCategory].self, forKey: .wordCategories)
        phrases = try container.decode([StudyPhrase].self, forKey: .phrases)
        phraseCategories = try container.decode([String: StudyCategory].self, forKey: .phraseCategories)
        readings = try container.decode([StudyReading].self, forKey: .readings)
        readingCategories = try container.decode([String: String].self, forKey: .readingCategories)
        niqqud = try container.decode([StudyNiqqud].self, forKey: .niqqud)
        confusables = try container.decode([StudyComparison].self, forKey: .confusables)
        inflections = try container.decode([String: StudyInflectionGroup].self, forKey: .inflections).mapValues(\.forms)
        audio = try container.decode([String: String].self, forKey: .audio)
        consonants = try container.decode([StudyConsonant].self, forKey: .consonants)
        vowels = try container.decode([StudyVowel].self, forKey: .vowels)
        defaultDisplay = try container.decode([String: Bool].self, forKey: .defaultDisplay)
        displayPresets = try container.decode([StudyDisplayPreset].self, forKey: .displayPresets)
        grammarAffixes = try container.decode([StudyGrammarAffix].self, forKey: .grammarAffixes)
        grammarBinyanim = try container.decode([StudyGrammarBinyan].self, forKey: .grammarBinyanim)
        minimalPairs = try container.decode([StudyMinimalPair].self, forKey: .minimalPairs)
    }

    func edition(hasFullAccess: Bool) -> Self {
        var result = self
        result.isFreeEdition = !hasFullAccess
        return result
    }

    func isFreeReading(_ id: String) -> Bool {
        learningPath.contains { $0.readingId == id }
    }

    func isFreePack(_ pack: StudyWordPack) -> Bool {
        pack.kind != .words || pack.id == StudyWordPack.beginnerID
    }

    func savedDailyWord(_ id: String) -> StudyWord? {
        allWords.first { $0.id == id }
    }

    func dailyVocabularyPack(in progress: StudyProgress) -> StudyWordPack? {
        guard let id = progress.dailyVocabularyPackId, let pack = wordPack(id: id) else { return nil }
        return isFreeEdition && !isFreePack(pack) ? wordPack(id: StudyWordPack.beginnerID) : pack
    }

    var introductoryDisplay: [String: Bool] {
        let visible: Set<String> = ["showBlock", "showSofit", "showEnglishName", "showMastery"]
        return Dictionary(uniqueKeysWithValues: defaultDisplay.keys.map { ($0, visible.contains($0)) })
    }

    func letterDisplay(in progress: StudyProgress) -> [String: Bool] {
        displayWithGlyph(introductoryDisplay.merging(progress.read("alef.displayConfig.v1", default: [:])) { _, saved in saved })
    }

    func displayWithGlyph(_ options: [String: Bool]) -> [String: Bool] {
        guard options["showBlock"] != true && options["showCursive"] != true else { return options }
        var visible = options
        visible["showBlock"] = true
        return visible
    }

    func dueWords(in progress: StudyProgress, at date: Date = .now) -> [StudyWord] {
        let schedule = progress.schedule
        return words.filter { schedule[$0.id]?.isDue(at: date) == true }.sorted {
            (schedule[$0.id]?.nextReviewAt ?? 0) < (schedule[$1.id]?.nextReviewAt ?? 0)
        }
    }

    func dueLetters(in progress: StudyProgress, at date: Date = .now) -> [StudyLetter] {
        let schedule = progress.letterSchedule
        return letters.filter { schedule[$0.id]?.isDue(at: date) == true }.sorted {
            (schedule[$0.id]?.nextReviewAt ?? 0) < (schedule[$1.id]?.nextReviewAt ?? 0)
        }
    }

    func recommendedStage(in progress: StudyProgress, at date: Date = .now) -> StudyPathStage? {
        learningPath.first { stage in
            stage.letterIds.contains { progress.effectiveLetterMastery($0, at: date) != .mastered }
                || stage.wordIds.contains { progress.effectiveWordMastery($0, at: date) != .mastered }
        }
    }

    func dailyVocabularyWords(in progress: StudyProgress, packId: String?, at date: Date = .now) -> [StudyWord] {
        guard let packId, let pack = wordPack(id: packId), pack.kind == .words,
              !isFreeEdition || isFreePack(pack) else { return [] }
        let stageIDs = Set(recommendedStage(in: progress, at: date)?.wordIds ?? [])
        // Keep saved IDs available for daily plans created before vocabulary grouping.
        let pool = words(inPack: pack.id, includingEquivalentEntries: true)
        let ranked = pool.map { word in
            let priority = (word.difficulty == .beginner ? 0 : 1, word.frequency.rank,
                            word.frequencyRank ?? Int.max, word.difficulty.rank,
                            stageIDs.contains(word.id) ? 0 : 1)
            return (word, priority)
        }
        return ranked.sorted { $0.1 < $1.1 }.map { $0.0 }
    }

    func dailyVocabularyWords(in progress: StudyProgress, at date: Date = .now) -> [StudyWord] {
        dailyVocabularyWords(in: progress, packId: dailyVocabularyPack(in: progress)?.id, at: date)
    }

    func introductoryDailyVocabularyWords(in progress: StudyProgress, at date: Date = .now) -> [StudyWord] {
        guard !progress.hasDailyVocabularyPackPreference else { return [] }
        return dailyVocabularyWords(in: progress, packId: StudyWordPack.beginnerID, at: date)
    }

    func startIntroductoryDailyVocabulary(in progress: StudyProgress, at date: Date = .now) -> DailyVocabularyGroup? {
        let words = introductoryDailyVocabularyWords(in: progress, at: date)
        guard !words.isEmpty, progress.dailyVocabularyPlan(words: words, date: date).nextGroup != nil else { return nil }
        progress.setDailyVocabularyPack(StudyWordPack.beginnerID, words: words, date: date)
        return progress.dailyVocabulary.nextGroup
    }

    func wordPacks(in progress: StudyProgress) -> [StudyWordPack] {
        let savedIDs = Set(progress.pinnedWordPackIds + [progress.dailyVocabularyPackId].compactMap { $0 })
        return StudyWordPack.catalog + StudyWordPack.legacyCatalog.filter { savedIDs.contains($0.id) }
    }

    func wordPack(id: String) -> StudyWordPack? {
        StudyWordPack.catalog.first { $0.id == id } ?? StudyWordPack.legacyCatalog.first { $0.id == id }
    }

    static func uniqueVocabulary(_ entries: [StudyWord]) -> [StudyWord] {
        var seen: Set<String> = []
        return entries.filter { seen.insert($0.equivalentTo ?? $0.id).inserted }
    }

    func words(inPack id: String, includingEquivalentEntries: Bool = false) -> [StudyWord] {
        let entries = matchingWords(inPack: id)
        return includingEquivalentEntries ? entries : Self.uniqueVocabulary(entries)
    }

    private func matchingWords(inPack id: String) -> [StudyWord] {
        switch id {
        case StudyWordPack.beginnerID:
            return isFreeEdition ? beginnerWords : words.filter { $0.difficulty == .beginner }
        case "pack_top1000":
            return words.filter { ($0.frequencyRank ?? Int.max) <= 1000 }
        case "pack_top1001_2000":
            return words.filter {
                guard let rank = $0.frequencyRank else { return false }
                return rank > 1000 && rank <= 2000
            }
        case "pack_top2001_plus":
            return words.filter { ($0.frequencyRank ?? Int.max) > 2000 }
        case "pack_top2000":
            return words.filter { ($0.frequencyRank ?? Int.max) <= 2000 }
        case "pack_common":
            return words.filter { $0.frequency == .common }
        case "pack_phrases", "pack_readings":
            return []
        default:
            if id.hasPrefix("cat_") {
                let category = String(id.dropFirst(4))
                return words.filter { $0.category == category }
            }
            return words.filter { $0.category == id }
        }
    }

    func reminderReviews(in progress: StudyProgress) -> StudyReminderReviews {
        let wordSchedule = progress.schedule
        let letterSchedule = progress.letterSchedule
        return StudyReminderReviews(
            wordDates: words.compactMap { wordSchedule[$0.id]?.reviewDate },
            letterDates: letters.compactMap { letterSchedule[$0.id]?.reviewDate }
        )
    }

    func meaningPrompt(for word: StudyWord, showNiqqud: Bool) -> String {
        showNiqqud || ambiguousSpellings.contains(word.hebrewUnpointed) ? word.hebrew : word.hebrewUnpointed
    }

    func distractors(for word: StudyWord, listening: Bool) -> [StudyWord] {
        var meanings: Set<String> = [word.meaningZh]
        let candidates = words.shuffled().filter { candidate in
            (!listening || candidate.ipa != word.ipa)
                && meanings.insert(candidate.meaningZh).inserted
        }
        return Array(candidates.prefix(3))
    }

    func dailyVocabularyOptions(for word: StudyWord, stage: DailyVocabularyChoiceStage, groupWordIDs: [String],
                                selectedWordID: String? = nil) -> [StudyWord] {
        let spellsWord = stage == .spokenWord
        let groupIDs = Set(groupWordIDs)
        let shuffled = words.shuffled()
        let selected = selectedWordID.flatMap(savedDailyWord)
        let groupWords = isFreeEdition ? allWords.filter { groupIDs.contains($0.id) }.shuffled()
                                      : shuffled.filter { groupIDs.contains($0.id) }
        let candidates = [selected].compactMap { $0 } + groupWords + shuffled.filter { !groupIDs.contains($0.id) }
        var labels: Set<String> = [spellsWord ? word.hebrewUnpointed : word.meaningZh]
        var options = [word]
        for candidate in candidates {
            guard candidate.hebrew != word.hebrew,
                  stage == .writtenMeaning || candidate.ipa != word.ipa,
                  !spellsWord || !word.acceptsSpelling(candidate.hebrewUnpointed) else { continue }
            let label = spellsWord ? candidate.hebrewUnpointed : candidate.meaningZh
            guard labels.insert(label).inserted else { continue }
            options.append(candidate)
            if options.count == 4 { break }
        }
        return options.shuffled()
    }

    func words(withRoot root: String) -> [StudyWord] {
        guard let key = StudyRoot.key(for: root) else { return [] }
        return activeWordsByRoot[key] ?? []
    }

    func rootFamilies() -> [(root: String, words: [StudyWord])] {
        activeWordsByRoot
            .map { (root: $0.key, words: $0.value) }
            .sorted { lhs, rhs in
                if lhs.words.count != rhs.words.count { return lhs.words.count > rhs.words.count }
                return lhs.root < rhs.root
            }
    }

    private var activeWordsByRoot: [String: [StudyWord]] { isFreeEdition ? beginnerWordsByRoot : wordsByRoot }

    private static func indexWordsByRoot(_ words: [StudyWord]) -> [String: [StudyWord]] {
        uniqueVocabulary(words).reduce(into: [:]) { index, word in
            for root in word.rootKeys {
                index[root, default: []].append(word)
            }
        }
    }

    static func load() throws -> Self {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json", subdirectory: "StudyAssets") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

struct StudyDisplayPreset: Decodable, Identifiable {
    let id: String
    let label: String
    let config: [String: Bool]
}

struct StudyCategory: Decodable {
    let label: String
}

enum StudyWordPackKind: String, Hashable {
    case words, phrases, readings
}

enum StudyWordPackGroup: String, CaseIterable, Identifiable {
    case content, frequency, featured, core

    var id: String { rawValue }
    var title: String {
        switch self {
        case .content: "综合内容包"
        case .frequency: "基础与高频词包"
        case .featured: "进阶专题包"
        case .core: "基础主题包"
        }
    }
}

struct StudyWordPack: Identifiable, Hashable {
    static let beginnerID = "pack_beginner"

    let id: String
    let title: String
    let shortTitle: String
    let subtitle: String
    let symbol: String
    let group: StudyWordPackGroup
    var kind: StudyWordPackKind = .words

    static let defaultPinnedIDs = ["pack_top1000", "pack_top1001_2000", "pack_phrases", "pack_readings"]

    static let legacyCatalog: [StudyWordPack] = [
        StudyWordPack(id: "pack_top2000", title: "常用 Top 2000", shortTitle: "Top 2000", subtitle: "旧版词包 · he_50k 前 2000 名", symbol: "chart.bar.fill", group: .frequency),
        StudyWordPack(id: "pack_common", title: "高频常用词", shortTitle: "常用词", subtitle: "旧版词包 · 高频常用词汇", symbol: "star.fill", group: .frequency),
    ]

    static let catalog: [StudyWordPack] = [
        // 综合内容包
        StudyWordPack(id: "pack_phrases", title: "情景短语", shortTitle: "情景短语", subtitle: "日常交流、出行点餐与跟读练习", symbol: "text.bubble", group: .content, kind: .phrases),
        StudyWordPack(id: "pack_readings", title: "分级阅读", shortTitle: "阅读", subtitle: "经典短文、过渡元音点与阅读理解", symbol: "text.book.closed", group: .content, kind: .readings),
        // 基础与高频词包（词频段互斥）
        StudyWordPack(id: beginnerID, title: "基础入门", shortTitle: "基础入门", subtitle: "拼读简单的短词，零基础首选", symbol: "sparkles", group: .frequency),
        StudyWordPack(id: "pack_top1000", title: "核心词 1–1000", shortTitle: "核心 1000", subtitle: "he_50k 排名 #1–#1000 最高频词", symbol: "flame", group: .frequency),
        StudyWordPack(id: "pack_top1001_2000", title: "进阶词 1001–2000", shortTitle: "进阶 2000", subtitle: "he_50k 排名 #1001–#2000（无重叠）", symbol: "chart.bar.fill", group: .frequency),
        StudyWordPack(id: "pack_top2001_plus", title: "扩展词 2001+", shortTitle: "扩展 2001+", subtitle: "he_50k 2000 名以后的进阶扩展词", symbol: "star.fill", group: .frequency),
        // 进阶专题包
        StudyWordPack(id: "cat_news", title: "新闻与社会", shortTitle: "新闻社会", subtitle: "政治、媒体、法律与公共事务", symbol: "newspaper", group: .featured),
        StudyWordPack(id: "cat_tech", title: "科技与互联网", shortTitle: "科技网络", subtitle: "软件、网络、设备与现代办公", symbol: "cpu", group: .featured),
        StudyWordPack(id: "cat_colloquial", title: "影视与地道口语", shortTitle: "地道口语", subtitle: "高频口语副词、感叹词与情感表达", symbol: "bubble.left.and.text.bubble.right", group: .featured),
        StudyWordPack(id: "cat_health", title: "医疗与健康", shortTitle: "医疗健康", subtitle: "症状、就医、心理与身心健康", symbol: "heart.text.square", group: .featured),
        StudyWordPack(id: "cat_business", title: "商业与金融", shortTitle: "商业金融", subtitle: "经济、交易、职场沟通与理财", symbol: "briefcase", group: .featured),
        // 基础主题包
        StudyWordPack(id: "cat_greetings", title: "日常问候", shortTitle: "问候", subtitle: "寒暄、礼貌与高频表达", symbol: "hand.wave", group: .core),
        StudyWordPack(id: "cat_daily", title: "生活饮食", shortTitle: "生活", subtitle: "居家、餐饮与日常物品", symbol: "fork.knife", group: .core),
        StudyWordPack(id: "cat_verbs", title: "核心动词", shortTitle: "动词", subtitle: "日常高频动作与变化", symbol: "bolt", group: .core),
        StudyWordPack(id: "cat_adjectives", title: "形容与颜色", shortTitle: "形容", subtitle: "状态、性质与色彩描绘", symbol: "paintpalette", group: .core),
        StudyWordPack(id: "cat_work", title: "工作学习", shortTitle: "职场", subtitle: "校园、办公与专业表达", symbol: "laptopcomputer", group: .core),
        StudyWordPack(id: "cat_city", title: "城市出行", shortTitle: "城市", subtitle: "交通、建筑与城市生活", symbol: "building.2", group: .core),
        StudyWordPack(id: "cat_time", title: "时间数字", shortTitle: "时间", subtitle: "日期、时刻与基础计数", symbol: "clock", group: .core),
        StudyWordPack(id: "cat_nature", title: "自然世界", shortTitle: "自然", subtitle: "天气、动植物与地理", symbol: "leaf", group: .core),
        StudyWordPack(id: "cat_family", title: "人物家庭", shortTitle: "家庭", subtitle: "亲属称谓与人际关系", symbol: "person.2", group: .core),
        StudyWordPack(id: "cat_body", title: "身体情绪", shortTitle: "身心", subtitle: "身体部位与心理感受", symbol: "figure.walk", group: .core),
        StudyWordPack(id: "cat_biblical", title: "圣经文化", shortTitle: "圣经", subtitle: "经典文化与历史词源", symbol: "book.closed", group: .core),
    ]
}

struct StudyLetter: Decodable, Identifiable {
    let id: String
    let order: Int
    let hebrew: String
    let sofit: String?
    let nameHebrew: String
    let nameEnglish: String
    let nameChinese: String
    let transliteration: String
    let modernSound: String
    let modernIpa: String
    let biblicalIpa: String
    let biblicalDiff: String
    let pronunciationDesc: String
    let gematria: Int
    let categories: [String]
    let meaning: String
    let etymology: String
    let cursiveDesc: String
    let confusableWith: [String]
    let begadkefat: StudyDagesh?
    let sofitInfo: StudySofit?
    let strokeGuide: StudyStrokes
    let examples: [StudyExample]

    var studyName: String { nameEnglish.components(separatedBy: " / ").first ?? nameEnglish }
}

struct StudyDagesh: Decodable {
    struct Variant: Decodable {
        let glyph: String
        let name: String
        let modernSound: String
        let modernIpa: String
        let biblicalIpa: String
    }

    let withDagesh: Variant
    let withoutDagesh: Variant
    let modernPreserved: Bool
    let note: String

    func modernExample(for variant: Variant) -> String {
        let glyph = modernPreserved ? variant.glyph : withoutDagesh.glyph
        let medial = glyph.components(separatedBy: " / ").first ?? glyph
        return medial + "\u{05B5}"
    }
}

struct StudySofit: Decodable {
    let medialGlyph: String
    let finalGlyph: String
    let sofitGematria: Int
    let rule: String
    let exampleWord: StudyExample
}

struct StudyStrokes: Decodable {
    struct Stroke: Decodable {
        let d: String
        let startX: Double
        let startY: Double
    }

    struct CursiveMark: Decodable {
        let glyph: String
        let label: String
        let step: String
        let stroke: Stroke
    }

    let blockSteps: [String]
    let cursiveSteps: [String]
    let sofitBlockSteps: [String]?
    let sofitCursiveSteps: [String]?
    let blockStrokes: [Stroke]
    let cursiveStrokes: [Stroke]
    let cursiveMarks: [CursiveMark]?
    let sofitBlockStrokes: [Stroke]?
    let sofitCursiveStrokes: [Stroke]?
}

struct StudyExample: Decodable {
    let hebrew: String
    let transliteration: String
    let meaning: String
    let note: String?
}

enum WordFrequency: String, Codable, CaseIterable {
    case common, regular, extended

    var rank: Int {
        switch self {
        case .common: 0
        case .regular: 1
        case .extended: 2
        }
    }

    var label: String {
        switch self {
        case .common: "常用"
        case .regular: "较常用"
        case .extended: "扩展"
        }
    }
}

enum WordDifficulty: String, Codable, CaseIterable {
    case beginner, intermediate, advanced

    var rank: Int {
        switch self {
        case .beginner: 0
        case .intermediate: 1
        case .advanced: 2
        }
    }

    var label: String {
        switch self {
        case .beginner: "入门"
        case .intermediate: "进阶"
        case .advanced: "挑战"
        }
    }
}

struct StudyWord: Decodable, Identifiable {
    struct Sentence: Decodable {
        let hebrew: String
        let transliteration: String
        let meaningZh: String
    }

    let id: String
    let hebrew: String
    let hebrewUnpointed: String
    let alternateSpellings: [String]?
    let equivalentTo: String?
    let transliteration: String
    let ipa: String
    let meaningZh: String
    let partOfSpeech: String
    let grammarTag: String
    let category: String
    let frequency: WordFrequency
    let difficulty: WordDifficulty
    let frequencyRank: Int?
    let root: String?
    let note: String
    let sentence: Sentence?

    var rootKeys: [String] {
        guard let root else { return [] }
        var seen: Set<String> = []
        return root.split(separator: "/")
            .compactMap { StudyRoot.key(for: String($0)) }
            .filter { seen.insert($0).inserted }
    }

    var canPracticeSpelling: Bool {
        (2...8).contains(hebrewUnpointed.count)
            && hebrewUnpointed.allSatisfy { "אבגדהוזחטיכלמנסעפצקרשתךםןףץ".contains($0) }
    }

    private static func normalizeSpelling(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: "\"", with: "״")
    }

    private static func containsHebrewMarks(_ value: String) -> Bool {
        value.unicodeScalars.contains { (0x0591...0x05C7).contains($0.value) }
    }

    func acceptsSpelling(_ input: String) -> Bool {
        let answer = Self.normalizeSpelling(input)
        return ([hebrew, hebrewUnpointed] + (alternateSpellings ?? [])).contains { Self.normalizeSpelling($0) == answer }
    }

    func spellingComparison(for input: String) -> SpellingComparison {
        let normalizedInput = Self.normalizeSpelling(input)
        let rawCandidates = Self.containsHebrewMarks(normalizedInput)
            ? [hebrew, hebrewUnpointed] + (alternateSpellings ?? [])
            : [hebrewUnpointed] + (alternateSpellings ?? [])
        let candidates = rawCandidates.map(Self.normalizeSpelling).filter { !$0.isEmpty }
        let inputChars = Array(normalizedInput)
        var bestTarget = Array(candidates.first ?? Self.normalizeSpelling(hebrewUnpointed))
        var bestDistance = Int.max
        for candidate in candidates {
            let chars = Array(candidate)
            let distance = SpellingComparison.editDistance(inputChars, chars)
            if distance < bestDistance {
                bestDistance = distance
                bestTarget = chars
                if distance == 0 { break }
            }
        }
        return SpellingComparison.compare(input: inputChars, target: bestTarget)
    }
}

struct SpellingComparison: Equatable {
    enum TokenKind: Equatable {
        case match
        case wrong
        case extra
        case missing
    }

    struct Token: Equatable, Identifiable {
        let id: Int
        let text: String
        let kind: TokenKind
        let isFinalFormMismatch: Bool
    }

    let tokens: [Token]
    let summary: String
    let isExactMatch: Bool

    private static let finalFormCounterparts: [Character: Character] = [
        "כ": "ך", "ך": "כ",
        "מ": "ם", "ם": "מ",
        "נ": "ן", "ן": "נ",
        "פ": "ף", "ף": "פ",
        "צ": "ץ", "ץ": "צ",
    ]

    static func editDistance(_ source: [Character], _ target: [Character]) -> Int {
        let m = source.count
        let n = target.count
        if m == 0 { return n }
        if n == 0 { return m }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                let cost = source[i - 1] == target[j - 1] ? 0 : 1
                dp[i][j] = min(dp[i - 1][j - 1] + cost, dp[i - 1][j] + 1, dp[i][j - 1] + 1)
            }
        }
        return dp[m][n]
    }

    static func compare(input: [Character], target: [Character]) -> SpellingComparison {
        let m = input.count
        let n = target.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        if m > 0 && n > 0 {
            for i in 1...m {
                for j in 1...n {
                    let cost = input[i - 1] == target[j - 1] ? 0 : 1
                    dp[i][j] = min(dp[i - 1][j - 1] + cost, dp[i - 1][j] + 1, dp[i][j - 1] + 1)
                }
            }
        }

        var reversed: [(text: String, kind: TokenKind, finalForm: Bool)] = []
        var i = m
        var j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && input[i - 1] == target[j - 1] && dp[i][j] == dp[i - 1][j - 1] {
                reversed.append((String(input[i - 1]), .match, false))
                i -= 1
                j -= 1
            } else if i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + 1 {
                let isFinal = finalFormCounterparts[input[i - 1]] == target[j - 1]
                reversed.append((String(input[i - 1]), .wrong, isFinal))
                i -= 1
                j -= 1
            } else if i > 0 && dp[i][j] == dp[i - 1][j] + 1 {
                reversed.append((String(input[i - 1]), .extra, false))
                i -= 1
            } else {
                reversed.append(("?", .missing, false))
                j -= 1
            }
        }

        let tokens = reversed.reversed().enumerated().map { offset, item in
            Token(id: offset, text: item.text, kind: item.kind, isFinalFormMismatch: item.finalForm)
        }

        let wrongPositions = tokens.filter { $0.kind == .wrong }.map { $0.id + 1 }
        let missingPositions = tokens.filter { $0.kind == .missing }.map { $0.id + 1 }
        let extraPositions = tokens.filter { $0.kind == .extra }.map { $0.id + 1 }
        let finalMismatchOnly = wrongPositions.count == 1
            && missingPositions.isEmpty
            && extraPositions.isEmpty
            && tokens.contains { $0.kind == .wrong && $0.isFinalFormMismatch }

        let summary: String
        if wrongPositions.isEmpty && missingPositions.isEmpty && extraPositions.isEmpty {
            summary = ""
        } else if finalMismatchOnly {
            summary = "第 \(wrongPositions[0]) 位注意词尾形（从右往左数）"
        } else {
            var parts: [String] = []
            if !wrongPositions.isEmpty {
                parts.append("第 \(formatPositions(wrongPositions)) 位有误")
            }
            if !missingPositions.isEmpty {
                parts.append("第 \(formatPositions(missingPositions)) 位缺少字母")
            }
            if !extraPositions.isEmpty {
                parts.append("第 \(formatPositions(extraPositions)) 位多写了字母")
            }
            summary = parts.joined(separator: "，") + "（从右往左数）"
        }

        return SpellingComparison(tokens: tokens, summary: summary, isExactMatch: summary.isEmpty)
    }

    private static func formatPositions(_ positions: [Int]) -> String {
        positions.map(String.init).joined(separator: "、")
    }
}

enum StudyRoot {
    private static let normalLetters: [Character: Character] = ["ך": "כ", "ם": "מ", "ן": "נ", "ף": "פ", "ץ": "צ"]
    private static let finalLetters: [Character: Character] = ["כ": "ך", "מ": "ם", "נ": "ן", "פ": "ף", "צ": "ץ"]

    static func letters(in value: String) -> String {
        let hebrew = String(value.unicodeScalars.filter { (0x05D0...0x05EA).contains($0.value) })
        return String(hebrew.map { normalLetters[$0] ?? $0 })
    }

    static func key(for value: String) -> String? {
        let letters = letters(in: value)
        guard let last = letters.last, (2...5).contains(letters.count) else { return nil }
        return (Array(letters.dropLast()) + [finalLetters[last] ?? last]).map { String($0) }.joined(separator: "-")
    }
}

struct StudyInflection: Decodable {
    let hebrew: String
    let translit: String
    let label: String?
}

private struct StudyInflectionGroup: Decodable {
    let forms: [String: StudyInflection]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case ms, fs, mp, fp, infinitive, past3ms, singular, plural
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var forms: [String: StudyInflection] = [:]
        for key in CodingKeys.allCases {
            forms[key.rawValue] = try container.decodeIfPresent(StudyInflection.self, forKey: key)
        }
        self.forms = forms
    }
}

struct StudyPhrase: Decodable, Identifiable {
    let id: String
    let scenario: String
    let hebrew: String
    let hebrewUnpointed: String
    let transliteration: String
    let meaningZh: String
    let note: String?
}

enum ReadingNiqqudMode: String, CaseIterable, Identifiable {
    case full, assisted, unpointed

    var id: Self { self }

    var title: String {
        switch self {
        case .full: "全带点"
        case .assisted: "过渡"
        case .unpointed: "无点"
        }
    }
}

struct StudyReading: Decodable, Identifiable {
    struct Gloss {
        let range: Range<String.Index>
        let definition: String
    }

    struct Audio: Decodable {
        enum Style: String, Decodable, Hashable {
            case modernSynthesis, scriptureReading, traditionalChant

            var title: String {
                switch self {
                case .modernSynthesis: "现代合成发音"
                case .scriptureReading: "经文朗读"
                case .traditionalChant: "传统吟诵"
                }
            }
        }

        let style: Style
        let performer: String?
    }

    struct Sentence: Decodable {
        let hebrew: String
        let unpointed: String
        let transliteration: String
        let chinese: String
        var audio: Audio? = nil
    }

    struct Question: Decodable {
        let prompt: String
        let choices: [String]
        let correctIndex: Int
    }

    let id: String
    let title: String
    let category: String
    let source: String?
    let sentences: [Sentence]
    let glosses: [String: String]
    let question: Question

    var audioStyles: [Audio.Style] {
        var seen: Set<Audio.Style> = []
        return sentences.compactMap { $0.audio?.style }.filter { seen.insert($0).inserted }
    }

    private static let hebrewWords = try? NSRegularExpression(pattern: #"(?:[א-ת]\p{M}*)+"#)

    func displayText(for sentence: Sentence, mode: ReadingNiqqudMode) -> String {
        switch mode {
        case .full:
            return sentence.hebrew
        case .unpointed:
            return sentence.unpointed
        case .assisted:
            let text = sentence.hebrew
            let matches = Self.hebrewWords?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
            guard !matches.isEmpty else { return sentence.unpointed }
            var output = ""
            var next = text.startIndex
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                output += text[next..<range.lowerBound]
                let token = String(text[range])
                let unpointed = withoutHebrewMarks(token)
                output += glosses[unpointed] != nil ? token : unpointed
                next = range.upperBound
            }
            output += text[next...]
            return output
        }
    }

    func inlineGlosses(in text: String) -> [Gloss] {
        let matches = Self.hebrewWords?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text),
                  let definition = glosses[withoutHebrewMarks(String(text[range]))] else { return nil }
            return Gloss(range: range, definition: definition)
        }
    }
}

func withoutHebrewMarks(_ text: String) -> String {
    text.replacingOccurrences(of: #"\p{M}"#, with: "", options: .regularExpression)
}

struct StudyNiqqud: Decodable, Identifiable {
    let id: String
    let nameHebrew: String
    let nameEnglish: String
    let nameChinese: String
    let sample: String
    let vowelSound: String
    let ipa: String
    let note: String
}

struct StudyComparison: Decodable, Identifiable {
    let id: String
    let title: String
    let letterIds: [String]
    let comparisonNotes: [String]
    let tip: String
}

struct StudyConsonant: Decodable, Identifiable {
    let id: String
    let glyph: String
    let label: String
    let roman: String
    let ipa: String
    let isSilent: Bool?
}

struct StudyVowel: Decodable, Identifiable {
    let id: String
    let name: String
    let nameZh: String
    let mark: String
    let suffix: String?
    let vowelRoman: String
    let vowelIpa: String
    let tip: String
}

struct StudyGrammarAffix: Decodable, Identifiable {
    struct Example: Decodable {
        let hebrew: String
        let transliteration: String
        let meaning: String
        let wordId: String?
    }

    let id: String
    let kind: String
    let hebrew: String
    let transliteration: String
    let meaning: String
    let rule: String
    let examples: [Example]
}

struct StudyGrammarBinyan: Decodable, Identifiable {
    let id: String
    let nameHebrew: String
    let nameEnglish: String
    let role: String
    let pattern: String
    let presentPrefix: String
    let tip: String
    let exampleWordIds: [String]
}

struct StudyMinimalPair: Decodable, Identifiable {
    let id: String
    let contrast: String
    let tip: String
    let firstWordId: String
    let secondWordId: String
}

struct StudyPathStage: Decodable, Identifiable {
    let id: String
    let stage: Int
    let title: String
    let subtitle: String
    let goal: String
    let letterIds: [String]
    let ruleTopic: String
    let wordIds: [String]
    let readingId: String?
}
