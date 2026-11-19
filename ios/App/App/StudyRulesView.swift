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
        default:
            List {
                switch category {
                case "sofit": Text("כ · מ · נ · פ · צ 位于词尾时写作 ך · ם · ן · ף · ץ。")
                case "begadkefat": Text("现代希伯来语中，בּ / ב、כּ / כ 和 פּ / פ 保留带点和不带点的读音区别。")
                default: Text("א、ה、ח、ע 是喉音，ר 常具有相似的语法特性。")
                }
                ForEach(content.letters.filter { letter in
                    letter.categories.contains(category) || (category == "guttural" && letter.id == "resh")
                }) { letter in
                    letterLink(letter)
                }
            }
        }
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
    let consonants: [StudyConsonant]
    let vowels: [StudyVowel]
    @State private var consonantID = "bet"
    @State private var quizzing = false
    @State private var question: StudyVowel?
    @State private var answer: String?
    @State private var correct = 0
    @State private var total = 0

    var body: some View {
        List {
            Picker("辅音", selection: $consonantID) {
                ForEach(consonants) { item in Text("\(item.glyph) · \(item.label)").tag(item.id) }
            }
            Toggle("进入测验", isOn: $quizzing)
            if let consonant = consonants.first(where: { $0.id == consonantID }) {
                if quizzing, let question {
                    Section("得分 \(correct) / \(total)") {
                        HebrewText(text: word(consonant, question), size: 56)
                        PronunciationButton(hebrew: word(consonant, question), fallback: roman(consonant, question))
                        ForEach(vowels) { vowel in
                            Button(vowel.name) {
                                answer = vowel.id
                                total += 1
                                if vowel.id == question.id { correct += 1 }
                                progress.recordStudy()
                            }
                            .disabled(answer != nil)
                        }
                        if let answer {
                            Text(answer == question.id ? "答对了" : "正确答案：\(question.name)")
                            Button("下一题", action: next)
                        }
                    }
                } else {
                    Section("辅音与元音组合") {
                        ForEach(vowels) { vowel in
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    HebrewText(text: word(consonant, vowel), size: 37)
                                    Text("\(vowel.name) · \(vowel.nameZh)").font(.subheadline)
                                    Text(roman(consonant, vowel)).foregroundStyle(.secondary)
                                    Text(vowel.tip).font(.footnote)
                                }
                                Spacer()
                                PronunciationButton(hebrew: word(consonant, vowel), fallback: roman(consonant, vowel), iconOnly: true)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: quizzing) { _, active in if active { next() } }
        .onChange(of: consonantID) { _, _ in if quizzing { next() } }
    }

    private func word(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> String {
        consonant.glyph + vowel.mark + (vowel.suffix ?? "")
    }

    private func roman(_ consonant: StudyConsonant, _ vowel: StudyVowel) -> String {
        consonant.roman + (vowel.id == "shva" ? "(e)" : vowel.vowelRoman)
    }

    private func next() {
        question = vowels.filter { $0.id != question?.id }.randomElement() ?? vowels.first
        answer = nil
    }
}
