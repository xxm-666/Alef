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

@main
struct DailyLetterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyLetterWidget", provider: LetterProvider()) { entry in
            DailyLetterCard(letter: entry.letter)
                .containerBackground(for: .widget) { DailyLetterBackground() }
                .widgetURL(entry.letter.url)
        }
        .configurationDisplayName("Alef · 每日字母")
        .description("每天展示一个希伯来字母。点按小组件可打开字母详情。")
        .supportedFamilies([.systemSmall])
    }
}
