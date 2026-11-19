import React from 'react';
import {
  ArrowLeftRight,
  Database,
  Eye,
  Flame,
  Moon,
  PictureInPicture2,
  Pin,
  PinOff,
  RotateCcw,
  SlidersHorizontal,
  Sun,
  Volume2,
} from 'lucide-react';
import {
  AlphabetOrder,
  CustomDisplayConfig,
  ElectronWindowState,
  StudyStats,
  ThemeMode,
} from '../types/hebrew';
import { speakHebrew } from '../utils/audio';
import { OfflineAudioSettings } from './OfflineAudioSettings';

const THEME_CHOICES: { id: ThemeMode; label: string }[] = [
  { id: 'parchment', label: '羊皮纸日间' },
  { id: 'rose', label: '玫瑰红' },
  { id: 'violet', label: '暮光紫' },
  { id: 'dark', label: '深邃夜间' },
];

interface SettingsViewProps {
  theme: ThemeMode;
  onSelectTheme: (theme: ThemeMode) => void;
  order: AlphabetOrder;
  onToggleOrder: () => void;
  speechRate: number;
  onChangeSpeechRate: (rate: number) => void;
  displayConfig: CustomDisplayConfig;
  onUpdateDisplayConfig: (next: CustomDisplayConfig) => void;
  onResetDisplayConfig: () => void;
  onOpenBackup: () => void;
  masteredLettersCount: number;
  totalLettersCount: number;
  masteredWordsCount: number;
  totalWordsCount: number;
  studyStats: StudyStats;
  windowState: ElectronWindowState;
  onToggleAlwaysOnTop: () => void;
  onToggleMiniMode: () => void;
  onChangeOpacity: (opacity: number) => void;
}

const DISPLAY_FIELD_LABELS: { key: keyof CustomDisplayConfig; label: string }[] = [
  { key: 'showBlock', label: '印刷体' },
  { key: 'showCursive', label: '手写体' },
  { key: 'showSofit', label: '词尾形 Sofit' },
  { key: 'showBegadkefat', label: '软硬音标记' },
  { key: 'showHebrewName', label: '希伯来名称' },
  { key: 'showEnglishName', label: '英文名' },
  { key: 'showChineseName', label: '中文名' },
  { key: 'showModernSound', label: '现代读音' },
  { key: 'showBiblicalDiff', label: '古今差异' },
  { key: 'showTransliteration', label: '拉丁音译' },
  { key: 'showGematria', label: '数值 Gematria' },
  { key: 'showMastery', label: '掌握度标记' },
  { key: 'showCategoryBadges', label: '分类标签' },
];

