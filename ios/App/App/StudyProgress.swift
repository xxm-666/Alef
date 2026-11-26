import Foundation
import Observation

enum Mastery: String, Codable, CaseIterable, Identifiable {
    case unlearned, learning, mastered

    var id: Self { self }
    var title: String {
        switch self {
        case .unlearned: "未学习"
        case .learning: "学习中"
        case .mastered: "已掌握"
        }
    }

    var symbol: String {
        switch self {
        case .unlearned: "circle"
        case .learning: "circle.lefthalf.filled"
        case .mastered: "checkmark.circle.fill"
        }
    }
}

enum StudyTheme: String, Codable, CaseIterable, Identifiable {
    case system, white, parchment, rose, violet, dark

    var id: Self { self }
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .white: "白色"
        case .parchment: "羊皮纸"
        case .rose: "玫瑰"
        case .violet: "紫罗兰"
        case .dark: "深色"
        }
    }
}

enum ReviewGrade: String, Codable, CaseIterable, Identifiable {
    case again, hard, good, easy

    var id: Self { self }

    var title: String {
        switch self {
        case .again: "重来"
        case .hard: "困难"
        case .good: "记住"
        case .easy: "轻松"
        }
    }

    var symbol: String {
        switch self {
        case .again: "arrow.counterclockwise"
        case .hard: "tortoise"
        case .good: "checkmark"
        case .easy: "bolt"
        }
    }

    var mastery: Mastery {
        self == .again || self == .hard ? .learning : .mastered
    }
}

struct ReviewSchedule: Codable, Equatable {
    struct Attempt: Codable, Equatable {
        let date: Date
        let grade: ReviewGrade
    }

    static let defaultEase = 2.5
    static let minEase = 1.3
    static let maxEase = 3.0
    static let maxIntervalDays = 180
    static let rememberedIntervalDays = 30

    let nextReviewAt: Int64
    let intervalDays: Int
    let easeFactor: Double
    let repetitions: Int
    let lapses: Int
    let lastReview: Attempt?
    let strength: Double?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case nextReviewAt, intervalDays, easeFactor, repetitions, lapses, lastReview, strength, updatedAt
    }

    init(nextReviewAt: Int64, intervalDays: Int, easeFactor: Double = defaultEase,
         repetitions: Int = 0, lapses: Int = 0, lastReview: Attempt? = nil,
         strength: Double? = nil, updatedAt: Date? = nil) {
        self.nextReviewAt = nextReviewAt
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.lapses = lapses
        self.lastReview = lastReview
        self.strength = strength
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nextReviewAt = try container.decode(Int64.self, forKey: .nextReviewAt)
        let intervalDays = try container.decode(Int.self, forKey: .intervalDays)
        self.nextReviewAt = nextReviewAt
        self.intervalDays = intervalDays
        self.easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? Self.defaultEase
        self.repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions) ?? (intervalDays >= 3 ? 1 : 0)
        self.lapses = try container.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        self.lastReview = try container.decodeIfPresent(Attempt.self, forKey: .lastReview)
        self.strength = try container.decodeIfPresent(Double.self, forKey: .strength)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var reviewDate: Date { Date(timeIntervalSince1970: Double(nextReviewAt) / 1_000) }

    func isDue(at date: Date) -> Bool { reviewDate <= date }

    var isDue: Bool { isDue(at: .now) }

    func displayDate(relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        if isDue(at: now) { return "已到期" }
        if calendar.isDate(reviewDate, inSameDayAs: now) { return "今天" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(reviewDate, inSameDayAs: tomorrow) { return "明天" }
        return reviewDate.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
    }

    var displayDate: String { displayDate(relativeTo: .now) }

    var intervalLabel: String { "\(intervalDays) 天" }

    var isValid: Bool {
        let validStrength = strength.map { $0.isFinite && (0...100).contains($0) } ?? true
        return nextReviewAt >= 0 && intervalDays >= 0 && easeFactor.isFinite
            && (1.0...5.0).contains(easeFactor) && repetitions >= 0 && lapses >= 0 && validStrength
    }

    func resolvedStrength(mastery: Mastery = .learning) -> Double {
        if let strength, strength.isFinite {
            return min(100, max(0, strength))
        }
        if mastery == .unlearned && repetitions == 0 { return 0 }
        if mastery == .mastered && repetitions == 0 { return 85 }
        return min(100, Double(25 + repetitions * 25))
    }

    func proficiency(at now: Date = .now, mastery: Mastery = .learning) -> Int {
        let base = resolvedStrength(mastery: mastery)
        guard base > 0 else { return 0 }
        let reference = updatedAt ?? lastReview?.date
            ?? reviewDate.addingTimeInterval(-Double(max(1, intervalDays)) * 86_400)
        let elapsedDays = max(0, now.timeIntervalSince(reference) / 86_400)
        let stabilityDays = Double(max(1, intervalDays))
        let graceDays = stabilityDays * 0.5
        if elapsedDays <= graceDays {
            return Int(round(base))
        }
        let overdue = elapsedDays - graceDays
        let retention = exp(-0.35 * (overdue / stabilityDays))
        let minimum = base >= 10 ? 10 : min(1, Int(round(base)))
        return max(minimum, min(100, Int(round(base * retention))))
    }

    func isDecayed(at now: Date = .now, mastery: Mastery = .learning) -> Bool {
        let base = Int(round(resolvedStrength(mastery: mastery)))
        return base > 0 && proficiency(at: now, mastery: mastery) < base
    }

    static func next(from current: ReviewSchedule?, grade: ReviewGrade, on date: Date,
                     calendar: Calendar = .current, recordsReview: Bool = true) -> ReviewSchedule {
        let ease = min(maxEase, max(minEase, current?.easeFactor ?? defaultEase))
        let reps = max(0, current?.repetitions ?? 0)
        let lapses = max(0, current?.lapses ?? 0)
        let prevInterval = max(1, current?.intervalDays ?? 1)
        let currentStrength = current.map { Double($0.proficiency(at: date)) } ?? 0
        let streakBonus = Double(min(20, reps * 7))

        let outcome: (interval: Int, newEase: Double, newReps: Int, newLapses: Int, strengthDelta: Double)
        switch grade {
        case .again:
            outcome = (1, max(minEase, ease - 0.2), 0, lapses + 1, -25)
        case .hard:
            let interval = reps == 0
                ? 1
                : min(maxIntervalDays, max(prevInterval + 1, Int(round(Double(prevInterval) * 1.2))))
            outcome = (interval, max(minEase, ease - 0.15), reps + 1, lapses, 12 + streakBonus)
        case .good:
            let interval: Int = switch reps {
            case 0: 3
            case 1: 7
            default: min(maxIntervalDays, max(prevInterval + 1, Int(round(Double(prevInterval) * ease))))
            }
            outcome = (interval, ease, reps + 1, lapses, 18 + streakBonus)
        case .easy:
            let interval = reps == 0
                ? 5
                : min(maxIntervalDays, max(prevInterval + 2, Int(round(Double(prevInterval) * ease * 1.3))))
            outcome = (interval, min(maxEase, ease + 0.15), reps + 1, lapses, 25 + streakBonus)
        }

        let minimumAfterMistake = currentStrength > 0 ? min(10, currentStrength) : 10
        let newStrength = grade == .again
            ? max(minimumAfterMistake, currentStrength + outcome.strengthDelta)
            : min(100, max(10, currentStrength + outcome.strengthDelta))
        let nextDate = calendar.date(byAdding: .day, value: outcome.interval, to: date) ?? date
        return ReviewSchedule(
            nextReviewAt: Int64(nextDate.timeIntervalSince1970 * 1_000),
            intervalDays: outcome.interval,
            easeFactor: outcome.newEase,
            repetitions: outcome.newReps,
            lapses: outcome.newLapses,
            lastReview: recordsReview ? Attempt(date: date, grade: grade) : current?.lastReview,
            strength: newStrength,
            updatedAt: date
        )
    }

    static func manual(mastery: Mastery, existing: ReviewSchedule?, on date: Date,
                       calendar: Calendar = .current) -> ReviewSchedule? {
        switch mastery {
        case .unlearned:
            return nil
        case .learning:
            let currentStrength = existing.map { Double($0.proficiency(at: date, mastery: .learning)) } ?? 0
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return ReviewSchedule(
                nextReviewAt: Int64(nextDate.timeIntervalSince1970 * 1_000),
                intervalDays: 1,
                easeFactor: existing?.easeFactor ?? defaultEase,
                repetitions: 0,
                lapses: existing?.lapses ?? 0,
                lastReview: existing?.lastReview,
                strength: min(65, max(25, currentStrength)),
                updatedAt: date
            )
        case .mastered:
            if let existing, !existing.isDue(at: date), existing.intervalDays >= rememberedIntervalDays {
                return ReviewSchedule(
                    nextReviewAt: existing.nextReviewAt,
                    intervalDays: existing.intervalDays,
                    easeFactor: existing.easeFactor,
                    repetitions: existing.repetitions,
                    lapses: existing.lapses,
                    lastReview: existing.lastReview,
                    strength: 100,
                    updatedAt: date
                )
            }
            let nextDate = calendar.date(byAdding: .day, value: rememberedIntervalDays, to: date) ?? date
            return ReviewSchedule(
                nextReviewAt: Int64(nextDate.timeIntervalSince1970 * 1_000),
                intervalDays: rememberedIntervalDays,
                easeFactor: existing?.easeFactor ?? defaultEase,
                repetitions: max(3, existing?.repetitions ?? 3),
                lapses: existing?.lapses ?? 0,
                lastReview: existing?.lastReview,
                strength: 100,
                updatedAt: date
            )
        }
    }
}

