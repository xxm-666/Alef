import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct StudySettingsView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    @State private var importing = false
    @State private var exporting = false
    @State private var openConfirmation = false
    @State private var undoConfirmation = false
    @State private var backup: StudyBackupDocument?
    @State private var pending: [String: Data]?
    @State private var message: String?
    @State private var showsBackupText = false
    @State private var backupText = ""

    private let displayOptions = [
        ("showBlock", "印刷体", true), ("showCursive", "手写体", true), ("showSofit", "词尾形", true),
        ("showBegadkefat", "达盖什字形", true), ("showHebrewName", "希伯来语名称", true),
        ("showEnglishName", "英文名称", true), ("showChineseName", "中文名称", true),
        ("showModernSound", "现代读音", true), ("showBiblicalDiff", "古典读音", false),
        ("showTransliteration", "音译", true), ("showGematria", "字母数值", true),
        ("showMastery", "掌握度", true), ("showCategoryBadges", "字母分类", false)
    ]

    var body: some View {
        @Bindable var progress = progress
        Form {
            Section("外观") {
                Picker("主题", selection: $progress.theme) {
                    ForEach(StudyTheme.allCases) { theme in Text(theme.title).tag(theme) }
                }
                Toggle("字母从右向左排列", isOn: $progress.alphabetFromRight)
            }
            Section("发音") {
                LabeledContent("发音速度") { Text(progress.speechRate, format: .number.precision(.fractionLength(2))) }
                Slider(value: $progress.speechRate, in: 0.5...1.5, step: 0.05) { Text("发音速度") }
                PronunciationButton(hebrew: "שָׁלוֹם", fallback: "shalom")
                LabeledContent("内置离线录音", value: String(Set(content.audio.values).count))
            }
            Section("学习记录") {
                LabeledContent("已掌握字母", value: "\(progress.letterMastery.values.filter { $0 == .mastered }.count) / \(content.letters.count)")
                LabeledContent("已掌握单词", value: "\(progress.wordMastery.values.filter { $0 == .mastered }.count) / \(content.words.count)")
                LabeledContent("到期复习", value: String(progress.schedule.values.filter(\.isDue).count))
                LabeledContent("今日练习", value: String(progress.statistics.reviewsToday))
                LabeledContent("连续学习天数", value: String(progress.statistics.streakDays))
                LabeledContent("累计练习", value: String(progress.statistics.totalReviews))
            }
            Section("备份与恢复") {
                Button("导出 Alef 备份", systemImage: "square.and.arrow.up", action: export)
                Button("复制备份文本", systemImage: "doc.on.doc", action: copyBackup)
                Button("导入 Alef 备份", systemImage: "square.and.arrow.down") { importing = true }
                DisclosureGroup("从文本恢复", isExpanded: $showsBackupText) {
                    TextEditor(text: $backupText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 96)
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
                if progress.restorePoint != nil {
                    Button("撤销上次导入", systemImage: "arrow.uturn.backward") { undoConfirmation = true }
                }
            }
            Section("字母表显示") {
                Menu("视图模板", systemImage: "rectangle.3.group") {
                    ForEach(content.displayPresets) { preset in
                        Button(preset.label) { progress.write(preset.config, for: "alef.displayConfig.v1") }
                    }
                    Button("恢复默认", systemImage: "arrow.counterclockwise") {
                        progress.write(content.defaultDisplay, for: "alef.displayConfig.v1")
                    }
                }
                ForEach(displayOptions, id: \.0) { key, label, fallback in
                    Toggle(label, isOn: Binding(get: { progress.display(key, default: fallback) }, set: {
                        progress.setDisplay(key, enabled: $0)
                    }))
                }
            }
        }
        .navigationTitle("设置")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], onCompletion: prepareImport)
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "alef-backup") { outcome in
            if case let .failure(error) = outcome { message = error.localizedDescription }
        }
        .confirmationDialog("恢复学习数据", isPresented: $openConfirmation, titleVisibility: .visible) {
            Button("确认恢复", role: .destructive) {
                if let pending { progress.applyBackup(pending) }
                pending = nil
                backupText = ""
                showsBackupText = false
            }
            Button("取消", role: .cancel) { pending = nil }
        } message: {
            let changes = progress.backupChanges(pending ?? [:]).map(backupLabel)
            Text("将更新 \(changes.count) 项：\(changes.joined(separator: "、"))。导入后可以撤销。")
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
        pending = nil
        do {
            let preview = try progress.previewBackup(data)
            guard !progress.backupChanges(preview).isEmpty else {
                message = "备份内容与当前数据相同。"
                return
            }
            pending = preview
            openConfirmation = true
        } catch {
            message = error.localizedDescription
        }
    }

    private func copyBackup() {
        do {
            UIPasteboard.general.string = String(decoding: try progress.exportBackup(), as: UTF8.self)
            message = "已复制 Alef JSON 备份。"
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
