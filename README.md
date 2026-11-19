# Alef — 希伯来语字母与词汇学习工具

**Alef** 是一款基于 **Electron + React + TypeScript + Vite** 构建的希伯来语入门与桌面/移动端（PWA）学习应用，支持希伯来语 22 个字母的印刷体与手写体对照、笔顺描红、词尾形（Sofit）与 Begadkefat 发音规则、高频词库与间隔重复（SRS）闪卡复习，以及离线真声音频包。

---

## 核心功能

### 1. 字母表总览与详情精学
- **双序列切换**：支持希伯来语标准 **RTL（从右到左）** 与 **LTR** 排列顺序，提供全部、词尾形、Begadkefat、喉音、易混字母、待复习等筛选视图。
- **多维度卡片展示**：支持自由开关印刷体（Block）、手写体（Cursive）、词尾形（Sofit）、音译、Gematria 数值、现代发音与圣经发音差异、掌握度标记等显示项。
- **手写笔顺描红**：内置 [`StrokeOrderPad`](src/components/StrokeOrderPad.tsx)，支持印刷体与手写体（含词尾形）的分步笔顺动画演示与交互式临摹练习。

### 2. 高频词汇、短语与 SRS 复习
- **多分类词汇库**：覆盖日常问候、人物家庭、时间数字、生活饮食、自然世界、核心动词、形容与颜色、城市出行、身体情绪、工作学习、圣经文化 11 大主题（见 [`hebrewWords.ts`](src/data/hebrewWords.ts) 与 [`words/`](src/data/words)）。
- **词形与例句解析**：包含带点（Niqqud）/ 去点对照、IPA 音标、词根、语法标签、变形提示与例句发音。
- **闪卡与间隔重复**：[`FlashcardStudyView`](src/components/FlashcardStudyView.tsx) 支持字母与词汇翻转记忆、收藏筛选与本地学习统计（连续学习天数、今日/累计复习次数）。

### 3. 发音规则与元音音节实验室
- **特殊规则速查**：[`SpecialRulesView`](src/components/SpecialRulesView.tsx) 系统梳理词尾形（ם ן ץ ף ך）、Begadkefat（ב ג ד כ פ ת）点音变化、喉音字母与易混字母辨析。
- **元音音节实验室**：[`SyllableLab`](src/components/SyllableLab.tsx) 支持自由组合辅音字母与 Niqqud 元音符号，实时试听并练习拼读。

### 4. 真声音频与离线 PWA 支持
- **多级音频播放策略**：[`audio.ts`](src/utils/audio.ts) 优先播放内置预录 MP3（`public/audio/`），无录音时回退至浏览器希伯来语 TTS 或音译拼读。iOS 应用使用原生播放器播放录音，结束后释放音频会话。
- **离线音频包下载**：[`offlineAudio.ts`](src/utils/offlineAudio.ts) 支持在 PWA 中将全部字母、词汇与短语音频缓存至浏览器 `Cache Storage`，配合 Vite 构建自动生成的 `sw.js` 实现完全离线使用。

### 5. 桌面端特性、多主题与数据备份
- **Electron 桌面增强**：[`electron/main.cjs`](electron/main.cjs) 提供无边框自定义标题栏、窗口置顶（Always on Top）以及轻量级迷你浮窗模式（[`MiniWidgetView`](src/components/MiniWidgetView.tsx)）。
- **多套视觉主题**：内置 `parchment`（羊皮纸）、`dark`（暗色）、`rose`、`violet` 四种主题，移动端采用悬浮毛玻璃底部导航栏。
- **数据备份与恢复**：[`BackupModal`](src/components/BackupModal.tsx) 支持将学习进度、收藏词汇与个人设置导出/导入为 JSON 备份。

---

## 技术栈