struct StudyStatistics: Codable, Equatable {
    var streakDays = 0
    var lastActiveDate = ""
    var todayReviews = 0
    var totalReviews = 0

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var reviewsToday: Int { lastActiveDate == Self.dateFormatter.string(from: .now) ? todayReviews : 0 }

    func activeStreakDays(on date: Date = .now) -> Int {
        let today = Self.dateFormatter.string(from: date)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date).map(Self.dateFormatter.string(from:))
        return lastActiveDate == today || lastActiveDate == yesterday ? streakDays : 0
    }

    mutating func record(on date: Date) {
        let today = Self.dateFormatter.string(from: date)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date).map(Self.dateFormatter.string(from:))
        if lastActiveDate == today {
            streakDays = max(1, streakDays)
            todayReviews += 1
        } else {
            streakDays = lastActiveDate == yesterday ? streakDays + 1 : 1
            todayReviews = 1
        }
        lastActiveDate = today
        totalReviews += 1
    }
}

enum StudyAchievement: String, CaseIterable, Hashable, Identifiable {
    case firstPractice, tenLetters, alphabet, firstVocabularyGroup
    case twentyWords, fiftyWords, threeDays, sevenDays
    case comboThree, comboFive, comboTen

    static let storageKey = "alef.native.achievements.v1"
    static let comboGoals = Set([Self.comboThree, .comboFive, .comboTen].map(\.goal))

    var id: String { rawValue }

    var goal: Int {
        switch self {
        case .firstPractice, .firstVocabularyGroup: 1
        case .tenLetters: 10
        case .alphabet: 22
        case .twentyWords: 20
        case .fiftyWords: 50
        case .threeDays: 3
        case .sevenDays: 7
        case .comboThree: 3
        case .comboFive: 5
        case .comboTen: 10
        }
    }
}

struct StudyAchievementProgress: Equatable {
    var practiceCount = 0
    var masteredLetters = 0
    var masteredWords = 0
    var completedVocabularyGroups = 0
    var streakDays = 0
    var bestAnswerCombo = 0

    func value(for achievement: StudyAchievement) -> Int {
        switch achievement {
        case .firstPractice: practiceCount
        case .tenLetters, .alphabet: masteredLetters
        case .firstVocabularyGroup: completedVocabularyGroups
        case .twentyWords, .fiftyWords: masteredWords
        case .threeDays, .sevenDays: streakDays
        case .comboThree, .comboFive, .comboTen: bestAnswerCombo
        }
    }
}

struct StudyAnswerCelebration: Equatable, Identifiable {
    let id = UUID()
    let combo: Int

    var isMilestone: Bool { StudyAchievement.comboGoals.contains(combo) }
}

struct StudyAnswerRun {
    private(set) var combo = 0
    private(set) var celebration: StudyAnswerCelebration?

    mutating func record(correct: Bool, in progress: StudyProgress, isRetry: Bool = false) {
        guard correct else {
            combo = 0
            celebration = nil
            return
        }
        if !isRetry {
            combo += 1
            progress.recordBestAnswerCombo(combo)
        }
        celebration = StudyAnswerCelebration(combo: isRetry ? 0 : combo)
    }

    mutating func clearCelebration() {
        celebration = nil
    }
}

struct DailySpellingAnswer: Codable, Equatable {
    let input: String
    let correct: Bool
    var peeked: Bool? = nil

    var wasPeeked: Bool { peeked == true }
}

enum DailyVocabularyChoiceStage: Int, CaseIterable {
    case writtenMeaning, spokenWord, spokenMeaning

    var title: String {
        switch self {
        case .writtenMeaning: "看词选义"
        case .spokenWord: "听音选词"
        case .spokenMeaning: "听音选义"
        }
    }
}

struct DailyVocabularyChoices: Codable, Equatable {
    let wordOrder: [[Int]]
    var answered = 0
    var selectedWordID: String?

    init(wordCount: Int) {
        wordOrder = DailyVocabularyChoiceStage.allCases.map { _ in (0..<wordCount).shuffled() }
    }

    func isValid(wordCount: Int) -> Bool {
        wordOrder.count == DailyVocabularyChoiceStage.allCases.count
            && (0...(wordOrder.count * wordCount)).contains(answered)
            && (selectedWordID.map { !$0.isEmpty && answered < wordOrder.count * wordCount } ?? true)
            && wordOrder.allSatisfy { $0.count == wordCount && Set($0) == Set(0..<wordCount) }
    }
}

struct DailyVocabularyGroup: Codable, Equatable, Identifiable {
    let wordIds: [String]
    var studied = 0
    var answers: [DailySpellingAnswer] = []
    var feedbackPending = false
    var practiceRound: Int? = nil
    var choices: DailyVocabularyChoices? = nil
    var spellingPeeked: Bool? = nil

    var id: String { wordIds.first ?? "" }
    var roundCount: Int { max(0, practiceRound ?? 0) }
    var hasStarted: Bool { studied > 0 || roundCount > 0 }
    var isComplete: Bool { answers.count == wordIds.count && !feedbackPending }
    var correctCount: Int { answers.filter(\.correct).count }
    var answerCombo: Int { answers.reversed().prefix(while: { $0.correct && !$0.wasPeeked }).count }
    var choiceStage: DailyVocabularyChoiceStage? {
        guard let choices, !wordIds.isEmpty else { return nil }
        return DailyVocabularyChoiceStage(rawValue: choices.answered / wordIds.count)
    }
    var choiceOffset: Int { (choices?.answered ?? 0) % max(1, wordIds.count) }
    var choiceWordID: String? {
        guard let choices, let stage = choiceStage else { return nil }
        return wordIds[choices.wordOrder[stage.rawValue][choiceOffset]]
    }
    var completedChoiceCount: Int {
        // Existing groups with spelling answers resume at spelling.
        choices?.answered ?? (answers.isEmpty ? 0 : DailyVocabularyChoiceStage.allCases.count * wordIds.count)
    }
    var status: String {
        if isComplete { return "拼对 \(correctCount) / \(wordIds.count)" }
        if let choiceStage {
            let submitted = choiceOffset + (choices?.selectedWordID == nil ? 0 : 1)
            return "\(choiceStage.title) \(submitted) / \(wordIds.count)"
        }
        if studied == wordIds.count { return "拼写 \(answers.count) / \(wordIds.count)" }
        if studied > 0 { return "认读 \(studied) / \(wordIds.count)" }
        return roundCount > 0 ? "第 \(roundCount + 1) 轮 · 准备重练" : "准备认读"
    }
}

struct DailyVocabularyPlan: Codable, Equatable {
    static let storageKey = "alef.dailyVocabulary.v1"
    static let groupOptions = [1, 2, 3]
    static let groupSize = 5
    static let maxGroupsPerDay = 20

    var day = ""
    var groupsPerDay = 2
    var groups: [DailyVocabularyGroup] = []
    var spellingCombo: Int? = nil
    var usesBeginnerFirstSelection: Bool? = nil

    var completedCount: Int { groups.filter(\.isComplete).count }
    var nextGroup: DailyVocabularyGroup? { groups.first { !$0.isComplete } }
    var hasStarted: Bool { groups.contains(where: \.hasStarted) }
    var answerCombo: Int {
        spellingCombo ?? groups.flatMap(\.answers).reversed().prefix(while: { $0.correct && !$0.wasPeeked }).count
    }

    static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    func plan(for date: Date, words: [StudyWord], mastery: [String: Mastery], schedule: [String: ReviewSchedule]) -> Self {
        let today = Self.dayKey(for: date)
        let isToday = day == today
        // Rebuild older plans once so their unopened groups use the new priority.
        let shouldReselect = isToday && usesBeginnerFirstSelection != true
        let available = Set(words.map(\.id))
        let valid = groups.filter { $0.wordIds.allSatisfy(available.contains) }
        let isEligibleUnstarted: (DailyVocabularyGroup) -> Bool = { group in
            group.wordIds.allSatisfy { mastery[$0] != .mastered && schedule[$0] == nil }
        }
        if isToday, !shouldReselect, valid.count == groups.count,
           valid.allSatisfy({ $0.hasStarted || isEligibleUnstarted($0) }) {
            return self
        }

        var assignments = valid.filter { group in
            if isToday {
                return group.hasStarted || (!shouldReselect && isEligibleUnstarted(group))
            }
            return group.hasStarted && !group.isComplete
        }
        let assigned = Set(assignments.flatMap(\.wordIds))
        let newIds = words.filter { !assigned.contains($0.id) && mastery[$0.id] != .mastered && schedule[$0.id] == nil }.map(\.id)
        let groupLimit = shouldReselect ? max(groups.count, groupsPerDay) : groupsPerDay
        for offset in stride(from: 0, to: newIds.count, by: Self.groupSize) {
            guard assignments.count < groupLimit else { break }
            assignments.append(DailyVocabularyGroup(wordIds: Array(newIds.dropFirst(offset).prefix(Self.groupSize))))
        }
        return Self(day: today, groupsPerDay: groupsPerDay, groups: assignments,
                    spellingCombo: isToday ? spellingCombo : 0, usesBeginnerFirstSelection: true)
    }

