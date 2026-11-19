import SwiftUI

struct StudyRulesView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent

    private let categories = [
        ("syllables", "拼读实验室", "waveform", "组合辅音和元音，练习听辨音节"),
        ("sofit", "词尾变形", "textformat.abc", "对照五个字母的普通形和词尾形"),
        ("begadkefat", "达盖什", "circle.grid.2x2", "比较带点与不带点的现代及古典读音"),
        ("confusable", "易混字母", "square.on.square", "辨认外形相近的字母"),
        ("guttural", "喉音字母", "speaker.wave.2", "学习喉音的元音搭配与词尾读法"),
        ("niqqud", "元音点", "character.cursor.ibeam", "查看元音点示例并听名称")
    ]

    var body: some View {
        List {
            ForEach(categories, id: \.0) { key, label, symbol, description in
                NavigationLink {
                    details(key)
                        .navigationTitle(label)
                        .onAppear { progress.write(key, for: "alef.rulesTab.v1") }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label).font(.headline)
                            Text(description).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } icon: {
                        Image(systemName: symbol).foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("拼读与规则")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func details(_ category: String) -> some View {
        switch category {
        case "syllables":
            StudySyllablesView(consonants: content.consonants, vowels: content.vowels)
        case "niqqud":
            List(content.niqqud) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(item.nameEnglish) · \(item.nameChinese)").font(.headline)
                    HebrewText(text: item.sample, size: 42).foregroundStyle(.tint)
                    LabeledContent("读音", value: "\(item.vowelSound) · \(item.ipa)")
                    PronunciationButton(hebrew: item.nameHebrew, fallback: item.nameEnglish,
                                        title: "朗读元音点名称", minimumHitSize: 44)
                    Text(item.note).foregroundStyle(.secondary)
                }
            }
        case "confusable":
            List(content.confusables) { group in
                let letters = content.letters.filter { group.letterIds.contains($0.id) }
                Section(group.title) {
                    ScrollView(.horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 20) {
                            ForEach(letters) { letter in
                                HebrewText(text: letter.hebrew, size: 44).foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    ForEach(letters) { letter in
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
                            comparisonLayout {
                                sofitGlyph("词中", glyph: pair.medialGlyph)
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
                            comparisonLayout {
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
                Section("发音规则") {
                    Text("א、ה、ח、ע 和特性相近的 ר 不接受双写点（Dagesh Chazak）。")
                    Text("这些字母常与复合元音 אֲ · אֱ · אֳ 搭配。")
                    Text("词尾 ח、ע 及带 Mappiq 的 הּ 若紧跟非 /a/ 元音，可能带前置 Patach。")
                }
                Section("词尾举例") {
                    LabeledContent("带前置 Patach", value: "רוּחַ · ruach")
                    LabeledContent("已有 /a/，无需另加", value: "אָח · ach")
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

    private func comparisonLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return layout { content() }.padding(.vertical, 8)
    }

    private func sofitGlyph(_ title: String, glyph: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HebrewText(text: glyph, size: 36)
                HebrewText(text: glyph, cursive: true, size: 36)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func variant(_ title: String, _ value: StudyDagesh.Variant) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            HebrewText(text: value.glyph, size: 40)
            Text("现代 \(value.modernIpa)")
            Text("古典 \(value.biblicalIpa)").font(.footnote).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func letterLink(_ letter: StudyLetter) -> some View {
        NavigationLink {
            LetterStudyView(letter: letter, content: content)
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack {
                    HebrewText(text: letter.hebrew)
                    Text(letter.nameChinese).fixedSize()
                    Spacer()
                    Text(letter.modernIpa).foregroundStyle(.secondary).fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    HebrewText(text: letter.hebrew)
                    Text(letter.nameChinese)
                    Text(letter.modernIpa).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct StudySyllablesView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
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
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                if typeSize.isAccessibilitySize { modePicker.pickerStyle(.menu) }
                else { modePicker.pickerStyle(.segmented) }
                if quizzing {
                    LabeledContent("当前得分", value: "\(correct) / \(total)")
                        .font(.subheadline).monospacedDigit()
                } else {
                    Picker("辅音", selection: $consonantID) {
                        ForEach(consonants) { item in Text("\(item.glyph) · \(item.label)").tag(item.id) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)

            ScrollViewReader { scroll in
                List {
                    if quizzing {
                        if let question { quiz(question) }
                    } else if let consonant = consonants.first(where: { $0.id == consonantID }) {
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
                .contentMargins(.vertical, 8, for: .scrollContent)
                .onChange(of: answer) { _, newAnswer in
                    if quizzing {
                        scroll.scrollTo(newAnswer == nil ? "syllable-question" : "syllable-result",
                                        anchor: newAnswer == nil ? .top : .bottom)
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if quizzing && answer != nil {
                StudyActionBar {
                    Button(action: next) {
                        Label("下一题", systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .onChange(of: quizzing) { _, active in
            if active { next() }
            else { audio.stop() }
        }
    }

    private var modePicker: some View {
        Picker("练习方式", selection: $quizzing) {
            Text("拼读探索").tag(false)
            Text("听音测验").tag(true)
        }
    }

    @ViewBuilder private func quiz(_ question: Question) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("听发音，选出对应的希伯来语音节。").font(.headline)
                PronunciationButton(hebrew: word(question.consonant, question.solution), fallback: roman(question.consonant, question.solution),
                                    title: "播放题目", minimumHitSize: 44)
            }
            .id("syllable-question")
            ForEach(question.choices) { vowel in
                StudyAnswerButton(title: word(question.consonant, vowel), submitted: answer != nil,
                                  selected: answer == vowel.id, correct: vowel.id == question.solution.id, isHebrew: true) {
                    grade(vowel.id, solution: question.solution.id)
                }
            }
        }
        if let answer {
            Section("答题结果") {
                Label(answer == question.solution.id ? "答对了" : "正确答案 · \(word(question.consonant, question.solution))",
                      systemImage: answer == question.solution.id ? "checkmark.circle" : "info.circle")
                Text(question.solution.tip).font(.footnote).foregroundStyle(.secondary)
            }
            .id("syllable-result")
        }
    }

    private func grade(_ choice: String, solution: String) {
        guard answer == nil else { return }
        answer = choice
        total += 1
        let success = choice == solution
        if success { correct += 1 }
        audio.playFeedback(success ? .correct : .wrong)
        progress.recordStudy()
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
            PronunciationButton(hebrew: word(consonant, vowel), fallback: roman(consonant, vowel), iconOnly: true, minimumHitSize: 44)
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
