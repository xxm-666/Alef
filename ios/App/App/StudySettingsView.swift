import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct StudySettingsView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        @Bindable var progress = progress
        Form {
            Section {
                Picker("主题", selection: $progress.theme) {
                    ForEach(StudyTheme.allCases) { theme in Text(theme.title).tag(theme) }
                }
                Toggle("字母从右向左排列", isOn: $progress.alphabetFromRight)
                NavigationLink {
                    StudyLetterDisplayView(content: content)
                } label: {
                    Label("字母表显示", systemImage: "rectangle.3.group")
                }
            } header: {
                Text("外观")
            } footer: {
                if progress.theme == .system {
                    Text("随 iOS 外观自动切换，浅色时使用白色主题，深色时使用深色主题。")
                }
            }
            Section("发音") {
                LabeledContent("发音速度") { Text(progress.speechRate, format: .number.precision(.fractionLength(2))) }
                Slider(value: $progress.speechRate, in: 0.5...1.5, step: 0.05) { Text("发音速度") }
                PronunciationButton(hebrew: "שָׁלוֹם", fallback: "shalom", title: "试听发音", minimumHitSize: 44)
                LabeledContent("内置离线录音", value: String(Set(content.audio.values).count))
            }
            Section("学习记录") {
                LabeledContent("今日练习", value: String(progress.statistics.reviewsToday))
                LabeledContent("连续学习天数", value: String(progress.statistics.streakDays))
                NavigationLink {
                    StudyStatisticsView(content: content)
                } label: {
                    Label("完整学习统计", systemImage: "chart.bar")
                }
            }
            Section {
                NavigationLink {
                    StudyBackupView()
                } label: {
                    Label("备份与恢复", systemImage: "externaldrive")
                }
            }
        }
        .studyGroupedBackground()
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StudyStatisticsView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        List {
            Section("掌握度") {
                LabeledContent("已掌握字母", value: "\(progress.letterMastery.values.filter { $0 == .mastered }.count) / \(content.letters.count)")
                LabeledContent("已掌握单词", value: "\(progress.wordMastery.values.filter { $0 == .mastered }.count) / \(content.words.count)")
                LabeledContent("到期复习", value: String(progress.schedule.values.filter(\.isDue).count))
            }
            Section("练习") {
                LabeledContent("今日练习", value: String(progress.statistics.reviewsToday))
                LabeledContent("连续学习天数", value: String(progress.statistics.streakDays))
                LabeledContent("累计练习", value: String(progress.statistics.totalReviews))
            }
        }
        .studyGroupedBackground()
        .navigationTitle("学习统计")
    }
}

