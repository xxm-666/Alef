import Foundation

struct StudyContent: Decodable {
    let letters: [StudyLetter]
    let words: [StudyWord]
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

    enum CodingKeys: CodingKey {
        case letters, words, wordCategories, phrases, phraseCategories, readings, readingCategories
        case niqqud, confusables, inflections, audio, consonants, vowels, defaultDisplay, displayPresets
        case grammarAffixes, grammarBinyanim, minimalPairs, learningPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        letters = try container.decode([StudyLetter].self, forKey: .letters)
        words = try container.decode([StudyWord].self, forKey: .words)
        wordsByRoot = words.reduce(into: [:]) { index, word in
            for root in word.rootKeys {
                index[root, default: []].append(word)
            }
        }
        let entriesBySpelling = Dictionary(grouping: words, by: \.hebrewUnpointed)
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
        learningPath = try container.decode([StudyPathStage].self, forKey: .learningPath)
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

    func recommendedStage(in progress: StudyProgress) -> StudyPathStage? {
        let letters = progress.letterMastery
        let words = progress.wordMastery
        return learningPath.first { stage in
            stage.letterIds.contains { letters[$0] != .mastered }
                || stage.wordIds.contains { words[$0] != .mastered }
        }
    }

    func dailyVocabularyWords(in progress: StudyProgress) -> [StudyWord] {
        guard let stage = recommendedStage(in: progress) else { return words }
        let stageIDs = Set(stage.wordIds)
        return words.filter { stageIDs.contains($0.id) } + words.filter { !stageIDs.contains($0.id) }
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

    func words(withRoot root: String) -> [StudyWord] {
        guard let key = StudyRoot.key(for: root) else { return [] }
        return wordsByRoot[key] ?? []
    }

    func rootFamilies() -> [(root: String, words: [StudyWord])] {
        wordsByRoot
            .map { (root: $0.key, words: $0.value) }
            .sorted { lhs, rhs in
                if lhs.words.count != rhs.words.count { return lhs.words.count > rhs.words.count }
                return lhs.root < rhs.root
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
    let transliteration: String
    let ipa: String
    let meaningZh: String
    let partOfSpeech: String
    let grammarTag: String
    let category: String
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

    struct Sentence: Decodable {
        let hebrew: String
        let unpointed: String
        let transliteration: String
        let chinese: String
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
