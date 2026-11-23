import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct StudySettingsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(StudyFolderSyncManager.self) private var folderSync
    let content: StudyContent
    @State private var showsDisplay = false
    @State private var showsThemes = false

    var body: some View {
        StudyPage {
            StudyHeading(title: "学习与设置")
            statistics

            StudySectionTitle("学习偏好")
            learningSettings

            StudySectionTitle("外观与设备")
            StudyCard(padding: 10, spacing: 2) {
                Button { showsThemes = true } label: {
                    StudyRow(title: "外观主题", symbol: "sun.max", value: progress.theme.title)
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    StudyWidgetPreview(content: content)
                } label: {
                    StudyRow(title: "每日字母小组件", symbol: "square.grid.2x2")
                }
                .buttonStyle(.plain)
            }

            StudySectionTitle("语音与数据")
            StudyCard(padding: 10, spacing: 2) {
                NavigationLink {
                    StudySpeechView(content: content)
                } label: {
                    StudyRow(title: "发音与音效", symbol: "headphones", subtitle: "\(recordingCount) 段离线录音")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    StudyAISettingsView()
                } label: {
                    StudyRow(title: "AI 功能", symbol: "waveform.badge.magnifyingglass",
                             subtitle: "跟读识别服务")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    StudyBackupView()
                } label: {
                    StudyRow(title: "数据备份与恢复", symbol: "externaldrive", subtitle: backupSubtitle)
                }
                .buttonStyle(.plain)
            }
        }
        .studyHome()
        .sheet(isPresented: $showsDisplay) {
            NavigationStack { StudyLetterDisplayView(content: content) }.presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsThemes) {
            NavigationStack { StudyAppearanceView() }.presentationDragIndicator(.visible)
        }
    }

    private var recordingCount: Int { Set(content.audio.values).count }

    private var statistics: some View {
        let letterMastery = progress.letterMastery
        let wordMastery = progress.wordMastery
        let masteredLetters = content.letters.filter { letterMastery[$0.id] == .mastered }.count
        let masteredWords = content.words.filter { wordMastery[$0.id] == .mastered }.count
        let dueCount = content.dueWords(in: progress).count + content.dueLetters(in: progress).count
        let stats = progress.statistics
        return StudyCard(padding: 10) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("掌握字母", value: "\(masteredLetters) / \(content.letters.count)")
                    LabeledContent("掌握单词", value: "\(masteredWords)")
                    LabeledContent("到期复习", value: "\(dueCount)")
                    LabeledContent("累计练习", value: "\(stats.totalReviews)")
                }
                .font(.subheadline)
                .foregroundStyle(progress.theme.mutedInk)
                .padding(.top, 4)
            } label: {
                StudyRow(title: "学习进度", symbol: "chart.bar",
                         subtitle: "今日练习 \(stats.reviewsToday) 次 · 连续 \(stats.streakDays) 天", chevron: false)
            }
        }
    }

    private var learningSettings: some View {
        @Bindable var progress = progress
        return StudyCard(padding: 9, spacing: 2) {
            Toggle(isOn: $progress.alphabetFromRight) {
                StudyRow(title: "字母从右向左排列", symbol: "arrow.left.arrow.right",
                         subtitle: progress.alphabetFromRight ? "RTL" : "LTR", chevron: false)
            }
            .tint(progress.theme.primaryButton)
            Divider()
            Button { showsDisplay = true } label: {
                StudyRow(title: "字母卡片显示项", symbol: "rectangle.3.group")
            }
            .buttonStyle(.plain)
            Divider()
            NavigationLink {
                StudyReminderSettingsView(content: content)
            } label: {
                StudyRow(title: "学习提醒", symbol: "bell.badge", value: reminderSummary)
            }
            .buttonStyle(.plain)
        }
    }

    private var reminderSummary: String {
        let pref = progress.reminderPreferences
        return pref.enabled ? "\(pref.timeText)\(pref.onlyWhenDue ? " · 到期时" : "")" : "已关闭"
    }

    private var backupSubtitle: String? {
        switch folderSync.state {
        case .failed:
            return "同步出错，点按查看详情"
        case .syncing:
            return "正在同步 · \(folderSync.folderName ?? "iCloud Drive")"
        case .synced, .idle:
            return "自动同步 · \(folderSync.folderName ?? "iCloud Drive")"
        case .unconfigured:
            return progress.backupReminderMessage()
        }
    }
}

