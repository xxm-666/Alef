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
    static let openTabNotification = Notification.Name("alef.reminder.openTab")
    static var pendingTargetTab: String?

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?
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

    func sync(preferences: ReminderPreferences, dueWords: Int, dueLetters: Int,
              streakDays: Int, todayReviews: Int, now: Date = .now) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
        await refreshAuthorizationStatus()
        guard Self.isAuthorized(authorizationStatus),
              let request = Self.makeRequest(
                  preferences: preferences,
                  dueWords: dueWords,
                  dueLetters: dueLetters,
                  streakDays: streakDays,
                  todayReviews: todayReviews,
                  now: now
              ) else { return }
        do {
            try await center.add(request)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    static func makeRequest(preferences: ReminderPreferences, dueWords: Int, dueLetters: Int,
                            streakDays: Int, todayReviews: Int, now: Date = .now,
                            calendar: Calendar = .current) -> UNNotificationRequest? {
        guard preferences.enabled, preferences.isValid else { return nil }
        let safeWords = max(0, dueWords)
        let safeLetters = max(0, dueLetters)
        let totalDue = safeWords + safeLetters
        if preferences.onlyWhenDue && totalDue == 0 { return nil }

        let content = UNMutableNotificationContent()
        content.sound = .default
        if totalDue > 0 {
            content.title = "Alef · 有 \(totalDue) 项复习已到期"
            if safeWords > 0 && safeLetters > 0 {
                content.body = "包含 \(safeWords) 个单词和 \(safeLetters) 个字母，趁热打铁巩固记忆。"
            } else if safeWords > 0 {
                content.body = "有 \(safeWords) 个到期单词等你回顾。"
            } else {
                content.body = "有 \(safeLetters) 个到期字母等你回顾。"
            }
            content.userInfo = ["targetTab": "flashcards"]
        } else {
            content.title = "Alef · 每日希伯来语时间"
            if todayReviews > 0 {
                content.body = "今天已完成 \(todayReviews) 次练习，继续保持手感或学几个新词吧。"
            } else if streakDays > 0 {
                content.body = "已连续学习 \(streakDays) 天，花几分钟保持今日学习记录吧。"
            } else {
                content.body = "花几分钟拼读几个希伯来字母和常用词吧。"
            }
            content.userInfo = ["targetTab": "grid"]
        }

        let trigger: UNCalendarNotificationTrigger
        if preferences.onlyWhenDue {
            let todayTarget = preferences.date(on: now, calendar: calendar)
            let fireDate = todayTarget > now
                ? todayTarget
                : (calendar.date(byAdding: .day, value: 1, to: todayTarget) ?? todayTarget)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            let components = DateComponents(hour: preferences.hour, minute: preferences.minute)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        return UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
    }
}
