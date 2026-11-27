import SwiftUI

enum StudyComicScenario: String, CaseIterable, Identifiable {
    case telAvivCafe
    case oldCityDayTrip
    case rainyTransfer

    var id: String { rawValue }

    var navTitle: String {
        switch self {
        case .telAvivCafe: "特拉维夫咖啡馆"
        case .oldCityDayTrip: "旧城一日游"
        case .rainyTransfer: "雨天换乘"
        }
    }

    var cardTitle: String {
        switch self {
        case .telAvivCafe: "咖啡馆点单"
        case .oldCityDayTrip: "旧城一日游"
        case .rainyTransfer: "雨天换乘"
        }
    }

    var cardSubtitle: String {
        switch self {
        case .telAvivCafe: "入座要菜单、点奶咖、要冷水、夸好喝到买单"
        case .oldCityDayTrip: "集市买石榴、老城问路、庭院畅聊与日落告别"
        case .rainyTransfer: "问线路、找站点、听到站时间"
        }
    }

    var categoryTag: String {
        switch self {
        case .telAvivCafe: "餐饮点单"
        case .oldCityDayTrip: "旅行探索"
        case .rainyTransfer: "公交出行"
        }
    }

    var coverImage: String {
        switch self {
        case .telAvivCafe: "CafeMenuOrder"
        case .oldCityDayTrip: "OldCityMarket"
        case .rainyTransfer: RainyTransferSession.Phase.askDriver.imageName
        }
    }

    var actCountBadge: String {
        let count = switch self {
        case .telAvivCafe: ScenarioAct.cafeActs.count
        case .oldCityDayTrip: ScenarioAct.oldCityActs.count
        case .rainyTransfer: RainyTransferSession.actTitles.count
        }
        return "\(count) 幕 · \(categoryTag)"
    }
}

private enum StudyDialogueScenario {
    case telAvivCafe
    case oldCityDayTrip

    var navTitle: String {
        switch self {
        case .telAvivCafe: StudyComicScenario.telAvivCafe.navTitle
        case .oldCityDayTrip: StudyComicScenario.oldCityDayTrip.navTitle
        }
    }

    var partnerRole: String {
        switch self {
        case .telAvivCafe: "店员"
        case .oldCityDayTrip: "当地向导"
        }
    }

    var stageAspectRatio: CGFloat {
        16.0 / 9.0
    }

    var summaryHeadline: String {
        switch self {
        case .telAvivCafe: "כָּל הַכָּבוֹד! 咖啡馆实战完成"
        case .oldCityDayTrip: "יוֹם נִפְלָא! 旧城一日游通关"
        }
    }

    var summaryDescription: String {
        switch self {
        case .telAvivCafe:
            "从入座要菜单、点奶咖、要冷水、夸好喝到结账告别，你已完成完整特拉维夫点单对话"
        case .oldCityDayTrip:
            "从集市买石榴、老城巷尾问路、庭院喝茶畅聊到日落露台道别，你已完成完整旅行情景对话"
        }
    }

    var cardPopupTitle: String {
        switch self {
        case .telAvivCafe: "📜 特拉维夫双语菜单 · 点击词汇听读音"
        case .oldCityDayTrip: "🍎 露天集市风物卡（שׁוּק）· 点击听读音"
        }
    }

    var popupItems: [ScenarioPopupItem] {
        switch self {
        case .telAvivCafe: ScenarioPopupItem.cafeMenu
        case .oldCityDayTrip: ScenarioPopupItem.shukMarket
        }
    }

    fileprivate var acts: [ScenarioAct] {
        switch self {
        case .telAvivCafe: ScenarioAct.cafeActs
        case .oldCityDayTrip: ScenarioAct.oldCityActs
        }
    }
}

private struct ScenarioSceneChoice: Identifiable {
    let id: String
    let isCorrect: Bool
    let animationFrames: [String]
    let outcomeImage: String
    let partnerReplyHebrew: String?
    let partnerReplyZh: String?
    let wrongTip: String?
}

private struct ScenarioStageInteraction {
    let label: String
    let emoji: String
    let xFraction: CGFloat
    let yFraction: CGFloat
    let opensPopupCard: Bool
    let doneText: String
    let propID: String
    let propEmoji: String
    let propLabel: String
    let propTipTitle: String
    let propTipHebrew: String
    let propTipSubtitle: String
    let burstEmoji: String
    let tapAudioHebrew: String?
    let culturalTip: String
}

private struct ScenarioPartnerPrompt {
    let hebrew: String
    let unpointed: String
    let transliteration: String
    let meaningZh: String
}

private struct ScenarioAct: Identifiable {
    let id: String
    let stepLabel: String
    let title: String
    let sceneNote: String
    let baseImage: String
    let partner: ScenarioPartnerPrompt
    let userThought: String
    let customerHotspot: CGPoint
    let partnerHotspot: CGPoint
    let choices: [ScenarioSceneChoice]
    let interaction: ScenarioStageInteraction

    var solutionChoice: ScenarioSceneChoice? {
        choices.first(where: \.isCorrect)
    }

    // MARK: - Scenario 1: Tel Aviv Cafe (5 Acts)