export const SettingsView: React.FC<SettingsViewProps> = ({
  theme,
  onSelectTheme,
  order,
  onToggleOrder,
  speechRate,
  onChangeSpeechRate,
  displayConfig,
  onUpdateDisplayConfig,
  onResetDisplayConfig,
  onOpenBackup,
  masteredLettersCount,
  totalLettersCount,
  masteredWordsCount,
  totalWordsCount,
  studyStats,
  windowState,
  onToggleAlwaysOnTop,
  onToggleMiniMode,
  onChangeOpacity,
}) => {
  const todayKey = (() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
      d.getDate()
    ).padStart(2, '0')}`;
  })();
  const todayCount = studyStats.lastActiveDate === todayKey ? studyStats.todayReviews : 0;

  function toggleField(key: keyof CustomDisplayConfig) {
    onUpdateDisplayConfig({
      ...displayConfig,
      [key]: !displayConfig[key],
    });
  }

  return (
    <div className="view-container settings-view">
      <div className="settings-grid">
        {/* Theme & Appearance */}
        <section className="settings-card">
          <div className="settings-card-header">
            <div className="settings-card-title">
              {theme === 'dark' ? <Moon size={16} /> : <Sun size={16} />}
              <h3>外观主题</h3>
            </div>
          </div>
          <div className="theme-choice-grid" role="group" aria-label="外观主题">
            {THEME_CHOICES.map(({ id, label }) => (
              <button
                key={id}
                type="button"
                data-theme={id}
                className={`theme-choice-btn ${theme === id ? 'active' : ''}`}
                aria-pressed={theme === id}
                onClick={() => onSelectTheme(id)}
              >
                <span className="theme-swatch" aria-hidden="true" />
                <strong>{label}</strong>
              </button>
            ))}
          </div>
        </section>

        {/* Pronunciation & Order */}
        <section className="settings-card">
          <div className="settings-card-header">
            <div className="settings-card-title">
              <Volume2 size={16} />
              <h3>发音与阅读方向</h3>
            </div>
            <button
              type="button"
              className="btn-secondary btn-sm"
              onClick={() => speakHebrew('שָׁלוֹם', 'shalom', speechRate)}
            >
              <Volume2 size={14} />
              <span>试听 שָׁלוֹם</span>
            </button>
          </div>

          <div className="settings-rows">
            <div className="settings-row">
              <div className="settings-row-info">
                <strong>朗读语速：{speechRate.toFixed(2)}x</strong>
                <span>内置离线以色列神经网络语音（支持调速）</span>
              </div>
              <input
                type="range"
                min={0.65}
                max={1.3}
                step={0.05}
                value={speechRate}
                onChange={(e) => onChangeSpeechRate(Number(e.target.value))}
                className="settings-range"
                aria-label="调节朗读语速"
              />
            </div>

            <div className="settings-row">
              <div className="settings-row-info">
                <strong>字母表排列方向</strong>
                <span>
                  {order === 'rtl'
                    ? '当前：从右向左（符合希伯来语阅读习惯）'
                    : '当前：从左向右（按中文/英文习惯）'}
                </span>
              </div>
              <button
                type="button"
                className="btn-secondary btn-sm"
                onClick={onToggleOrder}
              >
                <ArrowLeftRight size={14} />
                <span>{order === 'rtl' ? 'RTL א←ת' : 'LTR א→ת'}</span>
              </button>
            </div>
          </div>
        </section>
      </div>

      {/* Alphabet Card Display Config */}
      <section className="settings-card">
        <div className="settings-card-header">
          <div className="settings-card-title">
            <Eye size={16} />
            <h3>全字母表卡片显示字段</h3>
          </div>
          <button
            type="button"
            className="btn-ghost btn-sm"
            onClick={onResetDisplayConfig}
          >
            <RotateCcw size={14} />
            <span>恢复默认</span>
          </button>
        </div>
        <div className="settings-chips-grid">
          {DISPLAY_FIELD_LABELS.map((item) => {
            const active = displayConfig[item.key];
            return (
              <button
                key={item.key}
                type="button"
                className={`filter-pill ${active ? 'active' : ''}`}
                onClick={() => toggleField(item.key)}
              >
                {item.label}
              </button>
            );
          })}
        </div>
      </section>

      <div className="settings-grid">
        {/* Backup & Sync */}
        <section className="settings-card">
          <div className="settings-card-header">
            <div className="settings-card-title">
              <Database size={16} />
              <h3>数据备份与同步</h3>
            </div>
          </div>
          <p className="settings-desc">
            导出 JSON 备份文件，或将手机/电脑上的字母掌握度、词库复习记录与收藏列表恢复到当前设备。
          </p>
          <div>
            <button
              type="button"
              className="btn-primary btn-sm"
              onClick={onOpenBackup}
            >
              <Database size={14} />
              <span>打开备份与导入/导出</span>
            </button>
          </div>
        </section>

        {!windowState.isElectron && <OfflineAudioSettings />}

        {/* Desktop Window Controls */}
        <section className="settings-card desktop-only-control">
          <div className="settings-card-header">
            <div className="settings-card-title">
              <SlidersHorizontal size={16} />
              <h3>桌面窗口设置</h3>
            </div>
          </div>
          <div className="settings-rows">
            <div className="settings-row">
              <div className="settings-row-info">
                <strong>窗口透明度：{Math.round(windowState.opacity * 100)}%</strong>
                <span>调低透明度可一边对照其他窗口一边背字母</span>
              </div>
              <input
                type="range"
                min={0.45}
                max={1}
                step={0.05}
                value={windowState.opacity}
                onChange={(e) => onChangeOpacity(Number(e.target.value))}
                className="settings-range"
                aria-label="调节窗口透明度"
              />
            </div>
            <div className="settings-row-actions">
              <button
                type="button"
                className={`btn-secondary btn-sm ${windowState.isAlwaysOnTop ? 'active-btn' : ''}`}
                onClick={onToggleAlwaysOnTop}
              >
                {windowState.isAlwaysOnTop ? <Pin size={14} /> : <PinOff size={14} />}
                <span>{windowState.isAlwaysOnTop ? '取消置顶' : '窗口置顶'}</span>
              </button>
              <button
                type="button"
                className="btn-secondary btn-sm"
                onClick={onToggleMiniMode}
              >
                <PictureInPicture2 size={14} />
                <span>切换迷你悬浮窗</span>
              </button>
            </div>
          </div>
        </section>
      </div>

      {/* Study Overview */}
      <section className="settings-card">
        <div className="settings-card-header">
          <div className="settings-card-title">
            <Flame size={16} />
            <h3>学习进度概览</h3>
          </div>
          <span className="muted-caption">今日复习 {todayCount} 次</span>
        </div>
        <div className="settings-stats-grid">
          <div className="settings-stat-box">
            <span className="settings-stat-value">
              {masteredLettersCount}/{totalLettersCount}
            </span>
            <span className="settings-stat-label">已掌握字母</span>
          </div>
          <div className="settings-stat-box">
            <span className="settings-stat-value">
              {masteredWordsCount}/{totalWordsCount}
            </span>
            <span className="settings-stat-label">已掌握高频词</span>
          </div>
          <div className="settings-stat-box">
            <span className="settings-stat-value">{studyStats.streakDays} 天</span>
            <span className="settings-stat-label">连续学习</span>
          </div>
          <div className="settings-stat-box">
            <span className="settings-stat-value">{studyStats.totalReviews}</span>
            <span className="settings-stat-label">累计复习次数</span>
          </div>
        </div>
      </section>
    </div>
  );
};
