import SwiftUI
import UIKit
import UserNotifications

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let tab = response.notification.request.content.userInfo["targetTab"] as? String {
            Task { @MainActor in
                StudyReminderManager.pendingTargetTab = tab
                NotificationCenter.default.post(name: StudyReminderManager.openTabNotification, object: tab)
            }
        }
        completionHandler()
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var audio: StudyAudio?
    private var progress: StudyProgress?
    private var reminders: StudyReminderManager?
    private var legacyImport: LegacyStudyImport?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        do {
            let content = try StudyContent.load()
            let progress = StudyProgress()
            self.progress = progress
            progress.dailyLetterRequest = connectionOptions.urlContexts.lazy.compactMap { DailyLetter.id(from: $0.url) }.first
            let audio = StudyAudio(recordings: content.audio)
            self.audio = audio
            let reminders = StudyReminderManager()
            self.reminders = reminders
            window.rootViewController = UIHostingController(rootView: StudyRootView(content: content)
                .environment(progress)
                .environment(reminders)
                .environmentObject(audio))
            if progress.needsLegacyMigration {
                let migration = LegacyStudyImport(progress: progress)
                legacyImport = migration
                migration.start()
            }
        } catch {
            window.rootViewController = UIHostingController(rootView:
                ContentUnavailableView("无法载入学习资料", systemImage: "book.closed",
                                       description: Text("此版本的学习资料缺失或损坏。"))
                    .foregroundStyle(StudyTheme.system.ink)
                    .tint(StudyTheme.system.accent)
                    .background(StudyTheme.system.canvas.ignoresSafeArea())
            )
            NSLog("Alef could not load its study resources: %@", error.localizedDescription)
        }
        window.makeKeyAndVisible()
    }

    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        if let id = contexts.lazy.compactMap({ DailyLetter.id(from: $0.url) }).first {
            progress?.dailyLetterRequest = id
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        audio?.stop()
    }
}