    static let cafeActs: [ScenarioAct] = [
        ScenarioAct(
            id: "menu",
            stepLabel: "入座",
            title: "第一幕 · 入座要菜单",
            sceneNote: "你刚在特拉维夫阳光咖啡馆坐下，店员笑着走来问候。你想先要一份菜单。",
            baseImage: "CafeMenuOrder",
            partner: ScenarioPartnerPrompt(
                hebrew: "שָׁלוֹם, מַה שְׁלוֹמְךָ?",
                unpointed: "שלום, מה שלומך?",
                transliteration: "Shalom, ma shlomkha?",
                meaningZh: "你好，你近来怎么样？"
            ),
            userThought: "想先看看菜单再点单…",
            customerHotspot: CGPoint(x: 0.24, y: 0.44),
            partnerHotspot: CGPoint(x: 0.72, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-dine-1",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    partnerReplyHebrew: "בְּוַדַּאי! הִנֵּה הַתַּפְרִיט.",
                    partnerReplyZh: "当然！这是菜单。",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-dine-3",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeWaterHappy",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "店员先给你端来一杯冷水！想先要菜单的话，找找含 תַּפְרִיט（菜单）的句子。"
                ),
                ScenarioSceneChoice(
                    id: "p-dine-7",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeBillHappy",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "还没点单就说买单啦！再选一次「菜单」吧。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点接过菜单 · 翻看双语餐单",
                emoji: "📜",
                xFraction: 0.46,
                yFraction: 0.68,
                opensPopupCard: true,
                doneText: "你翻开了特拉维夫双语菜单，锁定了招牌奶咖！",
                propID: "menu",
                propEmoji: "📜",
                propLabel: "查看菜单",
                propTipTitle: "双语菜单",
                propTipHebrew: "תַּפְרִיט",
                propTipSubtitle: "tafrit · 点击展开菜单",
                burstEmoji: "📜✨",
                tapAudioHebrew: "תַּפְרִיט",
                culturalTip: "小贴士：אֶפְשָׁר (efshar) = 可以吗？是点单时最万能的礼貌开头。"
            )
        ),
        ScenarioAct(
            id: "coffee",
            stepLabel: "点单",
            title: "第二幕 · 点一杯奶咖",
            sceneNote: "店员端着香气扑鼻的咖啡托盘微笑走近，你准备点一杯以色列经典奶咖（Kafeh Hafuch）。",
            baseImage: "CafeCoffeeApproach",
            partner: ScenarioPartnerPrompt(
                hebrew: "מָה תִּרְצֶה לִשְׁתּוֹת?",
                unpointed: "מה תרצה לשתות?",
                transliteration: "Ma tirtse lishtot?",
                meaningZh: "你想喝什么？（对男性）"
            ),
            userThought: "就坐在这里，点一杯热奶咖吧！",
            customerHotspot: CGPoint(x: 0.24, y: 0.44),
            partnerHotspot: CGPoint(x: 0.72, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-dine-2",
                    isCorrect: true,
                    animationFrames: ["CafeCoffeeApproach", "CafeTastingHappy"],
                    outcomeImage: "CafeTastingHappy",
                    partnerReplyHebrew: "מְצֻיָּן! הִנֵּה הַקָּפֶה הֶהָפוּךְ שֶׁלְּךָ.",
                    partnerReplyZh: "太好了！这是你的奶咖。",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-dine-5",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeCoffeeApproach",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "你问了有没有素食菜品～现在想先点一杯奶咖（קָפֶה הָפוּךְ）哦！"
                ),
                ScenarioSceneChoice(
                    id: "p-dine-14",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeCoffeeApproach",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "店员眨了眨眼：还没说要喝什么呢！先点一杯奶咖吧。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点热咖啡杯 · 补充「不加糖」",
                emoji: "☕",
                xFraction: 0.38,
                yFraction: 0.62,
                opensPopupCard: false,
                doneText: "你顺口补了一句：בְּלִי סֻכָּר, בְּבַקָּשָׁה.（请不要加糖）",
                propID: "coffee",
                propEmoji: "☕",
                propLabel: "热奶咖",
                propTipTitle: "你的特拉维夫奶咖",
                propTipHebrew: "קָפֶה הָפוּךְ",
                propTipSubtitle: "kafeh hafuch · 热气腾腾，不加糖",
                burstEmoji: "☕💨",
                tapAudioHebrew: "קָפֶה הָפוּךְ",
                culturalTip: "文化彩蛋：קָפֶה הָפוּךְ 字面是「倒过来的咖啡」；男性说 רוֹצֶה (rotzeh)，女性说 רוֹצָה (rotzah)。"
            )
        ),
        ScenarioAct(
            id: "water",
            stepLabel: "冷水",
            title: "第三幕 · 顺便来杯冷水",
            sceneNote: "午后阳光暖洋洋的，配着咖啡你想礼貌地向店员要一杯冷水解渴。",
            baseImage: "CafeWaterHappy",
            partner: ScenarioPartnerPrompt(
                hebrew: "עוֹד מַשֶּׁהוּ בֵּינְתַיִם?",
                unpointed: "עוד משהו בינתיים?",
                transliteration: "Od mashehu beintayim?",
                meaningZh: "还需要点别的吗？"
            ),
            userThought: "好渴，再来一杯冷水吧…",
            customerHotspot: CGPoint(x: 0.24, y: 0.44),
            partnerHotspot: CGPoint(x: 0.72, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-dine-3",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeWaterHappy",
                    partnerReplyHebrew: "בְּשִׂמְחָה! הִנֵּה מַיִם קָרִים.",
                    partnerReplyZh: "乐意效劳！这是冷水。",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-dine-1",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "菜单已经在你手边啦！我们要的是冷水（מַיִם קָרִים）哦。"
                ),
                ScenarioSceneChoice(
                    id: "p-dine-7",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeBillHappy",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "咖啡都还没喝完呢，先别急着结账！选含 מַיִם（水）的那句。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点冷水杯 · 清凉喝一口",
                emoji: "💧",
                xFraction: 0.52,
                yFraction: 0.74,
                opensPopupCard: false,
                doneText: "冰凉清爽！你顺便记住了「水」就是 מַיִם (mayim)。",
                propID: "water",
                propEmoji: "💧",
                propLabel: "冷水",
                propTipTitle: "冷水",
                propTipHebrew: "מַיִם קָרִים",
                propTipSubtitle: "mayim karim · 清凉解渴",
                burstEmoji: "💧❄️✨",
                tapAudioHebrew: "מַיִם קָרִים",
                culturalTip: "词法提示：מַיִם（水）在希伯来语中永远是复数形式，所以形容词「冷的」也用复数 קָרִים (karim)。"
            )
        ),
        ScenarioAct(
            id: "taste",
            stepLabel: "品尝",
            title: "第四幕 · 品尝与赞美",
            sceneNote: "你双手捧起温热的奶咖抿了一口，奶泡绵密香醇！店员微笑着祝你慢用。",
            baseImage: "CafeTastingHappy",
            partner: ScenarioPartnerPrompt(
                hebrew: "בְּתֵאָבוֹן!",
                unpointed: "בתיאבון!",
                transliteration: "Be-teavon!",
                meaningZh: "请慢用（祝你好胃口）！"
            ),
            userThought: "奶泡好绵密，太好喝了，夸一句吧！",
            customerHotspot: CGPoint(x: 0.24, y: 0.44),
            partnerHotspot: CGPoint(x: 0.72, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-dine-4",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeTastingHappy",
                    partnerReplyHebrew: "תּוֹדָה רַבָּה! אֵיזֶה כֵּיף!",
                    partnerReplyZh: "非常感谢！真开心！",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-dine-6",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeTastingHappy",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "这杯已经按你的要求没加糖啦～想夸它「非常美味」，找找 טָעִים (taim)！"
                ),
                ScenarioSceneChoice(
                    id: "p-greet-2",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeTastingHappy",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "虽然很礼貌，但这里更想直接夸赞「太美味了」（זֶה טָעִים מְאֹד!）。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点送出好评 · 与店员相视一笑",
                emoji: "💛",
                xFraction: 0.68,
                yFraction: 0.34,
                opensPopupCard: false,
                doneText: "店员开心地笑起来，咖啡馆里洋溢着温暖的阳光！",
                propID: "coffee",
                propEmoji: "☕",
                propLabel: "热奶咖",
                propTipTitle: "你的特拉维夫奶咖",
                propTipHebrew: "קָפֶה הָפוּךְ",
                propTipSubtitle: "kafeh hafuch · 香醇可口",
                burstEmoji: "💛☕✨",
                tapAudioHebrew: "קָפֶה הָפוּךְ",
                culturalTip: "高频词：טָעִים (taim) 既能夸菜好吃，也能夸咖啡好喝；加上 מְאֹד (meod) 就是「非常」。"
            )
        ),
        ScenarioAct(
            id: "bill",
            stepLabel: "买单",
            title: "第五幕 · 结账告别",
            sceneNote: "惬意的咖啡时光结束，准备向店员礼貌地要账单结账离开。",
            baseImage: "CafeBillHappy",
            partner: ScenarioPartnerPrompt(
                hebrew: "הַכֹּל הָיָה בְּסֵדֶר?",
                unpointed: "הכול היה בסדר?",
                transliteration: "Hakol hayah beseder?",
                meaningZh: "今天一切都还满意吗？"
            ),
            userThought: "喝完啦，该礼貌地买单离开咯。",
            customerHotspot: CGPoint(x: 0.24, y: 0.44),
            partnerHotspot: CGPoint(x: 0.72, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-dine-7",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "CafeBillHappy",
                    partnerReplyHebrew: "בְּוַדַּאי, הִנֵּה הַחֶשְׁבּוֹן. תּוֹדָה!",
                    partnerReplyZh: "当然，这是账单。谢谢！",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-dine-1",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeMenuOrder",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "店员以为你要加单！准备买单要找含 חֶשְׁבּוֹן（账单）的那句。"
                ),
                ScenarioSceneChoice(
                    id: "p-dine-3",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "CafeWaterHappy",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "店员又端来一杯冷水！准备结账要说 הַחֶשְׁבּוֹן (ha-cheshbon)。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点账单 · 付款并道别",
                emoji: "🧾",
                xFraction: 0.49,
                yFraction: 0.66,
                opensPopupCard: false,
                doneText: "你挥手告别：לְהִתְרָאוֹת בְּקָרוֹב!（回头见！）",
                propID: "paid",
                propEmoji: "🧾",
                propLabel: "账单",
                propTipTitle: "账单已结清",
                propTipHebrew: "חֶשְׁבּוֹן",
                propTipSubtitle: "cheshbon · 欢迎再来",
                burstEmoji: "🧾🎉👋",
                tapAudioHebrew: "חֶשְׁבּוֹן",
                culturalTip: "实战总结：תַּפְרִיט(菜单) → קָפֶה הָפוּךְ(奶咖) → מַיִם קָרִים(冷水) → טָעִים מְאֹד(超好喝) → חֶשְׁבּוֹן(账单)，一整套咖啡馆全流程通关！"
            )
        )
    ]

