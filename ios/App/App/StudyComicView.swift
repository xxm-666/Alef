import SwiftUI

private struct CafeSceneChoice: Identifiable {
    let id: String
    let isCorrect: Bool
    let animationFrames: [String]
    let outcomeImage: String
    let baristaReplyHebrew: String?
    let baristaReplyZh: String?
    let wrongTip: String?
}

private struct CafeStageInteraction {
    enum Prop: String, CaseIterable, Identifiable {
        case menu, coffee, water, paid
        var id: String { rawValue }
    }

    let label: String
    let emoji: String
    let xFraction: CGFloat
    let yFraction: CGFloat
    let opensMenu: Bool
    let doneText: String
    let prop: Prop
    let burstEmoji: String
    let tapAudioHebrew: String?
    let culturalTip: String
}

private struct CafeBaristaPrompt {
    let hebrew: String
    let unpointed: String
    let transliteration: String
    let meaningZh: String
}

private struct CafeAct: Identifiable {
    let id: String
    let stepLabel: String
    let title: String
    let sceneNote: String
    let baseImage: String
    let barista: CafeBaristaPrompt
    let customerThought: String
    let choices: [CafeSceneChoice]
    let interaction: CafeStageInteraction

    var solutionChoice: CafeSceneChoice? {
        choices.first(where: \.isCorrect)
    }