private struct StudyReminderSettingsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(StudyReminderManager.self) private var reminders
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    let content: StudyContent
    @State private var deniedAlert = false

    private var pref: ReminderPreferences { progress.reminderPreferences }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { pref.enabled && StudyReminderManager.isAuthorized(reminders.authorizationStatus) },
            set: { nextValue in
                if !nextValue {
                    var updated = pref
                    updated.enabled = false
                    progress.reminderPreferences = updated
                    return
                }
                Task {
                    await reminders.refreshAuthorizationStatus()
                    if reminders.authorizationStatus == .denied {
                        deniedAlert = true
                        return
                    }
                    let granted = StudyReminderManager.isAuthorized(reminders.authorizationStatus)
                        ? true
                        : await reminders.requestAuthorization()
                    var updated = progress.reminderPreferences
                    updated.enabled = granted
                    progress.reminderPreferences = updated
                    if !granted { deniedAlert = true }
                }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { pref.date() },
            set: { newDate in
                var updated = pref
                updated.setTime(from: newDate)
                progress.reminderPreferences = updated
            }
        )
    }

    private var onlyWhenDueBinding: Binding<Bool> {
        Binding(
            get: { pref.onlyWhenDue },
            set: { value in
                var updated = pref
                updated.onlyWhenDue = value
                progress.reminderPreferences = updated
            }
        )
    }

    var body: some View {
        let dueWords = content.dueWords(in: progress).count
        let dueLetters = content.dueLetters(in: progress).count
        let preview = StudyReminderManager.makeRequest(
            preferences: pref,
            dueWords: dueWords,
            dueLetters: dueLetters,
            streakDays: progress.statistics.streakDays,
            todayReviews: progress.statistics.reviewsToday
        )
        StudyPage {
            StudyCard {
                Toggle(isOn: enabledBinding) {
                    StudyRow(title: "每日学习提醒", symbol: "bell.badge",
                             subtitle: "离线本地推送，不会上传学习数据", chevron: false)
                }
                .tint(progress.theme.primaryButton)
                if pref.enabled {
                    Divider()
                    DatePicker("提醒时间", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(progress.theme.ink)
                    Divider()
                    Toggle(isOn: onlyWhenDueBinding) {
                        StudyRow(title: "仅在有到期复习时提醒", symbol: "calendar.badge.clock",
                                 subtitle: "无到期单词或字母时不打扰", chevron: false)
                    }
                    .tint(progress.theme.primaryButton)
                }
            }

            if reminders.authorizationStatus == .denied {
                StudyNotice(title: "系统通知权限未开启", symbol: "bell.slash",
                            note: "请在系统设置中允许 Alef 发送通知。", reminder: true)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("前往系统设置开启", systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(prominent: true))
            }

            if let error = reminders.lastError {
                StudyNotice(title: "提醒安排失败", symbol: "exclamationmark.triangle", note: error, reminder: true)
            }

            if let preview {
                StudySectionTitle("下一次提醒预览")
                StudyCard(highlighted: true) {
                    Text(preview.content.title).font(.headline).foregroundStyle(progress.theme.ink)
                    Text(preview.content.body).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                }
            } else if pref.enabled && pref.onlyWhenDue {
                StudyNotice(title: "当前没有到期复习项目", symbol: "checkmark.circle",
                            note: "有单词或字母到期后，将在 \(pref.timeText) 提醒你。")
            }
        }
        .studyDetail("学习提醒")
        .task { await reminders.refreshAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await reminders.refreshAuthorizationStatus() }
            }
        }
        .alert("需要通知权限", isPresented: $deniedAlert) {
            Button("取消", role: .cancel) {}
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: {
            Text("请在「设置 → Alef → 通知」中开启允许通知，才能按计划收到学习提醒。")
        }
    }
}

private struct StudyAppearanceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StudyPage {
            StudyCard { StudyThemeChoices() }
            StudyNotice(title: "跟随系统", symbol: "circle.lefthalf.filled", note: "根据 iOS 外观在暖白与深色之间切换。")
        }
        .studyDetail("外观主题")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
        }
    }
}

