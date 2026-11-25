import Charts
import SwiftUI
import UIKit
import WidgetKit

struct StudyRootView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(StudyFolderSyncManager.self) private var folderSync
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.scenePhase) private var scenePhase
    let content: StudyContent
    @State private var letterPath = NavigationPath()
    @State private var wordPath = NavigationPath()
    @State private var widgetTabIDs: [StudyWidgetRoute.Tab: UUID] = [:]

    var body: some View {
        TabView(selection: Binding(get: { selectedTab }, set: { progress.write($0, for: "alef.activeView.v1") })) {
            NavigationStack(path: $letterPath) {
                AlphabetView(content: content)
                    .navigationDestination(for: String.self) { id in
                        if let letter = content.letters.first(where: { $0.id == id }) {
                            LetterStudyView(letter: letter, content: content)
                        }
                    }
            }
            .tabItem { Label("字母", systemImage: "book") }
            .id(widgetTabIDs[.alphabet]?.uuidString ?? "grid")
            .tag("grid")
            NavigationStack(path: $wordPath) {
                WordsView(content: content)
                    .navigationDestination(for: String.self) { id in
                        if let word = content.words.first(where: { $0.id == id }) {
                            WordDetailView(word: word, content: content)
                        }
                    }
            }
            .tabItem { Label("词库", systemImage: "square.stack.3d.up") }
            .id(widgetTabIDs[.words]?.uuidString ?? "words")
            .tag("words")
            NavigationStack { PracticeCenterView(content: content) }
                .tabItem { Label("练习", systemImage: "pencil") }
                .id(widgetTabIDs[.practice]?.uuidString ?? "flashcards")
                .tag("flashcards")
            NavigationStack { StudyRulesView(content: content) }
                .tabItem { Label("规则", systemImage: "list.bullet.rectangle") }
                .id(widgetTabIDs[.rules]?.uuidString ?? "rules")
                .tag("rules")
            NavigationStack { StudySettingsView(content: content) }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag("settings")
        }
        .modifier(StudyTabBarMinimization())
        .background(progress.theme.canvas)
        .tint(progress.theme.accent)
        .preferredColorScheme(progress.theme.preferredScheme)
        .onChange(of: progress.feedbackEnabled, initial: true) { _, enabled in audio.feedbackEnabled = enabled }
        .onChange(of: progress.prefersRecordings, initial: true) { _, enabled in audio.prefersRecordings = enabled }
        .onChange(of: progress.hapticsEnabled, initial: true) { _, enabled in audio.hapticsEnabled = enabled }
        .onChange(of: selectedTab) { _, _ in audio.stop() }
        .onChange(of: progress.widgetRequest, initial: true) { _, route in
            guard let route else { return }
            progress.widgetRequest = nil
            openWidgetRoute(route)
        }
        .onAppear { handlePendingReminderTab() }
        .onReceive(NotificationCenter.default.publisher(for: StudyReminderManager.openTabNotification)) { _ in
            handlePendingReminderTab()
        }
        .background {
            StudyReminderSyncBridge(content: content)
            StudyWidgetWordsSyncBridge()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard (phase == .active || phase == .background) && folderSync.isConfigured else { return }
            Task { await folderSync.sync(progress: progress) }
        }
        .task(id: progress.syncRevision) {
            guard progress.syncRevision > 0 && folderSync.isConfigured else { return }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            await folderSync.sync(progress: progress)
        }
        .alert("发音", isPresented: Binding(get: { audio.playbackError != nil }, set: { visible in
            if !visible { audio.dismissError() }
        })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(audio.playbackError ?? "")
        }
    }

    private func openWidgetRoute(_ route: StudyWidgetRoute) {
        switch route {
        case .letter(let id):
            guard content.letters.contains(where: { $0.id == id }) else { return }
            letterPath = NavigationPath([id])
            progress.write(StudyWidgetRoute.Tab.alphabet.rawValue, for: "alef.activeView.v1")
        case .word(let id):
            guard content.words.contains(where: { $0.id == id }) else { return }
            wordPath = NavigationPath([id])
            progress.write(StudyWidgetRoute.Tab.words.rawValue, for: "alef.activeView.v1")
        case .tab(let tab):
            switch tab {
            case .alphabet: letterPath = NavigationPath()
            case .words: wordPath = NavigationPath()
            case .practice, .rules: break
            }
            // Recreate the stack so a shortcut also dismisses view-based navigation destinations.
            widgetTabIDs[tab] = UUID()
            progress.write(tab.rawValue, for: "alef.activeView.v1")
        }
    }

    private func handlePendingReminderTab() {
        guard let tab = StudyReminderManager.pendingTargetTab else { return }
        StudyReminderManager.pendingTargetTab = nil
        if ["grid", "words", "flashcards", "rules", "settings"].contains(tab) {
            progress.write(tab, for: "alef.activeView.v1")
        }
    }

    private var selectedTab: String {
        let saved = progress.read("alef.activeView.v1", default: "grid")
        return ["words", "flashcards", "rules", "settings"].contains(saved) ? saved : "grid"
    }
}