    func remainingNewWordIds(from words: [StudyWord], mastery: [String: Mastery], schedule: [String: ReviewSchedule]) -> [String] {
        let assigned = Set(groups.flatMap(\.wordIds))
        return words.filter { !assigned.contains($0.id) && mastery[$0.id] != .mastered && schedule[$0.id] == nil }.map(\.id)
    }

    var isValid: Bool {
        guard Self.groupOptions.contains(groupsPerDay), groups.count <= Self.maxGroupsPerDay, (spellingCombo ?? 0) >= 0,
              day.isEmpty ? groups.isEmpty : day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil
        else { return false }
        var ids = Set<String>()
        for group in groups {
            guard (1...Self.groupSize).contains(group.wordIds.count),
                  (0...group.wordIds.count).contains(group.studied), group.answers.count <= group.wordIds.count,
                  group.studied == group.wordIds.count || group.answers.isEmpty,
                  !group.feedbackPending || !group.answers.isEmpty,
                  group.spellingPeeked != true || (group.studied == group.wordIds.count && group.choiceStage == nil
                                                     && !group.feedbackPending && group.answers.count < group.wordIds.count),
                  group.answers.allSatisfy({ !$0.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  group.wordIds.allSatisfy({ !$0.isEmpty && ids.insert($0).inserted })
            else { return false }
            if let choices = group.choices {
                guard choices.isValid(wordCount: group.wordIds.count), group.studied == group.wordIds.count,
                      group.choiceStage == nil || group.answers.isEmpty else { return false }
            }
        }
        return true
    }
}

enum StudyWordMistakeKind: String, Codable, CaseIterable, Hashable {
    case meaning, spelling

    var title: String { self == .meaning ? "词义" : "拼写" }
}

struct StudyWordMistake: Codable, Identifiable, Equatable {
    static let storageKey = "alef.native.wordMistakes.v1"

    let wordID: String
    let kind: StudyWordMistakeKind
    var count = 1
    var lastMissedAt: Date

    var id: String { "\(kind.rawValue):\(wordID)" }
}

struct StudyReviewBatch: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case letters, meaning, spelling

        var title: String {
            switch self {
            case .letters: "字母"
            case .meaning: "单词词义"
            case .spelling: "单词拼写"
            }
        }
    }

    static let storageKey = "alef.native.reviewBatch.v1"
    static let limit = 10

    let kind: Kind
    let itemIDs: [String]

    var isValid: Bool {
        !itemIDs.isEmpty && itemIDs.count <= Self.limit
            && itemIDs.allSatisfy { !$0.isEmpty } && Set(itemIDs).count == itemIDs.count
    }

    func remaining(in dueIDs: Set<String>) -> Self? {
        let pending = itemIDs.filter(dueIDs.contains)
        return pending.isEmpty ? nil : Self(kind: kind, itemIDs: pending)
    }
}

@Observable final class StudyProgress {
    struct BackupUndo: Codable {
        let previous: [String: Data]
        let absent: [String]
        var applied: [String: Data]? = nil
        var appliedLearning: [String: Data]? = nil
    }

    enum BackupRestoreMode: Hashable {
        case keepCurrent, restoreSnapshot
    }

    private static let storageKey = "alef.native.progress.v1"
    private static let restoreKey = "alef.native.restore.v1"
    private static let migrationKey = "alef.native.didReadWebStorage.v1"
    private static let localUpdatedAtKey = "alef.sync.localUpdatedAt.v1"
    static let bestAnswerComboKey = "alef.native.bestAnswerCombo.v1"
    private static let achievementInputKeys: Set<String> = [
        "alef.mastery.v1", "alef.wordMastery.v1", "alef.studyStats.v1", DailyVocabularyPlan.storageKey, bestAnswerComboKey
    ]
    private static let learningBackupKeys = achievementInputKeys.union([
        "alef.wordSrs.v1", letterScheduleKey, StudyReviewBatch.storageKey,
        StudyWordMistake.storageKey, StudyAchievement.storageKey
    ])
    static let letterScheduleKey = "alef.native.letterSrs.v1"
    static let lastBackupAtKey = "alef.native.lastBackupAt.v1"
    static let nonSyncedKeys: Set<String> = [
        lastBackupAtKey, "alef.activeView.v1", "alef.selectedLetterId.v1",
        StudyReviewBatch.storageKey, StudyWordMistake.storageKey, StudyAchievement.storageKey, bestAnswerComboKey
    ]
    static let appearanceKey = "alef.native.appearance.v1"
    static let themeKey = "alef.theme.v1"
    static let dayThemeKey = "alef.dayTheme.v1"
    private enum AppearanceOverride: String, Codable {
        case manual, system, white
    }

    private let defaults: UserDefaults
    private let letterIDs: Set<String>
    private let wordIDs: Set<String>
    @ObservationIgnored private var entries: [String: Data]
    @ObservationIgnored private var readCache: [String: (Data, Any)] = [:]
    private(set) var restorePoint: BackupUndo?
    private(set) var syncRevision: Int = 0
    private(set) var localUpdatedAt: Int64 = 0
    private(set) var achievementProgress = StudyAchievementProgress()
    private(set) var earnedAchievements: Set<StudyAchievement> = []
    var widgetRequest: StudyWidgetRoute?

    private var cachedTheme: StudyTheme = .system
    private var cachedLetterMastery: [String: Mastery] = [:]
    private var cachedLetterSchedule: [String: ReviewSchedule] = [:]
    private var cachedWordMastery: [String: Mastery] = [:]
    private var cachedSchedule: [String: ReviewSchedule] = [:]
    private var cachedFavorites: [String] = []
    private var cachedStatistics = StudyStatistics()
    private var cachedDailyVocabulary = DailyVocabularyPlan()
    private var cachedLastBackupAt: Int64? = nil
    private var cachedSpeechRate: Double = 1
    private var cachedFeedbackEnabled = true
    private var cachedHapticsEnabled = true
    private var cachedPrefersRecordings = true
    private var cachedAlphabetFromRight = true
    private var cachedReminderPreferences = ReminderPreferences()
    private var cachedWordMistakes: [StudyWordMistake] = []
    private var cachedReviewBatch: StudyReviewBatch? = nil

    private var activeViewVersion = 0
    private var selectedLetterVersion = 0
    private var displayConfigVersion = 0
    private var wordsStateVersion = 0
    private var flashcardStateVersion = 0
    private var phraseFavoritesVersion = 0
    private var otherKeyVersion = 0

    init(defaults: UserDefaults = .standard, letterIDs: Set<String> = [], wordIDs: Set<String> = []) {
        self.defaults = defaults
        self.letterIDs = letterIDs
        self.wordIDs = wordIDs
        entries = defaults.dictionary(forKey: Self.storageKey) as? [String: Data] ?? [:]
        restorePoint = defaults.data(forKey: Self.restoreKey).flatMap { try? JSONDecoder().decode(BackupUndo.self, from: $0) }
        localUpdatedAt = (defaults.object(forKey: Self.localUpdatedAtKey) as? NSNumber)?.int64Value ?? 0
        let storedAchievements = entries[StudyAchievement.storageKey]
        refreshCachedState(changedKeys: nil)
        if entries[StudyAchievement.storageKey] != storedAchievements { save() }
    }

    var letterMastery: [String: Mastery] { cachedLetterMastery }
    var letterSchedule: [String: ReviewSchedule] { cachedLetterSchedule }
    var wordMastery: [String: Mastery] { cachedWordMastery }
    var learnedWidgetWordIDs: Set<String> {
        Set(cachedWordMastery.compactMap { $0.value == .unlearned ? nil : $0.key })
    }
    var schedule: [String: ReviewSchedule] { cachedSchedule }
    var favorites: [String] { cachedFavorites }
    var statistics: StudyStatistics { cachedStatistics }
    var dailyVocabulary: DailyVocabularyPlan { cachedDailyVocabulary }
    var needsLegacyMigration: Bool { !defaults.bool(forKey: Self.migrationKey) }

    var hasMeaningfulData: Bool {
        !wordMastery.isEmpty || !letterMastery.isEmpty || !schedule.isEmpty
            || !letterSchedule.isEmpty || !favorites.isEmpty || statistics.totalReviews > 0
    }

    var lastBackupAt: Int64? { cachedLastBackupAt }

    var lastBackupDate: Date? {
        lastBackupAt.map { Date(timeIntervalSince1970: Double($0) / 1_000) }
    }

    func markBackupExported(on date: Date = .now) {
        write(Int64(date.timeIntervalSince1970 * 1_000), for: Self.lastBackupAtKey)
    }

    func backupReminderMessage(on date: Date = .now, staleDays: Int = 7) -> String? {
        if statistics.totalReviews < 10 && wordMastery.isEmpty && letterMastery.isEmpty {
            return nil
        }
        guard let lastBackupDate else {
            return "尚未备份学习记录。重签或换机前建议保存一份 JSON 备份。"
        }
        let days = max(0, Int(date.timeIntervalSince(lastBackupDate) / 86_400))
        guard days >= staleDays else { return nil }
        return "距离上次备份已过 \(days) 天，建议导出 JSON 备份到「文件」。"
    }

