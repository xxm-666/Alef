import SwiftUI
import WidgetKit

@main
struct AlefWidgets: WidgetBundle {
    var body: some Widget {
        LearnedWordWidget()
        DailyWordWidget()
        AlphabetReferenceWidget()
        StudyShortcutsWidget()
    }
}

private enum WidgetVocabulary {
    static let words: [StudyWidgetWord] = {
        guard let url = Bundle.main.url(forResource: "widget-words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([StudyWidgetWord].self, from: data) else { return [] }
        return words
    }()
}

private struct WordEntry: TimelineEntry {
    let date: Date
    let word: StudyWidgetWord?
    var sharingAvailable = true
}

private struct LearnedWordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, word: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entries(for: [.now])[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let dates = StudyWidgetWords.timelineDates(from: .now)
        completion(Timeline(entries: entries(for: dates), policy: .atEnd))
    }

    private func entries(for dates: [Date]) -> [WordEntry] {
        guard let snapshot = StudyWidgetWords.snapshotURL else {
            return dates.map { WordEntry(date: $0, word: nil, sharingAvailable: false) }
        }
        let words = StudyWidgetWords.candidates(for: StudyWidgetWords.readIDs(from: snapshot),
                                               in: WidgetVocabulary.words)
        return dates.map { date in
            WordEntry(date: date, word: StudyWidgetWords.word(on: date, from: words))
        }
    }
}

private struct LearnedWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: StudyWidgetWords.kind, provider: LearnedWordProvider()) { entry in
            LearnedWordWidgetView(entry: entry)
        }
        .configurationDisplayName("Alef · 已学单词")
        .description("每两小时轮换一个学过的希伯来语单词。点按可打开单词详情。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct LearnedWordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var emptyMessage: String {
        entry.sharingAvailable ? "学习单词后会在这里出现" : "此安装未启用学习记录共享"
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    DailyLetterBackground()
                } else {
                    Color.clear
                }
            }
            .widgetURL(entry.word.flatMap { StudyWidgetRoute.word($0.id).url } ?? StudyWidgetRoute.tab(.words).url)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                StudyWidgetWordAccessory(word: entry.word, style: .circular, emptyMessage: emptyMessage)
            }
        case .accessoryRectangular:
            StudyWidgetWordAccessory(word: entry.word, style: .rectangular, emptyMessage: emptyMessage)
        case .accessoryInline:
            StudyWidgetWordAccessory(word: entry.word, style: .inline, emptyMessage: emptyMessage)
        default:
            StudyWidgetWordCard(word: entry.word, emptyMessage: emptyMessage)
        }
    }
}

private struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, word: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(on: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let future = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        completion(Timeline(entries: ([now] + future).map { entry(on: $0) }, policy: .atEnd))
    }

    private func entry(on date: Date) -> WordEntry {
        let words = WidgetVocabulary.words
        guard !words.isEmpty else { return WordEntry(date: date, word: nil) }
        let index = DailyLetter.rotationIndex(on: date, count: words.count, calendar: Calendar(identifier: .gregorian))
        return WordEntry(date: date, word: words[index])
    }
}

private struct DailyWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlefDailyWord", provider: WordProvider()) { entry in
            StudyWidgetWordCard(word: entry.word, title: "每日单词", emptyMessage: "打开词库")
                .containerBackground(for: .widget) { DailyLetterBackground() }
                .widgetURL(entry.word.flatMap { StudyWidgetRoute.word($0.id).url } ?? StudyWidgetRoute.tab(.words).url)
        }
        .configurationDisplayName("Alef · 每日单词")
        .description("每天从完整词库展示一个希伯来语单词，点按可打开单词详情。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StaticStudyEntry: TimelineEntry {
    let date: Date
}

private struct StaticStudyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StaticStudyEntry { StaticStudyEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (StaticStudyEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StaticStudyEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

private struct AlphabetReferenceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlefAlphabetReference", provider: StaticStudyProvider()) { _ in
            AlphabetReferenceWidgetView()
        }
        .configurationDisplayName("Alef · 字母速查")
        .description("从右往左查看 22 个希伯来字母，点按字母可打开详情。")
        .supportedFamilies([.systemMedium])
    }
}

private struct AlphabetReferenceWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("字母速查", systemImage: "character.book.closed")
                .font(.caption.bold())
                .widgetAccentable()
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                letterRow(DailyLetter.alphabet.prefix(11))
                letterRow(DailyLetter.alphabet.suffix(11))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { DailyLetterBackground() }
        .widgetURL(StudyWidgetRoute.tab(.alphabet).url)
    }

    private func letterRow(_ letters: ArraySlice<DailyLetter>) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(letters.reversed()), id: \.id) { letter in
                if let url = letter.url {
                    Link(destination: url) {
                        Text(letter.glyph)
                            .font(.system(size: 21, weight: .semibold, design: .serif))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            .accessibilityLabel("\(letter.nameZh)，\(letter.name)")
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

private struct StudyShortcutsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlefStudyShortcuts", provider: StaticStudyProvider()) { _ in
            StudyShortcutsWidgetView()
        }
        .configurationDisplayName("Alef · 学习快捷入口")
        .description("快速打开练习。中号组件还可直接进入词库和规则。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StudyShortcutsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("学习快捷入口")
                .font(.caption.bold())
                .widgetAccentable()
            if family == .systemSmall {
                shortcutContent("打开练习", symbol: "pencil")
                    .frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 6) {
                    shortcut(.practice, title: "练习", symbol: "pencil")
                    shortcut(.words, title: "词库", symbol: "square.stack.3d.up")
                    shortcut(.rules, title: "规则", symbol: "list.bullet.rectangle")
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { DailyLetterBackground() }
        .widgetURL(StudyWidgetRoute.tab(.practice).url)
    }

    @ViewBuilder private func shortcut(_ tab: StudyWidgetRoute.Tab, title: String, symbol: String) -> some View {
        if let url = StudyWidgetRoute.tab(tab).url {
            Link(destination: url) { shortcutContent(title, symbol: symbol) }
        }
    }

    private func shortcutContent(_ title: String, symbol: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.title2).accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