    static let all: [CafeAct] = [
        CafeAct(
            id: "menu",
            stepLabel: "入座",
            title: "第一幕 · 入座要菜单",
            sceneNote: "你刚在特拉维夫阳光咖啡馆坐下，店员笑着走来问候。你想先要一份菜单。",
            baseImage: "CafeMenuOrder",
            barista: CafeBaristaPrompt(
                hebrew: "שָׁלוֹם, מַה שְׁלוֹמְךָ?",
                unpointed: "שלום, מה שלומך?",
                transliteration: "Shalom, ma shlomkha?",
                meaningZh: "你好，今天过得怎么样？"
            ),
            customerThought: "想先看看菜单再点单…",
            choices: [
                CafeSceneChoice(
                    id: "p-dine-1",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    baristaReplyHebrew: "בְּוַדַּאי! הִנֵּה הַתַּפְרִיט.",
                    baristaReplyZh: "当然！这是菜单，请慢看。",
                    wrongTip: nil
                ),
                CafeSceneChoice(
                    id: "p-dine-3",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeWaterHappy",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "店员先给你端来一杯冰水！想先要菜单的话，找找含 תַּפְרִיט（菜单）的句子。"
                ),
                CafeSceneChoice(
                    id: "p-dine-7",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeBillHappy",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "还没点单就说买单啦！再选一次「菜单」吧。"
                )
            ],
            interaction: CafeStageInteraction(
                label: "轻点接过菜单 · 翻看双语餐单",
                emoji: "📜",
                xFraction: 0.46,
                yFraction: 0.68,
                opensMenu: true,
                doneText: "你翻开了特拉维夫双语菜单，锁定了招牌奶咖！",
                prop: .menu,
                burstEmoji: "📜✨",
                tapAudioHebrew: "תַּפְרִיט",
                culturalTip: "小贴士：אֶפְשָׁר (efshar) = 可以吗？是点单时最万能的礼貌开头。"
            )
        ),
        CafeAct(
            id: "coffee",
            stepLabel: "点单",
            title: "第二幕 · 点一杯奶咖",
            sceneNote: "店员端着香气扑鼻的咖啡托盘微笑走近，你准备点一杯以色列经典奶咖（Kafeh Hafuch）。",
            baseImage: "CafeCoffeeApproach",
            barista: CafeBaristaPrompt(
                hebrew: "לָשֶׁבֶת כָּאן אוֹ לָקַחַת?",
                unpointed: "לשבת כאן או לקחת?",
                transliteration: "Lashevet kan o lakakhat?",
                meaningZh: "在这里喝还是带走？想点什么呢？"
            ),
            customerThought: "就坐在这里，点一杯热奶咖吧！",
            choices: [
                CafeSceneChoice(
                    id: "p-dine-2",
                    isCorrect: true,
                    animationFrames: ["CafeCoffeeApproach", "CafeTastingHappy"],
                    outcomeImage: "CafeTastingHappy",
                    baristaReplyHebrew: "מְצֻיָּן! הִנֵּה הַקָּפֶה הֶהָפוּךְ שֶׁלְּךָ.",
                    baristaReplyZh: "太棒了！热腾腾的招牌奶咖为你端上来了。",
                    wrongTip: nil
                ),
                CafeSceneChoice(
                    id: "p-dine-5",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "你问了有没有素食菜品～现在想先点一杯奶咖（קָפֶה הָפוּךְ）哦！"
                ),
                CafeSceneChoice(
                    id: "p-dine-14",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "店员眨了眨眼：还没说要喝什么呢！先点一杯奶咖吧。"
                )
            ],
            interaction: CafeStageInteraction(
                label: "轻点热咖啡杯 · 补充「不加糖」",
                emoji: "☕",
                xFraction: 0.38,
                yFraction: 0.62,
                opensMenu: false,
                doneText: "你顺口补了一句：בְּלִי סֻכָּר, בְּבַקָּשָׁה.（请不要加糖）",
                prop: .coffee,
                burstEmoji: "☕💨",
                tapAudioHebrew: "בְּלִי סֻכָּר, בְּבַקָּשָׁה.",
                culturalTip: "文化彩蛋：קָפֶה הָפוּךְ 字面是「倒过来的咖啡」；男性说 רוֹצֶה (rotzeh)，女性说 רוֹצָה (rotzah)。"
            )
        ),
        CafeAct(
            id: "water",
            stepLabel: "冷水",
            title: "第三幕 · 顺便来杯冰水",
            sceneNote: "午后阳光暖洋洋的，配着咖啡你想礼貌地向店员要一杯冰水解渴。",
            baseImage: "CafeWaterHappy",
            barista: CafeBaristaPrompt(
                hebrew: "עוֹד מַשֶּׁהוּ בֵּינְתַיִם?",
                unpointed: "עוד משהו בינתיים?",
                transliteration: "Od mashehu beintayim?",
                meaningZh: "还需要点别的吗？"
            ),
            customerThought: "好渴，再来一杯冰水吧…",
            choices: [
                CafeSceneChoice(
                    id: "p-dine-3",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeWaterHappy",
                    baristaReplyHebrew: "בְּשִׂמְחָה! הִנֵּה מַיִם קָרִים.",
                    baristaReplyZh: "乐意效劳！这是一杯冰水，请慢用。",
                    wrongTip: nil
                ),
                CafeSceneChoice(
                    id: "p-dine-1",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "菜单已经在你手边啦！我们要的是冰水（מַיִם קָרִים）哦。"
                ),
                CafeSceneChoice(
                    id: "p-dine-7",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeBillHappy",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "咖啡都还没喝完呢，先别急着结账！选含 מַיִם（水）的那句。"
                )
            ],
            interaction: CafeStageInteraction(
                label: "轻点冰水杯 · 清凉喝一口",
                emoji: "💧",
                xFraction: 0.52,
                yFraction: 0.74,
                opensMenu: false,
                doneText: "冰凉清爽！你顺便记住了「水」就是 מַיִם (mayim)。",
                prop: .water,
                burstEmoji: "💧❄️✨",
                tapAudioHebrew: "מַיִם",
                culturalTip: "词法提示：מַיִם（水）在希伯来语中永远是复数形式，所以形容词「冷的」也用复数 קָרִים (karim)。"
            )
        ),
        CafeAct(
            id: "taste",
            stepLabel: "品尝",
            title: "第四幕 · 品尝与赞美",
            sceneNote: "你双手捧起温热的奶咖抿了一口，奶泡绵密香醇！店员微笑着祝你慢用。",
            baseImage: "CafeTastingHappy",
            barista: CafeBaristaPrompt(
                hebrew: "בְּתֵאָבוֹן!",
                unpointed: "בתיאבון!",
                transliteration: "Be-teavon!",
                meaningZh: "请慢用（祝你好胃口）！"
            ),
            customerThought: "奶泡好绵密，太好喝了，夸一句吧！",
            choices: [
                CafeSceneChoice(
                    id: "p-dine-4",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeTastingHappy",
                    baristaReplyHebrew: "תּוֹדָה רַבָּה! אֵיזֶה כֵּיף!",
                    baristaReplyZh: "非常感谢！听你这么说真开心！",
                    wrongTip: nil
                ),
                CafeSceneChoice(
                    id: "p-dine-6",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeTastingHappy",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "这杯已经按你的要求没加糖啦～想夸它「非常美味」，找找 טָעִים (taim)！"
                ),
                CafeSceneChoice(
                    id: "p-greet-2",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeTastingHappy",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "虽然很礼貌，但这里更想直接夸赞「太美味了」（זֶה טָעִים מְאֹד!）。"
                )
            ],
            interaction: CafeStageInteraction(
                label: "轻点送出好评 · 与店员相视一笑",
                emoji: "💛",
                xFraction: 0.68,
                yFraction: 0.34,
                opensMenu: false,
                doneText: "店员开心地笑起来，咖啡馆里洋溢着温暖的阳光！",
                prop: .coffee,
                burstEmoji: "💛☕✨",
                tapAudioHebrew: "טָעִים",
                culturalTip: "高频词：טָעִים (taim) 既能夸菜好吃，也能夸咖啡好喝；加上 מְאֹד (meod) 就是「非常」。"
            )
        ),
        CafeAct(
            id: "bill",
            stepLabel: "买单",
            title: "第五幕 · 结账告别",
            sceneNote: "惬意的咖啡时光结束，准备向店员礼貌地要账单结账离开。",
            baseImage: "CafeBillHappy",
            barista: CafeBaristaPrompt(
                hebrew: "הַכֹּל הָיָה בְּסֵדֶר?",
                unpointed: "הכול היה בסדר?",
                transliteration: "Hakol hayah beseder?",
                meaningZh: "今天一切都还满意吗？"
            ),
            customerThought: "喝完啦，该礼貌地买单离开咯。",
            choices: [
                CafeSceneChoice(
                    id: "p-dine-7",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeBillHappy",
                    baristaReplyHebrew: "בְּוַדַּאי, הִנֵּה הַחֶשְׁבּוֹן. תּוֹדָה!",
                    baristaReplyZh: "好的，这是账单。欢迎下次再来！",
                    wrongTip: nil
                ),
                CafeSceneChoice(
                    id: "p-dine-1",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "店员以为你要加单！准备买单要找含 חֶשְׁבּוֹן（账单）的那句。"
                ),
                CafeSceneChoice(
                    id: "p-dine-3",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeWaterHappy",
                    baristaReplyHebrew: nil,
                    baristaReplyZh: nil,
                    wrongTip: "店员又端来一杯冰水！准备结账要说 הַחֶשְׁבּוֹן (ha-cheshbon)。"
                )
            ],
            interaction: CafeStageInteraction(
                label: "轻点账单 · 付款并道别",
                emoji: "🧾",
                xFraction: 0.49,
                yFraction: 0.66,
                opensMenu: false,
                doneText: "你挥手告别：לְהִתְרָאוֹת בְּקָרוֹב!（回头见！）",
                prop: .paid,
                burstEmoji: "🧾🎉👋",
                tapAudioHebrew: "לְהִתְרָאוֹת בְּקָרוֹב!",
                culturalTip: "实战总结：תַּפְרִיט(菜单) → קָפֶה הָפוּךְ(奶咖) → מַיִם קָרִים(冰水) → טָעִים מְאֹד(超好喝) → חֶשְׁבּוֹן(账单)，一整套咖啡馆全流程通关！"
            )
        )
    ]
}