private struct StudyLetterDisplayView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent

    private let displayOptions = [
        ("showBlock", "印刷体"), ("showCursive", "手写体"), ("showSofit", "词尾形"),
        ("showBegadkefat", "达盖什字形"), ("showHebrewName", "希伯来语名称"),
        ("showEnglishName", "英文名称"), ("showChineseName", "中文名称"),
        ("showModernSound", "现代读音"), ("showBiblicalDiff", "古典读音"),
        ("showTransliteration", "音译"), ("showGematria", "字母数值"),
        ("showMastery", "掌握度"), ("showCategoryBadges", "字母分类")
    ]

    private var config: [String: Bool] {
        content.defaultDisplay.merging(progress.read("alef.displayConfig.v1", default: [:])) { _, saved in saved }
    }

    private var selectedPreset: String {
        content.displayPresets.first { presetConfig($0) == config }?.label
            ?? (config == content.defaultDisplay ? "默认" : "自定义")
    }

    var body: some View {
        GeometryReader { geometry in
            form(previewWidth: LetterGridLayout.previewWidth(pageWidth: geometry.size.width,
                                                             options: config, typeSize: typeSize))
        }
        .navigationTitle("字母表显示")
    }

    private func form(previewWidth: CGFloat) -> some View {
        Form {
            Section("模板") {
                Menu {
                    ForEach(content.displayPresets) { preset in
                        Button {
                            progress.write(preset.config, for: "alef.displayConfig.v1")
                        } label: {
                            Label(preset.label, systemImage: presetConfig(preset) == config ? "checkmark" : "rectangle.3.group")
                        }
                    }
                    Button("恢复默认", systemImage: "arrow.counterclockwise") {
                        progress.write(content.defaultDisplay, for: "alef.displayConfig.v1")
                    }
                } label: {
                    LabeledContent("视图模板", value: selectedPreset)
                        .frame(minHeight: 44)
                }
            }
            if let example = content.letters.first(where: { $0.id == "kaf" }) ?? content.letters.first {
                Section("卡片预览") {
                    VStack(spacing: 0) {
                        LetterTileContent(letter: example, options: config)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(10)
                        Divider().padding(.horizontal, 10)
                        HStack {
                            PronunciationButton(hebrew: example.nameHebrew, fallback: example.nameEnglish,
                                                iconOnly: true, minimumHitSize: 44)
                            Spacer(minLength: 0)
                            if config["showMastery"] == true {
                                let mastery = progress.letterMastery[example.id] ?? .unlearned
                                Image(systemName: mastery.symbol)
                                    .foregroundStyle(mastery == .unlearned ? Color.secondary : progress.theme.accent)
                                    .accessibilityLabel(mastery.title)
                                    .frame(minWidth: 44)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(width: previewWidth)
                    .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color(uiColor: .separator).opacity(0.4), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                DisclosureGroup("自定义显示项目") {
                    ForEach(displayOptions, id: \.0) { key, label in
                        Toggle(label, isOn: Binding(get: { config[key] == true }, set: {
                            progress.setDisplay(key, enabled: $0)
                        }))
                    }
                }
            }
        }
        .studyGroupedBackground()
    }

    private func presetConfig(_ preset: StudyDisplayPreset) -> [String: Bool] {
        content.defaultDisplay.merging(preset.config) { _, preset in preset }
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
    }

    var body: some View {
        Form {
            Section("保存备份") {
                Button("导出 Alef 备份", systemImage: "square.and.arrow.up", action: export)
                Button("复制备份文本", systemImage: "doc.on.doc", action: copyBackup)
                if status == .copied {
                    Text("已复制 Alef JSON 备份。").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("恢复学习数据") {
                Button("导入 Alef 备份", systemImage: "square.and.arrow.down") { importing = true }
                Button {
                    showsBackupText.toggle()
                } label: {
                    Label(showsBackupText ? "收起文本输入" : "从文本恢复", systemImage: "doc.text")
                }
                if status == .unchanged {
                    Text("备份内容与当前数据相同。").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if showsBackupText {
                Section("JSON 备份文本") {
                    TextEditor(text: $backupText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 160)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Alef JSON 备份文本")
                    PasteButton(payloadType: String.self) { values in
                        if let text = values.first { backupText = text }
                    }
                    Button("预览备份", systemImage: "doc.text.magnifyingglass") {
                        prepareBackup(Data(backupText.utf8))
                    }
                    .disabled(backupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if progress.restorePoint != nil {
                Section {
                    Button("撤销上次导入", systemImage: "arrow.uturn.backward") { undoConfirmation = true }
                }
            }
        }
        .studyGroupedBackground()
        .navigationTitle("备份与恢复")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], onCompletion: prepareImport)
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "alef-backup") { outcome in
            if case let .failure(error) = outcome { message = error.localizedDescription }
        }
        .sheet(item: $preview) { pending in
            NavigationStack {
                List {
                    Section("将更新 \(pending.changes.count) 项") {
                        ForEach(pending.changes.indices, id: \.self) { index in
                            Text(pending.changes[index])
                        }
                    }
                    Text("导入后可以从备份页撤销本次恢复。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .studyGroupedBackground()
                .navigationTitle("恢复预览")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { preview = nil }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    StudyActionBar {
                        Button {
                            preview = nil
                            backupText = ""
                            showsBackupText = false
                            progress.applyBackup(pending.entries)
                        } label: {
                            Label("确认恢复", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
        }
        .confirmationDialog("撤销上次导入？", isPresented: $undoConfirmation, titleVisibility: .visible) {
            Button("撤销导入", role: .destructive) { progress.undoBackup() }
        }
        .alert("Alef 备份", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message ?? "")
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
            let changes = progress.backupChanges(entries).map(backupLabel)
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
        case "alef.gridState.v1": "字母表筛选"
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