private struct StudyThemeChoices: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let count = typeSize.isAccessibilitySize ? 2 : (typeSize >= .xLarge ? 3 : 6)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: count), spacing: 6) {
            ForEach(StudyTheme.allCases) { theme in
                Button {
                    progress.theme = theme
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(swatch(theme))
                            .frame(width: 27, height: 27)
                            .overlay { Circle().strokeBorder(progress.theme.outline, lineWidth: 1) }
                            .overlay {
                                if progress.theme == theme {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme == .dark ? Color.white : Color.black)
                                }
                            }
                        Text(theme == .system ? "系统" : theme.title).font(.caption2.weight(.medium))
                            .foregroundStyle(progress.theme.ink)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 53)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.title)
                .accessibilityAddTraits(progress.theme == theme ? .isSelected : [])
            }
        }
    }

    private func swatch(_ theme: StudyTheme) -> Color {
        switch theme {
        case .system: Color(red: 0.71, green: 0.88, blue: 0.87)
        case .white: .white
        case .parchment: Color(red: 0.92, green: 0.86, blue: 0.76)
        case .rose: Color(red: 0.95, green: 0.81, blue: 0.85)
        case .violet: Color(red: 0.86, green: 0.81, blue: 0.94)
        case .dark: Color(red: 0.07, green: 0.15, blue: 0.18)
        }
    }
}

private struct StudySpeechView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        StudyPage {
            StudyCard { StudySpeechControls() }
            StudyNotice(title: "\(Set(content.audio.values).count) 段内置离线录音", symbol: "waveform",
                        note: progress.prefersRecordings
                            ? "有录音时优先播放录音，缺少录音时使用 iOS 希伯来语语音。"
                            : "优先使用 iOS 希伯来语语音。系统语音不可用时会尝试播放内置音频。")
            StudyNotice(title: "练习音频", symbol: "info.circle",
                        note: "单词听力和拼读示范使用内置音频。情景短语的慢速按钮固定为 0.68×。")
        }
        .studyDetail("发音与音效")
    }
}

private struct StudySpeechControls: View {
    @Environment(StudyProgress.self) private var progress

    var body: some View {
        @Bindable var progress = progress
        VStack(alignment: .leading, spacing: 7) {
            LabeledContent {
                Text("\(progress.speechRate.formatted(.number.precision(.fractionLength(2))))×")
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(progress.theme.accent)
            } label: {
                Label("全局发音速度", systemImage: "speedometer")
            }
            .font(.subheadline)
            Slider(value: $progress.speechRate, in: 0.5...1.5, step: 0.05) { Text("全局发音速度") }
                .frame(minHeight: 44)
            HStack {
                Text("0.50×")
                Spacer()
                Text("1.50×")
            }
            .font(.caption)
            .foregroundStyle(progress.theme.mutedInk)
            .accessibilityHidden(true)
            PronunciationButton(hebrew: "שָׁלוֹם", title: "试听发音")
            Toggle(isOn: $progress.prefersRecordings) { Label("优先离线录音", systemImage: "waveform") }
                .frame(minHeight: 44)
            Toggle(isOn: $progress.feedbackEnabled) { Label("答题与翻卡音效", systemImage: "bell") }
                .frame(minHeight: 44)
            Toggle(isOn: $progress.hapticsEnabled) { Label("触感反馈", systemImage: "iphone.radiowaves.left.and.right") }
                .frame(minHeight: 44)
        }
        .tint(progress.theme.primaryButton)
    }
}