    private var appearanceOverride: AppearanceOverride { decodeEntry(Self.appearanceKey, default: .manual) }

    var theme: StudyTheme {
        get { cachedTheme }
        set {
            update { values, encoder in
                switch newValue {
                case .system:
                    values[Self.appearanceKey] = try encoder.encode(AppearanceOverride.system)
                case .white:
                    values[Self.appearanceKey] = try encoder.encode(AppearanceOverride.white)
                case .parchment, .rose, .violet, .dark:
                    values[Self.appearanceKey] = try encoder.encode(AppearanceOverride.manual)
                    let theme = try encoder.encode(newValue)
                    values[Self.themeKey] = theme
                    if newValue != .dark { values[Self.dayThemeKey] = theme }
                }
            }
        }
    }

    var speechRate: Double {
        get { cachedSpeechRate }
        set { write(newValue, for: "alef.speechRate.v1") }
    }

    var feedbackEnabled: Bool {
        get { cachedFeedbackEnabled }
        set { write(newValue, for: "alef.native.feedback.v1") }
    }

    var hapticsEnabled: Bool {
        get { cachedHapticsEnabled }
        set { write(newValue, for: "alef.native.haptics.v1") }
    }

    var prefersRecordings: Bool {
        get { cachedPrefersRecordings }
        set { write(newValue, for: "alef.native.recordings.v1") }
    }

    var alphabetFromRight: Bool {
        get { cachedAlphabetFromRight }
        set { write(newValue ? "rtl" : "ltr", for: "alef.order.v1") }
    }

    var showNiqqud: Bool {
        get { read("alef.wordsState.v1", default: WordPreferences()).showNiqqud }
        set {
            var prefs = read("alef.wordsState.v1", default: WordPreferences())
            guard prefs.showNiqqud != newValue else { return }
            prefs.showNiqqud = newValue
            write(prefs, for: "alef.wordsState.v1")
        }
    }

    var showCursive: Bool {
        get { read("alef.wordsState.v1", default: WordPreferences()).showCursive }
        set {
            var prefs = read("alef.wordsState.v1", default: WordPreferences())
            guard prefs.showCursive != newValue else { return }
            prefs.showCursive = newValue
            write(prefs, for: "alef.wordsState.v1")
        }
    }

    var reminderPreferences: ReminderPreferences {
        get { cachedReminderPreferences }
        set {
            guard newValue.isValid else { return }
            write(newValue, for: ReminderPreferences.storageKey)
        }
    }

    var wordMistakes: [StudyWordMistake] { cachedWordMistakes }

    var reviewBatch: StudyReviewBatch? { cachedReviewBatch }

    func beginReviewBatch(_ batch: StudyReviewBatch) {
        guard batch.isValid else { return }
        write(batch, for: StudyReviewBatch.storageKey)
    }

    func setLetter(_ id: String, mastery: Mastery, date: Date = .now) {
        if (letterMastery[id] ?? .unlearned) == mastery,
           effectiveLetterMastery(id, at: date) == mastery,
           (letterSchedule[id] == nil) == (mastery == .unlearned) { return }
        saveManual(id, masteryKey: "alef.mastery.v1", scheduleKey: Self.letterScheduleKey, mastery: mastery, date: date)
    }

    func completeLetterReview(_ id: String, grade: ReviewGrade, isRetry: Bool = false, date: Date = .now) {
        saveReview(id, masteryKey: "alef.mastery.v1", scheduleKey: Self.letterScheduleKey,
                   base: letterSchedule[id], grade: grade, recordStats: true, date: date, isRetry: isRetry)
    }

    func completeLetterReview(_ id: String, correct: Bool, date: Date = .now) {
        completeLetterReview(id, grade: correct ? .good : .again, date: date)
    }

    func adjustLetterReview(_ id: String, base: ReviewSchedule?, grade: ReviewGrade, date: Date = .now) {
        saveReview(id, masteryKey: "alef.mastery.v1", scheduleKey: Self.letterScheduleKey,
                   base: base, grade: grade, recordStats: false, date: date)
    }