private struct StudyWidgetWordsSyncBridge: View {
    @Environment(StudyProgress.self) private var progress

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: progress.learnedWidgetWordIDs, initial: true) { _, ids in
                guard let url = StudyWidgetWords.snapshotURL,
                      (try? StudyWidgetWords.writeIDs(ids, to: url)) == true else { return }
                WidgetCenter.shared.reloadTimelines(ofKind: StudyWidgetWords.kind)
            }
    }
}

private struct StudyReminderSyncBridge: View {
    private struct ReminderSyncKey: Equatable {
        let active: Bool
        let preferences: ReminderPreferences
        let reviews: StudyReminderReviews
    }

    @Environment(StudyProgress.self) private var progress
    @Environment(StudyReminderManager.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    let content: StudyContent

    var body: some View {
        let key = ReminderSyncKey(
            active: scenePhase == .active,
            preferences: progress.reminderPreferences,
            reviews: content.reminderReviews(in: progress)
        )
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: key) {
                await reminders.sync(preferences: key.preferences, reviews: key.reviews)
            }
    }
}

extension StudyTheme {
    var preferredScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .white, .parchment, .rose, .violet: .light
        }
    }

    var accent: Color { palette(light: dayAccent, dark: 0x83D7D3) }
    var canvas: Color {
        let light: UInt32 = switch self {
        case .white: 0xF9FBF9
        case .parchment: 0xF7F0E3
        case .rose: 0xFBF1F3
        case .violet: 0xF5F1FA
        default: 0xF8F7F3
        }
        return palette(light: light, dark: 0x11232B)
    }

    var ink: Color { palette(light: 0x142B34, dark: 0xEDF5F5) }
    var mutedInk: Color { palette(light: 0x4F656C, dark: 0xA9C0C7) }
    var cardSurface: Color {
        let light: UInt32 = switch self {
        case .parchment: 0xFFFBF3
        case .rose: 0xFFFAFB
        case .violet: 0xFDFAFF
        default: 0xFFFFFD
        }
        return palette(light: light, dark: 0x1B313A)
    }
    var insetSurface: Color {
        let light: UInt32 = switch self {
        case .parchment: 0xF3EADC
        case .rose: 0xF7E8ED
        case .violet: 0xEEE8F7
        default: 0xEFF3F3
        }
        return palette(light: light, dark: 0x233F49)
    }
    var highlightedSurface: Color {
        let light: UInt32 = switch self {
        case .rose: 0xF7E3EA
        case .violet: 0xEEE5F8
        default: 0xDDEFF0
        }
        return palette(light: light, dark: 0x244950)
    }
    var outline: Color { palette(light: 0xDCE5E4, dark: 0x38535C) }
    var primaryButton: Color { palette(light: dayAccent, dark: 0x166369) }
    var learningAction: Color { palette(light: 0x2452A3, dark: 0x3B6BBB) }
    var success: Color { palette(light: 0x246457, dark: 0xA9E4D0) }
    var successSurface: Color { palette(light: 0xE3F0E9, dark: 0x24443C) }
    var error: Color { palette(light: 0x993D45, dark: 0xFFB2B8) }
    var errorSurface: Color { palette(light: 0xF8E8EA, dark: 0x4E3039) }
    var reminder: Color { palette(light: 0x88612A, dark: 0xF3C989) }
    var reminderSurface: Color { palette(light: 0xFBF0DA, dark: 0x473B2D) }

    private var dayAccent: UInt32 {
        switch self {
        case .rose: 0x893B58
        case .violet: 0x5D4685
        default: 0x17686D
        }
    }

    var heroGradient: [Color] {
        switch self {
        case .white:
            return [palette(light: 0x155E75, dark: 0x0F766E), palette(light: 0x0D9488, dark: 0x0284C7)]
        case .parchment:
            return [palette(light: 0x0F766E, dark: 0x0F766E), palette(light: 0xB45309, dark: 0xD97706)]
        case .rose:
            return [palette(light: 0x9D174D, dark: 0x9D174D), palette(light: 0xE11D48, dark: 0xBE185D)]
        case .violet:
            return [palette(light: 0x5B21B6, dark: 0x5B21B6), palette(light: 0x4F46E5, dark: 0x4338CA)]
        case .dark:
            return [palette(light: 0x0F766E, dark: 0x0F766E), palette(light: 0x1D4ED8, dark: 0x1D4ED8)]
        case .system:
            return [palette(light: 0x0E7490, dark: 0x0F766E), palette(light: 0x2563EB, dark: 0x1D4ED8)]
        }
    }

    var warmGradient: [Color] {
        [palette(light: 0xB45309, dark: 0x9A3412), palette(light: 0xC2410C, dark: 0xB45309)]
    }

    var indigoGradient: [Color] {
        [palette(light: 0x4F46E5, dark: 0x4338CA), palette(light: 0x0E7490, dark: 0x0F766E)]
    }

    var ambientGlow: Color {
        switch self {
        case .parchment: palette(light: 0xD97706, dark: 0xF59E0B).opacity(0.14)
        case .rose: palette(light: 0xF43F5E, dark: 0xFB7185).opacity(0.14)
        case .violet: palette(light: 0x8B5CF6, dark: 0xA78BFA).opacity(0.16)
        default: palette(light: 0x0EA5E9, dark: 0x2DD4BF).opacity(0.15)
        }
    }

    var cardShadow: Color {
        palette(light: 0x0F172A, dark: 0x000000).opacity(0.08)
    }

    private func palette(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

struct StudyPage<Content: View>: View {
    @Environment(StudyProgress.self) private var progress
    var maxWidth: CGFloat = 620
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16, content: content)
                .frame(maxWidth: maxWidth, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
        }
        .background(progress.theme.canvas.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }
}

