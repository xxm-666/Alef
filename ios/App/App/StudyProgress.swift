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

struct ReviewSchedule: Codable {
    let nextReviewAt: Int64
    let intervalDays: Int

    var reviewDate: Date { Date(timeIntervalSince1970: Double(nextReviewAt) / 1_000) }
    var isDue: Bool { reviewDate <= .now }

    var displayDate: String {
        let calendar = Calendar.current
        if isDue { return "已到期" }
        if calendar.isDateInToday(reviewDate) { return "今天" }
        if calendar.isDateInTomorrow(reviewDate) { return "明天" }
        return reviewDate.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
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
    // Keep the shared theme keys readable by Alef's web and desktop versions.
    private static let appearanceKey = "alef.native.appearance.v1"
    private enum AppearanceOverride: String, Codable {
        case manual, system, white
    }

    private let defaults: UserDefaults
    private var entries: [String: Data]
    private(set) var restorePoint: BackupUndo?
    var dailyLetterRequest: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.dictionary(forKey: Self.storageKey) as? [String: Data] ?? [:]
        restorePoint = defaults.data(forKey: Self.restoreKey).flatMap { try? JSONDecoder().decode(BackupUndo.self, from: $0) }
    }

    var letterMastery: [String: Mastery] { read("alef.mastery.v1", default: [:]) }
    var wordMastery: [String: Mastery] { read("alef.wordMastery.v1", default: [:]) }
    var schedule: [String: ReviewSchedule] { read("alef.wordSrs.v1", default: [:]) }
    var favorites: [String] { read("alef.favoriteWords.v1", default: []) }
    var statistics: StudyStatistics { read("alef.studyStats.v1", default: StudyStatistics()) }
    var dailyVocabulary: DailyVocabularyPlan {
        let plan = read(DailyVocabularyPlan.storageKey, default: DailyVocabularyPlan())
        return plan.isValid ? plan : DailyVocabularyPlan()
    }
    var needsLegacyMigration: Bool { !defaults.bool(forKey: Self.migrationKey) }

    private var appearanceOverride: AppearanceOverride { read(Self.appearanceKey, default: .manual) }

