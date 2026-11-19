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
}

enum StudyTheme: String, Codable, CaseIterable, Identifiable {
    case parchment, rose, violet, dark

    var id: Self { self }
    var title: String {
        switch self {
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

    var isDue: Bool { nextReviewAt <= Int64(Date.now.timeIntervalSince1970 * 1_000) }
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

@Observable final class StudyProgress {
    struct BackupUndo: Codable {
        let previous: [String: Data]
        let absent: [String]
    }

    private static let storageKey = "alef.native.progress.v1"
    private static let restoreKey = "alef.native.restore.v1"
    private static let migrationKey = "alef.native.didReadWebStorage.v1"
    private let defaults: UserDefaults
    private var entries: [String: Data]
    private(set) var restorePoint: BackupUndo?

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
    var needsLegacyMigration: Bool { !defaults.bool(forKey: Self.migrationKey) }

    var theme: StudyTheme {
        get { read("alef.theme.v1", default: .parchment) }
        set {
            update { values, encoder in
                let theme = try encoder.encode(newValue)
                values["alef.theme.v1"] = theme
                if newValue != .dark { values["alef.dayTheme.v1"] = theme }
            }
        }
    }

    var speechRate: Double {
        get { read("alef.speechRate.v1", default: 1) }
        set { write(newValue, for: "alef.speechRate.v1") }
    }

    var alphabetFromRight: Bool {
        get { read("alef.order.v1", default: "rtl") == "rtl" }
        set { write(newValue ? "rtl" : "ltr", for: "alef.order.v1") }
    }

    func display(_ key: String, default defaultValue: Bool = true) -> Bool {
        let options: [String: Bool] = read("alef.displayConfig.v1", default: [:])
        return options[key] ?? defaultValue
    }

    func setDisplay(_ key: String, enabled: Bool) {
        var options: [String: Bool] = read("alef.displayConfig.v1", default: [:])
        options[key] = enabled
        write(options, for: "alef.displayConfig.v1")
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
        var values = wordMastery
        var dates = schedule
        values[id] = mastery
        switch mastery {
        case .unlearned:
            dates.removeValue(forKey: id)
        case .learning, .mastered:
            let previous = dates[id]?.intervalDays ?? 1
            let interval = mastery == .learning ? 1 : ([3, 7, 14, 30].first { $0 > previous } ?? 30)
            let next = date.addingTimeInterval(Double(interval) * 86_400)
            dates[id] = ReviewSchedule(nextReviewAt: Int64(next.timeIntervalSince1970 * 1_000), intervalDays: interval)
        }
        var stats = statistics
        stats.record(on: date)
        update { entries, encoder in
            entries["alef.wordMastery.v1"] = try encoder.encode(values)
            entries["alef.wordSrs.v1"] = try encoder.encode(dates)
            entries["alef.studyStats.v1"] = try encoder.encode(stats)
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
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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
        case "alef.favoriteWords.v1":
            _ = try decoder.decode([String].self, from: data)
        case "alef.wordSrs.v1":
            let dates = try decoder.decode([String: ReviewSchedule].self, from: data)
            guard dates.values.allSatisfy({ $0.nextReviewAt >= 0 && $0.intervalDays >= 0 }) else { throw BackupError.invalid }
        case "alef.studyStats.v1":
            let stats = try decoder.decode(StudyStatistics.self, from: data)
            guard stats.streakDays >= 0, stats.todayReviews >= 0, stats.totalReviews >= 0 else { throw BackupError.invalid }
        case "alef.theme.v1", "alef.dayTheme.v1":
            _ = try decoder.decode(StudyTheme.self, from: data)
        case "alef.speechRate.v1":
            let rate = try decoder.decode(Double.self, from: data)
            guard (0.5...1.5).contains(rate) else { throw BackupError.invalid }
        case "alef.order.v1":
            let order = try decoder.decode(String.self, from: data)
            guard ["rtl", "ltr"].contains(order) else { throw BackupError.invalid }
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