    func setWord(_ id: String, mastery: Mastery, date: Date = .now) {
        if (wordMastery[id] ?? .unlearned) == mastery,
           effectiveWordMastery(id, at: date) == mastery,
           (schedule[id] == nil) == (mastery == .unlearned) { return }
        saveManual(id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1", mastery: mastery, date: date)
    }

    func completeReview(_ id: String, grade: ReviewGrade, mistakeKind: StudyWordMistakeKind = .meaning,
                        isRetry: Bool = false, date: Date = .now) {
        saveReview(id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1",
                   base: schedule[id], grade: grade, recordStats: true, date: date,
                   isRetry: isRetry, mistakeKind: mistakeKind)
    }

    func completeReview(_ id: String, correct: Bool, mistakeKind: StudyWordMistakeKind = .meaning,
                        isRetry: Bool = false, date: Date = .now) {
        let recovering = schedule[id].map { $0.lapses > 0 && $0.intervalDays == 1 } ?? false
        let grade: ReviewGrade = correct ? (recovering ? .hard : .good) : .again
        completeReview(id, grade: grade, mistakeKind: mistakeKind, isRetry: isRetry, date: date)
    }

    func recordWordPractice(_ id: String, correct: Bool, date: Date = .now) {
        savePractice(id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1",
                     correct: correct, date: date)
    }

    func recordLetterPractice(_ id: String, correct: Bool, date: Date = .now) {
        savePractice(id, masteryKey: "alef.mastery.v1", scheduleKey: Self.letterScheduleKey,
                     correct: correct, date: date)
    }

    func wordProficiency(_ id: String, at date: Date = .now) -> Int {
        let mastery = wordMastery[id] ?? .unlearned
        if let existing = schedule[id] {
            return existing.proficiency(at: date, mastery: mastery)
        }
        switch mastery {
        case .unlearned: return 0
        case .learning: return 35
        case .mastered: return 100
        }
    }

    func letterProficiency(_ id: String, at date: Date = .now) -> Int {
        let mastery = letterMastery[id] ?? .unlearned
        if let existing = letterSchedule[id] {
            return existing.proficiency(at: date, mastery: mastery)
        }
        switch mastery {
        case .unlearned: return 0
        case .learning: return 35
        case .mastered: return 100
        }
    }

    static func mastery(forProficiency proficiency: Int) -> Mastery {
        if proficiency >= 80 { return .mastered }
        if proficiency > 0 { return .learning }
        return .unlearned
    }

    func effectiveWordMastery(_ id: String, at date: Date = .now) -> Mastery {
        Self.mastery(forProficiency: wordProficiency(id, at: date))
    }

    func effectiveLetterMastery(_ id: String, at date: Date = .now) -> Mastery {
        Self.mastery(forProficiency: letterProficiency(id, at: date))
    }

    func quizWeight(forWord id: String, at date: Date = .now) -> Int {
        let proficiency = wordProficiency(id, at: date)
        if wordMastery[id] == .mastered && proficiency >= 80 { return 1 }
        if proficiency >= 80 { return 2 }
        if proficiency >= 40 { return 5 }
        return 10
    }

    func quizWeight(forLetter id: String, at date: Date = .now) -> Int {
        let proficiency = letterProficiency(id, at: date)
        if letterMastery[id] == .mastered && proficiency >= 80 { return 1 }
        if proficiency >= 80 { return 2 }
        if proficiency >= 40 { return 5 }
        return 10
    }

    func weightedRandom<T>(from items: [T], weight: (T) -> Int) -> T? {
        let total = items.reduce(0) { $0 + max(1, weight($1)) }
        guard total > 0 else { return items.first }
        var target = Int.random(in: 0..<total)
        for item in items {
            let w = max(1, weight(item))
            if target < w { return item }
            target -= w
        }
        return items.last
    }

    func dailyVocabularyPlan(words: [StudyWord], date: Date = .now) -> DailyVocabularyPlan {
        dailyVocabulary.plan(for: date, words: words, mastery: wordMastery, schedule: schedule)
    }

    func prepareDailyVocabulary(words: [StudyWord], date: Date = .now) {
        let current = dailyVocabulary
        var plan = current.plan(for: date, words: words, mastery: wordMastery, schedule: schedule)
        for index in plan.groups.indices {
            let group = plan.groups[index]
            if group.studied == group.wordIds.count && group.choices == nil && group.answers.isEmpty {
                plan.groups[index].choices = DailyVocabularyChoices(wordCount: group.wordIds.count)
            }
            // Older saves can be waiting for confirmation after an already scored answer.
            if let selected = group.choices?.selectedWordID, selected == group.choiceWordID {
                plan.groups[index].choices?.selectedWordID = nil
                plan.groups[index].choices?.answered += 1
            }
            if group.feedbackPending && group.answers.last?.correct == true {
                plan.groups[index].feedbackPending = false
            }
        }
        if current != plan { write(plan, for: DailyVocabularyPlan.storageKey) }
    }

    func setDailyVocabularyLimit(_ count: Int, words: [StudyWord], date: Date = .now) {
        guard DailyVocabularyPlan.groupOptions.contains(count) else { return }
        var plan = dailyVocabularyPlan(words: words, date: date)
        guard plan.groupsPerDay != count else { return }
        plan.groupsPerDay = count
        if plan.groups.count < count {
            let newIds = plan.remainingNewWordIds(from: words, mastery: wordMastery, schedule: schedule)
            for offset in stride(from: 0, to: newIds.count, by: DailyVocabularyPlan.groupSize) {
                guard plan.groups.count < count else { break }
                plan.groups.append(DailyVocabularyGroup(wordIds: Array(newIds.dropFirst(offset).prefix(DailyVocabularyPlan.groupSize))))
            }
        } else if plan.groups.count > count {
            while plan.groups.count > count, let last = plan.groups.last, !last.hasStarted {
                plan.groups.removeLast()
            }
        }
        write(plan, for: DailyVocabularyPlan.storageKey)
    }

    @discardableResult
    func addDailyVocabularyGroup(words: [StudyWord], date: Date = .now) -> DailyVocabularyGroup? {
        var plan = dailyVocabularyPlan(words: words, date: date)
        guard plan.groups.count < DailyVocabularyPlan.maxGroupsPerDay else { return nil }
        let newIds = plan.remainingNewWordIds(from: words, mastery: wordMastery, schedule: schedule)
        guard !newIds.isEmpty else { return nil }
        let added = DailyVocabularyGroup(wordIds: Array(newIds.prefix(DailyVocabularyPlan.groupSize)))
        plan.groups.append(added)
        write(plan, for: DailyVocabularyPlan.storageKey)
        return added
    }

    @discardableResult
    func restartDailyVocabularyGroup(_ expected: DailyVocabularyGroup, day: String) -> Bool {
        var plan = dailyVocabulary
        guard plan.day == day, expected.isComplete,
              let index = plan.groups.firstIndex(of: expected) else { return false }
        plan.spellingCombo = plan.answerCombo
        plan.groups[index].studied = 0
        plan.groups[index].answers = []
        plan.groups[index].feedbackPending = false
        plan.groups[index].practiceRound = expected.roundCount + 1
        plan.groups[index].choices = nil
        plan.groups[index].spellingPeeked = nil
        write(plan, for: DailyVocabularyPlan.storageKey)
        return true
    }

    @discardableResult
    func advanceDailyVocabulary(_ expected: DailyVocabularyGroup, day: String) -> Bool {
        var plan = dailyVocabulary
        guard plan.day == day, !expected.isComplete,
              let index = plan.groups.firstIndex(of: expected) else { return false }
        if expected.studied < expected.wordIds.count {
            plan.groups[index].studied += 1
            if plan.groups[index].studied == expected.wordIds.count {
                plan.groups[index].choices = DailyVocabularyChoices(wordCount: expected.wordIds.count)
            }
        } else if expected.feedbackPending {
            plan.groups[index].feedbackPending = false
        } else if expected.choices?.selectedWordID != nil {
            plan.groups[index].choices?.selectedWordID = nil
            plan.groups[index].choices?.answered += 1
        } else {
            return false
        }
        write(plan, for: DailyVocabularyPlan.storageKey)
        return true
    }

    @discardableResult
    func answerDailyVocabularyChoice(_ expected: DailyVocabularyGroup, day: String, selectedWordID: String,
                                     date: Date = .now) -> Bool {
        var plan = dailyVocabulary
        guard plan.day == day, let wordID = expected.choiceWordID, expected.choices?.selectedWordID == nil,
              !selectedWordID.isEmpty,
              let index = plan.groups.firstIndex(of: expected) else { return false }
        if selectedWordID == wordID {
            plan.groups[index].choices?.answered += 1
            savePractice(wordID, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1",
                         correct: true, date: date, dailyPlan: plan)
        } else {
            plan.groups[index].choices?.selectedWordID = selectedWordID
            saveDailyPractice(plan, on: date)
        }
        return true
    }

    func markDailyVocabularySpellingPeeked(_ expected: DailyVocabularyGroup, day: String) -> Bool {
        var plan = dailyVocabulary
        guard plan.day == day, expected.studied == expected.wordIds.count, expected.choiceStage == nil,
              !expected.feedbackPending, !expected.isComplete,
              let index = plan.groups.firstIndex(of: expected) else { return false }
        plan.groups[index].spellingPeeked = true
        write(plan, for: DailyVocabularyPlan.storageKey)
        return true
    }

    private func saveDailyPractice(_ plan: DailyVocabularyPlan, on date: Date) {
        var stats = statistics
        stats.record(on: date)
        update { entries, encoder in
            entries["alef.studyStats.v1"] = try encoder.encode(stats)
            entries[DailyVocabularyPlan.storageKey] = try encoder.encode(plan)
        }
    }

    func answerDailyVocabulary(_ expected: DailyVocabularyGroup, day: String, word: StudyWord, input: String,
                               date: Date = .now) -> DailySpellingAnswer? {
        var plan = dailyVocabulary
        let answer = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard plan.day == day, !expected.isComplete, let index = plan.groups.firstIndex(of: expected),
              !answer.isEmpty, expected.studied == expected.wordIds.count, expected.choiceStage == nil, !expected.feedbackPending,
              expected.wordIds.indices.contains(expected.answers.count), expected.wordIds[expected.answers.count] == word.id
        else { return nil }
        let usedHint = expected.spellingPeeked == true
        let attempt = DailySpellingAnswer(input: answer, correct: word.acceptsSpelling(answer), peeked: usedHint ? true : nil)
        plan.spellingCombo = attempt.correct && !usedHint ? min(plan.answerCombo, Int.max - 1) + 1 : 0
        plan.groups[index].answers.append(attempt)
        plan.groups[index].feedbackPending = !attempt.correct
        plan.groups[index].spellingPeeked = nil
        if usedHint && attempt.correct {
            saveDailyPractice(plan, on: date)
            return attempt
        }
        if expected.roundCount > 0, let existing = schedule[word.id],
           existing.repetitions > 0 || existing.lapses > 0 || existing.lastReview != nil {
            savePractice(word.id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1",
                         correct: attempt.correct, date: date, dailyPlan: plan, mistakeKind: .spelling)
            return attempt
        }
        saveReview(word.id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1",
                   base: schedule[word.id], grade: attempt.correct ? .good : .again,
                   recordStats: true, date: date, dailyPlan: plan, mistakeKind: .spelling,
                   answerCombo: plan.answerCombo)
        return attempt
    }

    private func saveManual(_ id: String, masteryKey: String, scheduleKey: String, mastery: Mastery, date: Date) {
        var values: [String: Mastery] = read(masteryKey, default: [:])
        var dates: [String: ReviewSchedule] = read(scheduleKey, default: [:])
        values[id] = mastery
        if let updated = ReviewSchedule.manual(mastery: mastery, existing: dates[id], on: date) {
            dates[id] = updated
        } else {
            dates.removeValue(forKey: id)
        }
        var stats = statistics
        stats.record(on: date)
        update { entries, encoder in
            entries[masteryKey] = try encoder.encode(values)
            entries[scheduleKey] = try encoder.encode(dates)
            entries["alef.studyStats.v1"] = try encoder.encode(stats)
        }
    }

    private func savePractice(_ id: String, masteryKey: String, scheduleKey: String, correct: Bool, date: Date,
                              dailyPlan: DailyVocabularyPlan? = nil, mistakeKind: StudyWordMistakeKind? = nil) {
        var values: [String: Mastery] = read(masteryKey, default: [:])
        var dates: [String: ReviewSchedule] = read(scheduleKey, default: [:])
        let currentMastery = values[id] ?? .unlearned
        let existing = dates[id]
        let currentStrength: Double = if let existing {
            Double(existing.proficiency(at: date, mastery: currentMastery))
        } else {
            switch currentMastery {
            case .unlearned: 0
            case .learning: 35
            case .mastered: 100
            }
        }
        let newStrength: Double = if correct {
            if dailyPlan != nil { min(100, currentStrength + 4) }
            else { currentStrength == 0 ? 25 : min(100, currentStrength + 15) }
        } else {
            max(currentStrength > 0 ? min(10, currentStrength) : 10, currentStrength - 15)
        }
        let nextSchedule: ReviewSchedule
        if let existing {
            nextSchedule = ReviewSchedule(
                nextReviewAt: existing.nextReviewAt,
                intervalDays: existing.intervalDays,
                easeFactor: existing.easeFactor,
                repetitions: existing.repetitions,
                lapses: existing.lapses,
                lastReview: existing.lastReview,
                strength: newStrength,
                updatedAt: date
            )
        } else {
            let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            nextSchedule = ReviewSchedule(
                nextReviewAt: Int64(nextDate.timeIntervalSince1970 * 1_000),
                intervalDays: 1,
                easeFactor: ReviewSchedule.defaultEase,
                repetitions: correct && dailyPlan == nil ? 1 : 0,
                lapses: correct ? 0 : 1,
                lastReview: nil,
                strength: newStrength,
                updatedAt: date
            )
        }
        values[id] = Self.mastery(forProficiency: Int(round(newStrength)))
        dates[id] = nextSchedule
        var stats = statistics
        stats.record(on: date)
        let mistakes = mistakeKind.map { updatedMistakes(wordID: id, kind: $0, failed: !correct, formal: false, date: date) }
        update { entries, encoder in
            entries[masteryKey] = try encoder.encode(values)
            entries[scheduleKey] = try encoder.encode(dates)
            entries["alef.studyStats.v1"] = try encoder.encode(stats)
            if let mistakes, mistakes != wordMistakes {
                entries[StudyWordMistake.storageKey] = try encoder.encode(mistakes)
            }
            if let dailyPlan {
                entries[DailyVocabularyPlan.storageKey] = try encoder.encode(dailyPlan)
                if dailyPlan.answerCombo > achievementProgress.bestAnswerCombo {
                    entries[Self.bestAnswerComboKey] = try encoder.encode(dailyPlan.answerCombo)
                }
            }
        }
    }

    private func saveReview(_ id: String, masteryKey: String, scheduleKey: String, base: ReviewSchedule?,
                            grade: ReviewGrade, recordStats: Bool, date: Date,
                            dailyPlan: DailyVocabularyPlan? = nil, isRetry: Bool = false,
                            mistakeKind: StudyWordMistakeKind? = nil, answerCombo: Int = 0) {
        if isRetry {
            recordStudy(on: date)
            return
        }
        var values: [String: Mastery] = read(masteryKey, default: [:])
        var dates: [String: ReviewSchedule] = read(scheduleKey, default: [:])
        let nextSchedule = ReviewSchedule.next(from: base, grade: grade, on: date, recordsReview: dailyPlan == nil)
        let nextProficiency = nextSchedule.proficiency(at: date, mastery: .learning)
        values[id] = Self.mastery(forProficiency: nextProficiency)
        dates[id] = nextSchedule
        var stats = statistics
        if recordStats { stats.record(on: date) }
        let mistakes = mistakeKind.map { kind in
            updatedMistakes(wordID: id, kind: kind, failed: grade == .again, formal: dailyPlan == nil, date: date)
        }
        update { entries, encoder in
            entries[masteryKey] = try encoder.encode(values)
            entries[scheduleKey] = try encoder.encode(dates)
            if recordStats { entries["alef.studyStats.v1"] = try encoder.encode(stats) }
            if let mistakes, mistakes != wordMistakes {
                entries[StudyWordMistake.storageKey] = try encoder.encode(mistakes)
            }
            if let dailyPlan { entries[DailyVocabularyPlan.storageKey] = try encoder.encode(dailyPlan) }
            if answerCombo > achievementProgress.bestAnswerCombo {
                entries[Self.bestAnswerComboKey] = try encoder.encode(answerCombo)
            }
        }
    }

    private func updatedMistakes(wordID: String, kind: StudyWordMistakeKind,
                                 failed: Bool, formal: Bool, date: Date) -> [StudyWordMistake] {
        var mistakes = wordMistakes
        if let index = mistakes.firstIndex(where: { $0.wordID == wordID && $0.kind == kind }) {
            if failed {
                if mistakes[index].count < Int.max { mistakes[index].count += 1 }
                mistakes[index].lastMissedAt = date
            } else if formal {
                mistakes.remove(at: index)
            }
        } else if failed {
            mistakes.append(StudyWordMistake(wordID: wordID, kind: kind, lastMissedAt: date))
        }
        return mistakes
    }

    func toggleFavorite(_ id: String) {
        var selected = favorites
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else {
            selected.append(id)
        }
        write(selected, for: "alef.favoriteWords.v1")
    }

    func recordStudy(on date: Date = .now) {
        var stats = statistics
        stats.record(on: date)
        write(stats, for: "alef.studyStats.v1")
    }

    func recordBestAnswerCombo(_ combo: Int) {
        guard combo > achievementProgress.bestAnswerCombo else { return }
        write(combo, for: Self.bestAnswerComboKey)
    }

    func read<Value: Decodable>(_ key: String, default defaultValue: Value) -> Value {
        observeKey(key)
        return decodeEntry(key, default: defaultValue)
    }

    private func decodeEntry<Value: Decodable>(_ key: String, default defaultValue: Value) -> Value {
        guard let data = entries[key] else { return defaultValue }
        if let cached = readCache[key], cached.0 == data, let typed = cached.1 as? Value {
            return typed
        }
        guard let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return defaultValue
        }
        readCache[key] = (data, value)
        return value
    }

