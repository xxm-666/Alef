# Alef iOS 27 (Liquid Glass × 活力现代) UI 升级设计文档

## 一、设计目标与视觉理念

基于当前 Alef 原生 iOS（SwiftUI + PencilKit + WidgetKit）架构，在**100% 保留全部现有学习功能、数据模型与无障碍能力**的前提下，引入 **iOS 27 Liquid Glass（液态玻璃）** 设计语言与**活力现代**视觉层次，让界面更具吸引力、单手操作更流畅。

### 1.1 核心分层规范（功能层 vs. 内容层）
| 层级 | 适用组件 | iOS 26/27 原生表现 | iOS 17–25 及无障碍回退 |
|---|---|---|---|
| **功能浮层（Functional Layer）** | 底部 `TabView`、悬浮 `StudyActionBar`、快捷胶囊、闪卡自评栏 | `.tabBarMinimizeBehavior(.onScrollDown)`；`.glassEffect(.regular, in: ...)` | `.regularMaterial` + 柔和阴影；开启「减少透明度」时回退为 `cardSurface` 实底 |
| **内容层（Content Layer）** | 学习卡片 `StudyCard`、词条行、详情分区 | `RoundedRectangle(cornerRadius: 20, style: .continuous)` 实底 + 柔和投影 + 细描边 | 保持一致，确保希伯来字母与元音点（Niqqud）清晰锐利 |
| **活力焦点层（Hero Layer）** | 字母进度主卡、今日复习主卡、拼读实验室、咖啡馆漫画横幅 | 双色渐变 `StudyHeroCard`（适配 6 套主题与深浅模式）+ 内嵌半透明胶囊 CTA | 保持一致 |

### 1.2 6 套原生主题活力渐变 Token
- **跟随系统（system）**：青蓝渐变 `#0E7490 → #2563EB`（深色 `#0F766E → #1D4ED8`）
- **纯白（white）**：森青到湖绿 `#155E75 → #0D9488`
- **羊皮纸（parchment）**：深青到琥珀 `#0F766E → #B45309`
- **玫瑰（rose）**：酒红到玫红 `#9D174D → #E11D48`
- **紫罗兰（violet）**：深紫到靛蓝 `#5B21B6 → #4F46E5`
- **深色（dark）**：深海青到群青 `#0F766E → #1D4ED8`

### 1.3 流畅度与微交互升级
1. **底部导航滚动自动收起**：主页面向下浏览内容时，Tab Bar 自动收起为迷你胶囊，扩大阅读视野。
2. **弹簧分段滑块**：`StudySegments` 与 `MasteryPicker` 引入 `matchedGeometryEffect` 弹簧滑块动画（遵循 `accessibilityReduceMotion`）。
3. **声波播放反馈**：`PronunciationButton` 在音频播放中呈现动态声波与高亮环。
4. **高频入口前置**：词库将「元音点」「手写体」「仅看收藏」「卡片布局」提到外层一键切换；字母详情支持左右滑动及底部悬浮栏单手切字母；闪卡支持真 3D 翻面与底部悬浮 SM-2 自评条。
5. **可交互原型存档**：见 [alef-ios27-prototype.html](alef-ios27-prototype.html)。

---

## 二、100% 功能覆盖对照清单

| 模块 | 覆盖的一级与二/三级功能 |
|---|---|
| **字母（AlphabetView）** | 22 字母总览、全部/需复习筛选、RTL/LTR 实时切换、快速操作模式、长按快捷菜单、13 项显示定制与实时预览（至少保留一种字形）、词尾变形 5 组速查、入门路线入口、字母详情（现代/古典对照、达盖什、词尾数值、代表例词、字源、易混跳转、记忆曲线）、独立笔顺动画与 PencilKit 描红 |
| **词库（WordsView）** | 1,053 词多字段搜索、外置快捷胶囊（元音点/手写体/收藏/卡片切换）、11 主题/首字母/范围/排序完整筛选弹窗、单词详情（例句、记忆曲线、跟读节奏/分段对比与 AI 识别、词根家族跳转、字母拆解跳转、词形变化朗读）、情景短语（场景/收藏/自测遮罩/0.68×慢速/跟读）、分级阅读（完整/过渡/无点三模式、生词点按释义、单句跟读、阅读理解） |
| **练习（PracticeCenterView）** | 今日到期复习与错题本（词义/拼写分类与专项重练）、今日记词（每日分组、先认读后拼写、22 字母+5 词尾屏内希伯来语键盘）、3D 字母闪卡（5 范围、4 正面字形、打乱顺序、4 档 SM-2 自评）、4 类字母测验、3 类单词测验、易混音辨析（双行对比试听）、4 款学习小游戏（侦探/拼字/寻宝/翻牌配对）、8 阶段入门路线与咖啡馆点单互动漫画 |
| **规则（StudyRulesView）** | 拼读实验室快捷预览 + 完整探索/听音测验与 Shva 对照、全部 8 大专题（词尾变形、达盖什、易混字母、喉音字母、元音点、前缀与后缀、动词词干 Binyanim、可搜索词根家族） |
| **我的（StudySettingsView）** | 2×2 Bento 学习统计、6 套原生主题横向可视化色卡、RTL/LTR 开关、13 项字母卡片配置、本地学习提醒、发音与音效设置（语速/录音优先/音效/触感）、AI 转写配置与示例测试、JSON 备份恢复/预览/撤销与 iCloud Drive 文件夹自动同步、4 类小组件预览 |

---

## 三、实现任务清单

- [x] **任务 1**：沉淀 iOS 27 UI 升级设计文档并归档可交互 HTML 原型（`设计文档/iOS27_UI升级设计文档.md`、`设计文档/alef-ios27-prototype.html`）
- [x] **任务 2**：升级全局设计底座与 iOS 27 Liquid Glass 组件（`ios/App/App/StudyRootView.swift`：TabBar 滚动最小化、6 主题渐变 Token、`StudyHeroCard`、`StudyIconBadge`、`StudyProgressRing`、悬浮玻璃 `StudyActionBar`、弹簧 `StudySegments` & `MasteryPicker`、声波 `PronunciationButton`、升级 `StudyPage`/`StudyHeading`/`StudyCard`/`StudyRow`/`StudyButtonStyle`）
- [x] **任务 3**：升级字母总览、字母详情与笔顺入口（`ios/App/App/AlphabetView.swift`：Hero 进度卡、快捷 RTL/LTR、字母网格长按快捷菜单、详情左右滑动手势与底部悬浮切字母栏）
- [x] **任务 4**：升级词库、短语、单词详情与阅读页面（`ios/App/App/WordsView.swift`：外置快捷胶囊行、词条语义掌握度徽章、单词详情 Hero 卡片）
- [x] **任务 5**：升级练习仪表盘、3D 闪卡、今日复习、今日记词与入门路线（`StudyFlashcardsView.swift`、`StudyReviewView.swift`、`DailyVocabularyView.swift`、`LearningPathView.swift`）
- [x] **任务 6**：升级规则中心、拼读快捷预览与「我的」Bento 面板（`StudyRulesView.swift`、`StudySettingsView.swift`）
- [x] **任务 7**：运行内容管线校验（`npm run typecheck`、`npm run verify:content`）及 Swift 源码静态语法/`#available(iOS 26, *)` 守卫/测试兼容检查