    // MARK: - Scenario 2: Old City Day Trip (4 Acts)

    static let oldCityActs: [ScenarioAct] = [
        ScenarioAct(
            id: "shuk",
            stepLabel: "集市",
            title: "第一幕 · 集市偶遇与问候",
            sceneNote: "你背着背包走进热闹的露天集市（שׁוּק），在石榴与无花果摊前驻足。摊主热情地挥手问候，你想问问石榴多少钱。",
            baseImage: "OldCityMarket",
            partner: ScenarioPartnerPrompt(
                hebrew: "שָׁלוֹם, מַה שְׁלוֹמְךָ?",
                unpointed: "שלום, מה שלומך?",
                transliteration: "Shalom, ma shlomkha?",
                meaningZh: "你好，你近来怎么样？"
            ),
            userThought: "这堆新鲜石榴看起来真棒，问问多少钱吧！",
            customerHotspot: CGPoint(x: 0.20, y: 0.34),
            partnerHotspot: CGPoint(x: 0.85, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-shop-1",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "OldCityMarket",
                    partnerReplyHebrew: "הָרִמּוֹנִים טְרִיִּים הַיּוֹם! עֶשֶׂר שְׁקָלִים.",
                    partnerReplyZh: "今天的石榴很新鲜！十谢克尔。",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-shop-4",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCityMarket",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "你说「我只是随便看看」～如果想打听价格，找找含 כַּמָּה（多少）的那句！"
                ),
                ScenarioSceneChoice(
                    id: "p-shop-6",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCityMarket",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "还没问价就先要袋子啦！先用 כַּמָּה זֶה עוֹלֶה? 问问价格吧。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点石榴摊 · 探索集市风物卡",
                emoji: "🍎",
                xFraction: 0.72,
                yFraction: 0.74,
                opensPopupCard: true,
                doneText: "你挑了两颗饱满的红石榴（רִמּוֹנִים），摊主还送了你一颗无花果！",
                propID: "shuk",
                propEmoji: "🍎",
                propLabel: "集市石榴",
                propTipTitle: "露天集市特产",
                propTipHebrew: "שׁוּק",
                propTipSubtitle: "shuk · 耶路撒冷/特拉维夫传统集市",
                burstEmoji: "🍎✨",
                tapAudioHebrew: "שׁוּק",
                culturalTip: "文化小贴士：שׁוּק (shuk) 指以色列最具烟火气的露天集市；询问价格最地道的一句就是 כַּמָּה זֶה עוֹלֶה?（Kamah zeh oleh?）。"
            )
        ),
        ScenarioAct(
            id: "alley",
            stepLabel: "问路",
            title: "第二幕 · 旧城问路与指引",
            sceneNote: "走出集市，她脱下围裙背上小包，正热心地在古老石墙边帮你看地图。你想问去老城地标该怎么走。",
            baseImage: "OldCityAlley",
            partner: ScenarioPartnerPrompt(
                hebrew: "שַׁעַר הָעִיר הָעַתִּיקָה קָרוֹב מִכָּאן.",
                unpointed: "שער העיר העתיקה קרוב מכאן.",
                transliteration: "Sha’ar ha’ir ha’atika karov mikan.",
                meaningZh: "老城门离这里很近。"
            ),
            userThought: "老城石巷像迷宫一样，问问怎么去前面的老城门吧…",
            customerHotspot: CGPoint(x: 0.26, y: 0.30),
            partnerHotspot: CGPoint(x: 0.62, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-dir-2",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "OldCityAlley",
                    partnerReplyHebrew: "לֵךְ יָשָׁר וְאַחַר כָּךְ פְּנֵה יָמִינָה.",
                    partnerReplyZh: "直走，然后向右转。",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-dir-4",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCityAlley",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "你问了「离这里远吗」～这次想直接问「怎么去那里」，找含 אֵיךְ（怎么）的那句！"
                ),
                ScenarioSceneChoice(
                    id: "p-dir-6",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCityAlley",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "这句是在问洗手间在哪儿啦！问路要用 אֵיךְ מַגִּיעִים לְשָׁם?。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点老城地图 · 听她指路方向",
                emoji: "🗺️",
                xFraction: 0.38,
                yFraction: 0.72,
                opensPopupCard: false,
                doneText: "她指着前方石巷说：לֵךְ יָשָׁר וְאַחַר כָּךְ פְּנֵה יָמִינָה.（直走，然后右转）",
                propID: "map",
                propEmoji: "🗺️",
                propLabel: "老城地图",
                propTipTitle: "老城指路路线",
                propTipHebrew: "לֵךְ יָשָׁר וְאַחַר כָּךְ פְּנֵה יָמִינָה.",
                propTipSubtitle: "直走，然后向右转",
                burstEmoji: "🗺️➡️✨",
                tapAudioHebrew: "לֵךְ יָשָׁר וְאַחַר כָּךְ פְּנֵה יָמִינָה.",
                culturalTip: "语法提示：לֵךְ (lech，直走) 与 פְּנֵה (pne，转弯) 是对男性的祈使句；对女性则说 לְכִי (lechi) 与 פְּנִי (pni)。"
            )
        ),
        ScenarioAct(
            id: "courtyard",
            stepLabel: "畅聊",
            title: "第三幕 · 庭院小憩与畅聊",
            sceneNote: "午后，你们在橄榄树与藤蔓环绕的庭院咖啡馆坐下，品着咖啡和点心。她好奇地问你从哪里来。",
            baseImage: "OldCityCourtyard",
            partner: ScenarioPartnerPrompt(
                hebrew: "מֵאֵיפֹה אַתָּה?",
                unpointed: "מאיפה אתה?",
                transliteration: "Me’eifo ata?",
                meaningZh: "你从哪里来？（对男性）"
            ),
            userThought: "告诉她我来自中国。",
            customerHotspot: CGPoint(x: 0.25, y: 0.34),
            partnerHotspot: CGPoint(x: 0.78, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-greet-6",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "OldCityCourtyard",
                    partnerReplyHebrew: "נָעִים מְאֹד לְהַכִּיר אוֹתְךָ.",
                    partnerReplyZh: "很高兴认识你。",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-dine-2",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCityCourtyard",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "桌上已经摆好两杯咖啡和点心啦～现在先回应她「我来自中国」（אֲנִי מִסִּין.）吧！"
                ),
                ScenarioSceneChoice(
                    id: "p-study-1",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCityCourtyard",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "她笑着夸你希伯来语不错！先告诉她你来自哪里（אֲנִי מִסִּין.）吧。"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点庭院茶点 · 干杯畅聊",
                emoji: "☕",
                xFraction: 0.52,
                yFraction: 0.78,
                opensPopupCard: false,
                doneText: "你们端起杯子相视而笑：נָעִים מְאֹד לְהַכִּיר אוֹתְךָ.（很高兴认识你）",
                propID: "tea",
                propEmoji: "☕",
                propLabel: "庭院茶点",
                propTipTitle: "阳光庭院小憩",
                propTipHebrew: "נָעִים מְאֹד לְהַכִּיר אוֹתְךָ.",
                propTipSubtitle: "Naim meod lehakir otkha · 很高兴认识你",
                burstEmoji: "☕🥐💛",
                tapAudioHebrew: "נָעִים מְאֹד לְהַכִּיר אוֹתְךָ.",
                culturalTip: "构词技巧：前缀 מִ־ (mi-) 表示「来自……」，所以 מִסִּין (mi-Sin) 就是「来自中国」！在某些字母前，前缀会变为 מֵ־ (me-)。"
            )
        ),
        ScenarioAct(
            id: "sunset",
            stepLabel: "告别",
            title: "第四幕 · 日落告别与约定",
            sceneNote: "夕阳西下，金色余晖洒满老城穹顶。你们在观景石阶前停下脚步，互相挥手道别，约定保持联系。",
            baseImage: "OldCitySunset",
            partner: ScenarioPartnerPrompt(
                hebrew: "שֶׁיִּהְיֶה לְךָ עֶרֶב נָעִים!",
                unpointed: "שיהיה לך ערב נעים!",
                transliteration: "She-yihye lekha erev na’im!",
                meaningZh: "祝你晚上愉快！（对男性）"
            ),
            userThought: "真是难忘的一天，挥手和她说「回头见」吧！",
            customerHotspot: CGPoint(x: 0.24, y: 0.30),
            partnerHotspot: CGPoint(x: 0.84, y: 0.36),
            choices: [
                ScenarioSceneChoice(
                    id: "p-greet-8",
                    isCorrect: true,
                    animationFrames: [],
                    outcomeImage: "OldCitySunset",
                    partnerReplyHebrew: "לְהִתְרָאוֹת! נִהְיֶה בְּקֶשֶׁר!",
                    partnerReplyZh: "再见！保持联系！",
                    wrongTip: nil
                ),
                ScenarioSceneChoice(
                    id: "p-greet-2",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCitySunset",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "这句是「一切都好，谢谢」～日落道别最温暖的是「回头见」（לְהִתְרָאוֹת בְּקָרוֹב!）。"
                ),
                ScenarioSceneChoice(
                    id: "p-greet-12",
                    isCorrect: false,
                    animationFrames: [],
                    outcomeImage: "OldCitySunset",
                    partnerReplyHebrew: nil,
                    partnerReplyZh: nil,
                    wrongTip: "这句是「我是第一次来这里」～现在已经到了告别时刻，选「回头见」吧！"
                )
            ],
            interaction: ScenarioStageInteraction(
                label: "轻点夕阳挥手 · 约定保持联系",
                emoji: "🌅",
                xFraction: 0.56,
                yFraction: 0.48,
                opensPopupCard: false,
                doneText: "金色晚霞映照着老城穹顶，你挥手道别：לְהִתְרָאוֹת בְּקָרוֹב!（回头见！）",
                propID: "sunset",
                propEmoji: "🌅",
                propLabel: "日落约定",
                propTipTitle: "旧城日落露台",
                propTipHebrew: "שֶׁיִּהְיֶה לְךָ עֶרֶב נָעִים!",
                propTipSubtitle: "祝你晚上愉快",
                burstEmoji: "🌅👋💛",
                tapAudioHebrew: "שֶׁיִּהְיֶה לְךָ עֶרֶב נָעִים!",
                culturalTip: "地道表达：לְהִתְרָאוֹת (lehitraot) 字面意为「彼此再相见」，比单纯说再见更有「期待重逢」的温度！"
            )
        )
    ]
}

