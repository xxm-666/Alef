# Alef — 希伯来语字母与词汇学习工具 (iOS 原生版)

**Alef** 是一款基于 **SwiftUI + PencilKit + WidgetKit** 构建的离线优先希伯来语原生 iOS 学习应用（iOS 17+），内置 22 个希伯来字母的印刷体与手写体对照、分步笔顺与临摹练习、词尾形（Sofit）与 Begadkefat 规则、1,760 个词条、情景短语、分级阅读、拼读实验室、动态 SRS 间隔重复、本地学习提醒以及主屏幕/锁屏「已学单词」小组件。

---

## 核心功能

### 1. 字母表总览、详情与 PencilKit 手写描红
- **双序列与 13 项定制展示**：支持标准 **RTL（从右到左）** 与 **LTR** 顺序切换；支持入门/精学/自定义显示预设（印刷体、手写体、词尾形、达盖什字形、现代与古典发音、音译、Gematria 数值、掌握度等）。
- **分步笔顺与手写临摹**：内置矢量笔顺动画与 `PKCanvasView` 手写描红区，支持印刷体、手写体、词尾形及加点手写形式，落笔与清空带有触感反馈。

### 2. 高频词汇、短语、阅读与每日记词
- **词库与词形解析**：覆盖 16 个主题共 1,760 个词条，另有 10 个场景的 120 条短句、24 篇现代阅读和 14 篇经典选读。词条包含带点（Niqqud）和无点拼写、IPA 音标与语法标签，部分词条提供词根、变形和例句。
- **组合筛选**：可按主题、常用程度和拼读难度同时筛选。常用程度参考希伯来语字幕中无点词形的出现频率，以前 1,500 名、前 8,000 名划分「常用」「较常用」「扩展」。短语按其中最低频的词分档。拼读难度参考字母数、元音数、词数和词首辅音组合，分为「入门」「进阶」「挑战」。[字幕词频来源](https://github.com/hermitdave/FrequencyWords/blob/525f9b560de45753a5ea01069454e72e9aa541c6/content/2018/he/he_50k.txt)
- **今日记词小组**：按天分组（默认每组 5 词），支持“先认读、再拼写（屏内希伯来语键盘含词尾形，或切换系统键盘）”流程。

### 3. 动态 SRS 复习与测验练习
- **SM-2 动态间隔重复**：单词与字母均支持基于作答表现（重来 / 困难 / 记住 / 轻松）动态计算间隔与难度系数；到期复习支持答错当场加入本轮末尾再练一次，答对后可微调难度。
- **专项测验**：字母闪卡、字形→发音、手写→印刷、匹配词尾、达盖什辨音、词义测验、听力辨音与拼写练习，配合音效与触感反馈。

### 4. 发音规则、拼读实验室与离线音频
- **规则速查与拼读实验室**：涵盖 Sofit 词尾形、Begadkefat 软硬音、易混字母、喉音与 Niqqud 元音点；支持自由组合辅音与元音试听，并提供听音辨音练习。
- **完全离线音频**：打包脚本将 2,336 段真人或合成发音 MP3 和提示音效集成至 `StudyAssets`。无录音时回退至 iOS `he-IL` 系统语音。[音频来源](public/audio/CREDITS.md)

### 5. 本地学习提醒、主题、小组件与数据备份
- **本地提醒**：基于 `UNUserNotificationCenter` 离线安排每日固定时段提醒，支持“仅在有到期复习时提醒”与点击跳转。
- **6 套原生外观**：跟随系统、白色、羊皮纸、玫瑰、紫罗兰、深色。
- **主屏幕与锁屏「已学单词」小组件**：从「学习中」和「已掌握」的词中每两小时轮换一次，点击直达单词详情。原「每日字母」组件会升级为「已学单词」，组件库仍提供「字母速查」。
- **JSON 备份与 iCloud Drive 文件夹自动同步**：支持将授权文件夹（建议选在「iCloud Drive」下自建文件夹，如 `iCloud Drive/Alef`）内的 `alef-sync.json` 在后台与变更时自动双向合并，**无需付费 Apple 开发者账号**，AltStore 重签或卸载重装后重新选择同一目录即可无损恢复；同时保留手动 JSON 导入/导出、变更预览与撤销功能。

---

## iPhone 安装方式

1. 在 GitHub 仓库打开 **Actions → Build Alef iOS IPA → Run workflow**，选择 3.0 分支和默认的 `sideload`。默认使用 **Xcode 27** runner，也可以选择 **Xcode 26 (Intel)**。工作流执行内容校验和 TypeScript 类型检查，勾选 `run_unit_tests` 可以同时运行 `AppTests`。
2. 下载运行结果中的 **Alef-iOS**，解压得到 `Alef.ipa`。安装前仍需重签，IPA 中的临时签名用于保留小组件的 App Group 信息。
3. Windows 用户可按 [AltStore Classic 官方指南](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) 安装 AltServer 和 AltStore，再在 iPhone 上通过 **AltStore → My Apps → ＋** 导入 `Alef.ipa`（提示保留应用扩展时选择保留，以启用小组件）。免费 Apple 账号签名通常每 7 天需刷新一次，刷新或重装前建议在「我的 → 数据备份与恢复」导出 JSON 备份。
4. 安装后先打开 Alef，再长按主屏幕或锁屏，在组件库中搜索 **Alef** 添加「已学单词」。主应用和小组件必须使用同一签名团队，并保留共同的 App Group，组件才能读取学习记录。

---

## App Store 与 TestFlight 打包

使用 **Xcode 26 或更新版本**。App Store 构建默认版本为 `3.0.0`，最低系统仍为 iOS 17。该构建支持本地跟读，云端转写在编译时禁用。音频包选取来源与许可有记录的音频，缺失录音时可使用 iOS 的希伯来语合成语音。

### 准备 Apple Developer 签名

1. 在同一个 Apple Developer Team 注册主应用 `com.xxm666.alef` 和组件 `com.xxm666.alef.dailyletter`，并给两者启用 App Groups，加入 `group.com.xxm666.alef.study`。
2. 在 App Store Connect 创建与主应用 Bundle ID 对应的记录。使用 Xcode 自动管理签名，或为两个目标分别创建 App Store 分发描述文件，使用同一张 Apple Distribution 证书。

### 在 GitHub Actions 构建

在仓库的 **Settings → Secrets and variables → Actions** 配置签名资料。Base64 值须为整个文件的编码，含换行也可正常解码。

| 类型 | 名称 | 值 |
| --- | --- | --- |
| Variable | `ALEF_DEVELOPMENT_TEAM` | 10 位 Apple Developer Team ID |
| Secret | `ALEF_DISTRIBUTION_P12_BASE64` | Apple Distribution 证书与私钥的带密码 P12 文件 |
| Secret | `ALEF_DISTRIBUTION_P12_PASSWORD` | P12 密码 |
| Secret | `ALEF_APP_STORE_PROFILE_BASE64` | 主应用的 App Store 分发描述文件 |
| Secret | `ALEF_WIDGET_STORE_PROFILE_BASE64` | 小组件的 App Store 分发描述文件 |

运行原有 **Build Alef iOS IPA** 工作流，选择包含发布配置的 3.0 分支，将 `distribution` 设为 `app-store`。构建号默认使用本次工作流的运行编号，也可以手动填入。可用 GitHub CLI 指定同样的选项。

```bash
gh workflow run build-ios.yml --ref ios-native-v3.0 -f distribution=app-store -f run_unit_tests=true
```

将 **Alef-App-Store** 中的签名 IPA 用 Apple Transporter 上传到 App Store Connect。每次上传前确保构建号可用。工作流只导出构建产物。

### 在 Mac 本地归档

安装项目的 Node.js 依赖，在 Xcode 登录具备签名权限的 Apple Developer 账号。把以下 Team ID 和构建号换成实际值。

```bash
npm ci
ALEF_DEVELOPMENT_TEAM=YOURTEAMID ALEF_BUILD_NUMBER=1 bash build/archive-app-store.sh
```

归档和 IPA 默认写到 `release/app-store/`。再次构建可以用 `ALEF_ARCHIVE_OUTPUT` 指定新的目录，用 `ALEF_MARKETING_VERSION` 设置版本。若本机已安装两份分发描述文件与证书，也可同时指定 `ALEF_APP_PROFILE` 和 `ALEF_WIDGET_PROFILE` 进行手动签名。切回侧载开发前运行 `npm run prepare:ios` 恢复完整的本地音频包。

### 提交审核前

- 发布 [隐私政策](public/privacy.txt)，在 App Store Connect 填写其公开网址和 [Alef 支持地址](https://github.com/xxm-666/Alef/issues)。应用内入口为「我的 → 关于 Alef」。
- 按实际分发包填写隐私标签、出口合规、年龄分级、内容权利和审核联系方式。准备 iPhone、13 英寸 iPad 的商店截图与描述。在 TestFlight 验证首启、离线发音、跟读权限、练习、备份恢复和 Widget。
- 根据 [音频来源清单](public/audio/CREDITS.md) 和应用内的署名核对素材分发权，尤其是 CC BY-SA 的署名、相同方式共享与附加限制要求。对未纳入商店包的音频取得授权后再随包分发。
- 选择发行地区，再确认对应的申报。例如中国大陆的备案与内容合规，以及欧盟的 DSA 交易者身份。

### 配置「Alef 完整版」内购

1. 在 App Store Connect 签署付费 App 协议并完成税务和银行资料。在 Alef 应用下创建非消耗型商品 `com.xxm666.alef.full`，配置名称、描述、价格、销售地区及审核截图。
2. App Store 构建的「我的 → Alef 完整版」提供一次性购买和恢复购买。免费内容包括完整入门路线及其四篇配套阅读、基础词包、特拉维夫咖啡馆和基础练习。完整版解锁其他词包、阅读、剧场和易混音辨析。
3. 在 Xcode 本地测试时，为 App scheme 的 **Run → Options → StoreKit Configuration** 选择 `ios/App/Alef.storekit`，并在 **Run → Arguments → Environment Variables** 设置 `ALEF_TEST_STOREKIT=1`。此开关只在 Debug 运行时生效，配置文件的价格仅用于模拟。测试完成、取消、待批准、恢复和退款等状态。
4. 用 TestFlight 验证正式商品。将首次内购与 App 版本一同送审，并提供「我的 → Alef 完整版」的审核路径。侧载 IPA 提供全部内容，使用现有侧载工作流即可。

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
│   └── build-ios.yml             # 内容校验、XCTest 与侧载 / App Store 打包工作流
├── build/
│   ├── fonts/                    # Gveret Levin 手写体字体与许可
│   ├── prepare-ios.mjs           # 生成 iOS StudyAssets 资源包与反馈音效
│   ├── archive-app-store.sh      # App Store 签名归档与导出
│   ├── validate-content.mjs      # 词库、音频、Widget 字母表一致性校验
│   └── validate-content.test.mjs # 数据校验单元测试
├── ios/App/
│   ├── App/                      # SwiftUI 主应用（字母、词库、练习、规则、我的）
│   ├── AppTests/                 # XCTest 核心逻辑单元测试 (AlefCoreTests)
│   ├── DailyLetterWidget/        # 主屏幕与锁屏 WidgetKit 扩展
│   └── Shared/                   # 主应用与小组件共享模型与视图 (DailyLetter)
├── public/audio/                 # 希伯来语离线发音 MP3 与 CREDITS.md
├── src/
│   ├── data/                     # 字母表、元音、短语、阅读、变形与分批词库数据源
│   └── types/                    # TypeScript 数据结构定义
├── 设计文档/                      # UI 设计说明与离线发音核对记录
├── package.json
└── tsconfig.json
```
