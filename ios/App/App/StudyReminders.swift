import Foundation
import Observation
import UserNotifications

struct ReminderPreferences: Codable, Equatable, Hashable {
    static let storageKey = "alef.native.reminders.v1"

    var enabled = false
    var hour = 20
    var minute = 0
    var onlyWhenDue = false

    var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func date(on reference: Date = .now, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? reference
    }

    mutating func setTime(from date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? 20
        minute = components.minute ?? 0
    }
}

struct StudyReminderReviews: Equatable {
    let wordDates: [Date]
    let letterDates: [Date]

    var earliest: Date? {
        [wordDates.min(), letterDates.min()].compactMap { $0 }.min()
    }

    func counts(dueAt date: Date) -> (words: Int, letters: Int) {
        (wordDates.filter { $0 <= date }.count, letterDates.filter { $0 <= date }.count)
    }
}

protocol StudyNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

struct SystemStudyNotificationCenter: StudyNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
@Observable
final class StudyReminderManager {
    static let dailyReminderIdentifier = "alef.daily-study-reminder"
    static let openReminderNotification = Notification.Name("alef.reminder.open")
    private static var hasPendingOpen = false
    private static var lastOpenedReminderDate: Date?

    nonisolated static func requestOpen(for response: UNNotificationResponse) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let identifier = response.notification.request.identifier
        let deliveryDate = response.notification.date
        Task { @MainActor in
            // A tap that launches the app can reach both the scene and notification delegates.
            guard identifier == dailyReminderIdentifier, lastOpenedReminderDate != deliveryDate else { return }
            lastOpenedReminderDate = deliveryDate
            hasPendingOpen = true
            NotificationCenter.default.post(name: openReminderNotification, object: nil)
        }
    }

    static func takePendingOpen() -> Bool {
        guard hasPendingOpen else { return false }
        hasPendingOpen = false
        return true
    }

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?
    private(set) var nextScheduledDate: Date?
    @ObservationIgnored private var schedulingTask: Task<Void, Never>?
    private let center: any StudyNotificationCenter

    init(center: any StudyNotificationCenter = SystemStudyNotificationCenter()) {
        self.center = center
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            lastError = nil
            await refreshAuthorizationStatus()
            return granted
        } catch {
            lastError = error.localizedDescription
            await refreshAuthorizationStatus()
            return false
        }
    }

    func sync(preferences: ReminderPreferences, reviews: StudyReminderReviews,
              now: Date = .now, calendar: Calendar = .current) async {
        let previous = schedulingTask
        previous?.cancel()
        let task = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await updateSchedule(preferences: preferences, reviews: reviews, now: now, calendar: calendar)
        }
        schedulingTask = task
        await task.value
    }

    private func updateSchedule(preferences: ReminderPreferences, reviews: StudyReminderReviews,
                                now: Date, calendar: Calendar) async {
        await refreshAuthorizationStatus()
        guard !Task.isCancelled else { return }
        guard Self.isAuthorized(authorizationStatus),
              let request = Self.makeRequest(preferences: preferences, reviews: reviews, now: now, calendar: calendar)
        else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
            nextScheduledDate = nil
            lastError = nil
            return
        }
        do {
            // Adding the same identifier replaces the old request.
            try await center.add(request)
            nextScheduledDate = Self.nextFireDate(preferences: preferences, reviews: reviews, now: now, calendar: calendar)
            lastError = nil
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
            nextScheduledDate = nil
            lastError = error.localizedDescription
        }
    }

    static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    static func nextFireDate(preferences: ReminderPreferences, reviews: StudyReminderReviews,
                             now: Date, calendar: Calendar) -> Date? {
        guard preferences.enabled, preferences.isValid else { return nil }
        let time = DateComponents(hour: preferences.hour, minute: preferences.minute, second: 0)
        let nextTime = calendar.nextDate(after: now, matching: time, matchingPolicy: .nextTime)
        guard preferences.onlyWhenDue else { return nextTime }
        guard let earliest = reviews.earliest, let nextTime else { return nil }
        if nextTime >= earliest { return nextTime }

        // Allow a review due at exactly the preferred notification time.
        let beforeDue = earliest.addingTimeInterval(-1)
        let candidate = calendar.nextDate(after: beforeDue, matching: time, matchingPolicy: .nextTime)
        if let candidate, candidate >= earliest { return candidate }
        return calendar.nextDate(after: earliest, matching: time, matchingPolicy: .nextTime)
    }

    static func makeRequest(preferences: ReminderPreferences, reviews: StudyReminderReviews,
                            now: Date = .now, calendar: Calendar = .current) -> UNNotificationRequest? {
        guard let fireDate = nextFireDate(preferences: preferences, reviews: reviews, now: now, calendar: calendar) else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        if preferences.onlyWhenDue {
            let counts = reviews.counts(dueAt: fireDate)
            content.title = "Alef · 有 \(counts.words + counts.letters) 项复习已到期"
            switch (counts.words, counts.letters) {
            case (0, let letters): content.body = "有 \(letters) 个到期字母等你回顾。"
            case (let words, 0): content.body = "有 \(words) 个到期单词等你回顾。"
            case (let words, let letters): content.body = "有 \(words) 个单词和 \(letters) 个字母等你回顾。"
            }
        } else {
            content.title = "Alef · 每日希伯来语时间"
            content.body = "可以复习到期内容，或继续学习新词。"
        }
        let trigger: UNCalendarNotificationTrigger
        if preferences.onlyWhenDue {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            let components = DateComponents(hour: preferences.hour, minute: preferences.minute)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
        return UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
    }
}