struct ScenarioPopupItem: Identifiable {
    let id: String
    let emoji: String
    let hebrew: String
    let unpointed: String
    let transliteration: String
    let meaningZh: String
    let tag: String

    static let cafeMenu: [ScenarioPopupItem] = [
        ScenarioPopupItem(id: "coffee", emoji: "☕", hebrew: "קָפֶה הָפוּךְ", unpointed: "קפה הפוך", transliteration: "kafeh hafuch", meaningZh: "以色列奶咖（招牌）", tag: "₪16"),
        ScenarioPopupItem(id: "water", emoji: "💧", hebrew: "כּוֹס מַיִם קָרִים", unpointed: "כוס מים קרים", transliteration: "kos mayim karim", meaningZh: "冷水", tag: "免费"),
        ScenarioPopupItem(id: "salad", emoji: "🥗", hebrew: "סָלָט טָרִי", unpointed: "סלט טרי", transliteration: "salat tari", meaningZh: "新鲜沙拉", tag: "₪38"),
        ScenarioPopupItem(id: "nosugar", emoji: "✨", hebrew: "בְּלִי סֻכָּר", unpointed: "בלי סוכר", transliteration: "bli sukar", meaningZh: "备注：不加糖", tag: "可选")
    ]

    static let shukMarket: [ScenarioPopupItem] = [
        ScenarioPopupItem(id: "shuk", emoji: "🏛️", hebrew: "שׁוּק", unpointed: "שוק", transliteration: "shuk", meaningZh: "露天传统集市", tag: "地标"),
        ScenarioPopupItem(id: "price", emoji: "💰", hebrew: "כַּמָּה זֶה עוֹלֶה?", unpointed: "כמה זה עולה?", transliteration: "kamah zeh oleh?", meaningZh: "这个多少钱？", tag: "必学"),
        ScenarioPopupItem(id: "bag", emoji: "🛍️", hebrew: "אֶפְשָׁר שַׂקִּית בְּבַקָּשָׁה?", unpointed: "אפשר שקית בבקשה?", transliteration: "efshar sakit bevakasha?", meaningZh: "可以给个袋子吗？", tag: "实用"),
        ScenarioPopupItem(id: "tasty", emoji: "🍎", hebrew: "טָעִים", unpointed: "טעים", transliteration: "taim", meaningZh: "美味的", tag: "夸赞")
    ]
}