private struct CafeMenuCardItem: Identifiable {
    let id: String
    let emoji: String
    let hebrew: String
    let unpointed: String
    let transliteration: String
    let meaningZh: String
    let price: String
    let audioHebrew: String

    static let all: [CafeMenuCardItem] = [
        CafeMenuCardItem(id: "coffee", emoji: "☕", hebrew: "קָפֶה הָפוּךְ", unpointed: "קפה הפוך", transliteration: "kafeh hafuch", meaningZh: "以色列奶咖（招牌）", price: "₪16", audioHebrew: "קָפֶה"),
        CafeMenuCardItem(id: "water", emoji: "💧", hebrew: "כּוֹס מַיִם קָרִים", unpointed: "כוס מים קרים", transliteration: "kos mayim karim", meaningZh: "冰水", price: "免费", audioHebrew: "מַיִם"),
        CafeMenuCardItem(id: "salad", emoji: "🥗", hebrew: "סָלָט טָרִי", unpointed: "סלט טרי", transliteration: "salat tari", meaningZh: "新鲜田园沙拉", price: "₪38", audioHebrew: "סָלָט"),
        CafeMenuCardItem(id: "nosugar", emoji: "✨", hebrew: "בְּלִי סֻכָּר", unpointed: "בלי סוכר", transliteration: "bli sukar", meaningZh: "备注：不加糖", price: "可选", audioHebrew: "סֻכָּר")
    ]
}

private struct CafeTranscriptEntry: Identifiable {
    let id = UUID()
    let isUser: Bool
    let hebrew: String
    let unpointed: String
    let transliteration: String
    let meaningZh: String
}

private struct CafeHotspotTip: Equatable {
    let title: String
    let hebrew: String?
    let subtitle: String
}

private enum CafeDialoguePhase: Equatable {
    case prompt
    case animating
    case interact
    case wrong
    case summary
}