private struct StudyWidgetPreview: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let today = DailyLetter.on(timeline.date)
            StudyPage {
                if let letter = content.letters.first(where: { $0.id == today.id }) {
                    StudySectionTitle("主屏幕小组件")
                    NavigationLink {
                        LetterStudyView(letter: letter, content: content)
                    } label: {
                        DailyLetterCard(letter: today)
                            .padding(14)
                            .frame(width: 154, height: 154)
                            .background { DailyLetterBackground() }
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                    StudySectionTitle("锁屏小组件")
                    NavigationLink {
                        LetterStudyView(letter: letter, content: content)
                    } label: {
                        StudyCard {
                            HStack(spacing: 16) {
                                DailyLetterCircularContent(letter: today)
                                    .frame(width: 60, height: 60)
                                    .background(progress.theme.insetSurface, in: Circle())
                                DailyLetterRectangularContent(letter: today)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .foregroundStyle(progress.theme.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
                StudyNotice(title: "每天一个字母", symbol: "calendar",
                            note: "小组件按手机本地日期轮换，无需联网。点按小组件可打开对应的字母详情。")
                StudyCard {
                    StudySectionTitle("添加方式")
                    Text("主屏幕：长按主屏幕，点左上角「编辑 → 添加小组件」，搜索「Alef」。")
                        .font(.subheadline)
                    Text("锁屏：长按锁定屏幕 → 自定 → 点击锁屏时间下方小组件区并搜索「Alef」。")
                        .font(.subheadline)
                        .foregroundStyle(progress.theme.mutedInk)
                }
            }
        }
        .studyDetail("每日字母小组件")
    }
}

struct StudyLetterDisplayView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss
    let content: StudyContent
    @State private var draft: [String: Bool]?
    @State private var editingCustom = false

    private let displayOptions = [
        ("showBlock", "印刷体"), ("showCursive", "手写体"), ("showSofit", "词尾形"),
        ("showBegadkefat", "达盖什字形"), ("showHebrewName", "希伯来语名称"),
        ("showEnglishName", "英文名称"), ("showChineseName", "中文名称"),
        ("showModernSound", "现代读音"), ("showBiblicalDiff", "古典读音"),
        ("showTransliteration", "音译"), ("showGematria", "Gematria 字母数值"),
        ("showMastery", "掌握度"), ("showCategoryBadges", "字母分类")
    ]

    private var config: [String: Bool] { draft ?? content.letterDisplay(in: progress) }
    private var scholar: [String: Bool] {
        content.displayPresets.first { $0.id == "scholar" }?.config ?? content.defaultDisplay
    }
    private var selectedPreset: String {
        if editingCustom { return "custom" }
        if config == content.introductoryDisplay { return "beginner" }
        if config == scholar { return "scholar" }
        return "custom"
    }

    var body: some View {
        StudyPage {
            StudySegments(title: "显示预设", options: [("beginner", "入门"), ("scholar", "精学"), ("custom", "自定义")],
                          selection: Binding(get: { selectedPreset }, set: { preset in
                editingCustom = preset == "custom"
                if preset == "beginner" { draft = content.introductoryDisplay }
                if preset == "scholar" { draft = scholar }
            }))
            if let example = content.letters.first(where: { $0.id == "kaf" }) ?? content.letters.first {
                StudySectionTitle("卡片预览")
                StudyCard {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        LetterTileContent(letter: example, options: config)
                        if config["showMastery"] == true {
                            let level = progress.letterMastery[example.id] ?? .unlearned
                            Label(level.title, systemImage: level.symbol)
                                .font(.caption)
                                .foregroundStyle(progress.theme.accent)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            StudyCard {
                ForEach(Array(displayOptions.prefix(8)), id: \.0) { key, title in
                    displayToggle(key, title: title)
                }
                Text("至少保留一种字形。").font(.caption).foregroundStyle(progress.theme.mutedInk)
            }
            StudyCard {
                DisclosureGroup("更多显示项 · 5 项") {
                    ForEach(Array(displayOptions.dropFirst(8)), id: \.0) { key, title in
                        displayToggle(key, title: title)
                    }
                    Menu {
                        ForEach(content.displayPresets.filter { ["writing", "quiz_mask"].contains($0.id) }) { preset in
                            Button(preset.label) {
                                editingCustom = true
                                draft = content.displayWithGlyph(preset.config)
                            }
                        }
                    } label: {
                        Label("其他预设", systemImage: "rectangle.3.group").frame(minHeight: 44)
                    }
                }
            }
        }
        .studyDetail("定制字母卡片")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("完成", action: save) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StudyActionBar {
                Button(action: save) { Text("应用到字母表").frame(maxWidth: .infinity) }
                    .buttonStyle(StudyButtonStyle(prominent: true))
            }
        }
    }

    private func displayToggle(_ key: String, title: String) -> some View {
        let otherGlyph = key == "showBlock" ? "showCursive" : "showBlock"
        let glyph = key == "showBlock" || key == "showCursive"
        return Toggle(title, isOn: Binding(get: { config[key] == true }, set: { enabled in
            var options = config
            options[key] = enabled
            draft = content.displayWithGlyph(options)
            editingCustom = true
        }))
        .tint(progress.theme.primaryButton)
        .frame(minHeight: 44)
        .disabled(glyph && config[key] == true && config[otherGlyph] != true)
    }

    private func save() {
        progress.write(config, for: "alef.displayConfig.v1")
        dismiss()
    }
}

private struct StudyBackupView: View {
    @Environment(StudyProgress.self) private var progress
    @State private var importing = false
    @State private var exporting = false
    @State private var undoConfirmation = false
    @State private var backup: StudyBackupDocument?
    @State private var preview: BackupPreview?
    @State private var message: String?
    @State private var status: BackupStatus?
    @State private var showsBackupText = false
    @State private var backupText = ""

    private struct BackupPreview: Identifiable {
        let id = UUID()
        let entries: [String: Data]
        let changes: [String]
    }

    private enum BackupStatus {
        case copied
        case unchanged
        case restored
        case undone
    }

    var body: some View {
        StudyPage {
            StudyFolderSyncSection()
            if let reminder = progress.backupReminderMessage() {
                StudyNotice(title: "建议保存新备份", symbol: "exclamationmark.shield", note: reminder, reminder: true)
            } else if let lastDate = progress.lastBackupDate {
                StudyNotice(title: "最近备份 · \(lastDate.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "zh_CN"))))",
                            symbol: "checkmark.shield")
            }
            StudySectionTitle("手动备份与导出")
            backupAction("导出 JSON", note: "保存学习记录与偏好到文件", symbol: "square.and.arrow.up", action: export)
            if status == .copied { StudyNotice(title: "已复制备份", symbol: "checkmark.circle") }
            StudySectionTitle("恢复学习数据")
            backupAction("从文件恢复", note: "选择一个 Alef JSON 备份", symbol: "square.and.arrow.down") { importing = true }
            Menu {
                Button("复制备份", systemImage: "doc.on.doc", action: copyBackup)
                Button(showsBackupText ? "收起文本输入" : "粘贴备份文本", systemImage: "doc.text") {
                    showsBackupText.toggle()
                }
            } label: {
                Label("更多备份操作", systemImage: "ellipsis")
            }
            .buttonStyle(StudyButtonStyle())
            if showsBackupText {
                StudyCard {
                    StudySectionTitle("JSON 备份文本")
                    TextEditor(text: $backupText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 142)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Alef JSON 备份文本")
                    PasteButton(payloadType: String.self) { values in
                        if let text = values.first { backupText = text }
                    }
                    Button("预览备份", systemImage: "doc.text.magnifyingglass") {
                        prepareBackup(Data(backupText.utf8))
                    }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                    .disabled(backupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if status == .unchanged { StudyNotice(title: "备份内容与当前数据相同", symbol: "info.circle") }
            if status == .restored { StudyNotice(title: "已恢复学习数据", symbol: "checkmark.circle") }
            if status == .undone { StudyNotice(title: "已撤销上次恢复", symbol: "arrow.uturn.backward") }
            if progress.restorePoint != nil {
                backupAction("撤销上次导入", note: "恢复到导入前的数据", symbol: "arrow.uturn.backward") {
                    undoConfirmation = true
                }
            }
        }
        .studyDetail("数据备份与恢复")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], onCompletion: prepareImport)
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "alef-backup") { outcome in
            switch outcome {
            case .success:
                progress.markBackupExported()
            case let .failure(error):
                message = error.localizedDescription
            }
        }
        .sheet(item: $preview) { pending in
            NavigationStack { restorePreview(pending) }
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("撤销上次导入？", isPresented: $undoConfirmation, titleVisibility: .visible) {
            Button("撤销导入", role: .destructive) {
                progress.undoBackup()
                status = .undone
            }
        }
        .alert("Alef 备份", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func backupAction(_ title: String, note: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            StudyCard(padding: 8) {
                StudyRow(title: title, symbol: symbol, subtitle: note)
            }
        }
        .buttonStyle(.plain)
    }

    private func restorePreview(_ pending: BackupPreview) -> some View {
        StudyPage {
            StudySectionTitle("将更新 \(pending.changes.count) 项数据")
            StudyCard {
                ForEach(pending.changes, id: \.self) { key in
                    StudyRow(title: backupLabel(key), symbol: backupSymbol(key), value: backupCount(key, data: pending.entries[key]),
                             chevron: false)
                }
            }
            StudyNotice(title: "恢复后仍可撤销", symbol: "info.circle",
                        note: "可在备份页撤销最近一次导入。")
        }
        .studyDetail("确认恢复内容")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { preview = nil }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StudyActionBar {
                VStack(spacing: 6) {
                    Button {
                        progress.applyBackup(pending.entries)
                        preview = nil
                        backupText = ""
                        showsBackupText = false
                        status = .restored
                    } label: {
                        Label("确认恢复", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                    Button {
                        preview = nil
                    } label: {
                        Text("取消，保留当前数据").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyButtonStyle())
                }
            }
        }
    }

    private func backupSymbol(_ key: String) -> String {
        switch key {
        case "alef.mastery.v1": "book"
        case "alef.wordMastery.v1": "square.stack.3d.up"
        case "alef.wordSrs.v1", StudyProgress.letterScheduleKey: "calendar"
        case ReminderPreferences.storageKey: "bell.badge"
        case StudyProgress.lastBackupAtKey: "clock"
        case "alef.favoriteWords.v1", "alef.native.phraseFavorites.v1": "bookmark"
        case "alef.studyStats.v1": "chart.bar.xaxis"
        default: "gearshape"
        }
    }

    private func backupCount(_ key: String, data: Data?) -> String? {
        guard let data, let value = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else { return nil }
        switch key {
        case "alef.mastery.v1", "alef.wordMastery.v1", "alef.wordSrs.v1", StudyProgress.letterScheduleKey,
             "alef.studyStats.v1", "alef.displayConfig.v1":
            return (value as? [String: Any]).map { "\($0.count) 项" }
        case "alef.favoriteWords.v1", "alef.native.phraseFavorites.v1":
            return (value as? [String]).map { "\($0.count) 项" }
        default:
            return nil
        }
    }

    private func prepareImport(_ outcome: Result<URL, Error>) {
        do {
            let url = try outcome.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            prepareBackup(try Data(contentsOf: url))
        } catch {
            message = error.localizedDescription
        }
    }

    private func prepareBackup(_ data: Data) {
        preview = nil
        status = nil
        do {
            let entries = try progress.previewBackup(data)
            let changes = progress.backupChanges(entries)
            guard !changes.isEmpty else {
                status = .unchanged
                return
            }
            preview = BackupPreview(entries: entries, changes: changes)
        } catch {
            message = error.localizedDescription
        }
    }

    private func copyBackup() {
        status = nil
        do {
            UIPasteboard.general.string = String(decoding: try progress.exportBackup(), as: UTF8.self)
            progress.markBackupExported()
            status = .copied
        } catch {
            message = error.localizedDescription
        }
    }

    private func backupLabel(_ key: String) -> String {
        switch key {
        case "alef.mastery.v1": "字母掌握度"
        case "alef.wordMastery.v1": "单词掌握度"
        case "alef.wordSrs.v1": "单词复习排期"
        case StudyProgress.letterScheduleKey: "字母复习排期"
        case ReminderPreferences.storageKey: "学习提醒"
        case DailyVocabularyPlan.storageKey: "今日记词进度"
        case "alef.favoriteWords.v1": "收藏单词"
        case "alef.native.phraseFavorites.v1": "收藏短语"
        case "alef.native.feedback.v1": "答题与翻卡音效"
        case "alef.native.haptics.v1": "触感反馈"
        case StudyProgress.lastBackupAtKey: "上次备份时间"
        case "alef.native.recordings.v1": "离线录音偏好"
        case "alef.studyStats.v1": "学习统计"
        case "alef.theme.v1": "主题"
        case "alef.native.appearance.v1": "iOS 外观模式"
        case "alef.dayTheme.v1": "日间主题"
        case "alef.order.v1": "阅读方向"
        case "alef.speechRate.v1": "朗读速度"
        case "alef.activeView.v1": "上次打开的页面"
        case "alef.selectedLetterId.v1": "上次查看的字母"
        case "alef.displayConfig.v1": "字母表显示选项"
        case "alef.rulesTab.v1": "规则页选项"
        case "alef.gridState.v1": "旧版字母表选项"
        case "alef.wordsState.v1": "词表选项"
        case "alef.flashcardState.v1": "闪卡选项"
        default: key
        }
    }

    private func export() {
        do {
            backup = StudyBackupDocument(data: try progress.exportBackup())
            exporting = true
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct StudyFolderSyncSection: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(StudyFolderSyncManager.self) private var folderSync
    @State private var pickingFolder = false
    @State private var disconnecting = false
    @State private var pickerError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudySectionTitle("iCloud Drive 文件夹自动同步")
            if folderSync.isConfigured {
                configuredCard
            } else {
                unconfiguredCard
            }
            if let pickerError {
                StudyNotice(title: "无法读取所选文件夹", symbol: "exclamationmark.triangle",
                            note: pickerError, reminder: true)
            }
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { outcome in
            switch outcome {
            case let .success(url):
                pickerError = nil
                Task { await folderSync.configureFolder(url: url, progress: progress) }
            case let .failure(error):
                pickerError = error.localizedDescription
            }
        }
        .confirmationDialog("断开文件夹同步？", isPresented: $disconnecting, titleVisibility: .visible) {
            Button("断开同步", role: .destructive) { folderSync.disconnect() }
        } message: {
            Text("仅移除同步关联，不会删除文件夹中已保存的 \(StudyFolderSyncManager.syncFileName)。")
        }
    }

    private var unconfiguredCard: some View {
        StudyCard(highlighted: true) {
            StudyRow(title: "免付费账号自动云同步", symbol: "icloud",
                     subtitle: "授权「iCloud Drive」中你自建的文件夹后，会自动把 \(StudyFolderSyncManager.syncFileName) 同步到云端。",
                     chevron: false)
            StudyNotice(title: "请勿选在「我的 iPhone → Alef」目录中", symbol: "info.circle",
                        note: "请选在 iCloud Drive 下自建文件夹（如 iCloud Drive/Alef），卸载或重装后重新选该文件夹即可自动恢复。")
            Button {
                pickingFolder = true
            } label: {
                Label("选择 iCloud Drive 文件夹", systemImage: "folder.badge.plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle(prominent: true))
        }
    }

    private var configuredCard: some View {
        StudyCard(highlighted: true) {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol)
                    .font(.title3)
                    .foregroundStyle(isFailed ? progress.theme.error : progress.theme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(folderSync.folderName ?? "同步文件夹")
                        .font(.headline)
                        .foregroundStyle(progress.theme.ink)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(isFailed ? progress.theme.error : progress.theme.mutedInk)
                    if let summary = folderSync.lastSummary, !isFailed {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                }
                Spacer(minLength: 0)
                if folderSync.state == .syncing {
                    ProgressView()
                }
            }

            HStack(spacing: 6) {
                Button {
                    Task { await folderSync.sync(progress: progress, force: true) }
                } label: {
                    Label("立即同步", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(prominent: true))
                .disabled(folderSync.state == .syncing)

                Button {
                    pickingFolder = true
                } label: {
                    Text("更换文件夹")
                }
                .buttonStyle(StudyButtonStyle())
            }

            Button(role: .destructive) {
                disconnecting = true
            } label: {
                Label("断开同步", systemImage: "xmark.circle")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle())
        }
    }

    private var isFailed: Bool {
        if case .failed = folderSync.state { return true }
        return false
    }

    private var statusSymbol: String {
        switch folderSync.state {
        case .failed: "exclamationmark.icloud"
        case .syncing: "icloud.and.arrow.up"
        default: "checkmark.icloud"
        }
    }

    private var statusText: String {
        switch folderSync.state {
        case .unconfigured:
            return "未配置"
        case .idle:
            return "已连接 · 等待首次同步"
        case .syncing:
            return "正在同步 \(StudyFolderSyncManager.syncFileName)…"
        case let .synced(date):
            return "上次同步 · \(date.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "zh_CN"))))"
        case let .failed(message):
            return message
        }
    }
}

private struct StudyBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct StudyAISettingsView: View {
    @Environment(StudyProgress.self) private var progress
    @AppStorage(StudyAIKeychain.enabledKey) private var enabled = false
    @AppStorage(StudyAIKeychain.providerKey) private var provider = StudyAIProvider.openAI
    @AppStorage(StudyOpenRouterModel.preferenceKey) private var openRouterModel = StudyOpenRouterModel.whisper
    @AppStorage(StudyAIKeychain.gatewayKey) private var gateway = ""
    @AppStorage(StudyAIKeychain.revisionKey) private var revision = 0
    @State private var gatewayDraft = ""
    @State private var draft = ""
    @State private var hasKey = false
    @State private var message: String?

    var body: some View {
        StudyPage {
            StudyCard {
                Toggle("启用 AI 功能", isOn: $enabled)
                Text("录完后选择识别服务，才会发送本次录音。网络和用量费用由所选服务决定。")
                    .font(.footnote)
                    .foregroundStyle(progress.theme.mutedInk)
            }
            StudyCard {
                Picker("配置服务", selection: $provider) {
                    ForEach(StudyAIProvider.allCases) { service in
                        Text(service.title).tag(service)
                    }
                }
                if provider == .openRouter {
                    Picker("转写模型", selection: $openRouterModel) {
                        ForEach(StudyOpenRouterModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    Text("切换模型会立即生效，继续使用同一把 OpenRouter API 密钥。")
                        .font(.footnote)
                        .foregroundStyle(progress.theme.mutedInk)
                }
                if provider == .aliyun {
                    aliyunKeyInstructions
                    TextField("HTTPS 测试网关完整地址", text: $gatewayDraft)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if hasKey {
                    Label("密钥已保存在本机钥匙串", systemImage: "lock.fill")
                        .foregroundStyle(progress.theme.success)
                }
                SecureField(hasKey ? "输入新密钥以替换" : (provider == .aliyun ? "粘贴网关测试密钥" : "粘贴 API 密钥"), text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                Button("保存配置") { saveConfiguration() }
                    .buttonStyle(StudyButtonStyle(prominent: true))
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                              !(provider == .aliyun && hasKey && gatewayDraft != gateway))
                if hasKey {
                    Button("移除密钥", role: .destructive) { removeKey() }
                }
                Text("各服务单独保存密钥，不随 iCloud 同步或学习备份迁移。")
                    .font(.footnote)
                    .foregroundStyle(progress.theme.mutedInk)
                if let message {
                    Text(message).font(.footnote).foregroundStyle(progress.theme.error)
                }
            }
        }
        .studyDetail("AI 功能")
        .onChange(of: provider, initial: true) { _, _ in
            draft = ""
            gatewayDraft = gateway
            message = nil
            do { hasKey = try StudyAIKeychain.read(for: provider) != nil }
            catch {
                hasKey = false
                message = error.localizedDescription
            }
        }
    }

    private var aliyunKeyInstructions: some View {
        DisclosureGroup("如何获取阿里云密钥？") {
            VStack(alignment: .leading, spacing: 8) {
                Text("网关测试密钥由网关管理员生成。自己部署时，可运行 openssl rand -hex 24，把同一个值写入服务端 ALEF_GATEWAY_KEY，再粘贴到下方。已有网关时，向管理员获取 HTTPS 地址和测试密钥。")
                Text("项目 AppKey 在阿里云智能语音交互控制台的「全部项目」获取。创建录音文件识别项目，选择「通用-希伯来语（16 kHz）」，将 AppKey 填入服务端 ALEF_NLS_APP_KEY。阿里云 RAM AccessKey 也只配置在服务端。")
                Link("打开阿里云智能语音交互控制台", destination: URL(string: "https://nls-portal.console.aliyun.com/")!)
                Link("查看阿里云模型配置说明", destination: URL(string: "https://help.aliyun.com/zh/isi/user-guide/api-reference-2")!)
            }
            .font(.footnote)
            .foregroundStyle(progress.theme.mutedInk)
            .padding(.top, 8)
        }
    }

    private func saveConfiguration() {
        do {
            if provider == .aliyun { _ = try provider.endpoint(gateway: gatewayDraft) }
            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try StudyAIKeychain.save(draft, for: provider)
                hasKey = true
            }
            if provider == .aliyun { gateway = gatewayDraft }
            revision += 1
            draft = ""
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try StudyAIKeychain.remove(for: provider)
            hasKey = false
            revision += 1
            draft = ""
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
}