private struct ScenarioCollectedProp: Identifiable, Hashable {
    let id: String
    let emoji: String
    let label: String
    let tipTitle: String
    let tipHebrew: String
    let tipSubtitle: String
    let opensPopupCard: Bool
    let audioHebrew: String?
}

private struct ScenarioTranscriptEntry: Identifiable {
    let id = UUID()
    let isUser: Bool
    let hebrew: String
    let unpointed: String
    let meaningZh: String
}

private struct ScenarioHotspotTip: Equatable {
    let title: String
    let hebrew: String?
    let subtitle: String
}

private enum ScenarioDialoguePhase: Equatable {
    case prompt
    case animating
    case interact
    case wrong
    case summary
}

struct StudyCafeComicView: View {
    let content: StudyContent
    var scenario: StudyComicScenario = .telAvivCafe

    var body: some View {
        StudyScenarioComicView(content: content, scenario: scenario)
    }
}

struct StudyScenarioPosterCard: View {
    let scenario: StudyComicScenario
    var cardWidth: CGFloat? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(width: cardWidth)
            .overlay {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        Image(scenario.coverImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.24),
                                Color.black.opacity(0.06),
                                Color.black.opacity(0.76)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text(scenario.actCountBadge)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .environment(\.colorScheme, .dark)
                                Spacer()
                            }

