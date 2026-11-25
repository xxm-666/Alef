import AVFAudio
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
        XCTAssertNil(decoded.lastReview)

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

        progress.completeReview("shalom", grade: .good, date: day1)
        XCTAssertEqual(progress.statistics.totalReviews, 1)
        XCTAssertEqual(progress.statistics.streakDays, 1)
        XCTAssertEqual(progress.schedule["shalom"]?.intervalDays, 3)

        // Consecutive day review increments streakDays
        let letterBase = progress.letterSchedule["bet"]
        progress.completeLetterReview("bet", grade: .good, date: day2)
        XCTAssertEqual(progress.statistics.totalReviews, 2)
        XCTAssertEqual(progress.statistics.streakDays, 2)
        XCTAssertEqual(progress.letterSchedule["bet"]?.intervalDays, 3)

        // Adjusting a letter's grade changes its schedule without inflating review counters.
        progress.adjustLetterReview("bet", base: letterBase, grade: .hard, date: day2)
        XCTAssertEqual(progress.statistics.totalReviews, 2)
        XCTAssertEqual(progress.letterSchedule["bet"]?.intervalDays, 1)

        // Gap resets streakDays to 1
        progress.completeReview("shalom", grade: .good, date: day5)
        XCTAssertEqual(progress.statistics.totalReviews, 3)
        XCTAssertEqual(progress.statistics.streakDays, 1)
    }

    func testWordReviewAutomaticallyShortensIntervalsAfterMisses() {
        let today = makeDate(year: 2026, month: 11, day: 23)
        let tomorrow = makeDate(year: 2026, month: 11, day: 24)
        let followingDay = makeDate(year: 2026, month: 11, day: 25)
        let normalReview = makeDate(year: 2026, month: 11, day: 27)

        progress.completeReview("shalom", correct: true, date: today)
        XCTAssertEqual(progress.schedule["shalom"]?.intervalDays, 3)
        XCTAssertEqual(progress.schedule["shalom"]?.lastReview?.grade, .good)
        progress.completeReview("todah", correct: false, date: today)
        let missed = progress.schedule["todah"]
        XCTAssertEqual(missed?.intervalDays, 1)
        XCTAssertEqual(missed?.lastReview?.grade, .again)

        progress.completeReview("todah", correct: true, isRetry: true, date: today.addingTimeInterval(60))
        XCTAssertEqual(progress.schedule["todah"], missed)
        progress.completeReview("todah", correct: true, date: tomorrow)
        XCTAssertEqual(progress.schedule["todah"]?.intervalDays, 1)
        XCTAssertEqual(progress.schedule["todah"]?.lastReview?.grade, .hard)
        XCTAssertEqual(progress.wordMastery["todah"], .learning)
        progress.completeReview("todah", correct: true, date: followingDay)
        XCTAssertEqual(progress.schedule["todah"]?.intervalDays, 2)
        progress.completeReview("todah", correct: true, date: normalReview)
        XCTAssertEqual(progress.schedule["todah"]?.lastReview?.grade, .good)
        XCTAssertEqual(progress.wordMastery["todah"], .mastered)
        XCTAssertEqual(progress.statistics.totalReviews, 6)
    }

    func testSameSessionRetriesKeepFirstReviewAndSchedule() throws {
        let now = makeDate(year: 2026, month: 11, day: 23)
        progress.completeReview("shalom", grade: .again, date: now)
        progress.completeLetterReview("bet", grade: .again, date: now)
        let word = try XCTUnwrap(progress.schedule["shalom"])
        let letter = try XCTUnwrap(progress.letterSchedule["bet"])

        progress.completeReview("shalom", grade: .good, isRetry: true, date: now.addingTimeInterval(60))
        progress.completeLetterReview("bet", grade: .good, isRetry: true, date: now.addingTimeInterval(120))

        XCTAssertEqual(progress.schedule["shalom"], word)
        XCTAssertEqual(progress.letterSchedule["bet"], letter)
        XCTAssertEqual(word.lastReview?.date, now)
        XCTAssertEqual(letter.lastReview?.grade, .again)
        XCTAssertEqual(progress.wordMastery["shalom"], .learning)
        XCTAssertEqual(progress.letterMastery["bet"], .learning)
        XCTAssertEqual(progress.statistics.totalReviews, 4)
        XCTAssertEqual(ReviewGrade.hard.mastery, .learning)
        XCTAssertEqual(ReviewGrade.good.mastery, .mastered)
        XCTAssertNil(ReviewSchedule.next(from: nil, grade: .good, on: now, recordsReview: false).lastReview)
    }

    func testTodayReviewBatchResumesAtNextUnansweredWord() throws {
        let content = try StudyContent.load()
        let now = makeDate(year: 2026, month: 11, day: 24)
        let yesterday = makeDate(year: 2026, month: 11, day: 23)
        progress.setWord("shalom", mastery: .learning, date: yesterday.addingTimeInterval(-60))
        progress.setWord("todah", mastery: .learning, date: yesterday)
        let overview = StudyReviewOverview(content: content, progress: progress, at: now, calendar: gregorianUtc)
        let batch = try XCTUnwrap(overview.nextBatch)
        XCTAssertEqual(batch.itemIDs, ["shalom", "todah"])
        XCTAssertEqual(overview.completed, 0)
        progress.beginReviewBatch(batch)
        progress.completeReview("shalom", correct: false, date: now)

        let reopened = StudyProgress(defaults: defaults)
        let resumed = StudyReviewOverview(content: content, progress: reopened, at: now, calendar: gregorianUtc)
        XCTAssertEqual(resumed.savedBatch?.itemIDs, ["todah"])
        XCTAssertEqual(resumed.completed, 1)
        XCTAssertEqual(resumed.words.map(\.id), ["todah"])
        XCTAssertNotNil(resumed.nextReview)
    }

    func testMistakeBookSavesTypesAndOnlyClearsMatchingFormalReview() throws {
        let content = try StudyContent.load()
        let word = try XCTUnwrap(content.words.first { $0.id == "shalom" })
        let day1 = makeDate(year: 2026, month: 11, day: 23)
        let day2 = makeDate(year: 2026, month: 11, day: 24)
        let day3 = makeDate(year: 2026, month: 11, day: 25)
        let group = DailyVocabularyGroup(wordIds: [word.id], studied: 1)
        let day = DailyVocabularyPlan.dayKey(for: day1)
        progress.write(DailyVocabularyPlan(day: day, groups: [group]), for: DailyVocabularyPlan.storageKey)
        XCTAssertEqual(progress.answerDailyVocabulary(group, day: day, word: word, input: "א", date: day1)?.correct, false)
        progress.completeReview(word.id, correct: false, date: day1)
        progress.completeReview(word.id, correct: false, date: day2)
        progress.completeReview(word.id, correct: true, isRetry: true, date: day2)

        let reopened = StudyProgress(defaults: defaults)
        XCTAssertEqual(reopened.wordMistakes.first { $0.kind == .spelling }?.count, 1)
        XCTAssertEqual(reopened.wordMistakes.first { $0.kind == .meaning }?.count, 2)
        XCTAssertEqual(reopened.wordMistakes.first { $0.kind == .meaning }?.lastMissedAt, day2)
        let overview = StudyReviewOverview(content: content, progress: reopened, at: day3, calendar: gregorianUtc)
        XCTAssertEqual(overview.nextBatch?.kind, .spelling)
        let backup = try reopened.exportBackup()
        XCTAssertNotNil(try reopened.previewBackup(backup)[StudyWordMistake.storageKey])
        XCTAssertNil(reopened.syncSnapshot()[StudyWordMistake.storageKey])

        reopened.completeReview(word.id, correct: true, mistakeKind: .meaning, date: day3)
        XCTAssertEqual(reopened.wordMistakes.map(\.kind), [.spelling])
        reopened.completeReview(word.id, correct: true, mistakeKind: .spelling, date: day3)
        XCTAssertTrue(reopened.wordMistakes.isEmpty)
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

    func testAchievementsPersistAfterMasteryAndStreakDrop() throws {
        let letters = Set(DailyLetter.alphabet.map(\.id))
        let words = Set((1...50).map { "w\($0)" })
        let progress = StudyProgress(defaults: defaults, letterIDs: letters, wordIDs: words)
        let start = makeDate(year: 2026, month: 11, day: 1)
        XCTAssertTrue(progress.earnedAchievements.isEmpty)

        progress.write(Dictionary(uniqueKeysWithValues: letters.map { ($0, Mastery.mastered) }),
                       for: "alef.mastery.v1")
        var mastery = Dictionary(uniqueKeysWithValues: words.subtracting(["w50"]).map { ($0, Mastery.mastered) })
        mastery["obsolete-word"] = .mastered
        progress.write(mastery, for: "alef.wordMastery.v1")
        XCTAssertEqual(progress.achievementProgress.masteredWords, 49)
        XCTAssertFalse(progress.earnedAchievements.contains(.fiftyWords))
        progress.setWord("w50", mastery: .mastered, date: start)

        for offset in 1...6 {
            progress.recordStudy(on: try XCTUnwrap(gregorianUtc.date(byAdding: .day, value: offset, to: start)))
        }
        XCTAssertEqual(progress.earnedAchievements,
                       [.firstPractice, .tenLetters, .alphabet, .twentyWords, .fiftyWords, .threeDays, .sevenDays])

        let afterBreak = try XCTUnwrap(gregorianUtc.date(byAdding: .day, value: 9, to: start))
        XCTAssertEqual(progress.statistics.activeStreakDays(on: afterBreak), 0)
        progress.setLetter(try XCTUnwrap(letters.first), mastery: .learning, date: afterBreak)
        progress.setWord("w50", mastery: .learning, date: afterBreak)
        let reopened = StudyProgress(defaults: defaults, letterIDs: letters, wordIDs: words)
        XCTAssertEqual(reopened.achievementProgress.masteredLetters, 21)
        XCTAssertEqual(reopened.achievementProgress.masteredWords, 49)
        XCTAssertEqual(reopened.statistics.streakDays, 1)
        XCTAssertEqual(reopened.earnedAchievements, progress.earnedAchievements)
        XCTAssertNil(reopened.syncSnapshot()[StudyAchievement.storageKey])
    }

    func testAnswerComboBreaksOnWrongAnswerAndPersistsMilestones() throws {
        var run = StudyAnswerRun()
        for _ in 1...2 { run.record(correct: true, in: progress) }
        run.record(correct: true, in: progress, isRetry: true)
        XCTAssertEqual(run.combo, 2)
        XCTAssertEqual(run.celebration?.combo, 0)
        XCTAssertEqual(progress.achievementProgress.bestAnswerCombo, 2)
        XCTAssertFalse(progress.earnedAchievements.contains(.comboThree))

        run.record(correct: false, in: progress, isRetry: true)
        XCTAssertEqual(run.combo, 0)
        XCTAssertNil(run.celebration)
        for count in 1...11 {
            run.record(correct: true, in: progress)
            XCTAssertEqual(run.combo, count)
            XCTAssertEqual(run.celebration?.isMilestone, [3, 5, 10].contains(count))
        }
        run.clearCelebration()
        XCTAssertNil(run.celebration)
        XCTAssertEqual(run.combo, 11)
        run.record(correct: false, in: progress)
        XCTAssertEqual(run.combo, 0)

        let reopened = StudyProgress(defaults: defaults)
        XCTAssertEqual(reopened.achievementProgress.bestAnswerCombo, 11)
        XCTAssertEqual(reopened.earnedAchievements, [.comboThree, .comboFive, .comboTen])
        let backup = try reopened.previewBackup(reopened.exportBackup())
        XCTAssertNotNil(backup[StudyProgress.bestAnswerComboKey])
        XCTAssertNil(reopened.syncSnapshot()[StudyProgress.bestAnswerComboKey])
    }

    func testDailyVocabularyComboKeepsAcceptedAnswersAndResetsOnMistake() throws {
        let words = (1...5).map { makeWord(id: "w\($0)", hebrew: "שָׁלוֹם", unpointed: "שלום") }
        let today = makeDate(year: 2026, month: 11, day: 1)
        let day = DailyVocabularyPlan.dayKey(for: today)
        progress.prepareDailyVocabulary(words: words, date: today)
        for _ in words {
            let group = try XCTUnwrap(progress.dailyVocabulary.nextGroup)
            XCTAssertTrue(progress.advanceDailyVocabulary(group, day: day))
        }
        for (index, word) in words.enumerated() {
            let group = try XCTUnwrap(progress.dailyVocabulary.nextGroup)
            let correct = index != 3
            let input = correct ? "שלום" : "תודה"
            XCTAssertEqual(progress.answerDailyVocabulary(group, day: day, word: word, input: input,
                                                          date: today)?.correct, correct)
            XCTAssertNil(progress.answerDailyVocabulary(group, day: day, word: word, input: input, date: today))
            let pending = try XCTUnwrap(progress.dailyVocabulary.nextGroup)
            XCTAssertEqual(pending.answerCombo, [1, 2, 3, 0, 1][index])
            XCTAssertTrue(progress.advanceDailyVocabulary(pending, day: day))
        }

        let reopened = StudyProgress(defaults: defaults)
        XCTAssertEqual(reopened.achievementProgress.bestAnswerCombo, 3)
        XCTAssertTrue(reopened.earnedAchievements.contains(.comboThree))
        XCTAssertFalse(reopened.earnedAchievements.contains(.comboFive))
    }

    func testVocabularyAchievementUnlocksOnGroupCompletionAndSurvivesRollover() throws {
        let word = makeWord(id: "shalom", hebrew: "שָׁלוֹם", unpointed: "שלום")
        let today = makeDate(year: 2026, month: 11, day: 1)
        let day = DailyVocabularyPlan.dayKey(for: today)
        progress.prepareDailyVocabulary(words: [word], date: today)
        XCTAssertTrue(progress.advanceDailyVocabulary(try XCTUnwrap(progress.dailyVocabulary.nextGroup), day: day))
        let group = try XCTUnwrap(progress.dailyVocabulary.nextGroup)
        XCTAssertEqual(progress.answerDailyVocabulary(group, day: day, word: word, input: "שלום",
                                                      date: today)?.correct, true)
        XCTAssertFalse(progress.earnedAchievements.contains(.firstVocabularyGroup))
        XCTAssertTrue(progress.advanceDailyVocabulary(try XCTUnwrap(progress.dailyVocabulary.nextGroup), day: day))
        XCTAssertTrue(progress.earnedAchievements.contains(.firstVocabularyGroup))

        let tomorrow = try XCTUnwrap(gregorianUtc.date(byAdding: .day, value: 1, to: today))
        progress.prepareDailyVocabulary(words: [word], date: tomorrow)
        XCTAssertEqual(progress.dailyVocabulary.completedCount, 0)
        XCTAssertTrue(StudyProgress(defaults: defaults).earnedAchievements.contains(.firstVocabularyGroup))
    }

    func testAchievementBackfillAndBackupUndo() throws {
        let oldBackup = Data(#"{"app":"Alef","version":1,"data":{"alef.studyStats.v1":{"streakDays":3,"lastActiveDate":"2026-11-01","todayReviews":1,"totalReviews":3}}}"#.utf8)
        let legacy = try progress.previewBackup(oldBackup)
        let key = StudyAchievement.storageKey

        progress.applyBackup(legacy)
        XCTAssertEqual(progress.earnedAchievements, [.firstPractice, .threeDays])
        let newBackup = try progress.exportBackup()
        XCTAssertNotNil(try progress.previewBackup(newBackup)[key])
        progress.undoBackup()
        XCTAssertTrue(progress.earnedAchievements.isEmpty)

        defaults.set(legacy, forKey: "alef.native.progress.v1")
        let upgraded = StudyProgress(defaults: defaults)
        XCTAssertEqual(upgraded.earnedAchievements, [.firstPractice, .threeDays])
        upgraded.recordStudy(on: makeDate(year: 2026, month: 11, day: 20))
        XCTAssertEqual(StudyProgress(defaults: defaults).earnedAchievements, [.firstPractice, .threeDays])
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

    func testStudyGameRepeatsMistakeOnceWithoutChangingFirstAttemptScore() throws {
        let content = try StudyContent.load()
        let questions = StudyGame.letters.questions(in: content)
        XCTAssertEqual(questions.count, 6)
        var round = StudyGameRound(questions: Array(questions.prefix(3)))
        round.submit(correct: false)
        round.submit(correct: true)
        XCTAssertEqual(round.answered, 1)
        XCTAssertEqual(round.mistakes.count, 1)

        round.advance()
        round.submit(correct: true)
        round.advance()
        round.submit(correct: true)
        round.advance()
        XCTAssertEqual(round.current?.isRetry, true)
        XCTAssertEqual(round.score, 22)
        round.submit(correct: false)
        round.advance()
        XCTAssertNil(round.current)
        XCTAssertEqual(round.answered, 3)
        XCTAssertEqual(round.correct, 2)
        XCTAssertEqual(round.mistakes.count, 1)
        XCTAssertEqual(round.score, 22)
    }

    func testCurrentStageAndMissedWordsArePrioritized() throws {
        let content = try StudyContent.load()
        let stage = try XCTUnwrap(content.recommendedStage(in: progress))
        let firstWord = try XCTUnwrap(content.dailyVocabularyWords(in: progress).first)
        XCTAssertTrue(stage.wordIds.contains(firstWord.id))

        let coreWordIDs = Set(content.learningPath.flatMap(\.wordIds))
        let missedWord = try XCTUnwrap(content.words.first {
            !coreWordIDs.contains($0.id) && $0.canPracticeSpelling && $0.hebrewUnpointed.count <= 5
        })
        progress.completeReview(missedWord.id, grade: .again)
        let firstQuestion = try XCTUnwrap(StudyGame.spelling.questions(in: content, progress: progress).first)
        guard case let .word(word, _) = firstQuestion else { return XCTFail("Expected a spelling question") }
        XCTAssertEqual(word.id, missedWord.id)
    }

    func testStudyGameSpellingTilesIncludeEveryRequiredLetter() throws {
        let content = try StudyContent.load()
        let questions = StudyGame.spelling.questions(in: content)
        XCTAssertEqual(questions.count, 6)
        for question in questions {
            guard case let .word(word, tiles) = question else {
                return XCTFail("Expected a spelling question")
            }
            var remaining = tiles
            for letter in word.hebrewUnpointed {
                let index = try XCTUnwrap(remaining.firstIndex(of: String(letter)))
                remaining.remove(at: index)
            }
            XCTAssertEqual(remaining.count, 2)
        }
    }

    func testStudyGameListeningUsesRecordedChoices() throws {
        let content = try StudyContent.load()
        let questions = StudyGame.listening.questions(in: content)
        XCTAssertEqual(questions.count, 6)
        for question in questions {
            guard case let .listening(solution, options, _) = question else {
                return XCTFail("Expected a listening question")
            }
            XCTAssertEqual(options.filter { $0.id == solution.id }.count, 1)
            XCTAssertEqual(Set(options.map(\.hebrew)).count, options.count)
            XCTAssertTrue(options.allSatisfy { content.audio[$0.audio] != nil })
        }
    }

    func testStudyGameMatchingRoundKeepsMatchesAndCountsEachAttemptOnce() throws {
        let content = try StudyContent.load()
        for deck in [StudyMatchingDeck.letters, .words] {
            let cards = deck.cards(in: content)
            XCTAssertEqual(cards.count, 8)
            let first = try XCTUnwrap(cards.first)
            let wrong = try XCTUnwrap(cards.first { $0.pair != first.pair })
            let match = try XCTUnwrap(cards.first { $0.pair == first.pair && $0.id != first.id })
            var round = StudyMatchingRound(cards: cards)
            XCTAssertNil(round.flip(first))
            XCTAssertNil(round.flip(first))
            XCTAssertEqual(round.flip(wrong), false)
            XCTAssertNil(round.flip(match))
            XCTAssertTrue(round.hasMismatch)
            round.coverMismatch()
            XCTAssertNil(round.flip(first))
            XCTAssertEqual(round.flip(match), true)
            XCTAssertEqual(round.matched, [first.id, match.id])
            XCTAssertEqual(round.attempts, 2)
            XCTAssertFalse(round.hasMismatch)
        }
    }

    func testAIProviderEndpointsAndOpenRouterRequestBody() throws {
        let openRouter = StudyAIProvider.openRouter
        XCTAssertEqual(try openRouter.endpoint(gateway: "https://example.com").host, "openrouter.ai")
        XCTAssertEqual(try openRouter.endpoint(gateway: "").path, "/api/v1/audio/transcriptions")
        XCTAssertThrowsError(try StudyAIProvider.aliyun.endpoint(gateway: "http://example.com/transcribe"))
        XCTAssertThrowsError(try StudyAIProvider.aliyun.endpoint(gateway: "https://user@example.com/transcribe"))
        XCTAssertEqual(try StudyAIProvider.aliyun.endpoint(gateway: "https://example.com/transcribe").path, "/transcribe")
        let expectedModels = ["openai/whisper-large-v3", "microsoft/mai-transcribe-2", "elevenlabs/scribe-v2", "deepgram/nova-3"]
        XCTAssertEqual(StudyOpenRouterModel.allCases.map(\.rawValue), expectedModels)
        for choice in StudyOpenRouterModel.allCases {
            let model = try XCTUnwrap(openRouter.model(openRouter: choice))
            let body = StudyAITranscription.multipart(audio: Data([0xAA, 0xBB]), model: model, boundary: "alef-test")
            let payload = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(payload.contains("name=\"model\"\r\n\r\n\(choice.rawValue)\r\n"))
            XCTAssertTrue(payload.contains("name=\"language\"\r\n\r\nhe"))
            XCTAssertTrue(payload.hasSuffix("--alef-test--\r\n"))
            XCTAssertNotNil(body.range(of: Data([0xAA, 0xBB])))
        }
    }

    func testAITranscriptComparisonIgnoresHebrewMarksAndFindsWordDifferences() throws {
        let matching = try StudyAITranscript(text: "שלום, חבר!", expected: "שָׁלוֹם חָבֵר")
        XCTAssertTrue(matching.missingWords.isEmpty)
        XCTAssertTrue(matching.extraWords.isEmpty)

        let missing = try StudyAITranscript(text: "אני כאן", expected: "אני גר כאן")
        XCTAssertEqual(missing.missingWords, ["גר"])
        XCTAssertTrue(missing.extraWords.isEmpty)

        let repeated = try StudyAITranscript(text: "שלום שלום חבר", expected: "שלום חבר")
        XCTAssertEqual(repeated.extraWords, ["שלום"])
        XCTAssertTrue(repeated.missingWords.isEmpty)
        XCTAssertThrowsError(try StudyAITranscript(text: " ", expected: "שלום"))
    }

    func testShadowingRejectsSilenceSteadyNoiseAndShortTransients() {
        let silence = Array(repeating: Float.zero, count: 35)
        let fanNoise = Array(repeating: Float(0.012), count: 35)
        let tap = Array(repeating: Float(0.4), count: 6)
        let voice = Array(repeating: Float(0.06), count: 12)

        XCTAssertNil(StudySpeechRhythm(levels: silence, isRecording: true))
        XCTAssertNil(StudySpeechRhythm(levels: fanNoise, isRecording: true))
        XCTAssertNil(StudySpeechRhythm(levels: silence + tap + silence, isRecording: true))
        XCTAssertNotNil(StudySpeechRhythm(levels: fanNoise + voice + fanNoise, isRecording: true))
    }

    func testShadowingRejectsVeryShortFilesBeforeComparing() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800))
        buffer.frameLength = 4_800
        let samples = try XCTUnwrap(buffer.floatChannelData)
        for index in 0..<Int(buffer.frameLength) {
            samples[0][index] = index.isMultiple(of: 2) ? 0.2 : -0.2
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }

        let result = await StudyRhythmComparison.analyze(recording: url, reference: url)
        guard case .failure(let issue) = result else { return XCTFail("An immediate stop must not produce a score") }
        XCTAssertEqual(issue, .tooShort)
    }

    func testShadowingRhythmTrimsSilenceAndDetectsTimingDifferences() throws {
        let speech = Array(repeating: Float(0.15), count: 20)
        let silence = Array(repeating: Float(0), count: 10)
        let reference = try XCTUnwrap(StudySpeechRhythm(levels: speech + silence + speech))
        let paddedRecording = try XCTUnwrap(StudySpeechRhythm(levels: silence + speech + silence + speech + silence))
        let matching = paddedRecording.compare(to: reference)
        XCTAssertEqual(matching.score, 100)
        XCTAssertEqual(matching.recordingDuration, 1, accuracy: 0.001)
        XCTAssertEqual(matching.referenceDuration, 1, accuracy: 0.001)

        let shiftedPause = try XCTUnwrap(StudySpeechRhythm(
            levels: Array(speech.prefix(10)) + silence + speech + Array(speech.prefix(10))
        ))
        XCTAssertLessThan(shiftedPause.compare(to: reference).score, matching.score)

        let faster = try XCTUnwrap(StudySpeechRhythm(levels: speech))
        XCTAssertLessThan(faster.compare(to: reference).score, matching.score)
        XCTAssertNil(StudySpeechRhythm(levels: silence + silence))
        XCTAssertNil(StudySpeechRhythm(levels: silence + [0.9] + silence))
    }

    func testShadowingAcousticComparisonFindsChangedSegmentAtEqualPace() throws {
        let levels = Array(repeating: Float(0.15), count: 30)
        let opening: [Float] = [1, 0, 0]
        let middle: [Float] = [0, 1, 0]
        let ending: [Float] = [0, 0, 1]
        let spectra = Array(repeating: opening, count: 10)
            + Array(repeating: middle, count: 10)
            + Array(repeating: ending, count: 10)
        let reference = try XCTUnwrap(StudySpeechRhythm(levels: levels, spectra: spectra))
        let unchanged = try XCTUnwrap(reference.compare(to: reference).acoustic)
        XCTAssertEqual(unchanged.segments.map(\.score), [100, 100, 100])

        let changedSpectra = Array(repeating: opening, count: 20) + Array(repeating: ending, count: 10)
        let attempt = try XCTUnwrap(StudySpeechRhythm(levels: levels, spectra: changedSpectra))
        let comparison = attempt.compare(to: reference)
        XCTAssertEqual(comparison.paceScore, 100)
        XCTAssertEqual(comparison.pauseScore, 100)
        let acoustic = try XCTUnwrap(comparison.acoustic)
        XCTAssertLessThan(acoustic.score, unchanged.score)
        XCTAssertLessThan(acoustic.segments[1].score, acoustic.segments[0].score)
        XCTAssertLessThan(acoustic.segments[1].score, acoustic.segments[2].score)
    }

    func testShadowingQualityRejectsLikelyCutoffRepeatNoiseAndClipping() throws {
        let speech = Array(repeating: Float(0.15), count: 35)
        let silence = Array(repeating: Float.zero, count: 25)
        let reference = try XCTUnwrap(StudySpeechRhythm(levels: speech + silence))
        let regular = try XCTUnwrap(StudySpeechRhythm(levels: silence + speech + silence))
        XCTAssertNil(regular.qualityIssue(comparedTo: reference))

        let cutoff = try XCTUnwrap(StudySpeechRhythm(levels: Array(speech.prefix(10))))
        XCTAssertEqual(cutoff.qualityIssue(comparedTo: reference), .possiblyCutOff)
        let capped = try XCTUnwrap(StudySpeechRhythm(levels: Array(repeating: 0, count: 465) + speech))
        XCTAssertEqual(capped.qualityIssue(comparedTo: reference), .possiblyCutOff)
        let repeated = try XCTUnwrap(StudySpeechRhythm(levels: speech + silence + speech))
        XCTAssertEqual(repeated.qualityIssue(comparedTo: reference), .possibleRepeat)
        let noisy = try XCTUnwrap(StudySpeechRhythm(levels: Array(repeating: 0.09, count: 25) + speech))
        XCTAssertEqual(noisy.qualityIssue(comparedTo: reference), .noisy)
        let clipped = try XCTUnwrap(StudySpeechRhythm(levels: speech, clippingRatio: 0.05))
        XCTAssertEqual(clipped.qualityIssue(comparedTo: reference), .clipped)
    }

    func testShadowingPlaybackRangesKeepOffsetsFromOriginalAudio() throws {
        let speech = Array(repeating: Float(0.15), count: 30)
        let silence = Array(repeating: Float.zero, count: 15)
        let spectra = Array(repeating: [Float(1), 0], count: speech.count)
        let padding = Array(repeating: [Float](), count: silence.count)
        let reference = try XCTUnwrap(StudySpeechRhythm(levels: speech, spectra: spectra))
        let padded = try XCTUnwrap(StudySpeechRhythm(levels: silence + speech, spectra: padding + spectra))
        let result = try XCTUnwrap(padded.compare(to: reference).acoustic)
        XCTAssertEqual(result.segments[0].referenceRange.lowerBound, 0, accuracy: 0.001)
        XCTAssertEqual(result.segments[0].recordingRange.lowerBound, 0.30, accuracy: 0.001)
        XCTAssertEqual(result.segments[1].recordingRange.lowerBound, 0.50, accuracy: 0.001)
        XCTAssertEqual(result.segments[2].recordingRange.upperBound, 0.90, accuracy: 0.001)
    }

    func testWidgetRoutesRoundTripAndRejectInvalidDestinations() throws {
        let routes: [StudyWidgetRoute] = [
            .letter("alef"), .word("word & form/1"), .tab(.alphabet),
            .tab(.words), .tab(.practice), .tab(.rules)
        ]
        for route in routes {
            XCTAssertEqual(StudyWidgetRoute(url: try XCTUnwrap(route.url)), route)
        }
        for url in ["alef://daily-letter/unknown", "alef://daily-word",
                    "alef://study-tab/settings", "https://study-tab/words"] {
            XCTAssertNil(StudyWidgetRoute(url: try XCTUnwrap(URL(string: url))))
        }
    }

    func testLearnedWordWidgetUsesStudyRecordsAndTwoHourSlots() throws {
        progress.setWord("study", mastery: .learning)
        progress.setWord("known", mastery: .mastered)
        progress.setWord("removed", mastery: .learning)
        progress.setWord("removed", mastery: .unlearned)

        let allWords = ["study", "new", "known", "removed"].map {
            StudyWidgetWord(id: $0, hebrew: "מִלָּה", transliteration: "mila", meaningZh: $0)
        }
        let candidates = StudyWidgetWords.candidates(for: progress.learnedWidgetWordIDs, in: allWords)
        XCTAssertEqual(candidates.map(\.id), ["known", "study"])

        let now = Date(timeIntervalSince1970: 7_199)
        let dates = StudyWidgetWords.timelineDates(from: now)
        XCTAssertEqual(dates.count, 13)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates[1], Date(timeIntervalSince1970: 7_200))
        for (earlier, later) in zip(dates.dropFirst(), dates.dropFirst(2)) {
            XCTAssertEqual(later.timeIntervalSince(earlier), 7_200)
        }
        XCTAssertEqual(dates.prefix(3).map { StudyWidgetWords.word(on: $0, from: candidates)?.id },
                       ["known", "study", "known"])
        XCTAssertNil(StudyWidgetWords.word(on: now, from: []))
        XCTAssertEqual(StudyWidgetWords.word(on: dates[2], from: [candidates[1]]), candidates[1])
    }

    func testLearnedWidgetSnapshotCanUpdateAndClearAcrossProcesses() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(StudyWidgetWords.readIDs(from: file), [])
        XCTAssertTrue(try StudyWidgetWords.writeIDs(["alef", "shalom"], to: file))
        XCTAssertEqual(StudyWidgetWords.readIDs(from: file), ["alef", "shalom"])
        XCTAssertFalse(try StudyWidgetWords.writeIDs(["shalom", "alef"], to: file))
        XCTAssertTrue(try StudyWidgetWords.writeIDs([], to: file))
        XCTAssertEqual(StudyWidgetWords.readIDs(from: file), [])

        let group = StudyWidgetWords.groupID
        XCTAssertEqual(StudyWidgetWords.groupIdentifiers(signedGroups: ["group.other", group + ".TEAMID"]),
                       [group + ".TEAMID", group])
    }

    func testLearnedWidgetFindsSideStoreGroupWithoutInfoPlistMetadata() throws {
        let group = StudyWidgetWords.groupID
        let provisionedGroup = group + ".SIDETEAM01"
        let profile: [String: Any] = [
            "Entitlements": ["com.apple.security.application-groups": ["group.other", provisionedGroup]]
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
        var wrappedProfile = Data([0x30, 0x82, 0x00])
        wrappedProfile.append(plist)
        wrappedProfile.append(Data([0x31, 0x82, 0xFF]))

        XCTAssertEqual(StudyWidgetWords.groupIdentifiers(signedGroups: [], provisioningProfile: wrappedProfile),
                       [provisionedGroup, group])
        XCTAssertEqual(StudyWidgetWords.groupIdentifiers(signedGroups: [provisionedGroup, group + ".ALTTEAM001"],
                                                         provisioningProfile: wrappedProfile),
                       [provisionedGroup, group + ".ALTTEAM001", group])
        XCTAssertEqual(StudyWidgetWords.groupIdentifiers(signedGroups: [group + ".ALTTEAM001"],
                                                         provisioningProfile: Data([0x30, 0x82])),
                       [group + ".ALTTEAM001", group])
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
        let now = makeDate(year: 2026, month: 11, day: 23, hour: 19)
        let tomorrow = makeDate(year: 2026, month: 11, day: 24, hour: 20)
        let dayAfter = makeDate(year: 2026, month: 11, day: 25, hour: 20)
        let reviews = StudyReminderReviews(wordDates: [tomorrow, dayAfter], letterDates: [])
        let noReviews = StudyReminderReviews(wordDates: [], letterDates: [])
        let disabled = ReminderPreferences(enabled: false, hour: 20, minute: 0, onlyWhenDue: false)
        let dueOnly = ReminderPreferences(enabled: true, hour: 20, minute: 0, onlyWhenDue: true)

        XCTAssertNil(StudyReminderManager.makeRequest(preferences: disabled, reviews: reviews, now: now, calendar: gregorianUtc))
        XCTAssertNil(StudyReminderManager.makeRequest(preferences: dueOnly, reviews: noReviews, now: now, calendar: gregorianUtc))

        let request = StudyReminderManager.makeRequest(preferences: dueOnly, reviews: reviews, now: now, calendar: gregorianUtc)
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.repeats, false)
        XCTAssertEqual(trigger?.dateComponents.day, 24)
        XCTAssertEqual(trigger?.dateComponents.hour, 20)
        XCTAssertEqual(request?.content.title, "Alef · 有 1 项复习已到期")
        XCTAssertEqual(request?.content.userInfo["targetTab"] as? String, "flashcards")

        let late = StudyReminderReviews(wordDates: [tomorrow.addingTimeInterval(60)], letterDates: [])
        XCTAssertEqual(StudyReminderManager.nextFireDate(preferences: dueOnly, reviews: late, now: now, calendar: gregorianUtc), dayAfter)

        let alreadyDue = StudyReminderReviews(wordDates: [], letterDates: [now])
        let afterReminder = makeDate(year: 2026, month: 11, day: 23, hour: 21)
        XCTAssertEqual(StudyReminderManager.nextFireDate(preferences: dueOnly, reviews: alreadyDue,
                                                          now: afterReminder, calendar: gregorianUtc), tomorrow)

        let daily = ReminderPreferences(enabled: true, hour: 8, minute: 30, onlyWhenDue: false)
        let dailyRequest = StudyReminderManager.makeRequest(preferences: daily, reviews: noReviews, now: now, calendar: gregorianUtc)
        let dailyTrigger = dailyRequest?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(dailyRequest?.content.userInfo["targetTab"] as? String, "flashcards")
        XCTAssertEqual(dailyTrigger?.repeats, true)
        XCTAssertEqual(dailyTrigger?.dateComponents.hour, 8)
        XCTAssertEqual(dailyTrigger?.dateComponents.minute, 30)

        let mock = MockStudyNotificationCenter()
        let manager = StudyReminderManager(center: mock)
        await manager.sync(preferences: dueOnly, reviews: reviews, now: now, calendar: gregorianUtc)
        XCTAssertEqual(manager.nextScheduledDate, tomorrow)
        XCTAssertEqual(mock.addedRequests.count, 1)

        await manager.sync(preferences: disabled, reviews: reviews, now: now, calendar: gregorianUtc)
        XCTAssertNil(manager.nextScheduledDate)
        XCTAssertEqual(mock.removedIdentifiers.count, 1)
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

    func testManualThemeSurvivesLegacySystemOverrideAndLaterProgressSync() throws {
        let system = try JSONEncoder().encode("system")
        let oldCloud = [StudyProgress.appearanceKey: system]
        progress.applySyncedEntries(oldCloud, updatedAt: 100)
        XCTAssertEqual(progress.theme, .system)

        progress.theme = .rose
        let selectedAt = progress.localUpdatedAt
        XCTAssertEqual(StudyProgress(defaults: defaults).theme, .rose)

        let cloudWithNewerProgress = oldCloud.merging([
            "alef.favoriteWords.v1": try JSONEncoder().encode(["shalom"])
        ]) { _, incoming in incoming }
        let merged = StudySyncMerger.merge(local: progress.syncSnapshot(), remote: cloudWithNewerProgress,
                                           localUpdatedAt: selectedAt, remoteUpdatedAt: selectedAt + 1_000)
        progress.applySyncedEntries(merged, updatedAt: selectedAt + 1_000)
        XCTAssertEqual(progress.theme, .rose)
        XCTAssertEqual(progress.favorites, ["shalom"])

        let roseSnapshot = progress.syncSnapshot()
        progress.theme = .system
        let afterSystem = StudySyncMerger.merge(local: progress.syncSnapshot(), remote: roseSnapshot,
                                                localUpdatedAt: progress.localUpdatedAt, remoteUpdatedAt: selectedAt)
        progress.applySyncedEntries(afterSystem, updatedAt: progress.localUpdatedAt)
        XCTAssertEqual(progress.theme, .system)
    }

    func testOlderManualThemeMergesAsOneSelectionAndStillRestoresFromBackup() throws {
        let manual = [StudyProgress.themeKey: try JSONEncoder().encode(StudyTheme.violet)]
        let cloud = [StudyProgress.appearanceKey: try JSONEncoder().encode("system")]
        progress.applySyncedEntries(cloud, updatedAt: 10)

        let document = try progress.encodeSyncDocument(entries: manual, updatedAt: 20)
        let parsed = try progress.parseSyncDocument(document)
        XCTAssertNil(parsed.entries[StudyProgress.appearanceKey])
        let merged = StudySyncMerger.merge(local: parsed.entries, remote: cloud,
                                           localUpdatedAt: parsed.updatedAt, remoteUpdatedAt: 10)
        XCTAssertNil(merged[StudyProgress.appearanceKey])
        XCTAssertEqual(merged[StudyProgress.themeKey], manual[StudyProgress.themeKey])

        progress.applyBackup(try progress.previewBackup(document))
        XCTAssertEqual(progress.theme, .violet)
        progress.undoBackup()
        XCTAssertEqual(progress.theme, .system)
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
