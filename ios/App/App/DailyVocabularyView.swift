import SwiftUI

struct DailyVocabularyEntry: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let plan = progress.dailyVocabularyPlan(words: content.words, date: timeline.date)
            let status = plan.groups.isEmpty ? "暂无待学新词" : "已完成 \(plan.completedCount) / \(plan.groups.count) 组"
            NavigationLink {
                DailyVocabularyView(content: content)
            } label: {
                StudyCard(highlighted: true, padding: 10) {
                    StudyRow(title: "今日记词", symbol: "calendar.badge.checkmark",
                             subtitle: plan.nextGroup.map { "\(status) · \($0.status)" } ?? status)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(plan.nextGroup?.hasStarted == true ? "继续记词" : "查看今日计划")
        }
    }
}

private struct DailyVocabularyView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.scenePhase) private var scenePhase
    let content: StudyContent
    @State private var activeId: String?
    @State private var revealed = false
    @State private var spelling = ""

    private var plan: DailyVocabularyPlan { progress.dailyVocabulary }
    private var activeIndex: Int? { plan.groups.firstIndex(where: { $0.id == activeId }) }

    var body: some View {
        let current = plan
        let index = activeIndex
        let group = index.map { current.groups[$0] }
        ScrollViewReader { scroll in
            StudyPage {
                if let group, let index {
                    StudySectionTitle("第 \(index + 1) 组").id("daily-question")
                    groupContent(group)
                } else {
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        let today = progress.dailyVocabularyPlan(words: content.words, date: timeline.date)
                        planContent(today)
                            .onChange(of: today.day, initial: true) { _, _ in
                                progress.prepareDailyVocabulary(words: content.words)
                            }
                    }
                }
            }
            .onChange(of: group?.studied) { _, _ in scroll.scrollTo("daily-question", anchor: .top) }
            .onChange(of: group?.feedbackPending) { _, pending in
                scroll.scrollTo(pending == true ? "daily-feedback" : "daily-question", anchor: pending == true ? .bottom : .top)
            }
            .onChange(of: activeId) { _, _ in scroll.scrollTo("daily-question", anchor: .top) }
        }
        .studyDetail("今日记词")
        .toolbar {
            if group != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今日计划") { openGroup(nil) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let group, !group.isComplete, let word = currentWord(group) {
                StudyActionBar { groupAction(group, word: word, day: current.day) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && activeIndex == nil {
                progress.prepareDailyVocabulary(words: content.words)
            }
        }
        .onDisappear { audio.stop() }
    }

    private func planContent(_ today: DailyVocabularyPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            StudyCard {
                StudySectionTitle("今日计划")
                Text("每组最多 \(DailyVocabularyPlan.groupSize) 词，先认读，再拼写。")
                    .font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                meter("已完成 \(today.completedCount) / \(today.groups.count) 组",
                      value: today.completedCount, total: today.groups.count, label: "今日分组进度")
                if today.groups.isEmpty {
                    Text("暂无待学新词。已安排过的单词可在到期复习中巩固。")
                        .font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                }
                ForEach(Array(today.groups.enumerated()), id: \.element.id) { index, group in
                    Divider()
                    groupRow(group, index: index, completed: today.completedCount)
                }
                if today.completedCount > 0 && today.completedCount == today.groups.count {
                    Label("今日新词已完成，明天接着学。", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(progress.theme.accent)
                }
            }
            StudyCard {
                StudySectionTitle("每日新词分组")
                if today.hasStarted {
                    Text("今天已开始，调整从明天生效。")
                        .font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                }
                StudySegments(title: "每日新词分组",
                              options: DailyVocabularyPlan.groupOptions.map { ($0, "\($0) 组") },
                              selection: Binding(get: { progress.dailyVocabulary.groupsPerDay },
                                                 set: { progress.setDailyVocabularyLimit($0, words: content.words) }))
            }
        }
    }

    private func groupRow(_ group: DailyVocabularyGroup, index: Int, completed: Int) -> some View {
        let title = "第 \(index + 1) 组 · \(group.wordIds.count) 词"
        let action = group.isComplete ? "查看结果" : group.hasStarted ? "继续" : "开始"
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                groupRowLabel(title, status: group.status)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                groupRowAction(group, index: index, completed: completed, action: action)
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 6) {
                groupRowLabel(title, status: group.status)
                groupRowAction(group, index: index, completed: completed, action: action)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupRowLabel(_ title: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(status).font(.caption).foregroundStyle(progress.theme.mutedInk)
        }
    }

    @ViewBuilder private func groupRowAction(_ group: DailyVocabularyGroup, index: Int, completed: Int, action: String) -> some View {
        if index <= completed {
            Button(action) {
                progress.prepareDailyVocabulary(words: content.words)
                openGroup(group.id)
            }
            .buttonStyle(StudyButtonStyle(prominent: index == completed))
            .accessibilityLabel("第 \(index + 1) 组 · \(action)")
        } else {
            Text("上一组完成后开始").font(.caption).foregroundStyle(progress.theme.mutedInk)
        }
    }

    @ViewBuilder private func groupContent(_ group: DailyVocabularyGroup) -> some View {
        if group.isComplete {
            StudyQuizSummary(title: "本组完成", correct: group.correctCount, answered: group.wordIds.count)
            if group.correctCount < group.wordIds.count {
                StudyCard {
                    StudySectionTitle("待巩固的词")
                    Text("拼错的词已安排到期复习。").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    ForEach(Array(group.wordIds.enumerated()), id: \.element) { offset, id in
                        if !group.answers[offset].correct, let word = word(id) {
                            Divider()
                            HStack(spacing: 10) {
                                HebrewText(text: word.hebrew, size: 24)
                                Spacer(minLength: 4)
                                Text(word.meaningZh).font(.subheadline)
                            }
                        }
                    }
                }
            }
            let next = plan.nextGroup
            primaryButton(next == nil ? "返回今日计划" : "开始下一组", symbol: "arrow.right") { openGroup(next?.id) }
        } else if let word = currentWord(group) {
            let total = group.wordIds.count
            if group.studied < total {
                meter("认读 · 第 \(group.studied + 1) / \(total) 词", value: group.studied, total: total, label: "认读进度")
                wordCard(word)
            } else {
                let index = group.answers.count - (group.feedbackPending ? 1 : 0)
                meter("拼写 · 第 \(index + 1) / \(total) 词", value: group.answers.count, total: total, label: "拼写进度")
                StudyCard {
                    StudySectionTitle("写出「\(word.meaningZh)」")
                    Text("提示 · \(word.transliteration)").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    Text("可输入带点写法或无点全拼").font(.caption).foregroundStyle(progress.theme.mutedInk)
                }
                let answer = group.feedbackPending ? group.answers.last : nil
                WordSpellingInput(content: content, wordId: word.id, spelling: Binding(
                    get: { answer?.input ?? spelling }, set: { spelling = $0 }
                ), submitted: answer != nil) { submit(group, word: word, day: plan.day) }
                if let answer {
                    VStack(alignment: .leading, spacing: 8) {
                        StudyQuizFeedback(correct: answer.correct, solution: "\(word.hebrew) · \(word.hebrewUnpointed)",
                                          response: answer.input)
                        PronunciationButton(hebrew: word.hebrew, title: "听正确发音")
                    }
                    .id("daily-feedback")
                }
            }
        }
    }

    private func wordCard(_ word: StudyWord) -> some View {
        StudyCard {
            VStack(spacing: 10) {
                HebrewText(text: word.hebrew, size: 52, style: .largeTitle)
                PronunciationButton(hebrew: word.hebrew, title: "听发音")
                if revealed {
                    Text(word.meaningZh).font(.title3.bold())
                    Text(word.transliteration).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                } else {
                    Text("先回想词义，再翻看答案。").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private func groupAction(_ group: DailyVocabularyGroup, word: StudyWord, day: String) -> some View {
        let total = group.wordIds.count
        if group.studied < total {
            if revealed {
                primaryButton(group.studied + 1 == total ? "开始本组拼写" : "下一词", symbol: "arrow.right") {
                    advance(group, day: day)
                }
            } else {
                primaryButton("显示释义", symbol: "eye") { revealed = true }
            }
        } else if group.feedbackPending {
            primaryButton(group.answers.count == total ? "查看本组结果" : "下一题", symbol: "arrow.right") {
                advance(group, day: day)
            }
        } else {
            primaryButton("确认答案", symbol: "checkmark") { submit(group, word: word, day: day) }
                .disabled(spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func meter(_ title: String, value: Int, total: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline.weight(.semibold)).monospacedDigit()
            if total > 0 {
                ProgressView(value: Double(value), total: Double(total))
                    .tint(progress.theme.accent)
                    .accessibilityLabel(label)
            }
        }
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(prominent: true))
    }

    private func currentWord(_ group: DailyVocabularyGroup) -> StudyWord? {
        let index = group.studied < group.wordIds.count ? group.studied : group.answers.count - (group.feedbackPending ? 1 : 0)
        guard group.wordIds.indices.contains(index) else { return nil }
        return word(group.wordIds[index])
    }

    private func word(_ id: String) -> StudyWord? {
        content.words.first { $0.id == id }
    }

    private func openGroup(_ id: String?) {
        if id == nil { progress.prepareDailyVocabulary(words: content.words) }
        audio.stop()
        activeId = id
        revealed = false
        spelling = ""
    }

    private func advance(_ group: DailyVocabularyGroup, day: String) {
        guard progress.advanceDailyVocabulary(group, day: day) else { return }
        audio.stop()
        revealed = false
        spelling = ""
    }

    private func submit(_ group: DailyVocabularyGroup, word: StudyWord, day: String) {
        guard let answer = progress.answerDailyVocabulary(group, day: day, word: word, input: spelling) else { return }
        audio.playFeedback(answer.correct ? .correct : .wrong)
    }
}