                            Spacer(minLength: 8)

                            HStack(alignment: .bottom, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(scenario.cardTitle)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(Color.white)
                                    Text(scenario.cardSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.88))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                HStack(spacing: 3) {
                                    Text("开始")
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.bold))
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.22), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
            .contentShape(shape)
    }
}

struct StudyScenarioTheaterHubView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    var body: some View {
        StudyPage {
            StudyHeading(title: "情景剧场", eyebrow: "THEATER · 互动情景对话")
            Text("跟随图文分镜与真人希伯来语配音，在真实生活语境中练习开口表达与画面互动。")
                .font(.subheadline)
                .foregroundStyle(progress.theme.mutedInk)

            ForEach(StudyComicScenario.allCases) { scenario in
                NavigationLink {
                    StudyScenarioComicView(content: content, scenario: scenario)
                } label: {
                    StudyScenarioPosterCard(scenario: scenario)
                }
                .buttonStyle(.plain)
            }
        }
        .studyDetail("情景剧场")
    }
}

struct StudyScenarioComicView: View {
    let content: StudyContent
    let scenario: StudyComicScenario

    var body: some View {
        switch scenario {
        case .telAvivCafe: StudyDialogueComicView(content: content, scenario: .telAvivCafe)
        case .oldCityDayTrip: StudyDialogueComicView(content: content, scenario: .oldCityDayTrip)
        case .rainyTransfer: StudyRainyTransferView(content: content)
        }
    }
}