    private func observeKey(_ key: String) {
        switch key {
        case "alef.activeView.v1": _ = activeViewVersion
        case "alef.selectedLetterId.v1": _ = selectedLetterVersion
        case "alef.displayConfig.v1": _ = displayConfigVersion
        case "alef.wordsState.v1": _ = wordsStateVersion
        case "alef.flashcardState.v1": _ = flashcardStateVersion
        case "alef.native.phraseFavorites.v1": _ = phraseFavoritesVersion
        default: _ = otherKeyVersion
        }
    }

    func write<Value: Encodable>(_ value: Value, for key: String) {
        update { entries, encoder in entries[key] = try encoder.encode(value) }
    }

    func completeLegacyMigration(_ raw: [String: String]) {
        var migrated = entries
        for (key, value) in raw where migrated[key] == nil && key.hasPrefix("alef.") {
            let data = Data(value.utf8)
            guard (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil,
                  (try? validateBackupEntry(key, data: data)) != nil else { continue }
            migrated[key] = data
        }
        saveLocalEntries(migrated)
        defaults.set(true, forKey: Self.migrationKey)
    }

    func exportBackup() throws -> Data {
        var document: [String: Any] = [:]
        for (key, data) in entries where key != StudySyncMerger.itemVersionsKey {
            document[key] = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        }
        return try JSONSerialization.data(withJSONObject: [
            "app": "Alef",
            "version": 1,
            "exportedAt": ISO8601DateFormatter().string(from: .now),
            "data": document
        ], options: [.prettyPrinted, .sortedKeys])
    }

    func previewBackup(_ data: Data) throws -> [String: Data] {
        var restored = try decodeBackupEntries(data)
        // A backup made before native appearance overrides can still restore its theme.
        if restored[Self.themeKey] != nil, restored[Self.appearanceKey] == nil, appearanceOverride != .manual {
            restored[Self.appearanceKey] = try JSONEncoder().encode(AppearanceOverride.manual)
        }
        return restored
    }

    func backupExportDate(_ data: Data) -> Date? {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return (root?["exportedAt"] as? String).flatMap(Self.parseIsoDate)
    }

    private func decodeBackupEntries(_ data: Data) throws -> [String: Data] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["app"] as? String == "Alef", root["version"] as? Int == 1,
              let values = root["data"] as? [String: Any] else { throw BackupError.invalid }

        var restored: [String: Data] = [:]
        for (key, value) in values where key.hasPrefix("alef.") {
            let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
            try validateBackupEntry(key, data: data)
            restored[key] = data
        }
        guard !restored.isEmpty else { throw BackupError.invalid }
        return restored
    }

    func backupRestoreEntries(_ backup: [String: Data], mode: BackupRestoreMode) -> [String: Data] {
        let incoming = backup.filter { $0.key != StudySyncMerger.itemVersionsKey }
        let hasIncomingLearning = incoming.keys.contains(where: Self.learningBackupKeys.contains)
        if mode == .restoreSnapshot {
            let base = hasIncomingLearning ? entries.filter { !Self.learningBackupKeys.contains($0.key) } : entries
            return base.merging(incoming) { _, restored in restored }
        }

        let hasLocalLearning = dailyVocabulary.hasStarted || statistics.totalReviews > 0
            || !wordMastery.isEmpty || !letterMastery.isEmpty || !schedule.isEmpty || !letterSchedule.isEmpty
            || !wordMistakes.isEmpty || !earnedAchievements.isEmpty || achievementProgress.bestAnswerCombo > 0
        guard hasLocalLearning else {
            let base = hasIncomingLearning ? entries.filter { !Self.learningBackupKeys.contains($0.key) } : entries
            return base.merging(incoming) { current, _ in current }
        }
        var restored = entries.merging(incoming.filter { !Self.learningBackupKeys.contains($0.key) }) { current, _ in current }
        for (masteryKey, scheduleKey) in [("alef.wordMastery.v1", "alef.wordSrs.v1"), ("alef.mastery.v1", Self.letterScheduleKey)] {
            var knownIDs = Set(backupRecords(entries[masteryKey]).keys).union(backupRecords(entries[scheduleKey]).keys)
            if masteryKey == "alef.wordMastery.v1" {
                let inProgress = dailyVocabulary.groups.filter { $0.hasStarted && !$0.isComplete }
                knownIDs.formUnion(inProgress.flatMap(\.wordIds))
            }
            for key in [masteryKey, scheduleKey] {
                let missing = backupRecords(incoming[key]).filter { !knownIDs.contains($0.key) }
                let merged = backupRecords(entries[key]).merging(missing) { current, _ in current }
                if !missing.isEmpty, let data = try? JSONSerialization.data(withJSONObject: merged, options: .sortedKeys) {
                    restored[key] = data
                }
            }
        }
        return restored
    }

    func backupChanges(_ backup: [String: Data], mode: BackupRestoreMode = .keepCurrent) -> [String] {
        changedBackupKeys(from: entries, to: backupRestoreEntries(backup, mode: mode)).sorted()
    }

