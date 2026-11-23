import SwiftUI

private enum CafeComicAction: String, CaseIterable {
    case menu = "p-dine-1"
    case water = "p-dine-3"
    case bill = "p-dine-7"

    var illustration: String {
        switch self {
        case .menu: "CafeResolution"
        case .water: "CafeWater"
        case .bill: "CafeBill"
        }
    }

    var outcome: String {
        switch self {
        case .menu: "店员微笑着递来一份菜单。"
        case .water: "店员端来一杯冷水。"
        case .bill: "店员把账单递给你。"
        }
    }

    var motionVariant: Float {
        switch self {
        case .menu: 0
        case .water: 1
        case .bill: 2
        }
    }
}

struct StudyCafeComicView: View {
    private static let phraseIDs = CafeComicAction.allCases.map(\.rawValue)
    private static let openingID = "cafe-comic-opening"
    private static let reactionID = "cafe-comic-reaction"
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
                   let solution = choices.first(where: { $0.id == CafeComicAction.menu.rawValue }) {
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
                            .transition(.offset(y: 12).combined(with: .opacity))
                    } else {
                        dialogueChoices(choices)
                    }
                } else {
                    ContentUnavailableView("暂时无法打开漫画", systemImage: "book.closed",
                                           description: Text("这一篇需要的台词资料不完整。"))
                }
            }
            .modifier(StudyComicMotion(value: completed))
            .onChange(of: wrongChoice?.id) { _, choiceID in
                guard choiceID != nil else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    reader.scrollTo(Self.reactionID, anchor: .top)
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
            if let wrongChoice, let action = CafeComicAction(rawValue: wrongChoice.id) {
                VStack {
                    reaction(wrongChoice, action: action)
                        .id(wrongChoice.id)
                        .transition(.offset(y: 12).combined(with: .opacity))
                }
                .id(Self.reactionID)
            }
            StudySectionTitle("你会怎么说？")
            ForEach(choices) { phrase in
                choice(phrase)
            }
            Toggle("显示中文", isOn: $showsTranslation)
                .font(.subheadline)
                .tint(progress.theme.primaryButton)
        }
        .modifier(StudyComicMotion(value: wrongChoice?.id))
    }

    private func reaction(_ phrase: StudyPhrase, action: CafeComicAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CafeComicActionPanel(action: action, phrase: phrase)
            StudyCard {
                Text("你刚才说的是「\(phrase.meaningZh)」。想要菜单的话，再选一句。")
                    .font(.footnote)
                    .foregroundStyle(progress.theme.ink)
            }
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
            CafeComicActionPanel(action: .menu, phrase: phrase)
            StudyCard {
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
        if phrase.id == CafeComicAction.menu.rawValue {
            completed = true
            audio.playFeedback(.correct)
        } else {
            wrongChoice = phrase
            skippedChoices.insert(phrase.id)
            audio.playFeedback(.wrong)
        }
    }
}

private struct CafeComicActionPanel: View {
    private struct Pose {
        var motion: CGFloat = 1
        var speech: CGFloat = 1
    }

    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var play = 0
    let action: CafeComicAction
    let phrase: StudyPhrase

    var body: some View {
        Group {
            if reduceMotion {
                scene(Pose())
            } else {
                KeyframeAnimator(initialValue: Pose(), trigger: play) { pose in
                    scene(pose)
                } keyframes: { _ in
                    KeyframeTrack(\.motion) {
                        MoveKeyframe(0)
                        LinearKeyframe(0, duration: 0.22)
                        LinearKeyframe(1, duration: 0.85)
                    }
                    KeyframeTrack(\.speech) {
                        MoveKeyframe(0)
                        LinearKeyframe(0, duration: 0.53)
                        CubicKeyframe(1, duration: 0.28)
                    }
                }
            }
        }
        .task {
            if !reduceMotion, play == 0 { play = 1 }
        }
    }

    private func scene(_ pose: Pose) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Image(action.illustration)
                .resizable()
                .aspectRatio(3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .layerEffect(
                    ShaderLibrary.cafeBranchMotion(.boundingRect, .float(action.motionVariant), .float(Float(pose.motion))),
                    maxSampleOffset: CGSize(width: 42, height: 30),
                    isEnabled: pose.motion < 1
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(action.outcome)
            HStack(spacing: 8) {
                PronunciationButton(hebrew: phrase.hebrew, iconOnly: true, title: "重听这句台词", bundledOnly: true)
                HebrewText(text: phrase.hebrew, size: 22)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .background(progress.theme.cardSurface,
                        in: UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14,
                                                   bottomTrailingRadius: 14, topTrailingRadius: 4))
            .offset(y: -6 * (1 - pose.speech))
            .opacity(0.35 + 0.65 * pose.speech)
        }
    }
}
