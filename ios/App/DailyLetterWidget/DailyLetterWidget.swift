import SwiftUI
import WidgetKit

private struct HebrewLetter {
    let glyph: String
    let name: String

    // Standard alphabet order, matching src/data/hebrewLetters.ts.
    static let alphabet: [HebrewLetter] = [
        .init(glyph: "א", name: "Alef"),
        .init(glyph: "ב", name: "Bet / Vet"),
        .init(glyph: "ג", name: "Gimel"),
        .init(glyph: "ד", name: "Dalet"),
        .init(glyph: "ה", name: "He"),
        .init(glyph: "ו", name: "Vav"),
        .init(glyph: "ז", name: "Zayin"),
        .init(glyph: "ח", name: "Chet"),
        .init(glyph: "ט", name: "Tet"),
        .init(glyph: "י", name: "Yod"),
        .init(glyph: "כ", name: "Kaf / Khaf"),
        .init(glyph: "ל", name: "Lamed"),
        .init(glyph: "מ", name: "Mem"),
        .init(glyph: "נ", name: "Nun"),
        .init(glyph: "ס", name: "Samekh"),
        .init(glyph: "ע", name: "Ayin"),
        .init(glyph: "פ", name: "Pe / Fe"),
        .init(glyph: "צ", name: "Tsadi"),
        .init(glyph: "ק", name: "Qof"),
        .init(glyph: "ר", name: "Resh"),
        .init(glyph: "ש", name: "Shin / Sin"),
        .init(glyph: "ת", name: "Tav")
    ]
}

private struct LetterEntry: TimelineEntry {
    let date: Date
    let letter: HebrewLetter
}

private struct LetterProvider: TimelineProvider {
    func placeholder(in context: Context) -> LetterEntry {
        LetterEntry(date: Date(), letter: HebrewLetter.alphabet[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (LetterEntry) -> Void) {
        completion(entry(for: Date(), in: Calendar(identifier: .gregorian)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LetterEntry>) -> Void) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let futureEntries = (1...7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map {
                entry(for: calendar.startOfDay(for: $0), in: calendar)
            }
        }
        completion(Timeline(entries: [entry(for: now, in: calendar)] + futureEntries, policy: .atEnd))
    }

    private func entry(for date: Date, in calendar: Calendar) -> LetterEntry {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        let alphabet = HebrewLetter.alphabet
        return LetterEntry(date: date, letter: alphabet[(day - 1) % alphabet.count])
    }
}

private struct DailyLetterView: View {
    let entry: LetterEntry

    var body: some View {
        VStack(spacing: 0) {
            Text("每日字母")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(entry.letter.glyph)
                .font(.system(size: 72, weight: .medium, design: .serif))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .layoutPriority(-1)
                .accessibilityHidden(true)
            Text(entry.letter.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}

@main
struct DailyLetterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyLetterWidget", provider: LetterProvider()) { entry in
            DailyLetterView(entry: entry)
        }
        .configurationDisplayName("Alef · 每日字母")
        .description("每天展示一个希伯来字母及其名称。")
        .supportedFamilies([.systemSmall])
    }
}