private struct StudyDialogueComicView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: StudyContent
    let scenario: StudyDialogueScenario

    @State private var actIndex = 0
    @State private var phase: ScenarioDialoguePhase = .prompt
    @State private var activeFrames: [String] = []
    @State private var frameStep = 0
    @State private var choiceOrder: [String] = []
    @State private var wrongChoiceIDs: Set<String> = []
    @State private var lastWrongChoice: ScenarioSceneChoice?
    @State private var lastWrongPhrase: StudyPhrase?
    @State private var mistakes = 0

    @State private var showNiqqud = true
    @State private var showTransliteration = true
    @State private var showTranslation = false

    @State private var stageInteracted = false
    @State private var collectedProps: [ScenarioCollectedProp] = []
    @State private var hotspotTip: ScenarioHotspotTip?
    @State private var burstEmoji: String?
    @State private var showPopupCard = false
    @State private var showTranscript = false
    @State private var history: [ScenarioTranscriptEntry] = []

    @State private var shakeTrigger = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var burstTask: Task<Void, Never>?
    @State private var celebration: StudyAnswerCelebration?

    private var acts: [ScenarioAct] { scenario.acts }

    private var currentAct: ScenarioAct {
        acts[min(max(actIndex, 0), acts.count - 1)]
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
                if showPopupCard {
                    bilingualPopupCard
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
        .studyDetail(scenario.navTitle)
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

    // MARK: - Act Stepper

    private var actStepper: some View {
        HStack(spacing: 6) {
            ForEach(Array(acts.enumerated()), id: \.element.id) { idx, act in
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
            ScenarioCinemaStage(
                imageName: currentImageName,
                aspectRatio: scenario.stageAspectRatio,
                act: currentAct,
                partnerRole: scenario.partnerRole,
                phase: phase,
                activeFrames: activeFrames,
                frameStep: frameStep,
                collectedProps: collectedProps,
                stageInteracted: stageInteracted,
                hotspotTip: hotspotTip,
                burstEmoji: burstEmoji,
                shakeTrigger: shakeTrigger,
                onTapCustomer: {
                    audio.playSelectionHaptic()
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                        hotspotTip = ScenarioHotspotTip(
                            title: "你的内心想法",
                            hebrew: nil,
                            subtitle: currentAct.userThought
                        )
                    }
                },
                onTapPartner: {
                    speakIfAvailable(currentAct.partner.hebrew)
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                        hotspotTip = ScenarioHotspotTip(
                            title: "\(scenario.partnerRole)刚刚说",
                            hebrew: showNiqqud ? currentAct.partner.hebrew : currentAct.partner.unpointed,
                            subtitle: "\(currentAct.partner.transliteration) · \(currentAct.partner.meaningZh)"
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
                    let target: ScenarioDialoguePhase = lastWrongChoice != nil ? .wrong : .interact
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
        if let bubble = activeSpeechBubble {
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
            let p = currentAct.partner
            return StageBubbleContent(
                speaker: scenario.partnerRole,
                hebrew: showNiqqud ? p.hebrew : p.unpointed,
                transliteration: p.transliteration,
                meaningZh: p.meaningZh,
                audioHebrew: p.hebrew,
                tint: progress.theme.accent,
                surface: progress.theme.cardSurface,
                alwaysShowMeaning: false
            )
        case .interact:
            guard let solution = currentAct.solutionChoice, let reply = solution.partnerReplyHebrew else { return nil }
            return StageBubbleContent(
                speaker: "\(scenario.partnerRole)回应",
                hebrew: showNiqqud ? reply : withoutHebrewMarks(reply),
                transliteration: nil,
                meaningZh: solution.partnerReplyZh,
                audioHebrew: reply,
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
            Text("第 \(actIndex + 1)/\(acts.count) 幕")
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

    // MARK: - Interactive Bilingual Popup Card (Menu / Market Specialties)

    private var bilingualPopupCard: some View {
        StudyCard(padding: 14, spacing: 10) {
            HStack {
                Text(scenario.cardPopupTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progress.theme.ink)
                Spacer()
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        showPopupCard = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(progress.theme.mutedInk)
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(scenario.popupItems) { item in
                    Button {
                        speakIfAvailable(item.hebrew)
                    } label: {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Text(item.emoji)
                                Spacer()
                                Text(item.tag)
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
                            Text(entry.isUser ? "你" : scenario.partnerRole)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(entry.isUser ? progress.theme.success : progress.theme.mutedInk)
                                .frame(width: 46, alignment: .leading)
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

    private func choiceRow(choice: ScenarioSceneChoice, phrase: StudyPhrase) -> some View {
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
                    if actIndex < acts.count - 1 {
                        startAct(actIndex + 1, autoSpeak: true)
                    } else {
                        phase = .summary
                        celebration = StudyAnswerCelebration(combo: acts.count)
                        audio.playFeedback(.correct)
                    }
                } label: {
                    Text(actIndex < acts.count - 1
                         ? "进入第 \(actIndex + 2) 幕：\(acts[actIndex + 1].stepLabel)"
                         : "完成本单元 · 查看复盘")
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
                    Text("\(acts.count) 幕情景全部通关")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.22), in: Capsule())
                    Spacer()
                    Text(String(repeating: "★", count: stars) + String(repeating: "☆", count: 3 - stars))
                        .font(.headline)
                }
                Text(scenario.summaryHeadline)
                    .font(.title3.weight(.bold))
                Text("\(scenario.summaryDescription)（本轮小插曲 \(mistakes) 次）。")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.92))
            }

            StudyCard(padding: 14, spacing: 10) {
                HStack {
                    Text("本场核心台词复盘")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(progress.theme.ink)
                    Spacer()
                    Text("\(acts.count) 句实战表达")
                        .font(.caption)
                        .foregroundStyle(progress.theme.mutedInk)
                }
                ForEach(Array(acts.enumerated()), id: \.element.id) { idx, act in
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
        actIndex = min(max(index, 0), acts.count - 1)
        phase = .prompt
        activeFrames = []
        frameStep = 0
        wrongChoiceIDs = []
        lastWrongChoice = nil
        lastWrongPhrase = nil
        stageInteracted = false
        hotspotTip = nil
        burstEmoji = nil
        showPopupCard = false
        choiceOrder = currentAct.choices.map(\.id).shuffled()
        if autoSpeak {
            speakIfAvailable(currentAct.partner.hebrew)
        }
    }

    private func restartEpisode() {
        history = []
        collectedProps = []
        mistakes = 0
        celebration = nil
        startAct(0, autoSpeak: true)
    }

    private func selectChoice(_ choice: ScenarioSceneChoice, phrase: StudyPhrase) {
        guard phase != .animating, !wrongChoiceIDs.contains(choice.id) else { return }
        hotspotTip = nil
        speakIfAvailable(phrase.hebrew)

        if choice.isCorrect {
            lastWrongChoice = nil
            lastWrongPhrase = nil
            audio.playFeedback(.correct)
            celebration = StudyAnswerCelebration(combo: 0)
            history.append(ScenarioTranscriptEntry(
                isUser: false,
                hebrew: currentAct.partner.hebrew,
                unpointed: currentAct.partner.unpointed,
                meaningZh: currentAct.partner.meaningZh
            ))
            history.append(ScenarioTranscriptEntry(
                isUser: true,
                hebrew: phrase.hebrew,
                unpointed: phrase.hebrewUnpointed,
                meaningZh: phrase.meaningZh
            ))
            if let reply = choice.partnerReplyHebrew, let translation = choice.partnerReplyZh {
                history.append(ScenarioTranscriptEntry(
                    isUser: false,
                    hebrew: reply,
                    unpointed: withoutHebrewMarks(reply),
                    meaningZh: translation
                ))
            }
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

    private func playFrameSequence(_ frames: [String], targetPhase: ScenarioDialoguePhase) {
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
        let prop = ScenarioCollectedProp(
            id: interaction.propID,
            emoji: interaction.propEmoji,
            label: interaction.propLabel,
            tipTitle: interaction.propTipTitle,
            tipHebrew: interaction.propTipHebrew,
            tipSubtitle: interaction.propTipSubtitle,
            opensPopupCard: interaction.opensPopupCard,
            audioHebrew: interaction.tapAudioHebrew
        )
        if !collectedProps.contains(where: { $0.id == prop.id }) {
            collectedProps.append(prop)
        }
        audio.playFeedback(.flip)
        if interaction.opensPopupCard {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                showPopupCard = true
            }
        }
        if let hebrew = interaction.tapAudioHebrew {
            speakIfAvailable(hebrew)
        }
        triggerBurst(interaction.burstEmoji)
    }

    private func handlePropTap(_ prop: ScenarioCollectedProp) {
        audio.playSelectionHaptic()
        if prop.opensPopupCard {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                showPopupCard.toggle()
            }
        } else {
            triggerBurst("\(prop.emoji)✨")
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                hotspotTip = ScenarioHotspotTip(
                    title: prop.tipTitle,
                    hebrew: prop.tipHebrew,
                    subtitle: prop.tipSubtitle
                )
            }
        }
        if let hebrew = prop.audioHebrew {
            speakIfAvailable(hebrew)
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

private struct ScenarioCinemaStage: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let imageName: String
    let aspectRatio: CGFloat
    let act: ScenarioAct
    let partnerRole: String
    let phase: ScenarioDialoguePhase
    let activeFrames: [String]
    let frameStep: Int
    let collectedProps: [ScenarioCollectedProp]
    let stageInteracted: Bool
    let hotspotTip: ScenarioHotspotTip?
    let burstEmoji: String?
    let shakeTrigger: Int

    let onTapCustomer: () -> Void
    let onTapPartner: () -> Void
    let onTapProp: (ScenarioCollectedProp) -> Void
    let onTapStageCTA: () -> Void
    let onDismissTip: () -> Void
    let onSelectFrame: (Int) -> Void
    let onReplayFrames: () -> Void

    @State private var breathing = false
    @State private var pulseRing = false
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        ZStack {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .id(imageName)
                                .transition(reduceMotion ? .identity : .opacity)
                        }
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: imageName)
                        .scaleEffect(!reduceMotion && phase != .animating && breathing ? 1.035 : 1.0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: breathing)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .accessibilityLabel(act.title)

                        LinearGradient(
                            colors: [Color.black.opacity(0.32), Color.clear, Color.black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)

                        // Top Bar: Act badge + accumulated props + replay
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

                                ForEach(collectedProps.prefix(3)) { prop in
                                    propBadge(prop.emoji, label: prop.label) { onTapProp(prop) }
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
                            hotspotButton(emoji: "💭", tint: .orange, label: "查看内心想法", action: onTapCustomer)
                                .position(x: geo.size.width * act.customerHotspot.x, y: geo.size.height * act.customerHotspot.y)

                            hotspotButton(emoji: "🔊", tint: .teal, label: "重听\(partnerRole)台词", action: onTapPartner)
                                .position(x: geo.size.width * act.partnerHotspot.x, y: geo.size.height * act.partnerHotspot.y)
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
            }
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
