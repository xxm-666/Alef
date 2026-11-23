import Foundation
import UserNotifications
import XCTest
@testable import App

final class AlefCoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: StudyProgress!
    private var gregorianUtc: Calendar!

    override func setUp() {
        super.setUp()
        suiteName = "com.xxm666.alef.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        progress = StudyProgress(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        gregorianUtc = calendar
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        progress = nil
        super.tearDown()
    }

    func testReviewScheduleSm2ProgressionAndCaps() {
        let baseDate = makeDate(year: 2026, month: 11, day: 1)

        // New card -> .good gives 3 days, reps = 1
        let s1 = ReviewSchedule.next(from: nil, grade: .good, on: baseDate, calendar: gregorianUtc)
        XCTAssertEqual(s1.intervalDays, 3)
        XCTAssertEqual(s1.repetitions, 1)
        XCTAssertEqual(s1.lapses, 0)
        XCTAssertEqual(s1.easeFactor, 2.5, accuracy: 0.001)

        // Second .good gives 7 days, reps = 2
        let s2 = ReviewSchedule.next(from: s1, grade: .good, on: baseDate, calendar: gregorianUtc)
        XCTAssertEqual(s2.intervalDays, 7)
        XCTAssertEqual(s2.repetitions, 2)

        // Third .good gives round(7 * 2.5) = 18 days, reps = 3
        let s3 = ReviewSchedule.next(from: s2, grade: .good, on: baseDate, calendar: gregorianUtc)
        XCTAssertEqual(s3.intervalDays, 18)
        XCTAssertEqual(s3.repetitions, 3)

        // .easy increases ease up to cap and interval up to 180 days
        var current = s3
        for _ in 0..<5 {
            current = ReviewSchedule.next(from: current, grade: .easy, on: baseDate, calendar: gregorianUtc)
        }
        XCTAssertEqual(current.easeFactor, ReviewSchedule.maxEase, accuracy: 0.001)
        XCTAssertEqual(current.intervalDays, ReviewSchedule.maxIntervalDays)

        // .hard lowers ease and preserves repetitions progression
        let hard = ReviewSchedule.next(from: s1, grade: .hard, on: baseDate, calendar: gregorianUtc)
        XCTAssertEqual(hard.intervalDays, 4)
        XCTAssertEqual(hard.easeFactor, 2.35, accuracy: 0.001)
        XCTAssertEqual(hard.repetitions, 2)

        // .again resets interval and repetitions, increments lapses, and floors ease at 1.3
        var lapsed = s2
        for expectedLapse in 1...10 {
            lapsed = ReviewSchedule.next(from: lapsed, grade: .again, on: baseDate, calendar: gregorianUtc)
            XCTAssertEqual(lapsed.intervalDays, 1)
            XCTAssertEqual(lapsed.repetitions, 0)
            XCTAssertEqual(lapsed.lapses, expectedLapse)
        }
        XCTAssertEqual(lapsed.easeFactor, ReviewSchedule.minEase, accuracy: 0.001)
    }

    func testReviewScheduleBackwardCompatibleDecoding() throws {
        let legacyJson = #"{"nextReviewAt":1795392000000,"intervalDays":7}"#
        let decoded = try JSONDecoder().decode(ReviewSchedule.self, from: Data(legacyJson.utf8))
        XCTAssertEqual(decoded.nextReviewAt, 1_795_392_000_000)
        XCTAssertEqual(decoded.intervalDays, 7)
        XCTAssertEqual(decoded.easeFactor, ReviewSchedule.defaultEase, accuracy: 0.001)
        XCTAssertEqual(decoded.repetitions, 1)
        XCTAssertEqual(decoded.lapses, 0)
        XCTAssertTrue(decoded.isValid)

        let legacyLearningJson = #"{"nextReviewAt":1795392000000,"intervalDays":1}"#
        let decodedLearning = try JSONDecoder().decode(ReviewSchedule.self, from: Data(legacyLearningJson.utf8))
        XCTAssertEqual(decodedLearning.repetitions, 0)
    }

    func testManualMasteryDoesNotAdvanceSrsInterval() {
        let day1 = makeDate(year: 2026, month: 11, day: 1)
        let day2 = makeDate(year: 2026, month: 11, day: 2)

        progress.setWord("shalom", mastery: .mastered, date: day1)
        let initialWordSchedule = progress.schedule["shalom"]
        XCTAssertEqual(initialWordSchedule?.intervalDays, 3)

        // Tapping mastered repeatedly does not extend interval
        progress.setWord("shalom", mastery: .mastered, date: day2)
        XCTAssertEqual(progress.schedule["shalom"], initialWordSchedule)

        // Real quiz progression reaches 7 days, manual toggle to mastered preserves existing non-due schedule
        progress.completeReview("shalom", grade: .good, date: day2)
        XCTAssertEqual(progress.schedule["shalom"]?.intervalDays, 7)
        progress.setWord("shalom", mastery: .mastered, date: day2)
        XCTAssertEqual(progress.schedule["shalom"]?.intervalDays, 7)

        // Setting unlearned clears schedule
        progress.setWord("shalom", mastery: .unlearned, date: day2)
        XCTAssertNil(progress.schedule["shalom"])

        // Same manual protection applies to letters
        progress.setLetter("alef", mastery: .mastered, date: day1)
        XCTAssertEqual(progress.letterSchedule["alef"]?.intervalDays, 3)
        progress.completeLetterReview("alef", grade: .good, date: day2)
        XCTAssertEqual(progress.letterSchedule["alef"]?.intervalDays, 7)
        progress.setLetter("alef", mastery: .mastered, date: day2)
        XCTAssertEqual(progress.letterSchedule["alef"]?.intervalDays, 7)
        progress.setLetter("alef", mastery: .unlearned, date: day2)
        XCTAssertNil(progress.letterSchedule["alef"])
    }

    func testCompleteAndAdjustReviewUpdatesStatsOnce() {
        let day1 = makeDate(year: 2026, month: 11, day: 1)
        let day2 = makeDate(year: 2026, month: 11, day: 2)
        let day5 = makeDate(year: 2026, month: 11, day: 5)

        let wordBase = progress.schedule["shalom"]
        progress.completeReview("shalom", grade: .good, date: day1)
        XCTAssertEqual(progress.statistics.totalReviews, 1)
        XCTAssertEqual(progress.statistics.streakDays, 1)
        XCTAssertEqual(progress.schedule["shalom"]?.intervalDays, 3)

        // Adjusting grade changes schedule without inflating review counters
        progress.adjustWordReview("shalom", base: wordBase, grade: .easy, date: day1)
        XCTAssertEqual(progress.statistics.totalReviews, 1)
        XCTAssertEqual(progress.schedule["shalom"]?.intervalDays, 5)

        // Consecutive day review increments streakDays
        let letterBase = progress.letterSchedule["bet"]
        progress.completeLetterReview("bet", grade: .good, date: day2)
        XCTAssertEqual(progress.statistics.totalReviews, 2)
        XCTAssertEqual(progress.statistics.streakDays, 2)
        XCTAssertEqual(progress.letterSchedule["bet"]?.intervalDays, 3)

        progress.adjustLetterReview("bet", base: letterBase, grade: .hard, date: day2)
        XCTAssertEqual(progress.statistics.totalReviews, 2)
        XCTAssertEqual(progress.letterSchedule["bet"]?.intervalDays, 1)

        // Gap resets streakDays to 1
        progress.completeReview("shalom", grade: .good, date: day5)
        XCTAssertEqual(progress.statistics.totalReviews, 3)
        XCTAssertEqual(progress.statistics.streakDays, 1)
    }

    func testDueWordsAndLettersSorting() throws {
        let content = try StudyContent.load()
        XCTAssertEqual(content.letters.count, 22)
        XCTAssertGreaterThan(content.words.count, 1000)

        let wordA = content.words[0].id
        let wordB = content.words[1].id
        let wordC = content.words[2].id
        let now = makeDate(year: 2026, month: 11, day: 10)
        let earlier = makeDate(year: 2026, month: 11, day: 8)
        let later = makeDate(year: 2026, month: 11, day: 9)
        let future = makeDate(year: 2026, month: 11, day: 15)

        progress.write([
            wordB: ReviewSchedule(nextReviewAt: Int64(later.timeIntervalSince1970 * 1_000), intervalDays: 3),
            wordA: ReviewSchedule(nextReviewAt: Int64(earlier.timeIntervalSince1970 * 1_000), intervalDays: 1),
            wordC: ReviewSchedule(nextReviewAt: Int64(future.timeIntervalSince1970 * 1_000), intervalDays: 7),
        ], for: "alef.wordSrs.v1")

        let dueWords = content.dueWords(in: progress, at: now).map(\.id)
        XCTAssertEqual(dueWords, [wordA, wordB])

        progress.write([
            "gimel": ReviewSchedule(nextReviewAt: Int64(later.timeIntervalSince1970 * 1_000), intervalDays: 3),
            "alef": ReviewSchedule(nextReviewAt: Int64(earlier.timeIntervalSince1970 * 1_000), intervalDays: 1),
            "bet": ReviewSchedule(nextReviewAt: Int64(future.timeIntervalSince1970 * 1_000), intervalDays: 7),
        ], for: StudyProgress.letterScheduleKey)

        let dueLetters = content.dueLetters(in: progress, at: now).map(\.id)
        XCTAssertEqual(dueLetters, ["alef", "gimel"])
    }

    func testDailyVocabularyPlanStateMachine() {
        let words = (1...12).map { index in
            makeWord(id: "w\(index)", hebrew: "שָׁלוֹם", unpointed: "שלום")
        }
        let day1 = makeDate(year: 2026, month: 11, day: 1)
        let dayKey1 = DailyVocabularyPlan.dayKey(for: day1)
        progress.prepareDailyVocabulary(words: words, date: day1)

        var plan = progress.dailyVocabularyPlan(words: words, date: day1)
        XCTAssertEqual(plan.groups.count, 2)
        XCTAssertEqual(plan.groups[0].wordIds.count, 5)
        XCTAssertTrue(plan.isValid)

        // Study all 5 words in group 0
        let firstGroup = plan.groups[0]
        for _ in 0..<5 {
            XCTAssertTrue(progress.advanceDailyVocabulary(progress.dailyVocabulary.nextGroup!, day: dayKey1))
        }

        // Answer first word correctly and advance feedback
        let answer = progress.answerDailyVocabulary(
            progress.dailyVocabulary.nextGroup!,
            day: dayKey1,
            word: words[0],
            input: "שלום",
            date: day1
        )
        XCTAssertEqual(answer?.correct, true)
        XCTAssertEqual(progress.dailyVocabulary.nextGroup?.feedbackPending, true)
        XCTAssertEqual(progress.schedule[words[0].id]?.intervalDays, 3)

        // Cross into next day: started incomplete group 0 is preserved
        let day2 = makeDate(year: 2026, month: 11, day: 2)
        plan = progress.dailyVocabularyPlan(words: words, date: day2)
        XCTAssertEqual(plan.day, DailyVocabularyPlan.dayKey(for: day2))
        XCTAssertEqual(plan.groups.first?.wordIds, firstGroup.wordIds)
        XCTAssertTrue(plan.groups.first?.hasStarted == true)

        // Invalid plan detection
        var invalid = plan
        invalid.groupsPerDay = 99
        XCTAssertFalse(invalid.isValid)
    }

    func testWordSpellingNormalization() {
        let word = makeWord(
            id: "todah",
            hebrew: "תּוֹדָה",
            unpointed: "תודה",
            alternateSpellings: ["תוד\"ה"]
        )
        XCTAssertTrue(word.acceptsSpelling("תּוֹדָה"))
        XCTAssertTrue(word.acceptsSpelling("תודה"))
        XCTAssertTrue(word.acceptsSpelling("  תודה  "))
        XCTAssertTrue(word.acceptsSpelling("תוד״ה"))
        XCTAssertTrue(word.acceptsSpelling("תוד\"ה"))
        XCTAssertFalse(word.acceptsSpelling("שלום"))
    }

    func testBackupExportPreviewApplyUndoAndLegacyCompatibility() throws {
        let day1 = makeDate(year: 2026, month: 11, day: 1)
        progress.setWord("shalom", mastery: .mastered, date: day1)
        progress.completeLetterReview("alef", grade: .easy, date: day1)
        progress.reminderPreferences = ReminderPreferences(enabled: true, hour: 9, minute: 30, onlyWhenDue: true)

        let exported = try progress.exportBackup()

        // Import into a fresh StudyProgress instance and test undo
        let targetSuite = "com.xxm666.alef.tests.restore.\(UUID().uuidString)"
        let targetDefaults = UserDefaults(suiteName: targetSuite)!
        defer { targetDefaults.removePersistentDomain(forName: targetSuite) }
        let target = StudyProgress(defaults: targetDefaults)
        target.setWord("other", mastery: .learning, date: day1)

        let preview = try target.previewBackup(exported)
        let changes = target.backupChanges(preview)
        XCTAssertTrue(changes.contains("alef.wordSrs.v1"))
        XCTAssertTrue(changes.contains(StudyProgress.letterScheduleKey))
        XCTAssertTrue(changes.contains(ReminderPreferences.storageKey))

        target.applyBackup(preview)
        XCTAssertEqual(target.schedule["shalom"]?.intervalDays, 3)
        XCTAssertEqual(target.letterSchedule["alef"]?.intervalDays, 5)
        XCTAssertEqual(target.reminderPreferences, ReminderPreferences(enabled: true, hour: 9, minute: 30, onlyWhenDue: true))

        target.undoBackup()
        XCTAssertNil(target.schedule["shalom"])
        XCTAssertNil(target.letterSchedule["alef"])
        XCTAssertEqual(target.wordMastery["other"], .learning)

        // Legacy backup without easeFactor/repetitions/lapses
        let legacyBackup = """
        {
          "app": "Alef",
          "version": 1,
          "data": {
            "alef.wordSrs.v1": {
              "shalom": { "nextReviewAt": 1795392000000, "intervalDays": 14 }
            }
          }
        }
        """
        let legacyPreview = try target.previewBackup(Data(legacyBackup.utf8))
        target.applyBackup(legacyPreview)
        XCTAssertEqual(target.schedule["shalom"]?.intervalDays, 14)
        XCTAssertEqual(target.schedule["shalom"]?.easeFactor ?? 0, 2.5, accuracy: 0.001)

        // Reject invalid backup
        XCTAssertThrowsError(try target.previewBackup(Data(#"{"app":"Other","version":1,"data":{}}"#.utf8)))
        let invalidReminderBackup = """
        {
          "app": "Alef",
          "version": 1,
          "data": {
            "alef.native.reminders.v1": { "enabled": true, "hour": 29, "minute": 0, "onlyWhenDue": false }
          }
        }
        """
        XCTAssertThrowsError(try target.previewBackup(Data(invalidReminderBackup.utf8)))
    }

    func testDailyLetterRotationAndDeepLink() {
        XCTAssertEqual(DailyLetter.alphabet.count, 22)
        XCTAssertTrue(DailyLetter.alphabet.allSatisfy { !$0.nameZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let start = makeDate(year: 2026, month: 1, day: 1)
        var seen: [String] = []
        for offset in 0..<22 {
            let date = gregorianUtc.date(byAdding: .day, value: offset, to: start)!
            seen.append(DailyLetter.on(date, calendar: gregorianUtc).id)
        }
        XCTAssertEqual(Set(seen).count, 22)

        let day23 = gregorianUtc.date(byAdding: .day, value: 22, to: start)!
        XCTAssertEqual(DailyLetter.on(day23, calendar: gregorianUtc).id, seen[0])

        let alef = DailyLetter.alphabet[0]
        XCTAssertEqual(DailyLetter.id(from: alef.url!), "alef")
        XCTAssertNil(DailyLetter.id(from: URL(string: "alef://daily-letter/unknown")!))
        XCTAssertNil(DailyLetter.id(from: URL(string: "https://example.com/alef")!))
    }

    func testBackupReminderAndHapticsPersistence() throws {
        let day1 = makeDate(year: 2026, month: 11, day: 1)
        let day4 = makeDate(year: 2026, month: 11, day: 4)
        let day8 = makeDate(year: 2026, month: 11, day: 8)

        // Fresh user with no study activity should not be nagged
        XCTAssertNil(progress.backupReminderMessage(on: day1))
        XCTAssertTrue(progress.hapticsEnabled)

        // After learning progress, missing backup triggers reminder
        progress.setWord("shalom", mastery: .mastered, date: day1)
        XCTAssertNotNil(progress.backupReminderMessage(on: day1))

        // Exporting backup clears reminder until staleDays (7 days) elapses
        progress.markBackupExported(on: day1)
        XCTAssertNil(progress.backupReminderMessage(on: day4))
        XCTAssertNotNil(progress.backupReminderMessage(on: day8))

        // Haptics and lastBackupAt round-trip through JSON backup
        progress.hapticsEnabled = false
        let exported = try progress.exportBackup()

        let restoredSuite = "com.xxm666.alef.tests.p2.\(UUID().uuidString)"
        let restoredDefaults = UserDefaults(suiteName: restoredSuite)!
        defer { restoredDefaults.removePersistentDomain(forName: restoredSuite) }
        let restored = StudyProgress(defaults: restoredDefaults)
        let preview = try restored.previewBackup(exported)
        restored.applyBackup(preview)
        XCTAssertFalse(restored.hapticsEnabled)
        XCTAssertEqual(restored.lastBackupAt, Int64(day1.timeIntervalSince1970 * 1_000))
    }

    @MainActor
    func testReminderRequestGenerationAndSync() async {
        let now = makeDate(year: 2026, month: 11, day: 23, hour: 19, minute: 0)

        // Disabled -> nil
        let disabled = ReminderPreferences(enabled: false, hour: 20, minute: 0, onlyWhenDue: false)
        XCTAssertNil(StudyReminderManager.makeRequest(
            preferences: disabled, dueWords: 3, dueLetters: 1, streakDays: 2, todayReviews: 0,
            now: now, calendar: gregorianUtc
        ))

        // onlyWhenDue with zero due -> nil
        let dueOnly = ReminderPreferences(enabled: true, hour: 20, minute: 0, onlyWhenDue: true)
        XCTAssertNil(StudyReminderManager.makeRequest(
            preferences: dueOnly, dueWords: 0, dueLetters: 0, streakDays: 2, todayReviews: 0,
            now: now, calendar: gregorianUtc
        ))

        // onlyWhenDue with due items -> non-repeating request pointing to flashcards tab
        let dueRequest = StudyReminderManager.makeRequest(
            preferences: dueOnly, dueWords: 4, dueLetters: 2, streakDays: 3, todayReviews: 1,
            now: now, calendar: gregorianUtc
        )
        XCTAssertNotNil(dueRequest)
        XCTAssertEqual(dueRequest?.content.title, "Alef · 有 6 项复习已到期")
        XCTAssertEqual(dueRequest?.content.userInfo["targetTab"] as? String, "flashcards")
        let dueTrigger = dueRequest?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(dueTrigger?.repeats, false)
        XCTAssertEqual(dueTrigger?.dateComponents.day, 23)
        XCTAssertEqual(dueTrigger?.dateComponents.hour, 20)

        // Passed hour today -> schedules for tomorrow in onlyWhenDue mode
        let laterNow = makeDate(year: 2026, month: 11, day: 23, hour: 21, minute: 0)
        let tomorrowRequest = StudyReminderManager.makeRequest(
            preferences: dueOnly, dueWords: 1, dueLetters: 0, streakDays: 0, todayReviews: 0,
            now: laterNow, calendar: gregorianUtc
        )
        let tomorrowTrigger = tomorrowRequest?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(tomorrowTrigger?.dateComponents.day, 24)

        // Daily mode -> repeating trigger
        let dailyPref = ReminderPreferences(enabled: true, hour: 8, minute: 30, onlyWhenDue: false)
        let dailyRequest = StudyReminderManager.makeRequest(
            preferences: dailyPref, dueWords: 0, dueLetters: 0, streakDays: 5, todayReviews: 0,
            now: now, calendar: gregorianUtc
        )
        XCTAssertEqual(dailyRequest?.content.userInfo["targetTab"] as? String, "grid")
        let dailyTrigger = dailyRequest?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(dailyTrigger?.repeats, true)
        XCTAssertEqual(dailyTrigger?.dateComponents.hour, 8)
        XCTAssertEqual(dailyTrigger?.dateComponents.minute, 30)

        // Manager sync with mock center
        let mock = MockStudyNotificationCenter()
        let manager = StudyReminderManager(center: mock)
        await manager.sync(preferences: dailyPref, dueWords: 2, dueLetters: 0, streakDays: 1, todayReviews: 0, now: now)
        XCTAssertEqual(mock.removedIdentifiers.count, 1)
        XCTAssertEqual(mock.addedRequests.count, 1)

        // Disabling clears pending without re-adding
        await manager.sync(preferences: disabled, dueWords: 2, dueLetters: 0, streakDays: 1, todayReviews: 0, now: now)
        XCTAssertEqual(mock.removedIdentifiers.count, 2)
        XCTAssertEqual(mock.addedRequests.count, 1)
    }

    func testP1ContentDecodingAndRootFamilies() throws {
        let content = try StudyContent.load()
        XCTAssertEqual(content.readings.count, 12)
        XCTAssertEqual(content.grammarAffixes.count, 10)
        XCTAssertEqual(content.grammarBinyanim.count, 6)
        XCTAssertEqual(content.minimalPairs.count, 26)
        XCTAssertEqual(content.learningPath.count, 8)

        let families = content.rootFamilies()
        XCTAssertGreaterThan(families.count, 50)
        XCTAssertTrue(families.allSatisfy { $0.words.count >= 2 })

        let wordIds = Set(content.words.map(\.id))
        for pair in content.minimalPairs {
            XCTAssertNotEqual(pair.firstWordId, pair.secondWordId)
            XCTAssertTrue(wordIds.contains(pair.firstWordId))
            XCTAssertTrue(wordIds.contains(pair.secondWordId))
        }

        let coveredLetters = Set(content.learningPath.flatMap(\.letterIds))
        XCTAssertEqual(coveredLetters.count, 22)
    }

    func testReadingNiqqudTransitionModes() {
        let sentence = StudyReading.Sentence(
            hebrew: "שָׁלוֹם, מַה שְׁלוֹמְךָ?",
            unpointed: "שלום, מה שלומך?",
            transliteration: "Shalom, ma shlomkha?",
            chinese: "你好，你最近怎么样？"
        )
        let reading = StudyReading(
            id: "test-reading",
            title: "测试阅读",
            category: "modern",
            source: nil,
            sentences: [sentence],
            glosses: ["שלומך": "你的近况"],
            question: StudyReading.Question(prompt: "问候", choices: ["A", "B"], correctIndex: 0)
        )

        XCTAssertEqual(reading.displayText(for: sentence, mode: .full), sentence.hebrew)
        XCTAssertEqual(reading.displayText(for: sentence, mode: .unpointed), sentence.unpointed)

        let assisted = reading.displayText(for: sentence, mode: .assisted)
        XCTAssertEqual(assisted, "שלום, מה שְׁלוֹמְךָ?")
        XCTAssertEqual(reading.inlineGlosses(in: assisted).count, 1)
    }

    @MainActor
    func testFolderSyncBidirectionalAndConflictMerge() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("alef-sync-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let syncFile = tempDir.appendingPathComponent(StudyFolderSyncManager.syncFileName)
        let suiteSyncA = "com.xxm666.alef.tests.syncA.\(UUID().uuidString)"
        let suiteSyncB = "com.xxm666.alef.tests.syncB.\(UUID().uuidString)"
        let suiteProgB = "com.xxm666.alef.tests.progB.\(UUID().uuidString)"
        let defaultsSyncA = UserDefaults(suiteName: suiteSyncA)!
        let defaultsSyncB = UserDefaults(suiteName: suiteSyncB)!
        let defaultsProgB = UserDefaults(suiteName: suiteProgB)!
        defer {
            defaultsSyncA.removePersistentDomain(forName: suiteSyncA)
            defaultsSyncB.removePersistentDomain(forName: suiteSyncB)
            defaultsProgB.removePersistentDomain(forName: suiteProgB)
        }

        // Device A writes initial progress and configures folder
        let day1 = makeDate(year: 2026, month: 11, day: 10, hour: 10)
        progress.completeReview("shalom", grade: .good, date: day1)
        progress.toggleFavorite("shalom")
        let syncA = StudyFolderSyncManager(defaults: defaultsSyncA)
        await syncA.configureFolder(url: tempDir, progress: progress)

        XCTAssertTrue(syncA.isConfigured)
        XCTAssertTrue(FileManager.default.fileExists(atPath: syncFile.path))
        XCTAssertNotNil(progress.lastBackupAt)
        let initialData = try Data(contentsOf: syncFile)
        _ = try progress.parseSyncDocument(initialData)

        // Device B starts empty, connects to same folder, and automatically restores without bumping syncRevision
        let progressB = StudyProgress(defaults: defaultsProgB)
        let syncB = StudyFolderSyncManager(defaults: defaultsSyncB)
        await syncB.configureFolder(url: tempDir, progress: progressB)

        XCTAssertEqual(progressB.wordMastery["shalom"], .mastered)
        XCTAssertEqual(progressB.favorites, ["shalom"])
        XCTAssertEqual(progressB.statistics.totalReviews, 1)
        XCTAssertEqual(progressB.syncRevision, 0)

        // Offline divergence on both devices
        let day2 = makeDate(year: 2026, month: 11, day: 11, hour: 9)
        progress.completeReview("todah", grade: .easy, date: day2)
        progress.toggleFavorite("todah")
        let revABeforeSync = progress.syncRevision

        progressB.completeReview("bayit", grade: .good, date: day2)
        progressB.completeLetterReview("bet", grade: .good, date: day2)
        progressB.toggleFavorite("bayit")
        let revBBeforeSync = progressB.syncRevision

        await syncA.sync(progress: progress, now: day2)
        await syncB.sync(progress: progressB, now: day2)
        await syncA.sync(progress: progress, now: day2)

        // Both devices converge with combined reviews, favorites, and no extra syncRevision loop
        XCTAssertEqual(progress.wordMastery["bayit"], .mastered)
        XCTAssertEqual(progress.letterMastery["bet"], .mastered)
        XCTAssertEqual(progressB.wordMastery["todah"], .mastered)
        XCTAssertEqual(Set(progress.favorites), Set(["shalom", "todah", "bayit"]))
        XCTAssertEqual(Set(progressB.favorites), Set(["shalom", "todah", "bayit"]))
        XCTAssertEqual(progress.syncRevision, revABeforeSync)
        XCTAssertEqual(progressB.syncRevision, revBBeforeSync)

        // Corrupt remote file fails gracefully and preserves local data
        try Data("{corrupt-json".utf8).write(to: syncFile, options: .atomic)
        await syncA.sync(progress: progress, now: day2)
        if case .failed = syncA.state {
            // Expected failure state
        } else {
            XCTFail("Expected .failed state on corrupt sync document, got \(syncA.state)")
        }
        XCTAssertEqual(progress.wordMastery["shalom"], .mastered)
        XCTAssertEqual(progress.wordMastery["bayit"], .mastered)
    }

    @MainActor
    func testFolderSyncKeepsLatestReviewAndFavoriteRemoval() async throws {
        let storage = MockStudySyncFolderStorage()
        let manager = StudyFolderSyncManager(defaults: defaults, storage: storage)
        let folder = FileManager.default.temporaryDirectory
        let firstDay = makeDate(year: 2026, month: 11, day: 10)
        let secondDay = makeDate(year: 2026, month: 11, day: 11)

        progress.completeReview("shalom", grade: .easy, date: firstDay)
        progress.completeLetterReview("alef", grade: .easy, date: firstDay)
        progress.toggleFavorite("shalom")
        progress.write(["greeting"], for: "alef.native.phraseFavorites.v1")
        await manager.configureFolder(url: folder, progress: progress)
        let oldCloudData = try XCTUnwrap(storage.data)
        let oldCloud = try progress.parseSyncDocument(oldCloudData)
        var legacyCloud = oldCloud.entries
        legacyCloud.removeValue(forKey: StudySyncMerger.itemVersionsKey)
        storage.data = try progress.encodeSyncDocument(entries: legacyCloud, updatedAt: oldCloud.updatedAt)
        let oldDue = try XCTUnwrap(progress.schedule["shalom"]?.nextReviewAt)

        progress.completeReview("shalom", grade: .again, date: secondDay)
        progress.completeLetterReview("alef", grade: .again, date: secondDay)
        progress.toggleFavorite("shalom")
        progress.write([String](), for: "alef.native.phraseFavorites.v1")
        let expectedSchedule = try XCTUnwrap(progress.schedule["shalom"])
        XCTAssertLessThan(expectedSchedule.nextReviewAt, oldDue)

        let reloaded = StudyProgress(defaults: defaults)
        await manager.sync(progress: reloaded)
        XCTAssertEqual(reloaded.schedule["shalom"], expectedSchedule)
        XCTAssertEqual(reloaded.wordMastery["shalom"], .learning)
        XCTAssertEqual(reloaded.letterSchedule["alef"]?.intervalDays, 1)
        XCTAssertEqual(reloaded.letterMastery["alef"], .learning)
        XCTAssertTrue(reloaded.favorites.isEmpty)
        XCTAssertEqual(reloaded.read("alef.native.phraseFavorites.v1", default: [String]()), [])
        let cloud = try reloaded.parseSyncDocument(XCTUnwrap(storage.data))
        XCTAssertTrue(StudySyncMerger.canonicalEqual(cloud.entries, reloaded.syncSnapshot()))

        reloaded.toggleFavorite("shalom")
        await manager.sync(progress: reloaded)
        let readded = try reloaded.parseSyncDocument(XCTUnwrap(storage.data))
        XCTAssertEqual(reloaded.favorites, ["shalom"])
        XCTAssertTrue(StudySyncMerger.canonicalEqual(readded.entries, reloaded.syncSnapshot()))
    }

    @MainActor
    func testFolderSyncRetriesWhenProgressChangesDuringCloudWrite() async throws {
        let storage = MockStudySyncFolderStorage()
        let manager = StudyFolderSyncManager(defaults: defaults, storage: storage)
        let remote = StudyProgress(defaults: UserDefaults(suiteName: suiteName + ".remote")!)
        defer { UserDefaults(suiteName: suiteName + ".remote")?.removePersistentDomain(forName: suiteName + ".remote") }
        remote.completeReview("bayit", grade: .good)
        storage.data = try remote.encodeSyncDocument(entries: remote.syncSnapshot(), updatedAt: remote.localUpdatedAt)
        progress.completeReview("shalom", grade: .good)

        storage.onNextWrite = { [progress = self.progress!] in
            progress.completeReview("shalom", grade: .again)
            progress.completeReview("todah", grade: .easy)
        }
        await manager.configureFolder(url: FileManager.default.temporaryDirectory, progress: progress)

        XCTAssertEqual(storage.writeCount, 2)
        XCTAssertEqual(progress.wordMastery["bayit"], .mastered)
        XCTAssertEqual(progress.wordMastery["shalom"], .learning)
        XCTAssertEqual(progress.wordMastery["todah"], .mastered)
        let cloud = try progress.parseSyncDocument(XCTUnwrap(storage.data))
        XCTAssertTrue(StudySyncMerger.canonicalEqual(cloud.entries, progress.syncSnapshot()))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        gregorianUtc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeWord(id: String, hebrew: String, unpointed: String,
                          alternateSpellings: [String]? = nil) -> StudyWord {
        StudyWord(
            id: id,
            hebrew: hebrew,
            hebrewUnpointed: unpointed,
            alternateSpellings: alternateSpellings,
            transliteration: "test",
            ipa: "/test/",
            meaningZh: "测试",
            partOfSpeech: "名词",
            grammarTag: "阳性",
            category: "greetings",
            root: nil,
            note: "",
            sentence: nil
        )
    }
}

private final class MockStudyNotificationCenter: StudyNotificationCenter {
    var status: UNAuthorizationStatus = .authorized
    var requestResult = true
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [[String]] = []

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        status = requestResult ? .authorized : .denied
        return requestResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }
}

@MainActor
private final class MockStudySyncFolderStorage: StudySyncFolderStorage {
    var data: Data?
    var onNextWrite: (() -> Void)?
    private(set) var writeCount = 0

    func read(bookmarkData: Data, fileName: String) async throws -> (data: Data?, refreshedBookmark: Data?) {
        (data, nil)
    }

    func write(_ data: Data, bookmarkData: Data, fileName: String) async throws -> Data? {
        writeCount += 1
        let edit = onNextWrite
        onNextWrite = nil
        await Task.yield()
        edit?()
        self.data = data
        return nil
    }
}
