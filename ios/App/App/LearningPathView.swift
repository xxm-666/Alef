import SwiftUI

struct LearningPathEntry: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    var highlighted = true

    var body: some View {
        let completedStages = content.learningPath.filter { isComplete($0) }.count
        let currentStage = content.learningPath.first { !isComplete($0) } ?? content.learningPath.last
        NavigationLink {
            LearningPathView(content: content)
        } label: {
            StudyCard(highlighted: highlighted, padding: 10) {
                StudyRow(
                    title: "零基础入门路线",
                    symbol: "map",
                    subtitle: currentStage.map { "第 \($0.stage) 关 · \(shortTitle($0.title))" } ?? "全部阶段已掌握",
                    value: "\(completedStages) / \(content.learningPath.count)"
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func isComplete(_ stage: StudyPathStage) -> Bool {
        let lettersDone = stage.letterIds.allSatisfy { progress.letterMastery[$0] == .mastered }
        let wordsDone = stage.wordIds.allSatisfy { progress.wordMastery[$0] == .mastered }
        return (!stage.letterIds.isEmpty || !stage.wordIds.isEmpty) && lettersDone && wordsDone
    }

    private func shortTitle(_ title: String) -> String {
        title.components(separatedBy: "：").last ?? title
    }
}

struct LearningPathView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        let summary = overallProgress
        let recommended = content.learningPath.first { !stageProgress($0).isComplete }
        StudyPage {
            StudyCard(highlighted: true) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("8 阶段循序渐进课程")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(progress.theme.accent)
                        Text("已完成 \(summary.completedStages) / \(content.learningPath.count) 关")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(progress.theme.ink)
                    }
                    Spacer(minLength: 0)
                    Text("\(summary.completedItems) / \(summary.totalItems)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(progress.theme.mutedInk)
                }
                ProgressView(value: Double(summary.completedItems), total: Double(max(1, summary.totalItems)))
                    .tint(progress.theme.accent)
                    .accessibilityLabel("入门路线总进度")
                if let recommended {
                    NavigationLink {
                        LearningStageDetailView(stage: recommended, content: content)
                    } label: {
                        Label("继续第 \(recommended.stage) 关", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                }
            }

            ForEach(content.learningPath) { stage in
                stageCard(stage, isRecommended: stage.id == recommended?.id)
            }
        }
        .studyDetail("零基础入门路线")
    }

    private func stageCard(_ stage: StudyPathStage, isRecommended: Bool) -> some View {
        let status = stageProgress(stage)
        return NavigationLink {
            LearningStageDetailView(stage: stage, content: content)
        } label: {
            StudyCard(highlighted: isRecommended, padding: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: status.isComplete ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                        .font(.title3)
                        .foregroundStyle(status.isComplete ? progress.theme.success : (isRecommended ? progress.theme.accent : progress.theme.mutedInk))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(stage.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(progress.theme.ink)
                        Text(stage.subtitle)
                            .font(.caption)
                            .foregroundStyle(progress.theme.accent)
                        Text(stage.goal)
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                        ProgressView(value: Double(status.done), total: Double(max(1, status.total)))
                            .tint(status.isComplete ? progress.theme.success : progress.theme.accent)
                    }
                    Spacer(minLength: 4)
                    Text("\(status.done)/\(status.total)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(progress.theme.mutedInk)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var overallProgress: (completedStages: Int, completedItems: Int, totalItems: Int) {
        var stagesDone = 0
        var itemsDone = 0
        var itemsTotal = 0
        for stage in content.learningPath {
            let status = stageProgress(stage)
            if status.isComplete { stagesDone += 1 }
            itemsDone += status.done
            itemsTotal += status.total
        }
        return (stagesDone, itemsDone, itemsTotal)
    }

    private func stageProgress(_ stage: StudyPathStage) -> (done: Int, total: Int, isComplete: Bool) {
        let lettersDone = stage.letterIds.filter { progress.letterMastery[$0] == .mastered }.count
        let wordsDone = stage.wordIds.filter { progress.wordMastery[$0] == .mastered }.count
        let done = lettersDone + wordsDone
        let total = stage.letterIds.count + stage.wordIds.count
        return (done, total, total > 0 && done == total)
    }
}

private struct LearningStageDetailView: View {
    @Environment(StudyProgress.self) private var progress
    let stage: StudyPathStage
    let content: StudyContent

    private var stageLetters: [StudyLetter] {
        stage.letterIds.compactMap { id in content.letters.first { $0.id == id } }
    }

    private var stageWords: [StudyWord] {
        stage.wordIds.compactMap { id in content.words.first { $0.id == id } }
    }

    private var stageReading: StudyReading? {
        stage.readingId.flatMap { id in content.readings.first { $0.id == id } }
    }

    var body: some View {
        StudyPage {
            StudyCard(highlighted: true) {
                Text(stage.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.theme.accent)
                Text(stage.goal)
                    .font(.subheadline)
                    .foregroundStyle(progress.theme.ink)
                if let nextLetter = stageLetters.first(where: { progress.letterMastery[$0.id] != .mastered }) {
                    Text("下一步 · 学习 \(nextLetter.studyName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress.theme.accent)
                } else if stageWords.contains(where: { progress.wordMastery[$0.id] != .mastered }) {
                    Text("下一步 · 学习本阶高频词")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress.theme.accent)
                }
            }

            if !stageLetters.isEmpty {
                StudySectionTitle("本阶字母（\(stageLetters.count) 个）")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                    ForEach(stageLetters) { letter in
                        letterCard(letter)
                    }
                }
                .environment(\.layoutDirection, progress.alphabetFromRight ? .rightToLeft : .leftToRight)
            }

            StudySectionTitle("配套规则专题")
            NavigationLink {
                StudyRulesView(content: content, topic: stage.ruleTopic)
            } label: {
                StudyCard(padding: 10) {
                    StudyRow(title: ruleTitle(for: stage.ruleTopic),
                             symbol: "list.bullet.rectangle",
                             subtitle: "结合本阶内容掌握发音与构词规律")
                }
            }
            .buttonStyle(.plain)

            if !stageWords.isEmpty {
                StudySectionTitle("本阶高频词（\(stageWords.count) 个）")
                ForEach(stageWords) { word in
                    wordRow(word)
                }
            }

            if let stageReading {
                StudySectionTitle("配套阅读")
                NavigationLink {
                    StudyReadingView(reading: stageReading)
                } label: {
                    StudyCard(padding: 10) {
                        StudyRow(title: stageReading.title, symbol: "text.book.closed",
                                 subtitle: "\(stageReading.sentences.count) 句 · 带点与无点过渡阅读")
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .studyDetail("第 \(stage.stage) 关")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !stageWords.isEmpty {
                StudyActionBar {
                    NavigationLink {
                        WordQuizView(content: content, words: stageWords, kind: .meaning)
                    } label: {
                        Label("本阶单词测验", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                }
            }
        }
    }

    private func letterCard(_ letter: StudyLetter) -> some View {
        let mastery = progress.letterMastery[letter.id] ?? .unlearned
        return NavigationLink {
            LetterStudyView(letter: letter, content: content)
        } label: {
            StudyCard(padding: 8) {
                VStack(spacing: 4) {
                    HebrewText(text: letter.hebrew, size: 34)
                    Text(letter.studyName).font(.caption.weight(.semibold)).foregroundStyle(progress.theme.ink)
                    Image(systemName: mastery.symbol)
                        .font(.caption2)
                        .foregroundStyle(mastery == .unlearned ? progress.theme.mutedInk : progress.theme.accent)
                }
                .frame(maxWidth: .infinity, minHeight: 74)
            }
        }
        .buttonStyle(.plain)
    }

    private func wordRow(_ word: StudyWord) -> some View {
        let mastery = progress.wordMastery[word.id] ?? .unlearned
        return StudyCard(padding: 10) {
            HStack(spacing: 8) {
                NavigationLink {
                    WordDetailView(word: word, content: content)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            HebrewText(text: word.hebrew, size: 28)
                            Text(word.transliteration).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                        }
                        Text(word.meaningZh).font(.subheadline.weight(.medium)).foregroundStyle(progress.theme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Image(systemName: mastery.symbol)
                    .font(.caption)
                    .foregroundStyle(mastery == .unlearned ? progress.theme.mutedInk : progress.theme.accent)
                    .accessibilityLabel(mastery.title)
                PronunciationButton(hebrew: word.hebrew, iconOnly: true)
            }
        }
    }

    private func ruleTitle(for topic: String) -> String {
        switch topic {
        case "niqqud": "元音点 Niqqud"
        case "guttural": "喉音字母发音规则"
        case "sofit": "词尾变形 Sofit"
        case "begadkefat": "达盖什软硬音"
        case "confusable": "易混字母对照辨析"
        case "prefixes": "高频前缀与后缀"
        case "binyanim": "动词词干 Binyanim"
        case "roots": "三辅音词根家族"
        default: "发音与语法规则"
        }
    }
}
