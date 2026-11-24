import SwiftUI

struct StudyTodayReviewEntry: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let overview = StudyReviewOverview(content: content, progress: progress, at: timeline.date)
            NavigationLink {
                StudyTodayReviewView(content: content)
            } label: {
                if overview.hasDueItems {
                    StudyHeroCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SM-2 智能队列")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.20), in: Capsule())
                                Text(overview.savedBatch == nil ? "今日复习" : "继续复习")
                                    .font(.title3.weight(.bold))
                                Text(overview.summary)
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.88))
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "bolt.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.white.opacity(0.92))
                                .accessibilityHidden(true)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.bold))
                            Text(overview.savedBatch == nil ? "立即开始本组复习" : "继续本组复习")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(progress.theme.primaryButton)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.white, in: Capsule())
                    }
                } else {
                    StudyCard(padding: 12) {
                        StudyRow(title: "今日复习", symbol: "calendar.badge.checkmark", subtitle: overview.summary,
                                 badgeColors: [progress.theme.success, progress.theme.accent])
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct StudyReviewOverview {
    let words: [StudyWord]
    let letters: [StudyLetter]
    let completed: Int
    let nextReview: Date?
    let savedBatch: StudyReviewBatch?
    let nextBatch: StudyReviewBatch?

    init(content: StudyContent, progress: StudyProgress, at date: Date, calendar: Calendar = .current) {
        let wordSchedule = progress.schedule
        let letterSchedule = progress.letterSchedule
        let dueWords = content.dueWords(in: progress, at: date)
        let dueLetters = content.dueLetters(in: progress, at: date)
        words = dueWords
        letters = dueLetters

        let reviews = content.words.compactMap { wordSchedule[$0.id] }
            + content.letters.compactMap { letterSchedule[$0.id] }
        completed = reviews.filter { schedule in
            schedule.lastReview.map { calendar.isDate($0.date, inSameDayAs: date) } ?? false
        }.count
        nextReview = reviews.map(\.reviewDate).filter { $0 > date }.min()

        let spellingIDs = Set(progress.wordMistakes.lazy.filter { $0.kind == .spelling }.map(\.wordID))
        func kind(for word: StudyWord) -> StudyReviewBatch.Kind {
            spellingIDs.contains(word.id) ? .spelling : .meaning
        }
        let dueLetterIDs = Set(dueLetters.map(\.id))
        let dueWordIDs = Set(dueWords.map(\.id))
        if let batch = progress.reviewBatch, batch.isValid {
            savedBatch = batch.remaining(in: batch.kind == .letters ? dueLetterIDs : dueWordIDs)
        } else {
            savedBatch = nil
        }

        let firstWordDate = dueWords.first.flatMap { wordSchedule[$0.id]?.reviewDate }
        let firstLetterDate = dueLetters.first.flatMap { letterSchedule[$0.id]?.reviewDate }
        if let firstLetterDate, firstLetterDate < (firstWordDate ?? .distantFuture) {
            nextBatch = StudyReviewBatch(kind: .letters, itemIDs: dueLetters.prefix(StudyReviewBatch.limit).map(\.id))
        } else if let firstWord = dueWords.first {
            let batchKind = kind(for: firstWord)
            let candidates = dueWords.lazy.filter { kind(for: $0) == batchKind }
            nextBatch = StudyReviewBatch(kind: batchKind, itemIDs: candidates.prefix(StudyReviewBatch.limit).map(\.id))
        } else {
            nextBatch = nil
        }
    }

    var hasDueItems: Bool { !words.isEmpty || !letters.isEmpty }
    var summary: String { "剩余 \(words.count + letters.count) 项 · 今日已复习 \(completed) 项" }
}

private struct StudyTodayReviewView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    @State private var openedBatch: StudyReviewBatch?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let overview = StudyReviewOverview(content: content, progress: progress, at: timeline.date)
            StudyPage {
                StudyCard {
                    StudySectionTitle(overview.summary)
                    Text("到期单词 \(overview.words.count) · 到期字母 \(overview.letters.count)")
                        .font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    if let nextReview = overview.nextReview {
                        Text("下一批 · \(nextReview.formatted(.dateTime.month().day().hour().minute()))")
                            .font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    }
                    if let batch = overview.savedBatch ?? overview.nextBatch {
                        Button {
                            // Recheck due items at tap time before taking the batch snapshot.
                            let current = StudyReviewOverview(content: content, progress: progress, at: .now)
                            guard let next = current.savedBatch ?? current.nextBatch else { return }
                            progress.beginReviewBatch(next)
                            openedBatch = next
                        } label: {
                            Label(overview.savedBatch == nil ? "开始一组" : "继续这一组",
                                  systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudyButtonStyle(learningAction: true))
                        Text("\(batch.kind.title) · \(batch.itemIDs.count) 题")
                            .font(.footnote).foregroundStyle(progress.theme.mutedInk)
                    } else {
                        Text("当前没有到期项目。").font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    }
                }
                NavigationLink {
                    StudyMistakeBookView(content: content)
                } label: {
                    StudyCard(padding: 10) {
                        StudyRow(title: "错题本", symbol: "arrow.counterclockwise",
                                 value: "\(progress.wordMistakes.count) 项")
                    }
                }
                .buttonStyle(.plain)
                if overview.hasDueItems {
                    StudyCard {
                        DisclosureGroup("到期明细") {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(overview.words) { word in
                                    NavigationLink {
                                        WordDetailView(word: word, content: content)
                                    } label: {
                                        StudyRow(title: word.hebrew, symbol: "character.book.closed", subtitle: word.meaningZh)
                                    }
                                    .buttonStyle(.plain)
                                }
                                ForEach(overview.letters) { letter in
                                    NavigationLink {
                                        LetterStudyView(letter: letter, content: content)
                                    } label: {
                                        StudyRow(title: letter.hebrew, symbol: "textformat.abc", subtitle: letter.studyName)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .studyDetail("今日复习")
        .navigationDestination(item: $openedBatch) { batch in
            if batch.kind == .letters {
                let letters = batch.itemIDs.compactMap { id in content.letters.first { $0.id == id } }
                LetterReviewView(letters: letters, allLetters: content.letters)
            } else {
                let words = batch.itemIDs.compactMap { id in content.words.first { $0.id == id } }
                WordReviewView(content: content, words: words, kind: batch.kind == .spelling ? .spelling : .meaning)
            }
        }
    }
}

private struct StudyMistakeBookView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    @State private var kind = StudyWordMistakeKind.meaning

    var body: some View {
        let wordsByID = Dictionary(uniqueKeysWithValues: content.words.map { ($0.id, $0) })
        let mistakes = progress.wordMistakes.filter { $0.kind == kind && wordsByID[$0.wordID] != nil }
            .sorted { lhs, rhs in lhs.count == rhs.count ? lhs.lastMissedAt > rhs.lastMissedAt : lhs.count > rhs.count }
        StudyPage {
            StudySegments(title: "错题类型", options: StudyWordMistakeKind.allCases.map { ($0, $0.title) },
                          selection: $kind)
            if mistakes.isEmpty {
                ContentUnavailableView("暂无\(kind.title)错题", systemImage: "checkmark.circle")
            } else {
                NavigationLink {
                    WordQuizView(content: content, words: mistakes.prefix(StudyReviewBatch.limit).compactMap { wordsByID[$0.wordID] },
                                 kind: kind == .spelling ? .spelling : .meaning, mistakePractice: true)
                } label: {
                    StudyRow(title: "练习这些错题", symbol: "play.fill",
                             subtitle: "最多 \(StudyReviewBatch.limit) 题 · 优先练常错的词", emphasized: true)
                }
                .buttonStyle(.plain)
                Text("下一次正式复习答对同类题后，词条会移出错题本。")
                    .font(.footnote).foregroundStyle(progress.theme.mutedInk)
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(mistakes) { mistake in
                        if let word = wordsByID[mistake.wordID] {
                            NavigationLink {
                                WordDetailView(word: word, content: content)
                            } label: {
                                StudyRow(title: word.hebrew, symbol: "character.book.closed",
                                     subtitle: "\(word.meaningZh) · 上次答错 \(mistake.lastMissedAt.formatted(.dateTime.month().day()))",
                                         value: "错 \(mistake.count) 次")
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }
        }
        .studyDetail("错题本")
        .onAppear {
            if mistakes.isEmpty && progress.wordMistakes.contains(where: { $0.kind != kind && wordsByID[$0.wordID] != nil }) {
                kind = kind == .meaning ? .spelling : .meaning
            }
        }
    }
}
