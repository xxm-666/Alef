import SwiftUI

struct StudyCafeComicView: View {
    private static let menuRequestID = "p-dine-1"
    private static let phraseIDs = [menuRequestID, "p-dine-3", "p-dine-7"]
    private static let openingID = "cafe-comic-opening"
    private static let resolutionID = "cafe-comic-resolution"

    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: StudyContent

    @State private var order = StudyCafeComicView.phraseIDs.shuffled()
    @State private var wrongChoice: StudyPhrase?
    @State private var skippedChoices: Set<String> = []
    @State private var showsTranslation = false
    @State private var completed = false

    var body: some View {
        let choices = order.compactMap { id in content.phrases.first { $0.id == id } }
        ScrollViewReader { reader in
            StudyPage {
                if choices.count == Self.phraseIDs.count,
                   let solution = choices.first(where: { $0.id == Self.menuRequestID }) {
                    panel("CafeArrival", description: "你刚坐下，咖啡馆的店员走过来。")
                        .id(Self.openingID)
                    Text("你刚坐下，想先要一份菜单。")
                        .font(.subheadline)
                        .foregroundStyle(progress.theme.ink)
                    panel("CafeQuestion", description: "你抬头看向店员，准备开口。")
                        .overlay(alignment: .top) {
                            if !completed {
                                Text("…")
                                    .font(.headline)
                                    .foregroundStyle(progress.theme.ink)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(progress.theme.cardSurface, in: Capsule())
                                    .padding(8)
                                    .accessibilityHidden(true)
                            }
                        }
                    if completed {
                        resolution(solution)
                            .id(Self.resolutionID)
                    } else {
                        dialogueChoices(choices)
                    }
                } else {
                    ContentUnavailableView("暂时无法打开漫画", systemImage: "book.closed",
                                           description: Text("这一篇需要的台词资料不完整。"))
                }
            }
            .onChange(of: completed) { _, isComplete in
                let target = isComplete ? Self.resolutionID : Self.openingID
                let anchor: UnitPoint = isComplete ? .bottom : .top
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    reader.scrollTo(target, anchor: anchor)
                }
            }
        }
        .studyDetail("咖啡馆点单")
        .onDisappear { audio.stop() }
    }

    private func panel(_ name: String, description: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(description)
    }

    private func dialogueChoices(_ choices: [StudyPhrase]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StudySectionTitle("你会怎么说？")
            ForEach(choices) { phrase in
                choice(phrase)
            }
            if let wrongChoice {
                StudyNotice(title: "试试另一句", symbol: "arrow.counterclockwise",
                            note: "刚才那句是「\(wrongChoice.meaningZh)」", reminder: true)
            }
            Toggle("显示中文", isOn: $showsTranslation)
                .font(.subheadline)
                .tint(progress.theme.primaryButton)
        }
    }

    private func choice(_ phrase: StudyPhrase) -> some View {
        let skipped = skippedChoices.contains(phrase.id)
        return HStack(spacing: 4) {
            PronunciationButton(hebrew: phrase.hebrew, iconOnly: true, title: "试听：\(phrase.hebrew)", bundledOnly: true)
            Button {
                choose(phrase)
            } label: {
                VStack(alignment: .trailing, spacing: 3) {
                    HebrewText(text: phrase.hebrewUnpointed, size: 21)
                    if showsTranslation {
                        Text(phrase.meaningZh)
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(skipped)
            if skipped {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(progress.theme.error)
                    .accessibilityLabel("已排除")
            }
        }
        .padding(.horizontal, 8)
        .background(skipped ? progress.theme.errorSurface : progress.theme.cardSurface,
                    in: RoundedRectangle(cornerRadius: 12))
    }

    private func resolution(_ phrase: StudyPhrase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            panel("CafeResolution", description: "店员微笑着递来一份菜单。")
            StudyCard {
                HStack(spacing: 8) {
                    PronunciationButton(hebrew: phrase.hebrew, iconOnly: true, title: "重听正确台词", bundledOnly: true)
                    HebrewText(text: phrase.hebrew, size: 24)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Text(phrase.meaningZh)
                    .font(.footnote)
                    .foregroundStyle(progress.theme.mutedInk)
            }
            Button {
                audio.stop()
                order.shuffle()
                wrongChoice = nil
                skippedChoices = []
                showsTranslation = false
                completed = false
            } label: {
                Label("再读一次", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle(learningAction: true))
        }
    }

    private func choose(_ phrase: StudyPhrase) {
        guard !completed, !skippedChoices.contains(phrase.id) else { return }
        audio.stop()
        if phrase.id == Self.menuRequestID {
            completed = true
            audio.playFeedback(.correct)
        } else {
            wrongChoice = phrase
            skippedChoices.insert(phrase.id)
            audio.playFeedback(.wrong)
        }
    }
}
