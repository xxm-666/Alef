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

    let nextReviewAt: Int64
    let intervalDays: Int
    let easeFactor: Double
    let repetitions: Int
    let lapses: Int
    let lastReview: Attempt?

    enum CodingKeys: String, CodingKey {
        case nextReviewAt, intervalDays, easeFactor, repetitions, lapses, lastReview
    }

    init(nextReviewAt: Int64, intervalDays: Int, easeFactor: Double = defaultEase,
         repetitions: Int = 0, lapses: Int = 0, lastReview: Attempt? = nil) {
        self.nextReviewAt = nextReviewAt
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.lapses = lapses
        self.lastReview = lastReview
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
        nextReviewAt >= 0 && intervalDays >= 0 && easeFactor.isFinite
            && (1.0...5.0).contains(easeFactor) && repetitions >= 0 && lapses >= 0
    }

    static func next(from current: ReviewSchedule?, grade: ReviewGrade, on date: Date,
                     calendar: Calendar = .current, recordsReview: Bool = true) -> ReviewSchedule {
        let ease = min(maxEase, max(minEase, current?.easeFactor ?? defaultEase))
        let reps = max(0, current?.repetitions ?? 0)
        let lapses = max(0, current?.lapses ?? 0)
        let prevInterval = max(1, current?.intervalDays ?? 1)

        let outcome: (interval: Int, newEase: Double, newReps: Int, newLapses: Int)
        switch grade {
        case .again:
            outcome = (1, max(minEase, ease - 0.2), 0, lapses + 1)
        case .hard:
            let interval = reps == 0
                ? 1
                : min(maxIntervalDays, max(prevInterval + 1, Int(round(Double(prevInterval) * 1.2))))
            outcome = (interval, max(minEase, ease - 0.15), reps + 1, lapses)
        case .good:
            let interval: Int = switch reps {
            case 0: 3
            case 1: 7
            default: min(maxIntervalDays, max(prevInterval + 1, Int(round(Double(prevInterval) * ease))))
            }
            outcome = (interval, ease, reps + 1, lapses)
        case .easy:
            let interval = reps == 0
                ? 5
                : min(maxIntervalDays, max(prevInterval + 2, Int(round(Double(prevInterval) * ease * 1.3))))
            outcome = (interval, min(maxEase, ease + 0.15), reps + 1, lapses)
        }

        let nextDate = calendar.date(byAdding: .day, value: outcome.interval, to: date) ?? date
        return ReviewSchedule(
            nextReviewAt: Int64(nextDate.timeIntervalSince1970 * 1_000),
            intervalDays: outcome.interval,
            easeFactor: outcome.newEase,
            repetitions: outcome.newReps,
            lapses: outcome.newLapses,
            lastReview: recordsReview ? Attempt(date: date, grade: grade) : current?.lastReview
        )
    }

    static func manual(mastery: Mastery, existing: ReviewSchedule?, on date: Date,
                       calendar: Calendar = .current) -> ReviewSchedule? {
        switch mastery {
        case .unlearned:
            return nil
        case .learning:
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return ReviewSchedule(
                nextReviewAt: Int64(nextDate.timeIntervalSince1970 * 1_000),
                intervalDays: 1,
                easeFactor: existing?.easeFactor ?? defaultEase,
                repetitions: 0,
                lapses: existing?.lapses ?? 0,
                lastReview: existing?.lastReview
            )
        case .mastered:
            if let existing, !existing.isDue(at: date), existing.repetitions >= 1 {
                return existing
            }
            let nextDate = calendar.date(byAdding: .day, value: 3, to: date) ?? date
            return ReviewSchedule(
                nextReviewAt: Int64(nextDate.timeIntervalSince1970 * 1_000),
                intervalDays: 3,
                easeFactor: existing?.easeFactor ?? defaultEase,
                repetitions: 1,
                lapses: existing?.lapses ?? 0,
                lastReview: existing?.lastReview
            )
        }
    }
}

struct StudyStatistics: Codable {
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

struct DailySpellingAnswer: Codable, Equatable {
    let input: String
    let correct: Bool
}

struct DailyVocabularyGroup: Codable, Equatable, Identifiable {
    let wordIds: [String]
    var studied = 0
    var answers: [DailySpellingAnswer] = []
    var feedbackPending = false

