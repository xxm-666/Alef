import Charts
import SwiftUI
import UIKit

struct StudyRootView: View {
    private struct ReminderSyncKey: Equatable {
        let active: Bool
        let preferences: ReminderPreferences
        let reviews: StudyReminderReviews
    }

    @Environment(StudyProgress.self) private var progress
    @Environment(StudyReminderManager.self) private var reminders
    @Environment(StudyFolderSyncManager.self) private var folderSync
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.scenePhase) private var scenePhase
    let content: StudyContent
    @State private var letterPath = NavigationPath()
    @State private var wordPath = NavigationPath()
    @State private var widgetTabIDs: [StudyWidgetRoute.Tab: UUID] = [:]

    var body: some View {
        let reminderKey = reminderSyncKey
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
        .task(id: reminderKey) {
            await reminders.sync(preferences: reminderKey.preferences, reviews: reminderKey.reviews)
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

    private var reminderSyncKey: ReminderSyncKey {
        ReminderSyncKey(
            active: scenePhase == .active,
            preferences: progress.reminderPreferences,
            reviews: content.reminderReviews(in: progress)
        )
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
                .padding(.vertical, 12)
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

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(progress.theme.ink)
            .accessibilityAddTraits(.isHeader)
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
        VStack(alignment: .leading, spacing: spacing, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(highlighted ? progress.theme.highlightedSurface : progress.theme.cardSurface,
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(progress.theme.outline, lineWidth: 1)
                    .allowsHitTesting(false)
            }
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(emphasized ? Color.white : progress.theme.accent)
                .frame(minWidth: 27)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(emphasized ? Color.white : progress.theme.ink)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(emphasized ? Color.white : progress.theme.mutedInk)
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
        .padding(emphasized ? 12 : 0)
        .background(emphasized ? progress.theme.learningAction : Color.clear,
                    in: RoundedRectangle(cornerRadius: 16))
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
    var prominent = false
    var selected = false
    var learningAction = false

    func makeBody(configuration: Configuration) -> some View {
        let filled = prominent || selected || (learningAction && enabled)
        let fill = learningAction && enabled ? progress.theme.learningAction : progress.theme.primaryButton
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(filled ? Color.white : progress.theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minHeight: 44)
            .background(filled ? fill : progress.theme.insetSurface, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.58)
            .contentShape(Capsule())
    }
}

struct StudySegments<Value: Hashable>: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
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
                    Button {
                        selection = option.value
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(selection == option.value ? Color.white : progress.theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 3)
                            .background(selection == option.value ? progress.theme.primaryButton : Color.clear, in: Capsule())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option.value ? .isSelected : [])
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
    let hebrew: String
    var iconOnly = false
    var rate: Double?
    var title = "播放发音"
    var minimumHitSize: CGFloat?
    var prominent = false
    var bundledOnly = false

    var body: some View {
        Group {
            if iconOnly {
                Button(action: play) {
                    Image(systemName: "speaker.wave.2")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(progress.theme.accent)
                        .frame(width: 32, height: 32)
                        .background(progress.theme.highlightedSurface, in: Circle())
                        .frame(minWidth: minimumHitSize ?? 44, minHeight: minimumHitSize ?? 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: play) {
                    Label(title, systemImage: "play.fill").frame(maxWidth: .infinity)
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
    @Binding var value: Mastery

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("掌握度").font(.caption.weight(.semibold)).foregroundStyle(progress.theme.mutedInk)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
            layout {
                ForEach(Mastery.allCases) { level in
                    Button {
                        value = level
                    } label: {
                        Label(level.title, systemImage: level.symbol)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(level == value ? progress.theme.accent : progress.theme.ink)
                            .background(level == value ? progress.theme.highlightedSurface : progress.theme.insetSurface,
                                        in: RoundedRectangle(cornerRadius: 11))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(level == value ? .isSelected : [])
                }
            }
        }
    }
}

struct StudyActionBar<Content: View>: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: 620)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if reduceTransparency { progress.theme.canvas.ignoresSafeArea(edges: .bottom) }
                else { Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .bottom) }
            }
            .overlay(alignment: .top) { Rectangle().fill(progress.theme.outline).frame(height: 1) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(correct ? "回答正确" : "答案有误",
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
