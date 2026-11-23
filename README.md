# Alef — 希伯来语字母与词汇学习工具 (iOS 原生版)

**Alef** 是一款基于 **SwiftUI + PencilKit + WidgetKit** 构建的离线优先希伯来语原生 iOS 学习应用（iOS 17+），内置 22 个希伯来字母的印刷体与手写体对照、分步笔顺与临摹练习、词尾形（Sofit）与 Begadkefat 规则、1,053 个高频词库、情景短语、分级阅读、拼读实验室、动态 SRS 间隔重复、本地学习提醒以及主屏幕/锁屏「每日字母」小组件。

---

## 核心功能

### 1. 字母表总览、详情与 PencilKit 手写描红
- **双序列与 13 项定制展示**：支持标准 **RTL（从右到左）** 与 **LTR** 顺序切换；支持入门/精学/自定义显示预设（印刷体、手写体、词尾形、达盖什字形、现代与古典发音、音译、Gematria 数值、掌握度等）。
- **分步笔顺与手写临摹**：内置矢量笔顺动画与 `PKCanvasView` 手写描红区，支持印刷体、手写体、词尾形及加点手写形式，落笔与清空带有触感反馈。

### 2. 高频词汇、短语、阅读与每日记词
- **词库与词形解析**：覆盖 11 大主题共 1,053 个词条、44 条情景短语及 6 篇短文阅读（16 个句子）；提供带点（Niqqud）/ 去点对照、IPA 音标、词根、语法标签、变形提示与例句发音。
- **今日记词小组**：按天分组（默认每组 5 词），支持“先认读、再拼写（屏内希伯来语键盘含词尾形，或切换系统键盘）”流程。

### 3. 动态 SRS 复习与测验练习
- **SM-2 动态间隔重复**：单词与字母均支持基于作答表现（重来 / 困难 / 记住 / 轻松）动态计算间隔与难度系数；到期复习支持答错当场加入本轮末尾再练一次，答对后可微调难度。
- **专项测验**：字母闪卡、字形→发音、手写→印刷、匹配词尾、达盖什辨音、词义测验、听力辨音与拼写练习，配合音效与触感反馈。

### 4. 发音规则、拼读实验室与离线音频
- **规则速查与拼读实验室**：涵盖 Sofit 词尾形、Begadkefat 软硬音、易混字母、喉音与 Niqqud 元音点；支持自由组合辅音与元音试听，并提供听音辨音练习。
- **完全离线音频**：打包脚本自动将 1,529 段预录 MP3（见 [音频来源](public/audio/CREDITS.md)）与提示音效集成至 `StudyAssets`，无录音时回退至 iOS `he-IL` 系统语音。

### 5. 本地学习提醒、主题、小组件与数据备份
- **本地提醒**：基于 `UNUserNotificationCenter` 离线安排每日固定时段提醒，支持“仅在有到期复习时提醒”与点击跳转。
- **6 套原生外观**：跟随系统、白色、羊皮纸、玫瑰、紫罗兰、深色。
- **主屏幕与锁屏「每日字母」小组件**：支持桌面小尺寸与锁屏圆形/矩形/单行样式，按本地日期离线轮换 22 个字母，点击直达对应字母详情。
- **JSON 备份与防丢失提醒**：支持导入/导出/剪贴板复制、变更预览与撤销上次导入；累计一定学习进度且超过 7 天未备份时主动提醒保存备份（适配免费个人签名定期重签场景）。

---

## iPhone 安装方式

1. 在 GitHub 仓库打开 **Actions → Build Alef iOS IPA → Run workflow**。默认使用 **Xcode 27** 预览 runner；若无法分配，可选择 **Xcode 26 (Intel)**。工作流会自动执行内容校验、TypeScript 类型检查、`AppTests` 单元测试并产出 `Alef.ipa`。
2. 下载运行结果中的 **Alef-iOS**，解压得到 `Alef.ipa`（未签名，需自签名后安装）。
3. Windows 用户可按 [AltStore Classic 官方指南](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) 安装 AltServer 和 AltStore，再在 iPhone 上通过 **AltStore → My Apps → ＋** 导入 `Alef.ipa`（提示保留应用扩展时选择保留，以启用小组件）。免费 Apple 账号签名通常每 7 天需刷新一次，刷新或重装前建议在「我的 → 数据备份与恢复」导出 JSON 备份。
4. 安装后可长按主屏幕或锁定屏幕，在组件库中搜索 **Alef** 添加「每日字母」。

---

## 本地开发与内容管线

### 环境要求
- **Node.js** 20+（用于将 `src/data/` 编译并校验为 iOS 学习资源）
- **Xcode 15+**（仅在 macOS 本地编译/运行 `ios/App/App.xcodeproj` 时需要）

### 常用命令

```bash
# 安装轻量数据构建依赖 (esbuild + typescript)
npm install

# TypeScript 数据模型与词库类型检查
npm run typecheck

# 校验并将词库、字母、短语、阅读与离线音频同步到 ios/App/App/StudyAssets/
npm run prepare:ios

# 运行内容管线与 Widget ID 同步校验测试
npm run verify:content
```

在 Mac 本地开发时，更新 `src/data/` 或 `public/audio/` 后执行 `npm run prepare:ios`，再打开 `ios/App/App.xcodeproj` 编译运行或执行 `AppTests`。

---

## 项目结构

```text
Alef/
├── .github/workflows/
│   └── build-ios.yml             # 内容校验、XCTest 单元测试与 IPA 打包工作流
├── build/
│   ├── fonts/                    # Gveret Levin 手写体字体与许可
│   ├── prepare-ios.mjs           # 生成 iOS StudyAssets 资源包与反馈音效
│   ├── validate-content.mjs      # 词库、音频、Widget 字母表一致性校验
│   └── validate-content.test.mjs # 数据校验单元测试
├── ios/App/
│   ├── App/                      # SwiftUI 主应用（字母、词库、练习、规则、我的）
│   ├── AppTests/                 # XCTest 核心逻辑单元测试 (AlefCoreTests)
│   ├── DailyLetterWidget/        # 主屏幕与锁屏「每日字母」WidgetKit 扩展
│   └── Shared/                   # 主应用与小组件共享模型与视图 (DailyLetter)
├── public/audio/                 # 1,529 段预录希伯来语 MP3 与 CREDITS.md
├── src/
│   ├── data/                     # 字母表、元音、短语、阅读、变形与分批词库数据源
│   └── types/                    # TypeScript 数据结构定义
├── 设计文档/                      # UI 设计说明与离线发音核对记录
├── package.json
└── tsconfig.json
```
