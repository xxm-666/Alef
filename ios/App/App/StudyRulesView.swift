import SwiftUI

struct StudyRulesView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    private let categories = [("syllables", "拼读实验室", "waveform"), ("sofit", "词尾变形", "textformat.abc"),
                              ("begadkefat", "达盖什", "circle.grid.2x2"), ("confusable", "易混字母", "square.on.square"),
                              ("guttural", "喉音字母", "speaker.wave.2"), ("niqqud", "元音点", "character.cursor.ibeam")]

    var body: some View {
        List {
            ForEach(categories, id: \.0) { key, label, symbol in
                NavigationLink {
                    details(key)
                        .navigationTitle(label)
                        .onAppear { progress.write(key, for: "alef.rulesTab.v1") }
                } label: {
                    Label(label, systemImage: symbol)
                }
            }
        }
        .navigationTitle("拼读与规则")
    }

    @ViewBuilder private func details(_ category: String) -> some View {
        switch category {
        case "syllables":
            StudySyllablesView(consonants: content.consonants, vowels: content.vowels)
        case "niqqud":
            List(content.niqqud) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HebrewText(text: item.sample, size: 42)
                        Spacer()
                        PronunciationButton(hebrew: item.nameHebrew, fallback: item.nameEnglish, iconOnly: true)
                    }
                    Text("\(item.nameEnglish) · \(item.nameChinese)").font(.headline)
                    Text("\(item.vowelSound) · \(item.ipa)")
                    Text(item.note).foregroundStyle(.secondary)
                }
            }
        case "confusable":
            List(content.confusables) { group in
                Section(group.title) {
                    ForEach(content.letters.filter { group.letterIds.contains($0.id) }) { letter in
                        letterLink(letter)
                    }
                    ForEach(Array(group.comparisonNotes.enumerated()), id: \.offset) { _, note in Text(note) }
                    Text(group.tip).foregroundStyle(.secondary)
                }
            }
        case "sofit":
            List {
                Section("词尾规则") {
                    Text("记忆口诀：כמנפ״ץ（Kamnapetz）。五个字母位于词尾时分别写作 ך · ם · ן · ף · ץ。除闭合的 ם 外，其余四个词尾形都向下越过基线。")
                }
                ForEach(content.letters.filter { $0.sofitInfo != nil }) { letter in
                    if let pair = letter.sofitInfo {
                        Section("\(letter.nameEnglish) · \(letter.nameChinese)") {
                            HStack {
                                sofitGlyph("词中", glyph: pair.medialGlyph)
                                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                                sofitGlyph("词尾", glyph: pair.finalGlyph)
                            }
                            LabeledContent("字母数值", value: "\(letter.gematria) → \(pair.sofitGematria)")
                            Text(pair.rule)
                            WordExampleRow(example: pair.exampleWord)
                            letterLink(letter)
                        }
                    }
                }
            }
        case "begadkefat":
            List {
                Section("带点与不带点") {
                    Text("ב · ג · ד · כ · פ · ת 的中心点（Dagesh Kal）标记硬音。现代希伯来语只有 ב · כ · פ 保留硬音和软音的区别，ג · ד · ת 的擦音化见于古典朗诵。")
                }
                ForEach(content.letters.filter { $0.begadkefat != nil }) { letter in
                    if let pair = letter.begadkefat {
                        Section("\(letter.nameEnglish) · \(letter.nameChinese)") {
                            HStack(alignment: .top) {
                                variant("带点", pair.withDagesh)
                                variant("不带点", pair.withoutDagesh)
                            }
                            Label(pair.modernPreserved ? "现代保留音变" : "现代读音已合并", systemImage: "waveform")
                            Text(pair.note)
                            letterLink(letter)
                        }
                    }
                }
            }
        default:
            List {
                Section("喉音和准喉音") {
                    Text("א、ה、ח、ע 和特性相近的 ר 不接受双写点（Dagesh Chazak），并常和复合元音 אֲ · אֱ · אֳ 搭配。")
                    Text("词尾 ח、ע 及带 Mappiq 的 הּ 若紧跟非 /a/ 元音，可能带前置 Patach。例如 רוּחַ 读 ruach。אָח 前面已有 /a/，无需再加。")
                }
                ForEach(content.letters.filter { $0.categories.contains("guttural") || $0.id == "resh" }) { letter in
                    Section("\(letter.hebrew) · \(letter.nameChinese)") {
                        LabeledContent("现代 · 古典", value: "\(letter.modernIpa) · \(letter.biblicalIpa)")
                        Text(letter.biblicalDiff)
                        letterLink(letter)
                    }
                }
            }
        }
    }

    private func sofitGlyph(_ title: String, glyph: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                HebrewText(text: glyph, size: 36)
                HebrewText(text: glyph, cursive: true, size: 36)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func variant(_ title: String, _ value: StudyDagesh.Variant) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HebrewText(text: value.glyph, size: 40)
            Text("现代 \(value.modernIpa)")
            Text("古典 \(value.biblicalIpa)").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func letterLink(_ letter: StudyLetter) -> some View {
        NavigationLink {
            LetterStudyView(letter: letter, content: content)
        } label: {
            HStack {
                HebrewText(text: letter.hebrew)
                Text(letter.nameChinese)
                Spacer()
                Text(letter.modernIpa).foregroundStyle(.secondary)
            }
        }
    }
}

