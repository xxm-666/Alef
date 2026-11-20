import SwiftUI

struct StudyRulesView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    let topic: String?

    init(content: StudyContent, topic: String? = nil) {
        self.content = content
        self.topic = topic
    }

    private let categories = [
        ("sofit", "词尾变形", "textformat.abc", "Sofit", "5 组"),
        ("begadkefat", "达盖什", "ellipsis", "Begadkefat", "6 组"),
        ("confusable", "易混字母", "arrow.left.arrow.right", "对照辨析", ""),
        ("guttural", "喉音字母", "headphones", "发音规则", ""),
        ("niqqud", "元音点", "character.cursor.ibeam", "Niqqud", "名称与读音")
    ]

    var body: some View {
        if let topic, let category = categories.first(where: { $0.0 == topic }) {
            ruleDetails(topic, title: category.1)
        } else {
            overview
        }
    }

    private var overview: some View {
        StudyPage {
            StudyHeading(section: "规则", title: "让每个声音，有迹可循")
            NavigationLink {
                StudySyllablesView(consonants: content.consonants, vowels: content.vowels)
            } label: {
                StudyCard(highlighted: true) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            StudySectionTitle("拼读实验室")
                            HStack(spacing: 12) {
                                HebrewText(text: "בַּ", size: 33)
                                HebrewText(text: "בִּ", size: 33)
                                HebrewText(text: "בֶּ", size: 33)
                            }
                            .accessibilityHidden(true)
                            Text("探索辅音与元音的组合").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "waveform")
                            .font(.largeTitle)
                            .foregroundStyle(progress.theme.accent)
                            .accessibilityHidden(true)
                    }
                    Label("进入实验室", systemImage: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(progress.theme.primaryButton, in: Capsule())
                }
            }
            .buttonStyle(.plain)

            StudySectionTitle("规则速查")
            VStack(spacing: 7) {
                ForEach(categories, id: \.0) { key, title, symbol, subtitle, count in
                    NavigationLink {
                        StudyRulesView(content: content, topic: key)
                    } label: {
                        StudyCard(padding: 9) {
                            StudyRow(title: title, symbol: symbol, subtitle: subtitle, value: count.isEmpty ? nil : count)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .studyHome()
    }

    @ViewBuilder private func ruleDetails(_ category: String, title: String) -> some View {
        if category == "sofit" {
            StudySofitView(content: content)
                .onAppear { progress.write(category, for: "alef.rulesTab.v1") }
        } else {
            StudyPage {
                switch category {
                case "niqqud": niqqudDetails
                case "confusable": confusableDetails
                case "begadkefat": begadkefatDetails
                default: gutturalDetails
                }
            }
            .studyDetail(title)
            .onAppear { progress.write(category, for: "alef.rulesTab.v1") }
        }
    }

    private var niqqudDetails: some View {
        ForEach(content.niqqud) { item in
            StudyCard {
                HStack(spacing: 9) {
                    HebrewText(text: item.sample, size: 42)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(item.nameEnglish) · \(item.nameChinese)").font(.headline)
                        Text("\(item.vowelSound) · \(item.ipa)").foregroundStyle(progress.theme.mutedInk)
                    }
                    Spacer(minLength: 0)
                    PronunciationButton(hebrew: item.nameHebrew, fallback: item.nameEnglish, iconOnly: true,
                                        title: "朗读\(item.nameChinese)")
                }
                Text(item.note).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
            }
        }
    }

    private var confusableDetails: some View {
        ForEach(content.confusables) { group in
            let letters = content.letters.filter { group.letterIds.contains($0.id) }
            StudyCard {
                StudySectionTitle(group.title)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(letters) { letter in
                            NavigationLink {
                                LetterStudyView(letter: letter, content: content)
                            } label: {
                                VStack(spacing: 4) {
                                    HebrewText(text: letter.hebrew, size: 44)
                                    Text(letter.nameChinese).font(.subheadline.weight(.medium))
                                    Text(letter.modernIpa).font(.caption).foregroundStyle(progress.theme.mutedInk)
                                }
                                .padding(10)
                                .frame(minWidth: 66, minHeight: 44)
                                .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                                .accessibilityElement(children: .combine)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                ForEach(Array(group.comparisonNotes.enumerated()), id: \.offset) { _, note in Text(note).font(.subheadline) }
                StudyNotice(title: group.tip, symbol: "lightbulb")
            }
        }
    }

    @ViewBuilder private var begadkefatDetails: some View {
        StudyNotice(title: "带点与不带点", symbol: "info.circle",
                    note: "达盖什轻点标记硬音。现代希伯来语中，ב、כ、פ 仍保留硬音和软音的区别。")
        ForEach(content.letters.filter { $0.begadkefat != nil }) { letter in
            if let pair = letter.begadkefat {
                StudyCard {
                    StudySectionTitle("\(letter.studyName) · \(letter.nameChinese)")
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
                    layout {
                        variant("带达盖什", pair.withDagesh)
                        variant("不带达盖什", pair.withoutDagesh)
                    }
                    Label(pair.modernPreserved ? "现代保留音变" : "现代读音已合并", systemImage: "waveform")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress.theme.accent)
                    Text(pair.note).font(.subheadline)
                    letterLink(letter)
                }
            }
        }
    }

    @ViewBuilder private var gutturalDetails: some View {
        StudyCard(highlighted: true) {
            StudySectionTitle("发音规则")
            Text("א、ה、ח、ע 和特性相近的 ר 不接受双写点（Dagesh Chazak）。")
            Text("这些字母常与复合元音 אֲ · אֱ · אֳ 搭配。")
            Text("词尾 ח、ע 及带 Mappiq 的 הּ 若紧跟非 /a/ 元音，可能带前置 Patach。")
        }
        StudySectionTitle("词尾举例")
        StudyCard {
            WordExampleRow(example: StudyExample(hebrew: "רוּחַ", transliteration: "ruach", meaning: "风", note: "带前置 Patach"))
            WordExampleRow(example: StudyExample(hebrew: "אָח", transliteration: "ach", meaning: "兄弟", note: "已有 /a/，无需另加"))
        }
        ForEach(content.letters.filter { $0.categories.contains("guttural") || $0.id == "resh" }) { letter in
            StudyCard {
                StudySectionTitle("\(letter.hebrew) · \(letter.nameChinese)")
                LabeledContent("现代 · 古典", value: "\(letter.modernIpa) · \(letter.biblicalIpa)")
                Text(letter.biblicalDiff).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                letterLink(letter)
            }
        }
    }

    private func variant(_ title: String, _ value: StudyDagesh.Variant) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            HebrewText(text: value.glyph, size: 43)
            Text("现代 \(value.modernIpa)")
            Text("古典 \(value.biblicalIpa)").font(.footnote).foregroundStyle(progress.theme.mutedInk)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func letterLink(_ letter: StudyLetter) -> some View {
        NavigationLink {
            LetterStudyView(letter: letter, content: content)
        } label: {
            StudyRow(title: "查看\(letter.nameChinese)", symbol: "book", subtitle: letter.studyName)
        }
        .buttonStyle(.plain)
    }
}

private struct StudySyllablesView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
    let consonants: [StudyConsonant]
    let vowels: [StudyVowel]
    @State private var consonantID = "bet"
    @State private var vowelID = "kamatz"
    @State private var quizzing = false
    @State private var question: Question?
    @State private var selection: String?
    @State private var answer: String?
    @State private var correct = 0
    @State private var total = 0

    private struct Question {
        let consonant: StudyConsonant
        let choices: [StudyVowel]
        let solution: StudyVowel
    }

    var body: some View {
        ScrollViewReader { scroll in
            StudyPage {
                StudySegments(title: "拼读模式", options: [(false, "拼读探索"), (true, "听音测验")], selection: $quizzing)
                if quizzing {
                    if let question { quiz(question) }
                    else { ContentUnavailableView("没有可用的音节", systemImage: "waveform") }
                } else if let consonant = consonants.first(where: { $0.id == consonantID }),
                          let vowel = vowels.first(where: { $0.id == vowelID }) ?? vowels.first {
                    exploration(consonant, vowel: vowel)
                }
            }
            .onChange(of: answer) { _, value in
                if quizzing {
                    scroll.scrollTo(value == nil ? "syllable-question" : "syllable-result", anchor: value == nil ? .top : .bottom)
                }
            }
        }
        .studyDetail("拼读实验室")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StudyActionBar {
                if quizzing {
                    if let question {
                        Button {
                            if answer != nil { next() }
                            else if let selection { grade(selection, solution: question.solution.id) }
                        } label: {
                            Label(answer == nil ? "确认答案" : "下一题", systemImage: answer == nil ? "checkmark" : "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudyButtonStyle(prominent: true))
                        .disabled(answer == nil && selection == nil)
                    }
                } else {
                    Button { quizzing = true } label: {
                        Label("开始听音测验", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                }
            }
        }
        .onChange(of: quizzing) { _, active in
            if active { next() }
            else { audio.stop() }
        }
        .onDisappear { audio.stop() }
    }

    @ViewBuilder private func exploration(_ consonant: StudyConsonant, vowel: StudyVowel) -> some View {
        StudyCard(padding: 8) {
            HStack {
                Text("辅音").font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Picker("辅音", selection: $consonantID) {
                    ForEach(consonants) { item in Text("\(item.glyph) · \(item.label)").tag(item.id) }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
            }
        }
        StudyCard(highlighted: true) {
            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 3) {
                    HebrewText(text: word(consonant, vowel), size: 64, style: .largeTitle)
                    Text("\(roman(consonant, vowel)) · \(ipa(consonant, vowel))")
                        .font(.headline).foregroundStyle(progress.theme.accent)
                    Text("\(vowel.name) · \(vowel.nameZh)").font(.subheadline)
                    Text(vowel.tip).font(.caption).foregroundStyle(progress.theme.mutedInk)
                }
                .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                PronunciationButton(hebrew: word(consonant, vowel), fallback: roman(consonant, vowel), iconOnly: true)
            }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 190 : 98), spacing: 7)], spacing: 7) {
            ForEach(vowels) { item in
                Button {
                    vowelID = item.id
                    audio.speak(word(consonant, item), fallback: roman(consonant, item), rate: progress.speechRate)
                } label: {
                    StudyCard(highlighted: item.id == vowelID, padding: 6) {
                        VStack(spacing: 4) {
                            HebrewText(text: word(consonant, item), size: 31)
                            Text(item.id == "shva" ? "Shva" : roman(consonant, item))
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "speaker.wave.2")
                                .font(.caption).foregroundStyle(progress.theme.accent).accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.nameZh)，\(roman(consonant, item))")
                .accessibilityAddTraits(item.id == vowelID ? .isSelected : [])
            }
        }
        StudyCard {
            DisclosureGroup {
                WordExampleRow(example: StudyExample(hebrew: "סְלִיחָה", transliteration: "slicha", meaning: "对不起",
                                                     note: "词首辅音下的 Shva 在这里静音。"))
                WordExampleRow(example: StudyExample(hebrew: "מְדַבֵּר", transliteration: "medaber", meaning: "说话",
                                                     note: "词首辅音下的 Shva 在这里轻读 /e/。"))
            } label: {
                StudyNotice(title: "Shva · 静音与轻读", symbol: "info.circle", note: "听两个例词，比较 Shva 的读法。")
            }
        }
    }

    @ViewBuilder private func quiz(_ question: Question) -> some View {
        Label("得分 \(correct) / \(total)", systemImage: "star")
            .font(.subheadline.weight(.semibold)).foregroundStyle(progress.theme.mutedInk)
        StudyCard(highlighted: true) {
            StudySectionTitle("听发音，选出对应的音节")
            PronunciationButton(hebrew: word(question.consonant, question.solution), fallback: roman(question.consonant, question.solution),
                                title: "播放题目", prominent: true)
        }
        .id("syllable-question")
        ForEach(Array(question.choices.enumerated()), id: \.offset) { index, vowel in
            StudyAnswerButton(title: word(question.consonant, vowel), submitted: answer != nil,
                              selected: selection == vowel.id, correct: vowel.id == question.solution.id, isHebrew: true,
                              optionLabel: studyOptionLabel(index)) {
                selection = vowel.id
            }
        }
        if let answer {
            let selected = question.choices.first { $0.id == answer }
            StudyQuizFeedback(correct: answer == question.solution.id,
                              solution: word(question.consonant, question.solution),
                              response: selected.map { word(question.consonant, $0) },
                              explanation: question.solution.tip)
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

    private func word(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> String {
        consonant.glyph + vowel.mark + (vowel.suffix ?? "")
    }

    private func roman(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> String {
        if vowel.id == "shva" { return consonant.isSilent == true ? "(e / ∅)" : consonant.roman + "(e)" }
        return consonant.roman + vowel.vowelRoman
    }

    private func ipa(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> String {
        let prefix = consonant.isSilent == true ? "" : consonant.ipa
        return vowel.id == "shva" ? "/\(prefix)(e)/" : "/\(prefix)\(vowel.vowelIpa)/"
    }

    private func next() {
        let core = ["kamatz", "tzere", "chirik", "cholam", "shuruk"]
        let choices = Array(vowels.filter { core.contains($0.id) }.shuffled().prefix(4))
        guard let consonant = consonants.filter({ $0.isSilent != true }).randomElement(),
              let solution = choices.randomElement() else { return }
        question = Question(consonant: consonant, choices: choices, solution: solution)
        selection = nil
        answer = nil
        audio.speak(word(consonant, solution), fallback: roman(consonant, solution), rate: progress.speechRate)
    }
}