struct StudyHeading: View {
    @Environment(StudyProgress.self) private var progress
    let title: String
    var eyebrow: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(progress.theme.accent)
            }
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(progress.theme.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StudySectionTitle: View {
    @Environment(StudyProgress.self) private var progress
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(progress.theme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

struct StudyCard<Content: View>: View {
    @Environment(StudyProgress.self) private var progress
    var highlighted = false
    var padding: CGFloat = 14
    var spacing: CGFloat = 10
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: spacing, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(highlighted ? progress.theme.highlightedSurface : progress.theme.cardSurface, in: shape)
            .overlay {
                shape
                    .strokeBorder(progress.theme.outline.opacity(0.75), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct StudyHeroCard<Content: View>: View {
    @Environment(StudyProgress.self) private var progress
    var colors: [Color]? = nil
    var padding: CGFloat = 16
    var spacing: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let stops = colors ?? progress.theme.heroGradient
        VStack(alignment: .leading, spacing: spacing, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .foregroundStyle(Color.white)
            .background {
                LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 140, height: 140)
                            .offset(x: 42, y: -48)
                            .allowsHitTesting(false)
                    }
                    .clipShape(shape)
            }
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct StudyIconBadge: View {
    let symbol: String
    var colors: [Color]
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

struct StudyProgressRing: View {
    let value: Double
    let total: Double
    var lineWidth: CGFloat = 5
    var size: CGFloat = 52
    var tint: Color = .white

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, value / total))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.24), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct StudyRow: View {
    @Environment(StudyProgress.self) private var progress
    let title: String
    let symbol: String
    var subtitle: String? = nil
    var value: String? = nil
    var chevron = true
    var emphasized = false
    var badgeColors: [Color]? = nil

    var body: some View {
        HStack(spacing: 11) {
            if let badgeColors, !emphasized {
                StudyIconBadge(symbol: symbol, colors: badgeColors)
            } else {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(emphasized ? Color.white : progress.theme.accent)
                    .frame(minWidth: 27)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(emphasized ? Color.white : progress.theme.ink)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(emphasized ? Color.white.opacity(0.9) : progress.theme.mutedInk)
                }
            }
            Spacer(minLength: 0)
            if let value {
                Text(value).font(.caption).foregroundStyle(emphasized ? Color.white : progress.theme.mutedInk)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(emphasized ? Color.white : progress.theme.mutedInk)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .padding(emphasized ? 14 : 0)
        .background {
            if emphasized {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: progress.theme.heroGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct StudyNotice: View {
    @Environment(StudyProgress.self) private var progress
    let title: String
    let symbol: String
    var note: String? = nil
    var reminder = false

    var body: some View {
        StudyRow(title: title, symbol: symbol, subtitle: note, chevron: false)
            .padding(.horizontal, 9)
            .background(reminder ? progress.theme.reminderSurface : progress.theme.highlightedSurface,
                        in: RoundedRectangle(cornerRadius: 12))
    }
}

enum StudyProficiencyStyle {
    private static let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0.58, 0.64, 0.72), // 柔和灰
        (0.18, 0.94, 0.27, 0.27), // 珊瑚红
        (0.38, 0.96, 0.62, 0.04), // 琥珀黄
        (0.58, 0.23, 0.51, 0.96), // 天青蓝
        (0.78, 0.55, 0.36, 0.96), // 优雅紫
        (0.90, 0.08, 0.72, 0.65), // 青碧过渡
        (1.00, 0.06, 0.73, 0.51)  // 翡翠绿
    ]

    static var spectrumGradient: LinearGradient {
        LinearGradient(
            stops: stops.map {
                Gradient.Stop(color: Color(red: $0.r, green: $0.g, blue: $0.b), location: $0.t)
            },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func color(for proficiency: Int) -> Color {
        let t = min(1.0, max(0.0, Double(proficiency) / 100.0))
        guard let upperIndex = stops.firstIndex(where: { $0.t >= t }) else {
            let last = stops[stops.count - 1]
            return Color(red: last.r, green: last.g, blue: last.b)
        }
        if upperIndex == 0 {
            let first = stops[0]
            return Color(red: first.r, green: first.g, blue: first.b)
        }
        let low = stops[upperIndex - 1]
        let high = stops[upperIndex]
        let span = max(0.0001, high.t - low.t)
        let ratio = (t - low.t) / span
        return Color(
            red: low.r + (high.r - low.r) * ratio,
            green: low.g + (high.g - low.g) * ratio,
            blue: low.b + (high.b - low.b) * ratio
        )
    }

    static func stageTitle(for proficiency: Int) -> String {
        switch min(100, max(0, proficiency)) {
        case 0: "未开始"
        case 1..<25: "初识"
        case 25..<45: "初记"
        case 45..<65: "巩固"
        case 65..<85: "熟悉"
        case 85..<100: "熟练"
        default: "牢记"
        }
    }
}

struct StudyProficiencyMeter: View {
    @Environment(StudyProgress.self) private var progress
    let proficiency: Int
    var width: CGFloat? = nil
    var height: CGFloat = 7

    var body: some View {
        let clamped = min(100, max(0, proficiency))
        let fraction = Double(clamped) / 100.0
        Capsule()
            .fill(progress.theme.insetSurface)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let filledWidth = clamped == 0 ? 0 : max(height, proxy.size.width * fraction)
                    StudyProficiencyStyle.spectrumGradient
                        .frame(width: proxy.size.width, height: height)
                        .mask(alignment: .leading) {
                            Capsule()
                                .frame(width: filledWidth, height: height)
                        }
                }
            }
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("记忆熟练度 \(StudyProficiencyStyle.stageTitle(for: clamped))")
            .accessibilityValue("\(clamped)%")
    }
}

struct StudyProficiencyCard: View {
    @Environment(StudyProgress.self) private var progress
    let proficiency: Int
    let schedule: ReviewSchedule?
    let mastery: Mastery
    var onToggleRemembered: (() -> Void)? = nil

    private var tint: Color {
        StudyProficiencyStyle.color(for: proficiency)
    }

    private var subtitle: String {
        if let schedule {
            if schedule.isDecayed(mastery: mastery) {
                return "久未复习记忆有所回落 · 下次复习 \(schedule.displayDate)"
            }
            return "下次复习 · \(schedule.displayDate)（间隔 \(schedule.intervalLabel)）"
        }
        return proficiency == 0 ? "正常拼读或复习会自动累积熟练度" : "继续练习颜色会逐步过渡到绿色"
    }

    var body: some View {
        StudyCard(padding: 12, spacing: 8) {
            HStack(spacing: 8) {
                Label("记忆熟练度", systemImage: "brain.head.profile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.ink)
                Spacer(minLength: 4)
                HStack(spacing: 5) {
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                    Text(StudyProficiencyStyle.stageTitle(for: proficiency))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(progress.theme.ink)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(tint.opacity(0.16), in: Capsule())
            }
            StudyProficiencyMeter(proficiency: proficiency, height: 8)
            HStack(alignment: .center, spacing: 8) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(schedule?.isDue == true ? progress.theme.reminder : progress.theme.mutedInk)
                if let onToggleRemembered {
                    Spacer(minLength: 4)
                    let remembered = mastery == .mastered
                    Button(action: onToggleRemembered) {
                        Label(remembered ? "已记住" : "标记已记住",
                              systemImage: remembered ? "checkmark.seal.fill" : "checkmark.seal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(remembered ? progress.theme.success : progress.theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                remembered ? progress.theme.successSurface : progress.theme.accent.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(remembered ? "已记住，点按恢复常规练习" : "标记为已记住，30 天后再抽查")
                }
            }
        }
    }
}

struct StudyMemoryCurveEntry: View {
    enum Item {
        case letter, word

        var reviewInstructions: String {
            switch self {
            case .letter: "在「复习字母」提交答案，或翻开字母闪卡后选择自评。闪卡自评和到期题首次作答会更新排程。"
            case .word: "在「复习单词」首次提交答案后，系统根据作答结果和以往记录安排下次复习。完成「今日记词」的单词拼写也会更新排程。"
            }
        }

        func resultLabel(for grade: ReviewGrade) -> String {
            switch self {
            case .letter: grade.title
            case .word: grade == .again ? "答错" : "答对"
            }
        }
    }

    @State private var showsCurve = false
    let schedule: ReviewSchedule?
    let item: Item

    var body: some View {
        Button {
            showsCurve = true
        } label: {
            Label("记忆曲线", systemImage: "chart.line.downtrend.xyaxis")
                .labelStyle(.iconOnly)
        }
        .sheet(isPresented: $showsCurve) {
            NavigationStack {
                StudyMemoryCurveView(schedule: schedule, item: item)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showsCurve = false }
                        }
                    }
            }
        }
    }
}

private struct StudyMemoryCurveView: View {
    @Environment(StudyProgress.self) private var progress
    let schedule: ReviewSchedule?
    let item: StudyMemoryCurveEntry.Item

    var body: some View {
        StudyPage {
            if let schedule, schedule.intervalDays > 0, schedule.intervalDays <= ReviewSchedule.maxIntervalDays,
               let startDate = Calendar.current.date(byAdding: .day, value: -schedule.intervalDays, to: schedule.reviewDate) {
                StudyCard {
                    StudySectionTitle("预计记忆保留")
                    curve(interval: Double(schedule.intervalDays))
                    Text("虚线标出下次复习。示意曲线从 100% 逐渐下降，并以计划复习日的 80% 为参考。百分比是模型假设，实际记忆因人而异。")
                        .font(.footnote)
                        .foregroundStyle(progress.theme.mutedInk)
                }
                StudyCard {
                    if let lastReview = schedule.lastReview {
                        StudyRow(title: "最近正式复习", symbol: "clock",
                                 subtitle: lastReview.date.formatted(date: .abbreviated, time: .shortened),
                                 value: item.resultLabel(for: lastReview.grade), chevron: false)
                    } else {
                        StudyRow(title: "本轮起点（推算）", symbol: "clock",
                                 subtitle: startDate.formatted(date: .abbreviated, time: .shortened), chevron: false)
                    }
                    scheduleRow(schedule)
                    StudyRow(title: "当前间隔", symbol: "arrow.left.and.right",
                             value: schedule.intervalLabel, chevron: false)
                }
            } else if let schedule {
                StudyCard { scheduleRow(schedule) }
                Text("这条排程没有可用于绘制曲线的复习间隔。完成一次复习后即可查看。")
                    .foregroundStyle(progress.theme.mutedInk)
            } else {
                ContentUnavailableView("暂无复习安排", systemImage: "chart.line.downtrend.xyaxis",
                                       description: Text("将此项目标记为「学习中」，即可安排第一次复习。"))
            }
            StudyCard {
                StudySectionTitle("怎样算一次复习")
                Text(item.reviewInstructions)
                Text("首次答错会安排更早再练。同轮补练计入练习次数，沿用首次作答安排的复习时间。")
                    .foregroundStyle(progress.theme.mutedInk)
            }
            .font(.subheadline)
        }
        .navigationTitle("记忆曲线")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scheduleRow(_ schedule: ReviewSchedule) -> some View {
        StudyRow(title: schedule.isDue ? "下次复习 · 已到期" : "下次复习", symbol: "calendar",
                 subtitle: schedule.reviewDate.formatted(date: .abbreviated, time: .shortened), chevron: false)
    }

    private func curve(interval: Double) -> some View {
        Chart {
            ForEach(0...40, id: \.self) { step in
                let fraction = Double(step) / 40 * 1.5
                // Illustrative exponential decay, anchored at 80% on the scheduled review day.
                LineMark(x: .value("排程后的天数", fraction * interval),
                         y: .value("预计记忆保留", pow(0.8, fraction)))
                    .foregroundStyle(progress.theme.learningAction)
            }
            RuleMark(x: .value("下次复习", interval))
                .foregroundStyle(progress.theme.mutedInk)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartXScale(domain: 0...(interval * 1.5))
        .chartXAxis {
            AxisMarks(values: [0.0, interval]) { value in
                AxisTick()
                AxisValueLabel {
                    if let day = value.as(Double.self) { Text("第 \(Int(day)) 天") }
                }
            }
        }
        .chartYScale(domain: 0.0...1.0)
        .chartYAxis {
            AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let ratio = value.as(Double.self) { Text(ratio, format: .percent) }
                }
            }
        }
        .frame(height: 180)
        .accessibilityHidden(true)
    }
}

struct StudyButtonStyle: ButtonStyle {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var prominent = false
    var selected = false
    var learningAction = false

    func makeBody(configuration: Configuration) -> some View {
        let filled = prominent || selected || (learningAction && enabled)
        let fill = learningAction && enabled ? progress.theme.learningAction : progress.theme.primaryButton
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(filled ? Color.white : progress.theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(minHeight: 44)
            .background(filled ? fill : progress.theme.insetSurface, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.84 : 1) : 0.58)
            .scaleEffect(reduceMotion || !enabled ? 1 : (configuration.isPressed ? 0.96 : 1))
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct StudySegments<Value: Hashable>: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var segmentNamespace
    let title: String
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        if typeSize.isAccessibilitySize {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.value) { option in Text(option.title).tag(option.value) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(progress.theme.insetSurface, in: Capsule())
        } else {
            HStack(spacing: 3) {
                ForEach(options, id: \.value) { option in
                    let isSelected = selection == option.value
                    Button {
                        if reduceMotion {
                            selection = option.value
                        } else {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                                selection = option.value
                            }
                        }
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(isSelected ? Color.white : progress.theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 4)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(progress.theme.primaryButton)
                                        .matchedGeometryEffect(id: "activeSegment", in: segmentNamespace)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(3)
            .background(progress.theme.insetSurface, in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }
}

extension View {
    func studyHome() -> some View {
        modifier(StudyHomeBars())
    }

    func studyDetail(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
    }

    func studyGlassSurface(cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(StudyGlassSurfaceModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}

private struct StudyTabBarMinimization: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

private struct StudyGlassSurfaceModifier: ViewModifier {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(progress.theme.cardSurface, in: shape)
                .overlay {
                    shape.strokeBorder(progress.theme.outline, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        } else if #available(iOS 26, *) {
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(progress.theme.outline.opacity(0.65), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct StudyHomeBars: ViewModifier {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let page = content
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.visible, for: .tabBar)
        if reduceTransparency {
            page
                .toolbarBackground(progress.theme.cardSurface, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        } else if #available(iOS 26, *) {
            page
        } else {
            page
                .toolbarBackground(.thinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }
}

struct PronunciationButton: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let hebrew: String
    var iconOnly = false
    var rate: Double?
    var title = "播放发音"
    var minimumHitSize: CGFloat?
    var prominent = false
    var bundledOnly = false

    private var isPlaying: Bool {
        audio.playingPronunciation == hebrew
    }

    var body: some View {
        Group {
            if iconOnly {
                Button(action: play) {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isPlaying ? Color.white : progress.theme.accent)
                        .symbolEffect(.variableColor, isActive: isPlaying && !reduceMotion)
                        .frame(width: 34, height: 34)
                        .background(isPlaying ? progress.theme.accent : progress.theme.highlightedSurface, in: Circle())
                        .overlay {
                            if isPlaying {
                                Circle()
                                    .strokeBorder(progress.theme.accent.opacity(0.45), lineWidth: 2)
                                    .scaleEffect(1.18)
                            }
                        }
                        .frame(minWidth: minimumHitSize ?? 44, minHeight: minimumHitSize ?? 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: play) {
                    Label {
                        Text(title)
                    } icon: {
                        Image(systemName: isPlaying ? "waveform" : "play.fill")
                            .symbolEffect(.variableColor, isActive: isPlaying && !reduceMotion)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(prominent: prominent))
            }
        }
        .accessibilityLabel(title)
    }

    private func play() {
        audio.speak(hebrew, rate: rate ?? progress.speechRate, bundledOnly: bundledOnly)
    }
}

struct HebrewText: View {
    @Environment(StudyProgress.self) private var progress
    let text: String
    var cursive = false
    var size: CGFloat = 26
    var style: Font.TextStyle = .body
    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .font(cursive ? .custom("GveretLevin-Regular", size: size, relativeTo: style)
                  : .system(size: size * scale, weight: .semibold, design: .serif))
            .foregroundStyle(progress.theme.ink)
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
            .speechSpellsOutCharacters(text.count == 1)
    }
}

struct MasteryPicker: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var masteryNamespace
    @Binding var value: Mastery

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("掌握度").font(.caption.weight(.semibold)).foregroundStyle(progress.theme.mutedInk)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 4))
            layout {
                ForEach(Mastery.allCases) { level in
                    let isSelected = level == value
                    Button {
                        if progress.hapticsEnabled {
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        if reduceMotion {
                            value = level
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                value = level
                            }
                        }
                    } label: {
                        Label(level.title, systemImage: level.symbol)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(isSelected ? selectedForeground(for: level) : progress.theme.ink)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedBackground(for: level))
                                        .matchedGeometryEffect(id: "masteryPill", in: masteryNamespace)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    private func selectedForeground(for level: Mastery) -> Color {
        switch level {
        case .mastered: progress.theme.success
        case .learning: progress.theme.learningAction
        case .unlearned: progress.theme.ink
        }
    }

    private func selectedBackground(for level: Mastery) -> Color {
        switch level {
        case .mastered: progress.theme.successSurface
        case .learning: progress.theme.highlightedSurface
        case .unlearned: progress.theme.cardSurface
        }
    }
}

struct StudyActionBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: 620)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .studyGlassSurface(cornerRadius: 26, interactive: false)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
    }
}

struct StudyAnswerButton: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let submitted: Bool
    let selected: Bool
    let correct: Bool
    var isHebrew = false
    var optionLabel: String?
    var playing = false
    let action: () -> Void

    private var surface: Color {
        if submitted && correct { return progress.theme.successSurface }
        if submitted && selected { return progress.theme.errorSurface }
        return selected ? progress.theme.highlightedSurface : progress.theme.cardSurface
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let optionLabel {
                    Text(optionLabel)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(progress.theme.mutedInk)
                        .frame(width: 25, height: 25)
                        .background(progress.theme.insetSurface, in: Circle())
                        .accessibilityHidden(true)
                }
                if isHebrew { HebrewText(text: title, size: 28) }
                else { Text(title).foregroundStyle(progress.theme.ink) }
                Spacer()
                if playing {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(progress.theme.learningAction)
                        .symbolEffect(.variableColor, isActive: !reduceMotion)
                        .accessibilityLabel("播放中")
                }
                if submitted && (selected || correct) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? progress.theme.success : progress.theme.error)
                        .accessibilityLabel(correct ? "正确答案" : "答案有误")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? progress.theme.accent : progress.theme.outline, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(submitted)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct StudyQuizFeedback: View {
    @Environment(StudyProgress.self) private var progress
    @AccessibilityFocusState(for: .voiceOver) private var focused: Bool
    @State private var didFocus = false
    let correct: Bool
    let solution: String
    var response: String?
    var explanation: String?
    var combo = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(correct ? (combo > 1 ? "回答正确 · \(combo) 连击" : "回答正确") : "答案有误",
                  systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(correct ? progress.theme.success : progress.theme.error)
            if !correct, let response {
                Text("你的答案  \(response)").foregroundStyle(progress.theme.mutedInk)
            }
            Text("正确答案  \(solution)")
            if let explanation, !explanation.isEmpty {
                Text(explanation).foregroundStyle(progress.theme.mutedInk)
            }
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(correct ? progress.theme.successSurface : progress.theme.errorSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityFocused($focused)
        .onAppear {
            guard !didFocus else { return }
            focused = true
            didFocus = true
        }
    }
}

extension View {
    func studyAnswerCelebration(_ celebration: StudyAnswerCelebration?) -> some View {
        overlay(alignment: .top) {
            StudyAnswerCelebrationOverlay(celebration: celebration)
                .padding(.top, 16)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct StudyAnswerCelebrationOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible: StudyAnswerCelebration?
    let celebration: StudyAnswerCelebration?

    var body: some View {
        ZStack {
            if let visible {
                StudyAnswerToast(celebration: visible)
                    .id(visible.id)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .task(id: celebration) {
            visible = celebration
            guard let celebration else { return }
            do {
                try await Task.sleep(for: .milliseconds(celebration.isMilestone ? 1_200 : 850))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { visible = nil }
        }
    }
}

private struct StudyAnswerToast: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    let celebration: StudyAnswerCelebration

    var body: some View {
        let theme = progress.theme
        let tint = celebration.isMilestone ? theme.reminder : theme.success
        ZStack {
            if celebration.isMilestone && !reduceMotion {
                fireworks(colors: [theme.reminder, theme.success, theme.accent])
            }
            Label(celebration.combo > 1 ? "\(celebration.combo) 连击" : "回答正确",
                  systemImage: celebration.isMilestone ? "sparkles" : "hand.thumbsup.fill")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(celebration.isMilestone ? theme.reminderSurface : theme.successSurface, in: Capsule())
                .overlay { Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1) }
                .shadow(color: theme.cardShadow, radius: 4, y: 2)
                .scaleEffect(expanded || reduceMotion ? 1 : 0.74)
                .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.58), value: expanded)
        }
        .onAppear { expanded = true }
    }

    private func fireworks(colors: [Color]) -> some View {
        ForEach(0..<12, id: \.self) { index in
            let angle = Double(index) * Double.pi / 6
            let radius = index.isMultiple(of: 2) ? 1.0 : 0.78
            let size: CGFloat = index.isMultiple(of: 3) ? 6 : 4
            Circle()
                .fill(colors[index % colors.count])
                .frame(width: size, height: size)
                .offset(x: expanded ? CGFloat(cos(angle) * 96 * radius) : 0,
                        y: expanded ? CGFloat(sin(angle) * 30 * radius) : 0)
                .animation(.easeOut(duration: 0.54), value: expanded)
                .opacity(expanded ? 0 : 1)
                .animation(.easeOut(duration: 0.45).delay(0.22), value: expanded)
        }
    }
}

func studyOptionLabel(_ index: Int) -> String {
    let labels = ["A", "B", "C", "D"]
    return labels.indices.contains(index) ? labels[index] : String(index + 1)
}

struct StudyQuizSummary: View {
    @Environment(StudyProgress.self) private var progress
    let title: String
    let correct: Int
    let answered: Int
    var message: String? = nil

    var body: some View {
        StudyCard(highlighted: true) {
            VStack(spacing: 14) {
                Image(systemName: "trophy")
                    .font(.largeTitle)
                    .foregroundStyle(progress.theme.reminder)
                    .accessibilityHidden(true)
                Text(title).font(.title2.bold()).foregroundStyle(progress.theme.ink)
                Text("\(correct) / \(answered)")
                    .font(.title.bold().monospacedDigit())
                    .accessibilityLabel("答对 \(correct) 题，共 \(answered) 题")
                if let message {
                    Label(message, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(progress.theme.mutedInk)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }
}
