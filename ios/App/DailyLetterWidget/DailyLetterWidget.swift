import SwiftUI
import WidgetKit

private struct LetterEntry: TimelineEntry {
    let date: Date
    let letter: DailyLetter
}

private struct LetterProvider: TimelineProvider {
    func placeholder(in context: Context) -> LetterEntry {
        LetterEntry(date: Date(), letter: DailyLetter.alphabet[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (LetterEntry) -> Void) {
        let now = Date()
        completion(LetterEntry(date: now, letter: DailyLetter.on(now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LetterEntry>) -> Void) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let futureEntries = (1...7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map {
                LetterEntry(date: $0, letter: DailyLetter.on($0, calendar: calendar))
            }
        }
        completion(Timeline(entries: [LetterEntry(date: now, letter: DailyLetter.on(now, calendar: calendar))] + futureEntries,
                            policy: .atEnd))
    }
}

private struct DailyLetterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let letter: DailyLetter

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    DailyLetterBackground()
                } else {
                    Color.clear
                }
            }
            .widgetURL(letter.url)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                DailyLetterCircularContent(letter: letter)
            }
        case .accessoryRectangular:
            DailyLetterRectangularContent(letter: letter)
        case .accessoryInline:
            DailyLetterInlineContent(letter: letter)
        default:
            DailyLetterCard(letter: letter)
        }
    }
}

@main
struct AlefWidgets: WidgetBundle {
    var body: some Widget {
        DailyLetterWidget()
        DailyWordWidget()
        AlphabetReferenceWidget()
        StudyShortcutsWidget()
    }
}

private struct DailyLetterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyLetterWidget", provider: LetterProvider()) { entry in
            DailyLetterWidgetView(letter: entry.letter)
        }
        .configurationDisplayName("Alef · 每日字母")
        .description("每天展示一个希伯来字母，支持主屏幕与锁屏小组件。点按可打开字母详情。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct WidgetWord: Decodable {
    let id: String
    let hebrew: String
    let transliteration: String
    let meaningZh: String

    static let preview = Self(id: "shalom", hebrew: "שָׁלוֹם", transliteration: "shalom", meaningZh: "你好；和平")

    static let vocabulary: [Self] = {
        guard let url = Bundle.main.url(forResource: "widget-words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        return words
    }()
}

private struct WordEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord?
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
        let words = WidgetWord.vocabulary
        guard !words.isEmpty else { return WordEntry(date: date, word: nil) }
        let index = DailyLetter.rotationIndex(on: date, count: words.count, calendar: Calendar(identifier: .gregorian))
        return WordEntry(date: date, word: words[index])
    }
}

private struct DailyWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlefDailyWord", provider: WordProvider()) { entry in
            DailyWordWidgetView(word: entry.word)
        }
        .configurationDisplayName("Alef · 每日单词")
        .description("每天认识一个希伯来语单词，点按即可打开单词详情。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DailyWordWidgetView: View {
    let word: WidgetWord?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("每日单词", systemImage: "text.book.closed")
                .font(.caption.bold())
                .widgetAccentable()
            Spacer(minLength: 2)
            if let word {
                Text(word.hebrew)
                    .font(.system(size: 36, weight: .semibold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(word.transliteration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(word.meaningZh)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            } else {
                Text("打开词库").font(.headline)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { DailyLetterBackground() }
        .widgetURL(word.flatMap { StudyWidgetRoute.word($0.id).url } ?? StudyWidgetRoute.tab(.words).url)
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