    var id: String { wordIds.first ?? "" }
    var hasStarted: Bool { studied > 0 }
    var isComplete: Bool { answers.count == wordIds.count && !feedbackPending }
    var correctCount: Int { answers.filter(\.correct).count }
    var status: String {
        if isComplete { return "拼对 \(correctCount) / \(wordIds.count)" }
        if studied == wordIds.count { return "拼写 \(answers.count) / \(wordIds.count)" }
        return hasStarted ? "认读 \(studied) / \(wordIds.count)" : "先认读，再拼写"
    }
}

struct DailyVocabularyPlan: Codable, Equatable {
    static let storageKey = "alef.dailyVocabulary.v1"
    static let groupOptions = [1, 2, 3]
    static let groupSize = 5

    var day = ""
    var groupsPerDay = 2
    var groups: [DailyVocabularyGroup] = []

    var completedCount: Int { groups.filter(\.isComplete).count }
    var nextGroup: DailyVocabularyGroup? { groups.first { !$0.isComplete } }
    var hasStarted: Bool { groups.contains(where: \.hasStarted) }

    static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    func plan(for date: Date, words: [StudyWord], mastery: [String: Mastery], schedule: [String: ReviewSchedule]) -> Self {
        let today = Self.dayKey(for: date)
        let available = Set(words.map(\.id))
        let valid = groups.filter { $0.wordIds.allSatisfy(available.contains) }
        if day == today, valid.count == groups.count { return self }

        var assignments = valid.filter { day == today || ($0.hasStarted && !$0.isComplete) }
        let assigned = Set(assignments.flatMap(\.wordIds))
        let newIds = words.filter { !assigned.contains($0.id) && mastery[$0.id] != .mastered && schedule[$0.id] == nil }.map(\.id)
        for offset in stride(from: 0, to: newIds.count, by: Self.groupSize) {
            guard assignments.count < groupsPerDay else { break }
            assignments.append(DailyVocabularyGroup(wordIds: Array(newIds.dropFirst(offset).prefix(Self.groupSize))))
        }
        return Self(day: today, groupsPerDay: groupsPerDay, groups: assignments)
    }