struct StudyCafeComicView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: StudyContent

    @State private var actIndex = 0
    @State private var phase: CafeDialoguePhase = .prompt
    @State private var activeFrames: [String] = []
    @State private var frameStep = 0
    @State private var choiceOrder: [String] = []
    @State private var wrongChoiceIDs: Set<String> = []
    @State private var lastWrongChoice: CafeSceneChoice?
    @State private var lastWrongPhrase: StudyPhrase?
    @State private var mistakes = 0

    @State private var showNiqqud = true
    @State private var showTransliteration = true
    @State private var showTranslation = false

    @State private var stageInteracted = false
    @State private var tableProps: Set<CafeStageInteraction.Prop> = []
    @State private var hotspotTip: CafeHotspotTip?
    @State private var burstEmoji: String?
    @State private var showMenuCard = false
    @State private var showTranscript = false
    @State private var history: [CafeTranscriptEntry] = []

    @State private var shakeTrigger = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var burstTask: Task<Void, Never>?
    @State private var celebration: StudyAnswerCelebration?

    private var currentAct: CafeAct {
        CafeAct.all[min(max(actIndex, 0), CafeAct.all.count - 1)]
    }

    private var phraseIndex: [String: StudyPhrase] {
        Dictionary(uniqueKeysWithValues: content.phrases.map { ($0.id, $0) })
    }

    private var currentImageName: String {
        if !activeFrames.isEmpty {
            return activeFrames[min(frameStep, activeFrames.count - 1)]
        }
        if phase == .interact, let sol = currentAct.solutionChoice {
            return sol.outcomeImage
        }
        if phase == .wrong, let wrong = lastWrongChoice {
            return wrong.outcomeImage
        }
        return currentAct.baseImage
    }

    var body: some View {
        StudyPage {
            if phase == .summary {
                summaryView
            } else {
                actStepper
                stageCard
                scaffoldingBar
                if showMenuCard {
                    bilingualMenuCard
                }
                if showTranscript {
                    transcriptCard
                }
                if phase == .interact {
                    postInteractionCard
                } else {
                    choicesCard
                }
            }
        }
        .studyDetail("特拉维夫咖啡馆")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if phase != .summary {
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                            showTranscript.toggle()
                        }
                    } label: {
                        Label("\(history.count)", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption.weight(.semibold))
                    }
                    .accessibilityLabel("对话记录")
                }
            }
        }
        .studyAnswerCelebration(celebration)
        .onAppear {
            if choiceOrder.isEmpty {
                startAct(0, autoSpeak: false)
            }
        }
        .onDisappear {
            animationTask?.cancel()
            burstTask?.cancel()
            audio.stop()
        }
    }

    // MARK: - 5-Act Stepper

    private var actStepper: some View {
        HStack(spacing: 6) {
            ForEach(Array(CafeAct.all.enumerated()), id: \.element.id) { idx, act in
                let isActive = idx == actIndex
                let isDone = idx < actIndex
                Button {
                    startAct(idx, autoSpeak: true)
                } label: {
                    Text(isDone ? "✓ \(act.stepLabel)" : "\(idx + 1).\(act.stepLabel)")
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(isActive ? Color.white : (isDone ? progress.theme.success : progress.theme.mutedInk))
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(LinearGradient(colors: progress.theme.warmGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            } else {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(isDone ? progress.theme.successSurface : progress.theme.cardSurface)
                            }
                        }
                        .overlay {
                            if !isActive && !isDone {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(progress.theme.outline.opacity(0.75), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Interactive Cinema Stage

    private var stageCard: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(spacing: 0) {
            CafeCinemaStage(
                imageName: currentImageName,
                act: currentAct,
                phase: phase,
                activeFrames: activeFrames,
                frameStep: frameStep,
                tableProps: tableProps,
                stageInteracted: stageInteracted,
                hotspotTip: hotspotTip,
                burstEmoji: burstEmoji,
                shakeTrigger: shakeTrigger,
                onTapCustomer: {
                    audio.playSelectionHaptic()
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                        hotspotTip = CafeHotspotTip(
                            title: "你的内心想法",
                            hebrew: nil,
                            subtitle: currentAct.customerThought
                        )
                    }
                },
                onTapBarista: {
                    speakIfAvailable(currentAct.barista.hebrew)
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                        hotspotTip = CafeHotspotTip(
                            title: "店员刚刚说",
                            hebrew: showNiqqud ? currentAct.barista.hebrew : currentAct.barista.unpointed,
                            subtitle: "\(currentAct.barista.transliteration) · \(currentAct.barista.meaningZh)"
                        )
                    }
                },
                onTapProp: { prop in
                    handlePropTap(prop)
                },
                onTapStageCTA: {
                    performStageInteraction()
                },
                onDismissTip: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        hotspotTip = nil
                    }
                },
                onSelectFrame: { idx in
                    animationTask?.cancel()
                    frameStep = idx
                    if phase == .animating {
                        phase = lastWrongChoice != nil ? .wrong : .interact
                    }
                },
                onReplayFrames: {
                    guard !activeFrames.isEmpty else { return }
                    let target: CafeDialoguePhase = lastWrongChoice != nil ? .wrong : .interact
                    playFrameSequence(activeFrames, targetPhase: target)
                }
            )
            stageBubbleBar
        }
        .background(progress.theme.cardSurface, in: shape)
        .clipShape(shape)
        .overlay {
            shape
                .strokeBorder(progress.theme.outline.opacity(0.75), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var stageBubbleBar: some View {
        let bubble = activeSpeechBubble
        if let bubble {
            HStack(alignment: .top, spacing: 10) {
                if let audioText = bubble.audioHebrew, audio.referenceRecordingURL(for: audioText) != nil {
                    PronunciationButton(hebrew: audioText, iconOnly: true, title: "播放台词", bundledOnly: true)
                } else {
                    Image(systemName: "bubble.left.fill")
                        .font(.subheadline)
                        .foregroundStyle(bubble.tint)
                        .frame(width: 36, height: 36)
                        .background(progress.theme.cardSurface, in: Circle())
                        .accessibilityHidden(true)
                }
                VStack(alignment: .trailing, spacing: 3) {
                    HStack {
                        Text(bubble.speaker)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(bubble.tint)
                        Spacer(minLength: 4)
                        if phase == .prompt {
                            Text("轻点画面人物可互动")
                                .font(.caption2)
                                .foregroundStyle(progress.theme.mutedInk)
                        }
                    }
                    HebrewText(text: bubble.hebrew, size: 19)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if showTransliteration, let tr = bubble.transliteration, !tr.isEmpty {
                        Text(tr)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(progress.theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if (showTranslation || bubble.alwaysShowMeaning), let zh = bubble.meaningZh {
                        Text(zh)
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(12)
            .background(bubble.surface)
        }
    }

    private struct StageBubbleContent {
        let speaker: String
        let hebrew: String
        let transliteration: String?
        let meaningZh: String?
        let audioHebrew: String?
        let tint: Color
        let surface: Color
        let alwaysShowMeaning: Bool
    }

    private var activeSpeechBubble: StageBubbleContent? {
        switch phase {
        case .prompt, .animating:
            let b = currentAct.barista
            return StageBubbleContent(
                speaker: "店员",
                hebrew: showNiqqud ? b.hebrew : b.unpointed,
                transliteration: b.transliteration,
                meaningZh: b.meaningZh,
                audioHebrew: b.hebrew,
                tint: progress.theme.accent,
                surface: progress.theme.cardSurface,
                alwaysShowMeaning: false
            )
        case .interact:
            guard let sol = currentAct.solutionChoice else { return nil }
            let phrase = phraseIndex[sol.id]
            return StageBubbleContent(
                speaker: "店员回应",
                hebrew: sol.baristaReplyHebrew ?? (phrase?.hebrew ?? ""),
                transliteration: nil,
                meaningZh: sol.baristaReplyZh,
                audioHebrew: phrase?.hebrew,
                tint: progress.theme.success,
                surface: progress.theme.successSurface,
                alwaysShowMeaning: true
            )
        case .wrong:
            guard let phrase = lastWrongPhrase else { return nil }
            return StageBubbleContent(
                speaker: "你刚才说了…",
                hebrew: showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed,
                transliteration: phrase.transliteration,
                meaningZh: phrase.meaningZh,
                audioHebrew: phrase.hebrew,
                tint: progress.theme.error,
                surface: progress.theme.errorSurface,
                alwaysShowMeaning: true
            )
        case .summary:
            return nil
        }
    }

    // MARK: - 3-Tier Learning Scaffolding Bar

    private var scaffoldingBar: some View {
        HStack(spacing: 8) {
            scaffoldPill("元音点", active: showNiqqud) { showNiqqud.toggle() }
            scaffoldPill("音译", active: showTransliteration) { showTransliteration.toggle() }
            scaffoldPill("中文", active: showTranslation) { showTranslation.toggle() }
            Spacer(minLength: 4)
            Text("第 \(actIndex + 1)/\(CafeAct.all.count) 幕")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(progress.theme.mutedInk)
        }
    }

    private func scaffoldPill(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            audio.playSelectionHaptic()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                action()
            }
        } label: {
            Text(active ? "✓ \(title)" : title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(active ? Color.white : progress.theme.mutedInk)
                .background(active ? progress.theme.accent : progress.theme.cardSurface, in: Capsule())
                .overlay {
                    if !active {
                        Capsule().strokeBorder(progress.theme.outline.opacity(0.8), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Interactive Bilingual Menu Card

    private var bilingualMenuCard: some View {
        StudyCard(padding: 14, spacing: 10) {
            HStack {
                Text("📜 特拉维夫双语菜单 · 点击词汇听读音")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progress.theme.ink)
                Spacer()
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        showMenuCard = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(progress.theme.mutedInk)
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(CafeMenuCardItem.all) { item in
                    Button {
                        speakIfAvailable(item.audioHebrew)
                    } label: {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Text(item.emoji)
                                Spacer()
                                Text(item.price)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(progress.theme.accent)
                            }
                            HebrewText(text: showNiqqud ? item.hebrew : item.unpointed, size: 16)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(item.meaningZh)
                                .font(.caption2)
                                .foregroundStyle(progress.theme.mutedInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                        }
                        .padding(10)
                        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Transcript Drawer Card

    private var transcriptCard: some View {
        StudyCard(padding: 12, spacing: 8) {
            HStack {
                Text("本场对话记录")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progress.theme.ink)
                Spacer()
                Button("收起") {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        showTranscript = false
                    }
                }
                .font(.caption.weight(.semibold))
            }
            if history.isEmpty {
                Text("选出第一句台词后，对话记录会自动汇总在这里。")
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
            } else {
                ForEach(history) { entry in
                    Button {
                        speakIfAvailable(entry.hebrew)
                    } label: {
                        HStack(spacing: 8) {
                            Text(entry.isUser ? "你" : "店员")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(entry.isUser ? progress.theme.success : progress.theme.mutedInk)
                                .frame(width: 28, alignment: .leading)
                            VStack(alignment: .trailing, spacing: 2) {
                                HebrewText(text: showNiqqud ? entry.hebrew : entry.unpointed, size: 16)
                                Text(entry.meaningZh)
                                    .font(.caption2)
                                    .foregroundStyle(progress.theme.mutedInk)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(8)
                        .background(entry.isUser ? progress.theme.successSurface : progress.theme.insetSurface,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Choices & Post-Interaction Cards

    private var choicesCard: some View {
        let orderedChoices = choiceOrder.compactMap { id in
            currentAct.choices.first(where: { $0.id == id })
        }
        return StudyCard(padding: 14, spacing: 10) {
            Text(currentAct.sceneNote)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(progress.theme.ink)

            if phase == .wrong, let tip = lastWrongChoice?.wrongTip {
                Text("😅 \(tip)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.theme.reminder)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(progress.theme.reminderSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            ForEach(orderedChoices) { item in
                if let phrase = phraseIndex[item.id] {
                    choiceRow(choice: item, phrase: phrase)
                }
            }
        }
    }

    private func choiceRow(choice: CafeSceneChoice, phrase: StudyPhrase) -> some View {
        let excluded = wrongChoiceIDs.contains(choice.id)
        return HStack(spacing: 6) {
            PronunciationButton(hebrew: phrase.hebrew, iconOnly: true, title: "试听：\(phrase.hebrew)", bundledOnly: true)
            Button {
                selectChoice(choice, phrase: phrase)
            } label: {
                VStack(alignment: .trailing, spacing: 3) {
                    HebrewText(text: showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed, size: 19)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if showTransliteration {
                        Text(phrase.transliteration)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(progress.theme.accent)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if showTranslation {
                        Text(phrase.meaningZh)
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(excluded || phase == .animating)

            if excluded {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(progress.theme.error)
                    .accessibilityLabel("已排除")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(excluded ? progress.theme.errorSurface : progress.theme.insetSurface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(excluded ? 0.65 : 1)
    }

    private var postInteractionCard: some View {
        let interaction = currentAct.interaction
        return StudyCard(padding: 14, spacing: 10) {
            if stageInteracted {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(progress.theme.success)
                    Text(interaction.doneText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(progress.theme.success)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(progress.theme.successSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("💡 \(interaction.culturalTip)")
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)

                Button {
                    if actIndex < CafeAct.all.count - 1 {
                        startAct(actIndex + 1, autoSpeak: true)
                    } else {
                        phase = .summary
                        celebration = StudyAnswerCelebration(combo: CafeAct.all.count)
                        audio.playFeedback(.correct)
                    }
                } label: {
                    Text(actIndex < CafeAct.all.count - 1
                         ? "进入第 \(actIndex + 2) 幕：\(CafeAct.all[actIndex + 1].stepLabel)"
                         : "完成点单 · 查看复盘")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(learningAction: true))
            } else {
                HStack(spacing: 10) {
                    Text(interaction.emoji)
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(progress.theme.reminderSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("请先在上方动画画面中互动")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(progress.theme.ink)
                        Text("轻点画面中闪烁的「\(interaction.label)」按钮触发下一段交互。")
                            .font(.caption)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                }
                Button {
                    performStageInteraction()
                } label: {
                    Text("\(interaction.emoji) \(interaction.label)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyButtonStyle(prominent: true))
            }
        }
    }

    // MARK: - Episode Summary View

    private var summaryView: some View {
        let stars = mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1)
        return VStack(alignment: .leading, spacing: 14) {
            StudyHeroCard(colors: progress.theme.warmGradient) {
                HStack {
                    Text("5 幕情景全部通关")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.22), in: Capsule())
                    Spacer()
                    Text(String(repeating: "★", count: stars) + String(repeating: "☆", count: 3 - stars))
                        .font(.headline)
                }
                Text("כָּל הַכָּבוֹד! 咖啡馆实战完成")
                    .font(.title3.weight(.bold))
                Text("从入座要菜单、点奶咖、要冰水、夸好喝到结账告别，你已完成完整特拉维夫点单对话（本轮小插曲 \(mistakes) 次）。")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.92))
            }

            StudyCard(padding: 14, spacing: 10) {
                HStack {
                    Text("本场核心台词复盘")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(progress.theme.ink)
                    Spacer()
                    Text("\(CafeAct.all.count) 句实战表达")
                        .font(.caption)
                        .foregroundStyle(progress.theme.mutedInk)
                }
                ForEach(Array(CafeAct.all.enumerated()), id: \.element.id) { idx, act in
                    if let sol = act.solutionChoice, let phrase = phraseIndex[sol.id] {
                        HStack(spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(progress.theme.accent)
                                .frame(width: 26, height: 26)
                                .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .trailing, spacing: 2) {
                                HebrewText(text: phrase.hebrew, size: 17)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(phrase.transliteration)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(progress.theme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(phrase.meaningZh)
                                    .font(.caption2)
                                    .foregroundStyle(progress.theme.mutedInk)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            PronunciationButton(hebrew: phrase.hebrew, iconOnly: true, title: "重听台词", bundledOnly: true)
                        }
                        .padding(10)
                        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }

            Button {
                restartEpisode()
            } label: {
                Label("再演一遍", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle(learningAction: true))
        }
    }

    // MARK: - Actions & Transitions

    private func startAct(_ index: Int, autoSpeak: Bool) {
        animationTask?.cancel()
        burstTask?.cancel()
        audio.stop()
        actIndex = min(max(index, 0), CafeAct.all.count - 1)
        phase = .prompt
        activeFrames = []
        frameStep = 0
        wrongChoiceIDs = []
        lastWrongChoice = nil
        lastWrongPhrase = nil
        stageInteracted = false
        hotspotTip = nil
        burstEmoji = nil
        showMenuCard = false
        choiceOrder = currentAct.choices.map(\.id).shuffled()
        if autoSpeak {
            speakIfAvailable(currentAct.barista.hebrew)
        }
    }

    private func restartEpisode() {
        history = []
        tableProps = []
        mistakes = 0
        celebration = nil
        startAct(0, autoSpeak: true)
    }

    private func selectChoice(_ choice: CafeSceneChoice, phrase: StudyPhrase) {
        guard phase != .animating, !wrongChoiceIDs.contains(choice.id) else { return }
        hotspotTip = nil
        speakIfAvailable(phrase.hebrew)

        if choice.isCorrect {
            lastWrongChoice = nil
            lastWrongPhrase = nil
            audio.playFeedback(.correct)
            celebration = StudyAnswerCelebration(combo: 0)
            history.append(CafeTranscriptEntry(
                isUser: false,
                hebrew: currentAct.barista.hebrew,
                unpointed: currentAct.barista.unpointed,
                transliteration: currentAct.barista.transliteration,
                meaningZh: currentAct.barista.meaningZh
            ))
            history.append(CafeTranscriptEntry(
                isUser: true,
                hebrew: phrase.hebrew,
                unpointed: phrase.hebrewUnpointed,
                transliteration: phrase.transliteration,
                meaningZh: phrase.meaningZh
            ))
            if choice.animationFrames.count > 1 {
                playFrameSequence(choice.animationFrames, targetPhase: .interact)
            } else {
                activeFrames = []
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    phase = .interact
                }
            }
        } else {
            mistakes += 1
            wrongChoiceIDs.insert(choice.id)
            lastWrongChoice = choice
            lastWrongPhrase = phrase
            shakeTrigger += 1
            audio.playFeedback(.wrong)
            activeFrames = []
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                phase = .wrong
            }
        }
    }

    private func playFrameSequence(_ frames: [String], targetPhase: CafeDialoguePhase) {
        animationTask?.cancel()
        activeFrames = frames
        if reduceMotion {
            frameStep = max(frames.count - 1, 0)
            phase = targetPhase
            return
        }
        frameStep = 0
        phase = .animating
        animationTask = Task { @MainActor in
            for step in 1..<frames.count {
                do {
                    try await Task.sleep(for: .milliseconds(650))
                } catch {
                    return
                }
                withAnimation(.easeInOut(duration: 0.28)) {
                    frameStep = step
                }
            }
            phase = targetPhase
        }
    }

    private func performStageInteraction() {
        let interaction = currentAct.interaction
        stageInteracted = true
        tableProps.insert(interaction.prop)
        audio.playFeedback(.flip)
        if interaction.opensMenu {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                showMenuCard = true
            }
        }
        if let hebrew = interaction.tapAudioHebrew {
            speakIfAvailable(hebrew)
        }
        triggerBurst(interaction.burstEmoji)
    }

    private func handlePropTap(_ prop: CafeStageInteraction.Prop) {
        audio.playSelectionHaptic()
        switch prop {
        case .menu:
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                showMenuCard.toggle()
            }
            speakIfAvailable("תַּפְרִיט")
        case .coffee:
            triggerBurst("☕💨")
            hotspotTip = CafeHotspotTip(title: "你的特拉维夫奶咖", hebrew: "קָפֶה הָפוּךְ", subtitle: "kafeh hafuch · 热气腾腾，不加糖")
            speakIfAvailable("קָפֶה")
        case .water:
            triggerBurst("💧❄️")
            hotspotTip = CafeHotspotTip(title: "冰水", hebrew: "מַיִם קָרִים", subtitle: "mayim karim · 清凉解渴")
            speakIfAvailable("מַיִם")
        case .paid:
            triggerBurst("🧾✨")
            speakIfAvailable("חֶשְׁבּוֹן")
        }
    }

    private func triggerBurst(_ emoji: String) {
        burstTask?.cancel()
        burstEmoji = emoji
        burstTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(1050))
            } catch {
                return
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                burstEmoji = nil
            }
        }
    }

    private func speakIfAvailable(_ hebrew: String) {
        guard audio.referenceRecordingURL(for: hebrew) != nil else { return }
        audio.speak(hebrew, rate: progress.speechRate, bundledOnly: true)
    }
}

// MARK: - Interactive Stage Subview

private struct CafeCinemaStage: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let imageName: String
    let act: CafeAct
    let phase: CafeDialoguePhase
    let activeFrames: [String]
    let frameStep: Int
    let tableProps: Set<CafeStageInteraction.Prop>
    let stageInteracted: Bool
    let hotspotTip: CafeHotspotTip?
    let burstEmoji: String?
    let shakeTrigger: Int

    let onTapCustomer: () -> Void
    let onTapBarista: () -> Void
    let onTapProp: (CafeStageInteraction.Prop) -> Void
    let onTapStageCTA: () -> Void
    let onDismissTip: () -> Void
    let onSelectFrame: (Int) -> Void
    let onReplayFrames: () -> Void

    @State private var breathing = false
    @State private var pulseRing = false
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(!reduceMotion && phase != .animating && breathing ? 1.04 : 1.0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: breathing)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: imageName)
                    .clipped()
                    .accessibilityLabel(act.title)

                LinearGradient(
                    colors: [Color.black.opacity(0.32), Color.clear, Color.black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                // Top Bar: Act badge + accumulated table props + replay
                VStack {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text(act.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(progress.theme.ink)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())

                        Spacer(minLength: 4)

                        if tableProps.contains(.menu) {
                            propBadge("📜", label: "查看菜单") { onTapProp(.menu) }
                        }
                        if tableProps.contains(.coffee) {
                            propBadge("☕", label: "热奶咖") { onTapProp(.coffee) }
                        }
                        if tableProps.contains(.water) {
                            propBadge("💧", label: "冰水") { onTapProp(.water) }
                        }
                        if activeFrames.count > 1 {
                            Button(action: onReplayFrames) {
                                Text("↻ 重播")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(progress.theme.ink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    Spacer()
                }

                // Always-on character hotspots
                if phase != .animating {
                    hotspotButton(emoji: "💭", tint: .orange, label: "查看顾客想法", action: onTapCustomer)
                        .position(x: geo.size.width * 0.24, y: geo.size.height * 0.44)

                    hotspotButton(emoji: "🔊", tint: .teal, label: "重听店员台词", action: onTapBarista)
                        .position(x: geo.size.width * 0.72, y: geo.size.height * 0.36)
                }

                // Direct stage interaction CTA
                if phase == .interact && !stageInteracted {
                    Button(action: onTapStageCTA) {
                        HStack(spacing: 6) {
                            Text(act.interaction.emoji)
                            Text(act.interaction.label)
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(colors: progress.theme.warmGradient, startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                        .shadow(color: Color.orange.opacity(0.45), radius: 10, y: 4)
                        .scaleEffect(!reduceMotion && pulseRing ? 1.04 : 0.98)
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: geo.size.width * act.interaction.xFraction,
                        y: geo.size.height * act.interaction.yFraction
                    )
                }

                // Floating burst emoji
                if let burstEmoji {
                    Text(burstEmoji)
                        .font(.largeTitle)
                        .shadow(radius: 6)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                // Bottom Overlay: Hotspot Tooltip OR Multi-Frame Scrubber
                VStack {
                    Spacer()
                    if let tip = hotspotTip {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tip.title)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(progress.theme.ink)
                                if let he = tip.hebrew {
                                    HebrewText(text: he, size: 15)
                                }
                                Text(tip.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(progress.theme.mutedInk)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            Button(action: onDismissTip) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(progress.theme.mutedInk)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(10)
                    } else if activeFrames.count > 1 {
                        HStack {
                            HStack(spacing: 4) {
                                ForEach(0..<activeFrames.count, id: \.self) { idx in
                                    let label = idx == 0 ? "1 过场" : "2 完成"
                                    Button {
                                        onSelectFrame(idx)
                                    } label: {
                                        Text(label)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .foregroundStyle(frameStep == idx ? Color.white : progress.theme.ink)
                                            .background(frameStep == idx ? Color.orange : Color.clear, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(4)
                            .background(.ultraThinMaterial, in: Capsule())
                            Spacer()
                        }
                        .padding(10)
                    }
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .offset(x: shakeOffset)
        .onAppear {
            if !reduceMotion {
                breathing = true
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulseRing = true
                }
            }
        }
        .onChange(of: shakeTrigger) { _, _ in
            guard !reduceMotion else { return }
            Task { @MainActor in
                for offset in [-7.0, 7.0, -4.0, 4.0, 0.0] {
                    withAnimation(.linear(duration: 0.06)) {
                        shakeOffset = offset
                    }
                    try? await Task.sleep(for: .milliseconds(60))
                }
            }
        }
    }

    private func propBadge(_ emoji: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(emoji)
                .font(.caption)
                .frame(width: 26, height: 26)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func hotspotButton(emoji: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if !reduceMotion {
                    Circle()
                        .fill(tint.opacity(0.35))
                        .frame(width: 34, height: 34)
                        .scaleEffect(pulseRing ? 1.28 : 0.88)
                        .opacity(pulseRing ? 0.15 : 0.65)
                }
                Text(emoji)
                    .font(.caption2)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.92), in: Circle())
                    .overlay(Circle().strokeBorder(tint.opacity(0.75), lineWidth: 1))
                    .shadow(radius: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
