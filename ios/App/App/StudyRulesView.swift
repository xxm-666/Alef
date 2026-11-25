import SwiftUI

struct StudyRulesView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    let topic: String?

    init(content: StudyContent, topic: String? = nil) {
        self.content = content
        self.topic = topic
    }

    private var categories: [(key: String, title: String, symbol: String, subtitle: String, value: String)] {
        [
            ("sofit", "词尾变形", "textformat.abc", "Sofit", "5 组"),
            ("begadkefat", "达盖什", "ellipsis", "Begadkefat", "6 组"),
            ("confusable", "易混字母", "arrow.left.arrow.right", "对照辨析", ""),
            ("guttural", "喉音字母", "headphones", "发音规则", ""),
            ("niqqud", "元音点", "character.cursor.ibeam", "Niqqud", "名称与读音"),
            ("prefixes", "前缀与后缀", "plus.square.on.square", "定冠词、介词与所有格", "\(content.grammarAffixes.count) 组"),
            ("binyanim", "动词词干", "wand.and.stars", "Binyanim 构词规律", "\(content.grammarBinyanim.count) 组"),
            ("roots", "词根家族", "point.3.connected.trianglepath.dotted", "Shoresh 同根词串联", "\(content.rootFamilies().count) 组")
        ]
    }

    var body: some View {
        if let topic, let category = categories.first(where: { $0.key == topic }) {
            ruleDetails(topic, title: category.title)
        } else {
            overview
        }
    }

    private var overview: some View {
        let quickSyllables = [("בַּ", "ba"), ("בִּ", "bi"), ("בֶּ", "be"), ("בֹּ", "bo"), ("בֻּ", "bu")]
        return StudyPage {
            StudyHeading(title: "规则", eyebrow: "RULES & LAB")
            StudyHeroCard(colors: progress.theme.indigoGradient, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("音节合成与听辨")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.20), in: Capsule())
                        Text("拼读实验室")
                            .font(.title3.weight(.bold))
                        Text("点击音节直接试听，或进入完整实验室自由组合")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .accessibilityHidden(true)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(quickSyllables, id: \.0) { syllable, sound in
                            Button {
                                audio.speak(syllable, rate: progress.speechRate, bundledOnly: true)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(syllable)
                                        .font(.system(size: 24, weight: .bold, design: .serif))
                                        .environment(\.layoutDirection, .rightToLeft)
                                    Text(sound)
                                        .font(.caption2.weight(.semibold))
                                        .opacity(0.88)
                                }
                                .foregroundStyle(Color.white)
                                .frame(minWidth: 50, minHeight: 50)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("试听音节 \(sound)")
                        }
                    }
                }
                .scrollIndicators(.hidden)

                NavigationLink {
                    StudySyllablesView(consonants: content.consonants, vowels: content.vowels)
                } label: {
                    HStack(spacing: 6) {
                        Text("进入完整拼读实验室")
                            .font(.subheadline.weight(.bold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(progress.theme.primaryButton)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            let groups = [("字形与发音", categories.prefix(5)), ("构词与语法", categories.dropFirst(5))]
            ForEach(groups, id: \.0) { title, rules in
                StudySectionTitle(title)
                StudyCard(padding: 10, spacing: 2) {
                    ForEach(rules, id: \.0) { key, title, symbol, subtitle, count in
                        if key != rules.first?.key { Divider() }
                        NavigationLink {
                            StudyRulesView(content: content, topic: key)
                        } label: {
                            StudyRow(title: title, symbol: symbol, subtitle: subtitle,
                                     value: count.isEmpty ? nil : count,
                                     badgeColors: ruleBadgeColors(for: key))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .studyHome()
    }

    private func ruleBadgeColors(for key: String) -> [Color] {
        switch key {
        case "sofit", "niqqud": progress.theme.heroGradient
        case "begadkefat", "binyanim": progress.theme.indigoGradient
        case "confusable", "guttural": progress.theme.warmGradient
        default: [progress.theme.success, progress.theme.accent]
        }
    }

    @ViewBuilder private func ruleDetails(_ category: String, title: String) -> some View {
        if category == "sofit" {
            StudySofitView(content: content)
                .onAppear { progress.write(category, for: "alef.rulesTab.v1") }
        } else if category == "prefixes" {
            GrammarAffixesView(content: content)
                .onAppear { progress.write(category, for: "alef.rulesTab.v1") }
        } else if category == "binyanim" {
            GrammarBinyanimView(content: content)
                .onAppear { progress.write(category, for: "alef.rulesTab.v1") }
        } else if category == "roots" {
            RootDirectoryView(content: content)
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
                    PronunciationButton(hebrew: item.nameHebrew, iconOnly: true,
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
                        variant("带达盖什", pair.withDagesh, pair: pair)
                        variant("不带达盖什", pair.withoutDagesh, pair: pair)
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

    private func variant(_ title: String, _ value: StudyDagesh.Variant, pair: StudyDagesh) -> some View {
        let sample = pair.modernExample(for: value)
        return VStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            HebrewText(text: value.glyph, size: 43)
            Text("现代 \(value.modernIpa)")
            Text("古典 \(value.biblicalIpa)").font(.footnote).foregroundStyle(progress.theme.mutedInk)
            PronunciationButton(hebrew: sample, title: "听现代音节 \(sample)", bundledOnly: true)
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

private struct GrammarAffixesView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    @State private var kind = "prefix"

    var body: some View {
        let items = content.grammarAffixes.filter { $0.kind == kind }
        StudyPage {
            StudySegments(title: "词缀类型", options: [("prefix", "高频前缀"), ("suffix", "后缀与结构")], selection: $kind)
            StudyNotice(title: kind == "prefix" ? "希伯来语单字母前缀直接贴在词首" : "人称所有格、复数与构造态是阅读高频结构",
                        symbol: "info.circle")
            ForEach(items) { item in
                affixCard(item)
            }
        }
        .studyDetail("前缀与后缀")
    }

    private func affixCard(_ item: StudyGrammarAffix) -> some View {
        StudyCard {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HebrewText(text: item.hebrew, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.meaning).font(.headline).foregroundStyle(progress.theme.ink)
                    Text(item.transliteration).font(.caption.weight(.medium)).foregroundStyle(progress.theme.mutedInk)
                }
            }
            Text(item.rule).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
            Divider()
            ForEach(Array(item.examples.enumerated()), id: \.offset) { _, example in
                affixExampleRow(example)
            }
        }
    }

    private func affixExampleRow(_ example: StudyGrammarAffix.Example) -> some View {
        let linkedWord = example.wordId.flatMap { id in content.words.first { $0.id == id } }
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HebrewText(text: example.hebrew, size: 24)
                Text("\(example.transliteration) · \(example.meaning)")
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
            }
            Spacer(minLength: 0)
            if let linkedWord {
                NavigationLink {
                    WordDetailView(word: linkedWord, content: content)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(progress.theme.accent)
                .accessibilityLabel("查看基础词 \(linkedWord.meaningZh)")
            }
            PronunciationButton(hebrew: example.hebrew, iconOnly: true, title: "朗读 \(example.meaning)")
        }
    }
}

private struct GrammarBinyanimView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        StudyPage {
            StudyNotice(title: "Binyanim（动词词干系统）", symbol: "wand.and.stars",
                        note: "希伯来语动词把 3 个辅音词根填进不同“词干模具”，就能系统表达主动、强化、使动、反身或被动含义。")
            ForEach(content.grammarBinyanim) { binyan in
                binyanCard(binyan)
            }
        }
        .studyDetail("动词词干")
    }

    private func binyanCard(_ binyan: StudyGrammarBinyan) -> some View {
        let examples = binyan.exampleWordIds.compactMap { id in content.words.first { $0.id == id } }
        return StudyCard {
            HStack(alignment: .firstTextBaseline) {
                HebrewText(text: binyan.nameHebrew, size: 28)
                Spacer(minLength: 8)
                Text("\(binyan.nameEnglish) · \(binyan.role)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.accent)
            }
            LabeledContent("骨架模板", value: binyan.pattern).font(.subheadline)
            LabeledContent("现在时标志", value: binyan.presentPrefix).font(.subheadline)
            StudyNotice(title: binyan.tip, symbol: "lightbulb")
            if !examples.isEmpty {
                Divider()
                ForEach(examples) { word in
                    HStack {
                        NavigationLink {
                            WordDetailView(word: word, content: content)
                        } label: {
                            StudyRow(title: word.hebrew, symbol: "book", subtitle: "\(word.transliteration) · \(word.meaningZh)")
                        }
                        .buttonStyle(.plain)
                        PronunciationButton(hebrew: word.hebrew, iconOnly: true)
                    }
                }
            }
        }
    }
}

private struct RootDirectoryView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    @State private var query = ""

    var body: some View {
        let families = filteredFamilies
        StudyPage {
            StudyNotice(title: "Shoresh（三辅音词根）", symbol: "point.3.connected.trianglepath.dotted",
                        note: "同一组词根辅音会衍生出大量相关名词与动词。记住词根，能成串扩展词汇。")
            if families.isEmpty {
                ContentUnavailableView("没有匹配的词根", systemImage: "magnifyingglass")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(families, id: \.root) { family in
                        NavigationLink {
                            RootFamilyView(root: family.root, content: content)
                        } label: {
                            StudyCard(padding: 10) {
                                StudyRow(
                                    title: family.root,
                                    symbol: "point.3.connected.trianglepath.dotted",
                                    subtitle: family.words.prefix(3).map(\.meaningZh).joined(separator: "、"),
                                    value: "\(family.words.count) 词"
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .studyDetail("词根家族")
        .searchable(text: $query, prompt: "搜索词根或关联词义")
    }

    private var filteredFamilies: [(root: String, words: [StudyWord])] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = content.rootFamilies()
        guard !trimmed.isEmpty else { return all }
        return all.filter { family in
            family.root.localizedCaseInsensitiveContains(trimmed)
                || family.words.contains {
                    $0.meaningZh.localizedCaseInsensitiveContains(trimmed)
                        || $0.hebrewUnpointed.contains(trimmed)
                        || $0.transliteration.localizedCaseInsensitiveContains(trimmed)
                }
        }
    }
}

struct RootFamilyView: View {
    @Environment(StudyProgress.self) private var progress
    let root: String
    let content: StudyContent

    var body: some View {
        let familyWords = content.words(withRoot: root)
        StudyPage {
            StudyCard(highlighted: true) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("三辅音词根").font(.caption.weight(.semibold)).foregroundStyle(progress.theme.accent)
                        HebrewText(text: root, size: 38)
                    }
                    Spacer(minLength: 0)
                    Text("共 \(familyWords.count) 个关联词")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress.theme.mutedInk)
                }
                Text("观察这些词如何共享相同的核心辅音骨架，通过改变元音和前缀表达不同词性与含义。")
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
            }
            ForEach(familyWords) { word in
                StudyCard(padding: 10) {
                    HStack(spacing: 8) {
                        NavigationLink {
                            WordDetailView(word: word, content: content)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    HebrewText(text: word.hebrew, size: 28)
                                    Text(word.transliteration).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                                }
                                Text("\(word.meaningZh) · \(word.partOfSpeech)")
                                    .font(.subheadline)
                                    .foregroundStyle(progress.theme.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        PronunciationButton(hebrew: word.hebrew, iconOnly: true)
                    }
                }
            }
        }
        .studyDetail("词根 · \(root)")
    }
}

private struct StudySyllablesView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var previewCardHeight: CGFloat = 196
    @ScaledMetric(relativeTo: .body) private var previewGlyphHeight: CGFloat = 84
    @ScaledMetric(relativeTo: .body) private var tileHeight: CGFloat = 84
    @ScaledMetric(relativeTo: .body) private var tileGlyphHeight: CGFloat = 40
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
    @State private var answerRun = StudyAnswerRun()

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
        .studyAnswerCelebration(answerRun.celebration)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if quizzing, let question {
                StudyActionBar {
                    Button {
                        if answer != nil { next() }
                        else if let selection { grade(selection, solution: question.solution.id) }
                    } label: {
                        Label(answer == nil ? "确认答案" : "下一题", systemImage: answer == nil ? "checkmark" : "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(learningAction: true))
                    .disabled(answer == nil && selection == nil)
                }
            }
        }
        .onChange(of: quizzing) { _, active in
            answerRun = StudyAnswerRun()
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
            VStack(spacing: 4) {
                HebrewText(text: word(consonant, vowel), size: 64, style: .largeTitle)
                    .frame(height: typeSize.isAccessibilitySize ? nil : previewGlyphHeight)
                Text("\(roman(consonant, vowel)) · \(ipa(consonant, vowel))")
                    .font(.headline)
                    .foregroundStyle(progress.theme.accent)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(0.85)
                Text("\(vowel.name) · \(vowel.nameZh)")
                    .font(.subheadline)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(0.85)
                Text(vowel.tip)
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3, reservesSpace: !typeSize.isAccessibilitySize)
                    .minimumScaleFactor(0.88)
                    .padding(.horizontal, 4)
                if typeSize.isAccessibilitySize && vowel.id != "shva" {
                    PronunciationButton(hebrew: word(consonant, vowel), iconOnly: true, bundledOnly: true)
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity,
                   minHeight: previewCardHeight,
                   maxHeight: typeSize.isAccessibilitySize ? nil : previewCardHeight,
                   alignment: .center)
            .overlay(alignment: .topTrailing) {
                if !typeSize.isAccessibilitySize && vowel.id != "shva" {
                    PronunciationButton(hebrew: word(consonant, vowel), iconOnly: true, bundledOnly: true)
                }
            }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 190 : 98), spacing: 7)], spacing: 7) {
            ForEach(vowels) { item in
                let selected = item.id == vowelID
                Button {
                    vowelID = item.id
                    if item.id != "shva" {
                        audio.speak(word(consonant, item), rate: progress.speechRate, bundledOnly: true)
                    }
                } label: {
                    StudyCard(highlighted: selected, padding: 6) {
                        VStack(spacing: 4) {
                            HebrewText(text: word(consonant, item), size: 31)
                                .frame(height: typeSize.isAccessibilitySize ? nil : tileGlyphHeight)
                            Text(item.id == "shva" ? "Shva" : roman(consonant, item))
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Image(systemName: item.id == "shva" ? "info.circle" : "speaker.wave.2")
                                .font(.caption).foregroundStyle(progress.theme.accent).accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity,
                               minHeight: tileHeight,
                               maxHeight: typeSize.isAccessibilitySize ? nil : tileHeight)
                        .contentShape(Rectangle())
                    }
                    .overlay {
                        if selected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(progress.theme.accent.opacity(0.65), lineWidth: 1.5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.nameZh)，\(roman(consonant, item))")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        StudyCard {
            DisclosureGroup {
                WordExampleRow(example: StudyExample(hebrew: "סְלִיחָה", transliteration: "slicha", meaning: "对不起",
                                                     note: "词首辅音下的 Shva 在这里静音。"), bundledOnly: true)
                WordExampleRow(example: StudyExample(hebrew: "מְדַבֵּר", transliteration: "medaber", meaning: "说话",
                                                     note: "词首辅音下的 Shva 在这里轻读 /e/。"), bundledOnly: true)
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
            PronunciationButton(hebrew: word(question.consonant, question.solution),
                                title: "播放题目", prominent: true, bundledOnly: true)
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
                              explanation: question.solution.tip, combo: answerRun.combo)
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
        answerRun.record(correct: success, in: progress)
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
        answerRun.clearCelebration()
        let core = ["kamatz", "tzere", "chirik", "cholam", "shuruk"]
        let choices = Array(vowels.filter { core.contains($0.id) }.shuffled().prefix(4))
        guard let consonant = consonants.filter({ $0.isSilent != true }).randomElement(),
              let solution = choices.randomElement() else { return }
        question = Question(consonant: consonant, choices: choices, solution: solution)
        selection = nil
        answer = nil
        audio.speak(word(consonant, solution), rate: progress.speechRate, bundledOnly: true)
    }
}