    var isValid: Bool {
        guard Self.groupOptions.contains(groupsPerDay), groups.count <= Self.groupOptions.count,
              day.isEmpty ? groups.isEmpty : day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil
        else { return false }
        var ids = Set<String>()
        var foundIncomplete = false
        for group in groups {
            guard (1...Self.groupSize).contains(group.wordIds.count),
                  (0...group.wordIds.count).contains(group.studied), group.answers.count <= group.wordIds.count,
                  group.studied == group.wordIds.count || group.answers.isEmpty,
                  !group.feedbackPending || !group.answers.isEmpty,
                  group.answers.allSatisfy({ !$0.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  !foundIncomplete || !group.hasStarted,
                  group.wordIds.allSatisfy({ !$0.isEmpty && ids.insert($0).inserted })
            else { return false }
            if !group.isComplete { foundIncomplete = true }
        }
        return true
    }
}

@Observable final class StudyProgress {
    struct BackupUndo: Codable {
        let previous: [String: Data]
        let absent: [String]
    }

    private static let storageKey = "alef.native.progress.v1"
    private static let restoreKey = "alef.native.restore.v1"
    private static let migrationKey = "alef.native.didReadWebStorage.v1"
    private static let localUpdatedAtKey = "alef.sync.localUpdatedAt.v1"
    static let letterScheduleKey = "alef.native.letterSrs.v1"
    static let lastBackupAtKey = "alef.native.lastBackupAt.v1"
    static let nonSyncedKeys: Set<String> = [lastBackupAtKey, "alef.activeView.v1", "alef.selectedLetterId.v1"]
    static let appearanceKey = "alef.native.appearance.v1"
    static let themeKey = "alef.theme.v1"
    static let dayThemeKey = "alef.dayTheme.v1"
    private enum AppearanceOverride: String, Codable {
        case manual, system, white
    }

    private let defaults: UserDefaults
    private var entries: [String: Data]
    private(set) var restorePoint: BackupUndo?
    private(set) var syncRevision: Int = 0
    private(set) var localUpdatedAt: Int64 = 0
    var widgetRequest: StudyWidgetRoute?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.dictionary(forKey: Self.storageKey) as? [String: Data] ?? [:]
        restorePoint = defaults.data(forKey: Self.restoreKey).flatMap { try? JSONDecoder().decode(BackupUndo.self, from: $0) }
        localUpdatedAt = (defaults.object(forKey: Self.localUpdatedAtKey) as? NSNumber)?.int64Value ?? 0
    }

    var letterMastery: [String: Mastery] { read("alef.mastery.v1", default: [:]) }
    var letterSchedule: [String: ReviewSchedule] { read(Self.letterScheduleKey, default: [:]) }
    var wordMastery: [String: Mastery] { read("alef.wordMastery.v1", default: [:]) }
    var schedule: [String: ReviewSchedule] { read("alef.wordSrs.v1", default: [:]) }
    var favorites: [String] { read("alef.favoriteWords.v1", default: []) }
    var statistics: StudyStatistics { read("alef.studyStats.v1", default: StudyStatistics()) }
    var dailyVocabulary: DailyVocabularyPlan {
        let plan = read(DailyVocabularyPlan.storageKey, default: DailyVocabularyPlan())
        return plan.isValid ? plan : DailyVocabularyPlan()
    }
    var needsLegacyMigration: Bool { !defaults.bool(forKey: Self.migrationKey) }

    var hasMeaningfulData: Bool {
        !wordMastery.isEmpty || !letterMastery.isEmpty || !schedule.isEmpty
            || !letterSchedule.isEmpty || !favorites.isEmpty || statistics.totalReviews > 0
    }

    var lastBackupAt: Int64? {
        entries[Self.lastBackupAtKey].flatMap { try? JSONDecoder().decode(Int64.self, from: $0) }
    }

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

    private var appearanceOverride: AppearanceOverride { read(Self.appearanceKey, default: .manual) }

    var theme: StudyTheme {
        get {
            switch appearanceOverride {
            case .system: .system
            case .white: .white
            case .manual: read(Self.themeKey, default: .system)
            }
        }
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
        get { read("alef.speechRate.v1", default: 1) }
        set { write(newValue, for: "alef.speechRate.v1") }
    }

    var feedbackEnabled: Bool {
        get { read("alef.native.feedback.v1", default: true) }
        set { write(newValue, for: "alef.native.feedback.v1") }
    }

    var hapticsEnabled: Bool {
        get { read("alef.native.haptics.v1", default: true) }
        set { write(newValue, for: "alef.native.haptics.v1") }
    }

    var prefersRecordings: Bool {
        get { read("alef.native.recordings.v1", default: true) }
        set { write(newValue, for: "alef.native.recordings.v1") }
    }

    var alphabetFromRight: Bool {
        get { read("alef.order.v1", default: "rtl") == "rtl" }
        set { write(newValue ? "rtl" : "ltr", for: "alef.order.v1") }
    }

    var reminderPreferences: ReminderPreferences {
        get {
            let stored = read(ReminderPreferences.storageKey, default: ReminderPreferences())
            return stored.isValid ? stored : ReminderPreferences()
        }
        set {
            guard newValue.isValid else { return }
            write(newValue, for: ReminderPreferences.storageKey)
        }
    }

    func setLetter(_ id: String, mastery: Mastery, date: Date = .now) {
        if (letterMastery[id] ?? .unlearned) == mastery,
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
           (schedule[id] == nil) == (mastery == .unlearned) { return }
        saveManual(id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1", mastery: mastery, date: date)
    }

    func completeReview(_ id: String, grade: ReviewGrade, isRetry: Bool = false, date: Date = .now) {
        saveReview(id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1",
                   base: schedule[id], grade: grade, recordStats: true, date: date, isRetry: isRetry)
    }

    func completeReview(_ id: String, correct: Bool, isRetry: Bool = false, date: Date = .now) {
        let recovering = schedule[id].map { $0.lapses > 0 && $0.intervalDays == 1 } ?? false
        let grade: ReviewGrade = correct ? (recovering ? .hard : .good) : .again
        completeReview(id, grade: grade, isRetry: isRetry, date: date)
    }

    func dailyVocabularyPlan(words: [StudyWord], date: Date = .now) -> DailyVocabularyPlan {
        dailyVocabulary.plan(for: date, words: words, mastery: wordMastery, schedule: schedule)
    }

    func prepareDailyVocabulary(words: [StudyWord], date: Date = .now) {
        let current = dailyVocabulary
        let plan = current.plan(for: date, words: words, mastery: wordMastery, schedule: schedule)
        if current != plan { write(plan, for: DailyVocabularyPlan.storageKey) }
    }

    func setDailyVocabularyLimit(_ count: Int, words: [StudyWord], date: Date = .now) {
        guard DailyVocabularyPlan.groupOptions.contains(count) else { return }
        var plan = dailyVocabularyPlan(words: words, date: date)
        guard plan.groupsPerDay != count else { return }
        plan.groupsPerDay = count
        if !plan.hasStarted {
            plan.day = ""
            plan.groups = []
            plan = plan.plan(for: date, words: words, mastery: wordMastery, schedule: schedule)
        }
        write(plan, for: DailyVocabularyPlan.storageKey)
    }

    @discardableResult
    func advanceDailyVocabulary(_ expected: DailyVocabularyGroup, day: String) -> Bool {
        var plan = dailyVocabulary
        guard plan.day == day, plan.nextGroup == expected,
              let index = plan.groups.firstIndex(of: expected) else { return false }
        if expected.studied < expected.wordIds.count {
            plan.groups[index].studied += 1
        } else if expected.feedbackPending {
            plan.groups[index].feedbackPending = false
        } else {
            return false
        }
        write(plan, for: DailyVocabularyPlan.storageKey)
        return true
    }

    func answerDailyVocabulary(_ expected: DailyVocabularyGroup, day: String, word: StudyWord, input: String,
                               date: Date = .now) -> DailySpellingAnswer? {
        var plan = dailyVocabulary
        let answer = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard plan.day == day, plan.nextGroup == expected, let index = plan.groups.firstIndex(of: expected),
              !answer.isEmpty, expected.studied == expected.wordIds.count, !expected.feedbackPending,
              expected.wordIds.indices.contains(expected.answers.count), expected.wordIds[expected.answers.count] == word.id
        else { return nil }
        let attempt = DailySpellingAnswer(input: answer, correct: word.acceptsSpelling(answer))
        plan.groups[index].answers.append(attempt)
        plan.groups[index].feedbackPending = true
        saveReview(word.id, masteryKey: "alef.wordMastery.v1", scheduleKey: "alef.wordSrs.v1",
                   base: schedule[word.id], grade: attempt.correct ? .good : .again,
                   recordStats: true, date: date, dailyPlan: plan)
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

    private func saveReview(_ id: String, masteryKey: String, scheduleKey: String, base: ReviewSchedule?,
                            grade: ReviewGrade, recordStats: Bool, date: Date,
                            dailyPlan: DailyVocabularyPlan? = nil, isRetry: Bool = false) {
        if isRetry {
            recordStudy(on: date)
            return
        }
        var values: [String: Mastery] = read(masteryKey, default: [:])
        var dates: [String: ReviewSchedule] = read(scheduleKey, default: [:])
        values[id] = grade.mastery
        dates[id] = ReviewSchedule.next(from: base, grade: grade, on: date, recordsReview: dailyPlan == nil)
        var stats = statistics
        if recordStats { stats.record(on: date) }
        update { entries, encoder in
            entries[masteryKey] = try encoder.encode(values)
            entries[scheduleKey] = try encoder.encode(dates)
            if recordStats { entries["alef.studyStats.v1"] = try encoder.encode(stats) }
            if let dailyPlan { entries[DailyVocabularyPlan.storageKey] = try encoder.encode(dailyPlan) }
        }
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

    func read<Value: Decodable>(_ key: String, default defaultValue: Value) -> Value {
        guard let data = entries[key], let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return defaultValue
        }
        return value
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

    func backupChanges(_ restored: [String: Data]) -> [String] {
        restored.keys.filter { key in
            guard key != StudySyncMerger.itemVersionsKey else { return false }
            guard let old = entries[key], let new = restored[key] else { return true }
            return canonicalJSON(old) != canonicalJSON(new)
        }.sorted()
    }

    private func canonicalJSON(_ data: Data) -> Data {
        do {
            let value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            return try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        } catch {
            return data
        }
    }

    func applyBackup(_ backup: [String: Data]) {
        let restored = backup.filter { $0.key != StudySyncMerger.itemVersionsKey }
        let previous = entries.filter { restored[$0.key] != nil }
        let absent = restored.keys.filter { entries[$0] == nil }
        let undo = BackupUndo(previous: previous, absent: absent)
        guard let backupData = try? JSONEncoder().encode(undo) else { return }
        restorePoint = undo
        defaults.set(backupData, forKey: Self.restoreKey)
        let merged = entries.merging(restored) { _, incoming in incoming }
        saveLocalEntries(merged)
    }

    func undoBackup() {
        guard let restorePoint else { return }
        var restored = entries.merging(restorePoint.previous) { _, incoming in incoming }
        for key in restorePoint.absent { restored.removeValue(forKey: key) }
        saveLocalEntries(restored)
        self.restorePoint = nil
        defaults.removeObject(forKey: Self.restoreKey)
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
        entries = nextEntries
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
            case let (a?, b?): return canonicalJSON(a) != canonicalJSON(b)
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
        var updated = proposed
        if hasSyncableDifference(from: entries, to: updated) {
            let now = Int64(Date.now.timeIntervalSince1970 * 1_000)
            let next = localUpdatedAt < Int64.max ? localUpdatedAt + 1 : localUpdatedAt
            let timestamp = max(now, next)
            StudySyncMerger.stampChanges(from: entries, to: &updated, at: timestamp)
            observeSyncTimestamp(timestamp)
            syncRevision += 1
        }
        entries = updated
        save()
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