    func backupRecordChanges(_ key: String, restored: Data?) -> (added: Int, replaced: Int, removed: Int)? {
        guard ["alef.wordMastery.v1", "alef.wordSrs.v1", "alef.mastery.v1", Self.letterScheduleKey].contains(key) else {
            return nil
        }
        let before = backupRecords(entries[key])
        let after = backupRecords(restored)
        let replaced = before.keys.filter { id in
            guard let current = before[id], let incoming = after[id],
                  let a = try? JSONSerialization.data(withJSONObject: current, options: [.fragmentsAllowed, .sortedKeys]),
                  let b = try? JSONSerialization.data(withJSONObject: incoming, options: [.fragmentsAllowed, .sortedKeys])
            else { return false }
            return a != b
        }.count
        return (after.keys.filter { before[$0] == nil }.count, replaced, before.keys.filter { after[$0] == nil }.count)
    }

    private func backupRecords(_ data: Data?) -> [String: Any] {
        guard let data else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private func changedBackupKeys(from oldEntries: [String: Data], to newEntries: [String: Data]) -> Set<String> {
        Set(oldEntries.keys).union(newEntries.keys).filter { key in
            guard key != StudySyncMerger.itemVersionsKey else { return false }
            guard let old = oldEntries[key], let new = newEntries[key] else { return true }
            return canonicalJSON(old) != canonicalJSON(new)
        }
    }

    private func canonicalJSON(_ data: Data) -> Data {
        do {
            let value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            return try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        } catch {
            return data
        }
    }

    func applyBackup(_ backup: [String: Data], mode: BackupRestoreMode = .keepCurrent) {
        let restored = backupRestoreEntries(backup, mode: mode)
        var affectedKeys = changedBackupKeys(from: entries, to: restored)
        guard !affectedKeys.isEmpty else { return }
        // Restored study records can unlock achievements that were absent from older backups.
        if !affectedKeys.isDisjoint(with: Self.achievementInputKeys) {
            affectedKeys.insert(StudyAchievement.storageKey)
        }
        let previous = entries.filter { affectedKeys.contains($0.key) }
        let absent = affectedKeys.filter { entries[$0] == nil }.sorted()
        saveLocalEntries(restored)
        let appliedLearning = affectedKeys.isDisjoint(with: Self.learningBackupKeys)
            ? nil : entries.filter { Self.learningBackupKeys.contains($0.key) }
        let undo = BackupUndo(previous: previous, absent: absent, applied: entries.filter { affectedKeys.contains($0.key) },
                              appliedLearning: appliedLearning)
        guard let backupData = try? JSONEncoder().encode(undo) else { return }
        restorePoint = undo
        defaults.set(backupData, forKey: Self.restoreKey)
    }

    @discardableResult
    func undoBackup() -> Bool {
        guard let restorePoint, let applied = restorePoint.applied else { return false }
        let affected = Set(restorePoint.previous.keys).union(restorePoint.absent)
        let current = entries.filter { affected.contains($0.key) }
        guard changedBackupKeys(from: current, to: applied).isEmpty else { return false }
        if let appliedLearning = restorePoint.appliedLearning {
            let currentLearning = entries.filter { Self.learningBackupKeys.contains($0.key) }
            guard changedBackupKeys(from: currentLearning, to: appliedLearning).isEmpty else { return false }
        }
        var restored = entries.merging(restorePoint.previous) { _, incoming in incoming }
        for key in restorePoint.absent { restored.removeValue(forKey: key) }
        saveLocalEntries(restored)
        self.restorePoint = nil
        defaults.removeObject(forKey: Self.restoreKey)
        return true
    }

    func syncSnapshot() -> [String: Data] {
        entries.filter { !Self.nonSyncedKeys.contains($0.key) }
    }

    func applySyncedEntries(_ synced: [String: Data], updatedAt: Int64, syncDate: Date = .now) {
        var nextEntries = entries.filter { Self.nonSyncedKeys.contains($0.key) }
        for (key, value) in synced where !Self.nonSyncedKeys.contains(key) {
            nextEntries[key] = value
        }
        if let encodedBackup = try? JSONEncoder().encode(Int64(syncDate.timeIntervalSince1970 * 1_000)) {
            nextEntries[Self.lastBackupAtKey] = encodedBackup
        }
        readCache.removeAll()
        entries = nextEntries
        refreshCachedState(changedKeys: nil)
        observeSyncTimestamp(updatedAt)
        save()
    }

    func encodeSyncDocument(entries source: [String: Data], updatedAt: Int64) throws -> Data {
        var document: [String: Any] = [:]
        for (key, data) in source where !Self.nonSyncedKeys.contains(key) {
            document[key] = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        }
        let date = Date(timeIntervalSince1970: Double(updatedAt) / 1_000)
        return try JSONSerialization.data(withJSONObject: [
            "app": "Alef",
            "version": 1,
            "exportedAt": ISO8601DateFormatter().string(from: date),
            "updatedAt": updatedAt,
            "data": document
        ], options: [.prettyPrinted, .sortedKeys])
    }

    func parseSyncDocument(_ data: Data) throws -> (entries: [String: Data], updatedAt: Int64) {
        let parsed = try decodeBackupEntries(data)
        let synced = parsed.filter { !Self.nonSyncedKeys.contains($0.key) }
        guard !synced.isEmpty else { throw BackupError.invalid }
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let updatedAt: Int64
        if let number = root?["updatedAt"] as? NSNumber {
            updatedAt = max(0, number.int64Value)
        } else if let exportedAt = root?["exportedAt"] as? String,
                  let parsedDate = Self.parseIsoDate(exportedAt) {
            updatedAt = max(0, Int64(parsedDate.timeIntervalSince1970 * 1_000))
        } else {
            updatedAt = 0
        }
        return (synced, updatedAt)
    }

    private static func parseIsoDate(_ raw: String) -> Date? {
        let standard = ISO8601DateFormatter()
        if let date = standard.date(from: raw) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw)
    }

    private func save() {
        defaults.set(entries, forKey: Self.storageKey)
    }

    private func update(_ apply: (inout [String: Data], JSONEncoder) throws -> Void) {
        var updated = entries
        guard (try? apply(&updated, JSONEncoder())) != nil else { return }
        saveLocalEntries(updated)
    }

    private func hasSyncableDifference(from old: [String: Data], to new: [String: Data]) -> Bool {
        let keys = Set(old.keys).union(new.keys).subtracting(Self.nonSyncedKeys)
        return keys.contains { key in
            switch (old[key], new[key]) {
            case let (a?, b?):
                if a == b { return false }
                return canonicalJSON(a) != canonicalJSON(b)
            case (nil, nil): return false
            default: return true
            }
        }
    }

    func observeSyncTimestamp(_ timestamp: Int64) {
        guard timestamp > localUpdatedAt else { return }
        localUpdatedAt = timestamp
        defaults.set(NSNumber(value: timestamp), forKey: Self.localUpdatedAtKey)
    }

    private func saveLocalEntries(_ proposed: [String: Data]) {
        let allKeys = Set(entries.keys).union(proposed.keys)
        let changedKeys = Set(allKeys.filter { entries[$0] != proposed[$0] })
        guard !changedKeys.isEmpty else { return }

        var updated = proposed
        let hasSyncableChanges = !changedKeys.subtracting(Self.nonSyncedKeys).isEmpty
        if hasSyncableChanges && hasSyncableDifference(from: entries, to: updated) {
            let now = Int64(Date.now.timeIntervalSince1970 * 1_000)
            let next = localUpdatedAt < Int64.max ? localUpdatedAt + 1 : localUpdatedAt
            let timestamp = max(now, next)
            StudySyncMerger.stampChanges(from: entries, to: &updated, at: timestamp)
            observeSyncTimestamp(timestamp)
            syncRevision += 1
        }
        for key in changedKeys {
            readCache.removeValue(forKey: key)
        }
        entries = updated
        refreshCachedState(changedKeys: changedKeys)
        save()
    }

