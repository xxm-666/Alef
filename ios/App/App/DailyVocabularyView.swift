import SwiftUI
import UIKit

struct DailyVocabularyEntry: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    var emphasized = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let plan = progress.dailyVocabularyPlan(words: content.dailyVocabularyWords(in: progress, at: timeline.date), date: timeline.date)
            let activePack = progress.dailyVocabularyPackId.flatMap { content.wordPack(id: $0) }
            let status = activePack == nil ? "请先选取学习词包" : (plan.groups.isEmpty ? "暂无待学新词" : "已完成 \(plan.completedCount) / \(plan.groups.count) 组")
            NavigationLink {
                DailyVocabularyView(content: content)
            } label: {
                let packPrefix = activePack.map { "\($0.shortTitle) · " } ?? ""
                let summary = activePack == nil ? status : packPrefix + (plan.nextGroup.map { "\(status) · \($0.status)" } ?? status)
                if emphasized {
                    StudyHeroCard(colors: progress.theme.warmGradient, padding: 14, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("今日记词")
                                    .font(.headline.weight(.bold))
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.title2)
                                .accessibilityHidden(true)
                        }
                        if !plan.groups.isEmpty {
                            HStack(spacing: 5) {
                                ForEach(Array(plan.groups.enumerated()), id: \.element.id) { _, group in
                                    Capsule()
                                        .fill(group.isComplete ? Color.white : Color.white.opacity(0.28))
                                        .frame(height: 5)
                                }
                            }
                            .accessibilityHidden(true)
                        }
                    }
                } else {
                    StudyCard(padding: 12) {
                        StudyRow(title: "今日记词", symbol: "calendar.badge.checkmark", subtitle: summary,
                                 badgeColors: progress.theme.warmGradient)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(plan.nextGroup?.hasStarted == true ? "继续记词" : "查看今日计划")
        }
    }
}

private struct DailyVocabularyView: View {
    private enum ScrollTarget: Hashable {
        case question, feedback
    }

    private struct ChoiceQuestion: Equatable {
        let groupWordIDs: [String]
        let round: Int
        let position: Int
        let wordID: String
    }

    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @State private var activeId: String?
    @State private var browsingIndex: Int?
    @State private var choiceOptions: (question: ChoiceQuestion, words: [StudyWord])?
    @State private var spelling = ""
    @State private var retryingMistake = false
    @State private var retryMatched = false
    @State private var retryComparison: SpellingComparison?
    @State private var celebration: StudyAnswerCelebration?
    @State private var reviewingGroup: DailyVocabularyGroup?
    @State private var showsPackPicker = false

