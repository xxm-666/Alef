import SwiftUI

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
        .preferredColorScheme(progress.theme == .dark ? .dark : .light)
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

private extension StudyTheme {
    var accent: Color {
        switch self {
        case .parchment: .blue
        case .rose: Color(red: 0.65, green: 0.12, blue: 0.28)
        case .violet: Color(red: 0.40, green: 0.22, blue: 0.66)
        case .dark: .cyan
        }
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
