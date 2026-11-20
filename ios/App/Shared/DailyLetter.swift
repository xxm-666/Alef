import SwiftUI

struct DailyLetter {
    let id: String
    let glyph: String
    let name: String

    static let alphabet: [DailyLetter] = [
        .init(id: "alef", glyph: "א", name: "Alef"),
        .init(id: "bet", glyph: "ב", name: "Bet"),
        .init(id: "gimel", glyph: "ג", name: "Gimel"),
        .init(id: "dalet", glyph: "ד", name: "Dalet"),
        .init(id: "he", glyph: "ה", name: "He"),
        .init(id: "vav", glyph: "ו", name: "Vav"),
        .init(id: "zayin", glyph: "ז", name: "Zayin"),
        .init(id: "chet", glyph: "ח", name: "Chet"),
        .init(id: "tet", glyph: "ט", name: "Tet"),
        .init(id: "yod", glyph: "י", name: "Yod"),
        .init(id: "kaf", glyph: "כ", name: "Kaf"),
        .init(id: "lamed", glyph: "ל", name: "Lamed"),
        .init(id: "mem", glyph: "מ", name: "Mem"),
        .init(id: "nun", glyph: "נ", name: "Nun"),
        .init(id: "samekh", glyph: "ס", name: "Samekh"),
        .init(id: "ayin", glyph: "ע", name: "Ayin"),
        .init(id: "pe", glyph: "פ", name: "Pe"),
        .init(id: "tsadi", glyph: "צ", name: "Tsadi"),
        .init(id: "qof", glyph: "ק", name: "Qof"),
        .init(id: "resh", glyph: "ר", name: "Resh"),
        .init(id: "shin", glyph: "ש", name: "Shin"),
        .init(id: "tav", glyph: "ת", name: "Tav")
    ]

    static func on(_ date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> DailyLetter {
        // Index by the local calendar date so daylight-saving changes do not change the day's letter.
        let localDay = calendar.dateComponents([.era, .year, .month, .day], from: date)
        var indexingCalendar = calendar
        indexingCalendar.timeZone = .gmt
        let day = indexingCalendar.date(from: localDay)
            .flatMap { indexingCalendar.ordinality(of: .day, in: .era, for: $0) } ?? 1
        return alphabet[(max(1, day) - 1) % alphabet.count]
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

struct DailyLetterCard: View {
    let letter: DailyLetter
    @Environment(\.colorScheme) private var scheme

    private var ink: Color {
        scheme == .dark ? Color(red: 0.93, green: 0.98, blue: 0.98) : Color(red: 0.07, green: 0.23, blue: 0.27)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("每日字母")
                    .font(.caption.weight(.bold))
                Spacer(minLength: 2)
                Image(systemName: "chevron.right.circle.fill")
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 1)
            Text(letter.glyph)
                .font(.system(size: 65, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .layoutPriority(-1)
            Text(letter.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 1)
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("每日字母，\(letter.glyph)，\(letter.name)")
        .accessibilityHint("打开字母详情")
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
