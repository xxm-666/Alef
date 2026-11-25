import SwiftUI
import WidgetKit

struct DailyLetter {
    let id: String
    let glyph: String
    let name: String
    let nameZh: String

    static let alphabet: [DailyLetter] = [
        .init(id: "alef", glyph: "א", name: "Alef", nameZh: "阿莱夫"),
        .init(id: "bet", glyph: "ב", name: "Bet", nameZh: "贝特"),
        .init(id: "gimel", glyph: "ג", name: "Gimel", nameZh: "吉梅尔"),
        .init(id: "dalet", glyph: "ד", name: "Dalet", nameZh: "达莱特"),
        .init(id: "he", glyph: "ה", name: "He", nameZh: "海"),
        .init(id: "vav", glyph: "ו", name: "Vav", nameZh: "瓦夫"),
        .init(id: "zayin", glyph: "ז", name: "Zayin", nameZh: "扎因"),
        .init(id: "chet", glyph: "ח", name: "Chet", nameZh: "赫特"),
        .init(id: "tet", glyph: "ט", name: "Tet", nameZh: "泰特"),
        .init(id: "yod", glyph: "י", name: "Yod", nameZh: "约德"),
        .init(id: "kaf", glyph: "כ", name: "Kaf", nameZh: "卡夫"),
        .init(id: "lamed", glyph: "ל", name: "Lamed", nameZh: "拉梅德"),
        .init(id: "mem", glyph: "מ", name: "Mem", nameZh: "梅姆"),
        .init(id: "nun", glyph: "נ", name: "Nun", nameZh: "努恩"),
        .init(id: "samekh", glyph: "ס", name: "Samekh", nameZh: "萨梅赫"),
        .init(id: "ayin", glyph: "ע", name: "Ayin", nameZh: "艾因"),
        .init(id: "pe", glyph: "פ", name: "Pe", nameZh: "佩"),
        .init(id: "tsadi", glyph: "צ", name: "Tsadi", nameZh: "察迪"),
        .init(id: "qof", glyph: "ק", name: "Qof", nameZh: "科夫"),
        .init(id: "resh", glyph: "ר", name: "Resh", nameZh: "雷什"),
        .init(id: "shin", glyph: "ש", name: "Shin", nameZh: "辛"),
        .init(id: "tav", glyph: "ת", name: "Tav", nameZh: "塔夫")
    ]

    static func on(_ date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> DailyLetter {
        alphabet[rotationIndex(on: date, count: alphabet.count, calendar: calendar)]
    }

    static func rotationIndex(on date: Date, count: Int, calendar: Calendar) -> Int {
        // Index by the local calendar date so daylight-saving changes do not change the day's letter.
        let localDay = calendar.dateComponents([.era, .year, .month, .day], from: date)
        var indexingCalendar = calendar
        indexingCalendar.timeZone = .gmt
        let day = indexingCalendar.date(from: localDay)
            .flatMap { indexingCalendar.ordinality(of: .day, in: .era, for: $0) } ?? 1
        return (max(1, day) - 1) % count
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = "alef"
        components.host = "daily-letter"
        components.path = "/" + id
        return components.url
    }

    static func id(from url: URL) -> String? {
        guard url.scheme == "alef", url.host == "daily-letter", url.pathComponents.count == 2 else { return nil }
        let id = url.lastPathComponent
        return alphabet.contains { $0.id == id } ? id : nil
    }
}

struct StudyWidgetWordCard: View {
    let word: StudyWidgetWord?
    var title = "已学单词"
    var emptyMessage = "学习单词后会在这里出现"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: "text.book.closed")
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
                Text(emptyMessage).font(.footnote)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct StudyWidgetWordAccessory: View {
    enum Style {
        case circular, rectangular, inline
    }

    let word: StudyWidgetWord?
    let style: Style
    var emptyMessage = "学习单词后会在这里出现"

    var body: some View {
        Group {
            switch style {
            case .circular:
                if let word {
                    Text(word.hebrew)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .minimumScaleFactor(0.35)
                        .lineLimit(1)
                        .padding(6)
                } else {
                    Image(systemName: "text.book.closed")
                        .font(.title3)
                }
            case .rectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("已学单词").font(.caption2.weight(.semibold))
                    if let word {
                        Text(word.hebrew).font(.title3.weight(.semibold))
                        Text(word.meaningZh).font(.caption)
                    } else {
                        Text(emptyMessage).font(.caption)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            case .inline:
                Label(word.map { "\($0.hebrew) · \($0.meaningZh)" } ?? "已学单词",
                      systemImage: "text.book.closed")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(word.map {
            "已学单词，\($0.hebrew)，\($0.transliteration)，\($0.meaningZh)"
        } ?? emptyMessage))
    }
}

struct DailyLetterBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        let top = dark ? Color(red: 0.08, green: 0.19, blue: 0.24) : Color(red: 0.93, green: 0.98, blue: 0.97)
        let bottom = dark ? Color(red: 0.14, green: 0.32, blue: 0.36) : Color(red: 0.79, green: 0.92, blue: 0.91)
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.78))
                        path.addQuadCurve(to: CGPoint(x: width, y: height * 0.73),
                                          control: CGPoint(x: width * 0.5, y: height * 1.03))
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(dark ? Color.white.opacity(0.08) : Color.white.opacity(0.33))
                }
                .accessibilityHidden(true)
            }
    }
}

enum StudyWidgetRoute: Equatable {
    enum Tab: String {
        case alphabet = "grid"
        case words
        case practice = "flashcards"
        case rules
    }

    case letter(String)
    case word(String)
    case tab(Tab)

    var url: URL? {
        switch self {
        case .letter(let id):
            return DailyLetter.alphabet.first { $0.id == id }?.url
        case .word(let id):
            var components = URLComponents()
            components.scheme = "alef"
            components.host = "daily-word"
            components.queryItems = [URLQueryItem(name: "id", value: id)]
            return components.url
        case .tab(let tab):
            return URL(string: "alef://study-tab/\(tab.rawValue)")
        }
    }

    init?(url: URL) {
        guard url.scheme == "alef" else { return nil }
        if let id = DailyLetter.id(from: url) {
            self = .letter(id)
        } else if url.host == "daily-word", url.path.isEmpty,
                  let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value, !id.isEmpty {
            self = .word(id)
        } else if url.host == "study-tab", url.pathComponents.count == 2,
                  let tab = Tab(rawValue: url.lastPathComponent) {
            self = .tab(tab)
        } else {
            return nil
        }
    }
}
