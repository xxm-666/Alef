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
    private let ambiguousSpellings: Set<String>

    enum CodingKeys: CodingKey {
        case letters, words, wordCategories, phrases, phraseCategories, readings, readingCategories
        case niqqud, confusables, inflections, audio, consonants, vowels, defaultDisplay, displayPresets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        letters = try container.decode([StudyLetter].self, forKey: .letters)
        words = try container.decode([StudyWord].self, forKey: .words)
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

    func dueWords(in progress: StudyProgress) -> [StudyWord] {
        let schedule = progress.schedule
        return words.filter { schedule[$0.id]?.isDue == true }.sorted {
            (schedule[$0.id]?.nextReviewAt ?? 0) < (schedule[$1.id]?.nextReviewAt ?? 0)
        }
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

    var canPracticeSpelling: Bool {
        (2...8).contains(hebrewUnpointed.count)
            && hebrewUnpointed.allSatisfy { "אבגדהוזחטיכלמנסעפצקרשתךםןףץ".contains($0) }
    }

    func acceptsSpelling(_ input: String) -> Bool {
        let answer = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return answer == hebrew || answer == hebrewUnpointed || alternateSpellings?.contains(answer) == true
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