    private func refreshCachedState(changedKeys: Set<String>?) {
        func touches(_ keys: String...) -> Bool {
            guard let changedKeys else { return true }
            return keys.contains(where: changedKeys.contains)
        }

        if touches(Self.appearanceKey, Self.themeKey) {
            let resolvedTheme: StudyTheme = switch appearanceOverride {
            case .system: .system
            case .white: .white
            case .manual: decodeEntry(Self.themeKey, default: .system)
            }
            if cachedTheme != resolvedTheme { cachedTheme = resolvedTheme }
        }
        if touches("alef.mastery.v1") {
            let val: [String: Mastery] = decodeEntry("alef.mastery.v1", default: [:])
            if cachedLetterMastery != val { cachedLetterMastery = val }
        }
        if touches(Self.letterScheduleKey) {
            let val: [String: ReviewSchedule] = decodeEntry(Self.letterScheduleKey, default: [:])
            if cachedLetterSchedule != val { cachedLetterSchedule = val }
        }
        if touches("alef.wordMastery.v1") {
            let val: [String: Mastery] = decodeEntry("alef.wordMastery.v1", default: [:])
            if cachedWordMastery != val { cachedWordMastery = val }
        }
        if touches("alef.wordSrs.v1") {
            let val: [String: ReviewSchedule] = decodeEntry("alef.wordSrs.v1", default: [:])
            if cachedSchedule != val { cachedSchedule = val }
        }
        if touches("alef.favoriteWords.v1") {
            let val: [String] = decodeEntry("alef.favoriteWords.v1", default: [])
            if cachedFavorites != val { cachedFavorites = val }
        }
        if touches("alef.studyStats.v1") {
            let val: StudyStatistics = decodeEntry("alef.studyStats.v1", default: StudyStatistics())
            if cachedStatistics != val { cachedStatistics = val }
        }
        if touches(DailyVocabularyPlan.storageKey) {
            let decoded = decodeEntry(DailyVocabularyPlan.storageKey, default: DailyVocabularyPlan())
            let val = decoded.isValid ? decoded : DailyVocabularyPlan()
            if cachedDailyVocabulary != val { cachedDailyVocabulary = val }
        }
        if touches(Self.lastBackupAtKey) {
            let val: Int64? = entries[Self.lastBackupAtKey].flatMap { try? JSONDecoder().decode(Int64.self, from: $0) }
            if cachedLastBackupAt != val { cachedLastBackupAt = val }
        }
        if touches("alef.speechRate.v1") {
            let val: Double = decodeEntry("alef.speechRate.v1", default: 1)
            if cachedSpeechRate != val { cachedSpeechRate = val }
        }
        if touches("alef.native.feedback.v1") {
            let val: Bool = decodeEntry("alef.native.feedback.v1", default: true)
            if cachedFeedbackEnabled != val { cachedFeedbackEnabled = val }
        }
        if touches("alef.native.haptics.v1") {
            let val: Bool = decodeEntry("alef.native.haptics.v1", default: true)
            if cachedHapticsEnabled != val { cachedHapticsEnabled = val }
        }
        if touches("alef.native.recordings.v1") {
            let val: Bool = decodeEntry("alef.native.recordings.v1", default: true)
            if cachedPrefersRecordings != val { cachedPrefersRecordings = val }
        }
        if touches("alef.order.v1") {
            let val = decodeEntry("alef.order.v1", default: "rtl") == "rtl"
            if cachedAlphabetFromRight != val { cachedAlphabetFromRight = val }
        }
        if touches(ReminderPreferences.storageKey) {
            let stored = decodeEntry(ReminderPreferences.storageKey, default: ReminderPreferences())
            let val = stored.isValid ? stored : ReminderPreferences()
            if cachedReminderPreferences != val { cachedReminderPreferences = val }
        }
        if touches(StudyWordMistake.storageKey) {
            let val: [StudyWordMistake] = decodeEntry(StudyWordMistake.storageKey, default: [])
            if cachedWordMistakes != val { cachedWordMistakes = val }
        }
        if touches(StudyReviewBatch.storageKey) {
            let val: StudyReviewBatch? = decodeEntry(StudyReviewBatch.storageKey, default: nil)
            if cachedReviewBatch != val { cachedReviewBatch = val }
        }

        if let changedKeys {
            for key in changedKeys {
                switch key {
                case "alef.activeView.v1": activeViewVersion &+= 1
                case "alef.selectedLetterId.v1": selectedLetterVersion &+= 1
                case "alef.displayConfig.v1": displayConfigVersion &+= 1
                case "alef.wordsState.v1": wordsStateVersion &+= 1
                case "alef.flashcardState.v1": flashcardStateVersion &+= 1
                case "alef.native.phraseFavorites.v1": phraseFavoritesVersion &+= 1
                case Self.appearanceKey, Self.themeKey, "alef.mastery.v1", Self.letterScheduleKey,
                     "alef.wordMastery.v1", "alef.wordSrs.v1", "alef.favoriteWords.v1",
                     "alef.studyStats.v1", DailyVocabularyPlan.storageKey, Self.lastBackupAtKey,
                     "alef.speechRate.v1", "alef.native.feedback.v1", "alef.native.haptics.v1",
                     "alef.native.recordings.v1", "alef.order.v1", ReminderPreferences.storageKey,
                     StudyWordMistake.storageKey, StudyReviewBatch.storageKey, StudyAchievement.storageKey,
                     Self.bestAnswerComboKey:
                    break
                default:
                    otherKeyVersion &+= 1
                }
            }
        }

        if touches(StudyAchievement.storageKey)
            || changedKeys?.isDisjoint(with: Self.achievementInputKeys) == false {
            var measured = achievementProgress
            if touches("alef.mastery.v1") {
                measured.masteredLetters = cachedLetterMastery.lazy.filter {
                    $0.value == .mastered && self.letterIDs.contains($0.key)
                }.count
            }
            if touches("alef.wordMastery.v1") {
                measured.masteredWords = cachedWordMastery.lazy.filter {
                    $0.value == .mastered && self.wordIDs.contains($0.key)
                }.count
            }
            measured.practiceCount = cachedStatistics.totalReviews
            // A stored streak can qualify even if it has ended by the time the app is updated.
            measured.streakDays = cachedStatistics.streakDays
            measured.completedVocabularyGroups = cachedDailyVocabulary.completedCount
            if touches(Self.bestAnswerComboKey) {
                measured.bestAnswerCombo = max(0, decodeEntry(Self.bestAnswerComboKey, default: 0))
            }
            if achievementProgress != measured { achievementProgress = measured }
            unlockAchievements(using: measured)
        }
    }

    private func unlockAchievements(using measured: StudyAchievementProgress) {
        let key = StudyAchievement.storageKey
        let stored = decodeEntry(key, default: [String]())
        var unlocked = Set(stored)
        for achievement in StudyAchievement.allCases where measured.value(for: achievement) >= achievement.goal {
            unlocked.insert(achievement.rawValue)
        }
        let known = Set(unlocked.compactMap(StudyAchievement.init(rawValue:)))
        if earnedAchievements != known { earnedAchievements = known }
        if unlocked.count > stored.count, let data = try? JSONEncoder().encode(unlocked.sorted()) {
            entries[key] = data
        }
    }

    private func validateBackupEntry(_ key: String, data: Data) throws {
        let decoder = JSONDecoder()
        switch key {
        case "alef.mastery.v1", "alef.wordMastery.v1":
            _ = try decoder.decode([String: Mastery].self, from: data)
        case "alef.favoriteWords.v1", "alef.native.phraseFavorites.v1":
            _ = try decoder.decode([String].self, from: data)
        case "alef.wordSrs.v1", Self.letterScheduleKey:
            let dates = try decoder.decode([String: ReviewSchedule].self, from: data)
            guard dates.values.allSatisfy(\.isValid) else { throw BackupError.invalid }
        case ReminderPreferences.storageKey:
            guard try decoder.decode(ReminderPreferences.self, from: data).isValid else { throw BackupError.invalid }
        case DailyVocabularyPlan.storageKey:
            guard try decoder.decode(DailyVocabularyPlan.self, from: data).isValid else { throw BackupError.invalid }
        case StudyWordMistake.storageKey:
            let mistakes = try decoder.decode([StudyWordMistake].self, from: data)
            guard mistakes.allSatisfy({ !$0.wordID.isEmpty && $0.count > 0 }),
                  Set(mistakes.map(\.id)).count == mistakes.count else { throw BackupError.invalid }
        case StudyReviewBatch.storageKey:
            guard try decoder.decode(StudyReviewBatch.self, from: data).isValid else { throw BackupError.invalid }
        case StudyAchievement.storageKey:
            let ids = try decoder.decode([String].self, from: data)
            guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else { throw BackupError.invalid }
        case Self.bestAnswerComboKey:
            guard try decoder.decode(Int.self, from: data) >= 0 else { throw BackupError.invalid }
        case "alef.studyStats.v1":
            let stats = try decoder.decode(StudyStatistics.self, from: data)
            guard stats.streakDays >= 0, stats.todayReviews >= 0, stats.totalReviews >= 0 else { throw BackupError.invalid }
        case Self.themeKey, Self.dayThemeKey:
            let theme = try decoder.decode(StudyTheme.self, from: data)
            guard theme != .system, theme != .white else { throw BackupError.invalid }
        case Self.appearanceKey:
            _ = try decoder.decode(AppearanceOverride.self, from: data)
        case "alef.speechRate.v1":
            let rate = try decoder.decode(Double.self, from: data)
            guard (0.5...1.5).contains(rate) else { throw BackupError.invalid }
        case "alef.order.v1":
            let order = try decoder.decode(String.self, from: data)
            guard ["rtl", "ltr"].contains(order) else { throw BackupError.invalid }
        case "alef.native.feedback.v1", "alef.native.recordings.v1", "alef.native.haptics.v1":
            _ = try decoder.decode(Bool.self, from: data)
        case StudySyncMerger.itemVersionsKey:
            let versions = try decoder.decode([String: [String: Int64]].self, from: data)
            guard versions.values.allSatisfy({ $0.values.allSatisfy { $0 >= 0 } }) else { throw BackupError.invalid }
        case Self.lastBackupAtKey:
            let timestamp = try decoder.decode(Int64.self, from: data)
            guard timestamp >= 0 else { throw BackupError.invalid }
        case "alef.displayConfig.v1":
            _ = try decoder.decode([String: Bool].self, from: data)
        default:
            break
        }
    }

    private enum BackupError: LocalizedError {
        case invalid
        var errorDescription: String? { "此文件不是有效的 Alef 备份。" }
    }
}