- **桌面端容器**：Electron 33 (`electron-builder` 打包)
- **前端框架**：React 19 + TypeScript 5
- **构建工具**：Vite 5（含自定义离线 PWA Service Worker 插件 `alefOfflinePwaPlugin`）
- **UI 与字体**：`lucide-react`、`liquid-glass-react`、`@fontsource/gveret-levin`

---

## 快速开始

### 环境要求

- **Node.js** 20+（推荐与 CI 一致使用 Node 20）
- **npm**

### 安装依赖

```bash
npm install
```

### 本地开发

```bash
# 仅启动 Web / PWA 开发服务器 (默认端口 5173)
npm run dev:web

# 同时启动 Vite 与 Electron 桌面端窗口
npm run dev
```

### 构建与运行

```bash
# TypeScript 类型检查并构建前端资源到 dist/
npm run build

# 预览构建后的 Web 版本
npm run preview

# 构建后以 Electron 桌面端启动
npm run start
```

### 桌面端打包

```bash
# 生成未打包目录用于测试
npm run pack

# 打包 Windows 安装包与便携版 (NSIS + Portable)
npm run dist

# 打包 macOS (.dmg)
npm run dist:mac

# 打包 Linux (AppImage + deb)
npm run dist:linux
```

打包产物默认输出至 `release/` 目录，图标位于 `build/icon.png`。

### iPhone 安装与「每日字母」小组件

此 iOS 版本面向 iOS 17 及以上。底部导航使用 iOS 系统标签栏，学习页面沿用 Alef 网页界面。小组件会按手机本地日期轮换 22 个希伯来字母，可离线使用。

1. 在 GitHub 仓库打开 **Actions → Build Alef iOS IPA → Run workflow**。默认使用 **Xcode 27** 预览 runner。若 GitHub 无法分配该 runner，可以新建一次运行并选择 **Xcode 26 (Intel)**。两个选项都会把应用和小组件打进 IPA。
2. 下载运行结果中的 **Alef-iOS**，解压得到 `Alef.ipa`。IPA 需要签名后才能安装。
3. Windows 用户可以按 [AltStore Classic 官方指南](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) 安装 AltServer 和 AltStore，再在 iPhone 上通过 **AltStore → My Apps → ＋** 导入 `Alef.ipa`。如果提示是否保留应用扩展，选择保留。免费 Apple 账号签名通常需要每 7 天刷新。
4. 安装并打开 Alef 后，长按 iPhone 主屏幕，在小组件列表里搜索 **Alef** 并添加「每日字母」。

---

## 项目结构

```text
Alef/
├── .github/workflows/
│   └── deploy-pages.yml      # GitHub Pages 自动构建与部署工作流
├── electron/
│   ├── main.cjs              # Electron 主进程（窗口控制、置顶、迷你模式）
│   ├── preload.cjs           # 安全预加载脚本
│   └── icon.png              # 桌面应用图标
├── public/
│   ├── audio/                # 预录希伯来语 MP3 音频资源
│   ├── icons/                # PWA 应用图标
│   └── manifest.webmanifest  # PWA 清单文件
├── src/
│   ├── components/           # 字母网格、详情、笔顺画板、单词、闪卡、规则、设置等视图组件
│   ├── data/                 # 字母表、Niqqud 元音、短语、分批词汇及音频清单
│   ├── types/                # TypeScript 类型定义
│   ├── utils/                # 音频播放、离线缓存、本地存储、备份与 Electron 桥接
│   ├── App.tsx               # 应用主入口与视图路由状态
│   ├── index.css             # 全局样式与响应式/主题样式
│   └── main.tsx              # React 挂载入口
├── index.html
├── package.json
├── tsconfig.json
└── vite.config.ts            # Vite 配置与离线 PWA Service Worker 生成插件
```

---

## 部署

仓库配置了 GitHub Actions 工作流 [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml)：每次推送到 `main` 分支（或手动触发 `workflow_dispatch`）时，会自动执行 `npm ci` 与 `npm run build`，并将 `dist/` 目录部署至 GitHub Pages。
