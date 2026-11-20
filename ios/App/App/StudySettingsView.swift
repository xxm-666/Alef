import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct StudySettingsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @State private var showsDisplay = false
    @State private var showsThemes = false

    var body: some View {
        StudyPage {
            StudyHeading(section: "我的", title: "按照你的节奏学习")
            statistics
            StudySectionTitle("学习设置")
            learningSettings

            StudySectionTitle("发音与音效")
            StudyCard {
                StudySpeechControls()
                NavigationLink {
                    StudySpeechView(content: content)
                } label: {
                    StudyRow(title: "发音设置", symbol: "headphones", subtitle: "\(recordingCount) 段离线录音")
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                StudyBackupView()
            } label: {
                StudyCard(padding: 9) {
                    StudyRow(title: "数据备份与恢复", symbol: "externaldrive")
                }
            }
            .buttonStyle(.plain)

            StudySectionTitle("外观选择")
            StudyCard { StudyThemeChoices() }

            NavigationLink {
                StudyWidgetPreview(content: content)
            } label: {
                StudyCard(padding: 9) {
                    StudyRow(title: "每日字母小组件", symbol: "square.grid.2x2", subtitle: "查看今天的字母与添加方式")
                }
            }
            .buttonStyle(.plain)
            StudyNotice(title: "学习资料与记录保存在设备上", symbol: "iphone",
                        note: "内置录音和小组件可离线使用。用 JSON 备份在设备间迁移记录。")
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
        let stats = progress.statistics
        let values = [
            ("\(masteredLetters) / \(content.letters.count)", "掌握字母", "book"),
            (String(masteredWords), "掌握单词", "square.stack.3d.up"),
            (String(content.dueWords(in: progress).count), "到期复习", "calendar"),
            (String(stats.reviewsToday), "今日练习", "target"),
            (String(stats.streakDays), "连续天数", "flame"),
            (String(stats.totalReviews), "累计练习", "chart.bar.xaxis")
        ]
        let count = typeSize.isAccessibilitySize ? 1 : 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: count), spacing: 7) {
            ForEach(values, id: \.1) { value, title, symbol in
                StudyCard(padding: 8) {
                    VStack(spacing: 5) {
                        Image(systemName: symbol).font(.subheadline).foregroundStyle(title == "连续天数" ? progress.theme.reminder : progress.theme.accent)
                            .accessibilityHidden(true)
                        Text(value).font(.headline.monospacedDigit()).foregroundStyle(progress.theme.ink)
                        Text(title).font(.caption).foregroundStyle(progress.theme.mutedInk)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var learningSettings: some View {
        @Bindable var progress = progress
        return StudyCard(padding: 9) {
            Button { showsThemes = true } label: {
                StudyRow(title: "外观主题", symbol: "sun.max", value: progress.theme.title)
            }
            .buttonStyle(.plain)
            Divider()
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
                            : "使用 iOS 希伯来语语音。开启「优先离线录音」可恢复录音播放。")
            StudyNotice(title: "系统语音与音译", symbol: "info.circle",
                        note: "如果没有安装希伯来语语音，应用会尝试朗读音译。情景短语的慢速按钮固定为 0.68×。")
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
            PronunciationButton(hebrew: "שָׁלוֹם", fallback: "shalom", title: "试听发音")
            Toggle(isOn: $progress.prefersRecordings) { Label("优先离线录音", systemImage: "waveform") }
                .frame(minHeight: 44)
            Toggle(isOn: $progress.feedbackEnabled) { Label("答题与翻卡音效", systemImage: "bell") }
                .frame(minHeight: 44)
        }
        .tint(progress.theme.primaryButton)
    }
}

private struct StudyWidgetPreview: View {
    let content: StudyContent

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let today = DailyLetter.on(timeline.date)
            StudyPage {
                if let letter = content.letters.first(where: { $0.id == today.id }) {
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
                }
                StudyNotice(title: "每天一个字母", symbol: "calendar",
                            note: "小组件按手机本地日期轮换，无需联网。点按小组件可打开对应的字母详情。")
                StudyCard {
                    StudySectionTitle("添加到主屏幕")
                    Text("长按 iPhone 主屏幕，选择编辑小组件，搜索「Alef」，再添加「每日字母」。")
                        .font(.subheadline)
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
            StudySectionTitle("保存备份")
            backupAction("导出 JSON", note: "保存学习记录与偏好到文件", symbol: "square.and.arrow.up", action: export)
            backupAction("复制备份", note: "复制 JSON 到剪贴板", symbol: "doc.on.doc", action: copyBackup)
            if status == .copied { StudyNotice(title: "已复制备份", symbol: "checkmark.circle") }
            StudySectionTitle("恢复学习数据")
            backupAction("从文件恢复", note: "选择一个 Alef JSON 备份", symbol: "square.and.arrow.down") { importing = true }
            backupAction(showsBackupText ? "收起文本输入" : "粘贴文本",
                         note: "粘贴备份后，先预览将更新的项目", symbol: "doc.text") {
                showsBackupText.toggle()
            }
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
            if case let .failure(error) = outcome { message = error.localizedDescription }
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
        case "alef.wordSrs.v1": "calendar"
        case "alef.favoriteWords.v1", "alef.native.phraseFavorites.v1": "bookmark"
        case "alef.studyStats.v1": "chart.bar.xaxis"
        default: "gearshape"
        }
    }

    private func backupCount(_ key: String, data: Data?) -> String? {
        guard let data, let value = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else { return nil }
        switch key {
        case "alef.mastery.v1", "alef.wordMastery.v1", "alef.wordSrs.v1", "alef.studyStats.v1", "alef.displayConfig.v1":
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
        case "alef.favoriteWords.v1": "收藏单词"
        case "alef.native.phraseFavorites.v1": "收藏短语"
        case "alef.native.feedback.v1": "答题与翻卡音效"
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
