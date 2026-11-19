import SwiftUI
import UIKit

struct StudyRootView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let content: StudyContent

    var body: some View {
        TabView(selection: Binding(get: { selectedTab }, set: { progress.write($0, for: "alef.activeView.v1") })) {
            NavigationStack { WordsView(content: content) }
                .tabItem { Label("单词", systemImage: "character.book.closed") }
                .tag("words")
            NavigationStack { StudyFlashcardsView(content: content) }
                .tabItem { Label("闪卡", systemImage: "rectangle.on.rectangle") }
                .tag("flashcards")
            NavigationStack { AlphabetView(content: content) }
                .tabItem { Label("字母", systemImage: "textformat.abc") }
                .tag("grid")
            NavigationStack { StudyRulesView(content: content) }
                .tabItem { Label("规则", systemImage: "book") }
                .tag("rules")
            NavigationStack { StudySettingsView(content: content) }
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag("settings")
        }
        .tint(progress.theme.accent)
        .preferredColorScheme(progress.theme.preferredScheme)
        .onChange(of: selectedTab) { _, _ in audio.stop() }
        .alert("发音", isPresented: Binding(get: { audio.playbackError != nil }, set: { visible in
            if !visible { audio.dismissError() }
        })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(audio.playbackError ?? "")
        }
    }

    private var selectedTab: String {
        let saved = progress.read("alef.activeView.v1", default: "grid")
        return ["words", "flashcards", "rules", "settings"].contains(saved) ? saved : "grid"
    }
}

extension StudyTheme {
    var preferredScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .white, .parchment, .rose, .violet: .light
        }
    }

    var accent: Color {
        switch self {
        case .system:
            Color(uiColor: UIColor { traits in
                let color: UIColor = traits.userInterfaceStyle == .dark ? .systemCyan : .systemBlue
                return color.resolvedColor(with: traits)
            })
        case .white: Color(uiColor: .systemBlue)
        case .parchment: .blue
        case .rose: Color(red: 0.65, green: 0.12, blue: 0.28)
        case .violet: Color(red: 0.40, green: 0.22, blue: 0.66)
        case .dark: Color(uiColor: .systemCyan)
        }
    }

    var canvas: Color {
        Color(uiColor: usesWhitePalette ? Self.whiteCanvas : .systemGroupedBackground)
    }

    var cardSurface: Color {
        guard usesWhitePalette else { return Color(uiColor: .secondarySystemGroupedBackground) }
        return Color(uiColor: Self.whiteCardSurface)
    }

    fileprivate var usesWhitePalette: Bool { self == .system || self == .white }

    private static let whiteCanvas = UIColor { traits in
        let color: UIColor = traits.userInterfaceStyle == .dark ? .systemGroupedBackground : .systemBackground
        return color.resolvedColor(with: traits)
    }

    private static let whiteCardSurface = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor.secondarySystemGroupedBackground.resolvedColor(with: traits)
        }
        return UIColor(red: 0.965, green: 0.969, blue: 0.977, alpha: 1)
    }

    fileprivate var groupedCanvas: Color {
        guard usesWhitePalette else { return Color(uiColor: .systemGroupedBackground) }
        return Color(uiColor: Self.whiteGroupedCanvas)
    }

    private static let whiteGroupedCanvas = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor.systemGroupedBackground.resolvedColor(with: traits)
        }
        return UIColor(white: 0.977, alpha: 1)
    }
}

private struct StudyGroupedBackground: ViewModifier {
    @Environment(StudyProgress.self) private var progress

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(progress.theme.usesWhitePalette ? .hidden : .automatic)
            .background(progress.theme.groupedCanvas)
    }
}

extension View {
    func studyGroupedBackground() -> some View {
        modifier(StudyGroupedBackground())
    }
}

struct PronunciationButton: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    let hebrew: String
    var fallback: String?
    var iconOnly = false
    var rate: Double?
    var title = "播放发音"
    var minimumHitSize: CGFloat?

    var body: some View {
        Button {
            audio.speak(hebrew, fallback: fallback, rate: rate ?? progress.speechRate)
        } label: {
            Group {
                if iconOnly {
                    Image(systemName: "speaker.wave.2")
                } else {
                    Label(title, systemImage: "speaker.wave.2")
                }
            }
            .frame(minWidth: minimumHitSize, minHeight: minimumHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
    }
}

struct HebrewText: View {
    let text: String
    var cursive = false
    var size: CGFloat = 26
    var style: Font.TextStyle = .body
    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .font(cursive ? .custom("GveretLevin-Regular", size: size, relativeTo: style) : .system(size: size * scale, design: .serif))
            .speechSpellsOutCharacters(text.count == 1)
    }
}

struct MasteryPicker: View {
    @Binding var value: Mastery

    var body: some View {
        Picker("掌握度", selection: $value) {
            ForEach(Mastery.allCases) { level in
                Text(level.title).tag(level)
            }
        }
    }
}

struct StudyActionBar<Content: View>: View {
    @Environment(StudyProgress.self) private var progress
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            content()
                .frame(maxWidth: 560)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
        .background(progress.theme.canvas)
    }
}

struct StudyAnswerButton: View {
    let title: String
    let submitted: Bool
    let selected: Bool
    let correct: Bool
    var isHebrew = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isHebrew { HebrewText(text: title, size: 32).foregroundStyle(.primary) }
                else { Text(title).foregroundStyle(.primary) }
                Spacer()
                if submitted && (selected || correct) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? Color.green : Color.red)
                        .accessibilityLabel(correct ? "正确答案" : "答案有误")
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(submitted)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct StudyQuizFeedback: View {
    @AccessibilityFocusState(for: .voiceOver) private var focused: Bool
    @State private var didFocus = false
    let correct: Bool
    let solution: String
    var response: String?
    var explanation: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(correct ? "答对了" : "答案有误",
                  systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
            if !correct, let response {
                Text("你的答案  \(response)").foregroundStyle(.secondary)
            }
            Text("正确答案  \(solution)")
            if let explanation, !explanation.isEmpty {
                Text(explanation).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($focused)
        .onAppear {
            guard !didFocus else { return }
            focused = true
            didFocus = true
        }
    }
}