    var theme: StudyTheme {
        get {
            switch appearanceOverride {
            case .system: .system
            case .white: .white
            case .manual: read("alef.theme.v1", default: .system)
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
                    values.removeValue(forKey: Self.appearanceKey)
                    let theme = try encoder.encode(newValue)
                    values["alef.theme.v1"] = theme
                    if newValue != .dark { values["alef.dayTheme.v1"] = theme }
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

    var prefersRecordings: Bool {
        get { read("alef.native.recordings.v1", default: true) }
        set { write(newValue, for: "alef.native.recordings.v1") }
    }

    var alphabetFromRight: Bool {
        get { read("alef.order.v1", default: "rtl") == "rtl" }
        set { write(newValue ? "rtl" : "ltr", for: "alef.order.v1") }
    }

    func setLetter(_ id: String, mastery: Mastery) {
        var values = letterMastery
        values[id] = mastery
        var stats = statistics
        stats.record(on: .now)
        update { entries, encoder in
            entries["alef.mastery.v1"] = try encoder.encode(values)
            entries["alef.studyStats.v1"] = try encoder.encode(stats)
        }
    }

    func setWord(_ id: String, mastery: Mastery, date: Date = .now) {
        if (wordMastery[id] ?? .unlearned) == mastery,
           (schedule[id] == nil) == (mastery == .unlearned) { return }
        saveWord(id, mastery: mastery, reviewed: false, date: date)
    }

    func completeReview(_ id: String, correct: Bool, date: Date = .now) {
        saveWord(id, mastery: correct ? .mastered : .learning, reviewed: true, date: date)
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
        saveWord(word.id, mastery: attempt.correct ? .mastered : .learning, reviewed: true, date: date, dailyPlan: plan)
        return attempt
    }

    private func saveWord(_ id: String, mastery: Mastery, reviewed: Bool, date: Date, dailyPlan: DailyVocabularyPlan? = nil) {
        var values = wordMastery
        var dates = schedule
        values[id] = mastery
        switch mastery {
        case .unlearned:
            dates.removeValue(forKey: id)
        case .learning, .mastered:
            let previous = reviewed ? dates[id]?.intervalDays ?? 1 : 1
            let interval = mastery == .learning ? 1 : ([3, 7, 14, 30].first { $0 > previous } ?? 30)
            let next = Calendar.current.date(byAdding: .day, value: interval, to: date) ?? date
            dates[id] = ReviewSchedule(nextReviewAt: Int64(next.timeIntervalSince1970 * 1_000), intervalDays: interval)
        }
        var stats = statistics
        stats.record(on: date)
        update { entries, encoder in
            entries["alef.wordMastery.v1"] = try encoder.encode(values)
            entries["alef.wordSrs.v1"] = try encoder.encode(dates)
            entries["alef.studyStats.v1"] = try encoder.encode(stats)
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
        for (key, value) in raw where entries[key] == nil && key.hasPrefix("alef.") {
            let data = Data(value.utf8)
            guard (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil,
                  (try? validateBackupEntry(key, data: data)) != nil else { continue }
            entries[key] = data
        }
        save()
        defaults.set(true, forKey: Self.migrationKey)
    }

    func exportBackup() throws -> Data {
        var document: [String: Any] = [:]
        for (key, data) in entries {
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
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["app"] as? String == "Alef", root["version"] as? Int == 1,
              let values = root["data"] as? [String: Any] else { throw BackupError.invalid }

        var restored: [String: Data] = [:]
        for (key, value) in values where key.hasPrefix("alef.") {
            let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
            try validateBackupEntry(key, data: data)
            restored[key] = data
        }
        // A backup made before native appearance overrides can still restore its theme.
        if restored["alef.theme.v1"] != nil, restored[Self.appearanceKey] == nil, appearanceOverride != .manual {
            restored[Self.appearanceKey] = try JSONEncoder().encode(AppearanceOverride.manual)
        }
        guard !restored.isEmpty else { throw BackupError.invalid }
        return restored
    }

    func backupChanges(_ restored: [String: Data]) -> [String] {
        restored.keys.filter { key in
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

    func applyBackup(_ restored: [String: Data]) {
        let previous = entries.filter { restored[$0.key] != nil }
        let absent = restored.keys.filter { entries[$0] == nil }
        let undo = BackupUndo(previous: previous, absent: absent)
        guard let backupData = try? JSONEncoder().encode(undo) else { return }
        restorePoint = undo
        defaults.set(backupData, forKey: Self.restoreKey)
        entries.merge(restored) { _, incoming in incoming }
        save()
    }

    func undoBackup() {
        guard let restorePoint else { return }
        entries.merge(restorePoint.previous) { _, incoming in incoming }
        for key in restorePoint.absent { entries.removeValue(forKey: key) }
        save()
        self.restorePoint = nil
        defaults.removeObject(forKey: Self.restoreKey)
    }

    private func save() {
        defaults.set(entries, forKey: Self.storageKey)
    }

    private func update(_ apply: (inout [String: Data], JSONEncoder) throws -> Void) {
        var updated = entries
        guard (try? apply(&updated, JSONEncoder())) != nil else { return }
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
        case "alef.wordSrs.v1":
            let dates = try decoder.decode([String: ReviewSchedule].self, from: data)
            guard dates.values.allSatisfy({ $0.nextReviewAt >= 0 && $0.intervalDays >= 0 }) else { throw BackupError.invalid }
        case DailyVocabularyPlan.storageKey:
            guard try decoder.decode(DailyVocabularyPlan.self, from: data).isValid else { throw BackupError.invalid }
        case "alef.studyStats.v1":
            let stats = try decoder.decode(StudyStatistics.self, from: data)
            guard stats.streakDays >= 0, stats.todayReviews >= 0, stats.totalReviews >= 0 else { throw BackupError.invalid }
        case "alef.theme.v1", "alef.dayTheme.v1":
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
        case "alef.native.feedback.v1", "alef.native.recordings.v1":
            _ = try decoder.decode(Bool.self, from: data)
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