private struct StudySyllablesView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let consonants: [StudyConsonant]
    let vowels: [StudyVowel]
    @State private var consonantID = "bet"
    @State private var quizzing = false
    @State private var question: Question?
    @State private var answer: String?
    @State private var correct = 0
    @State private var total = 0

    private struct Question {
        let consonant: StudyConsonant
        let choices: [StudyVowel]
        let solution: StudyVowel
    }

    var body: some View {
        List {
            Picker("练习方式", selection: $quizzing) {
                Text("拼读探索").tag(false)
                Text("听音测验").tag(true)
            }
            .pickerStyle(.segmented)
            if quizzing {
                if let question { quiz(question) }
            } else if let consonant = consonants.first(where: { $0.id == consonantID }) {
                Picker("辅音", selection: $consonantID) {
                    ForEach(consonants) { item in Text("\(item.glyph) · \(item.label)").tag(item.id) }
                }
                Section("辅音与元音组合") {
                    ForEach(vowels) { vowel in combination(consonant, vowel) }
                }
                Section("Shva 的静音与轻读") {
                    WordExampleRow(example: StudyExample(hebrew: "סְלִיחָה", transliteration: "slicha", meaning: "对不起",
                                                         note: "词首辅音下的 Shva 在这里静音。"))
                    WordExampleRow(example: StudyExample(hebrew: "מְדַבֵּר", transliteration: "medaber", meaning: "说话",
                                                         note: "词首辅音下的 Shva 在这里轻读 /e/。"))
                }
            }
        }
        .onChange(of: quizzing) { _, active in
            if active { next() }
            else { audio.stop() }
        }
    }

    private func quiz(_ question: Question) -> some View {
        Section("得分 \(correct) / \(total)") {
            Text("听发音，选出对应的希伯来语音节。")
            PronunciationButton(hebrew: word(question.consonant, question.solution), fallback: roman(question.consonant, question.solution),
                                title: "播放题目")
            ForEach(question.choices) { vowel in
                Button {
                    guard answer == nil else { return }
                    answer = vowel.id
                    total += 1
                    let success = vowel.id == question.solution.id
                    if success { correct += 1 }
                    audio.playFeedback(success ? .correct : .wrong)
                    progress.recordStudy()
                } label: {
                    HebrewText(text: word(question.consonant, vowel), size: 34)
                }
                .disabled(answer != nil)
            }
            if let answer {
                Text(answer == question.solution.id ? "答对了" : "正确答案：\(word(question.consonant, question.solution))")
                Text(question.solution.tip).font(.footnote).foregroundStyle(.secondary)
                Button("下一题", action: next)
            }
        }
    }

    private func combination(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HebrewText(text: word(consonant, vowel), size: 37)
                Text("\(vowel.name) · \(vowel.nameZh)").font(.subheadline)
                let consonantIpa = consonant.isSilent == true ? "" : consonant.ipa
                Text("\(roman(consonant, vowel)) · /\(consonantIpa)\(vowel.vowelIpa)/").foregroundStyle(.secondary)
                Text(vowel.tip).font(.footnote)
            }
            Spacer()
            PronunciationButton(hebrew: word(consonant, vowel), fallback: roman(consonant, vowel), iconOnly: true)
        }
    }

    private func word(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> String {
        consonant.glyph + vowel.mark + (vowel.suffix ?? "")
    }

    private func roman(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> String {
        if vowel.id == "shva" { return consonant.isSilent == true ? "(e / ∅)" : consonant.roman + "(e)" }
        return consonant.roman + vowel.vowelRoman
    }

    private func next() {
        let core = ["kamatz", "tzere", "chirik", "cholam", "shuruk"]
        let choices = Array(vowels.filter { core.contains($0.id) }.shuffled().prefix(4))
        guard let consonant = consonants.filter({ $0.isSilent != true }).randomElement(),
              let solution = choices.randomElement() else { return }
        question = Question(consonant: consonant, choices: choices, solution: solution)
        answer = nil
        audio.speak(word(consonant, solution), fallback: roman(consonant, solution), rate: progress.speechRate)
    }
}
