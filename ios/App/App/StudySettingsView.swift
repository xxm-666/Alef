import SwiftUI
import UniformTypeIdentifiers

struct StudySettingsView: View {
    @Environment(StudyProgress.self) private var progress
    @State private var importing = false
    @State private var exporting = false
    @State private var openConfirmation = false
    @State private var undoConfirmation = false
    @State private var backup: StudyBackupDocument?
    @State private var pending: [String: Data]?
    @State private var message: String?

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
            }
            Section("学习记录") {
                LabeledContent("已掌握字母", value: String(progress.letterMastery.values.filter { $0 == .mastered }.count))
                LabeledContent("已掌握单词", value: String(progress.wordMastery.values.filter { $0 == .mastered }.count))
                LabeledContent("今日练习", value: String(progress.statistics.reviewsToday))
                LabeledContent("连续学习天数", value: String(progress.statistics.streakDays))
                LabeledContent("累计练习", value: String(progress.statistics.totalReviews))
            }
            Section("备份与恢复") {
                Button("导出 Alef 备份", systemImage: "square.and.arrow.up", action: export)
                Button("导入 Alef 备份", systemImage: "square.and.arrow.down") { importing = true }
                if progress.restorePoint != nil {
                    Button("撤销上次导入", systemImage: "arrow.uturn.backward") { undoConfirmation = true }
                }
            }
            Section("字母表显示") {
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
            }
            Button("取消", role: .cancel) { pending = nil }
        } message: {
            Text("恢复此备份中的 \(pending?.count ?? 0) 项设置和学习数据。可在导入后撤销。")
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
            pending = try progress.previewBackup(Data(contentsOf: url))
            openConfirmation = true
        } catch {
            message = error.localizedDescription
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