    private var plan: DailyVocabularyPlan { progress.dailyVocabulary }
    var body: some View {
        let current = plan
        let index = current.groups.firstIndex { $0.id == activeId }
        let group = index.map { current.groups[$0] }

        scrollingPage(group: group, index: index, day: current.day)
            .studyDetail("今日记词")
            .studyAnswerCelebration(celebration)
            .toolbar {
                if group != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("今日计划") { openGroup(nil) }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("每日新词分组", systemImage: "slider.horizontal.3") {
                            Picker("每日新词分组", selection: groupsPerDay) {
                                ForEach(DailyVocabularyPlan.groupOptions, id: \.self) { count in
                                    Text("\(count) 组").tag(count)
                                }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar(group: group, day: current.day)
            }
            .sheet(item: $reviewingGroup, onDismiss: { audio.stop() }) { group in
                groupWordReview(group)
            }
            .sheet(isPresented: $showsPackPicker) {
                NavigationStack {
                    DailyVocabularyPackPickerSheet(content: content) { selectedPackId in
                        let newWords = content.dailyVocabularyWords(in: progress, packId: selectedPackId)
                        progress.setDailyVocabularyPack(selectedPackId, words: newWords)
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .background {
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    Color.clear.onChange(of: DailyVocabularyPlan.dayKey(for: timeline.date), initial: true) { _, _ in
                        progress.prepareDailyVocabulary(words: content.dailyVocabularyWords(in: progress))
                    }
                }
                .accessibilityHidden(true)
            }
            .onChange(of: group, initial: true) { _, current in
                updateChoiceOptions(for: current)
            }
            .onChange(of: plan.groups.map(\.wordIds)) { _, _ in
                progress.prepareDailyVocabulary(words: content.dailyVocabularyWords(in: progress))
            }
            .onChange(of: progress.dailyVocabularyPackId) { _, _ in
                progress.prepareDailyVocabulary(words: content.dailyVocabularyWords(in: progress))
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    progress.prepareDailyVocabulary(words: content.dailyVocabularyWords(in: progress))
                }
            }
            .onDisappear { audio.stop() }
    }

    private func scrollingPage(group: DailyVocabularyGroup?, index: Int?, day: String) -> some View {
        ScrollViewReader { scroll in
            studyPage(group: group, index: index, day: day)
                .onChange(of: group?.studied) { _, _ in
                    scroll.scrollTo(ScrollTarget.question, anchor: .top)
                }
                .onChange(of: browsingIndex) { _, _ in
                    scroll.scrollTo(ScrollTarget.question, anchor: .top)
                }
                .onChange(of: group?.choices?.answered) { _, _ in
                    scroll.scrollTo(ScrollTarget.question, anchor: .top)
                }
                .onChange(of: group?.choices?.selectedWordID) { _, selection in
                    if selection != nil {
                        scroll.scrollTo(ScrollTarget.feedback, anchor: .bottom)
                    }
                }
                .onChange(of: group?.answers.count) { _, _ in
                    if group?.feedbackPending == false {
                        scroll.scrollTo(ScrollTarget.question, anchor: .top)
                    }
                }
                .onChange(of: group?.feedbackPending) { _, pending in
                    if pending == true {
                        scroll.scrollTo(ScrollTarget.feedback, anchor: .bottom)
                    } else {
                        scroll.scrollTo(ScrollTarget.question, anchor: .top)
                    }
                }
                .onChange(of: retryComparison) { _, comparison in
                    if comparison != nil {
                        scroll.scrollTo(ScrollTarget.feedback, anchor: .bottom)
                    }
                }
                .onChange(of: activeId) { _, _ in
                    scroll.scrollTo(ScrollTarget.question, anchor: .top)
                }
        }
    }

    private func studyPage(group: DailyVocabularyGroup?, index: Int?, day: String) -> some View {
        StudyPage {
            if let group, let index {
                let title: String = "第 \(index + 1) 组"
                StudySectionTitle(title)
                    .id(ScrollTarget.question)
                groupContent(group, day: day)
            } else {
                planTimeline
            }
        }
    }

    private var planTimeline: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let today = progress.dailyVocabularyPlan(words: content.dailyVocabularyWords(in: progress, at: timeline.date), date: timeline.date)
            planContent(today)
        }
    }

    @ViewBuilder private func actionBar(group: DailyVocabularyGroup?, day: String) -> some View {
        if let group, !group.isComplete, let word = currentWord(group),
           group.choiceStage == nil || group.choices?.selectedWordID != nil {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            StudyActionBar {
                if group.studied < group.wordIds.count {
                    let displayedIndex = studyWordIndex(for: group)
                    layout {
                        Button {
                            stepPrevious(group)
                        } label: {
                            Label("上一词", systemImage: "arrow.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudyButtonStyle())
                        .disabled(displayedIndex == 0)

                        groupAction(group, word: word, day: day)
                    }
                } else if group.choiceStage != nil {
                    primaryButton("下一题", symbol: "arrow.right") {
                        advance(group, day: day)
                    }
                } else if group.feedbackPending {
                    let answer = group.answers.last
                    if let answer, !answer.correct, !retryingMistake {
                        layout {
                            Button {
                                audio.stop()
                                retryingMistake = true
                                retryMatched = false
                                retryComparison = nil
                                spelling = ""
                            } label: {
                                Label("再拼一次", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(StudyButtonStyle())
                            groupAction(group, word: word, day: day)
                        }
                    } else if retryingMistake && !retryMatched {
                        layout {
                            PronunciationButton(hebrew: word.hebrew, title: "听发音")
                            primaryButton("核对订正", symbol: "checkmark") { checkMistakeRetry(word: word) }
                                .disabled(spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        layout {
                            reviewWordsButton(group)
                            groupAction(group, word: word, day: day)
                        }
                    }
                } else {
                    layout {
                        reviewWordsButton(group, markSpellingHint: true)
                        groupAction(group, word: word, day: day)
                    }
                }
            }
        }
    }

    private func planContent(_ today: DailyVocabularyPlan) -> some View {
        let activePack = progress.dailyVocabularyPackId.flatMap { content.wordPack(id: $0) }
        let remaining = today.remainingNewWordIds(from: content.dailyVocabularyWords(in: progress),
                                                  mastery: progress.wordMastery,
                                                  schedule: progress.schedule)
        let canAddGroup = activePack != nil && today.groups.count < DailyVocabularyPlan.maxGroupsPerDay && !remaining.isEmpty
        return VStack(alignment: .leading, spacing: 16) {
            if let activePack {
                StudyCard(padding: 12) {
                    Button {
                        showsPackPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: activePack.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(progress.theme.accent)
                                .frame(width: 36, height: 36)
                                .background(progress.theme.highlightedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("学习词包 · \(activePack.title)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(progress.theme.ink)
                                Text("剩余 \(remaining.count) 个未学新词 · 点按切换（独立于内容页）")
                                    .font(.caption)
                                    .foregroundStyle(progress.theme.mutedInk)
                                    .monospacedDigit()
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(progress.theme.mutedInk)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                StudyCard(highlighted: true) {
                    ContentUnavailableView {
                        Label("尚未选择学习词包", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("请先选取一个单词包作为今日学习来源。此处选择独立于内容页的固定词包。")
                    } actions: {
                        Button("选择学习词包") {
                            showsPackPicker = true
                        }
                        .buttonStyle(StudyButtonStyle(prominent: true))
                    }
                }
            }
            if activePack != nil || !today.groups.isEmpty {
                StudyCard {
                    StudySectionTitle("今日计划")
                    Text(activePack.map { "当前从「\($0.title)」优先选取未学高频词，每组最多 \(DailyVocabularyPlan.groupSize) 词。" }
                         ?? "当前未选定新词包，以下保留今日已开始的分组。")
                        .font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    meter("已完成 \(today.completedCount) / \(today.groups.count) 组",
                          value: today.completedCount, total: today.groups.count, label: "今日分组进度")
                    if today.groups.isEmpty {
                        Text("该词包暂无待学新词，可切换其他单词包或在到期复习中巩固。")
                            .font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    }
                    ForEach(Array(today.groups.enumerated()), id: \.element.id) { index, group in
                        Divider()
                        groupRow(group, index: index, nextGroupID: today.nextGroup?.id)
                    }
                    if today.completedCount > 0 && today.completedCount == today.groups.count {
                        Label("今日计划已完成，可继续加学或重练任意一组。", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(progress.theme.accent)
                    }
                    if canAddGroup {
                        Divider()
                        Button {
                            addExtraGroup()
                        } label: {
                            Label("加学一组新词", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudyButtonStyle(prominent: today.nextGroup == nil))
                    }
                }
            }
        }
    }

    private var groupsPerDay: Binding<Int> {
        Binding(get: { progress.dailyVocabulary.groupsPerDay },
                set: { progress.setDailyVocabularyLimit($0, words: content.dailyVocabularyWords(in: progress)) })
    }

    private func groupRow(_ group: DailyVocabularyGroup, index: Int, nextGroupID: String?) -> some View {
        let title = "第 \(index + 1) 组 · \(group.wordIds.count) 词"
        let action = group.isComplete ? "查看 / 重练" : group.hasStarted ? "继续" : "开始"
        let isNext = group.id == nextGroupID
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                groupRowLabel(title, status: group.status)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                groupRowAction(group, index: index, isNext: isNext, action: action)
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 6) {
                groupRowLabel(title, status: group.status)
                groupRowAction(group, index: index, isNext: isNext, action: action)
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

    @ViewBuilder private func groupRowAction(_ group: DailyVocabularyGroup, index: Int, isNext: Bool, action: String) -> some View {
        if group.isComplete || group.hasStarted || isNext {
            Button(action) {
                progress.prepareDailyVocabulary(words: content.dailyVocabularyWords(in: progress))
                openGroup(group.id)
            }
            .buttonStyle(StudyButtonStyle(prominent: isNext))
            .accessibilityLabel("第 \(index + 1) 组 · \(action)")
        } else {
            Text("上一组完成后开始").font(.caption).foregroundStyle(progress.theme.mutedInk)
        }
    }

    @ViewBuilder private func groupContent(_ group: DailyVocabularyGroup, day: String) -> some View {
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
                                HebrewText(text: progress.showNiqqud ? word.hebrew : word.hebrewUnpointed,
                                           cursive: progress.showCursive, size: 24)
                                Spacer(minLength: 4)
                                Text(word.meaningZh).font(.subheadline)
                            }
                        }
                    }
                }
            }
            let next = plan.nextGroup
            HStack(spacing: 8) {
                reviewWordsButton(group)
                Button {
                    restartGroup(group, day: day)
                } label: {
                    Label("再练一遍本组", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle())
            }
            if let next {
                primaryButton("开始下一组", symbol: "arrow.right") { openGroup(next.id) }
            }
        } else if let word = currentWord(group) {
            let total = group.wordIds.count
            if group.studied < total {
                let displayedIndex = studyWordIndex(for: group)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("认读 · 第 \(displayedIndex + 1) / \(total) 词")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Spacer(minLength: 4)
                        Button {
                            audio.stop()
                            celebration = nil
                            reviewingGroup = group
                        } label: {
                            Label("本组词表", systemImage: "book")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(progress.theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("查看本组全部单词")
                    }
                    if total > 0 {
                        ProgressView(value: Double(displayedIndex + 1), total: Double(total))
                            .tint(progress.theme.accent)
                            .accessibilityLabel("认读进度")
                    }
                }
                wordCard(word)
            } else if let stage = group.choiceStage {
                choiceContent(group, stage: stage, word: word, day: day)
            } else {
                spellingContent(group, word: word, day: day)
            }
        }
    }

    private func choiceQuestion(for group: DailyVocabularyGroup) -> ChoiceQuestion? {
        guard let position = group.choices?.answered, let wordID = group.choiceWordID else { return nil }
        return ChoiceQuestion(groupWordIDs: group.wordIds, round: group.roundCount, position: position, wordID: wordID)
    }

    private func updateChoiceOptions(for group: DailyVocabularyGroup?) {
        guard let group, let question = choiceQuestion(for: group),
              let stage = group.choiceStage, let word = word(question.wordID) else {
            choiceOptions = nil
            return
        }
        let selected = group.choices?.selectedWordID
        if let choiceOptions, choiceOptions.question == question,
           selected == nil || choiceOptions.words.contains(where: { $0.id == selected }) {
            return
        }
        let options = content.dailyVocabularyOptions(for: word, stage: stage, groupWordIDs: group.wordIds,
                                                     selectedWordID: selected)
        choiceOptions = (question, options)
    }

    private func choiceContent(_ group: DailyVocabularyGroup, stage: DailyVocabularyChoiceStage, word: StudyWord,
                               day: String) -> some View {
        let total = group.wordIds.count
        let showsHebrew = stage == .spokenWord
        let selected = group.choices?.selectedWordID
        let options = choiceOptions?.question == choiceQuestion(for: group) ? choiceOptions?.words ?? [] : []
        return VStack(alignment: .leading, spacing: 12) {
            quizMeter(group, title: "\(stage.title) · 第 \(group.choiceOffset + 1) / \(total) 题")
            StudyCard(highlighted: stage != .writtenMeaning) {
                switch stage {
                case .writtenMeaning:
                    StudySectionTitle("这个单词是什么意思？")
                    HebrewText(text: choiceSpelling(word), cursive: progress.showCursive, size: 48)
                        .frame(maxWidth: .infinity)
                case .spokenWord, .spokenMeaning:
                    StudySectionTitle(showsHebrew ? "听发音，选择希伯来语单词" : "听发音，选择中文意思")
                    PronunciationButton(hebrew: word.hebrew, title: "播放题目", prominent: true)
                }
            }
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                StudyAnswerButton(title: showsHebrew ? choiceSpelling(option) : option.meaningZh,
                                  submitted: selected != nil, selected: selected == option.id, correct: option.id == word.id,
                                  isHebrew: showsHebrew, cursive: progress.showCursive, optionLabel: studyOptionLabel(index)) {
                    let now = Date.now
                    guard progress.answerDailyVocabularyChoice(group, day: actionDay(day, on: now),
                                                              selectedWordID: option.id, date: now) else { return }
                    audio.stop()
                    audio.playFeedback(option.id == word.id ? .correct : .wrong)
                }
            }
            if let selected, selected != word.id {
                StudyQuizFeedback(correct: false, solution: "\(choiceSpelling(word)) · \(word.meaningZh)")
                    .id(ScrollTarget.feedback)
            }
        }
    }

    private func choiceSpelling(_ word: StudyWord) -> String {
        content.meaningPrompt(for: word, showNiqqud: progress.showNiqqud)
    }

    @ViewBuilder private func spellingContent(_ group: DailyVocabularyGroup, word: StudyWord, day: String) -> some View {
        let total = group.wordIds.count
        let index = group.answers.count - (group.feedbackPending ? 1 : 0)
        let title = "拼写 · 第 \(index + 1) / \(total) 词"
        let answer = group.feedbackPending ? group.answers.last : nil
        let isRetrying = retryingMistake && answer?.correct == false
        let input = Binding<String>(get: { isRetrying ? spelling : (answer?.input ?? spelling) }, set: { spelling = $0 })

        quizMeter(group, title: title)
        StudyCard {
            StudySectionTitle(isRetrying ? "订正拼写「\(word.meaningZh)」" : "写出「\(word.meaningZh)」")
            Text("提示 · \(word.transliteration)").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
            Text("使用系统键盘输入，支持无点全拼或带点写法").font(.caption).foregroundStyle(progress.theme.mutedInk)
        }
        WordSpellingInput(wordId: word.id, spelling: input,
                          submitted: isRetrying ? retryMatched : answer != nil) {
            if isRetrying {
                checkMistakeRetry(word: word)
            } else {
                submit(group, word: word, day: day)
            }
        }
        if isRetrying && retryMatched {
            StudyNotice(title: "订正成功，印象更牢了", symbol: "checkmark.circle.fill",
                        note: "\(word.hebrew) · \(word.hebrewUnpointed)")
                .id(ScrollTarget.feedback)
        } else if isRetrying, let retryComparison, !retryComparison.isExactMatch {
            VStack(alignment: .leading, spacing: 6) {
                Label("订正仍有误", systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(progress.theme.error)
                SpellingDiffView(comparison: retryComparison)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(progress.theme.errorSurface, in: RoundedRectangle(cornerRadius: 12))
            .id(ScrollTarget.feedback)
        } else if let answer, !isRetrying {
            let solution = "\(word.hebrew) · \(word.hebrewUnpointed)"
            let proficiency = progress.wordProficiency(word.id)
            VStack(alignment: .leading, spacing: 8) {
                StudyQuizFeedback(correct: answer.correct, solution: solution, response: answer.input,
                                  combo: plan.answerCombo,
                                  spellingComparison: answer.correct ? nil : word.spellingComparison(for: answer.input))
                if answer.wasPeeked && answer.correct {
                    StudyNotice(title: "已参考单词提示", symbol: "book",
                                note: "本题仅作跟写巩固，不增加熟练度与连击。")
                } else if let schedule = progress.schedule[word.id] {
                    StudyProficiencyCard(
                        proficiency: proficiency,
                        schedule: schedule,
                        mastery: progress.effectiveWordMastery(word.id)
                    )
                }
                PronunciationButton(hebrew: word.hebrew, title: "听正确发音")
            }
            .id(ScrollTarget.feedback)
        }
    }

    private func wordCard(_ word: StudyWord) -> some View {
        let displayWord = progress.showNiqqud ? word.hebrew : word.hebrewUnpointed
        return StudyCard {
            VStack(spacing: 10) {
                HebrewText(text: displayWord, cursive: progress.showCursive, size: 52, style: .largeTitle)
                PronunciationButton(hebrew: word.hebrew, title: "听发音")
                Text(word.meaningZh)
                    .font(.title3.bold())
                HStack(spacing: 6) {
                    Text("\(word.transliteration) · \(word.ipa)")
                        .font(.subheadline)
                        .foregroundStyle(progress.theme.mutedInk)
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(progress.theme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(progress.theme.accent.opacity(0.12), in: Capsule())
                    }
                }
                if !word.note.isEmpty {
                    Text(word.note)
                        .font(.caption)
                        .foregroundStyle(progress.theme.mutedInk)
                        .padding(.top, 2)
                }
                if let sentence = word.sentence {
                    Divider()
                    VStack(spacing: 4) {
                        HebrewText(text: sentence.hebrew, cursive: progress.showCursive, size: 22)
                        Text(sentence.meaningZh)
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }

    private func reviewWordsButton(_ group: DailyVocabularyGroup, markSpellingHint: Bool = false) -> some View {
        Button {
            if markSpellingHint {
                let day = actionDay(plan.day)
                guard progress.markDailyVocabularySpellingPeeked(group, day: day) else { return }
            }
            audio.stop()
            celebration = nil
            reviewingGroup = group
        } label: {
            Label("回看单词", systemImage: "book")
        }
        .buttonStyle(StudyButtonStyle())
        .accessibilityLabel(group.isComplete ? "回看本组单词" : "回看当前单词")
    }

    private func groupWordReview(_ group: DailyVocabularyGroup) -> some View {
        let duringSpelling = group.studied == group.wordIds.count && group.choiceStage == nil && !group.isComplete
        let words = duringSpelling ? [currentWord(group)].compactMap { $0 } : group.wordIds.compactMap { word($0) }
        return NavigationStack {
            StudyPage {
                if duringSpelling && !group.feedbackPending {
                    StudyNotice(title: "正在拼写答题中", symbol: "info.circle",
                                note: "提前回看后，当前词仅作跟写巩固，不增加熟练度与连击。")
                }
                StudyCard {
                    ForEach(words) { word in
                        if word.id != words.first?.id { Divider() }
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HebrewText(text: progress.showNiqqud ? word.hebrew : word.hebrewUnpointed,
                                           cursive: progress.showCursive, size: 30)
                                Text(word.meaningZh).font(.subheadline.weight(.semibold))
                                Text(word.transliteration)
                                    .font(.caption)
                                    .foregroundStyle(progress.theme.mutedInk)
                            }
                            Spacer(minLength: 4)
                            PronunciationButton(hebrew: word.hebrew, iconOnly: true, title: "播放\(word.meaningZh)的发音")
                        }
                    }
                }
            }
            .navigationTitle(duringSpelling ? "当前单词" : "本组单词")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(group.isComplete ? "返回结果" : "继续学习") { reviewingGroup = nil }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private func groupAction(_ group: DailyVocabularyGroup, word: StudyWord, day: String) -> some View {
        let total = group.wordIds.count
        if group.studied < total {
            let displayedIndex = studyWordIndex(for: group)
            primaryButton(displayedIndex + 1 == total ? "开始答题" : "下一词", symbol: "arrow.right") {
                stepNext(group, day: day)
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

    private func quizMeter(_ group: DailyVocabularyGroup, title: String) -> some View {
        let choiceQuestions = group.choices == nil ? 0 : group.wordIds.count * DailyVocabularyChoiceStage.allCases.count
        let choiceAnswers = (group.choices?.answered ?? 0) + (group.choices?.selectedWordID == nil ? 0 : 1)
        return meter(title, value: choiceAnswers + group.answers.count,
                     total: choiceQuestions + group.wordIds.count, label: "本组答题进度")
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(StudyButtonStyle(learningAction: true))
    }

    private func studyWordIndex(for group: DailyVocabularyGroup) -> Int {
        guard !group.wordIds.isEmpty else { return 0 }
        let maxIndex = min(group.studied, group.wordIds.count - 1)
        let candidate = browsingIndex ?? group.studied
        return min(max(0, candidate), maxIndex)
    }

    private func stepPrevious(_ group: DailyVocabularyGroup) {
        let current = studyWordIndex(for: group)
        guard current > 0 else { return }
        audio.stop()
        if progress.hapticsEnabled {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        browsingIndex = current - 1
    }

    private func stepNext(_ group: DailyVocabularyGroup, day: String) {
        let current = studyWordIndex(for: group)
        if current < group.studied {
            audio.stop()
            if progress.hapticsEnabled {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            let next = current + 1
            browsingIndex = next >= group.studied ? nil : next
        } else {
            browsingIndex = nil
            advance(group, day: day)
        }
    }

    private func currentWord(_ group: DailyVocabularyGroup) -> StudyWord? {
        if let choiceWordID = group.choiceWordID { return word(choiceWordID) }
        let index = group.studied < group.wordIds.count
            ? studyWordIndex(for: group)
            : group.answers.count - (group.feedbackPending ? 1 : 0)
        guard group.wordIds.indices.contains(index) else { return nil }
        return word(group.wordIds[index])
    }

    private func word(_ id: String) -> StudyWord? {
        content.words.first { $0.id == id }
    }

    private func openGroup(_ id: String?) {
        if id == nil { progress.prepareDailyVocabulary(words: content.dailyVocabularyWords(in: progress)) }
        audio.stop()
        activeId = id
        browsingIndex = nil
        celebration = nil
        retryingMistake = false
        retryMatched = false
        retryComparison = nil
        spelling = ""
    }

    private func addExtraGroup() {
        guard let added = progress.addDailyVocabularyGroup(words: content.dailyVocabularyWords(in: progress)) else { return }
        openGroup(added.id)
    }

    private func restartGroup(_ group: DailyVocabularyGroup, day: String) {
        guard progress.restartDailyVocabularyGroup(group, day: actionDay(day)) else { return }
        openGroup(group.id)
    }

    private func advance(_ group: DailyVocabularyGroup, day: String) {
        guard progress.advanceDailyVocabulary(group, day: actionDay(day)) else { return }
        audio.stop()
        browsingIndex = nil
        celebration = nil
        retryingMistake = false
        retryMatched = false
        retryComparison = nil
        spelling = ""
    }

    private func submit(_ group: DailyVocabularyGroup, word: StudyWord, day: String) {
        let now = Date.now
        guard let answer = progress.answerDailyVocabulary(group, day: actionDay(day, on: now), word: word,
                                                          input: spelling, date: now) else { return }
        spelling = ""
        retryingMistake = false
        retryMatched = false
        retryComparison = nil
        celebration = (answer.correct && !answer.wasPeeked) ? StudyAnswerCelebration(combo: progress.dailyVocabulary.answerCombo) : nil
        audio.playFeedback(answer.correct ? .correct : .wrong)
    }

    private func actionDay(_ displayedDay: String, on date: Date = .now) -> String {
        let today = DailyVocabularyPlan.dayKey(for: date)
        if displayedDay != today && plan.day != today {
            progress.prepareDailyVocabulary(words: content.dailyVocabularyWords(in: progress, at: date), date: date)
        }
        return today
    }

    private func checkMistakeRetry(word: StudyWord) {
        let trimmed = spelling.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if word.acceptsSpelling(trimmed) {
            retryMatched = true
            retryComparison = nil
            audio.playFeedback(.correct)
        } else {
            retryComparison = word.spellingComparison(for: trimmed)
            audio.playFeedback(.wrong)
        }
    }
}

private struct DailyVocabularyPackPickerSheet: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss
    let content: StudyContent
    let onSelect: (String?) -> Void

    private func unlearnedCount(for packId: String?) -> Int {
        let words = packId.map { content.words(inPack: $0) } ?? content.words
        return words.reduce(into: 0) { count, word in
            if progress.wordMastery[word.id] != .mastered && progress.schedule[word.id] == nil {
                count += 1
            }
        }
    }

    var body: some View {
        let selected = progress.dailyVocabularyPackId
        StudyPage {
            StudyCard(padding: 12) {
                Text("为「今日记词」单独选择一个单词包（不受内容页固定词包影响）。切换后，今日尚未开始的分组会立即从所选词包抽词；已开始或已完成的分组会保留。")
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
            }
            ForEach(StudyWordPackGroup.allCases.filter { $0 != .content }) { group in
                let packs = content.wordPacks(in: progress).filter { $0.group == group && $0.kind == .words }
                StudySectionTitle(group.title)
                StudyCard(padding: 10, spacing: 2) {
                    ForEach(packs) { pack in
                        if pack.id != packs.first?.id { Divider() }
                        let total = content.words(inPack: pack.id).count
                        packRow(id: pack.id, title: pack.title, subtitle: pack.subtitle, symbol: pack.symbol,
                                total: total, remaining: unlearnedCount(for: pack.id), selected: selected == pack.id,
                                inCard: true)
                    }
                }
            }
        }
        .studyDetail("选择今日学习词包")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
            if selected != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消词包") {
                        onSelect(nil)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func packRow(id: String?, title: String, subtitle: String, symbol: String,
                         total: Int, remaining: Int, selected: Bool, inCard: Bool = false) -> some View {
        let row = Button {
            onSelect(id)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? Color.white : progress.theme.accent)
                    .frame(width: 34, height: 34)
                    .background(selected ? progress.theme.primaryButton : progress.theme.highlightedSurface,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress.theme.ink)
                    Text("\(subtitle) · 待学 \(remaining)/\(total)")
                        .font(.caption)
                        .foregroundStyle(progress.theme.mutedInk)
                        .lineLimit(2)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(progress.theme.accent)
                }
            }
            .padding(.vertical, inCard ? 6 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if inCard {
            row
        } else {
            StudyCard(highlighted: selected, padding: 12) { row }
        }
    }
}
